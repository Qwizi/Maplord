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

// ─── Constants ────────────────────────────────────────────────────────────────

const SECTION_CONFIG = [
  {
    type: "tactical_package",
    label: "Pakiety Taktyczne",
    icon: "⚡",
    color: "text-cyan-300",
    accentBg: "bg-cyan-500/10",
    accentBorder: "border-cyan-500/20",
    slots: 5,
  },
  {
    type: "blueprint_building",
    label: "Budynki",
    icon: "🏗️",
    color: "text-amber-300",
    accentBg: "bg-amber-500/10",
    accentBorder: "border-amber-500/20",
    slots: 6,
  },
  {
    type: "boost",
    label: "Bonusy",
    icon: "🚀",
    color: "text-emerald-300",
    accentBg: "bg-emerald-500/10",
    accentBorder: "border-emerald-500/20",
    slots: 4,
  },
] as const;

type SectionType = (typeof SECTION_CONFIG)[number]["type"];
const DECK_ITEM_TYPES: string[] = SECTION_CONFIG.map((s) => s.type);

const RARITY_LEFT_BORDER: Record<string, string> = {
  common: "border-l-slate-500/50",
  uncommon: "border-l-green-500/50",
  rare: "border-l-blue-500/50",
  epic: "border-l-purple-500/50",
  legendary: "border-l-amber-500/50",
};

const RARITY_BG: Record<string, string> = {
  common: "bg-slate-500/[0.07]",
  uncommon: "bg-green-500/[0.07]",
  rare: "bg-blue-500/[0.07]",
  epic: "bg-purple-500/[0.07]",
  legendary: "bg-amber-500/[0.07]",
};

const RARITY_BADGE: Record<string, string> = {
  common: "text-slate-400",
  uncommon: "text-green-400",
  rare: "text-blue-400",
  epic: "text-purple-400",
  legendary: "text-amber-400",
};

// ─── Types ────────────────────────────────────────────────────────────────────

