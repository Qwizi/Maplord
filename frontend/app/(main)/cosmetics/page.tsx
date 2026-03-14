"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Shirt, X } from "lucide-react";
import { toast } from "sonner";
import { useAuth } from "@/hooks/useAuth";
import {
  getMyInventory,
  getEquippedCosmetics,
  equipCosmetic,
  unequipCosmetic,
  type InventoryItemOut,
  type EquippedCosmeticOut,
} from "@/lib/api";

// ─── Rarity config ─────────────────────────────────────────────────────────────

const RARITY_BORDER: Record<string, string> = {
  common: "border-l-slate-400",
  uncommon: "border-l-green-400",
  rare: "border-l-blue-400",
  epic: "border-l-purple-400",
  legendary: "border-l-amber-400",
};

const RARITY_SLOT_BG: Record<string, string> = {
  common: "bg-slate-500/[0.07]",
  uncommon: "bg-green-500/[0.07]",
  rare: "bg-blue-500/[0.07]",
  epic: "bg-purple-500/[0.07]",
  legendary: "bg-amber-500/[0.07]",
};

const RARITY_LEFT_BORDER: Record<string, string> = {
  common: "border-l-slate-500/50",
  uncommon: "border-l-green-500/50",
  rare: "border-l-blue-500/50",
  epic: "border-l-purple-500/50",
  legendary: "border-l-amber-500/50",
};

const RARITY_BG_BADGE: Record<string, string> = {
  common: "bg-slate-500/15 text-slate-300 border-slate-500/20",
  uncommon: "bg-green-500/15 text-green-300 border-green-500/20",
  rare: "bg-blue-500/15 text-blue-300 border-blue-500/20",
  epic: "bg-purple-500/15 text-purple-300 border-purple-500/20",
  legendary: "bg-amber-500/15 text-amber-300 border-amber-500/20",
};

const RARITY_LABELS: Record<string, string> = {
  common: "Zwykły",
  uncommon: "Niepospolity",
  rare: "Rzadki",
  epic: "Epicki",
  legendary: "Legendarny",
};

// ─── Equipped slot component ───────────────────────────────────────────────────

interface EquippedSlotProps {
  equipped: EquippedCosmeticOut;
  onUnequip: (slot: string) => void;
  loading: boolean;
}

function EquippedSlot({ equipped, onUnequip, loading }: EquippedSlotProps) {
  return (
    <div className="group relative flex flex-col items-center gap-2 rounded-xl border border-white/15 bg-white/[0.06] p-3 backdrop-blur-sm transition-all hover:border-white/25 hover:bg-white/[0.10]">
      {/* Unequip button */}
      <button
        onClick={() => onUnequip(equipped.slot)}
        disabled={loading}
        aria-label={`Zdejmij ${equipped.item_name}`}
        className="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full border border-white/10 bg-slate-900 text-slate-400 opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-400 disabled:cursor-not-allowed"
      >
        <X size={11} />
      </button>

      {/* Slot label */}
      <span className="text-[10px] uppercase tracking-[0.18em] text-slate-500 font-medium">
        {equipped.slot}
      </span>

      {/* Icon / asset */}
      <div className="flex h-14 w-14 items-center justify-center rounded-lg border border-white/10 bg-white/[0.05] text-3xl">
        {equipped.asset_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={equipped.asset_url}
            alt={equipped.item_name}
            className="h-10 w-10 object-contain"
          />
        ) : (
          "🎨"
        )}
      </div>

      {/* Item name */}
      <p className="max-w-full truncate text-center text-[11px] font-medium text-zinc-300">
        {equipped.item_name}
      </p>
    </div>
  );
}

function EmptyEquippedSlot({ slot }: { slot: string }) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed border-white/[0.10] bg-white/[0.02] p-3">
      <span className="text-[10px] uppercase tracking-[0.18em] text-slate-600 font-medium">
        {slot}
      </span>
      <div className="flex h-14 w-14 items-center justify-center rounded-lg border border-dashed border-white/[0.08] text-slate-600">
        <Shirt size={22} />
      </div>
      <p className="text-[11px] text-slate-600">Brak</p>
    </div>
  );
}

