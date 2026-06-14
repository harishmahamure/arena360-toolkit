export type PageId =
  | "dashboard"
  | "lan"
  | "uninstall"
  | "services"
  | "privacy"
  | "winupdate"
  | "gaming"
  | "remote"
  | "logs";

export interface AdminStatus {
  is_windows: boolean;
  is_elevated: boolean;
}

export interface StepResult {
  step: string;
  success: boolean;
  message: string;
}

export interface BloatItem {
  id: string;
  name: string;
  kind: string;
  installed: boolean;
  optional: boolean;
  presets: string[];
}

export interface ServiceItem {
  name: string;
  display_name: string;
  status: string;
  start_type: string;
  category: string;
  description: string;
}

export interface BackupInfo {
  path: string;
  created_at: string;
  label?: string;
}

export interface GamingProfileOptions {
  dry_run: boolean;
  debloat_preset: string;
  disable_win_update: boolean;
  disable_telemetry: boolean;
  disable_recommended_services: boolean;
  apply_gaming_tweaks: boolean;
  create_restore_point: boolean;
}

export interface ProfileResult {
  steps: StepResult[];
  backup_path?: string;
}

export interface RemoteTarget {
  hostname: string;
  username: string;
  password: string;
}

export interface RemoteProgress {
  hostname: string;
  step: string;
  success: boolean;
  message: string;
}

export interface LogEntry {
  id: string;
  timestamp: string;
  step: string;
  success: boolean;
  message: string;
}

export const DEFAULT_PROFILE_OPTIONS: GamingProfileOptions = {
  dry_run: false,
  debloat_preset: "standard",
  disable_win_update: true,
  disable_telemetry: true,
  disable_recommended_services: true,
  apply_gaming_tweaks: true,
  create_restore_point: true,
};

export type DeviceType = "windows" | "other" | "unknown";
export type ConnectionType = "wired" | "wireless" | "unknown";
export type LanFilterTab = "all" | "windows" | "other" | "winrm" | "no_winrm";

export interface SubnetConfig {
  subnet: string;
  prefix_length: number;
  gateway: string;
  dns_servers: string[];
  interface_name: string;
  current_ip: string;
  pool_start: string;
  pool_end: string;
}

export interface LanDevice {
  ip_address: string;
  mac_address?: string;
  hostname?: string;
  device_type: DeviceType | string;
  connection_type: ConnectionType | string;
  is_reachable: boolean;
  winrm_enabled: boolean;
  adapter_name?: string;
  ports_open?: number[];
  selected?: boolean;
}

export interface LanScanResult {
  devices: LanDevice[];
  scanned: number;
  found: number;
}

export interface LanBulkRequest {
  targets: string[];
  username: string;
  password: string;
  action:
    | "enable_winrm"
    | "copy_setup"
    | "optimize"
    | "desktop_customize";
  wallpaperSourcePath?: string;
  removeShortcuts?: boolean;
  setWallpaper?: boolean;
  dryRun?: boolean;
}

export interface StagedWallpaper {
  path: string;
  fileName: string;
}

export function filterLanDevices(
  devices: LanDevice[],
  tab: LanFilterTab,
): LanDevice[] {
  switch (tab) {
    case "windows":
      return devices.filter((d) => d.device_type === "windows");
    case "other":
      return devices.filter((d) => d.device_type !== "windows");
    case "winrm":
      return devices.filter((d) => d.winrm_enabled);
    case "no_winrm":
      return devices.filter(
        (d) => d.device_type === "windows" && !d.winrm_enabled,
      );
    default:
      return devices;
  }
}
