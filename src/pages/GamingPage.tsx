import { invoke } from "@tauri-apps/api/core";

interface GamingPageProps {
  onLog: (step: string, success: boolean, message: string) => void;
  busy: boolean;
  setBusy: (v: boolean) => void;
}

export function GamingPage({ onLog, busy, setBusy }: GamingPageProps) {
  const apply = async (dryRun: boolean) => {
    setBusy(true);
    try {
      const steps = await invoke<{ step: string; success: boolean; message: string }[]>(
        "apply_gaming_optimize",
        {
          options: {
            powerPlan: "high_performance",
            gameMode: true,
            hags: false,
            disableMouseAcceleration: true,
            disableSysMain: true,
            disableSearchIndexing: true,
            disableDeliveryOptimization: true,
            disableHibernation: true,
            disableBackgroundApps: true,
            networkTweaks: true,
            visualEffects: "best_performance",
            disableTips: true,
          },
          dryRun,
        },
      );
      steps.forEach((s) => onLog(s.step, s.success, s.message));
    } catch (e) {
      onLog("gaming", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Gaming Optimization</h2>
        <p>Apply performance tweaks for low-latency gaming.</p>
      </header>

      <div className="info-grid">
        <div className="card">
          <h3>Power &amp; Performance</h3>
          <ul>
            <li>High Performance power plan</li>
            <li>Game Mode enabled</li>
            <li>Visual effects: best performance</li>
            <li>Hibernation disabled</li>
          </ul>
        </div>
        <div className="card">
          <h3>Background Reduction</h3>
          <ul>
            <li>SysMain (Superfetch) disabled</li>
            <li>Windows Search indexing disabled</li>
            <li>Delivery Optimization disabled</li>
            <li>Background apps restricted</li>
          </ul>
        </div>
        <div className="card">
          <h3>Input &amp; Network</h3>
          <ul>
            <li>Mouse acceleration disabled</li>
            <li>TCP Nagle tweaks per adapter</li>
          </ul>
        </div>
      </div>

      <div className="toolbar">
        <button
          className="btn secondary"
          onClick={() => apply(true)}
          disabled={busy}
        >
          Preview
        </button>
        <button
          className="btn primary"
          onClick={() => apply(false)}
          disabled={busy}
        >
          Apply Gaming Tweaks
        </button>
      </div>
    </div>
  );
}
