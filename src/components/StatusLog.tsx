import type { LogEntry } from "../types";

export function StatusLog({ entries }: { entries: LogEntry[] }) {
  if (entries.length === 0) {
    return <p className="muted">No operations logged yet.</p>;
  }

  return (
    <div className="log-list">
      {entries.map((entry) => (
        <div
          key={entry.id}
          className={`log-entry ${entry.success ? "success" : "error"}`}
        >
          <span className="log-time">{entry.timestamp}</span>
          <span className="log-step">[{entry.step}]</span>
          <span className="log-message">{entry.message}</span>
        </div>
      ))}
    </div>
  );
}
