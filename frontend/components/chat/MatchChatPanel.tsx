"use client";

import { useState, useEffect, useRef } from "react";
import { MessageList, type ChatMessage } from "./MessageList";
import { ChatInput } from "./ChatInput";
import { MessageSquare, ChevronDown, ChevronUp } from "lucide-react";

const CHAT_NOTIFICATION_SOUND = "/assets/audio/gui/int_popup.ogg";

function playNotificationSound() {
  try {
    const audio = new Audio(CHAT_NOTIFICATION_SOUND);
    audio.volume = 0.3;
    audio.play().catch(() => {});
  } catch {}
}

interface MatchChatPanelProps {
  messages: ChatMessage[];
  currentUserId: string;
  onSend: (content: string) => void;
}

export default function MatchChatPanel({ messages, currentUserId, onSend }: MatchChatPanelProps) {
  const [expanded, setExpanded] = useState(true);
  const [unread, setUnread] = useState(0);
  const prevCountRef = useRef(messages.length);
  const initializedRef = useRef(false);

  useEffect(() => {
    // Skip sound on initial history load
    if (!initializedRef.current) {
      initializedRef.current = messages.length > 0;
      prevCountRef.current = messages.length;
      return;
    }

    const newCount = messages.length - prevCountRef.current;
    prevCountRef.current = messages.length;

    if (newCount <= 0) return;

    // Check if new messages are from someone else
    const latestMsg = messages[messages.length - 1];
    if (latestMsg && latestMsg.user_id !== currentUserId) {
      playNotificationSound();
      if (!expanded) {
        setUnread((u) => u + newCount);
      }
    }
  }, [messages.length, currentUserId, expanded]);

  return (
    <div className="absolute bottom-14 left-2 z-20 sm:bottom-4 sm:left-4">
      <div className="flex w-64 flex-col overflow-hidden rounded-2xl border border-white/10 bg-slate-950/88 shadow-[0_10px_24px_rgba(0,0,0,0.22)] backdrop-blur-xl sm:w-72">
        {/* Header — always visible, toggles expand */}
        <button
          onClick={() => {
            setExpanded(!expanded);
            if (!expanded) setUnread(0);
          }}
          className="flex items-center justify-between px-3 py-2 transition-colors hover:bg-white/[0.04]"
        >
          <div className="flex items-center gap-2">
            <MessageSquare className="h-3 w-3 text-slate-400" />
            <span className="text-[10px] font-medium uppercase tracking-[0.18em] text-slate-400">
              Czat meczu
            </span>
            {!expanded && unread > 0 && (
              <span className="flex h-4 min-w-4 items-center justify-center rounded-full bg-amber-500 px-1 text-[9px] font-bold text-slate-950">
                {unread}
              </span>
            )}
          </div>
          {expanded ? (
            <ChevronDown className="h-3 w-3 text-slate-500" />
          ) : (
            <ChevronUp className="h-3 w-3 text-slate-500" />
          )}
        </button>

        {expanded && (
          <>
            <div className="h-44 border-t border-white/[0.06]">
              <div className="flex h-full flex-col">
                <MessageList messages={messages} currentUserId={currentUserId} />
              </div>
            </div>
            <ChatInput onSend={onSend} placeholder="Napisz do graczy..." />
          </>
        )}
      </div>
    </div>
  );
}
