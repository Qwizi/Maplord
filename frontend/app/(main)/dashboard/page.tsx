"use client";

import { useAuth } from "@/hooks/useAuth";
import { useMatchmaking } from "@/hooks/useMatchmaking";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { getMyMatches, type Match } from "@/lib/api";
import {
  Swords,
  User,
  Trophy,
  LogOut,
  Loader2,
  Search,
} from "lucide-react";

export default function DashboardPage() {
  const { user, loading: authLoading, logout, token } = useAuth();
  const { inQueue, playersInQueue, matchId, joinQueue, leaveQueue } =
    useMatchmaking();
  const router = useRouter();
  const [recentMatches, setRecentMatches] = useState<Match[]>([]);

  useEffect(() => {
    if (authLoading) return;
    if (!user) {
      router.replace("/login");
    }
  }, [user, authLoading, router]);

  useEffect(() => {
    if (token) {
      getMyMatches(token)
        .then(setRecentMatches)
        .catch(() => {});
    }
  }, [token]);

  // Redirect to game when match found
  useEffect(() => {
    if (matchId) {
      router.push(`/game/${matchId}`);
    }
  }, [matchId, router]);

  if (authLoading || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-950">
        <Loader2 className="h-8 w-8 animate-spin text-zinc-400" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      {/* Top bar */}
      <header className="border-b border-zinc-800 bg-zinc-900/50">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
          <h1 className="text-2xl font-bold">🗺️ MapLord</h1>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <User className="h-4 w-4" />
              <span className="font-medium">{user.username}</span>
              <Badge variant="secondary">{user.elo_rating} ELO</Badge>
            </div>
            <Button variant="ghost" size="sm" onClick={logout}>
              <LogOut className="mr-1 h-4 w-4" />
              Wyloguj
            </Button>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-5xl space-y-6 px-6 py-8">
        {/* Find game */}
        <Card className="border-zinc-800 bg-zinc-900">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Swords className="h-5 w-5 text-red-400" />
              Szukaj gry
            </CardTitle>
            <CardDescription>
              Dołącz do kolejki i walcz o dominację na mapie
            </CardDescription>
          </CardHeader>
          <CardContent>
            {inQueue ? (
              <div className="flex items-center gap-4">
                <div className="flex items-center gap-2">
                  <Loader2 className="h-5 w-5 animate-spin text-yellow-400" />
                  <span>Szukam przeciwnika...</span>
                  <Badge variant="outline">
                    {playersInQueue} w kolejce
                  </Badge>
                </div>
                <Button variant="destructive" size="sm" onClick={leaveQueue}>
                  Anuluj
                </Button>
              </div>
            ) : (
              <Button
                size="lg"
                className="gap-2"
                onClick={joinQueue}
              >
                <Search className="h-5 w-5" />
                Szukaj gry
              </Button>
            )}
          </CardContent>
        </Card>

        <div className="grid gap-6 md:grid-cols-2">
          {/* Profile */}
          <Card className="border-zinc-800 bg-zinc-900">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <User className="h-5 w-5 text-blue-400" />
                Profil
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between">
                <span className="text-zinc-400">Nazwa</span>
                <span>{user.username}</span>
              </div>
              <Separator className="bg-zinc-800" />
              <div className="flex justify-between">
                <span className="text-zinc-400">Email</span>
                <span>{user.email}</span>
              </div>
              <Separator className="bg-zinc-800" />
              <div className="flex justify-between">
                <span className="text-zinc-400">ELO</span>
                <span className="font-bold text-yellow-400">
                  {user.elo_rating}
                </span>
              </div>
            </CardContent>
          </Card>

          {/* Recent matches */}
          <Card className="border-zinc-800 bg-zinc-900">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Trophy className="h-5 w-5 text-yellow-400" />
                Ostatnie mecze
              </CardTitle>
            </CardHeader>
            <CardContent>
              {recentMatches.length === 0 ? (
                <p className="text-sm text-zinc-500">
                  Brak rozegranych meczy
                </p>
              ) : (
                <div className="space-y-2">
                  {recentMatches.slice(0, 5).map((match) => (
                    <div
                      key={match.id}
                      className="flex items-center justify-between rounded-lg bg-zinc-800/50 px-3 py-2"
                    >
                      <div className="flex items-center gap-2">
                        <Badge
                          variant={
                            match.status === "finished"
                              ? "default"
                              : "secondary"
                          }
                        >
                          {match.status}
                        </Badge>
                        <span className="text-sm text-zinc-400">
                          {match.players.length} graczy
                        </span>
                      </div>
                      {match.status === "in_progress" && (
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() =>
                            router.push(`/game/${match.id}`)
                          }
                        >
                          Wróć do gry
                        </Button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  );
}
