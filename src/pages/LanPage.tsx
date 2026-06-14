import { useCallback, useEffect, useMemo, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { convertFileSrc } from "@tauri-apps/api/core";
import { open } from "@tauri-apps/plugin-dialog";
import { LanDeviceTable, LanSegregationTabs } from "../components/LanDeviceTable";
import type {
  InstallerInfo,
  LanBulkRequest,
  LanDevice,
  LanFilterTab,
  LanScanResult,
  StagedWallpaper,
  SubnetConfig,
} from "../types";
import { filterLanDevices } from "../types";

interface LanPageProps {
  onLog: (step: string, success: boolean, message: string) => void;
  busy: boolean;
  setBusy: (v: boolean) => void;
}

export function LanPage({ onLog, busy, setBusy }: LanPageProps) {
  const [subnet, setSubnet] = useState<SubnetConfig | null>(null);
  const [devices, setDevices] = useState<LanDevice[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [filterTab, setFilterTab] = useState<LanFilterTab>("all");
  const [username, setUsername] = useState("Administrator");
  const [password, setPassword] = useState("");
  const [scanInfo, setScanInfo] = useState<string | null>(null);
  const [stagedWallpaper, setStagedWallpaper] = useState<StagedWallpaper | null>(
    null,
  );
  const [dryRun, setDryRun] = useState(false);
  const [installer, setInstaller] = useState<InstallerInfo | null>(null);

  const loadInstaller = useCallback(async () => {
    try {
      const detected = await invoke<InstallerInfo | null>("detect_installer_path");
      setInstaller(detected);
    } catch (e) {
      onLog("installer", false, String(e));
    }
  }, [onLog]);

  const loadSubnet = useCallback(async () => {
    try {
      const config = await invoke<SubnetConfig>("get_subnet_config");
      setSubnet(config);
    } catch (e) {
      onLog("lan", false, String(e));
    }
  }, [onLog]);

  useEffect(() => {
    loadSubnet();
    loadInstaller();
  }, [loadSubnet, loadInstaller]);

  const runScan = async () => {
    setBusy(true);
    setScanInfo("Scanning...");
    try {
      const result = await invoke<LanScanResult>("scan_lan_devices", {
        usePool: true,
      });
      setDevices(result.devices);
      setScanInfo(`Found ${result.found} of ${result.scanned} addresses scanned`);
      onLog("lan", true, `LAN scan found ${result.found} devices`);

      if (result.devices.length > 0) {
        const classified = await invoke<LanDevice[]>("classify_lan_devices", {
          devices: result.devices,
          username: password ? username : null,
          password: password || null,
        });
        setDevices(classified);
        const windows = classified.filter((d) => d.device_type === "windows");
        setSelected(new Set(windows.map((d) => d.ip_address)));
        onLog("lan", true, `Classified ${classified.length} devices`);
      }
    } catch (e) {
      onLog("lan", false, String(e));
      setScanInfo(null);
    } finally {
      setBusy(false);
    }
  };

  const pickWallpaper = async () => {
    try {
      const picked = await open({
        multiple: false,
        filters: [
          {
            name: "Images",
            extensions: ["jpg", "jpeg", "png", "bmp"],
          },
        ],
      });
      if (!picked || Array.isArray(picked)) return;

      const staged = await invoke<StagedWallpaper>("stage_wallpaper_file", {
        sourcePath: picked,
      });
      setStagedWallpaper(staged);
      onLog("wallpaper", true, `Staged wallpaper: ${staged.fileName}`);
    } catch (e) {
      onLog("wallpaper", false, String(e));
    }
  };

  const pickInstaller = async () => {
    try {
      const picked = await open({
        multiple: false,
        filters: [{ name: "Installer", extensions: ["exe"] }],
      });
      if (!picked || Array.isArray(picked)) return;

      const staged = await invoke<InstallerInfo>("stage_installer_file", {
        sourcePath: picked,
      });
      setInstaller(staged);
      onLog("installer", true, `Staged installer: ${staged.fileName}`);
    } catch (e) {
      onLog("installer", false, String(e));
    }
  };

  const deployInstaller = () => {
    if (!installer) {
      onLog("installer", false, "No installer found — browse to select setup .exe");
      return;
    }

    const selectedDevices = devices.filter((d) => selected.has(d.ip_address));
    const noWinrm = selectedDevices.filter(
      (d) => d.device_type === "windows" && !d.winrm_enabled,
    );
    if (noWinrm.length > 0) {
      const proceed = window.confirm(
        `${noWinrm.length} selected station(s) do not have WinRM enabled. Enable WinRM first, or continue anyway?`,
      );
      if (!proceed) return;
    }

    runBulk({
      targets: [],
      username,
      password,
      action: "remote_install",
      installerSourcePath: installer.path,
      dryRun,
    });
  };

  const runBulk = async (request: LanBulkRequest) => {
    if (selected.size === 0 || !password) {
      onLog("lan", false, "Select devices and enter admin password");
      return;
    }
    setBusy(true);
    try {
      const steps = await invoke<
        Array<{ step: string; success: boolean; message: string }>
      >("lan_bulk_setup", {
        request: {
          ...request,
          targets: Array.from(selected),
          username,
          password,
        },
      });
      steps.forEach((s) => onLog(s.step, s.success, s.message));

      if (request.action === "enable_winrm") {
        const classified = await invoke<LanDevice[]>("classify_lan_devices", {
          devices,
          username,
          password,
        });
        setDevices(classified);
      }
    } catch (e) {
      onLog("lan", false, String(e));
    } finally {
      setBusy(false);
    }
  };

  const bulkAction = (
    action: "enable_winrm" | "copy_setup" | "optimize",
  ) => runBulk({ targets: [], username, password, action, dryRun });

  const applyDesktopCustomize = (setWallpaper: boolean) => {
    if (setWallpaper && !stagedWallpaper) {
      onLog("desktop", false, "Choose a wallpaper image first");
      return;
    }
    runBulk({
      targets: [],
      username,
      password,
      action: "desktop_customize",
      wallpaperSourcePath: stagedWallpaper?.path,
      removeShortcuts: true,
      setWallpaper,
      dryRun,
    });
  };

  const filtered = useMemo(
    () => filterLanDevices(devices, filterTab),
    [devices, filterTab],
  );

  const counts = useMemo(
    () => ({
      all: devices.length,
      windows: filterLanDevices(devices, "windows").length,
      other: filterLanDevices(devices, "other").length,
      winrm: filterLanDevices(devices, "winrm").length,
      no_winrm: filterLanDevices(devices, "no_winrm").length,
    }),
    [devices],
  );

  const toggle = (ip: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(ip)) next.delete(ip);
      else next.add(ip);
      return next;
    });
  };

  const toggleAll = (ips: string[], select: boolean) => {
    setSelected((prev) => {
      const next = new Set(prev);
      ips.forEach((ip) => (select ? next.add(ip) : next.delete(ip)));
      return next;
    });
  };

  const previewSrc = stagedWallpaper
    ? convertFileSrc(stagedWallpaper.path)
    : null;

  return (
    <div className="page">
      <header className="page-header">
        <h2>LAN Discovery</h2>
        <p>
          Find all devices on the local network, deploy the installer, enable WinRM,
          copy setup files, set wallpaper, clean desktops, and optimize gaming stations.
        </p>
      </header>

      {subnet && (
        <div className="status-cards">
          <div className="card">
            <h3>Network</h3>
            <p>
              {subnet.interface_name} — {subnet.current_ip}/{subnet.prefix_length}
            </p>
          </div>
          <div className="card">
            <h3>Gateway</h3>
            <p>{subnet.gateway}</p>
          </div>
          <div className="card">
            <h3>Scan Range</h3>
            <p>
              {subnet.pool_start} – {subnet.pool_end}
            </p>
          </div>
        </div>
      )}

      <div className="card">
        <h3>Remote Installer Deployment</h3>
        <p className="muted">
          Push the Game Zone Optimizer setup from this PC to selected stations and
          run a silent install. Requires WinRM and File and Printer Sharing (SMB).
          The post-install hook on each PC enables WinRM automatically.
        </p>
        <div className="installer-status">
          {installer ? (
            <p>
              <strong>{installer.fileName}</strong>
              <span className="muted small"> ({installer.source})</span>
              <br />
              <span className="muted small">{installer.path}</span>
            </p>
          ) : (
            <p className="muted">Installer not found — browse to select setup .exe</p>
          )}
        </div>
        <div className="toolbar">
          <button
            className="btn secondary"
            onClick={pickInstaller}
            disabled={busy}
          >
            Browse Installer
          </button>
          <button
            className="btn primary"
            onClick={deployInstaller}
            disabled={busy || selected.size === 0 || !installer}
          >
            Deploy Installer to Selected
          </button>
        </div>
      </div>

      <div className="card">
        <h3>Desktop Customization</h3>
        <p className="muted">
          Pick a wallpaper image and apply it to selected stations. Removes all
          desktop shortcuts (.lnk and .url) from Public and user desktops.
          Recycle Bin is preserved.
        </p>
        <div className="wallpaper-picker">
          {previewSrc && (
            <img
              src={previewSrc}
              alt="Wallpaper preview"
              className="wallpaper-preview"
            />
          )}
          <div>
            <button
              className="btn secondary"
              onClick={pickWallpaper}
              disabled={busy}
            >
              Choose Wallpaper
            </button>
            {stagedWallpaper && (
              <p className="muted small">{stagedWallpaper.fileName}</p>
            )}
          </div>
        </div>
        <div className="toolbar">
          <button
            className="btn primary"
            onClick={() => applyDesktopCustomize(true)}
            disabled={busy || selected.size === 0 || !stagedWallpaper}
          >
            Apply Wallpaper &amp; Clean Desktop
          </button>
          <button
            className="btn secondary"
            onClick={() => applyDesktopCustomize(false)}
            disabled={busy || selected.size === 0}
          >
            Remove Shortcuts Only
          </button>
          <label className="checkbox-label">
            <input
              type="checkbox"
              checked={dryRun}
              onChange={(e) => setDryRun(e.target.checked)}
            />
            Dry run (preview only)
          </label>
        </div>
      </div>

      <div className="card">
        <h3>Admin Credentials</h3>
        <p className="muted">
          Shared local admin account used to enable WinRM, copy files, and
          optimize remote stations.
        </p>
        <div className="form-grid">
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
      </div>

      <div className="toolbar">
        <button className="btn primary" onClick={runScan} disabled={busy}>
          {busy ? "Scanning..." : "Scan LAN"}
        </button>
        <button
          className="btn secondary"
          onClick={() => bulkAction("enable_winrm")}
          disabled={busy || selected.size === 0}
        >
          Enable WinRM on Selected
        </button>
        <button
          className="btn secondary"
          onClick={() => bulkAction("copy_setup")}
          disabled={busy || selected.size === 0}
        >
          Copy Setup Files
        </button>
        <button
          className="btn primary"
          onClick={() => bulkAction("optimize")}
          disabled={busy || selected.size === 0}
        >
          Optimize Selected
        </button>
      </div>

      {scanInfo && <p className="muted">{scanInfo}</p>}

      <LanSegregationTabs
        active={filterTab}
        counts={counts}
        onChange={setFilterTab}
      />

      <LanDeviceTable
        devices={filtered}
        selected={selected}
        onToggle={toggle}
        onToggleAll={toggleAll}
      />
    </div>
  );
}
