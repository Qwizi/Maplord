"use client";

import { useEffect, useRef } from "react";

export interface ChatMessage {
  user_id: string;
  username: string;
  content: string;
  timestamp: number;
}

interface MessageListProps {
  messages: ChatMessage[];
  currentUserId: string;
}

export function MessageList({ messages, currentUserId }: MessageListProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = containerRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [messages.length]);

  if (messages.length === 0) {
    return (
      <div className="flex flex-1 items-center justify-center text-[11px] text-slate-500">
        Brak wiadomosci
      </div>
    );
  }

  return (
    <div ref={containerRef} className="flex-1 overflow-y-auto px-3 py-2 space-y-0.5 scrollbar-thin scrollbar-thumb-white/10">
      {messages.map((msg, i) => {
        const isOwn = msg.user_id === currentUserId;
        const time = new Date(msg.timestamp * 1000);
        const timeStr = time.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

        return (
          <div key={`${msg.timestamp}-${i}`} className="text-[11px] leading-relaxed">
            <span className="text-slate-500">{timeStr}</span>{" "}
            <span className={isOwn ? "font-semibold text-amber-200" : "font-semibold text-zinc-300"}>
              {msg.username}
            </span>{" "}
            <span className="break-words text-slate-300">{msg.content}</span>
          </div>
        );
      })}
    </div>
  );
}
