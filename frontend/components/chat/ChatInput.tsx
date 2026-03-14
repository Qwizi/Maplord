"use client";

import { useState, useCallback, type KeyboardEvent } from "react";
import { SendHorizontal } from "lucide-react";

interface ChatInputProps {
  onSend: (content: string) => void;
  disabled?: boolean;
  placeholder?: string;
}

export function ChatInput({ onSend, disabled, placeholder }: ChatInputProps) {
  const [value, setValue] = useState("");

  const handleSend = useCallback(() => {
    const trimmed = value.trim();
    if (!trimmed) return;
    onSend(trimmed);
    setValue("");
  }, [value, onSend]);

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        handleSend();
      }
    },
    [handleSend]
  );

  return (
    <div className="flex items-center gap-1.5 border-t border-white/10 px-3 py-2">
      <input
        type="text"
        value={value}
        onChange={(e) => setValue(e.target.value.slice(0, 500))}
        onKeyDown={handleKeyDown}
        placeholder={disabled ? "Laczenie..." : (placeholder ?? "Napisz wiadomosc...")}
        disabled={disabled}
        className="flex-1 rounded-md border border-white/10 bg-white/[0.04] px-2.5 py-1.5 text-[11px] text-zinc-200 placeholder:text-slate-500 focus:border-white/20 focus:outline-none disabled:opacity-40"
      />
      <button
        onClick={handleSend}
        disabled={disabled || !value.trim()}
        className="rounded-md p-1.5 text-slate-400 transition-colors hover:bg-white/10 hover:text-zinc-100 disabled:opacity-30"
      >
        <SendHorizontal className="h-3.5 w-3.5" />
      </button>
    </div>
  );
}
