"use client";

import { useAuth } from "@/hooks/useAuth";
import { useRouter, useParams } from "next/navigation";
import { useEffect, useRef, useState, useCallback } from "react";
import {
  getCustomMap,
  updateCustomMap,
  createProvince,
  updateProvince,
  deleteProvince,
  type CustomMapDetail,
  type CustomProvinceOut,
  type GeoJSONGeometry,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  ArrowLeft,
  PenLine,
  MousePointer2,
  Trash2,
  ChevronLeft,
  ChevronRight,
  Loader2,
  Check,
  X,
  Eye,
  EyeOff,
  Layers,
} from "lucide-react";
import { toast } from "sonner";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PROVINCE_COLORS = [
  "#ef4444",
  "#f97316",
  "#eab308",
  "#22c55e",
  "#06b6d4",
  "#3b82f6",
  "#8b5cf6",
  "#ec4899",
];

type DrawMode = "select" | "draw" | "delete";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function nextColor(provinces: CustomProvinceOut[]): string {
  const usedColors = new Set(provinces.map((p) => p.color));
  const fresh = PROVINCE_COLORS.find((c) => !usedColors.has(c));
  if (fresh) return fresh;
  return PROVINCE_COLORS[provinces.length % PROVINCE_COLORS.length];
}

function polygonArea(coords: number[][]): number {
  // Shoelace formula — returns area in square degrees (approximate)
  let area = 0;
  const n = coords.length;
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    area += coords[i][0] * coords[j][1];
    area -= coords[j][0] * coords[i][1];
  }
  return Math.abs(area / 2);
}

// ---------------------------------------------------------------------------
// Province name prompt (inline overlay above map)
// ---------------------------------------------------------------------------

