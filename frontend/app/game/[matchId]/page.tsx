"use client";

import { useEffect, useState, useCallback, useMemo, use } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/hooks/useAuth";
import { useGameSocket } from "@/hooks/useGameSocket";
import { getRegions, getConfig, type GeoJSON, type BuildingType } from "@/lib/api";
import GameMap, {
  type TroopAnimation,
  ANIMATION_DURATION_MS,
} from "@/components/map/GameMap";
import GameHUD from "@/components/game/GameHUD";
import RegionPanel from "@/components/game/RegionPanel";
import ActionBar from "@/components/game/ActionBar";
import BuildQueue from "@/components/game/BuildQueue";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";

export default function GamePage({
  params,
}: {
  params: Promise<{ matchId: string }>;
}) {
  const { matchId } = use(params);
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();

  const {
    connected,
    gameState,
    events,
    selectCapital,
    attack,
    move,
    build,
  } = useGameSocket(matchId);

  const [geojson, setGeojson] = useState<GeoJSON | null>(null);
  const [buildings, setBuildings] = useState<BuildingType[]>([]);
  const [selectedRegion, setSelectedRegion] = useState<string | null>(null);
  const [actionTarget, setActionTarget] = useState<string | null>(null);
  const [animations, setAnimations] = useState<TroopAnimation[]>([]);

  // Redirect if not logged in
  useEffect(() => {
    if (!authLoading && !user) {
      router.replace("/login");
    }
  }, [user, authLoading, router]);

  // Load geo data and config
  useEffect(() => {
    getRegions().then(setGeojson).catch(console.error);
    getConfig()
      .then((cfg) => setBuildings(cfg.buildings))
      .catch(console.error);
  }, []);

  // Prune finished animations
  useEffect(() => {
    const timer = setInterval(() => {
      setAnimations((prev) => {
        const now = Date.now();
        const active = prev.filter(
          (a) => now - a.startTime < ANIMATION_DURATION_MS + 500
        );
        return active.length !== prev.length ? active : prev;
      });
    }, 500);
    return () => clearInterval(timer);
  }, []);

  // Build neighbor lookup
  const neighborMap = useMemo(() => {
    if (!geojson) return {};
    const m: Record<string, string[]> = {};
    for (const f of geojson.features) {
      m[f.properties.id] = f.properties.neighbor_ids || [];
    }
    return m;
  }, [geojson]);

  // Building slug → emoji icon lookup
  const buildingIcons = useMemo(() => {
    const m: Record<string, string> = {};
    for (const b of buildings) {
      m[b.slug] = b.icon;
    }
    return m;
  }, [buildings]);

  const myUserId = user?.id || "";
  const status = gameState?.meta?.status || "loading";

  // ── Derived state ──────────────────────────────────────────

  const sourceRegionData = selectedRegion
    ? gameState?.regions[selectedRegion]
    : null;

  const isSource =
    !!sourceRegionData &&
    sourceRegionData.owner_id === myUserId &&
    sourceRegionData.unit_count > 0;

  const highlightedNeighbors = useMemo(() => {
    if (!isSource || !selectedRegion || status !== "in_progress") return [];
    const allNeighbors = neighborMap[selectedRegion] || [];
    // Only highlight neighbors that exist on the current map
    const mapRegions = gameState?.regions || {};
    return allNeighbors.filter((nid) => nid in mapRegions);
  }, [isSource, selectedRegion, status, neighborMap, gameState?.regions]);

  const targetRegionData = actionTarget
    ? gameState?.regions[actionTarget]
    : null;

  const isAttack =
    !!targetRegionData && targetRegionData.owner_id !== myUserId;

  // My stats
  const { myRegionCount, myUnitCount } = useMemo(() => {
    if (!gameState) return { myRegionCount: 0, myUnitCount: 0 };
    let rc = 0;
    let uc = 0;
    for (const r of Object.values(gameState.regions)) {
      if (r.owner_id === myUserId) {
        rc++;
        uc += r.unit_count;
      }
    }
    return { myRegionCount: rc, myUnitCount: uc };
  }, [gameState, myUserId]);

  // ── Animation helper ───────────────────────────────────────

  const triggerAnimation = useCallback(
    (
      sourceId: string,
      targetId: string,
      units: number,
      type: "attack" | "move"
    ) => {
      const myPlayer = gameState?.players[myUserId];
      setAnimations((prev) => [
        ...prev,
        {
          id: crypto.randomUUID(),
          sourceId,
          targetId,
          color: myPlayer?.color || "#3b82f6",
          units,
          type,
          startTime: Date.now(),
        },
      ]);
    },
    [gameState, myUserId]
  );

  // ── Click handler ──────────────────────────────────────────

  const handleRegionClick = useCallback(
    (regionId: string) => {
      // Capital selection phase
      if (status === "selecting") {
        const region = gameState?.regions[regionId];
        if (!region) {
          toast.error("Ten region nie jest częścią tej mapy");
          return;
        }
        if (region.owner_id) {
          toast.error("Ten region jest już zajęty");
          return;
        }
        selectCapital(regionId);
        toast.success(`Stolica ustawiona: ${region.name}`);
        return;
      }

      if (status !== "in_progress") return;

      const region = gameState?.regions[regionId];
      if (!region) return;

      // If we have a source and clicked a valid neighbor → set as target
      if (
        selectedRegion &&
        selectedRegion !== regionId &&
        isSource &&
        highlightedNeighbors.includes(regionId)
      ) {
        setActionTarget(regionId);
        return;
      }

      // Click same region → deselect everything
      if (regionId === selectedRegion) {
        setSelectedRegion(null);
        setActionTarget(null);
        return;
      }

      // Select new region (switch source or info-only)
      setSelectedRegion(regionId);
      setActionTarget(null);
    },
    [
      status,
      gameState,
      myUserId,
      selectedRegion,
      isSource,
      highlightedNeighbors,
      selectCapital,
    ]
  );

  // ── Action handlers ────────────────────────────────────────

  // Confirm from ActionBar
  const handleConfirmAction = useCallback(
    (units: number) => {
      if (!selectedRegion || !actionTarget || !gameState) return;

      if (isAttack) {
        attack(selectedRegion, actionTarget, units);
        toast.info(`⚔️ Atak: ${units} jednostek`);
      } else {
        move(selectedRegion, actionTarget, units);
        toast.info(`📦 Przeniesienie: ${units} jednostek`);
      }

      triggerAnimation(
        selectedRegion,
        actionTarget,
        units,
        isAttack ? "attack" : "move"
      );
      setActionTarget(null);
    },
    [
      selectedRegion,
      actionTarget,
      gameState,
      isAttack,
      attack,
      move,
      triggerAnimation,
    ]
  );

  // Attack/move from RegionPanel
  const handleAttack = useCallback(
    (targetId: string, units: number) => {
      if (!selectedRegion) return;
      attack(selectedRegion, targetId, units);
      triggerAnimation(selectedRegion, targetId, units, "attack");
      toast.info(`⚔️ Atak: ${units} jednostek`);
    },
    [selectedRegion, attack, triggerAnimation]
  );

  const handleMove = useCallback(
    (targetId: string, units: number) => {
      if (!selectedRegion) return;
      move(selectedRegion, targetId, units);
      triggerAnimation(selectedRegion, targetId, units, "move");
      toast.info(`📦 Przeniesienie: ${units} jednostek`);
    },
    [selectedRegion, move, triggerAnimation]
  );

  const handleBuild = useCallback(
    (buildingType: string) => {
      if (selectedRegion) {
        build(selectedRegion, buildingType);
        toast.info(`🔨 Budowa: ${buildingType}`);
      }
    },
    [selectedRegion, build]
  );

  // ── Events ─────────────────────────────────────────────────

  useEffect(() => {
    if (events.length === 0) return;
    const last = events[events.length - 1];
    if (last.type === "game_over") {
      const winnerId = last.winner_id as string;
      const winner = gameState?.players[winnerId];
      if (winnerId === myUserId) {
        toast.success("🏆 Wygrałeś!");
      } else {
        toast.error(`Przegrałeś! Wygrywa: ${winner?.username || "?"}`);
      }
    }
    if (last.type === "player_eliminated" && last.player_id === myUserId) {
      toast.error("💀 Twoja stolica została zdobyta!");
    }
  }, [events, myUserId, gameState?.players]);

  // ── Render ─────────────────────────────────────────────────

  if (authLoading || !user) {
    return (
      <div className="flex h-screen items-center justify-center bg-zinc-950">
        <Loader2 className="h-8 w-8 animate-spin text-zinc-400" />
      </div>
    );
  }

  const players = gameState?.players || {};
  const regions = gameState?.regions || {};
  const currentTick = parseInt(gameState?.meta?.current_tick || "0", 10);

  return (
    <div className="relative h-screen w-screen overflow-hidden bg-zinc-950">
      {/* Connection status */}
      {!connected && (
        <div className="absolute inset-0 z-50 flex items-center justify-center bg-black/70">
          <div className="flex items-center gap-3 rounded-lg bg-zinc-900 px-6 py-4">
            <Loader2 className="h-5 w-5 animate-spin" />
            <span>Łączenie z serwerem...</span>
          </div>
        </div>
      )}

      {/* Capital selection overlay */}
      {status === "selecting" && (
        <div className="absolute left-1/2 top-4 z-20 -translate-x-1/2 rounded-lg bg-yellow-600/90 px-6 py-3 text-center font-bold text-white backdrop-blur">
          👑 Kliknij na region, aby wybrać stolicę
        </div>
      )}

      {/* Source selection hint */}
      {status === "in_progress" && !selectedRegion && (
        <div className="absolute left-1/2 top-4 z-20 -translate-x-1/2 rounded-lg bg-zinc-800/80 px-4 py-2 text-sm text-zinc-300 backdrop-blur">
          Kliknij swój region, aby wybrać źródło
        </div>
      )}

      {/* Target selection hint */}
      {status === "in_progress" && isSource && !actionTarget && (
        <div className="absolute left-1/2 top-4 z-20 -translate-x-1/2 rounded-lg bg-blue-800/80 px-4 py-2 text-sm text-blue-200 backdrop-blur">
          Kliknij sąsiedni region, aby zaatakować lub przenieść jednostki
        </div>
      )}

      {/* Game over overlay */}
      {status === "finished" && (
        <div className="absolute inset-0 z-50 flex items-center justify-center bg-black/70">
          <div className="rounded-xl bg-zinc-900 p-8 text-center">
            <h2 className="mb-4 text-3xl font-bold">🏆 Koniec gry!</h2>
            <button
              onClick={() => router.push("/dashboard")}
              className="rounded-lg bg-blue-600 px-6 py-2 font-medium text-white hover:bg-blue-500"
            >
              Wróć do lobby
            </button>
          </div>
        </div>
      )}

      {/* Map */}
      <GameMap
        geojson={geojson}
        regions={regions}
        players={players}
        selectedRegion={selectedRegion}
        targetRegion={actionTarget}
        highlightedNeighbors={highlightedNeighbors}
        onRegionClick={handleRegionClick}
        myUserId={myUserId}
        animations={animations}
        buildingIcons={buildingIcons}
      />

      {/* HUD */}
      <GameHUD
        tick={currentTick}
        status={status}
        players={players}
        events={events}
        myUserId={myUserId}
        myRegionCount={myRegionCount}
        myUnitCount={myUnitCount}
      />

      {/* Build queue progress */}
      <BuildQueue
        queue={gameState?.buildings_queue || []}
        buildings={buildings}
        myUserId={myUserId}
      />

      {/* Action Bar (click-to-attack) */}
      {actionTarget &&
        sourceRegionData &&
        targetRegionData &&
        selectedRegion && (
          <ActionBar
            sourceRegion={sourceRegionData}
            targetRegion={targetRegionData}
            sourceName={sourceRegionData.name}
            targetName={targetRegionData.name}
            isAttack={isAttack}
            onConfirm={handleConfirmAction}
            onCancel={() => setActionTarget(null)}
          />
        )}

      {/* Region panel (info + panel-based actions) */}
      {sourceRegionData && selectedRegion && !actionTarget && (
        <RegionPanel
          regionId={selectedRegion}
          region={sourceRegionData}
          players={players}
          myUserId={myUserId}
          neighborIds={neighborMap[selectedRegion] || []}
          regions={regions}
          buildings={buildings}
          onAttack={handleAttack}
          onMove={handleMove}
          onBuild={handleBuild}
          onClose={() => {
            setSelectedRegion(null);
            setActionTarget(null);
          }}
        />
      )}
    </div>
  );
}
