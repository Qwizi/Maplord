"use client";

import { type ReactNode, useEffect, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Backpack,
  ChevronDown,
  Code,
  Coins,
  Hammer,
  Layers,
  LogOut,
  Medal,
  Store,
  Swords,
  Trophy,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useAuth } from "@/hooks/useAuth";
import { getMyWallet, type WalletOut } from "@/lib/api";
import { cn } from "@/lib/utils";

function NavLink({
  active,
  label,
  href,
  icon,
}: {
  active: boolean;
  label: string;
  href: string;
  icon: ReactNode;
}) {
  return (
    <Link
      href={href}
      aria-current={active ? "page" : undefined}
      className={cn(
        "flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-medium transition-colors",
        active
          ? "border border-cyan-300/25 bg-cyan-400/10 text-cyan-100"
          : "text-slate-300 hover:bg-white/[0.06] hover:text-zinc-100"
      )}
    >
      {icon}
      <span className="hidden sm:inline">{label}</span>
    </Link>
  );
}

function NavDropdown({
  label,
  icon,
  active,
  children,
}: {
  label: string;
  icon: ReactNode;
  active: boolean;
  children: ReactNode;
}) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        className={cn(
          "flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-medium transition-colors outline-none",
          active
            ? "border border-cyan-300/25 bg-cyan-400/10 text-cyan-100"
            : "text-slate-300 hover:bg-white/[0.06] hover:text-zinc-100"
        )}
      >
        {icon}
        <span className="hidden sm:inline">{label}</span>
        <ChevronDown className="hidden h-3 w-3 opacity-60 sm:block" />
      </DropdownMenuTrigger>
      <DropdownMenuContent
        className="min-w-[160px] border border-white/10 bg-slate-950/95 p-1 backdrop-blur-xl"
        sideOffset={6}
      >
        {children}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function NavDropdownItem({
  href,
  icon,
  label,
  active,
}: {
  href: string;
  icon: ReactNode;
  label: string;
  active: boolean;
}) {
  return (
    <DropdownMenuItem
      className={cn(
        "cursor-pointer rounded-md px-3 py-2 text-sm",
        active
          ? "bg-cyan-400/10 text-cyan-100"
          : "text-slate-300 hover:bg-white/[0.06] hover:text-zinc-100"
      )}
    >
      <Link href={href} className="flex w-full items-center gap-2">
        {icon}
        {label}
      </Link>
    </DropdownMenuItem>
  );
}

