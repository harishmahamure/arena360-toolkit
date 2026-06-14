import { useEffect } from "react";
import { listen } from "@tauri-apps/api/event";
import type { LogEntry, RemoteProgress, StepResult } from "../types";

let logId = 0;

export function useTauriEvents(
  onProgress: (entry: LogEntry) => void,
  onRemoteProgress?: (entry: RemoteProgress) => void,
) {
  useEffect(() => {
    const unlisteners: Array<() => void> = [];

    const setup = async () => {
      const progressUnlisten = await listen<StepResult>(
        "operation-progress",
        (event) => {
          onProgress({
            id: String(++logId),
            timestamp: new Date().toLocaleTimeString(),
            step: event.payload.step,
            success: event.payload.success,
            message: event.payload.message,
          });
        },
      );
      unlisteners.push(progressUnlisten);

      if (onRemoteProgress) {
        const remoteUnlisten = await listen<RemoteProgress>(
          "remote-progress",
          (event) => {
            onRemoteProgress(event.payload);
          },
        );
        unlisteners.push(remoteUnlisten);
      }
    };

    setup();

    return () => {
      unlisteners.forEach((fn) => fn());
    };
  }, [onProgress, onRemoteProgress]);
}
