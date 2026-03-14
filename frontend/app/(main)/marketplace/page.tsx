"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  ArrowLeft,
  Coins,
  Search,
  ShoppingCart,
  Store,
  X,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/hooks/useAuth";
import {
  buyFromListing,
  cancelListing,
  createListing,
  getItemCategories,
  getMarketListings,
  getMyInventory,
  getMyListings,
  getMyTradeHistory,
  getMyWallet,
  type InventoryItemOut,
  type ItemCategoryOut,
  type ItemOut,
  type MarketListingOut,
  type MarketTransactionOut,
  type WalletOut,
} from "@/lib/api";

// ─── Rarity styling maps ────────────────────────────────────────────────────

const RARITY_BORDER_LEFT: Record<string, string> = {
  common: "border-l-slate-500",
  uncommon: "border-l-green-500",
  rare: "border-l-blue-500",
  epic: "border-l-purple-500",
  legendary: "border-l-amber-500",
};

const RARITY_GLOW: Record<string, string> = {
  common: "hover:shadow-slate-500/20",
  uncommon: "hover:shadow-green-500/20",
  rare: "hover:shadow-blue-500/20",
  epic: "hover:shadow-purple-500/20",
  legendary: "hover:shadow-amber-500/20",
};

const RARITY_BADGE: Record<string, string> = {
  common: "bg-slate-500/20 text-slate-300",
  uncommon: "bg-green-500/20 text-green-300",
  rare: "bg-blue-500/20 text-blue-300",
  epic: "bg-purple-500/20 text-purple-300",
  legendary: "bg-amber-500/20 text-amber-300",
};

const RARITY_LABELS: Record<string, string> = {
  common: "Zwykły",
  uncommon: "Niepospolity",
  rare: "Rzadki",
  epic: "Epicki",
  legendary: "Legendarny",
};

const TYPE_LABELS: Record<string, string> = {
  material: "Materiał",
  blueprint_building: "Blueprint: Budynek",
  blueprint_unit: "Blueprint: Jednostka",
  ability_scroll: "Scroll",
  boost: "Boost",
  crate: "Skrzynka",
  key: "Klucz",
  cosmetic: "Kosmetyk",
};

// ─── Types ────────────────────────────────────────────────────────────────────

type MainTab = "browse" | "my-listings" | "history";

interface AggregatedItem {
  item: ItemOut;
  cheapestPrice: number;
  listingCount: number;
  sellListings: MarketListingOut[];
  buyListings: MarketListingOut[];
}

// ─── Category filter config ────────────────────────────────────────────────

const CATEGORY_PILLS = [
  { value: "all", label: "Wszystko" },
  { value: "blueprint_building", label: "Blueprinty" },
  { value: "boost", label: "Pakiety" },
  { value: "ability_scroll", label: "Bonusy" },
  { value: "material", label: "Materiały" },
  { value: "cosmetic", label: "Kosmetyki" },
];

// ─── Sub-components ────────────────────────────────────────────────────────

function RarityIcon({ rarity }: { rarity: string }) {
  const colors: Record<string, string> = {
    common: "bg-slate-500",
    uncommon: "bg-green-500",
    rare: "bg-blue-500",
    epic: "bg-purple-500",
    legendary: "bg-amber-500",
  };
  return (
    <div
      className={`h-12 w-12 rounded-lg ${colors[rarity] ?? "bg-slate-600"} flex items-center justify-center text-lg font-bold text-white/70 shrink-0`}
    >
      {/* placeholder icon — replace with actual asset when available */}
      <Store className="h-6 w-6" />
    </div>
  );
}

// ─── Browse Grid ──────────────────────────────────────────────────────────

interface BrowseGridProps {
  aggregated: AggregatedItem[];
  onSelect: (slug: string) => void;
  loading: boolean;
  search: string;
  onSearchChange: (v: string) => void;
  filterCategory: string;
  onFilterCategory: (v: string) => void;
  categories: ItemCategoryOut[];
}

