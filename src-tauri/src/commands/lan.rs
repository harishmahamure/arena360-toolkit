use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use tauri::{AppHandle, Emitter, Manager};

use crate::powershell::{self, StepResult};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct SubnetConfig {
    pub subnet: String,
    pub prefix_length: u32,
    pub gateway: String,
    pub dns_servers: Vec<String>,
    pub interface_name: String,
    pub current_ip: String,
    pub pool_start: String,
    pub pool_end: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct LanDevice {
    pub ip_address: String,
    pub mac_address: Option<String>,
    pub hostname: Option<String>,
    pub device_type: String,
    pub connection_type: String,
    pub is_reachable: bool,
    pub winrm_enabled: bool,
    pub adapter_name: Option<String>,
    pub ports_open: Option<Vec<u32>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanScanResult {
    pub devices: Vec<LanDevice>,
    pub scanned: u32,
    pub found: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LanBulkRequest {
    pub targets: Vec<String>,
    pub username: String,
    pub password: String,
    pub action: String,
    #[serde(default)]
    pub wallpaper_source_path: Option<String>,
    #[serde(default = "default_true")]
    pub remove_shortcuts: bool,
    #[serde(default = "default_true")]
    pub set_wallpaper: bool,
    #[serde(default)]
    pub dry_run: bool,
    #[serde(default)]
    pub installer_source_path: Option<String>,
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StagedWallpaper {
    pub path: String,
    pub file_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstallerInfo {
    pub path: String,
    pub file_name: String,
    pub source: String,
}

const MIN_INSTALLER_BYTES: u64 = 1_048_576;

fn staging_dir(app: &AppHandle) -> Result<PathBuf, String> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?
        .join("staging");
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir)
}

fn is_valid_installer(path: &Path) -> bool {
    if path.extension().and_then(|e| e.to_str()) != Some("exe") {
        return false;
    }
    if let Ok(meta) = fs::metadata(path) {
        if meta.len() < MIN_INSTALLER_BYTES {
            return false;
        }
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("")
            .to_lowercase();
        return name.contains("setup")
            || name.contains("game zone optimizer")
            || name == "installer.exe";
    }
    false
}

fn installer_info_from(path: PathBuf, source: &str) -> InstallerInfo {
    InstallerInfo {
        path: path.to_string_lossy().to_string(),
        file_name: path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("installer.exe")
            .to_string(),
        source: source.to_string(),
    }
}

fn find_installers_in_dir(dir: &Path) -> Vec<PathBuf> {
    let mut found = Vec::new();
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() && is_valid_installer(&path) {
                found.push(path);
            }
        }
    }
    found
}

fn newest_path(paths: Vec<PathBuf>) -> Option<PathBuf> {
    paths
        .into_iter()
        .filter_map(|p| {
            fs::metadata(&p)
                .ok()
                .and_then(|m| m.modified().ok())
                .map(|t| (p, t))
        })
        .max_by_key(|(_, t)| *t)
        .map(|(p, _)| p)
}

pub fn detect_installer(app: &AppHandle) -> Option<InstallerInfo> {
    if let Ok(staging) = staging_dir(app) {
        let staged = staging.join("installer.exe");
        if staged.exists() && is_valid_installer(&staged) {
            return Some(installer_info_from(staged, "staged"));
        }
    }

    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            if let Some(path) = newest_path(find_installers_in_dir(dir)) {
                return Some(installer_info_from(path, "auto"));
            }
            if let Some(parent) = dir.parent() {
                if let Some(path) = newest_path(find_installers_in_dir(parent)) {
                    return Some(installer_info_from(path, "auto"));
                }
            }
        }
    }

    if let Ok(home) = std::env::var("USERPROFILE") {
        let downloads = PathBuf::from(home).join("Downloads");
        if let Some(path) = newest_path(find_installers_in_dir(&downloads)) {
            return Some(installer_info_from(path, "auto"));
        }
    }

    None
}

