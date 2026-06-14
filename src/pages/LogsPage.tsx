import { StatusLog } from "../components/StatusLog";
import type { LogEntry } from "../types";

export function LogsPage({ entries }: { entries: LogEntry[] }) {
  return (
    <div className="page">
      <header className="page-header">
        <h2>Operation Logs</h2>
        <p>Live log of all optimization operations.</p>
      </header>
      <StatusLog entries={entries} />
    </div>
  );
}
