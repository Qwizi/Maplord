"use client";

import type { GameRegion, GamePlayer } from "@/hooks/useGameSocket";
import type { BuildingType } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Swords, ArrowRight, Hammer, Shield, Crown } from "lucide-react";
import { useState } from "react";

interface RegionPanelProps {
  regionId: string;
  region: GameRegion;
  players: Record<string, GamePlayer>;
  myUserId: string;
  neighborIds: string[];
  regions: Record<string, GameRegion>;
  buildings: BuildingType[];
  onAttack: (targetId: string, units: number) => void;
  onMove: (targetId: string, units: number) => void;
  onBuild: (buildingType: string) => void;
  onClose: () => void;
}

export default function RegionPanel({
  regionId,
  region,
  players,
  myUserId,
  neighborIds,
  regions,
  buildings,
  onAttack,
  onMove,
  onBuild,
  onClose,
}: RegionPanelProps) {
  const [units, setUnits] = useState(1);
  const isOwned = region.owner_id === myUserId;
  const owner = region.owner_id ? players[region.owner_id] : null;

  const ownedNeighbors = neighborIds.filter(
    (nid) => regions[nid]?.owner_id === myUserId
  );
  const enemyNeighbors = neighborIds.filter(
    (nid) => regions[nid]?.owner_id && regions[nid]?.owner_id !== myUserId
  );
  const emptyNeighbors = neighborIds.filter(
    (nid) => !regions[nid]?.owner_id
  );

  return (
    <div className="absolute right-0 top-0 z-10 h-full w-80 overflow-y-auto border-l border-zinc-800 bg-zinc-900/95 p-4 backdrop-blur">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-bold">{region.name}</h3>
        <button
          onClick={onClose}
          className="rounded p-1 text-zinc-400 hover:bg-zinc-800 hover:text-white"
        >
          ✕
        </button>
      </div>

      <p className="text-sm text-zinc-400">{region.country_code}</p>

      <div className="mt-3 space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-zinc-400">Właściciel</span>
          {owner ? (
            <Badge style={{ backgroundColor: owner.color }}>
              {owner.username}
            </Badge>
          ) : (
            <span className="text-zinc-500">Brak</span>
          )}
        </div>

        <div className="flex items-center justify-between">
          <span className="text-zinc-400">Jednostki</span>
          <span className="text-xl font-bold">{region.unit_count}</span>
        </div>

        {region.is_capital && (
          <div className="flex items-center gap-1 text-yellow-400">
            <Crown className="h-4 w-4" />
            <span className="text-sm font-medium">Stolica</span>
          </div>
        )}

        {region.building_type && (
          <div className="flex items-center justify-between">
            <span className="text-zinc-400">Budynek</span>
            <Badge variant="secondary">{region.building_type}</Badge>
          </div>
        )}

        {region.defense_bonus > 0 && (
          <div className="flex items-center justify-between">
            <span className="text-zinc-400">Bonus obrony</span>
            <span className="flex items-center gap-1 text-green-400">
              <Shield className="h-3 w-3" />+
              {Math.round(region.defense_bonus * 100)}%
            </span>
          </div>
        )}
      </div>

      {isOwned && region.unit_count > 0 && (
        <>
          <Separator className="my-4 bg-zinc-800" />

          {/* Units slider */}
          <div className="space-y-2">
            <label className="text-sm text-zinc-400">
              Jednostki: {units} / {region.unit_count}
            </label>
            <input
              type="range"
              min={1}
              max={region.unit_count}
              value={units}
              onChange={(e) => setUnits(Number(e.target.value))}
              className="w-full accent-blue-500"
            />
          </div>

          {/* Attack targets */}
          {(enemyNeighbors.length > 0 || emptyNeighbors.length > 0) && (
            <div className="mt-3 space-y-1">
              <h4 className="flex items-center gap-1 text-sm font-medium text-red-400">
                <Swords className="h-3 w-3" /> Atakuj
              </h4>
              {[...enemyNeighbors, ...emptyNeighbors].map((nid) => {
                const n = regions[nid];
                if (!n) return null;
                const nOwner = n.owner_id ? players[n.owner_id] : null;
                return (
                  <button
                    key={nid}
                    onClick={() => onAttack(nid, units)}
                    className="flex w-full items-center justify-between rounded bg-red-950/50 px-2 py-1.5 text-sm hover:bg-red-900/50"
                  >
                    <span>
                      {n.name}{" "}
                      {nOwner && (
                        <span style={{ color: nOwner.color }}>
                          ({nOwner.username})
                        </span>
                      )}
                    </span>
                    <span className="text-zinc-400">{n.unit_count}🪖</span>
                  </button>
                );
              })}
            </div>
          )}

          {/* Move targets */}
          {ownedNeighbors.length > 0 && (
            <div className="mt-3 space-y-1">
              <h4 className="flex items-center gap-1 text-sm font-medium text-blue-400">
                <ArrowRight className="h-3 w-3" /> Przenieś
              </h4>
              {ownedNeighbors.map((nid) => {
                const n = regions[nid];
                if (!n) return null;
                return (
                  <button
                    key={nid}
                    onClick={() => onMove(nid, units)}
                    className="flex w-full items-center justify-between rounded bg-blue-950/50 px-2 py-1.5 text-sm hover:bg-blue-900/50"
                  >
                    <span>{n.name}</span>
                    <span className="text-zinc-400">{n.unit_count}🪖</span>
                  </button>
                );
              })}
            </div>
          )}
        </>
      )}

      {/* Build */}
      {isOwned && !region.building_type && (
        <>
          <Separator className="my-4 bg-zinc-800" />
          <h4 className="flex items-center gap-1 text-sm font-medium text-amber-400">
            <Hammer className="h-3 w-3" /> Buduj
          </h4>
          <div className="mt-1 space-y-1">
            {buildings
              .filter((b) => !b.requires_coastal || region.is_capital)
              .map((b) => (
                <button
                  key={b.id}
                  onClick={() => onBuild(b.slug)}
                  disabled={region.unit_count < b.cost}
                  className="flex w-full items-center justify-between rounded bg-amber-950/50 px-2 py-1.5 text-sm hover:bg-amber-900/50 disabled:opacity-40"
                >
                  <span>
                    {b.icon} {b.name}
                  </span>
                  <span className="text-zinc-400">{b.cost}🪖</span>
                </button>
              ))}
          </div>
        </>
      )}
    </div>
  );
}
