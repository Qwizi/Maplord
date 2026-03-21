"use client";

import { memo, useMemo, type ReactNode } from "react";
import Image from "next/image";
import { Zap } from "lucide-react";
import type { GamePlayer } from "@/hooks/useGameSocket";
import { Badge } from "@/components/ui/badge";
import type { CosmeticValue } from "@/lib/animationConfig";
import ActiveBoosts from "@/components/game/ActiveBoosts";

/**
 * Resolve the `emblem` cosmetic slot to a URL string, or return null if absent.
 * The cosmetic value may be a bare URL string or an object with a `url` field.
 */
function resolveEmblemUrl(cosmetics?: Record<string, unknown>): string | null {
  if (!cosmetics) return null;
  const raw = cosmetics.emblem as CosmeticValue | undefined;
  if (!raw) return null;
  if (typeof raw === "string") return raw;
  return raw.url ?? null;
}


interface GameHUDProps {
  tick: number;
  tickIntervalMs: number;
  status: string;
  players: Record<string, GamePlayer>;
  rankedPlayers: Array<{
    user_id: string;
    username: string;
    color: string;
    regionCount: number;
    unitCount: number;
    isAlive: boolean;
    isBot: boolean;
    /** Player's equipped cosmetics — used to render the emblem slot icon. */
    cosmetics?: Record<string, unknown>;
  }>;
  myUserId: string;
  myRegionCount: number;
  myUnitCount: number;
  myEnergy: number;
  fps?: number;
  ping?: number;
  connected?: boolean;
}

function formatClock(tick: number, tickIntervalMs: number) {
  const elapsedSeconds = Math.max(0, Math.floor((tick * tickIntervalMs) / 1000));
  const hours = Math.floor(elapsedSeconds / 3600);
  const minutes = Math.floor((elapsedSeconds % 3600) / 60);
  const seconds = elapsedSeconds % 60;

  if (hours > 0) {
    return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }

  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function statusLabel(status: string) {
  if (status === "selecting") return "Wybór stolicy";
  if (status === "in_progress") return "W trakcie";
  if (status === "finished") return "Koniec";
  return status;
}

export default memo(function GameHUD({
  tick,
  tickIntervalMs,
  status,
  players,
  rankedPlayers,
  myUserId,
  myRegionCount,
  myUnitCount,
  myEnergy,
  fps,
  ping,
  connected,
}: GameHUDProps) {
  const aliveCount = useMemo(
    () => Object.values(players).filter((player) => player.is_alive).length,
    [players]
  );
  const formattedClock = useMemo(() => formatClock(tick, tickIntervalMs), [tick, tickIntervalMs]);

  return (
    <div data-tutorial="hud" className="absolute left-2 top-2 z-10 flex max-w-[calc(100vw-5rem)] flex-col gap-2 sm:left-3 sm:top-3 sm:max-w-[240px]">
      <div className="inline-flex w-fit max-w-full items-center gap-2 rounded-full border border-border bg-card sm:bg-card/85 px-2.5 py-1.5 text-[10px] text-foreground shadow-lg sm:backdrop-blur-xl">
        <span className="font-display text-xs font-bold text-primary sm:text-base">{formattedClock}</span>
        <span className="h-1 w-1 rounded-full bg-white/20" />
        <Badge className="h-auto border-0 bg-primary/15 px-2 py-0.5 text-[10px] sm:text-xs text-primary hover:bg-primary/15">
          {statusLabel(status)}
        </Badge>
        <span className="hidden text-[10px] sm:text-xs text-muted-foreground sm:inline">{aliveCount} aktywnych</span>
        {connected === false && (
          <span className="flex items-center gap-1 text-[10px] sm:text-xs font-medium text-red-400">
            <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-red-400" />
            Rozłączono
          </span>
        )}
        {connected !== false && typeof fps === "number" && (
          <span className="text-[10px] sm:text-xs sm:font-semibold tabular-nums text-muted-foreground">{fps} FPS</span>
        )}
        {connected !== false && typeof ping === "number" && (
          <span className="text-[10px] sm:text-xs sm:font-semibold tabular-nums text-muted-foreground">{ping}ms</span>
        )}
      </div>

      <div className="grid grid-cols-3 gap-2">
        <CompactStat icon={<Zap className="h-3.5 w-3.5 text-primary" />} label="Energia" value={myEnergy} />
        <CompactStat icon="/assets/icons/storage_icon.webp" label="Regiony" value={myRegionCount} />
        <CompactStat icon="/assets/units/ground_unit.webp" label="Siła" value={myUnitCount} />
      </div>

      <ActiveBoosts
        boosts={players[myUserId]?.active_boosts ?? []}
        matchBoosts={players[myUserId]?.active_match_boosts}
        tickIntervalMs={tickIntervalMs}
      />

      <div className="military-frame hidden rounded-xl border border-border bg-card/80 p-1.5 shadow-[0_10px_24px_rgba(0,0,0,0.22)] backdrop-blur-xl sm:block">
        <div className="military-frame-inner px-1 pb-1.5 text-[10px] sm:text-xs uppercase tracking-[0.16em] text-muted-foreground">
          Ranking
        </div>
        <div className="space-y-0.5">
          {rankedPlayers.map((player, index) => {
            const emblemUrl = resolveEmblemUrl(player.cosmetics);
            return (
              <div
                key={player.user_id}
                className={`grid grid-cols-[18px_minmax(0,1fr)_auto] items-center gap-2 rounded-lg px-2 py-1 text-xs sm:text-sm ${
                  player.user_id === myUserId ? "bg-muted/30" : "bg-transparent"
                }`}
              >
                <div className="font-display text-muted-foreground">{index + 1}</div>
                <div className="min-w-0">
                  <div className={`flex items-center gap-1 truncate ${player.isAlive ? "text-foreground" : "text-muted-foreground line-through"}`}>
                    <span className="inline-block h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: player.color }} />
                    {/* Emblem cosmetic — small icon shown next to the player color dot */}
                    {emblemUrl && (
                      <Image
                        src={emblemUrl}
                        alt=""
                        width={16}
                        height={16}
                        className="h-4 w-4 shrink-0 rounded-sm object-contain"
                        title="Emblem"
                      />
                    )}
                    <span className="truncate">
                      {player.username}
                      {player.user_id === myUserId ? " (Ty)" : ""}
                    </span>
                    {player.isBot && <span className="ml-1 shrink-0 text-[10px] font-medium uppercase tracking-widest text-muted-foreground" title="Bot AI">BOT</span>}
                  </div>
                </div>
                <div className="text-right font-display text-xs sm:text-sm tabular-nums text-muted-foreground">
                  {player.regionCount}r · {player.unitCount}u
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
});


const CompactStat = memo(function CompactStat({
  icon, label, value,
}: { icon: string | ReactNode; label: string; value: number }) {
  return (
    <div className="min-w-0 rounded-2xl border border-border bg-card sm:bg-card/80 px-2 py-1.5 shadow-lg sm:backdrop-blur-xl">
      <div className="flex items-center gap-1.5 text-[10px] sm:text-xs uppercase tracking-[0.12em] text-muted-foreground">
        {typeof icon === "string" ? (
          <Image src={icon} alt="" width={14} height={14} className="h-3.5 w-3.5 object-contain" />
        ) : icon}
        <span className="truncate">{label}</span>
      </div>
      <div className="mt-1 truncate font-display text-base font-bold leading-none text-foreground sm:text-xl">{value}</div>
    </div>
  );
});
