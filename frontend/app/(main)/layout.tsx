"use client";

import { type ReactNode, useEffect, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Backpack,
  Code,
  Coins,
  Globe,
  Hammer,
  Layers,
  LayoutDashboard,
  LogOut,
  Medal,
  MoreHorizontal,
  Store,
  Trophy,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { useAuth } from "@/hooks/useAuth";
import { getMyWallet, type WalletOut } from "@/lib/api";
import { cn } from "@/lib/utils";

// ---------------------------------------------------------------------------
// Nav item definitions
// ---------------------------------------------------------------------------

interface NavItem {
  href: string;
  label: string;
  icon: ReactNode;
  matchExact?: boolean;
}

const ACTION_ITEMS: NavItem[] = [
  {
    href: "/dashboard",
    label: "Panel",
    icon: <LayoutDashboard size={18} />,
    matchExact: true,
  },
  {
    href: "/leaderboard",
    label: "Ranking",
    icon: <Medal size={18} />,
    matchExact: true,
  },
];

const ECONOMY_ITEMS: NavItem[] = [
  { href: "/inventory", label: "Ekwipunek", icon: <Backpack size={18} /> },
  { href: "/decks", label: "Talia", icon: <Layers size={18} /> },
  { href: "/marketplace", label: "Rynek", icon: <Store size={18} /> },
  { href: "/crafting", label: "Kuźnia", icon: <Hammer size={18} /> },
];

const OTHER_ITEMS: NavItem[] = [
  { href: "/developers", label: "Deweloperzy", icon: <Code size={18} /> },
];

// Bottom bar items shown on mobile (primary 4 + "więcej" trigger)
const BOTTOM_PRIMARY: NavItem[] = [
  {
    href: "/dashboard",
    label: "Panel",
    icon: <LayoutDashboard size={20} />,
    matchExact: true,
  },
  { href: "/inventory", label: "Ekwipunek", icon: <Backpack size={20} /> },
  { href: "/marketplace", label: "Rynek", icon: <Store size={20} /> },
  { href: "/decks", label: "Talia", icon: <Layers size={20} /> },
];

// ---------------------------------------------------------------------------
// Sidebar nav item
// ---------------------------------------------------------------------------

function SidebarItem({
  item,
  pathname,
  onClick,
}: {
  item: NavItem;
  pathname: string;
  onClick?: () => void;
}) {
  const active = item.matchExact
    ? pathname === item.href
    : pathname.startsWith(item.href);

  return (
    <Link
      href={item.href}
      onClick={onClick}
      aria-current={active ? "page" : undefined}
      className={cn(
        "flex items-center gap-3 px-3 py-2 text-sm font-medium transition-colors rounded-sm",
        active
          ? "border-l-2 border-amber-400 bg-white/[0.04] text-zinc-50 pl-[10px]"
          : "border-l-2 border-transparent text-slate-400 hover:text-zinc-200 hover:bg-white/[0.03] pl-[10px]"
      )}
    >
      <span className="shrink-0">{item.icon}</span>
      <span>{item.label}</span>
    </Link>
  );
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

function SectionHeader({ label }: { label: string }) {
  return (
    <div className="px-3 pb-1 pt-4 text-[10px] font-medium uppercase tracking-[0.2em] text-slate-600 select-none">
      {label}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Sidebar content (reused in desktop sidebar + mobile sheet)
// ---------------------------------------------------------------------------

function SidebarContent({
  pathname,
  onNavigate,
}: {
  pathname: string;
  onNavigate?: () => void;
}) {
  return (
    <nav className="flex flex-col py-2">
      <SectionHeader label="AKCJA" />
      {ACTION_ITEMS.map((item) => (
        <SidebarItem
          key={item.href}
          item={item}
          pathname={pathname}
          onClick={onNavigate}
        />
      ))}

      <SectionHeader label="EKONOMIA" />
      {ECONOMY_ITEMS.map((item) => (
        <SidebarItem
          key={item.href}
          item={item}
          pathname={pathname}
          onClick={onNavigate}
        />
      ))}

      <SectionHeader label="INNE" />
      {OTHER_ITEMS.map((item) => (
        <SidebarItem
          key={item.href}
          item={item}
          pathname={pathname}
          onClick={onNavigate}
        />
      ))}
    </nav>
  );
}

// ---------------------------------------------------------------------------
// Bottom bar item (mobile)
// ---------------------------------------------------------------------------

function BottomBarItem({ item, pathname }: { item: NavItem; pathname: string }) {
  const active = item.matchExact
    ? pathname === item.href
    : pathname.startsWith(item.href);

  return (
    <Link
      href={item.href}
      aria-current={active ? "page" : undefined}
      className={cn(
        "flex flex-col items-center gap-0.5 px-3 py-2 text-[10px] font-medium transition-colors",
        active ? "text-amber-300" : "text-slate-500 hover:text-slate-300"
      )}
    >
      <span className={cn("transition-colors", active && "text-amber-400")}>
        {item.icon}
      </span>
      <span>{item.label}</span>
    </Link>
  );
}

// ---------------------------------------------------------------------------
// Main layout
// ---------------------------------------------------------------------------

export default function MainLayout({ children }: { children: ReactNode }) {
  const { user, logout, token } = useAuth();
  const pathname = usePathname();
  const [wallet, setWallet] = useState<WalletOut | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);

  useEffect(() => {
    if (!token) return;
    getMyWallet(token)
      .then(setWallet)
      .catch(() => {
        // Wallet not available — silently ignore
      });
  }, [token]);

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,#1a2740_0%,#09111d_48%,#04070d_100%)] text-zinc-100">

      {/* ------------------------------------------------------------------ */}
      {/* Top bar                                                             */}
      {/* ------------------------------------------------------------------ */}
      <header className="fixed inset-x-0 top-0 z-40 h-12 border-b border-white/[0.08] bg-slate-950/80 backdrop-blur-xl">
        <div className="flex h-full items-center gap-3 px-4">

          {/* Logo */}
          <Link
            href="/dashboard"
            className="flex shrink-0 items-center gap-2 mr-2"
          >
            <div className="flex h-7 w-7 items-center justify-center rounded-md border border-white/10 bg-white/[0.04]">
              <Globe size={15} className="text-slate-300" />
            </div>
            <span className="font-display text-sm font-semibold uppercase tracking-[0.18em] text-zinc-100">
              MAPLORD
            </span>
          </Link>

          {/* Spacer */}
          <div className="flex-1" />

          {/* Right: gold + ELO + username + logout */}
          {user && (
            <div className="flex items-center gap-2">
              {/* Gold */}
              {wallet !== null && (
                <div className="flex items-center gap-1.5 rounded border border-amber-400/20 bg-amber-500/[0.08] px-2.5 py-1 text-xs font-medium tabular-nums text-amber-300">
                  <Coins size={12} className="shrink-0" />
                  {wallet.gold.toLocaleString("pl-PL")}
                </div>
              )}

              {/* ELO */}
              <div className="hidden items-center gap-1.5 rounded border border-white/10 bg-white/[0.04] px-2.5 py-1 text-xs font-medium text-slate-300 sm:flex">
                <Trophy size={12} className="shrink-0 text-amber-400" />
                {user.elo_rating}
              </div>

              {/* Username */}
              <span className="hidden max-w-[120px] truncate text-sm font-medium text-zinc-200 sm:block">
                {user.username}
              </span>

              {/* Logout */}
              <Button
                variant="ghost"
                size="icon"
                onClick={logout}
                className="h-8 w-8 shrink-0 rounded border border-white/10 bg-white/[0.03] text-slate-400 hover:bg-white/[0.08] hover:text-zinc-100"
                aria-label="Wyloguj"
              >
                <LogOut size={15} />
              </Button>
            </div>
          )}
        </div>
      </header>

      {/* ------------------------------------------------------------------ */}
      {/* Body (below top bar)                                                */}
      {/* ------------------------------------------------------------------ */}
      <div className="flex pt-12">

        {/* ---------------------------------------------------------------- */}
        {/* Desktop sidebar                                                   */}
        {/* ---------------------------------------------------------------- */}
        <aside className="fixed left-0 top-12 hidden h-[calc(100vh-3rem)] w-56 flex-col border-r border-white/[0.06] bg-slate-950/60 backdrop-blur-xl md:flex">
          <div className="flex-1 overflow-y-auto">
            <SidebarContent pathname={pathname} />
          </div>

          {/* Bottom of sidebar: compact user strip */}
          {user && (
            <div className="border-t border-white/[0.06] px-3 py-3">
              <div className="flex items-center gap-2.5">
                <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-slate-700 text-xs font-bold uppercase text-slate-200">
                  {user.username.charAt(0)}
                </div>
                <span className="flex-1 truncate text-xs font-medium text-slate-300">
                  {user.username}
                </span>
              </div>
            </div>
          )}
        </aside>

        {/* ---------------------------------------------------------------- */}
        {/* Main content                                                      */}
        {/* ---------------------------------------------------------------- */}
        <main className="flex-1 md:ml-56">
          <div className="mx-auto max-w-[1400px] px-8 py-6 pb-24 md:pb-6">
            {children}
          </div>
        </main>
      </div>

      {/* ------------------------------------------------------------------ */}
      {/* Mobile bottom bar                                                   */}
      {/* ------------------------------------------------------------------ */}
      <nav className="fixed inset-x-0 bottom-0 z-40 flex h-14 items-stretch border-t border-white/[0.08] bg-slate-950/90 backdrop-blur-xl md:hidden">
        {BOTTOM_PRIMARY.map((item) => (
          <BottomBarItem key={item.href} item={item} pathname={pathname} />
        ))}

        {/* "Więcej" sheet trigger */}
        <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
          <SheetTrigger
            render={
              <button
                className={cn(
                  "flex flex-1 flex-col items-center gap-0.5 px-3 py-2 text-[10px] font-medium transition-colors",
                  "text-slate-500 hover:text-slate-300"
                )}
                aria-label="Więcej opcji"
              />
            }
          >
            <MoreHorizontal size={20} />
            <span>Więcej</span>
          </SheetTrigger>
          <SheetContent
            side="bottom"
            className="rounded-t-2xl border-t border-white/10 bg-slate-950/95 px-0 pb-8 pt-4 backdrop-blur-xl"
          >
            <div className="mb-2 px-4 text-[10px] font-medium uppercase tracking-[0.2em] text-slate-600">
              NAWIGACJA
            </div>
            <SidebarContent
              pathname={pathname}
              onNavigate={() => setSheetOpen(false)}
            />
          </SheetContent>
        </Sheet>
      </nav>
    </div>
  );
}