// ─── Available cosmetic card ───────────────────────────────────────────────────

interface CosmeticCardProps {
  entry: InventoryItemOut;
  isEquipped: boolean;
  onEquip: (slug: string) => void;
  loading: boolean;
}

function CosmeticCard({ entry, isEquipped, onEquip, loading }: CosmeticCardProps) {
  const { item } = entry;
  const rarity = item.rarity;

  return (
    <button
      onClick={() => !isEquipped && onEquip(item.slug)}
      disabled={loading || isEquipped}
      className={[
        "group relative aspect-square rounded-lg border border-l-2 flex flex-col items-center justify-center transition-all duration-150",
        RARITY_LEFT_BORDER[rarity] ?? "border-l-slate-500/50",
        RARITY_SLOT_BG[rarity] ?? "bg-slate-500/[0.07]",
        "border-white/10",
        isEquipped
          ? "ring-2 ring-amber-400/40 border-amber-400/20 opacity-75 cursor-default"
          : "hover:border-white/30 hover:bg-white/[0.08] hover:scale-[1.03] cursor-pointer",
        loading ? "cursor-not-allowed" : "",
      ].join(" ")}
      title={isEquipped ? `${item.name} (założony)` : `Załóż ${item.name}`}
    >
      {/* Equipped indicator */}
      {isEquipped && (
        <div className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-amber-400/20 border border-amber-400/40">
          <span className="text-[8px] text-amber-300">✓</span>
        </div>
      )}

      {/* Icon */}
      <span className="text-2xl leading-none select-none">{item.icon || "🎨"}</span>

      {/* Name */}
      <p className="mt-1 max-w-full truncate px-1 text-center text-[9px] leading-none text-zinc-400">
        {item.name}
      </p>
    </button>
  );
}

// ─── Page ──────────────────────────────────────────────────────────────────────

// Known cosmetic slots — if the backend returns others they'll appear dynamically
const KNOWN_SLOTS = ["banner", "avatar_frame", "chat_badge", "flag"];

