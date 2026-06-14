import { invoke } from "@tauri-apps/api/core";
import type { AdminStatus, BackupInfo, GamingProfileOptions } from "../types";
import { DEFAULT_PROFILE_OPTIONS } from "../types";

interface DashboardPageProps {
  admin: AdminStatus;
  lastBackup: BackupInfo | null;
  onApplyProfile: (options: GamingProfileOptions) => void;
  onRollback: () => void;
  busy: boolean;
}

export function DashboardPage({
  admin,
  lastBackup,
  onApplyProfile,
  onRollback,
  busy,
}: DashboardPageProps) {
  const handleQuickApply = () => {
    onApplyProfile(DEFAULT_PROFILE_OPTIONS);
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Dashboard</h2>
        <p>One-click gaming PC optimization for your game zone.</p>
      </header>

      <div className="status-cards">
        <div className={`card ${admin.is_windows ? "ok" : "warn"}`}>
          <h3>Platform</h3>
          <p>{admin.is_windows ? "Windows detected" : "Windows required"}</p>
        </div>
        <div className={`card ${admin.is_elevated ? "ok" : "warn"}`}>
          <h3>Administrator</h3>
          <p>
            {admin.is_elevated
              ? "Running elevated"
              : "Restart as Administrator"}
          </p>
        </div>
        <div className="card">
          <h3>Last Backup</h3>
          <p>
            {lastBackup
              ? `${lastBackup.label ?? "Backup"} — ${new Date(lastBackup.created_at).toLocaleString()}`
              : "No backup yet"}
          </p>
        </div>
      </div>

      <div className="hero-card">
        <h3>Apply Gaming Profile</h3>
        <p>
          Debloats standard apps, disables telemetry, stops Windows Update,
          disables recommended services, and applies gaming optimizations.
          Creates a restore point and settings backup first.
        </p>
        <div className="hero-actions">
          <button
            className="btn primary large"
            onClick={handleQuickApply}
            disabled={busy || !admin.is_elevated}
          >
            {busy ? "Applying..." : "Apply Gaming Profile"}
          </button>
          {lastBackup && (
            <button
              className="btn secondary"
              onClick={onRollback}
              disabled={busy}
            >
              Rollback Last Backup
            </button>
          )}
        </div>
      </div>

      <div className="info-grid">
        <div className="card">
          <h4>Profile includes</h4>
          <ul>
            <li>Standard debloat preset</li>
            <li>Telemetry & consumer features off</li>
            <li>Windows Update fully disabled</li>
            <li>Non-essential services disabled</li>
            <li>High performance power plan & game mode</li>
          </ul>
        </div>
        <div className="card warn-card">
          <h4>Before you start</h4>
          <ul>
            <li>Run as Administrator on each gaming PC</li>
            <li>Use the <strong>LAN</strong> tab on admin PC to discover and bulk-setup stations</li>
            <li>Installer auto-enables WinRM on gaming PCs after install</li>
            <li>Disabling Windows Update removes automatic security patches</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

export async function fetchBackups(): Promise<BackupInfo[]> {
  return invoke<BackupInfo[]>("list_backups");
}
