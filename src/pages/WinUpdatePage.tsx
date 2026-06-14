import { useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { ConfirmDangerDialog } from "../components/ConfirmDangerDialog";

interface WinUpdatePageProps {
  onLog: (step: string, success: boolean, message: string) => void;
  busy: boolean;
  setBusy: (v: boolean) => void;
}

export function WinUpdatePage({ onLog, busy, setBusy }: WinUpdatePageProps) {
  const [showConfirm, setShowConfirm] = useState(false);

  const disable = async () => {
    setShowConfirm(false);
    setBusy(true);
    try {
      const steps = await invoke<{ step: string; success: boolean; message: string }[]>(
        "apply_win_update_disable",
        { dryRun: false },
      );
      steps.forEach((s) => onLog(s.step, s.success, s.message));
    } catch (e) {
      onLog("win_update", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  const enable = async () => {
    setBusy(true);
    try {
      const steps = await invoke<{ step: string; success: boolean; message: string }[]>(
        "apply_win_update_enable",
      );
      steps.forEach((s) => onLog(s.step, s.success, s.message));
    } catch (e) {
      onLog("win_update", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  const preview = async () => {
    setBusy(true);
    try {
      const steps = await invoke<{ step: string; success: boolean; message: string }[]>(
        "apply_win_update_disable",
        { dryRun: true },
      );
      steps.forEach((s) => onLog(s.step, s.success, s.message));
    } catch (e) {
      onLog("win_update", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Windows Update</h2>
        <p>Fully disable automatic Windows Update on gaming stations.</p>
      </header>

      <div className="card warn-card">
        <h3>Security Warning</h3>
        <p>
          Disabling Windows Update prevents automatic security patches. Gaming
          PCs will not receive critical updates until you manually re-enable
          updates or patch systems through another method.
        </p>
      </div>

      <div className="card">
        <h3>Actions</h3>
        <p>Stops wuauserv, UsoSvc, WaaSMedicSvc and disables update scheduled tasks.</p>
        <div className="toolbar">
          <button className="btn secondary" onClick={preview} disabled={busy}>
            Preview Disable
          </button>
          <button
            className="btn danger"
            onClick={() => setShowConfirm(true)}
            disabled={busy}
          >
            Disable Windows Update
          </button>
          <button className="btn primary" onClick={enable} disabled={busy}>
            Re-enable Windows Update
          </button>
        </div>
      </div>

      <ConfirmDangerDialog
        open={showConfirm}
        title="Disable Windows Update?"
        message="This will fully stop automatic updates on this PC. Security patches will not be installed automatically. A backup is recommended before proceeding."
        confirmLabel="Disable Updates"
        onConfirm={disable}
        onCancel={() => setShowConfirm(false)}
      />
    </div>
  );
}
