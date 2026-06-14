import { useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import type { GamingProfileOptions, RemoteProgress } from "../types";
import { DEFAULT_PROFILE_OPTIONS } from "../types";

interface RemotePageProps {
  onLog: (step: string, success: boolean, message: string) => void;
  onRemoteProgress: (entry: RemoteProgress) => void;
  busy: boolean;
  setBusy: (v: boolean) => void;
}

export function RemotePage({
  onLog,
  onRemoteProgress,
  busy,
  setBusy,
}: RemotePageProps) {
  const [hostname, setHostname] = useState("");
  const [username, setUsername] = useState("Administrator");
  const [password, setPassword] = useState("");
  const [targets, setTargets] = useState<
    Array<{ hostname: string; username: string; password: string }>
  >([]);
  const [connectionStatus, setConnectionStatus] = useState<string | null>(null);

  const addTarget = () => {
    if (!hostname.trim()) return;
    setTargets((prev) => [
      ...prev,
      { hostname: hostname.trim(), username, password },
    ]);
    setHostname("");
  };

  const testConnection = async () => {
    if (!hostname.trim()) return;
    setBusy(true);
    setConnectionStatus(null);
    try {
      const reachable = await invoke<boolean>("test_winrm_connection", {
        hostname: hostname.trim(),
        username,
        password,
      });
      setConnectionStatus(
        reachable ? "WinRM connection successful" : "WinRM connection failed",
      );
    } catch (e) {
      setConnectionStatus(`Error: ${e}`);
    } finally {
      setBusy(false);
    }
  };

  const pushProfile = async () => {
    if (targets.length === 0) return;
    setBusy(true);
    try {
      const options: GamingProfileOptions = {
        ...DEFAULT_PROFILE_OPTIONS,
        create_restore_point: false,
      };
      const results = await invoke<RemoteProgress[]>("remote_apply_profile", {
        targets,
        options,
      });
      results.forEach((r) => {
        onRemoteProgress(r);
        onLog(`remote:${r.hostname}`, r.success, r.message);
      });
    } catch (e) {
      onLog("remote", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Remote Admin</h2>
        <p>
          Push the gaming profile to stations over WinRM. Run Enable-WinRM.ps1 on
          each gaming PC first.
        </p>
      </header>

      <div className="card">
        <h3>Add Target</h3>
        <div className="form-grid">
          <label>
            Hostname / IP
            <input
              value={hostname}
              onChange={(e) => setHostname(e.target.value)}
              placeholder="192.168.1.50"
            />
          </label>
          <label>
            Username
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
          </label>
          <label>
            Password
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </label>
        </div>
        <div className="toolbar">
          <button className="btn secondary" onClick={testConnection} disabled={busy}>
            Test WinRM
          </button>
          <button className="btn secondary" onClick={addTarget} disabled={busy}>
            Add to List
          </button>
        </div>
        {connectionStatus && (
          <p className="muted">{connectionStatus}</p>
        )}
      </div>

      {targets.length > 0 && (
        <div className="card">
          <h3>Targets ({targets.length})</h3>
          <ul className="target-list">
            {targets.map((t, i) => (
              <li key={i}>
                {t.hostname} ({t.username})
                <button
                  className="btn link"
                  onClick={() =>
                    setTargets((prev) => prev.filter((_, idx) => idx !== i))
                  }
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>
          <button
            className="btn primary"
            onClick={pushProfile}
            disabled={busy}
          >
            Push Gaming Profile to All
          </button>
        </div>
      )}
    </div>
  );
}
