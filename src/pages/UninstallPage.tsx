import { useCallback, useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { AppChecklist } from "../components/AppChecklist";
import type { BloatItem } from "../types";

interface UninstallPageProps {
  onLog: (step: string, success: boolean, message: string) => void;
  busy: boolean;
  setBusy: (v: boolean) => void;
}

const PRESETS = ["light", "standard", "aggressive"] as const;

export function UninstallPage({ onLog, busy, setBusy }: UninstallPageProps) {
  const [items, setItems] = useState<BloatItem[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [filter, setFilter] = useState("");
  const [preset, setPreset] = useState<string>("standard");
  const [dryRun, setDryRun] = useState(true);

  const loadItems = useCallback(async () => {
    try {
      const result = await invoke<BloatItem[]>("scan_bloatware");
      setItems(result);
    } catch (e) {
      onLog("debloat", false, String(e));
    }
  }, [onLog]);

  useEffect(() => {
    loadItems();
  }, [loadItems]);

  const applyPreset = (p: string) => {
    setPreset(p);
    const ids = items
      .filter(
        (item) =>
          item.installed &&
          (item.presets.includes(p) ||
            (p === "standard" && item.presets.includes("light"))),
      )
      .map((item) => item.id);
    setSelected(new Set(ids));
  };

  const toggle = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleApply = async () => {
    if (selected.size === 0) return;
    setBusy(true);
    try {
      const steps = await invoke<{ step: string; success: boolean; message: string }[]>(
        "apply_debloat",
        { ids: Array.from(selected), dryRun },
      );
      steps.forEach((s) => onLog(s.step, s.success, s.message));
      if (!dryRun) await loadItems();
    } catch (e) {
      onLog("debloat", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Uninstall / Debloat</h2>
        <p>Remove bloatware apps from gaming PCs using manifest-driven presets.</p>
      </header>

      <div className="toolbar">
        {PRESETS.map((p) => (
          <button
            key={p}
            className={`btn ${preset === p ? "primary" : "secondary"}`}
            onClick={() => applyPreset(p)}
          >
            {p.charAt(0).toUpperCase() + p.slice(1)}
          </button>
        ))}
        <button className="btn secondary" onClick={loadItems} disabled={busy}>
          Rescan
        </button>
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={dryRun}
            onChange={(e) => setDryRun(e.target.checked)}
          />
          Dry run (preview only)
        </label>
        <button
          className="btn primary"
          onClick={handleApply}
          disabled={busy || selected.size === 0}
        >
          {dryRun ? "Preview Removal" : "Remove Selected"}
        </button>
      </div>

      <AppChecklist
        items={items}
        selected={selected}
        onToggle={toggle}
        onSelectAll={() =>
          setSelected(new Set(items.filter((i) => i.installed).map((i) => i.id)))
        }
        onClearAll={() => setSelected(new Set())}
        filter={filter}
        onFilterChange={setFilter}
      />
    </div>
  );
}
