import { useCallback, useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { ServiceTable } from "../components/ServiceTable";
import type { ServiceItem } from "../types";

interface ServicesPageProps {
  onLog: (step: string, success: boolean, message: string) => void;
  busy: boolean;
  setBusy: (v: boolean) => void;
}

export function ServicesPage({ onLog, busy, setBusy }: ServicesPageProps) {
  const [services, setServices] = useState<ServiceItem[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [categoryFilter, setCategoryFilter] = useState("gaming_safe_disable");
  const [dryRun, setDryRun] = useState(true);

  const load = useCallback(async () => {
    try {
      const result = await invoke<ServiceItem[]>("audit_services");
      setServices(result);
      const recommended = result
        .filter((s) => s.category === "gaming_safe_disable")
        .map((s) => s.name);
      setSelected(new Set(recommended));
    } catch (e) {
      onLog("services", false, String(e));
    }
  }, [onLog]);

  useEffect(() => {
    load();
  }, [load]);

  const toggle = (name: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  };

  const apply = async (action: string) => {
    if (selected.size === 0) return;
    setBusy(true);
    try {
      const steps = await invoke<{ step: string; success: boolean; message: string }[]>(
        "apply_services",
        { serviceNames: Array.from(selected), action, dryRun },
      );
      steps.forEach((s) => onLog(s.step, s.success, s.message));
      if (!dryRun) await load();
    } catch (e) {
      onLog("services", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Services Audit</h2>
        <p>Find and disable non-essential Windows services on gaming PCs.</p>
      </header>

      <div className="toolbar">
        <button className="btn secondary" onClick={load} disabled={busy}>
          Refresh Audit
        </button>
        <button
          className="btn secondary"
          onClick={() =>
            setSelected(
              new Set(
                services
                  .filter((s) => s.category === "gaming_safe_disable")
                  .map((s) => s.name),
              ),
            )
          }
        >
          Select recommended
        </button>
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={dryRun}
            onChange={(e) => setDryRun(e.target.checked)}
          />
          Dry run
        </label>
        <button
          className="btn primary"
          onClick={() => apply("disable")}
          disabled={busy || selected.size === 0}
        >
          Disable Selected
        </button>
      </div>

      <ServiceTable
        services={services}
        selected={selected}
        onToggle={toggle}
        categoryFilter={categoryFilter}
        onCategoryFilterChange={setCategoryFilter}
      />
    </div>
  );
}