pub fn stage_installer(app: &AppHandle, source: &str) -> Result<PathBuf, String> {
    let source_path = PathBuf::from(source);
    if !source_path.exists() {
        return Err(format!("Installer not found: {source}"));
    }
    if !is_valid_installer(&source_path) {
        return Err(
            "Invalid installer. Select a Game Zone Optimizer setup .exe (at least 1 MB)."
                .to_string(),
        );
    }

    let staging = staging_dir(app)?;
    let dest = staging.join("installer.exe");
    fs::copy(&source_path, &dest).map_err(|e| e.to_string())?;
    Ok(dest)
}

#[tauri::command]
pub async fn detect_installer_path(app: AppHandle) -> Result<Option<InstallerInfo>, String> {
    Ok(detect_installer(&app))
}

#[tauri::command]
pub async fn stage_installer_file(
    app: AppHandle,
    source_path: String,
) -> Result<InstallerInfo, String> {
    let staged = stage_installer(&app, &source_path)?;
    Ok(installer_info_from(staged, "manual"))
}

pub fn stage_wallpaper(app: &AppHandle, source: &str) -> Result<PathBuf, String> {
    let source_path = PathBuf::from(source);
    if !source_path.exists() {
        return Err(format!("Wallpaper file not found: {source}"));
    }

    let ext = source_path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("jpg")
        .to_lowercase();

    let allowed = ["jpg", "jpeg", "png", "bmp"];
    if !allowed.contains(&ext.as_str()) {
        return Err(format!(
            "Unsupported wallpaper format: {ext}. Use jpg, png, or bmp."
        ));
    }

    let staging_dir = staging_dir(app)?;

    let dest = staging_dir.join(format!("wallpaper.{ext}"));
    fs::copy(&source_path, &dest).map_err(|e| e.to_string())?;

    Ok(dest)
}

#[tauri::command]
pub async fn stage_wallpaper_file(
    app: AppHandle,
    source_path: String,
) -> Result<StagedWallpaper, String> {
    let staged = stage_wallpaper(&app, &source_path)?;
    let file_name = staged
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("wallpaper.jpg")
        .to_string();

    Ok(StagedWallpaper {
        path: staged.to_string_lossy().to_string(),
        file_name,
    })
}

