"use client";

import { useState } from "react";
import { usePathname } from "next/navigation";
import { useAuth } from "@/hooks/useAuth";
import { useChat } from "@/hooks/useChat";
import { MessageList } from "./MessageList";
import { ChatInput } from "./ChatInput";
import { MessageSquare, X } from "lucide-react";

export default function ChatWidget() {
  const { user } = useAuth();
  const { messages, connected, sendMessage, unreadCount, resetUnread } = useChat();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  // Hide in game pages — game has its own match chat panel
  const isGamePage = pathname.startsWith("/game/");

  if (!user || isGamePage) return null;

  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col items-end gap-2 md:bottom-6 md:right-6">
      {open && (
        <div className="flex h-[400px] w-80 flex-col overflow-hidden rounded-2xl border border-white/10 bg-slate-950/90 shadow-[0_16px_48px_rgba(0,0,0,0.5)] backdrop-blur-xl">
          {/* Header */}
          <div className="flex items-center justify-between border-b border-white/10 px-4 py-2.5">
            <div className="flex items-center gap-2">
              <MessageSquare className="h-3.5 w-3.5 text-slate-400" />
              <span className="text-[11px] font-medium uppercase tracking-[0.18em] text-slate-300">
                Czat
              </span>
            </div>
            <div className="flex items-center gap-2">
              {connected ? (
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" title="Polaczono" />
              ) : (
                <span className="h-1.5 w-1.5 rounded-full bg-red-400" title="Rozlaczono" />
              )}
              <button
                onClick={() => setOpen(false)}
                className="rounded-md p-0.5 text-slate-400 transition-colors hover:bg-white/10 hover:text-zinc-100"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          </div>

          {/* Messages */}
          <MessageList messages={messages} currentUserId={user.id} />

          {/* Input */}
          <ChatInput onSend={sendMessage} disabled={!connected} />
        </div>
      )}

      {/* Toggle button */}
      <button
        onClick={() => {
          setOpen(!open);
          if (!open) resetUnread();
        }}
        className="relative flex h-11 w-11 items-center justify-center rounded-full border border-white/10 bg-slate-950/80 text-slate-300 shadow-[0_10px_24px_rgba(0,0,0,0.3)] backdrop-blur-xl transition-colors hover:bg-white/[0.08] hover:text-zinc-100"
      >
        {open ? <X className="h-5 w-5" /> : <MessageSquare className="h-5 w-5" />}
        {!open && unreadCount > 0 && (
          <span className="absolute -right-1 -top-1 flex h-5 w-5 items-center justify-center rounded-full bg-amber-500 text-[10px] font-bold text-slate-950">
            {unreadCount > 99 ? "99+" : unreadCount}
          </span>
        )}
      </button>
    </div>
  );
}
