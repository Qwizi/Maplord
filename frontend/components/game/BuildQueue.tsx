"use client";

import type { BuildingQueueItem } from "@/hooks/useGameSocket";
import type { BuildingType } from "@/lib/api";
import { Hammer } from "lucide-react";

interface BuildQueueProps {
  queue: BuildingQueueItem[];
  buildings: BuildingType[];
  myUserId: string;
}

export default function BuildQueue({
  queue,
  buildings,
  myUserId,
}: BuildQueueProps) {
  const myBuilds = queue.filter((b) => b.player_id === myUserId);
  if (myBuilds.length === 0) return null;

  const buildingMap: Record<string, BuildingType> = {};
  for (const b of buildings) {
    buildingMap[b.slug] = b;
  }

  return (
    <div className="absolute bottom-4 left-4 z-20 w-64 space-y-1.5">
      <div className="flex items-center gap-1.5 text-xs font-medium text-amber-400">
        <Hammer className="h-3.5 w-3.5" />
        Budowa ({myBuilds.length})
      </div>
      {myBuilds.map((item, idx) => {
        const config = buildingMap[item.building_type];
        const icon = config?.icon || "🏗️";
        const name = config?.name || item.building_type;
        const total = item.total_ticks || 1;
        const remaining = item.ticks_remaining;
        const progress = Math.max(0, Math.min(1, 1 - remaining / total));
        const percent = Math.round(progress * 100);

        return (
          <div
            key={`${item.region_id}-${idx}`}
            className="overflow-hidden rounded-lg border border-amber-900/50 bg-zinc-900/90 backdrop-blur"
          >
            <div className="flex items-center gap-2 px-3 py-2">
              <span className="text-lg">{icon}</span>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium text-white">
                  {name}
                </div>
                <div className="text-xs text-zinc-400">
                  {remaining > 0
                    ? `${remaining} tur do końca`
                    : "Ukończono!"}
                </div>
              </div>
              <span className="text-xs font-mono font-bold text-amber-400">
                {percent}%
              </span>
            </div>
            {/* Progress bar */}
            <div className="h-1 w-full bg-zinc-800">
              <div
                className="h-full bg-amber-500 transition-all duration-300"
                style={{ width: `${percent}%` }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}
