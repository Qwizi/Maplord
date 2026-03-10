"use client";

import { useEffect, useRef, useCallback, useMemo, useState } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import type { GeoJSON } from "@/lib/api";
import type { GameRegion } from "@/hooks/useGameSocket";

// ── Types ────────────────────────────────────────────────────

export interface TroopAnimation {
  id: string;
  sourceId: string;
  targetId: string;
  color: string;
  units: number;
  type: "attack" | "move";
  startTime: number;
}

interface InternalAnim {
  id: string;
  path: [number, number][];
  color: string;
  units: number;
  startTime: number;
  duration: number;
}

interface GameMapProps {
  geojson: GeoJSON | null;
  regions: Record<string, GameRegion>;
  players: Record<string, { color: string; username: string }>;
  selectedRegion: string | null;
  targetRegion: string | null;
  highlightedNeighbors: string[];
  onRegionClick: (regionId: string) => void;
  myUserId: string;
  animations: TroopAnimation[];
  buildingIcons: Record<string, string>;
}

// ── Constants ────────────────────────────────────────────────

const DEFAULT_COLOR = "#374151";
const CAPITAL_OUTLINE = "#fbbf24";
const SELECTED_COLOR = "#3b82f6";
const TARGET_ENEMY = "#ef4444";
const TARGET_FRIENDLY = "#60a5fa";
export const ANIMATION_DURATION_MS = 2200;
const NUM_TRAIL_DOTS = 8;
const DOT_SPACING = 0.055;

// ── Geometry helpers ─────────────────────────────────────────

function computeCentroid(geometry: Record<string, unknown>): [number, number] {
  const coords: number[][] = [];
  const extract = (g: Record<string, unknown>) => {
    if (g.type === "Polygon") {
      coords.push(...(g.coordinates as number[][][])[0]);
    } else if (g.type === "MultiPolygon") {
      for (const poly of g.coordinates as number[][][][]) {
        coords.push(...poly[0]);
      }
    }
  };
  extract(geometry);
  if (coords.length === 0) return [0, 0];
  return [
    coords.reduce((s, c) => s + c[0], 0) / coords.length,
    coords.reduce((s, c) => s + c[1], 0) / coords.length,
  ];
}

function computeArc(
  from: [number, number],
  to: [number, number],
  n = 40
): [number, number][] {
  const dx = to[0] - from[0];
  const dy = to[1] - from[1];
  const dist = Math.sqrt(dx * dx + dy * dy);
  if (dist < 0.001) return [from, to];

  const mx = (from[0] + to[0]) / 2;
  const my = (from[1] + to[1]) / 2;
  const offset = dist * 0.15;
  const nx = -dy / dist;
  const ny = dx / dist;
  const cpx = mx + nx * offset;
  const cpy = my + ny * offset;

  const pts: [number, number][] = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const u = 1 - t;
    pts.push([
      u * u * from[0] + 2 * u * t * cpx + t * t * to[0],
      u * u * from[1] + 2 * u * t * cpy + t * t * to[1],
    ]);
  }
  return pts;
}

const EMPTY_FC = { type: "FeatureCollection" as const, features: [] as unknown[] };

// ── Component ────────────────────────────────────────────────

