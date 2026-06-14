import { useCallback, useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { Sidebar } from "./components/Sidebar";
import { useAdminCheck } from "./hooks/useAdminCheck";
import { useTauriEvents } from "./hooks/useTauriEvents";
import { DashboardPage, fetchBackups } from "./pages/DashboardPage";
import { GamingPage } from "./pages/GamingPage";
import { LanPage } from "./pages/LanPage";
import { LogsPage } from "./pages/LogsPage";
import { PrivacyPage } from "./pages/PrivacyPage";
import { RemotePage } from "./pages/RemotePage";
import { ServicesPage } from "./pages/ServicesPage";
import { UninstallPage } from "./pages/UninstallPage";
import { WinUpdatePage } from "./pages/WinUpdatePage";
import type {
  BackupInfo,
  GamingProfileOptions,
  LogEntry,
  PageId,
  RemoteProgress,
} from "./types";

let logCounter = 0;

function App() {
  const [page, setPage] = useState<PageId>("dashboard");
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [busy, setBusy] = useState(false);
  const [lastBackup, setLastBackup] = useState<BackupInfo | null>(null);
  const { status: admin } = useAdminCheck();

  const addLog = useCallback(
    (step: string, success: boolean, message: string) => {
      setLogs((prev) => [
        {
          id: String(++logCounter),
          timestamp: new Date().toLocaleTimeString(),
          step,
          success,
          message,
        },
        ...prev,
      ]);
    },
    [],
  );

  const onRemoteProgress = useCallback(
    (entry: RemoteProgress) => {
      addLog(`remote:${entry.hostname}`, entry.success, entry.message);
    },
    [addLog],
  );

  useTauriEvents(
    useCallback((entry: LogEntry) => {
      setLogs((prev) => [entry, ...prev]);
    }, []),
    onRemoteProgress,
  );

  const refreshBackups = useCallback(async () => {
    try {
      const backups = await fetchBackups();
      setLastBackup(backups[0] ?? null);
    } catch {
      /* ignore on non-Windows */
    }
  }, []);

  useEffect(() => {
    refreshBackups();
  }, [refreshBackups]);

  const applyProfile = async (options: GamingProfileOptions) => {
    setBusy(true);
    addLog("profile", true, "Starting gaming profile...");
    try {
      const result = await invoke<{
        steps: Array<{ step: string; success: boolean; message: string }>;
        backup_path?: string;
      }>("apply_gaming_profile", { options });
      result.steps.forEach((s) => addLog(s.step, s.success, s.message));
      await refreshBackups();
    } catch (e) {
      addLog("profile", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  const rollback = async () => {
    if (!lastBackup) return;
    setBusy(true);
    try {
      const steps = await invoke<
        Array<{ step: string; success: boolean; message: string }>
      >("rollback", { backupPath: lastBackup.path });
      steps.forEach((s) => addLog(s.step, s.success, s.message));
    } catch (e) {
      addLog("rollback", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  const renderPage = () => {
    const logProps = { onLog: addLog, busy, setBusy };
    switch (page) {
      case "dashboard":
        return (
          <DashboardPage
            admin={admin}
            lastBackup={lastBackup}
            onApplyProfile={applyProfile}
            onRollback={rollback}
            busy={busy}
          />
        );
      case "uninstall":
        return <UninstallPage {...logProps} />;
      case "lan":
        return <LanPage {...logProps} />;
      case "services":
        return <ServicesPage {...logProps} />;
      case "privacy":
        return <PrivacyPage {...logProps} />;
      case "winupdate":
        return <WinUpdatePage {...logProps} />;
      case "gaming":
        return <GamingPage {...logProps} />;
      case "remote":
        return (
          <RemotePage
            {...logProps}
            onRemoteProgress={onRemoteProgress}
          />
        );
      case "logs":
        return <LogsPage entries={logs} />;
      default:
        return null;
    }
  };

  return (
    <div className="app">
      <Sidebar active={page} onNavigate={(p) => setPage(p as PageId)} />
      <main className="main">
        {!admin.is_windows && (
          <div className="banner warn">
            This application requires Windows 10 or 11.
          </div>
        )}
        {admin.is_windows && !admin.is_elevated && (
          <div className="banner warn">
            Run as Administrator to apply system changes.
          </div>
        )}
        {renderPage()}
      </main>
    </div>
  );
}

export default App;
