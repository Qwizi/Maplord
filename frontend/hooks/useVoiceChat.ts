"use client";

import { useRef, useState, useCallback } from "react";
import {
  Room,
  RoomEvent,
  RemoteParticipant,
  ConnectionState,
} from "livekit-client";

export interface VoicePeer {
  identity: string;
  name: string;
  isSpeaking: boolean;
  isMuted: boolean;
}

interface UseVoiceChatReturn {
  connected: boolean;
  micEnabled: boolean;
  isSpeaking: boolean;
  peers: VoicePeer[];
  join: (url: string, token: string) => Promise<void>;
  leave: () => void;
  toggleMic: () => Promise<void>;
}

export function useVoiceChat(): UseVoiceChatReturn {
  const roomRef = useRef<Room | null>(null);
  const [connected, setConnected] = useState(false);
  const [micEnabled, setMicEnabled] = useState(false);
  const [peers, setPeers] = useState<VoicePeer[]>([]);
  const [isSpeaking, setIsSpeaking] = useState(false);

  const updatePeers = useCallback(() => {
    const room = roomRef.current;
    if (!room) return;
    const participants: VoicePeer[] = [];
    room.remoteParticipants.forEach((p: RemoteParticipant) => {
      participants.push({
        identity: p.identity,
        name: p.name || p.identity,
        isSpeaking: p.isSpeaking,
        isMuted: !p.isMicrophoneEnabled,
      });
    });
    setPeers(participants);
  }, []);

  const join = useCallback(
    async (url: string, token: string) => {
      // Disconnect existing room if any
      if (roomRef.current) {
        roomRef.current.disconnect();
      }

      const room = new Room({
        adaptiveStream: true,
        dynacast: true,
        audioCaptureDefaults: {
          autoGainControl: true,
          noiseSuppression: true,
          echoCancellation: true,
        },
      });

      roomRef.current = room;

      room.on(RoomEvent.Connected, () => {
        setConnected(true);
        updatePeers();
      });

      room.on(RoomEvent.Disconnected, () => {
        setConnected(false);
        setMicEnabled(false);
        setPeers([]);
        setIsSpeaking(false);
        roomRef.current = null;
      });

      room.on(RoomEvent.ParticipantConnected, () => updatePeers());
      room.on(RoomEvent.ParticipantDisconnected, () => updatePeers());
      room.on(RoomEvent.ActiveSpeakersChanged, (speakers) => {
        updatePeers();
        const localSpeaking = speakers.some(
          (s) => s.identity === room.localParticipant?.identity
        );
        setIsSpeaking(localSpeaking);
      });
      room.on(RoomEvent.TrackMuted, () => updatePeers());
      room.on(RoomEvent.TrackUnmuted, () => updatePeers());

      await room.connect(url, token);
      // Enable mic by default on join
      await room.localParticipant.setMicrophoneEnabled(true);
      setMicEnabled(true);
    },
    [updatePeers]
  );

  const leave = useCallback(() => {
    roomRef.current?.disconnect();
  }, []);

  const toggleMic = useCallback(async () => {
    const room = roomRef.current;
    if (!room || room.state !== ConnectionState.Connected) return;
    const next = !micEnabled;
    await room.localParticipant.setMicrophoneEnabled(next);
    setMicEnabled(next);
  }, [micEnabled]);

  return { connected, micEnabled, isSpeaking, peers, join, leave, toggleMic };
}