export default function GameMap({
  geojson,
  regions,
  players,
  selectedRegion,
  targetRegion,
  highlightedNeighbors,
  onRegionClick,
  myUserId,
  animations,
  buildingIcons,
}: GameMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const hoveredRef = useRef<string | null>(null);
  const onRegionClickRef = useRef(onRegionClick);
  onRegionClickRef.current = onRegionClick;
  const animsRef = useRef<InternalAnim[]>([]);
  const rafRef = useRef(0);
  const [layersReady, setLayersReady] = useState(false);

  // Precompute centroids
  const centroids = useMemo(() => {
    if (!geojson) return {} as Record<string, [number, number]>;
    const map: Record<string, [number, number]> = {};
    for (const f of geojson.features) {
      map[f.properties.id] = computeCentroid(
        f.geometry as unknown as Record<string, unknown>
      );
    }
    return map;
  }, [geojson]);

  const getRegionColor = useCallback(
    (regionId: string): string => {
      const r = regions[regionId];
      if (!r?.owner_id) return DEFAULT_COLOR;
      return players[r.owner_id]?.color || DEFAULT_COLOR;
    },
    [regions, players]
  );

  // ── Init map (once) ──────────────────────────────────────

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: {
        version: 8,
        sources: {},
        layers: [
          {
            id: "background",
            type: "background",
            paint: { "background-color": "#0f172a" },
          },
        ],
      },
      center: [15, 51],
      zoom: 4,
      maxZoom: 8,
      minZoom: 2,
    });
    map.addControl(new maplibregl.NavigationControl(), "top-right");
    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // ── Add sources & layers ─────────────────────────────────

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !geojson) return;

    const setup = () => {
      if (map.getSource("regions")) {
        (map.getSource("regions") as maplibregl.GeoJSONSource).setData(
          geojson as unknown as GeoJSON.FeatureCollection
        );
        return;
      }

      // --- Region source ---
      map.addSource("regions", {
        type: "geojson",
        data: geojson as unknown as GeoJSON.FeatureCollection,
        promoteId: "id",
      });

      // --- Animation sources ---
      map.addSource("anim-lines", {
        type: "geojson",
        data: EMPTY_FC as unknown as GeoJSON.FeatureCollection,
      });
      map.addSource("anim-dots", {
        type: "geojson",
        data: EMPTY_FC as unknown as GeoJSON.FeatureCollection,
      });

      // 1. Region fill
      map.addLayer({
        id: "regions-fill",
        type: "fill",
        source: "regions",
        paint: { "fill-color": DEFAULT_COLOR, "fill-opacity": 0.7 },
      });

      // 2. Region border
      map.addLayer({
        id: "regions-border",
        type: "line",
        source: "regions",
        paint: { "line-color": "#1e293b", "line-width": 1 },
      });

      // 3. Neighbor highlight (valid targets)
      map.addLayer({
        id: "regions-neighbor-glow",
        type: "line",
        source: "regions",
        paint: {
          "line-color": TARGET_ENEMY,
          "line-width": 2.5,
          "line-dasharray": [4, 3],
        },
        filter: ["==", ["get", "id"], ""],
      });

      // 4. Selected source border
      map.addLayer({
        id: "regions-selected",
        type: "line",
        source: "regions",
        paint: {
          "line-color": SELECTED_COLOR,
          "line-width": 3,
        },
        filter: ["==", ["get", "id"], ""],
      });

      // 5. Capital outline
      map.addLayer({
        id: "regions-capital",
        type: "line",
        source: "regions",
        paint: { "line-color": CAPITAL_OUTLINE, "line-width": 3 },
        filter: ["==", ["get", "id"], ""],
      });

      // 6. Animation lines (troop paths)
      map.addLayer({
        id: "anim-lines",
        type: "line",
        source: "anim-lines",
        paint: {
          "line-color": ["get", "color"],
          "line-width": 2,
          "line-opacity": ["get", "opacity"],
          "line-dasharray": [4, 3],
        },
      });

      // 7. Animation dots (troop markers)
      map.addLayer({
        id: "anim-dots",
        type: "circle",
        source: "anim-dots",
        paint: {
          "circle-radius": ["get", "size"],
          "circle-color": ["get", "color"],
          "circle-opacity": ["get", "opacity"],
          "circle-stroke-width": 1.5,
          "circle-stroke-color": "#000",
          "circle-stroke-opacity": ["get", "opacity"],
        },
      });

      // 8. Animation labels (unit counts on lead dot)
      map.addLayer({
        id: "anim-labels",
        type: "symbol",
        source: "anim-dots",
        filter: [">", ["get", "units"], 0],
        layout: {
          "text-field": ["concat", ["to-string", ["get", "units"]], " 🪖"],
          "text-size": 12,
          "text-offset": [0, -1.5],
          "text-allow-overlap": true,
        },
        paint: {
          "text-color": "#ffffff",
          "text-halo-color": "#000000",
          "text-halo-width": 1,
        },
      });

      // 9. Region unit labels
      map.addLayer({
        id: "regions-labels",
        type: "symbol",
        source: "regions",
        layout: {
          "text-field": "",
          "text-size": 14,
          "text-font": ["Open Sans Bold"],
          "text-allow-overlap": true,
        },
        paint: {
          "text-color": "#ffffff",
          "text-halo-color": "#000000",
          "text-halo-width": 1.5,
        },
      });

      // 10. Building icons (emoji below unit count)
      map.addLayer({
        id: "regions-building-icons",
        type: "symbol",
        source: "regions",
        layout: {
          "text-field": "",
          "text-size": 20,
          "text-offset": [0, 1],
          "text-allow-overlap": true,
          "text-ignore-placement": true,
        },
        paint: {
          "text-halo-color": "rgba(0,0,0,0.7)",
          "text-halo-width": 2,
        },
      });

      // --- Events ---
      map.on("click", "regions-fill", (e) => {
        const id = e.features?.[0]?.properties?.id;
        if (id) onRegionClickRef.current(id as string);
      });

      map.on("mouseenter", "regions-fill", () => {
        map.getCanvas().style.cursor = "pointer";
      });
      map.on("mouseleave", "regions-fill", () => {
        map.getCanvas().style.cursor = "";
      });

      map.on("mousemove", "regions-fill", (e) => {
        if (e.features?.[0]) {
          const id = e.features[0].properties?.id as string;
          if (hoveredRef.current && hoveredRef.current !== id) {
            map.setFeatureState(
              { source: "regions", id: hoveredRef.current },
              { hover: false }
            );
          }
          hoveredRef.current = id;
          map.setFeatureState({ source: "regions", id }, { hover: true });
        }
      });

      setLayersReady(true);
    };

    if (map.loaded()) setup();
    else map.on("load", setup);
  }, [geojson]);

  // ── Update region styles ─────────────────────────────────

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !geojson || !layersReady || !map.getLayer("regions-fill")) return;

    const colorExpr: unknown[] = ["match", ["get", "id"]];
    const capitalIds: string[] = [];
    const labelExprs: unknown[] = ["match", ["get", "id"]];

    for (const f of geojson.features) {
      const rid = f.properties.id;
      colorExpr.push(rid, getRegionColor(rid));
      const r = regions[rid];
      if (r?.unit_count > 0) labelExprs.push(rid, String(r.unit_count));
      if (r?.is_capital) capitalIds.push(rid);
    }
    colorExpr.push(DEFAULT_COLOR);
    labelExprs.push("");

    try {
      map.setPaintProperty("regions-fill", "fill-color", colorExpr);

      // Opacity: hover > selected > target > default
      const opacityExpr: unknown[] = [
        "case",
        ["boolean", ["feature-state", "hover"], false],
        0.9,
      ];
      if (selectedRegion) {
        opacityExpr.push(["==", ["get", "id"], selectedRegion], 0.95);
      }
      if (targetRegion) {
        opacityExpr.push(["==", ["get", "id"], targetRegion], 0.92);
      }
      opacityExpr.push(0.7);
      map.setPaintProperty("regions-fill", "fill-opacity", opacityExpr);

      // Capital outlines
      map.setFilter(
        "regions-capital",
        capitalIds.length > 0
          ? ["in", ["get", "id"], ["literal", capitalIds]]
          : ["==", ["get", "id"], ""]
      );

      // Selected source outline
      map.setFilter(
        "regions-selected",
        selectedRegion
          ? ["==", ["get", "id"], selectedRegion]
          : ["==", ["get", "id"], ""]
      );

      // Neighbor highlights
      if (highlightedNeighbors.length > 0) {
        map.setFilter("regions-neighbor-glow", [
          "in",
          ["get", "id"],
          ["literal", highlightedNeighbors],
        ]);
        // Color: red for enemy/neutral, blue for friendly
        const nColorExpr: unknown[] = ["match", ["get", "id"]];
        for (const nid of highlightedNeighbors) {
          const r = regions[nid];
          nColorExpr.push(
            nid,
            r?.owner_id === myUserId ? TARGET_FRIENDLY : TARGET_ENEMY
          );
        }
        nColorExpr.push(TARGET_ENEMY);
        map.setPaintProperty("regions-neighbor-glow", "line-color", nColorExpr);
      } else {
        map.setFilter("regions-neighbor-glow", ["==", ["get", "id"], ""]);
      }

      map.setLayoutProperty("regions-labels", "text-field", labelExprs);

      // Building icons
      const buildingExprs: unknown[] = ["match", ["get", "id"]];
      let hasBuildingIcons = false;
      for (const f of geojson.features) {
        const rid = f.properties.id;
        const r = regions[rid];
        if (r?.building_type) {
          const icon = buildingIcons[r.building_type];
          if (icon) {
            buildingExprs.push(rid, icon);
            hasBuildingIcons = true;
          }
        }
      }
      buildingExprs.push("");
      if (hasBuildingIcons) {
        map.setLayoutProperty(
          "regions-building-icons",
          "text-field",
          buildingExprs
        );
      } else {
        map.setLayoutProperty("regions-building-icons", "text-field", "");
      }
    } catch {
      // map not ready
    }
  }, [
    geojson,
    regions,
    players,
    selectedRegion,
    targetRegion,
    highlightedNeighbors,
    myUserId,
    getRegionColor,
    layersReady,
  ]);

  // ── Sync animation props → internal ref ──────────────────

  useEffect(() => {
    const newAnims: InternalAnim[] = [];
    for (const a of animations) {
      if (animsRef.current.some((x) => x.id === a.id)) continue;
      const from = centroids[a.sourceId];
      const to = centroids[a.targetId];
      if (!from || !to) continue;
      newAnims.push({
        id: a.id,
        path: computeArc(from, to),
        color: a.color,
        units: a.units,
        startTime: a.startTime,
        duration: ANIMATION_DURATION_MS,
      });
    }
    if (newAnims.length > 0) {
      animsRef.current = [...animsRef.current, ...newAnims];
    }
  }, [animations, centroids]);

  // ── rAF animation loop ───────────────────────────────────

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const tick = () => {
      if (
        !map.getSource("anim-lines") ||
        !map.getSource("anim-dots")
      ) {
        rafRef.current = requestAnimationFrame(tick);
        return;
      }

      const now = Date.now();
      animsRef.current = animsRef.current.filter(
        (a) => now - a.startTime < a.duration + 400
      );

      const lineFeats: unknown[] = [];
      const dotFeats: unknown[] = [];

      for (const a of animsRef.current) {
        const progress = Math.min((now - a.startTime) / a.duration, 1);
        const fadeOut = progress > 0.85 ? 1 - (progress - 0.85) / 0.15 : 1;

        // Path line
        lineFeats.push({
          type: "Feature",
          geometry: { type: "LineString", coordinates: a.path },
          properties: { color: a.color, opacity: 0.4 * fadeOut },
        });

        // Trail dots
        for (let i = 0; i < NUM_TRAIL_DOTS; i++) {
          const dp = progress - i * DOT_SPACING;
          if (dp < 0 || dp > 1) continue;
          const idx = Math.min(
            Math.floor(dp * (a.path.length - 1)),
            a.path.length - 1
          );
          dotFeats.push({
            type: "Feature",
            geometry: { type: "Point", coordinates: a.path[idx] },
            properties: {
              color: a.color,
              units: i === 0 ? a.units : 0,
              opacity: (1 - (i / NUM_TRAIL_DOTS) * 0.7) * fadeOut,
              size: i === 0 ? 8 : 5 - i * 0.3,
            },
          });
        }
      }

      try {
        (map.getSource("anim-lines") as maplibregl.GeoJSONSource).setData({
          type: "FeatureCollection",
          features: lineFeats,
        } as unknown as GeoJSON.FeatureCollection);
        (map.getSource("anim-dots") as maplibregl.GeoJSONSource).setData({
          type: "FeatureCollection",
          features: dotFeats,
        } as unknown as GeoJSON.FeatureCollection);
      } catch {
        // source not ready
      }

      rafRef.current = requestAnimationFrame(tick);
    };

    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, []);

  return <div ref={containerRef} className="h-full w-full" />;
}