export default function MainLayout({ children }: { children: ReactNode }) {
  const { user, logout, token } = useAuth();
  const pathname = usePathname();
  const [wallet, setWallet] = useState<WalletOut | null>(null);

  useEffect(() => {
    if (!token) return;
    getMyWallet(token)
      .then(setWallet)
      .catch(() => {
        // Wallet not available — silently ignore
      });
  }, [token]);

  const gameRoutes = ["/dashboard", "/leaderboard"];
  const economyRoutes = ["/inventory", "/marketplace", "/crafting", "/decks"];

  const isGameActive = gameRoutes.some((r) => pathname === r);
  const isEconomyActive = economyRoutes.some((r) => pathname.startsWith(r));

  return (
    <div className="min-h-screen overflow-hidden bg-[radial-gradient(circle_at_top,#1a2740_0%,#09111d_48%,#04070d_100%)] text-zinc-100">
      <div className="pointer-events-none absolute inset-0 bg-[url('/assets/ui/hex_bg_tile.webp')] bg-[size:240px] opacity-[0.05]" />
      <div className="pointer-events-none absolute right-0 top-0 h-[420px] w-[420px] opacity-50">
        <Image
          src="/assets/match_making/g707.webp"
          alt=""
          fill
          className="object-contain object-top-right"
        />
      </div>
      <div className="pointer-events-none absolute left-0 top-24 h-[320px] w-[320px] opacity-35">
        <Image
          src="/assets/match_making/g16.webp"
          alt=""
          fill
          className="object-contain object-left"
        />
      </div>

      <header className="relative border-b border-white/10 bg-slate-950/50 backdrop-blur-xl">
        <div className="mx-auto flex max-w-5xl items-center gap-4 px-4 py-3 sm:px-6">
          {/* Logo */}
          <Link href="/dashboard" className="flex shrink-0 items-center gap-2.5">
            <div className="rounded-xl border border-white/10 bg-white/[0.04] p-1.5">
              <Image
                src="/assets/common/world.webp"
                alt="MapLord"
                width={24}
                height={24}
                className="h-6 w-6 object-contain"
              />
            </div>
            <span className="font-display text-xl text-zinc-50">MapLord</span>
          </Link>

          {/* Nav */}
          <nav className="flex items-center gap-1">
            {/* Gra dropdown */}
            <NavDropdown
              label="Gra"
              icon={<Swords className="h-4 w-4" />}
              active={isGameActive}
            >
              <NavDropdownItem
                href="/dashboard"
                icon={<Swords className="h-3.5 w-3.5" />}
                label="Dashboard"
                active={pathname === "/dashboard"}
              />
              <NavDropdownItem
                href="/leaderboard"
                icon={<Medal className="h-3.5 w-3.5" />}
                label="Ranking"
                active={pathname === "/leaderboard"}
              />
            </NavDropdown>

            {/* Ekonomia dropdown */}
            <NavDropdown
              label="Ekonomia"
              icon={<Coins className="h-4 w-4" />}
              active={isEconomyActive}
            >
              <NavDropdownItem
                href="/inventory"
                icon={<Backpack className="h-3.5 w-3.5" />}
                label="Ekwipunek"
                active={pathname === "/inventory"}
              />
              <NavDropdownItem
                href="/decks"
                icon={<Layers className="h-3.5 w-3.5" />}
                label="Talia"
                active={pathname === "/decks"}
              />
              <NavDropdownItem
                href="/marketplace"
                icon={<Store className="h-3.5 w-3.5" />}
                label="Rynek"
                active={pathname === "/marketplace"}
              />
              <NavDropdownItem
                href="/crafting"
                icon={<Hammer className="h-3.5 w-3.5" />}
                label="Crafting"
                active={pathname === "/crafting"}
              />
            </NavDropdown>

            {/* Deweloperzy — single link */}
            <NavLink
              active={pathname.startsWith("/developers")}
              label="Deweloperzy"
              href="/developers"
              icon={<Code className="h-4 w-4" />}
            />
          </nav>

          {/* Spacer */}
          <div className="flex-1" />

          {/* User info + logout */}
          {user && (
            <div className="flex items-center gap-3">
              <div className="hidden items-center gap-2 sm:flex">
                <span className="max-w-[140px] truncate text-sm font-medium text-zinc-100">
                  {user.username}
                </span>
                <div className="flex items-center gap-1 rounded-full bg-amber-400/12 px-2.5 py-0.5 text-xs font-medium text-amber-200">
                  <Trophy className="h-3 w-3" />
                  {user.elo_rating}
                </div>
                {wallet !== null && (
                  <div className="flex items-center gap-1 rounded-full bg-amber-500/10 px-2.5 py-0.5 text-xs font-medium text-amber-300 border border-amber-400/15">
                    <Coins className="h-3 w-3" />
                    {wallet.gold.toLocaleString()}
                  </div>
                )}
              </div>
              <Button
                variant="ghost"
                size="sm"
                onClick={logout}
                className="rounded-full border border-white/10 bg-white/[0.03] px-3 text-slate-300 hover:bg-white/[0.08] hover:text-zinc-100"
              >
                <LogOut className="h-4 w-4 sm:mr-1.5" />
                <span className="hidden sm:inline">Wyloguj</span>
              </Button>
            </div>
          )}
        </div>
      </header>

      <main className="relative mx-auto max-w-5xl px-4 py-8 sm:px-6">{children}</main>
    </div>
  );
}
