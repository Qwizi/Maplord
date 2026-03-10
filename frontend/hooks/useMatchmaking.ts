"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { createSocket, type WSMessage } from "@/lib/ws";
import { getAccessToken } from "@/lib/auth";

interface UseMatchmakingReturn {
  inQueue: boolean;
  playersInQueue: number;
  matchId: string | null;
  joinQueue: () => void;
  leaveQueue: () => void;
}

export function useMatchmaking(): UseMatchmakingReturn {
  const [inQueue, setInQueue] = useState(false);
  const [playersInQueue, setPlayersInQueue] = useState(0);
  const [matchId, setMatchId] = useState<string | null>(null);
  const wsRef = useRef<WebSocket | null>(null);

  const handleMessage = useCallback((msg: WSMessage) => {
    switch (msg.type) {
      case "queue_status":
        setPlayersInQueue(msg.players_in_queue as number);
        break;
      case "match_found":
        setMatchId(msg.match_id as string);
        setInQueue(false);
        break;
      case "queue_left":
        setInQueue(false);
        break;
    }
  }, []);

  const joinQueue = useCallback(() => {
    const token = getAccessToken();
    if (!token) return;

    const ws = createSocket("/matchmaking/", token, handleMessage, () => {
      setInQueue(false);
    });

    ws.onopen = () => setInQueue(true);
    wsRef.current = ws;
  }, [handleMessage]);

  const leaveQueue = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ action: "cancel" }));
    }
    wsRef.current?.close();
    wsRef.current = null;
    setInQueue(false);
  }, []);

  useEffect(() => {
    return () => {
      wsRef.current?.close();
    };
  }, []);

  return { inQueue, playersInQueue, matchId, joinQueue, leaveQueue };
}
