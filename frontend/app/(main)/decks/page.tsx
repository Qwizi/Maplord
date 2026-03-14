"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Layers,
  Plus,
  Pencil,
  Trash2,
  Star,
  StarOff,
  Check,
  X,
  Minus,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/hooks/useAuth";
import {
  getMyDecks,
  createDeck,
  updateDeck,
  deleteDeck,
  setDefaultDeck,
  getMyInventory,
  type DeckOut,
  type InventoryItemOut,
} from "@/lib/api";

const SECTION_CONFIG = [
  { type: "tactical_package", label: "Pakiety taktyczne", icon: "⚡", color: "text-cyan-300" },
  { type: "blueprint_building", label: "Budynki", icon: "🏗️", color: "text-amber-300" },
  { type: "blueprint_unit", label: "Jednostki", icon: "⚔️", color: "text-blue-300" },
  { type: "boost", label: "Bonusy", icon: "🚀", color: "text-emerald-300" },
] as const;

const DECK_ITEM_TYPES: string[] = SECTION_CONFIG.map((s) => s.type);

const RARITY_COLORS: Record<string, string> = {
  common: "border-slate-500/30 text-slate-300",
  uncommon: "border-green-500/30 text-green-300",
  rare: "border-blue-500/30 text-blue-300",
  epic: "border-purple-500/30 text-purple-300",
  legendary: "border-amber-500/30 text-amber-300",
};

const RARITY_BG: Record<string, string> = {
  common: "bg-slate-500/10",
  uncommon: "bg-green-500/10",
  rare: "bg-blue-500/10",
  epic: "bg-purple-500/10",
  legendary: "bg-amber-500/10",
};

interface DeckItemEdit {
  item_slug: string;
  item_name: string;
  item_type: string;
  rarity: string;
  level: number;
  quantity: number;
  max_quantity: number;
}