export default function CosmeticsPage() {
  const { user, loading: authLoading, token } = useAuth();
  const router = useRouter();

  const [cosmetics, setCosmetics] = useState<InventoryItemOut[]>([]);
  const [equipped, setEquipped] = useState<EquippedCosmeticOut[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    if (!authLoading && !user) router.replace("/login");
  }, [user, authLoading, router]);

  const loadData = useCallback(async () => {
    if (!token) return;
    try {
      const [invRes, equippedRes] = await Promise.all([
        getMyInventory(token, 200),
        getEquippedCosmetics(token),
      ]);
      setCosmetics(invRes.items.filter((i) => i.item.item_type === "cosmetic"));
      setEquipped(equippedRes);
    } catch {
      toast.error("Nie udało się załadować kosmetyków");
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleEquip = async (itemSlug: string) => {
    if (!token || actionLoading) return;
    setActionLoading(true);
    try {
      const result = await equipCosmetic(token, itemSlug);
      toast.success(`Założono: ${result.item_name}`);
      await loadData();
    } catch {
      toast.error("Nie udało się założyć kosmetyku");
    } finally {
      setActionLoading(false);
    }
  };

  const handleUnequip = async (slot: string) => {
    if (!token || actionLoading) return;
    setActionLoading(true);
    try {
      await unequipCosmetic(token, slot);
      toast.success("Zdjęto kosmetyk");
      await loadData();
    } catch {
      toast.error("Nie udało się zdjąć kosmetyku");
    } finally {
      setActionLoading(false);
    }
  };

  if (authLoading || !user) {
    return (
      <div className="flex h-64 items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-slate-500" />
      </div>
    );
  }

  const equippedSlugs = new Set(equipped.map((e) => e.item_slug));

  // Build displayed slots: union of known slots and any currently equipped slot
  const allSlots = Array.from(
    new Set([...KNOWN_SLOTS, ...equipped.map((e) => e.slot)])
  );

  return (
    <div className="space-y-6">

      {/* ── Page header ───────────────────────────────────────────────────────── */}
      <div className="space-y-1">
        <p className="text-[11px] uppercase tracking-[0.24em] text-slate-400">Konto</p>
        <h1 className="font-display text-3xl text-zinc-50">Kosmetyki</h1>
      </div>

      {/* ── Equipped slots ────────────────────────────────────────────────────── */}
      <section className="rounded-2xl border border-white/10 bg-slate-950/55 p-5 backdrop-blur-xl">
        <p className="mb-4 text-[11px] uppercase tracking-[0.24em] text-slate-400 font-medium">
          Założone
        </p>

        {loading ? (
          <div className="flex h-24 items-center justify-center text-sm text-slate-500">
            <Loader2 className="h-4 w-4 animate-spin mr-2" />
            Ładowanie...
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
            {allSlots.map((slot) => {
              const equippedItem = equipped.find((e) => e.slot === slot);
              return equippedItem ? (
                <EquippedSlot
                  key={slot}
                  equipped={equippedItem}
                  onUnequip={handleUnequip}
                  loading={actionLoading}
                />
              ) : (
                <EmptyEquippedSlot key={slot} slot={slot} />
              );
            })}
          </div>
        )}

        {!loading && equipped.length === 0 && (
          <p className="mt-2 text-center text-sm text-slate-500">
            Nie masz założonych żadnych kosmetyków.
          </p>
        )}
      </section>

      {/* ── Available cosmetics ───────────────────────────────────────────────── */}
      <section className="rounded-2xl border border-white/10 bg-slate-950/55 backdrop-blur-xl">
        <div className="flex items-center gap-2 border-b border-white/10 px-5 py-4">
          <Shirt className="h-4 w-4 text-violet-400" />
          <span className="text-sm font-medium text-zinc-200">Dostępne kosmetyki</span>
          <span className="ml-auto text-[11px] text-slate-500 tabular-nums">
            {cosmetics.length} szt.
          </span>
        </div>

        <div className="p-5">
          {loading ? (
            <div className="flex h-40 items-center justify-center text-sm text-slate-500">
              <Loader2 className="h-4 w-4 animate-spin mr-2" />
              Ładowanie ekwipunku...
            </div>
          ) : cosmetics.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-12 text-center">
              <Shirt className="h-10 w-10 text-slate-600" />
              <p className="text-sm text-slate-500">
                Nie masz żadnych kosmetyków w ekwipunku.
              </p>
              <p className="text-xs text-slate-600">
                Zdobywaj kosmetyki przez grę lub kup je na rynku.
              </p>
            </div>
          ) : (
            <>
              <p className="mb-3 text-xs text-slate-500">
                Kliknij na kosmetyk, aby go założyć.
              </p>
              <div className="grid grid-cols-4 gap-1.5 sm:grid-cols-5 md:grid-cols-7 lg:grid-cols-9 xl:grid-cols-11">
                {cosmetics.map((entry) => (
                  <CosmeticCard
                    key={entry.id}
                    entry={entry}
                    isEquipped={equippedSlugs.has(entry.item.slug)}
                    onEquip={handleEquip}
                    loading={actionLoading}
                  />
                ))}
              </div>

              {/* Selected item detail tooltip */}
              <div className="mt-4 rounded-xl border border-white/10 bg-white/[0.03] p-3">
                <div className="flex flex-wrap gap-2">
                  {cosmetics
                    .filter((e) => equippedSlugs.has(e.item.slug))
                    .map((entry) => {
                      const rarity = entry.item.rarity;
                      return (
                        <div key={entry.id} className="flex items-center gap-2">
                          <span className="text-base">{entry.item.icon || "🎨"}</span>
                          <div>
                            <span className="text-xs font-medium text-zinc-300">
                              {entry.item.name}
                            </span>
                            <span
                              className={[
                                "ml-2 rounded-full border px-1.5 py-px text-[9px] font-medium uppercase tracking-wide",
                                RARITY_BG_BADGE[rarity] ?? "",
                              ].join(" ")}
                            >
                              {RARITY_LABELS[rarity] ?? rarity}
                            </span>
                          </div>
                        </div>
                      );
                    })}
                  {equippedSlugs.size === 0 && (
                    <p className="text-xs text-slate-600">Brak aktywnych kosmetyków.</p>
                  )}
                </div>
              </div>
            </>
          )}
        </div>
      </section>
    </div>
  );
}
