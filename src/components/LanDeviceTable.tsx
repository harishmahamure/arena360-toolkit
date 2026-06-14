import type { LanDevice, LanFilterTab } from "../types";

export function LanSegregationTabs({
  active,
  counts,
  onChange,
}: {
  active: LanFilterTab;
  counts: Record<LanFilterTab, number>;
  onChange: (tab: LanFilterTab) => void;
}) {
  const tabs: { id: LanFilterTab; label: string }[] = [
    { id: "all", label: "All" },
    { id: "windows", label: "Windows" },
    { id: "other", label: "Other" },
    { id: "winrm", label: "WinRM Ready" },
    { id: "no_winrm", label: "Needs WinRM" },
  ];

  return (
    <div className="seg-tabs">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          className={active === tab.id ? "active" : ""}
          onClick={() => onChange(tab.id)}
        >
          {tab.label} ({counts[tab.id]})
        </button>
      ))}
    </div>
  );
}

export function LanDeviceTable({
  devices,
  selected,
  onToggle,
  onToggleAll,
}: {
  devices: LanDevice[];
  selected: Set<string>;
  onToggle: (ip: string) => void;
  onToggleAll: (ips: string[], select: boolean) => void;
}) {
  const allSelected =
    devices.length > 0 && devices.every((d) => selected.has(d.ip_address));

  return (
    <div className="service-table-wrap">
      <table className="service-table">
        <thead>
          <tr>
            <th>
              <input
                type="checkbox"
                checked={allSelected}
                onChange={(e) =>
                  onToggleAll(
                    devices.map((d) => d.ip_address),
                    e.target.checked,
                  )
                }
              />
            </th>
            <th>IP</th>
            <th>Hostname</th>
            <th>MAC</th>
            <th>Type</th>
            <th>Connection</th>
            <th>WinRM</th>
          </tr>
        </thead>
        <tbody>
          {devices.map((d) => (
            <tr key={d.ip_address}>
              <td>
                <input
                  type="checkbox"
                  checked={selected.has(d.ip_address)}
                  onChange={() => onToggle(d.ip_address)}
                />
              </td>
              <td>
                <strong>{d.ip_address}</strong>
              </td>
              <td>{d.hostname || "—"}</td>
              <td className="muted small">{d.mac_address || "—"}</td>
              <td>
                <span className={`badge ${d.device_type}`}>{d.device_type}</span>
              </td>
              <td>{d.connection_type}</td>
              <td>
                <span
                  className={`badge ${d.winrm_enabled ? "installed" : "missing"}`}
                >
                  {d.winrm_enabled ? "Ready" : "No"}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {devices.length === 0 && (
        <p className="muted" style={{ padding: "1rem" }}>
          No devices in this view. Run a LAN scan to discover stations.
        </p>
      )}
    </div>
  );
}