#[tauri::command]
pub async fn get_subnet_config(app: AppHandle) -> Result<SubnetConfig, String> {
    if !powershell::is_windows() {
        return Ok(SubnetConfig {
            subnet: "192.168.1.0".into(),
            prefix_length: 24,
            gateway: "192.168.1.1".into(),
            dns_servers: vec!["192.168.1.1".into()],
            interface_name: "Ethernet (dev mock)".into(),
            current_ip: "192.168.1.10".into(),
            pool_start: "192.168.1.100".into(),
            pool_end: "192.168.1.200".into(),
        });
    }

    let result = powershell::run_script(
        &app,
        "Get-SubnetConfig.ps1",
        None,
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    Ok(SubnetConfig {
        subnet: json_str(&result, "subnet"),
        prefix_length: result
            .get("prefix_length")
            .and_then(|v| v.as_u64())
            .unwrap_or(24) as u32,
        gateway: json_str(&result, "gateway"),
        dns_servers: result
            .get("dns_servers")
            .and_then(|v| serde_json::from_value(v.clone()).ok())
            .unwrap_or_default(),
        interface_name: json_str(&result, "interface_name"),
        current_ip: json_str(&result, "current_ip"),
        pool_start: json_str(&result, "pool_start"),
        pool_end: json_str(&result, "pool_end"),
    })
}

#[tauri::command]
pub async fn scan_lan_devices(
    app: AppHandle,
    use_pool: bool,
) -> Result<LanScanResult, String> {
    emit_lan(&app, "scan", "Scanning LAN devices...");

    let result = powershell::run_script(
        &app,
        "Invoke-LanScan.ps1",
        Some(serde_json::json!({ "usePool": use_pool })),
        powershell::LONG_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let devices: Vec<LanDevice> = result
        .get("devices")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    let scan_result = LanScanResult {
        scanned: result.get("scanned").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
        found: result.get("found").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
        devices,
    };

    let _ = app.emit("lan-scan-complete", &scan_result);
    Ok(scan_result)
}

#[tauri::command]
pub async fn classify_lan_devices(
    app: AppHandle,
    devices: Vec<LanDevice>,
    username: Option<String>,
    password: Option<String>,
) -> Result<Vec<LanDevice>, String> {
    emit_lan(&app, "classify", "Classifying devices...");

    let result = powershell::run_script(
        &app,
        "Invoke-DeviceClassify.ps1",
        Some(serde_json::json!({
            "devices": devices,
            "username": username,
            "password": password,
        })),
        powershell::LONG_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    result
        .get("devices")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .ok_or_else(|| "Classification returned no devices".to_string())
}

#[tauri::command]
pub async fn lan_bulk_setup(
    app: AppHandle,
    request: LanBulkRequest,
) -> Result<Vec<StepResult>, String> {
    emit_lan(
        &app,
        "setup",
        format!(
            "Running {} on {} targets...",
            request.action,
            request.targets.len()
        ),
    );

    let mut config = serde_json::json!({
        "targets": request.targets,
        "username": request.username,
        "password": request.password,
        "action": request.action,
        "removeShortcuts": request.remove_shortcuts,
        "setWallpaper": request.set_wallpaper,
        "dryRun": request.dry_run,
    });

    if let Some(path) = request.wallpaper_source_path {
        config["wallpaperSourcePath"] = serde_json::Value::String(path);
    }

    if let Some(path) = request.installer_source_path {
        config["installerSourcePath"] = serde_json::Value::String(path);
    }

    let timeout = if request.action == "remote_install" {
        powershell::LONG_TIMEOUT * 3
    } else {
        powershell::LONG_TIMEOUT
    };

    let result = powershell::run_script(
        &app,
        "Invoke-LanBulkSetup.ps1",
        Some(config),
        timeout,
    )
    .map_err(|e| e.to_string())?;

    let steps: Vec<StepResult> = result
        .get("steps")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    for step in &steps {
        let _ = app.emit("operation-progress", step);
    }

    Ok(steps)
}

#[tauri::command]
pub async fn apply_desktop_customize(
    app: AppHandle,
    wallpaper_path: Option<String>,
    remove_shortcuts: bool,
    set_wallpaper: bool,
    dry_run: bool,
) -> Result<Vec<StepResult>, String> {
    let wp_path = wallpaper_path.unwrap_or_else(|| {
        "C:\\ProgramData\\GameZoneOptimizer\\wallpaper.jpg".to_string()
    });

    let result = powershell::run_script(
        &app,
        "Invoke-DesktopCustomize.ps1",
        Some(serde_json::json!({
            "wallpaperPath": wp_path,
            "removeShortcuts": remove_shortcuts,
            "setWallpaper": set_wallpaper,
            "dryRun": dry_run,
        })),
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let steps: Vec<StepResult> = result
        .get("steps")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    for step in &steps {
        let _ = app.emit("operation-progress", step);
    }

    Ok(steps)
}

#[tauri::command]
pub async fn run_post_install_setup(app: AppHandle) -> Result<Vec<StepResult>, String> {
    let result = powershell::run_script(
        &app,
        "Invoke-PostInstallSetup.ps1",
        None,
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let steps: Vec<StepResult> = result
        .get("steps")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_else(|| {
            vec![StepResult {
                step: "post_install".into(),
                success: true,
                message: "Post-install setup completed".into(),
            }]
        });

    Ok(steps)
}

fn json_str(val: &serde_json::Value, key: &str) -> String {
    val.get(key)
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string()
}

fn emit_lan(app: &AppHandle, step: &str, message: impl Into<String>) {
    let _ = app.emit(
        "lan-progress",
        serde_json::json!({
            "step": step,
            "message": message.into(),
        }),
    );
}
