"use client";

import { useState } from "react";
import { useAuth } from "@/hooks/useAuth";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import AuthScreen from "@/components/auth/AuthScreen";
import { toast } from "sonner";

export default function LoginPage() {
  const { login } = useAuth();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await login(email, password);
      router.push("/dashboard");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Błąd logowania"
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthScreen
      eyebrow="Access Portal"
      title="Logowanie"
      description="Wejdz do panelu dowodzenia i wracaj do swoich meczow rankingowych na mapie swiata."
      altPrompt="Nie masz konta?"
      altHref="/register"
      altLabel="Zarejestruj się"
    >
      <div className="space-y-5">
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email" className="text-slate-300">
              Email
            </Label>
            <Input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="dowodca@maplord.gg"
              required
              autoComplete="email"
              className="h-11 rounded-xl border-white/10 bg-slate-900/80 px-4 text-zinc-100 placeholder:text-slate-500"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password" className="text-slate-300">
              Hasło
            </Label>
            <Input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
              autoComplete="current-password"
              className="h-11 rounded-xl border-white/10 bg-slate-900/80 px-4 text-zinc-100 placeholder:text-slate-500"
            />
          </div>
          <Button
            type="submit"
            className="h-11 w-full rounded-xl border border-cyan-300/30 bg-[linear-gradient(135deg,#38bdf8,#0f766e)] font-display text-sm uppercase tracking-[0.22em] text-slate-950 hover:opacity-95"
            disabled={loading}
          >
            {loading ? "Logowanie..." : "Wejdz do gry"}
          </Button>
        </form>

      </div>
    </AuthScreen>
  );
}