function BrowseGrid({
  aggregated,
  onSelect,
  loading,
  search,
  onSearchChange,
  filterCategory,
  onFilterCategory,
}: BrowseGridProps) {
  const filtered = useMemo(() => {
    let items = aggregated;
    if (filterCategory !== "all") {
      items = items.filter((a) => a.item.item_type === filterCategory);
    }
    if (search.trim()) {
      const q = search.trim().toLowerCase();
      items = items.filter((a) => a.item.name.toLowerCase().includes(q));
    }
    return items;
  }, [aggregated, filterCategory, search]);

  return (
    <div>
      {/* Search + category filters */}
      <div className="mb-5 space-y-3">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" />
          <input
            type="text"
            placeholder="Szukaj przedmiotów..."
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
            className="w-full rounded-xl border border-white/10 bg-white/[0.04] py-2.5 pl-9 pr-4 text-sm text-zinc-100 placeholder:text-slate-500 outline-none focus:border-cyan-400/50 transition-colors"
          />
        </div>
        <div className="flex flex-wrap gap-1.5">
          {CATEGORY_PILLS.map((pill) => (
            <button
              key={pill.value}
              onClick={() => onFilterCategory(pill.value)}
              className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
                filterCategory === pill.value
                  ? "border border-cyan-300/25 bg-cyan-400/10 text-cyan-100"
                  : "border border-white/10 text-slate-400 hover:bg-white/[0.06]"
              }`}
            >
              {pill.label}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
          {Array.from({ length: 10 }).map((_, i) => (
            <div
              key={i}
              className="h-28 animate-pulse rounded-xl border border-white/5 bg-white/[0.03]"
            />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="py-16 text-center">
          <Store className="mx-auto mb-3 h-10 w-10 text-slate-600" />
          <p className="text-slate-400">Brak ofert spełniających kryteria</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
          {filtered.map((agg) => (
            <ItemCard key={agg.item.slug} agg={agg} onSelect={onSelect} />
          ))}
        </div>
      )}
    </div>
  );
}

function ItemCard({
  agg,
  onSelect,
}: {
  agg: AggregatedItem;
  onSelect: (slug: string) => void;
}) {
  return (
    <button
      onClick={() => onSelect(agg.item.slug)}
      className={`group relative flex flex-col rounded-xl border-l-[3px] border-t border-r border-b border-t-white/[0.08] border-r-white/[0.08] border-b-white/[0.08] bg-white/[0.03] p-3 text-left transition-all hover:-translate-y-0.5 hover:bg-white/[0.06] hover:shadow-lg ${RARITY_BORDER_LEFT[agg.item.rarity] ?? "border-l-slate-500"} ${RARITY_GLOW[agg.item.rarity] ?? ""}`}
    >
      {/* Icon */}
      <div className="mb-2">
        <RarityIcon rarity={agg.item.rarity} />
      </div>

      {/* Name */}
      <p className="mb-1 line-clamp-2 text-xs font-medium leading-tight text-zinc-100">
        {agg.item.name}
      </p>

      {/* Rarity badge */}
      <span
        className={`mb-2 self-start rounded-full px-1.5 py-0.5 text-[10px] font-medium ${RARITY_BADGE[agg.item.rarity] ?? "bg-slate-500/20 text-slate-300"}`}
      >
        {RARITY_LABELS[agg.item.rarity] ?? agg.item.rarity}
      </span>

      {/* Footer */}
      <div className="mt-auto space-y-0.5">
        <p className="text-[11px] text-slate-400">
          od{" "}
          <span className="font-mono tabular-nums text-amber-300">
            {agg.cheapestPrice}
          </span>{" "}
          gold
        </p>
        <p className="text-[10px] text-slate-600">
          {agg.listingCount} {agg.listingCount === 1 ? "oferta" : "ofert"}
        </p>
      </div>
    </button>
  );
}

// ─── Item Detail View ─────────────────────────────────────────────────────

interface ItemDetailProps {
  agg: AggregatedItem;
  onBack: () => void;
  currentUsername: string;
  token: string;
  inventory: InventoryItemOut[];
  onRefresh: () => void;
}

function ItemDetail({
  agg,
  onBack,
  currentUsername,
  token,
  inventory,
  onRefresh,
}: ItemDetailProps) {
  const [buyQty, setBuyQty] = useState(1);
  const [sellQty, setSellQty] = useState(1);
  const [sellPrice, setSellPrice] = useState(agg.cheapestPrice || 1);
  const [buying, setBuying] = useState(false);
  const [selling, setSelling] = useState(false);

  const sellListings = [...agg.sellListings].sort(
    (a, b) => a.price_per_unit - b.price_per_unit
  );
  const buyListings = [...agg.buyListings].sort(
    (a, b) => b.price_per_unit - a.price_per_unit
  );

  const ownedEntry = inventory.find(
    (i) => i.item.slug === agg.item.slug && i.item.is_tradeable
  );
  const ownedQty = ownedEntry?.quantity ?? 0;

  // Cheapest sell listing not owned by current user
  const cheapestAvailable = sellListings.find(
    (l) => l.seller_username !== currentUsername
  );

  const buyCost = cheapestAvailable
    ? buyQty * cheapestAvailable.price_per_unit
    : 0;
  const feeCost = Math.ceil(sellQty * sellPrice * 0.05);
  const netReceive = sellQty * sellPrice - feeCost;

  const handleBuyDirect = async (listing: MarketListingOut, qty = 1) => {
    setBuying(true);
    try {
      const result = await buyFromListing(token, listing.id, qty);
      toast.success(result.message);
      onRefresh();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Błąd zakupu";
      toast.error(msg);
    } finally {
      setBuying(false);
    }
  };

  const handleBuyCheapest = async () => {
    if (!cheapestAvailable) return;
    await handleBuyDirect(cheapestAvailable, buyQty);
  };

  const handleSell = async () => {
    if (!agg.item.is_tradeable) return;
    setSelling(true);
    try {
      await createListing(token, {
        item_slug: agg.item.slug,
        listing_type: "sell",
        quantity: sellQty,
        price_per_unit: sellPrice,
      });
      toast.success("Oferta wystawiona!");
      onRefresh();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Błąd wystawiania";
      toast.error(msg);
    } finally {
      setSelling(false);
    }
  };

  return (
    <div>
      {/* Back */}
      <button
        onClick={onBack}
        className="mb-4 flex items-center gap-1.5 text-sm text-slate-400 transition-colors hover:text-slate-200"
      >
        <ArrowLeft className="h-4 w-4" />
        Powrót
      </button>

      {/* Item header */}
      <div className="mb-6 flex gap-4 rounded-xl border border-white/[0.08] bg-white/[0.03] p-4">
        <RarityIcon rarity={agg.item.rarity} />
        <div className="min-w-0">
          <h2 className="font-display text-xl text-zinc-50">{agg.item.name}</h2>
          <p className="text-sm text-slate-400">
            {TYPE_LABELS[agg.item.item_type] ?? agg.item.item_type}
          </p>
          <div className="mt-1 flex items-center gap-2">
            <span
              className={`rounded-full px-2 py-0.5 text-xs font-medium ${RARITY_BADGE[agg.item.rarity]}`}
            >
              {RARITY_LABELS[agg.item.rarity]}
            </span>
          </div>
          {agg.item.description && (
            <p className="mt-2 text-sm text-slate-500">{agg.item.description}</p>
          )}
        </div>
      </div>

      {/* Order books */}
      <div className="mb-6 grid gap-4 md:grid-cols-2">
        {/* Sell listings */}
        <div>
          <h3 className="mb-2 text-sm font-medium text-slate-300">
            Oferty sprzedaży
          </h3>
          {sellListings.length === 0 ? (
            <p className="py-6 text-center text-sm text-slate-500">
              Brak ofert sprzedaży
            </p>
          ) : (
            <div className="overflow-hidden rounded-xl border border-white/[0.08]">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/[0.06] bg-white/[0.03]">
                    <th className="px-3 py-2 text-left text-xs font-medium text-slate-500">
                      Sprzedawca
                    </th>
                    <th className="px-3 py-2 text-right text-xs font-medium text-slate-500">
                      Cena
                    </th>
                    <th className="px-3 py-2 text-right text-xs font-medium text-slate-500">
                      Ilość
                    </th>
                    <th className="px-3 py-2 text-right text-xs font-medium text-slate-500" />
                  </tr>
                </thead>
                <tbody>
                  {sellListings.map((listing, idx) => (
                    <tr
                      key={listing.id}
                      className={`border-b border-white/[0.04] transition-colors hover:bg-white/[0.04] ${
                        idx % 2 === 0 ? "" : "bg-white/[0.02]"
                      }`}
                    >
                      <td className="px-3 py-2 text-zinc-300">
                        <span className="flex items-center gap-1.5">
                          {listing.seller_username}
                          {listing.is_bot_listing && (
                            <span className="rounded bg-cyan-500/15 px-1 py-0.5 text-[10px] text-cyan-400">
                              Bot
                            </span>
                          )}
                        </span>
                      </td>
                      <td className="px-3 py-2 text-right font-mono tabular-nums text-amber-300">
                        {listing.price_per_unit}g
                      </td>
                      <td className="px-3 py-2 text-right text-slate-400">
                        x{listing.quantity_remaining}
                      </td>
                      <td className="px-3 py-2 text-right">
                        {listing.seller_username !== currentUsername && (
                          <button
                            onClick={() => handleBuyDirect(listing, 1)}
                            disabled={buying}
                            className="rounded-md bg-cyan-500/15 px-2 py-1 text-xs text-cyan-300 transition-colors hover:bg-cyan-500/25 disabled:opacity-50"
                          >
                            Kup
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Buy listings */}
        <div>
          <h3 className="mb-2 text-sm font-medium text-slate-300">
            Oferty kupna
          </h3>
          {buyListings.length === 0 ? (
            <p className="py-6 text-center text-sm text-slate-500">
              Brak ofert kupna
            </p>
          ) : (
            <div className="overflow-hidden rounded-xl border border-white/[0.08]">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/[0.06] bg-white/[0.03]">
                    <th className="px-3 py-2 text-left text-xs font-medium text-slate-500">
                      Kupujący
                    </th>
                    <th className="px-3 py-2 text-right text-xs font-medium text-slate-500">
                      Cena
                    </th>
                    <th className="px-3 py-2 text-right text-xs font-medium text-slate-500">
                      Ilość
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {buyListings.map((listing, idx) => (
                    <tr
                      key={listing.id}
                      className={`border-b border-white/[0.04] transition-colors hover:bg-white/[0.04] ${
                        idx % 2 === 0 ? "" : "bg-white/[0.02]"
                      }`}
                    >
                      <td className="px-3 py-2 text-zinc-300">
                        <span className="flex items-center gap-1.5">
                          {listing.seller_username}
                          {listing.is_bot_listing && (
                            <span className="rounded bg-cyan-500/15 px-1 py-0.5 text-[10px] text-cyan-400">
                              Bot
                            </span>
                          )}
                        </span>
                      </td>
                      <td className="px-3 py-2 text-right font-mono tabular-nums text-green-300">
                        {listing.price_per_unit}g
                      </td>
                      <td className="px-3 py-2 text-right text-slate-400">
                        x{listing.quantity_remaining}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* Actions */}
      <div className="grid gap-4 md:grid-cols-2">
        {/* Quick buy */}
        {cheapestAvailable && (
          <div className="rounded-xl border border-white/[0.08] bg-white/[0.03] p-4">
            <h3 className="mb-3 text-sm font-medium text-slate-300">Kup</h3>
            <div className="flex items-center gap-2">
              <input
                type="number"
                min={1}
                max={cheapestAvailable.quantity_remaining}
                value={buyQty}
                onChange={(e) =>
                  setBuyQty(
                    Math.max(
                      1,
                      Math.min(
                        cheapestAvailable.quantity_remaining,
                        parseInt(e.target.value) || 1
                      )
                    )
                  )
                }
                className="w-20 rounded-lg border border-white/10 bg-white/[0.04] px-3 py-2 text-center text-sm text-zinc-100 outline-none focus:border-cyan-400/50"
              />
              <Button
                onClick={handleBuyCheapest}
                disabled={buying}
                className="flex-1 rounded-lg"
              >
                <Coins className="mr-1.5 h-4 w-4 text-amber-300" />
                Kup za{" "}
                <span className="ml-1 font-mono tabular-nums text-amber-300">
                  {buyCost}
                </span>{" "}
                gold
              </Button>
            </div>
          </div>
        )}

        {/* Sell form */}
        {agg.item.is_tradeable && (
          <div className="rounded-xl border border-white/[0.08] bg-white/[0.03] p-4">
            <div className="mb-3 flex items-center justify-between">
              <h3 className="text-sm font-medium text-slate-300">
                Wystaw na sprzedaż
              </h3>
              <span className="text-xs text-slate-500">
                Posiadasz:{" "}
                <span className="text-slate-300">{ownedQty}</span>
              </span>
            </div>
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <div className="flex-1">
                  <label className="mb-1 block text-[11px] text-slate-500">
                    Ilość
                  </label>
                  <input
                    type="number"
                    min={1}
                    max={ownedQty || undefined}
                    value={sellQty}
                    onChange={(e) =>
                      setSellQty(Math.max(1, parseInt(e.target.value) || 1))
                    }
                    className="w-full rounded-lg border border-white/10 bg-white/[0.04] px-3 py-2 text-sm text-zinc-100 outline-none focus:border-cyan-400/50"
                  />
                </div>
                <div className="flex-1">
                  <label className="mb-1 block text-[11px] text-slate-500">
                    Cena/szt.
                  </label>
                  <input
                    type="number"
                    min={1}
                    value={sellPrice}
                    onChange={(e) =>
                      setSellPrice(Math.max(1, parseInt(e.target.value) || 1))
                    }
                    className="w-full rounded-lg border border-white/10 bg-white/[0.04] px-3 py-2 text-sm text-zinc-100 outline-none focus:border-cyan-400/50"
                  />
                </div>
              </div>
              <div className="rounded-lg bg-white/[0.02] px-3 py-2 text-xs text-slate-500">
                Prowizja: 5% ={" "}
                <span className="text-amber-300/70">{feeCost}g</span>
                <span className="mx-2 text-slate-700">·</span>
                Otrzymasz:{" "}
                <span className="text-green-300">{netReceive}g</span>
              </div>
              <Button
                onClick={handleSell}
                disabled={selling || ownedQty < 1}
                variant="outline"
                className="w-full rounded-lg"
              >
                Wystaw
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── My Listings Tab ─────────────────────────────────────────────────────

interface MyListingsTabProps {
  listings: MarketListingOut[];
  currentUsername: string;
  token: string;
  onRefresh: () => void;
}

function MyListingsTab({
  listings,
  token,
  onRefresh,
}: MyListingsTabProps) {
  const [cancelling, setCancelling] = useState<string | null>(null);

  const handleCancel = async (listingId: string) => {
    setCancelling(listingId);
    try {
      await cancelListing(token, listingId);
      toast.success("Oferta anulowana");
      onRefresh();
    } catch {
      toast.error("Nie udało się anulować");
    } finally {
      setCancelling(null);
    }
  };

  if (listings.length === 0) {
    return (
      <div className="py-16 text-center">
        <ShoppingCart className="mx-auto mb-3 h-10 w-10 text-slate-600" />
        <p className="text-slate-400">Brak aktywnych ofert</p>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-white/[0.08]">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-white/[0.06] bg-white/[0.03]">
            <th className="px-4 py-3 text-left text-xs font-medium text-slate-500">
              Przedmiot
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-slate-500">
              Typ
            </th>
            <th className="px-4 py-3 text-right text-xs font-medium text-slate-500">
              Cena
            </th>
            <th className="px-4 py-3 text-right text-xs font-medium text-slate-500">
              Pozostało
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-slate-500">
              Status
            </th>
            <th className="px-4 py-3 text-right text-xs font-medium text-slate-500" />
          </tr>
        </thead>
        <tbody>
          {listings.map((listing, idx) => (
            <tr
              key={listing.id}
              className={`border-b border-white/[0.04] transition-colors hover:bg-white/[0.04] ${
                idx % 2 === 0 ? "" : "bg-white/[0.02]"
              }`}
            >
              <td className="px-4 py-3">
                <div className="flex items-center gap-2">
                  <div
                    className={`h-1.5 w-1.5 rounded-full ${
                      listing.item.rarity === "legendary"
                        ? "bg-amber-500"
                        : listing.item.rarity === "epic"
                          ? "bg-purple-500"
                          : listing.item.rarity === "rare"
                            ? "bg-blue-500"
                            : listing.item.rarity === "uncommon"
                              ? "bg-green-500"
                              : "bg-slate-500"
                    }`}
                  />
                  <span className="font-medium text-zinc-200">
                    {listing.item.name}
                  </span>
                </div>
              </td>
              <td className="px-4 py-3 text-slate-400">
                {listing.listing_type === "sell" ? "Sprzedaż" : "Kupno"}
              </td>
              <td className="px-4 py-3 text-right font-mono tabular-nums text-amber-300">
                {listing.price_per_unit}g
              </td>
              <td className="px-4 py-3 text-right text-slate-400">
                {listing.quantity_remaining}/{listing.quantity}
              </td>
              <td className="px-4 py-3 text-center">
                <span
                  className={`rounded-full px-2 py-0.5 text-xs ${
                    listing.status === "active"
                      ? "bg-green-500/15 text-green-400"
                      : "bg-slate-500/15 text-slate-400"
                  }`}
                >
                  {listing.status === "active" ? "Aktywna" : listing.status}
                </span>
              </td>
              <td className="px-4 py-3 text-right">
                {listing.status === "active" && (
                  <button
                    onClick={() => handleCancel(listing.id)}
                    disabled={cancelling === listing.id}
                    className="rounded-md bg-red-500/10 px-2 py-1 text-xs text-red-400 transition-colors hover:bg-red-500/20 disabled:opacity-50"
                  >
                    {cancelling === listing.id ? "..." : "Anuluj"}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ─── History Tab ─────────────────────────────────────────────────────────

interface HistoryTabProps {
  history: MarketTransactionOut[];
  currentUsername: string;
}

function HistoryTab({ history, currentUsername }: HistoryTabProps) {
  if (history.length === 0) {
    return (
      <div className="py-16 text-center">
        <Coins className="mx-auto mb-3 h-10 w-10 text-slate-600" />
        <p className="text-slate-400">Brak transakcji</p>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-white/[0.08]">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-white/[0.06] bg-white/[0.03]">
            <th className="px-4 py-3 text-left text-xs font-medium text-slate-500">
              Data
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-slate-500">
              Przedmiot
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-slate-500">
              Typ
            </th>
            <th className="px-4 py-3 text-right text-xs font-medium text-slate-500">
              Ilość
            </th>
            <th className="px-4 py-3 text-right text-xs font-medium text-slate-500">
              Cena
            </th>
            <th className="px-4 py-3 text-right text-xs font-medium text-slate-500">
              Prowizja
            </th>
          </tr>
        </thead>
        <tbody>
          {history.map((tx, idx) => {
            const isBuyer = tx.buyer_username === currentUsername;
            return (
              <tr
                key={tx.id}
                className={`border-b border-white/[0.04] transition-colors hover:bg-white/[0.04] ${
                  idx % 2 === 0 ? "" : "bg-white/[0.02]"
                }`}
              >
                <td className="px-4 py-3 text-slate-500">
                  {new Date(tx.created_at).toLocaleDateString("pl-PL")}
                </td>
                <td className="px-4 py-3 font-medium text-zinc-200">
                  <span>
                    {tx.item.name}
                  </span>
                </td>
                <td className="px-4 py-3 text-center">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs ${
                      isBuyer
                        ? "bg-red-500/15 text-red-400"
                        : "bg-green-500/15 text-green-400"
                    }`}
                  >
                    {isBuyer ? "Kupno" : "Sprzedaż"}
                  </span>
                </td>
                <td className="px-4 py-3 text-right text-slate-400">
                  x{tx.quantity}
                </td>
                <td
                  className={`px-4 py-3 text-right font-mono tabular-nums ${
                    isBuyer ? "text-red-300" : "text-green-300"
                  }`}
                >
                  {isBuyer ? "-" : "+"}
                  {isBuyer ? tx.total_price : tx.total_price - tx.fee}g
                </td>
                <td className="px-4 py-3 text-right font-mono tabular-nums text-slate-500">
                  {tx.fee > 0 ? `${tx.fee}g` : "—"}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

// ─── Main Page ─────────────────────────────────────────────────────────────

export default function MarketplacePage() {
  const { user, loading: authLoading, token } = useAuth();
  const router = useRouter();

  const [listings, setListings] = useState<MarketListingOut[]>([]);
  const [myListings, setMyListings] = useState<MarketListingOut[]>([]);
  const [history, setHistory] = useState<MarketTransactionOut[]>([]);
  const [wallet, setWallet] = useState<WalletOut | null>(null);
  const [inventory, setInventory] = useState<InventoryItemOut[]>([]);
  const [categories, setCategories] = useState<ItemCategoryOut[]>([]);
  const [loading, setLoading] = useState(true);

  const [tab, setTab] = useState<MainTab>("browse");
  const [selectedSlug, setSelectedSlug] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [filterCategory, setFilterCategory] = useState("all");

  useEffect(() => {
    if (!authLoading && !user) router.replace("/login");
  }, [user, authLoading, router]);

  const loadData = useCallback(async () => {
    if (!token) return;
    try {
      const [lsRes, mlRes, histRes, wal, invRes, cats] = await Promise.all([
        getMarketListings(),
        getMyListings(token),
        getMyTradeHistory(token),
        getMyWallet(token),
        getMyInventory(token),
        getItemCategories(),
      ]);
      setListings(lsRes.items);
      setMyListings(mlRes.items);
      setHistory(histRes.items);
      setWallet(wal);
      setInventory(invRes.items);
      setCategories(cats);
    } catch {
      toast.error("Nie udało się załadować rynku");
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Aggregate all sell listings by unique item slug
  const aggregatedItems = useMemo<AggregatedItem[]>(() => {
    const map = new Map<string, AggregatedItem>();
    for (const listing of listings) {
      const slug = listing.item.slug;
      if (!map.has(slug)) {
        map.set(slug, {
          item: listing.item,
          cheapestPrice: Infinity,
          listingCount: 0,
          sellListings: [],
          buyListings: [],
        });
      }
      const agg = map.get(slug)!;
      if (listing.listing_type === "sell" || !listing.listing_type) {
        agg.sellListings.push(listing);
        agg.listingCount += 1;
        if (listing.price_per_unit < agg.cheapestPrice) {
          agg.cheapestPrice = listing.price_per_unit;
        }
      } else {
        agg.buyListings.push(listing);
        agg.listingCount += 1;
      }
    }
    // Replace Infinity with 0 for items with no sell listings
    for (const agg of map.values()) {
      if (agg.cheapestPrice === Infinity) agg.cheapestPrice = 0;
    }
    return Array.from(map.values()).sort(
      (a, b) => a.cheapestPrice - b.cheapestPrice
    );
  }, [listings]);

  const selectedAgg = selectedSlug
    ? aggregatedItems.find((a) => a.item.slug === selectedSlug) ?? null
    : null;

  const handleSelectItem = (slug: string) => {
    setSelectedSlug(slug);
  };

  const handleBack = () => {
    setSelectedSlug(null);
  };

  // When switching away from browse, clear selection
  const handleTabChange = (t: MainTab) => {
    setTab(t);
    if (t !== "browse") setSelectedSlug(null);
  };

  if (authLoading || !user) return null;

  return (
    <div className="space-y-6">
      {/* ── Page header ─────────────────────────────────────────────────────── */}
      <div className="space-y-1">
        <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Rynek</p>
        <h1 className="font-display text-3xl text-zinc-50">Rynek handlowy</h1>
      </div>

      {/* Wallet bar */}
      <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-slate-950/55 px-5 py-2.5 backdrop-blur-xl">
        <div className="flex items-center gap-2">
          <Coins className="h-4 w-4 text-amber-400" />
          <span className="font-mono tabular-nums text-lg font-semibold text-amber-300">
            {wallet?.gold ?? "—"}
          </span>
          <span className="text-sm text-slate-500">złota</span>
        </div>
        <span className="text-xs text-slate-600">Prowizja rynkowa: 5%</span>
      </div>

      {/* Tab bar */}
      <div className="flex gap-1">
        {(
          [
            { key: "browse" as const, label: "Przeglądaj" },
            { key: "my-listings" as const, label: "Moje oferty" },
            { key: "history" as const, label: "Historia" },
          ] as const
        ).map((t) => (
          <button
            key={t.key}
            onClick={() => handleTabChange(t.key)}
            className={`rounded-lg px-3 py-1.5 text-sm transition-colors ${
              tab === t.key
                ? "bg-white/10 text-zinc-100"
                : "text-slate-400 hover:text-zinc-200 hover:bg-white/[0.04]"
            }`}
          >
            {t.label}
            {t.key === "my-listings" && myListings.length > 0 && (
              <span className="ml-1.5 rounded-full bg-cyan-500/20 px-1.5 py-0.5 text-[10px] text-cyan-400">
                {myListings.filter((l) => l.status === "active").length}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Main content panel */}
      <div className="rounded-2xl border border-white/10 bg-slate-950/55 p-6 backdrop-blur-xl">
        {tab === "browse" && (
          <>
            {selectedAgg ? (
              <ItemDetail
                agg={selectedAgg}
                onBack={handleBack}
                currentUsername={user.username}
                token={token!}
                inventory={inventory}
                onRefresh={loadData}
              />
            ) : (
              <BrowseGrid
                aggregated={aggregatedItems}
                onSelect={handleSelectItem}
                loading={loading}
                search={search}
                onSearchChange={setSearch}
                filterCategory={filterCategory}
                onFilterCategory={setFilterCategory}
                categories={categories}
              />
            )}
          </>
        )}

        {tab === "my-listings" && (
          <MyListingsTab
            listings={myListings}
            currentUsername={user.username}
            token={token!}
            onRefresh={loadData}
          />
        )}

        {tab === "history" && (
          <HistoryTab history={history} currentUsername={user.username} />
        )}
      </div>
    </div>
  );
}