function NamePrompt({
  onConfirm,
  onCancel,
}: {
  onConfirm: (name: string) => void;
  onCancel: () => void;
}) {
  const [value, setValue] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  return (
    <div className="absolute left-1/2 top-6 z-30 -translate-x-1/2">
      <div className="flex items-center gap-2 rounded-2xl border border-border bg-card/95 px-4 py-3 shadow-2xl backdrop-blur">
        <span className="text-sm font-medium text-foreground whitespace-nowrap">
          Province name:
        </span>
        <Input
          ref={inputRef}
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && value.trim()) onConfirm(value.trim());
            if (e.key === "Escape") onCancel();
          }}
          placeholder="e.g. Westmark"
          className="w-44 h-8 rounded-lg"
        />
        <Button
          size="icon-sm"
          disabled={!value.trim()}
          onClick={() => value.trim() && onConfirm(value.trim())}
          className="shrink-0"
        >
          <Check className="h-4 w-4" />
        </Button>
        <Button
          size="icon-sm"
          variant="ghost"
          onClick={onCancel}
          className="shrink-0"
        >
          <X className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function MapEditorPage() {
  const { user, loading: authLoading, token } = useAuth();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const mapId = params.id;

  // Map state
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const [mapReady, setMapReady] = useState(false);

  // Page state
  const [mapDetail, setMapDetail] = useState<CustomMapDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [selectedProvinceId, setSelectedProvinceId] = useState<string | null>(null);
  const [editingNameId, setEditingNameId] = useState<string | null>(null);
  const [editingNameValue, setEditingNameValue] = useState("");
  const [savingNameId, setSavingNameId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  // Map title editing
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleValue, setTitleValue] = useState("");
  const [savingTitle, setSavingTitle] = useState(false);
  const [togglingPublish, setTogglingPublish] = useState(false);

  // Drawing state
  const [drawMode, setDrawMode] = useState<DrawMode>("select");
  const drawModeRef = useRef<DrawMode>("select");
  const [drawingPoints, setDrawingPoints] = useState<number[][]>([]);
  const drawingPointsRef = useRef<number[][]>([]);
  const [mousePos, setMousePos] = useState<number[] | null>(null);
  const mousePosRef = useRef<number[] | null>(null);
  const [showNamePrompt, setShowNamePrompt] = useState(false);
  const pendingGeomRef = useRef<GeoJSONGeometry | null>(null);
  const [savingProvince, setSavingProvince] = useState(false);

  // Keep refs in sync
  useEffect(() => {
    drawModeRef.current = drawMode;
  }, [drawMode]);
  useEffect(() => {
    drawingPointsRef.current = drawingPoints;
  }, [drawingPoints]);
  useEffect(() => {
    mousePosRef.current = mousePos;
  }, [mousePos]);

  // ---------------------------------------------------------------------------
  // Auth guard
  // ---------------------------------------------------------------------------
  useEffect(() => {
    if (!authLoading && !user) router.replace("/login");
  }, [user, authLoading, router]);

  // ---------------------------------------------------------------------------
  // Load map data
  // ---------------------------------------------------------------------------
  useEffect(() => {
    if (!token || !mapId) return;
    setLoading(true);
    getCustomMap(token, mapId)
      .then((data) => {
        setMapDetail(data);
        setTitleValue(data.name);
      })
      .catch(() => toast.error("Failed to load map"))
      .finally(() => setLoading(false));
  }, [token, mapId]);

  // ---------------------------------------------------------------------------
  // Build GeoJSON source data from provinces
  // ---------------------------------------------------------------------------
  const buildGeoJSON = useCallback(
    (provinces: CustomProvinceOut[]): GeoJSON.FeatureCollection => ({
      type: "FeatureCollection",
      features: provinces.map((p) => ({
        type: "Feature",
        id: p.id,
        properties: {
          id: p.id,
          name: p.name,
          color: p.color,
        },
        geometry: p.geometry as GeoJSON.Geometry,
      })),
    }),
    []
  );

  // ---------------------------------------------------------------------------
  // Build draw preview GeoJSON
  // ---------------------------------------------------------------------------
  const buildDrawGeoJSON = useCallback(
    (points: number[][], cursor: number[] | null): GeoJSON.FeatureCollection => {
      const features: GeoJSON.Feature[] = [];

      if (points.length >= 2) {
        const lineCoords = cursor ? [...points, cursor] : [...points];
        features.push({
          type: "Feature",
          properties: {},
          geometry: {
            type: "LineString",
            coordinates: lineCoords,
          },
        });
      }

      if (points.length >= 3 && cursor) {
        // Close line back to first point
        features.push({
          type: "Feature",
          properties: { closing: true },
          geometry: {
            type: "LineString",
            coordinates: [cursor, points[0]],
          },
        });
      }

      // Vertex dots
      points.forEach((pt, i) => {
        features.push({
          type: "Feature",
          properties: { index: i, isFirst: i === 0 },
          geometry: { type: "Point", coordinates: pt },
        });
      });

      return { type: "FeatureCollection", features };
    },
    []
  );

  // ---------------------------------------------------------------------------
  // Update map sources when provinces or drawing changes
  // ---------------------------------------------------------------------------
  const updateProvincesSource = useCallback(
    (provinces: CustomProvinceOut[]) => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded()) return;
      const src = map.getSource("provinces") as maplibregl.GeoJSONSource | undefined;
      if (src) src.setData(buildGeoJSON(provinces));
    },
    [buildGeoJSON]
  );

  const updateDrawSource = useCallback(
    (points: number[][], cursor: number[] | null) => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded()) return;
      const src = map.getSource("draw-preview") as maplibregl.GeoJSONSource | undefined;
      if (src) src.setData(buildDrawGeoJSON(points, cursor));
    },
    [buildDrawGeoJSON]
  );

  // ---------------------------------------------------------------------------
  // Highlight selected province
  // ---------------------------------------------------------------------------
  const updateSelectedHighlight = useCallback(
    (selId: string | null, provinces: CustomProvinceOut[]) => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded()) return;
      const src = map.getSource("selected-province") as maplibregl.GeoJSONSource | undefined;
      if (!src) return;
      if (selId) {
        const prov = provinces.find((p) => p.id === selId);
        if (prov) {
          src.setData({
            type: "FeatureCollection",
            features: [
              {
                type: "Feature",
                properties: {},
                geometry: prov.geometry as GeoJSON.Geometry,
              },
            ],
          });
          return;
        }
      }
      src.setData({ type: "FeatureCollection", features: [] });
    },
    []
  );

  // ---------------------------------------------------------------------------
  // Initialize MapLibre
  // ---------------------------------------------------------------------------
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: mapContainerRef.current,
      style: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json",
      center: [15, 25],
      zoom: 2,
      attributionControl: false,
    });

    map.addControl(new maplibregl.NavigationControl(), "bottom-right");
    map.addControl(
      new maplibregl.AttributionControl({ compact: true }),
      "bottom-left"
    );

    map.on("load", () => {
      // --- Provinces fill layer ---
      map.addSource("provinces", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
      });
      map.addLayer({
        id: "provinces-fill",
        type: "fill",
        source: "provinces",
        paint: {
          "fill-color": ["get", "color"],
          "fill-opacity": 0.35,
        },
      });
      map.addLayer({
        id: "provinces-outline",
        type: "line",
        source: "provinces",
        paint: {
          "line-color": ["get", "color"],
          "line-width": 2,
          "line-opacity": 0.9,
        },
      });
      map.addLayer({
        id: "provinces-label",
        type: "symbol",
        source: "provinces",
        layout: {
          "text-field": ["get", "name"],
          "text-size": 12,
          "text-font": ["Noto Sans Regular"],
          "text-anchor": "center",
        },
        paint: {
          "text-color": "#ffffff",
          "text-halo-color": "#000000",
          "text-halo-width": 1.5,
        },
      });

      // --- Selected province highlight ---
      map.addSource("selected-province", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
      });
      map.addLayer({
        id: "selected-fill",
        type: "fill",
        source: "selected-province",
        paint: {
          "fill-color": "#ffffff",
          "fill-opacity": 0.12,
        },
      });
      map.addLayer({
        id: "selected-outline",
        type: "line",
        source: "selected-province",
        paint: {
          "line-color": "#ffffff",
          "line-width": 3,
          "line-opacity": 1,
          "line-dasharray": [4, 2],
        },
      });

      // --- Draw preview ---
      map.addSource("draw-preview", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
      });
      map.addLayer({
        id: "draw-line",
        type: "line",
        source: "draw-preview",
        paint: {
          "line-color": "#ffffff",
          "line-width": 2,
          "line-opacity": 0.85,
          "line-dasharray": [4, 2],
        },
      });
      map.addLayer({
        id: "draw-vertices",
        type: "circle",
        source: "draw-preview",
        filter: ["==", ["geometry-type"], "Point"],
        paint: {
          "circle-radius": [
            "case",
            ["==", ["get", "isFirst"], true],
            7,
            5,
          ],
          "circle-color": [
            "case",
            ["==", ["get", "isFirst"], true],
            "#22c55e",
            "#ffffff",
          ],
          "circle-stroke-color": "#000000",
          "circle-stroke-width": 1.5,
        },
      });

      setMapReady(true);
    });

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // ---------------------------------------------------------------------------
  // Sync provinces to map when data is loaded or changes
  // ---------------------------------------------------------------------------
  useEffect(() => {
    if (!mapReady || !mapDetail) return;
    updateProvincesSource(mapDetail.provinces);
    updateSelectedHighlight(selectedProvinceId, mapDetail.provinces);
  }, [mapReady, mapDetail, updateProvincesSource, updateSelectedHighlight, selectedProvinceId]);

  // ---------------------------------------------------------------------------
  // Map event handlers (click, mousemove) – re-attach when drawMode changes
  // ---------------------------------------------------------------------------
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !mapReady) return;

    const handleClick = (e: maplibregl.MapMouseEvent) => {
      const mode = drawModeRef.current;
      const pts = drawingPointsRef.current;

      if (mode === "draw") {
        const coord = [e.lngLat.lng, e.lngLat.lat];

        // Check if clicking near first point to close polygon
        if (pts.length >= 3) {
          const firstPt = pts[0];
          const dx = firstPt[0] - coord[0];
          const dy = firstPt[1] - coord[1];
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < 0.5) {
            // Close the polygon
            closeDraw(pts);
            return;
          }
        }

        const newPts = [...pts, coord];
        setDrawingPoints(newPts);
        drawingPointsRef.current = newPts;
        updateDrawSource(newPts, mousePosRef.current);
        return;
      }

      if (mode === "delete") {
        const features = map.queryRenderedFeatures(e.point, {
          layers: ["provinces-fill"],
        });
        if (features.length > 0) {
          const id = features[0].properties?.id as string;
          setConfirmDeleteId(id);
          setSelectedProvinceId(id);
        }
        return;
      }

      // select mode — click on province or deselect
      const features = map.queryRenderedFeatures(e.point, {
        layers: ["provinces-fill"],
      });
      if (features.length > 0) {
        const id = features[0].properties?.id as string;
        setSelectedProvinceId(id);
      } else {
        setSelectedProvinceId(null);
      }
    };

    const handleMouseMove = (e: maplibregl.MapMouseEvent) => {
      if (drawModeRef.current !== "draw") return;
      const cursor: number[] = [e.lngLat.lng, e.lngLat.lat];
      setMousePos(cursor);
      mousePosRef.current = cursor;
      updateDrawSource(drawingPointsRef.current, cursor);
    };

    const handleDblClick = (e: maplibregl.MapMouseEvent) => {
      if (drawModeRef.current !== "draw") return;
      e.preventDefault();
      const pts = drawingPointsRef.current;
      if (pts.length >= 3) closeDraw(pts);
    };

    map.on("click", handleClick);
    map.on("mousemove", handleMouseMove);
    map.on("dblclick", handleDblClick);

    return () => {
      map.off("click", handleClick);
      map.off("mousemove", handleMouseMove);
      map.off("dblclick", handleDblClick);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mapReady, updateDrawSource]);

  // ---------------------------------------------------------------------------
  // Cursor style
  // ---------------------------------------------------------------------------
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    const canvas = map.getCanvas();
    if (drawMode === "draw") canvas.style.cursor = "crosshair";
    else if (drawMode === "delete") canvas.style.cursor = "not-allowed";
    else canvas.style.cursor = "";
  }, [drawMode]);

  // ---------------------------------------------------------------------------
  // Close draw (build geometry, show name prompt)
  // ---------------------------------------------------------------------------
  const closeDraw = (pts: number[][]) => {
    if (pts.length < 3) return;
    const closed = [...pts, pts[0]];
    const geom: GeoJSONGeometry = {
      type: "Polygon",
      coordinates: [closed],
    };
    pendingGeomRef.current = geom;
    setDrawingPoints([]);
    drawingPointsRef.current = [];
    setMousePos(null);
    updateDrawSource([], null);
    setShowNamePrompt(true);
  };

  // ---------------------------------------------------------------------------
  // Cancel draw
  // ---------------------------------------------------------------------------
  const cancelDraw = () => {
    setDrawingPoints([]);
    drawingPointsRef.current = [];
    setMousePos(null);
    updateDrawSource([], null);
    setShowNamePrompt(false);
    pendingGeomRef.current = null;
  };

  // ---------------------------------------------------------------------------
  // Save new province
  // ---------------------------------------------------------------------------
  const handleSaveProvince = async (name: string) => {
    if (!token || !mapDetail || !pendingGeomRef.current) return;
    setShowNamePrompt(false);
    setSavingProvince(true);
    const color = nextColor(mapDetail.provinces);
    try {
      const newProv = await createProvince(token, mapDetail.id, {
        name,
        color,
        geometry: pendingGeomRef.current,
      });
      const updated = {
        ...mapDetail,
        provinces: [...mapDetail.provinces, newProv],
        province_count: mapDetail.province_count + 1,
      };
      setMapDetail(updated);
      setSelectedProvinceId(newProv.id);
      toast.success(`Province "${name}" created`);
    } catch {
      toast.error("Failed to save province");
    } finally {
      setSavingProvince(false);
      pendingGeomRef.current = null;
    }
  };

  // ---------------------------------------------------------------------------
  // Delete province
  // ---------------------------------------------------------------------------
  const handleDeleteProvince = async (provinceId: string) => {
    if (!token || !mapDetail) return;
    setDeletingId(provinceId);
    try {
      await deleteProvince(token, mapDetail.id, provinceId);
      const updated = {
        ...mapDetail,
        provinces: mapDetail.provinces.filter((p) => p.id !== provinceId),
        province_count: mapDetail.province_count - 1,
      };
      setMapDetail(updated);
      if (selectedProvinceId === provinceId) setSelectedProvinceId(null);
      setConfirmDeleteId(null);
      toast.success("Province deleted");
    } catch {
      toast.error("Failed to delete province");
    } finally {
      setDeletingId(null);
    }
  };

  // ---------------------------------------------------------------------------
  // Rename province
  // ---------------------------------------------------------------------------
  const handleRenameProvince = async (provinceId: string, name: string) => {
    if (!token || !mapDetail || !name.trim()) return;
    setSavingNameId(provinceId);
    try {
      const updated = await updateProvince(token, mapDetail.id, provinceId, {
        name: name.trim(),
      });
      setMapDetail({
        ...mapDetail,
        provinces: mapDetail.provinces.map((p) =>
          p.id === provinceId ? updated : p
        ),
      });
      setEditingNameId(null);
      toast.success("Province renamed");
    } catch {
      toast.error("Failed to rename province");
    } finally {
      setSavingNameId(null);
    }
  };

  // ---------------------------------------------------------------------------
  // Zoom to province
  // ---------------------------------------------------------------------------
  const zoomToProvince = useCallback((prov: CustomProvinceOut) => {
    const map = mapRef.current;
    if (!map) return;
    const coords = prov.geometry.coordinates[0];
    const lngs = coords.map((c) => c[0]);
    const lats = coords.map((c) => c[1]);
    const bounds = new maplibregl.LngLatBounds(
      [Math.min(...lngs), Math.min(...lats)],
      [Math.max(...lngs), Math.max(...lats)]
    );
    map.fitBounds(bounds, { padding: 80, duration: 600 });
  }, []);

  // ---------------------------------------------------------------------------
  // Save map title
  // ---------------------------------------------------------------------------
  const handleSaveTitle = async () => {
    if (!token || !mapDetail || !titleValue.trim()) return;
    setSavingTitle(true);
    try {
      const updated = await updateCustomMap(token, mapDetail.id, {
        name: titleValue.trim(),
      });
      setMapDetail({ ...mapDetail, name: updated.name });
      setEditingTitle(false);
      toast.success("Map name updated");
    } catch {
      toast.error("Failed to update map name");
    } finally {
      setSavingTitle(false);
    }
  };

  // ---------------------------------------------------------------------------
  // Toggle publish
  // ---------------------------------------------------------------------------
  const handleTogglePublish = async () => {
    if (!token || !mapDetail) return;
    setTogglingPublish(true);
    try {
      const updated = await updateCustomMap(token, mapDetail.id, {
        is_published: !mapDetail.is_published,
      });
      setMapDetail({ ...mapDetail, is_published: updated.is_published });
      toast.success(
        updated.is_published ? "Map published" : "Map unpublished"
      );
    } catch {
      toast.error("Failed to update publish status");
    } finally {
      setTogglingPublish(false);
    }
  };

  // ---------------------------------------------------------------------------
  // Early returns
  // ---------------------------------------------------------------------------
  if (authLoading || loading) {
    return (
      <div className="flex h-[calc(100vh-3rem)] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (!mapDetail) {
    return (
      <div className="flex h-[calc(100vh-3rem)] items-center justify-center">
        <p className="text-muted-foreground">Map not found.</p>
      </div>
    );
  }

  const selectedProvince = mapDetail.provinces.find(
    (p) => p.id === selectedProvinceId
  ) ?? null;

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------
  return (
    // Negative margin to break out of the (main) layout padding
    <div className="-mx-4 -mt-6 sm:-mx-6 lg:-mx-8 h-[calc(100vh-3rem)] flex flex-col">
      {/* ── Header bar ── */}
      <header className="flex h-12 shrink-0 items-center gap-3 border-b border-border bg-card/90 px-4 backdrop-blur-xl">
        {/* Back */}
        <Button
          size="icon-sm"
          variant="ghost"
          onClick={() => router.push("/map-editor")}
          title="Back to maps"
        >
          <ArrowLeft className="h-4 w-4" />
        </Button>

        {/* Title */}
        <div className="flex flex-1 items-center gap-2 min-w-0">
          {editingTitle ? (
            <div className="flex items-center gap-2">
              <Input
                value={titleValue}
                onChange={(e) => setTitleValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleSaveTitle();
                  if (e.key === "Escape") {
                    setEditingTitle(false);
                    setTitleValue(mapDetail.name);
                  }
                }}
                className="h-7 w-48 rounded-lg text-sm"
                autoFocus
              />
              <Button
                size="icon-sm"
                disabled={savingTitle || !titleValue.trim()}
                onClick={handleSaveTitle}
              >
                {savingTitle ? (
                  <Loader2 className="h-3 w-3 animate-spin" />
                ) : (
                  <Check className="h-3 w-3" />
                )}
              </Button>
              <Button
                size="icon-sm"
                variant="ghost"
                onClick={() => {
                  setEditingTitle(false);
                  setTitleValue(mapDetail.name);
                }}
              >
                <X className="h-3 w-3" />
              </Button>
            </div>
          ) : (
            <button
              className="truncate text-sm font-semibold text-foreground hover:text-primary transition-colors"
              onClick={() => setEditingTitle(true)}
              title="Click to rename"
            >
              {mapDetail.name}
            </button>
          )}
          {mapDetail.is_published && (
            <Badge className="shrink-0 text-xs bg-accent/15 text-accent border-accent/30 hover:bg-accent/15">
              Published
            </Badge>
          )}
        </div>

        {/* Province count */}
        <span className="hidden sm:flex items-center gap-1.5 text-xs text-muted-foreground">
          <Layers className="h-3.5 w-3.5" />
          {mapDetail.province_count}{" "}
          {mapDetail.province_count === 1 ? "province" : "provinces"}
        </span>

        {/* Publish toggle */}
        <Button
          size="sm"
          variant="outline"
          disabled={togglingPublish}
          onClick={handleTogglePublish}
          className="gap-1.5 text-xs"
        >
          {togglingPublish ? (
            <Loader2 className="h-3 w-3 animate-spin" />
          ) : mapDetail.is_published ? (
            <EyeOff className="h-3 w-3" />
          ) : (
            <Eye className="h-3 w-3" />
          )}
          {mapDetail.is_published ? "Unpublish" : "Publish"}
        </Button>
      </header>

      {/* ── Body (toolbar + map + sidebar) ── */}
      <div className="relative flex flex-1 overflow-hidden">

        {/* ── Sidebar ── */}
        <aside
          className={`
            absolute left-0 top-0 z-20 flex h-full flex-col border-r border-border
            bg-card/95 backdrop-blur transition-all duration-200
            ${sidebarOpen ? "w-72" : "w-0 overflow-hidden border-r-0"}
          `}
        >
          <div className="flex h-full flex-col overflow-hidden w-72">
            {/* Sidebar header */}
            <div className="flex h-10 shrink-0 items-center justify-between border-b border-border px-4">
              <span className="text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">
                Provinces
              </span>
              <span className="text-xs text-muted-foreground">
                {mapDetail.provinces.length}
              </span>
            </div>

            {/* Province list */}
            <div className="flex-1 overflow-y-auto">
              {mapDetail.provinces.length === 0 ? (
                <div className="flex flex-col items-center gap-3 py-12 text-center px-4">
                  <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-muted">
                    <PenLine className="h-6 w-6 text-muted-foreground" />
                  </div>
                  <p className="text-sm text-muted-foreground leading-snug">
                    No provinces yet. Select{" "}
                    <span className="font-medium text-foreground">Draw</span>{" "}
                    and click on the map to start.
                  </p>
                </div>
              ) : (
                <ul className="py-1">
                  {mapDetail.provinces.map((prov) => {
                    const isSelected = selectedProvinceId === prov.id;
                    const isConfirmDelete = confirmDeleteId === prov.id;

                    return (
                      <li
                        key={prov.id}
                        className={`
                          group relative border-l-2 transition-all
                          ${isSelected
                            ? "border-l-white/60 bg-white/5"
                            : "border-l-transparent hover:bg-white/[0.03]"
                          }
                        `}
                      >
                        <button
                          className="flex w-full items-center gap-3 px-4 py-2.5 text-left"
                          onClick={() => {
                            setSelectedProvinceId(prov.id);
                            setConfirmDeleteId(null);
                            zoomToProvince(prov);
                          }}
                        >
                          {/* Color swatch */}
                          <span
                            className="h-3 w-3 shrink-0 rounded-full border border-white/20"
                            style={{ backgroundColor: prov.color }}
                          />

                          {/* Name (editable) */}
                          {editingNameId === prov.id ? (
                            <div
                              className="flex flex-1 items-center gap-1.5"
                              onClick={(e) => e.stopPropagation()}
                            >
                              <Input
                                value={editingNameValue}
                                onChange={(e) =>
                                  setEditingNameValue(e.target.value)
                                }
                                onKeyDown={(e) => {
                                  if (e.key === "Enter")
                                    handleRenameProvince(
                                      prov.id,
                                      editingNameValue
                                    );
                                  if (e.key === "Escape")
                                    setEditingNameId(null);
                                }}
                                className="h-6 flex-1 rounded-md text-xs px-2"
                                autoFocus
                              />
                              <button
                                onClick={() =>
                                  handleRenameProvince(prov.id, editingNameValue)
                                }
                                disabled={savingNameId === prov.id}
                                className="text-primary hover:text-primary/80"
                              >
                                {savingNameId === prov.id ? (
                                  <Loader2 className="h-3 w-3 animate-spin" />
                                ) : (
                                  <Check className="h-3 w-3" />
                                )}
                              </button>
                              <button
                                onClick={() => setEditingNameId(null)}
                                className="text-muted-foreground hover:text-foreground"
                              >
                                <X className="h-3 w-3" />
                              </button>
                            </div>
                          ) : (
                            <span className="flex-1 truncate text-sm text-foreground">
                              {prov.name}
                            </span>
                          )}

                          {/* Actions (visible on hover/selected) */}
                          {editingNameId !== prov.id && (
                            <div
                              className={`flex items-center gap-0.5 ${
                                isSelected
                                  ? "opacity-100"
                                  : "opacity-0 group-hover:opacity-100"
                              } transition-opacity`}
                              onClick={(e) => e.stopPropagation()}
                            >
                              <button
                                title="Rename"
                                onClick={() => {
                                  setEditingNameId(prov.id);
                                  setEditingNameValue(prov.name);
                                }}
                                className="flex h-6 w-6 items-center justify-center rounded text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
                              >
                                <PenLine className="h-3 w-3" />
                              </button>
                              <button
                                title="Delete"
                                onClick={() => setConfirmDeleteId(prov.id)}
                                className="flex h-6 w-6 items-center justify-center rounded text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
                              >
                                <Trash2 className="h-3 w-3" />
                              </button>
                            </div>
                          )}
                        </button>

                        {/* Confirm delete */}
                        {isConfirmDelete && (
                          <div className="flex items-center gap-2 border-t border-border/50 px-4 py-2 bg-destructive/5">
                            <span className="flex-1 text-xs text-destructive">
                              Delete &ldquo;{prov.name}&rdquo;?
                            </span>
                            <Button
                              size="xs"
                              variant="destructive"
                              disabled={deletingId === prov.id}
                              onClick={() => handleDeleteProvince(prov.id)}
                              className="gap-1"
                            >
                              {deletingId === prov.id ? (
                                <Loader2 className="h-3 w-3 animate-spin" />
                              ) : (
                                "Delete"
                              )}
                            </Button>
                            <Button
                              size="xs"
                              variant="ghost"
                              onClick={() => setConfirmDeleteId(null)}
                            >
                              Cancel
                            </Button>
                          </div>
                        )}

                        {/* Stats (shown when selected) */}
                        {isSelected && !isConfirmDelete && !editingNameId && (
                          <div className="flex items-center gap-4 px-4 pb-2.5 text-xs text-muted-foreground">
                            <span>
                              {prov.geometry.coordinates[0].length - 1} vertices
                            </span>
                            <span>
                              Area:{" "}
                              {polygonArea(
                                prov.geometry.coordinates[0]
                              ).toFixed(2)}
                              °²
                            </span>
                          </div>
                        )}
                      </li>
                    );
                  })}
                </ul>
              )}
            </div>
          </div>
        </aside>

        {/* ── Sidebar toggle button ── */}
        <button
          onClick={() => setSidebarOpen((v) => !v)}
          className={`
            absolute top-1/2 z-30 flex h-8 w-5 -translate-y-1/2 items-center justify-center
            rounded-r-lg border border-l-0 border-border bg-card/90 text-muted-foreground
            hover:bg-muted hover:text-foreground transition-all duration-200
            ${sidebarOpen ? "left-72" : "left-0"}
          `}
          title={sidebarOpen ? "Collapse sidebar" : "Expand sidebar"}
        >
          {sidebarOpen ? (
            <ChevronLeft className="h-3.5 w-3.5" />
          ) : (
            <ChevronRight className="h-3.5 w-3.5" />
          )}
        </button>

        {/* ── Map container ── */}
        <div
          className={`relative flex-1 transition-all duration-200 ${
            sidebarOpen ? "ml-72" : "ml-0"
          }`}
        >
          {/* Draw toolbar */}
          <div className="absolute left-1/2 top-3 z-20 -translate-x-1/2">
            <div className="flex items-center gap-1 rounded-xl border border-border bg-card/95 p-1 shadow-xl backdrop-blur">
              {(
                [
                  {
                    mode: "select" as DrawMode,
                    icon: MousePointer2,
                    label: "Select",
                  },
                  {
                    mode: "draw" as DrawMode,
                    icon: PenLine,
                    label: "Draw Province",
                  },
                  {
                    mode: "delete" as DrawMode,
                    icon: Trash2,
                    label: "Delete",
                  },
                ] as const
              ).map(({ mode, icon: Icon, label }) => (
                <button
                  key={mode}
                  title={label}
                  onClick={() => {
                    if (drawMode === "draw" && mode !== "draw") cancelDraw();
                    setDrawMode(mode);
                  }}
                  className={`
                    flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium transition-all
                    ${
                      drawMode === mode
                        ? mode === "draw"
                          ? "bg-primary text-primary-foreground"
                          : mode === "delete"
                          ? "bg-destructive/15 text-destructive"
                          : "bg-secondary text-foreground"
                        : "text-muted-foreground hover:bg-muted hover:text-foreground"
                    }
                  `}
                >
                  <Icon className="h-3.5 w-3.5" />
                  <span className="hidden sm:inline">{label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Draw mode hint */}
          {drawMode === "draw" && drawingPoints.length === 0 && !showNamePrompt && (
            <div className="absolute bottom-10 left-1/2 z-20 -translate-x-1/2">
              <div className="rounded-xl border border-border bg-card/90 px-4 py-2 text-xs text-muted-foreground shadow-lg backdrop-blur">
                Click to place vertices. Double-click or click the first point to close.
              </div>
            </div>
          )}

          {/* Draw in progress hint */}
          {drawMode === "draw" && drawingPoints.length > 0 && !showNamePrompt && (
            <div className="absolute bottom-10 left-1/2 z-20 -translate-x-1/2">
              <div className="flex items-center gap-3 rounded-xl border border-border bg-card/90 px-4 py-2 text-xs shadow-lg backdrop-blur">
                <span className="text-foreground">
                  {drawingPoints.length} point{drawingPoints.length !== 1 ? "s" : ""}
                  {drawingPoints.length >= 3
                    ? " — click first point or double-click to close"
                    : " — keep clicking to add more"}
                </span>
                <button
                  onClick={cancelDraw}
                  className="text-muted-foreground hover:text-destructive transition-colors"
                >
                  <X className="h-3.5 w-3.5" />
                </button>
              </div>
            </div>
          )}

          {/* Saving indicator */}
          {savingProvince && (
            <div className="absolute bottom-10 left-1/2 z-20 -translate-x-1/2">
              <div className="flex items-center gap-2 rounded-xl border border-border bg-card/90 px-4 py-2 text-xs shadow-lg backdrop-blur">
                <Loader2 className="h-3.5 w-3.5 animate-spin text-primary" />
                <span className="text-foreground">Saving province...</span>
              </div>
            </div>
          )}

          {/* Name prompt */}
          {showNamePrompt && (
            <NamePrompt
              onConfirm={handleSaveProvince}
              onCancel={cancelDraw}
            />
          )}

          {/* The map */}
          <div ref={mapContainerRef} className="absolute inset-0" />
        </div>
      </div>
    </div>
  );
}
