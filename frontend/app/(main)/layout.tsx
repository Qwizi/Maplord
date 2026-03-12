"use client";

import type { ReactNode } from "react";
import Image from "next/image";
import { usePathname, useRouter } from "next/navigation";
import { LogOut, Medal, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useAuth } from "@/hooks/useAuth";

function NavButton({
  active,
  label,
  onClick,
  icon,
}: {
  active: boolean;
  label: string;
  onClick: () => void;
  icon: ReactNode;
}) {
  return (
    <Button
      variant="ghost"
      size="sm"
      onClick={onClick}
      className={`rounded-full border px-4 text-slate-200 transition-colors ${
        active
          ? "border-cyan-300/30 bg-cyan-400/12 text-cyan-100 hover:bg-cyan-400/18"
          : "border-white/10 bg-white/[0.03] hover:bg-white/[0.08]"
      }`}
    >
      <span className="mr-1">{icon}</span>
      {label}
    </Button>
  );
}

export default function MainLayout({ children }: { children: ReactNode }) {
  const { user, logout } = useAuth();
  const pathname = usePathname();
  const router = useRouter();

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

      <header className="relative border-b border-white/10 bg-slate-950/45 backdrop-blur-xl">
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-4 py-4 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-2">
              <Image
                src="/assets/common/world.webp"
                alt="MapLord"
                width={26}
                height={26}
                className="h-[26px] w-[26px] object-contain"
              />
            </div>
            <div>
              <p className="font-display text-xs uppercase tracking-[0.32em] text-cyan-200/70">
                Command Hub
              </p>
              <h1 className="font-display text-2xl text-zinc-50">MapLord</h1>
            </div>
          </div>

          <div className="flex flex-wrap items-center justify-end gap-2 sm:gap-4">
            <NavButton
              active={pathname === "/dashboard"}
              label="Dashboard"
              onClick={() => router.push("/dashboard")}
              icon={<User className="h-4 w-4" />}
            />
            <NavButton
              active={pathname === "/leaderboard"}
              label="Ranking"
              onClick={() => router.push("/leaderboard")}
              icon={<Medal className="h-4 w-4" />}
            />
            {user && (
              <div className="flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.03] px-3 py-2">
                <User className="h-4 w-4" />
                <span className="max-w-[120px] truncate font-medium">{user.username}</span>
                <Badge className="border-0 bg-cyan-400/15 text-cyan-200 hover:bg-cyan-400/15">
                  {user.elo_rating} ELO
                </Badge>
              </div>
            )}
            <Button
              variant="ghost"
              size="sm"
              onClick={logout}
              className="rounded-full border border-white/10 bg-white/[0.03] px-4 text-slate-200 hover:bg-white/[0.08]"
            >
              <LogOut className="mr-1 h-4 w-4" />
              Wyloguj
            </Button>
          </div>
        </div>
      </header>

      <main className="relative mx-auto max-w-5xl px-4 py-8 sm:px-6">{children}</main>
    </div>
  );
}
