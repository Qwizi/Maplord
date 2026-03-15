"use client";

import { useAuth } from "@/hooks/useAuth";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  getMyCustomMaps,
  createCustomMap,
  deleteCustomMap,
  type CustomMapOut,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Map,
  Plus,
  Trash2,
  ChevronRight,
  Loader2,
  Globe,
  CalendarDays,
  Layers,
} from "lucide-react";
import { toast } from "sonner";

export default function MapEditorListPage() {
  const { user, loading: authLoading, token } = useAuth();
  const router = useRouter();

  const [maps, setMaps] = useState<CustomMapOut[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [createName, setCreateName] = useState("");
  const [createDesc, setCreateDesc] = useState("");
  const [creating, setCreating] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  useEffect(() => {
    if (!authLoading && !user) router.replace("/login");
  }, [user, authLoading, router]);

  useEffect(() => {
    if (!token) return;
    setLoading(true);
    getMyCustomMaps(token)
      .then(setMaps)
      .catch(() => toast.error("Failed to load maps"))
      .finally(() => setLoading(false));
  }, [token]);

  const handleCreate = async () => {
    if (!token || !createName.trim()) return;
    setCreating(true);
    try {
      const newMap = await createCustomMap(token, {
        name: createName.trim(),
        description: createDesc.trim() || undefined,
      });
      setMaps((prev) => [newMap, ...prev]);
      setShowCreateForm(false);
      setCreateName("");
      setCreateDesc("");
      toast.success(`Map "${newMap.name}" created`);
      router.push(`/map-editor/${newMap.id}`);
    } catch {
      toast.error("Failed to create map");
    } finally {
      setCreating(false);
    }
  };

  const handleDelete = async (mapId: string) => {
    if (!token) return;
    setDeletingId(mapId);
    try {
      await deleteCustomMap(token, mapId);
      setMaps((prev) => prev.filter((m) => m.id !== mapId));
      setConfirmDeleteId(null);
      toast.success("Map deleted");
    } catch {
      toast.error("Failed to delete map");
    } finally {
      setDeletingId(null);
    }
  };

  if (authLoading || !user) {
    return (
      <div className="flex h-64 items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-end justify-between gap-4">
        <div className="space-y-2">
          <p className="text-xs uppercase tracking-[0.24em] text-muted-foreground font-medium">
            Map Editor
          </p>
          <h1 className="font-display text-4xl sm:text-5xl text-foreground">
            My Maps
          </h1>
        </div>
        <Button
          onClick={() => setShowCreateForm((v) => !v)}
          className="gap-2 rounded-xl"
          variant={showCreateForm ? "outline" : "default"}
        >
          <Plus className="h-4 w-4" />
          New Map
        </Button>
      </div>

      {/* Create form */}
      {showCreateForm && (
        <Card className="rounded-2xl border-primary/30 bg-primary/5">
          <CardContent className="p-6 space-y-4">
            <p className="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
              Create New Map
            </p>
            <div className="space-y-3">
              <Input
                placeholder="Map name"
                value={createName}
                onChange={(e) => setCreateName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleCreate()}
                className="rounded-xl bg-background"
                autoFocus
              />
              <Input
                placeholder="Description (optional)"
                value={createDesc}
                onChange={(e) => setCreateDesc(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleCreate()}
                className="rounded-xl bg-background"
              />
            </div>
            <div className="flex gap-3">
              <Button
                onClick={handleCreate}
                disabled={!createName.trim() || creating}
                className="gap-2 rounded-xl"
              >
                {creating ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Map className="h-4 w-4" />
                )}
                Create & Open
              </Button>
              <Button
                variant="ghost"
                onClick={() => {
                  setShowCreateForm(false);
                  setCreateName("");
                  setCreateDesc("");
                }}
                className="rounded-xl"
              >
                Cancel
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Map list */}
      {loading ? (
        <div className="flex h-48 items-center justify-center">
          <Loader2 className="h-7 w-7 animate-spin text-muted-foreground" />
        </div>
      ) : maps.length === 0 ? (
        <Card className="rounded-2xl">
          <CardContent className="flex flex-col items-center gap-4 py-16 text-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-muted">
              <Globe className="h-8 w-8 text-muted-foreground" />
            </div>
            <div className="space-y-1">
              <p className="text-lg font-semibold text-foreground">No maps yet</p>
              <p className="text-sm text-muted-foreground">
                Create your first custom map to get started
              </p>
            </div>
            <Button
              onClick={() => setShowCreateForm(true)}
              className="gap-2 rounded-xl mt-2"
            >
              <Plus className="h-4 w-4" />
              Create Map
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {maps.map((map) => (
            <Card
              key={map.id}
              className="group relative rounded-2xl cursor-pointer transition-all hover:border-primary/40 hover:bg-muted/30"
              onClick={() => {
                if (confirmDeleteId === map.id) return;
                router.push(`/map-editor/${map.id}`);
              }}
            >
              <CardContent className="p-5 space-y-4">
                {/* Header row */}
                <div className="flex items-start justify-between gap-2">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="font-semibold text-foreground truncate text-base leading-tight">
                        {map.name}
                      </h3>
                      {map.is_published && (
                        <Badge className="shrink-0 text-xs bg-accent/15 text-accent border-accent/30 hover:bg-accent/15">
                          Published
                        </Badge>
                      )}
                    </div>
                    {map.description && (
                      <p className="text-sm text-muted-foreground line-clamp-2 leading-snug">
                        {map.description}
                      </p>
                    )}
                  </div>
                  <ChevronRight className="h-5 w-5 text-muted-foreground shrink-0 mt-0.5 transition-transform group-hover:translate-x-0.5" />
                </div>

                {/* Stats row */}
                <div className="flex items-center gap-4 text-sm text-muted-foreground">
                  <span className="flex items-center gap-1.5">
                    <Layers className="h-3.5 w-3.5" />
                    {map.province_count}{" "}
                    {map.province_count === 1 ? "province" : "provinces"}
                  </span>
                  <span className="flex items-center gap-1.5">
                    <CalendarDays className="h-3.5 w-3.5" />
                    {new Date(map.updated_at).toLocaleDateString("en-GB", {
                      day: "numeric",
                      month: "short",
                      year: "numeric",
                    })}
                  </span>
                </div>

                {/* Delete */}
                {confirmDeleteId === map.id ? (
                  <div
                    className="flex items-center gap-2 pt-1"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <span className="text-sm text-destructive font-medium">
                      Delete this map?
                    </span>
                    <Button
                      size="sm"
                      variant="destructive"
                      className="h-7 rounded-lg text-xs"
                      disabled={deletingId === map.id}
                      onClick={() => handleDelete(map.id)}
                    >
                      {deletingId === map.id ? (
                        <Loader2 className="h-3 w-3 animate-spin" />
                      ) : (
                        "Confirm"
                      )}
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      className="h-7 rounded-lg text-xs"
                      onClick={() => setConfirmDeleteId(null)}
                    >
                      Cancel
                    </Button>
                  </div>
                ) : (
                  <div className="flex justify-end">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setConfirmDeleteId(map.id);
                      }}
                      className="flex items-center gap-1 text-xs text-muted-foreground hover:text-destructive transition-colors opacity-0 group-hover:opacity-100"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                      Delete
                    </button>
                  </div>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
