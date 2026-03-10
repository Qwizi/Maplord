"use client";

import { useState, useRef } from "react";
import { Swords, ArrowRight, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import type { GameRegion } from "@/hooks/useGameSocket";

interface ActionBarProps {
  sourceRegion: GameRegion;
  targetRegion: GameRegion;
  sourceName: string;
  targetName: string;
  isAttack: boolean;
  onConfirm: (units: number) => void;
  onCancel: () => void;
}

export default function ActionBar({
  sourceRegion,
  targetRegion,
  sourceName,
  targetName,
  isAttack,
  onConfirm,
  onCancel,
}: ActionBarProps) {
  // Freeze max units at the moment the bar opens so game ticks don't reset the slider
  const frozenMax = useRef(sourceRegion.unit_count);
  const maxUnits = frozenMax.current;
  const [units, setUnits] = useState(Math.max(1, Math.floor(maxUnits / 2)));

  // Live unit count for display only
  const liveUnits = sourceRegion.unit_count;

  if (maxUnits < 1) return null;

  return (
    <div className="absolute bottom-8 left-1/2 z-30 -translate-x-1/2 animate-in slide-in-from-bottom-4 fade-in duration-200">
      <div
        className={`min-w-[380px] rounded-xl border p-5 shadow-2xl backdrop-blur-md ${
          isAttack
            ? "border-red-800/60 bg-red-950/90"
            : "border-blue-800/60 bg-blue-950/90"
        }`}
      >
        {/* Header */}
        <div className="mb-4 flex items-center gap-3">
          {isAttack ? (
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-red-900/80">
              <Swords className="h-4 w-4 text-red-400" />
            </div>
          ) : (
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-900/80">
              <ArrowRight className="h-4 w-4 text-blue-400" />
            </div>
          )}
          <div className="flex items-center gap-2 text-sm">
            <span className="font-bold text-white">{sourceName}</span>
            <span
              className={`text-xs ${isAttack ? "text-red-400" : "text-blue-400"}`}
            >
              ({liveUnits}🪖)
            </span>
            <span className="text-zinc-500">→</span>
            <span className="font-bold text-white">{targetName}</span>
            <span className="text-xs text-zinc-400">
              ({targetRegion.unit_count}🪖)
            </span>
          </div>
          <button
            onClick={onCancel}
            className="ml-auto rounded p-1 text-zinc-400 hover:bg-zinc-800 hover:text-white"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Unit slider */}
        <div className="mb-4">
          <div className="mb-1 flex items-center justify-between text-sm">
            <span className="text-zinc-400">Jednostki</span>
            <span className="font-mono text-lg font-bold text-white">
              {units}
            </span>
          </div>
          <input
            type="range"
            min={1}
            max={maxUnits}
            value={units}
            onChange={(e) => setUnits(Number(e.target.value))}
            className={`w-full ${isAttack ? "accent-red-500" : "accent-blue-500"}`}
          />
          <div className="mt-0.5 flex justify-between text-xs text-zinc-500">
            <span>1</span>
            <span>{maxUnits}</span>
          </div>
        </div>

        {/* Buttons */}
        <div className="flex gap-2">
          <Button
            onClick={() => onConfirm(units)}
            className={`flex-1 font-semibold ${
              isAttack
                ? "bg-red-600 text-white hover:bg-red-500"
                : "bg-blue-600 text-white hover:bg-blue-500"
            }`}
          >
            {isAttack ? (
              <>
                <Swords className="mr-2 h-4 w-4" /> Atakuj
              </>
            ) : (
              <>
                <ArrowRight className="mr-2 h-4 w-4" /> Przenieś
              </>
            )}
          </Button>
          <Button
            variant="outline"
            onClick={onCancel}
            className="border-zinc-700 text-zinc-300"
          >
            Anuluj
          </Button>
        </div>
      </div>
    </div>
  );
}
