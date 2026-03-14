"use client";

import { useEffect, useMemo, useRef, useState, useCallback } from "react";
import { useParams } from "next/navigation";
import Image from "next/image";
import Link from "next/link";
import dynamic from "next/dynamic";
import {
  getSharedResource,
  getSharedSnapshot,
  getRegionsGraph,
  getConfig,
  getRegionTilesUrl,
  type SharedMatchData,
  type RegionGraphEntry,
  type BuildingType,
  type SnapshotTick,
} from "@/lib/api";
import type { GameState, GameRegion, GamePlayer } from "@/hooks/useGameSocket";
import { Button } from "@/components/ui/button";
import {
  Clock,
  Crown,
  MapPin,
  Skull,
  Swords,
  Users,
  Hammer,
  TrendingUp,
  TrendingDown,
  Pause,
  Play,
  SkipBack,
  SkipForward,
  LogIn,
} from "lucide-react";

const GameMap = dynamic(
  () => import("@/components/map/GameMap"),
  { ssr: false }
);

const SPEEDS = [1, 2, 4, 8];

const STATUS_LABELS: Record<string, { label: string; color: string }> = {
  finished: { label: "Zakonczony", color: "text-slate-400" },
  in_progress: { label: "W trakcie", color: "text-emerald-300" },
  selecting: { label: "Wybor stolic", color: "text-amber-200" },
  cancelled: { label: "Anulowany", color: "text-red-400" },
  waiting: { label: "Oczekiwanie", color: "text-slate-400" },
};

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  if (m === 0) return `${s}s`;
  return `${m}m ${s}s`;
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  return d.toLocaleDateString("pl-PL", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function SharePage() {
  const { token } = useParams<{ token: string }>();

  const [sharedData, setSharedData] = useState<SharedMatchData | null>(null);
  const [regionGraph, setRegionGraph] = useState<RegionGraphEntry[]>([]);
  const [buildingTypes, setBuildingTypes] = useState<BuildingType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Replay state — build SnapshotTick list from snapshot_ticks numbers
  const [snapshots, setSnapshots] = useState<SnapshotTick[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [snapshotLoading, setSnapshotLoading] = useState(false);

  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const playingRef = useRef(false);
  const speedRef = useRef(1);
  const currentIndexRef = useRef(0);
  playingRef.current = playing;
  speedRef.current = speed;
  currentIndexRef.current = currentIndex;

  const snapshotCache = useRef<Map<number, GameState>>(new Map());

  // ── Load snapshot via share endpoint ────────────────────
  const loadSnapshot = useCallback(async (tick: number, index: number) => {
    const cached = snapshotCache.current.get(tick);
    if (cached) {
      setGameState(cached);
      setCurrentIndex(index);
      return;
    }

    setSnapshotLoading(true);
    try {
      const snap = await getSharedSnapshot(token, tick);
      const state = snap.state_data as unknown as GameState;
      snapshotCache.current.set(tick, state);
      setGameState(state);
      setCurrentIndex(index);
    } catch {
      // ignore
    } finally {
      setSnapshotLoading(false);
    }
  }, [token]);

  // ── Initial data load ────────────────────────────────────
  useEffect(() => {
    Promise.all([
      getSharedResource(token),
      getConfig(),
    ]).then(async ([data, cfg]) => {
      setSharedData(data);
      setBuildingTypes(cfg.buildings);

      const ticks: SnapshotTick[] = data.snapshot_ticks.map((t) => ({
        tick: t,
        created_at: "",
      }));
      setSnapshots(ticks);

      // Load region graph using the match id from shared data
      const graph = await getRegionsGraph(data.match.id);
      setRegionGraph(graph);

      setLoading(false);

      if (ticks.length > 0) {
        loadSnapshot(ticks[0].tick, 0);
      }
    }).catch(() => {
      setError("Nie mozna zaladowac udostepnionych danych. Link moze byc nieprawidlowy lub wygasl.");
      setLoading(false);
    });
  }, [token, loadSnapshot]);

  // ── Prefetch next snapshots ─────────────────────────────
  useEffect(() => {
    if (snapshots.length === 0) return;
    for (let i = currentIndex + 1; i <= Math.min(currentIndex + 2, snapshots.length - 1); i++) {
      const tick = snapshots[i].tick;
      if (!snapshotCache.current.has(tick)) {
        getSharedSnapshot(token, tick)
          .then((snap) => {
            snapshotCache.current.set(tick, snap.state_data as unknown as GameState);
          })
          .catch(() => {});
      }
    }
  }, [currentIndex, token, snapshots]);

  // ── Playback loop ───────────────────────────────────────
  useEffect(() => {
    if (!playing || snapshots.length === 0) return;

    const interval = setInterval(() => {
      if (!playingRef.current) return;
      const nextIdx = currentIndexRef.current + 1;
      if (nextIdx >= snapshots.length) {
        setPlaying(false);
        return;
      }
      loadSnapshot(snapshots[nextIdx].tick, nextIdx);
    }, 1000 / speedRef.current);

    return () => clearInterval(interval);
  }, [playing, snapshots, loadSnapshot]);

  // ── Derived data ────────────────────────────────────────
  const centroids = useMemo(() => {
    const c: Record<string, [number, number]> = {};
    for (const entry of regionGraph) {
      if (entry.centroid) c[entry.id] = entry.centroid;
    }
    return c;
  }, [regionGraph]);

  const buildingIcons = useMemo(() => {
    const m: Record<string, string> = {};
    for (const b of buildingTypes) {
      m[b.slug] = b.asset_key || b.slug;
    }
    return m;
  }, [buildingTypes]);

  const regions = useMemo(() => gameState?.regions ?? {}, [gameState?.regions]);
  const players = useMemo(() => gameState?.players ?? {}, [gameState?.players]);

  const currentTick = snapshots[currentIndex]?.tick ?? 0;
  const totalTicks = snapshots.length > 0 ? snapshots[snapshots.length - 1].tick : 0;

  const playerList = useMemo(() => {
    const entries = Object.entries(players) as [string, GamePlayer][];
    const regionEntries = Object.values(regions) as GameRegion[];

    return entries.map(([id, p]) => {
      const ownedRegions = regionEntries.filter((r) => r.owner_id === id).length;
      const totalUnits = regionEntries
        .filter((r) => r.owner_id === id)
        .reduce((sum, r) => sum + (r.unit_count || 0), 0);
      return { id, ...p, ownedRegions, totalUnits };
    }).sort((a, b) => b.ownedRegions - a.ownedRegions);
  }, [players, regions]);

  const playersForMap = useMemo(() => {
    const m: Record<string, { color: string; username: string }> = {};
    for (const [id, p] of Object.entries(players)) {
      m[id] = { color: (p as GamePlayer).color, username: (p as GamePlayer).username };
    }
    return m;
  }, [players]);

  // ── Handlers ────────────────────────────────────────────
  const handleSliderChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const idx = Number(e.target.value);
    setPlaying(false);
    loadSnapshot(snapshots[idx].tick, idx);
  };

  const stepForward = () => {
    if (currentIndex < snapshots.length - 1) {
      setPlaying(false);
      loadSnapshot(snapshots[currentIndex + 1].tick, currentIndex + 1);
    }
  };

  const stepBackward = () => {
    if (currentIndex > 0) {
      setPlaying(false);
      loadSnapshot(snapshots[currentIndex - 1].tick, currentIndex - 1);
    }
  };

  const cycleSpeed = () => {
    const idx = SPEEDS.indexOf(speed);
    setSpeed(SPEEDS[(idx + 1) % SPEEDS.length]);
  };

  // ── Loading / error states ───────────────────────────────
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[radial-gradient(circle_at_top,#1a2740_0%,#09111d_48%,#04070d_100%)]">
        <Image
          src="/assets/match_making/circle291.webp"
          alt=""
          width={48}
          height={48}
          className="h-12 w-12 animate-spin object-contain"
        />
      </div>
    );
  }

  if (error || !sharedData) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-6 bg-[radial-gradient(circle_at_top,#1a2740_0%,#09111d_48%,#04070d_100%)] text-zinc-100">
        <p className="text-lg text-slate-400">{error ?? "Nie znaleziono zasobu."}</p>
        <Link
          href="/register"
          className="inline-flex items-center gap-2 rounded-full border border-cyan-300/30 bg-[linear-gradient(135deg,#38bdf8,#0f766e)] px-6 py-2.5 font-display text-sm uppercase tracking-[0.2em] text-slate-950 transition-opacity hover:opacity-90"
        >
          <LogIn className="h-4 w-4" />
          Dolacz do gry
        </Link>
      </div>
    );
  }

  const { match, result } = sharedData;
  const status = STATUS_LABELS[match.status] ?? { label: match.status, color: "text-slate-400" };
  const winner = match.players.find((p) => p.user_id === match.winner_id);
  const hasReplay = snapshots.length > 0;

  return (
    <div className="min-h-screen overflow-hidden bg-[radial-gradient(circle_at_top,#1a2740_0%,#09111d_48%,#04070d_100%)] text-zinc-100">
      {/* Subtle background texture */}
      <div className="pointer-events-none absolute inset-0 bg-[url('/assets/ui/hex_bg_tile.webp')] bg-[size:240px] opacity-[0.05]" />

      {/* Header / branding */}
      <header className="relative border-b border-white/10 bg-slate-950/50 backdrop-blur-xl">
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <Link href="/" className="flex items-center gap-2.5">
            <div className="rounded-xl border border-white/10 bg-white/[0.04] p-1.5">
              <Image
                src="/assets/common/world.webp"
                alt="MapLord"
                width={24}
                height={24}
                className="h-6 w-6 object-contain"
              />
            </div>
            <span className="font-display text-xl text-zinc-50">MapLord</span>
          </Link>

          <Link
            href="/register"
            className="inline-flex items-center gap-2 rounded-full border border-cyan-300/30 bg-[linear-gradient(135deg,#38bdf8,#0f766e)] px-5 py-2 font-display text-sm uppercase tracking-[0.2em] text-slate-950 transition-opacity hover:opacity-90"
          >
            <LogIn className="h-4 w-4" />
            Dolacz do gry
          </Link>
        </div>
      </header>

      <main className="relative mx-auto max-w-5xl space-y-6 px-4 py-8 sm:px-6">
        {/* Page title */}
        <div>
          <h1 className="font-display text-3xl text-zinc-50">Wyniki meczu</h1>
          <p className="mt-1 text-sm text-slate-500">
            ID: {match.id.slice(0, 8)}... &mdash; udostepniony replay
          </p>
        </div>

        {/* Match info cards */}
        <section className="rounded-[24px] border border-white/10 bg-slate-950/55 p-6 backdrop-blur-xl">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div className="rounded-xl border border-white/10 bg-white/[0.04] px-4 py-3">
              <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-slate-500">
                <Swords className="h-3.5 w-3.5" />
                Status
              </div>
              <div className={`mt-1 font-display text-xl ${status.color}`}>
                {status.label}
              </div>
            </div>
            <div className="rounded-xl border border-white/10 bg-white/[0.04] px-4 py-3">
              <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-slate-500">
                <Users className="h-3.5 w-3.5" />
                Gracze
              </div>
              <div className="mt-1 font-display text-xl text-zinc-50">
                {match.players.length} / {match.max_players}
              </div>
            </div>
            <div className="rounded-xl border border-white/10 bg-white/[0.04] px-4 py-3">
              <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-slate-500">
                <Clock className="h-3.5 w-3.5" />
                {result ? "Czas trwania" : "Utworzono"}
              </div>
              <div className="mt-1 font-display text-xl text-zinc-50">
                {result
                  ? formatDuration(result.duration_seconds)
                  : formatDate(match.created_at)}
              </div>
            </div>
            {winner && (
              <div className="rounded-xl border border-amber-300/20 bg-amber-400/5 px-4 py-3">
                <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-amber-300/70">
                  <Crown className="h-3.5 w-3.5" />
                  Zwyciezca
                </div>
                <div className="mt-1 font-display text-xl text-amber-200">
                  {winner.username}
                </div>
              </div>
            )}
          </div>
          {(match.started_at || match.finished_at) && (
            <div className="mt-4 flex flex-wrap gap-x-6 gap-y-1 text-xs text-slate-500">
              {match.started_at && <span>Start: {formatDate(match.started_at)}</span>}
              {match.finished_at && <span>Koniec: {formatDate(match.finished_at)}</span>}
              {result && <span>Ticki: {result.total_ticks}</span>}
            </div>
          )}
        </section>

        {/* Players + stats */}
        <section className="rounded-[24px] border border-white/10 bg-slate-950/55 p-6 backdrop-blur-xl">
          <div className="mb-5 flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04]">
              <Users className="h-5 w-5 text-cyan-300" />
            </div>
            <h3 className="font-display text-xl text-zinc-50">Gracze</h3>
          </div>

          <div className="space-y-2">
            {match.players.map((player) => {
              const isWinner = player.user_id === match.winner_id;
              const playerResult = result?.player_results.find(
                (pr) => pr.user_id === player.user_id
              );

              return (
                <div
                  key={player.id}
                  className={`grid grid-cols-[auto_1fr_auto] items-center gap-4 rounded-2xl border p-4 ${
                    isWinner
                      ? "border-amber-300/25 bg-amber-400/5"
                      : "border-white/10 bg-white/[0.03]"
                  }`}
                >
                  {/* Color + name */}
                  <div className="flex items-center gap-3">
                    <div
                      className="h-8 w-8 rounded-lg border border-white/15"
                      style={{ backgroundColor: player.color }}
                    />
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-zinc-50">
                          {player.username}
                        </span>
                        {isWinner && (
                          <Crown className="h-4 w-4 text-amber-300" />
                        )}
                      </div>
                      <div className="flex items-center gap-2 text-xs text-slate-500">
                        {player.is_alive ? (
                          <span className="text-emerald-400">Zywy</span>
                        ) : (
                          <span className="flex items-center gap-1 text-red-400">
                            <Skull className="h-3 w-3" />
                            Wyeliminowany
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Stats */}
                  {playerResult ? (
                    <div className="flex flex-wrap justify-end gap-x-5 gap-y-1 text-sm">
                      <div className="text-center">
                        <div className="text-[10px] uppercase tracking-wider text-slate-500">Miejsce</div>
                        <div className="font-display text-lg text-zinc-50">#{playerResult.placement}</div>
                      </div>
                      <div className="text-center">
                        <div className="text-[10px] uppercase tracking-wider text-slate-500">Regiony</div>
                        <div className="font-display text-lg text-cyan-200">
                          <span className="inline-flex items-center gap-1">
                            <MapPin className="h-3 w-3" />
                            {playerResult.regions_conquered}
                          </span>
                        </div>
                      </div>
                      <div className="text-center">
                        <div className="text-[10px] uppercase tracking-wider text-slate-500">Jednostki</div>
                        <div className="font-display text-lg text-zinc-50">
                          {playerResult.units_produced}
                        </div>
                      </div>
                      <div className="text-center">
                        <div className="text-[10px] uppercase tracking-wider text-slate-500">Straty</div>
                        <div className="font-display text-lg text-red-400">
                          {playerResult.units_lost}
                        </div>
                      </div>
                      <div className="text-center">
                        <div className="text-[10px] uppercase tracking-wider text-slate-500">Budynki</div>
                        <div className="font-display text-lg text-amber-200">
                          <span className="inline-flex items-center gap-1">
                            <Hammer className="h-3 w-3" />
                            {playerResult.buildings_built}
                          </span>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <div />
                  )}

                  {/* ELO */}
                  {playerResult ? (
                    <div className="text-right">
                      <div className="text-[10px] uppercase tracking-wider text-slate-500">ELO</div>
                      <div
                        className={`flex items-center gap-1 font-display text-lg ${
                          playerResult.elo_change > 0
                            ? "text-emerald-300"
                            : playerResult.elo_change < 0
                              ? "text-red-400"
                              : "text-slate-400"
                        }`}
                      >
                        {playerResult.elo_change > 0 ? (
                          <TrendingUp className="h-4 w-4" />
                        ) : playerResult.elo_change < 0 ? (
                          <TrendingDown className="h-4 w-4" />
                        ) : null}
                        {playerResult.elo_change > 0 ? "+" : ""}
                        {playerResult.elo_change}
                      </div>
                    </div>
                  ) : (
                    <div />
                  )}
                </div>
              );
            })}
          </div>
        </section>

        {/* Replay section */}
        {hasReplay && (
          <>
            <div className="flex items-center justify-between gap-4">
              <h2 className="font-display text-2xl text-zinc-50">Replay</h2>
              <div className="flex items-center gap-2 text-sm text-slate-400">
                <span>Tick {currentTick} / {totalTicks}</span>
                <span className="text-slate-600">|</span>
                <span>{snapshots.length} snapshotow</span>
              </div>
            </div>

            {/* Map + player sidebar */}
            <div className="grid gap-4 lg:grid-cols-[1fr_280px]">
              {/* Map */}
              <div className="relative overflow-hidden rounded-[24px] border border-white/10 bg-slate-950/55 backdrop-blur-xl">
                <div className="aspect-[16/10] w-full">
                  {gameState && (
                    <GameMap
                      tilesUrl={getRegionTilesUrl(match.id)}
                      centroids={centroids}
                      regions={regions as Record<string, GameRegion>}
                      players={playersForMap}
                      selectedRegion={null}
                      targetRegions={[]}
                      highlightedNeighbors={[]}
                      dimmedRegions={[]}
                      onRegionClick={() => {}}
                      myUserId=""
                      animations={[]}
                      buildingIcons={buildingIcons}
                      activeEffects={gameState.active_effects}
                    />
                  )}
                </div>
                {snapshotLoading && (
                  <div className="absolute inset-0 flex items-center justify-center bg-slate-950/50">
                    <Image
                      src="/assets/match_making/circle291.webp"
                      alt=""
                      width={32}
                      height={32}
                      className="h-8 w-8 animate-spin object-contain"
                    />
                  </div>
                )}
              </div>

              {/* Player panel */}
              <div className="rounded-[24px] border border-white/10 bg-slate-950/55 p-4 backdrop-blur-xl">
                <div className="mb-3 flex items-center gap-2">
                  <Users className="h-4 w-4 text-cyan-300" />
                  <h3 className="font-display text-sm uppercase tracking-[0.2em] text-slate-300">
                    Gracze
                  </h3>
                </div>
                <div className="space-y-2">
                  {playerList.map((p) => {
                    const isWinner = p.id === match.winner_id;
                    return (
                      <div
                        key={p.id}
                        className={`rounded-xl border p-3 ${
                          !p.is_alive
                            ? "border-white/5 bg-white/[0.02] opacity-50"
                            : isWinner
                              ? "border-amber-300/20 bg-amber-400/5"
                              : "border-white/10 bg-white/[0.04]"
                        }`}
                      >
                        <div className="flex items-center gap-2">
                          <div
                            className="h-4 w-4 rounded border border-white/15"
                            style={{ backgroundColor: p.color }}
                          />
                          <span className="flex-1 truncate text-sm font-medium text-zinc-100">
                            {p.username}
                          </span>
                          {isWinner && <Crown className="h-3.5 w-3.5 text-amber-300" />}
                          {!p.is_alive && <Skull className="h-3.5 w-3.5 text-red-400" />}
                        </div>
                        <div className="mt-2 grid grid-cols-3 gap-1 text-center text-[10px]">
                          <div>
                            <div className="text-slate-500">Regiony</div>
                            <div className="font-display text-sm text-cyan-200">{p.ownedRegions}</div>
                          </div>
                          <div>
                            <div className="text-slate-500">Jednostki</div>
                            <div className="font-display text-sm text-zinc-100">{p.totalUnits}</div>
                          </div>
                          <div>
                            <div className="text-slate-500">Energia</div>
                            <div className="font-display text-sm text-cyan-200">{p.energy}</div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>

            {/* Timeline controls */}
            <div className="rounded-[24px] border border-white/10 bg-slate-950/55 p-4 backdrop-blur-xl">
              <div className="flex items-center gap-3">
                <div className="flex items-center gap-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={stepBackward}
                    disabled={currentIndex === 0}
                    className="h-8 w-8 rounded-full p-0 text-slate-300 hover:bg-white/[0.08] hover:text-zinc-100 disabled:opacity-30"
                  >
                    <SkipBack className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setPlaying(!playing)}
                    className="h-9 w-9 rounded-full p-0 text-cyan-200 hover:bg-cyan-400/10 hover:text-cyan-100"
                  >
                    {playing ? <Pause className="h-5 w-5" /> : <Play className="h-5 w-5" />}
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={stepForward}
                    disabled={currentIndex >= snapshots.length - 1}
                    className="h-8 w-8 rounded-full p-0 text-slate-300 hover:bg-white/[0.08] hover:text-zinc-100 disabled:opacity-30"
                  >
                    <SkipForward className="h-4 w-4" />
                  </Button>
                </div>

                <input
                  type="range"
                  min={0}
                  max={snapshots.length - 1}
                  value={currentIndex}
                  onChange={handleSliderChange}
                  className="h-1.5 flex-1 cursor-pointer appearance-none rounded-full bg-white/10 accent-cyan-400 [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-cyan-400 [&::-webkit-slider-thumb]:shadow-[0_0_8px_rgba(34,211,238,0.4)]"
                />

                <button
                  onClick={cycleSpeed}
                  className="rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-xs font-medium text-slate-300 transition-colors hover:bg-white/[0.08] hover:text-zinc-100"
                >
                  {speed}x
                </button>

                <div className="hidden text-right text-xs text-slate-500 sm:block">
                  <span className="font-display text-sm text-zinc-100">{currentTick}</span>
                  <span> / {totalTicks}</span>
                </div>
              </div>
            </div>
          </>
        )}

        {/* CTA footer */}
        <section className="rounded-[24px] border border-cyan-300/15 bg-cyan-400/5 p-8 text-center backdrop-blur-xl">
          <h2 className="font-display text-2xl text-zinc-50">Zagraj w MapLord</h2>
          <p className="mx-auto mt-2 max-w-md text-sm text-slate-400">
            Zbuduj armie, podbij terytoria i rywalizuj z graczami z calego swiata w czasie rzeczywistym.
          </p>
          <div className="mt-6 flex items-center justify-center gap-3">
            <Link
              href="/register"
              className="inline-flex items-center gap-2 rounded-full border border-cyan-300/30 bg-[linear-gradient(135deg,#38bdf8,#0f766e)] px-8 py-3 font-display text-sm uppercase tracking-[0.2em] text-slate-950 transition-opacity hover:opacity-90"
            >
              <LogIn className="h-4 w-4" />
              Dolacz do gry
            </Link>
            <Link
              href="/login"
              className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/[0.05] px-8 py-3 font-display text-sm uppercase tracking-[0.2em] text-slate-300 transition-colors hover:bg-white/[0.09] hover:text-zinc-100"
            >
              Zaloguj sie
            </Link>
          </div>
        </section>
      </main>
    </div>
  );
}
