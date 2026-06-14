import { invoke } from "@tauri-apps/api/core";

interface PrivacyPageProps {
  onLog: (step: string, success: boolean, message: string) => void;
  busy: boolean;
  setBusy: (v: boolean) => void;
}

export function PrivacyPage({ onLog, busy, setBusy }: PrivacyPageProps) {
  const apply = async (dryRun: boolean) => {
    setBusy(true);
    try {
      const steps = await invoke<{ step: string; success: boolean; message: string }[]>(
        "apply_telemetry_off",
        { dryRun },
      );
      steps.forEach((s) => onLog(s.step, s.success, s.message));
    } catch (e) {
      onLog("telemetry", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Privacy / Telemetry</h2>
        <p>Disable Windows telemetry, advertising ID, and consumer experience features.</p>
      </header>

      <div className="card">
        <h3>Telemetry Off</h3>
        <ul>
          <li>Set AllowTelemetry to 0</li>
          <li>Disable DiagTrack and dmwappushservice</li>
          <li>Disable CEIP scheduled tasks</li>
          <li>Turn off tailored experiences and tips</li>
          <li>Disable Windows consumer features</li>
        </ul>
        <div className="toolbar">
          <button
            className="btn secondary"
            onClick={() => apply(true)}
            disabled={busy}
          >
            Preview Changes
          </button>
          <button
            className="btn primary"
            onClick={() => apply(false)}
            disabled={busy}
          >
            Apply Telemetry Off
          </button>
        </div>
      </div>
    </div>
  );
}