export default function DecksPage() {
  const { user, loading: authLoading, token } = useAuth();
  const router = useRouter();

  const [decks, setDecks] = useState<DeckOut[]>([]);
  const [inventory, setInventory] = useState<InventoryItemOut[]>([]);
  const [loading, setLoading] = useState(true);

  // Create form
  const [creating, setCreating] = useState(false);
  const [newDeckName, setNewDeckName] = useState("");
  const [saving, setSaving] = useState(false);

  // Edit state: deckId -> edit data
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [editItems, setEditItems] = useState<DeckItemEdit[]>([]);

  useEffect(() => {
    if (!authLoading && !user) router.replace("/login");
  }, [user, authLoading, router]);

  const loadData = useCallback(async () => {
    if (!token) return;
    try {
      const [decksRes, invRes] = await Promise.all([
        getMyDecks(token),
        getMyInventory(token),
      ]);
      setDecks(decksRes.items);
      setInventory(invRes.items.filter((i) => DECK_ITEM_TYPES.includes(i.item.item_type)));
    } catch {
      toast.error("Nie udało się załadować talii");
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleCreate = async () => {
    if (!token || !newDeckName.trim()) return;
    setSaving(true);
    try {
      await createDeck(token, { name: newDeckName.trim() });
      toast.success("Talia utworzona");
      setNewDeckName("");
      setCreating(false);
      await loadData();
    } catch {
      toast.error("Nie udało się utworzyć talii");
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (deckId: string) => {
    if (!token) return;
    try {
      await deleteDeck(token, deckId);
      toast.success("Talia usunięta");
      await loadData();
    } catch {
      toast.error("Nie udało się usunąć talii");
    }
  };

  const handleSetDefault = async (deckId: string) => {
    if (!token) return;
    try {
      await setDefaultDeck(token, deckId);
      toast.success("Domyślna talia ustawiona");
      await loadData();
    } catch {
      toast.error("Nie udało się ustawić domyślnej talii");
    }
  };

  const startEdit = (deck: DeckOut) => {
    setEditingId(deck.id);
    setEditName(deck.name);

    // Build edit items list: start with items already in the deck
    const items: DeckItemEdit[] = deck.items.map((di) => {
      const invEntry = inventory.find((i) => i.item.slug === di.item.slug);
      return {
        item_slug: di.item.slug,
        item_name: di.item.name,
        item_type: di.item.item_type,
        rarity: di.item.rarity,
        level: di.item.level ?? 1,
        quantity: di.quantity,
        max_quantity: invEntry ? invEntry.quantity + di.quantity : di.quantity,
      };
    });

    // Add inventory items not yet in the deck
    for (const inv of inventory) {
      if (!items.find((i) => i.item_slug === inv.item.slug)) {
        items.push({
          item_slug: inv.item.slug,
          item_name: inv.item.name,
          item_type: inv.item.item_type,
          rarity: inv.item.rarity,
          level: inv.item.level ?? 1,
          quantity: 0,
          max_quantity: inv.quantity,
        });
      }
    }

    setEditItems(items);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setEditItems([]);
  };

  const adjustQuantity = (slug: string, delta: number) => {
    setEditItems((prev) =>
      prev.map((item) => {
        if (item.item_slug !== slug) return item;
        const next = Math.max(0, Math.min(item.max_quantity, item.quantity + delta));
        return { ...item, quantity: next };
      })
    );
  };

  const saveEdit = async () => {
    if (!token || !editingId) return;
    setSaving(true);
    try {
      await updateDeck(token, editingId, {
        name: editName.trim() || undefined,
        items: editItems
          .filter((i) => i.quantity > 0)
          .map((i) => ({ item_slug: i.item_slug, quantity: i.quantity })),
      });
      toast.success("Talia zaktualizowana");
      cancelEdit();
      await loadData();
    } catch {
      toast.error("Nie udało się zapisać talii");
    } finally {
      setSaving(false);
    }
  };

  // Group edit items by section type
  const groupedEditItems = DECK_ITEM_TYPES.reduce<Record<string, DeckItemEdit[]>>(
    (acc, type) => {
      acc[type] = editItems.filter((i) => i.item_type === type);
      return acc;
    },
    {}
  );

  function levelBadgeClass(level: number): string {
    if (level >= 3) return "text-amber-300";
    if (level === 2) return "text-cyan-300";
    return "text-zinc-400";
  }

  if (authLoading || !user) return null;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04]">
            <Layers className="h-5 w-5 text-amber-300" />
          </div>
          <div>
            <h1 className="font-display text-2xl text-zinc-50">Talie</h1>
            <p className="text-sm text-slate-400">Zarządzaj swoimi taliami kart</p>
          </div>
        </div>
        {!creating && (
          <Button
            onClick={() => setCreating(true)}
            className="gap-2 rounded-full bg-amber-500/20 text-amber-200 hover:bg-amber-500/30 border border-amber-400/20"
          >
            <Plus className="h-4 w-4" />
            Nowa talia
          </Button>
        )}
      </div>

      {/* Create form */}
      {creating && (
        <div className="rounded-[24px] border border-amber-500/20 bg-amber-500/5 p-5 backdrop-blur-xl">
          <p className="mb-3 text-sm font-medium text-amber-200">Nowa talia</p>
          <div className="flex gap-2">
            <input
              type="text"
              value={newDeckName}
              onChange={(e) => setNewDeckName(e.target.value)}
              placeholder="Nazwa talii..."
              className="flex-1 rounded-xl border border-white/10 bg-white/[0.04] px-3 py-2 text-sm text-zinc-100 placeholder:text-slate-500 focus:border-amber-400/40 focus:outline-none"
              onKeyDown={(e) => e.key === "Enter" && handleCreate()}
            />
            <Button
              size="sm"
              onClick={handleCreate}
              disabled={saving || !newDeckName.trim()}
              className="rounded-xl bg-amber-500/20 text-amber-200 hover:bg-amber-500/30 border border-amber-400/20"
            >
              <Check className="h-4 w-4" />
            </Button>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => { setCreating(false); setNewDeckName(""); }}
              className="rounded-xl text-slate-400"
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
        </div>
      )}

      {/* Decks list */}
      {loading ? (
        <div className="rounded-[24px] border border-white/10 bg-slate-950/55 p-8 text-center backdrop-blur-xl">
          <p className="text-slate-400">Ładowanie...</p>
        </div>
      ) : decks.length === 0 ? (
        <div className="rounded-[24px] border border-white/10 bg-slate-950/55 p-8 text-center backdrop-blur-xl">
          <Layers className="mx-auto mb-3 h-10 w-10 text-slate-600" />
          <p className="text-slate-400">Nie masz żadnych talii. Utwórz pierwszą!</p>
        </div>
      ) : (
        <div className="space-y-4">
          {decks.map((deck) => (
            <div
              key={deck.id}
              className="rounded-[24px] border border-white/10 bg-slate-950/55 p-6 backdrop-blur-xl"
            >
              {editingId === deck.id ? (
                /* --- Edit mode --- */
                <div className="space-y-5">
                  <div className="flex items-center gap-3">
                    <input
                      type="text"
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      className="flex-1 rounded-xl border border-white/10 bg-white/[0.04] px-3 py-2 text-sm font-medium text-zinc-100 placeholder:text-slate-500 focus:border-cyan-400/40 focus:outline-none"
                    />
                    <Button
                      size="sm"
                      onClick={saveEdit}
                      disabled={saving}
                      className="gap-1 rounded-xl bg-cyan-500/20 text-cyan-200 hover:bg-cyan-500/30 border border-cyan-400/20"
                    >
                      <Check className="h-4 w-4" />
                      Zapisz
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={cancelEdit}
                      className="rounded-xl text-slate-400"
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  </div>

                  {/* Item sections */}
                  {SECTION_CONFIG.map((section) => {
                    const group = groupedEditItems[section.type];
                    if (!group || group.length === 0) return null;
                    return (
                      <div key={section.type}>
                        <div className="mb-2 flex items-center gap-2">
                          <span className="text-base leading-none">{section.icon}</span>
                          <p className={`text-xs font-semibold uppercase tracking-wider ${section.color}`}>
                            {section.label}
                          </p>
                          <div className="h-px flex-1 bg-white/5" />
                        </div>
                        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                          {group.map((item) => (
                            <div
                              key={item.item_slug}
                              className={`flex items-center justify-between rounded-xl border p-3 ${
                                item.quantity > 0
                                  ? `${RARITY_COLORS[item.rarity]} ${RARITY_BG[item.rarity]}`
                                  : "border-white/5 bg-white/[0.02] opacity-50"
                              }`}
                            >
                              <div className="min-w-0 flex-1">
                                <p className="truncate text-sm font-medium text-zinc-100">
                                  {item.item_name}{" "}
                                  <span className={`text-xs font-bold ${levelBadgeClass(item.level)}`}>
                                    Lvl {item.level}
                                  </span>
                                </p>
                                <p className="text-xs text-slate-400">
                                  Posiadasz: {item.max_quantity}
                                </p>
                              </div>
                              <div className="flex items-center gap-1 ml-2 shrink-0">
                                <button
                                  onClick={() => adjustQuantity(item.item_slug, -1)}
                                  disabled={item.quantity === 0}
                                  className="flex h-6 w-6 items-center justify-center rounded-lg border border-white/10 bg-white/[0.04] text-slate-300 hover:bg-white/[0.10] disabled:opacity-30"
                                >
                                  <Minus className="h-3 w-3" />
                                </button>
                                <span className="w-5 text-center text-sm font-bold text-zinc-100">
                                  {item.quantity}
                                </span>
                                <button
                                  onClick={() => adjustQuantity(item.item_slug, 1)}
                                  disabled={item.quantity >= item.max_quantity}
                                  className="flex h-6 w-6 items-center justify-center rounded-lg border border-white/10 bg-white/[0.04] text-slate-300 hover:bg-white/[0.10] disabled:opacity-30"
                                >
                                  <Plus className="h-3 w-3" />
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    );
                  })}

                  {inventory.length === 0 && (
                    <p className="text-center text-sm text-slate-500">
                      Brak przedmiotów do dodania w ekwipunku
                    </p>
                  )}
                </div>
              ) : (
                /* --- View mode --- */
                <div>
                  <div className="mb-4 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <h3 className="font-display text-lg text-zinc-50">{deck.name}</h3>
                      {deck.is_default && (
                        <span className="rounded-full border border-amber-400/25 bg-amber-400/10 px-2 py-0.5 text-xs font-medium text-amber-300">
                          Domyślna
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-1.5">
                      {!deck.is_default && (
                        <button
                          onClick={() => handleSetDefault(deck.id)}
                          title="Ustaw jako domyślną"
                          className="flex h-8 w-8 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] text-slate-400 hover:bg-amber-400/10 hover:text-amber-300 transition-colors"
                        >
                          <StarOff className="h-4 w-4" />
                        </button>
                      )}
                      {deck.is_default && (
                        <span
                          title="Domyślna talia"
                          className="flex h-8 w-8 items-center justify-center rounded-xl border border-amber-400/20 bg-amber-400/10 text-amber-300"
                        >
                          <Star className="h-4 w-4" />
                        </span>
                      )}
                      <button
                        onClick={() => startEdit(deck)}
                        title="Edytuj"
                        className="flex h-8 w-8 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] text-slate-400 hover:bg-cyan-400/10 hover:text-cyan-300 transition-colors"
                      >
                        <Pencil className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => handleDelete(deck.id)}
                        title="Usuń"
                        className="flex h-8 w-8 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] text-slate-400 hover:bg-red-400/10 hover:text-red-300 transition-colors"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </div>

                  {deck.items.length === 0 ? (
                    <p className="text-sm text-slate-500">
                      Talia jest pusta — edytuj, aby dodać przedmioty.
                    </p>
                  ) : (
                    <div className="flex flex-wrap gap-2">
                      {deck.items.map((di) => (
                        <span
                          key={di.item.slug}
                          className={`flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium ${RARITY_COLORS[di.item.rarity]} ${RARITY_BG[di.item.rarity]}`}
                        >
                          {di.item.name}
                          <span className={`font-bold ${levelBadgeClass(di.item.level ?? 1)}`}>
                            Lvl {di.item.level ?? 1}
                          </span>
                          <span className="rounded-full bg-white/10 px-1.5 py-0.5 font-bold">
                            x{di.quantity}
                          </span>
                        </span>
                      ))}
                    </div>
                  )}

                  <p className="mt-3 text-xs text-slate-500">
                    {deck.items.reduce((s, i) => s + i.quantity, 0)} przedmiotów w talii
                  </p>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
