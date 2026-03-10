"use client";

import type { GamePlayer, GameEvent } from "@/hooks/useGameSocket";
import { Badge } from "@/components/ui/badge";
import { Crown, Skull, Swords, Timer, Users } from "lucide-react";

interface GameHUDProps {
  tick: number;
  status: string;
  players: Record<string, GamePlayer>;
  events: GameEvent[];
  myUserId: string;
  myRegionCount: number;
  myUnitCount: number;
}

export default function GameHUD({
  tick,
  status,
  players,
  events,
  myUserId,
  myRegionCount,
  myUnitCount,
}: GameHUDProps) {
  const recentEvents = events.slice(-8).reverse();

  return (
    <div className="absolute left-0 top-0 z-10 flex flex-col gap-2 p-3">
      {/* Status bar */}
      <div className="flex items-center gap-3 rounded-lg bg-zinc-900/90 px-4 py-2 backdrop-blur">
        <div className="flex items-center gap-1.5">
          <Timer className="h-4 w-4 text-zinc-400" />
          <span className="font-mono text-sm">{tick}</span>
        </div>
        <Badge
          variant={status === "in_progress" ? "default" : "secondary"}
        >
          {status === "selecting"
            ? "Wybierz stolicę"
            : status === "in_progress"
              ? "W trakcie"
              : status}
        </Badge>
      </div>

      {/* My stats */}
      <div className="flex items-center gap-3 rounded-lg bg-zinc-900/90 px-4 py-2 backdrop-blur">
        <div className="flex items-center gap-1.5">
          <Crown className="h-4 w-4 text-yellow-400" />
          <span className="text-sm">{myRegionCount} regionów</span>
        </div>
        <div className="flex items-center gap-1.5">
          <Swords className="h-4 w-4 text-red-400" />
          <span className="text-sm">{myUnitCount} jednostek</span>
        </div>
      </div>

      {/* Players */}
      <div className="rounded-lg bg-zinc-900/90 px-4 py-2 backdrop-blur">
        <div className="mb-1 flex items-center gap-1 text-xs text-zinc-400">
          <Users className="h-3 w-3" /> Gracze
        </div>
        {Object.entries(players).map(([pid, player]) => (
          <div
            key={pid}
            className="flex items-center gap-2 text-sm"
          >
            <div
              className="h-3 w-3 rounded-full"
              style={{ backgroundColor: player.color }}
            />
            <span
              className={
                !player.is_alive ? "text-zinc-500 line-through" : ""
              }
            >
              {player.username}
              {pid === myUserId && " (Ty)"}
            </span>
            {!player.is_alive && (
              <Skull className="h-3 w-3 text-red-500" />
            )}
          </div>
        ))}
      </div>

      {/* Event log */}
      {recentEvents.length > 0 && (
        <div className="max-h-48 overflow-y-auto rounded-lg bg-zinc-900/90 px-4 py-2 backdrop-blur">
          <div className="mb-1 text-xs text-zinc-400">Zdarzenia</div>
          {recentEvents.map((ev, i) => (
            <div key={i} className="text-xs text-zinc-300">
              {formatEvent(ev, players)}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function formatEvent(
  event: GameEvent,
  players: Record<string, GamePlayer>
): string {
  const getPlayerName = (id: unknown) =>
    typeof id === "string" ? players[id]?.username || "?" : "?";

  switch (event.type) {
    case "attack_success":
      return `⚔️ ${getPlayerName(event.player_id)} przejął ${event.target_region_id}`;
    case "attack_failed":
      return `🛡️ Atak ${getPlayerName(event.player_id)} odparty`;
    case "capital_captured":
      return `👑 ${getPlayerName(event.captured_by)} zdobył stolicę ${getPlayerName(event.lost_by)}!`;
    case "player_eliminated":
      return `💀 ${getPlayerName(event.player_id)} wyeliminowany`;
    case "game_over":
      return `🏆 ${getPlayerName(event.winner_id)} wygrywa!`;
    case "building_complete":
      return `🏗️ ${getPlayerName(event.player_id)} zbudował ${event.building_type}`;
    case "build_started":
      return `🔨 ${getPlayerName(event.player_id)} rozpoczął budowę ${event.building_type}`;
    case "units_moved":
      return `➡️ ${getPlayerName(event.player_id)} przeniósł ${event.units} jednostek`;
    default:
      return `${event.type}`;
  }
}