interface SlotItem {
  item_slug: string;
  item_name: string;
  item_type: string;
  rarity: string;
  level: number;
  icon: string;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function levelBadgeClass(level: number): string {
  if (level >= 3) return "text-amber-300";
  if (level === 2) return "text-cyan-300";
  return "text-zinc-500";
}

function sectionForType(type: string) {
  return SECTION_CONFIG.find((s) => s.type === type);
}

// ─── Sub-components ───────────────────────────────────────────────────────────

interface FilledSlotProps {
  item: SlotItem;
  onRemove: () => void;
}

function FilledSlot({ item, onRemove }: FilledSlotProps) {
  const [hovered, setHovered] = useState(false);
  const rarity = item.rarity || "common";

  return (
    <div
      className={`group relative aspect-square rounded-lg border border-l-2 ${RARITY_LEFT_BORDER[rarity]} ${RARITY_BG[rarity]} border-white/[0.06] bg-white/[0.02] flex flex-col items-center justify-center cursor-pointer transition-all duration-150 hover:border-white/20`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={onRemove}
      title={`${item.item_name} — kliknij aby usunąć`}
    >
      {/* Remove badge */}
      {hovered && (
        <div className="absolute right-1 top-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500/80 text-white z-10">
          <X className="h-2.5 w-2.5" />
        </div>
      )}
      {/* Level badge */}
      <div className={`absolute left-1 top-1 text-[9px] font-bold leading-none ${levelBadgeClass(item.level)}`}>
        {item.level}
      </div>
      {/* Icon */}
      <span className="text-2xl leading-none select-none">{item.icon || "📦"}</span>
      {/* Name */}
      <p className="mt-1 max-w-full truncate px-1 text-center text-[9px] leading-none text-zinc-400">
        {item.item_name}
      </p>
    </div>
  );
}

function EmptySlot() {
  return (
    <div className="aspect-square rounded-lg border border-dashed border-white/[0.08] bg-white/[0.02] transition-colors hover:border-white/[0.15]" />
  );
}

// ─── Main Component ───────────────────────────────────────────────────────────

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

  // Editor state
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [isDefault, setIsDefault] = useState(false);
  // draftSlots: array of SlotItems per section type
  const [draftSlots, setDraftSlots] = useState<Record<SectionType, SlotItem[]>>({
    tactical_package: [],
    blueprint_building: [],
    boost: [],
  });
  // Available items tab
  const [availableTab, setAvailableTab] = useState<SectionType>("tactical_package");

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

  // ─── Create ──────────────────────────────────────────────────────────────────

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

  // ─── Delete ──────────────────────────────────────────────────────────────────

  const handleDelete = async (deckId: string) => {
    if (!token) return;
    try {
      await deleteDeck(token, deckId);
      toast.success("Talia usunięta");
      if (editingId === deckId) cancelEdit();
      await loadData();
    } catch {
      toast.error("Nie udało się usunąć talii");
    }
  };

  // ─── Set default ─────────────────────────────────────────────────────────────

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

  // ─── Edit start ──────────────────────────────────────────────────────────────

  const startEdit = (deck: DeckOut) => {
    setEditingId(deck.id);
    setEditName(deck.name);
    setIsDefault(deck.is_default);

    // Build initial slot state from deck items
    const slots: Record<SectionType, SlotItem[]> = {
      tactical_package: [],
      blueprint_building: [],
      boost: [],
    };

    for (const di of deck.items) {
      const type = di.item.item_type as SectionType;
      if (!(type in slots)) continue;
      const section = sectionForType(type);
      // Expand quantity into individual slots
      for (let i = 0; i < di.quantity; i++) {
        if (slots[type].length < (section?.slots ?? 99)) {
          slots[type].push({
            item_slug: di.item.slug,
            item_name: di.item.name,
            item_type: di.item.item_type,
            rarity: di.item.rarity,
            level: di.item.level ?? 1,
            icon: di.item.icon || "",
          });
        }
      }
    }

    setDraftSlots(slots);
    setAvailableTab("tactical_package");
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setIsDefault(false);
    setDraftSlots({ tactical_package: [], blueprint_building: [], boost: [] });
  };

  // ─── Slot interactions ───────────────────────────────────────────────────────

  const addItemToSection = (invItem: InventoryItemOut) => {
    const type = invItem.item.item_type as SectionType;
    const section = sectionForType(type);
    if (!section) return;

    setDraftSlots((prev) => {
      const current = prev[type];
      if (current.length >= section.slots) return prev; // full
      return {
        ...prev,
        [type]: [
          ...current,
          {
            item_slug: invItem.item.slug,
            item_name: invItem.item.name,
            item_type: invItem.item.item_type,
            rarity: invItem.item.rarity,
            level: invItem.item.level ?? 1,
            icon: invItem.item.icon || "",
          },
        ],
      };
    });
  };

  const removeSlotItem = (type: SectionType, index: number) => {
    setDraftSlots((prev) => {
      const updated = [...prev[type]];
      updated.splice(index, 1);
      return { ...prev, [type]: updated };
    });
  };

  // ─── Save ────────────────────────────────────────────────────────────────────

  const saveEdit = async () => {
    if (!token || !editingId) return;
    setSaving(true);
    try {
      // Collapse slots back to { item_slug, quantity }[]
      const allSlotItems = [
        ...draftSlots.tactical_package,
        ...draftSlots.blueprint_building,
        ...draftSlots.boost,
      ];
      const countMap = new Map<string, number>();
      for (const s of allSlotItems) {
        countMap.set(s.item_slug, (countMap.get(s.item_slug) ?? 0) + 1);
      }
      const items = Array.from(countMap.entries()).map(([item_slug, quantity]) => ({
        item_slug,
        quantity,
      }));

      await updateDeck(token, editingId, {
        name: editName.trim() || undefined,
        items,
      });

      // Handle default toggle
      const originalDeck = decks.find((d) => d.id === editingId);
      if (isDefault && !originalDeck?.is_default) {
        await setDefaultDeck(token, editingId);
      }

      toast.success("Talia zaktualizowana");
      cancelEdit();
      await loadData();
    } catch {
      toast.error("Nie udało się zapisać talii");
    } finally {
      setSaving(false);
    }
  };

  // ─── Available items helpers ──────────────────────────────────────────────────

  // Count how many times an item already appears in draft slots for its section
  const countInDraft = (slug: string, type: SectionType): number =>
    draftSlots[type].filter((s) => s.item_slug === slug).length;

  // Inventory quantities (owned)
  const ownedQty = (slug: string): number =>
    inventory.find((i) => i.item.slug === slug)?.quantity ?? 0;

  // Items available for the current available tab
  const availableItems = inventory.filter(
    (i) => i.item.item_type === availableTab
  );

  // Total deck item count across all sections
  const totalDraftItems = Object.values(draftSlots).reduce(
    (acc, arr) => acc + arr.length,
    0
  );

  // ─── Guard ───────────────────────────────────────────────────────────────────

  if (authLoading || !user) return null;

  // ─── Deck list view ──────────────────────────────────────────────────────────

  if (!editingId) {
    return (
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="space-y-1">
            <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Talia</p>
            <h1 className="font-display text-3xl text-zinc-50">Kreator talii</h1>
          </div>
          {!creating && (
            <button
              onClick={() => setCreating(true)}
              className="rounded-xl border border-cyan-400/20 bg-cyan-500/15 px-4 py-2 text-sm font-medium text-cyan-200 hover:bg-cyan-500/25 transition-colors flex items-center gap-2"
            >
              <Plus className="h-4 w-4" />
              Nowa talia
            </button>
          )}
        </div>

        {/* Create form */}
        {creating && (
          <div className="rounded-2xl border border-amber-500/20 bg-amber-500/5 p-5 backdrop-blur-xl">
            <p className="mb-3 text-sm font-medium text-amber-200">Nowa talia</p>
            <div className="flex gap-2">
              <input
                type="text"
                value={newDeckName}
                onChange={(e) => setNewDeckName(e.target.value)}
                placeholder="Nazwa talii..."
                className="flex-1 rounded-xl border border-white/10 bg-white/[0.04] px-3 py-2 text-sm text-zinc-100 placeholder:text-slate-500 focus:border-amber-400/40 focus:outline-none"
                onKeyDown={(e) => e.key === "Enter" && handleCreate()}
                autoFocus
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

        {/* Deck cards */}
        {loading ? (
          <div className="rounded-2xl border border-white/10 bg-slate-950/55 p-8 text-center backdrop-blur-xl">
            <p className="text-slate-400">Ładowanie...</p>
          </div>
        ) : decks.length === 0 ? (
          <div className="rounded-2xl border border-white/10 bg-slate-950/55 p-10 text-center backdrop-blur-xl">
            <Layers className="mx-auto mb-3 h-10 w-10 text-slate-600" />
            <p className="text-slate-400">Nie masz żadnych talii. Utwórz pierwszą!</p>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {decks.map((deck) => {
              const totalItems = deck.items.reduce((s, i) => s + i.quantity, 0);
              return (
                <div
                  key={deck.id}
                  className="group relative rounded-2xl border border-white/10 bg-slate-950/55 p-6 backdrop-blur-xl transition-all hover:border-white/20 hover:bg-slate-950/70"
                >
                  {/* Default glow stripe */}
                  {deck.is_default && (
                    <div className="absolute inset-x-0 top-0 h-[2px] rounded-t-2xl bg-gradient-to-r from-transparent via-amber-400/60 to-transparent" />
                  )}

                  <div className="mb-4 flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <h3 className="truncate font-display text-base text-zinc-50">
                          {deck.name}
                        </h3>
                        {deck.is_default && (
                          <span className="shrink-0 rounded-full border border-amber-400/25 bg-amber-400/10 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-amber-300">
                            Domyślna
                          </span>
                        )}
                      </div>
                      <p className="mt-0.5 text-xs text-slate-500">
                        {totalItems} {totalItems === 1 ? "przedmiot" : totalItems < 5 ? "przedmioty" : "przedmiotów"}
                      </p>
                    </div>
                  </div>

                  {/* Item preview pills */}
                  {deck.items.length > 0 && (
                    <div className="mb-4 flex flex-wrap gap-1.5">
                      {deck.items.slice(0, 6).map((di) => (
                        <span
                          key={di.item.slug}
                          className={`flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-medium ${RARITY_BADGE[di.item.rarity] ?? "text-slate-400"} border-white/[0.06] bg-white/[0.04]`}
                        >
                          <span className="text-[11px] leading-none">{di.item.icon || "📦"}</span>
                          {di.item.name}
                          {di.quantity > 1 && (
                            <span className="rounded-full bg-white/10 px-1 font-bold">x{di.quantity}</span>
                          )}
                        </span>
                      ))}
                      {deck.items.length > 6 && (
                        <span className="rounded-full border border-white/[0.06] bg-white/[0.04] px-2 py-0.5 text-[10px] text-slate-500">
                          +{deck.items.length - 6} więcej
                        </span>
                      )}
                    </div>
                  )}

                  {deck.items.length === 0 && (
                    <p className="mb-4 text-xs text-slate-600">Talia jest pusta</p>
                  )}

                  {/* Actions */}
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => startEdit(deck)}
                      className="flex h-8 items-center gap-1.5 rounded-lg border border-white/10 bg-white/[0.04] px-3 text-xs font-medium text-slate-300 transition-colors hover:border-cyan-400/20 hover:bg-cyan-400/10 hover:text-cyan-300"
                    >
                      <Pencil className="h-3.5 w-3.5" />
                      Edytuj
                    </button>
                    {!deck.is_default && (
                      <button
                        onClick={() => handleSetDefault(deck.id)}
                        title="Ustaw jako domyślną"
                        className="flex h-8 w-8 items-center justify-center rounded-lg border border-white/10 bg-white/[0.04] text-slate-400 transition-colors hover:border-amber-400/20 hover:bg-amber-400/10 hover:text-amber-300"
                      >
                        <StarOff className="h-3.5 w-3.5" />
                      </button>
                    )}
                    {deck.is_default && (
                      <span className="flex h-8 w-8 items-center justify-center rounded-lg border border-amber-400/20 bg-amber-400/10 text-amber-300">
                        <Star className="h-3.5 w-3.5" />
                      </span>
                    )}
                    <button
                      onClick={() => handleDelete(deck.id)}
                      title="Usuń"
                      className="ml-auto flex h-8 w-8 items-center justify-center rounded-lg border border-white/10 bg-white/[0.04] text-slate-500 transition-colors hover:border-red-400/20 hover:bg-red-400/10 hover:text-red-400"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    );
  }

  // ─── Deck editor view ────────────────────────────────────────────────────────

  return (
    <div className="space-y-5">
      {/* Editor top bar */}
      <div className="flex flex-wrap items-center gap-3 rounded-2xl border border-white/10 bg-slate-950/55 px-4 py-3 backdrop-blur-xl">
        <span className="text-[11px] font-semibold uppercase tracking-[0.24em] text-slate-500">
          Talia:
        </span>
        <input
          type="text"
          value={editName}
          onChange={(e) => setEditName(e.target.value)}
          className="min-w-0 flex-1 rounded-xl border border-white/10 bg-white/[0.04] px-3 py-1.5 text-sm font-medium text-zinc-100 placeholder:text-slate-500 focus:border-cyan-400/40 focus:outline-none"
        />

        <button
          onClick={() => setIsDefault((v) => !v)}
          className={`flex h-8 items-center gap-1.5 rounded-lg border px-3 text-xs font-medium transition-colors ${
            isDefault
              ? "border-amber-400/25 bg-amber-400/10 text-amber-300"
              : "border-white/10 bg-white/[0.04] text-slate-400 hover:border-amber-400/20 hover:text-amber-300"
          }`}
        >
          {isDefault ? <Star className="h-3.5 w-3.5" /> : <StarOff className="h-3.5 w-3.5" />}
          {isDefault ? "Domyślna" : "Ustaw domyślną"}
        </button>

        <Button
          size="sm"
          onClick={saveEdit}
          disabled={saving}
          className="gap-1.5 rounded-xl bg-cyan-500/20 text-cyan-200 hover:bg-cyan-500/30 border border-cyan-400/20"
        >
          <Check className="h-4 w-4" />
          Zapisz
        </Button>
        <Button
          size="sm"
          variant="ghost"
          onClick={cancelEdit}
          className="rounded-xl text-slate-400 hover:text-zinc-200"
        >
          <X className="h-4 w-4 mr-1" />
          Anuluj
        </Button>

        {/* Total count */}
        <span className="ml-auto text-xs text-slate-500">
          {totalDraftItems} przedmiot{totalDraftItems === 1 ? "" : totalDraftItems < 5 ? "y" : "ów"}
        </span>
      </div>

      {/* Slot sections */}
      <div className="rounded-2xl border border-white/10 bg-slate-950/55 p-6 backdrop-blur-xl space-y-6">
        {SECTION_CONFIG.map((section) => {
          const slots = draftSlots[section.type];
          const filled = slots.length;
          const empty = section.slots - filled;

          return (
            <div key={section.type}>
              {/* Section header */}
              <div className="mb-3 flex items-center gap-2">
                <span className="text-base leading-none">{section.icon}</span>
                <span className={`text-[11px] font-semibold uppercase tracking-[0.24em] ${section.color}`}>
                  {section.label}
                </span>
                <span className="text-[11px] text-slate-600">
                  ({filled}/{section.slots})
                </span>
                <div className="h-px flex-1 bg-white/[0.04]" />
              </div>

              {/* Slot grid */}
              <div className="grid grid-cols-6 gap-2 sm:grid-cols-8 lg:grid-cols-10 xl:grid-cols-12">
                {slots.map((slot, i) => (
                  <FilledSlot
                    key={`${slot.item_slug}-${i}`}
                    item={slot}
                    onRemove={() => removeSlotItem(section.type, i)}
                  />
                ))}
                {Array.from({ length: empty }).map((_, i) => (
                  <EmptySlot key={`empty-${i}`} />
                ))}
              </div>
            </div>
          );
        })}
      </div>

      {/* Available items */}
      <div className="rounded-2xl border border-white/10 bg-slate-950/55 p-6 backdrop-blur-xl">
        {/* Section label */}
        <p className="mb-3 text-[11px] font-semibold uppercase tracking-[0.24em] text-slate-500">
          Dostępne przedmioty
        </p>

        {/* Tab pills */}
        <div className="mb-4 flex flex-wrap gap-1.5">
          {SECTION_CONFIG.map((s) => (
            <button
              key={s.type}
              onClick={() => setAvailableTab(s.type)}
              className={`flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
                availableTab === s.type
                  ? `${s.accentBg} ${s.accentBorder} ${s.color}`
                  : "border-white/[0.06] text-slate-500 hover:border-white/[0.12] hover:text-slate-300"
              }`}
            >
              <span className="text-sm leading-none">{s.icon}</span>
              {s.label}
              <span className={`rounded-full px-1.5 py-0.5 text-[10px] font-bold ${availableTab === s.type ? "bg-white/20" : "bg-white/[0.06]"}`}>
                {inventory.filter((i) => i.item.item_type === s.type).length}
              </span>
            </button>
          ))}
        </div>

        {/* Items grid */}
        {availableItems.length === 0 ? (
          <p className="py-4 text-center text-sm text-slate-600">
            Brak przedmiotów tego typu w ekwipunku
          </p>
        ) : (
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6 xl:grid-cols-8">
            {availableItems.map((inv) => {
              const currentSection = sectionForType(availableTab);
              const inDraftCount = countInDraft(inv.item.slug, availableTab);
              const owned = ownedQty(inv.item.slug);
              const sectionFull = draftSlots[availableTab].length >= (currentSection?.slots ?? 0);
              const exhausted = inDraftCount >= owned;
              const disabled = sectionFull || exhausted;

              return (
                <button
                  key={inv.id}
                  onClick={() => !disabled && addItemToSection(inv)}
                  disabled={disabled}
                  title={disabled ? (sectionFull ? "Sekcja pełna" : "Brak sztuk") : `Dodaj ${inv.item.name}`}
                  className={`group relative flex flex-col items-center gap-1 rounded-lg border p-2 transition-all ${
                    disabled
                      ? "border-white/[0.04] bg-white/[0.01] opacity-35 cursor-not-allowed"
                      : `border-white/[0.06] bg-white/[0.02] cursor-pointer hover:border-white/[0.18] hover:bg-white/[0.06] ${RARITY_BG[inv.item.rarity]}`
                  }`}
                >
                  {/* Icon */}
                  <span className="text-xl leading-none select-none">
                    {inv.item.icon || "📦"}
                  </span>
                  {/* Name */}
                  <p className="line-clamp-2 text-center text-[9px] leading-tight text-zinc-400 group-hover:text-zinc-200">
                    {inv.item.name}
                  </p>
                  {/* Level */}
                  <span className={`text-[9px] font-bold ${levelBadgeClass(inv.item.level ?? 1)}`}>
                    Lvl {inv.item.level ?? 1}
                  </span>
                  {/* Owned qty */}
                  <span className="text-[9px] text-slate-600">
                    Posiadasz: {owned - inDraftCount}
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
