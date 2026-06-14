use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter};

use crate::backup::{self, BackupInfo};
use crate::powershell::{self, StepResult};
use crate::profiles::{self, GamingProfileOptions};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdminStatus {
    pub is_windows: bool,
    pub is_elevated: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BloatItem {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub installed: bool,
    pub optional: bool,
    pub presets: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceItem {
    pub name: String,
    pub display_name: String,
    pub status: String,
    pub start_type: String,
    pub category: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileResult {
    pub steps: Vec<StepResult>,
    pub backup_path: Option<String>,
}

#[tauri::command]
pub fn check_windows() -> bool {
    powershell::is_windows()
}

#[tauri::command]
pub fn check_admin() -> AdminStatus {
    AdminStatus {
        is_windows: powershell::is_windows(),
        is_elevated: powershell::is_elevated(),
    }
}

#[tauri::command]
pub async fn scan_bloatware(app: AppHandle) -> Result<Vec<BloatItem>, String> {
    let result = powershell::run_script(
        &app,
        "Invoke-DebloatScan.ps1",
        None,
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let items: Vec<BloatItem> = result
        .get("items")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    Ok(items)
}

#[tauri::command]
pub async fn apply_debloat(
    app: AppHandle,
    ids: Vec<String>,
    dry_run: bool,
) -> Result<Vec<StepResult>, String> {
    emit_step(&app, "debloat", "Starting debloat...");

    let result = powershell::run_script(
        &app,
        "Invoke-DebloatApply.ps1",
        Some(serde_json::json!({ "ids": ids, "dryRun": dry_run })),
        powershell::LONG_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let steps = extract_steps(&result);
    emit_steps(&app, &steps);
    Ok(steps)
}

#[tauri::command]
pub async fn audit_services(app: AppHandle) -> Result<Vec<ServiceItem>, String> {
    let result = powershell::run_script(
        &app,
        "Get-ServiceAudit.ps1",
        None,
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let items: Vec<ServiceItem> = result
        .get("services")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    Ok(items)
}

#[tauri::command]
pub async fn apply_services(
    app: AppHandle,
    service_names: Vec<String>,
    action: String,
    dry_run: bool,
) -> Result<Vec<StepResult>, String> {
    let result = powershell::run_script(
        &app,
        "Invoke-ServiceApply.ps1",
        Some(serde_json::json!({
            "serviceNames": service_names,
            "action": action,
            "dryRun": dry_run,
        })),
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let steps = extract_steps(&result);
    emit_steps(&app, &steps);
    Ok(steps)
}

#[tauri::command]
pub async fn apply_telemetry_off(app: AppHandle, dry_run: bool) -> Result<Vec<StepResult>, String> {
    emit_step(&app, "telemetry", "Disabling telemetry...");

    let result = powershell::run_script(
        &app,
        "Invoke-TelemetryDisable.ps1",
        Some(serde_json::json!({ "dryRun": dry_run })),
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let steps = extract_steps(&result);
    emit_steps(&app, &steps);
    Ok(steps)
}

#[tauri::command]
pub async fn apply_win_update_disable(
    app: AppHandle,
    dry_run: bool,
) -> Result<Vec<StepResult>, String> {
    emit_step(&app, "win_update", "Disabling Windows Update...");

    let result = powershell::run_script(
        &app,
        "Invoke-WinUpdateDisable.ps1",
        Some(serde_json::json!({ "dryRun": dry_run })),
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let steps = extract_steps(&result);
    emit_steps(&app, &steps);
    Ok(steps)
}

#[tauri::command]
pub async fn apply_win_update_enable(app: AppHandle) -> Result<Vec<StepResult>, String> {
    let result = powershell::run_script(
        &app,
        "Invoke-WinUpdateEnable.ps1",
        None,
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let steps = extract_steps(&result);
    emit_steps(&app, &steps);
    Ok(steps)
}

#[tauri::command]
pub async fn apply_gaming_optimize(
    app: AppHandle,
    options: serde_json::Value,
    dry_run: bool,
) -> Result<Vec<StepResult>, String> {
    emit_step(&app, "gaming", "Applying gaming optimizations...");

    let result = powershell::run_script(
        &app,
        "Invoke-GamingOptimize.ps1",
        Some(serde_json::json!({
            "options": options,
            "dryRun": dry_run,
        })),
        powershell::DEFAULT_TIMEOUT,
    )
    .map_err(|e| e.to_string())?;

    let steps = extract_steps(&result);
    emit_steps(&app, &steps);
    Ok(steps)
}

#[tauri::command]
pub async fn apply_gaming_profile(
    app: AppHandle,
    options: GamingProfileOptions,
) -> Result<ProfileResult, String> {
    let mut all_steps = Vec::new();
    let mut backup_path = None;

    emit_step(&app, "profile", "Starting Gaming Profile...");

    if options.create_restore_point && !options.dry_run {
        match backup::create_backup(&app, Some("pre-gaming-profile".into())) {
            Ok(info) => {
                backup_path = Some(info.path.clone());
                all_steps.push(StepResult {
                    step: "backup".into(),
                    success: true,
                    message: format!("Backup created: {}", info.path),
                });
            }
            Err(e) => {
                all_steps.push(StepResult {
                    step: "backup".into(),
                    success: false,
                    message: e.to_string(),
                });
            }
        }
    }

    if !options.dry_run {
        if let Ok(steps) = powershell::run_script(
            &app,
            "Invoke-CreateRestorePoint.ps1",
            None,
            powershell::DEFAULT_TIMEOUT,
        ) {
            all_steps.extend(extract_steps(&steps));
        }
    }

    if options.disable_telemetry {
        match apply_telemetry_off(app.clone(), options.dry_run).await {
            Ok(steps) => all_steps.extend(steps),
            Err(e) => all_steps.push(StepResult {
                step: "telemetry".into(),
                success: false,
                message: e,
            }),
        }
    }

    let debloat_ids =
        profiles::get_debloat_ids_for_preset(&app, &options.debloat_preset).unwrap_or_default();
    if !debloat_ids.is_empty() {
        match apply_debloat(app.clone(), debloat_ids, options.dry_run).await {
            Ok(steps) => all_steps.extend(steps),
            Err(e) => all_steps.push(StepResult {
                step: "debloat".into(),
                success: false,
                message: e,
            }),
        }
    }

    if options.disable_recommended_services {
        let service_names = profiles::get_recommended_service_names(&app).unwrap_or_default();
        if !service_names.is_empty() {
            match apply_services(
                app.clone(),
                service_names,
                "disable".into(),
                options.dry_run,
            )
            .await
            {
                Ok(steps) => all_steps.extend(steps),
                Err(e) => all_steps.push(StepResult {
                    step: "services".into(),
                    success: false,
                    message: e,
                }),
            }
        }
    }

    if options.disable_win_update {
        match apply_win_update_disable(app.clone(), options.dry_run).await {
            Ok(steps) => all_steps.extend(steps),
            Err(e) => all_steps.push(StepResult {
                step: "win_update".into(),
                success: false,
                message: e,
            }),
        }
    }

    if options.apply_gaming_tweaks {
        let gaming_opts = profiles::load_manifest(&app, "gaming-profile.json").unwrap_or_default();
        match apply_gaming_optimize(app.clone(), gaming_opts.clone(), options.dry_run).await {
            Ok(steps) => all_steps.extend(steps),
            Err(e) => all_steps.push(StepResult {
                step: "gaming".into(),
                success: false,
                message: e,
            }),
        }

        if gaming_opts
            .get("removeDesktopShortcuts")
            .and_then(|v| v.as_bool())
            .unwrap_or(false)
        {
            match powershell::run_script(
                &app,
                "Invoke-DesktopCustomize.ps1",
                Some(serde_json::json!({
                    "wallpaperPath": "C:\\ProgramData\\GameZoneOptimizer\\wallpaper.jpg",
                    "removeShortcuts": true,
                    "setWallpaper": false,
                    "dryRun": options.dry_run,
                })),
                powershell::DEFAULT_TIMEOUT,
            ) {
                Ok(result) => all_steps.extend(extract_steps(&result)),
                Err(e) => all_steps.push(StepResult {
                    step: "shortcuts".into(),
                    success: false,
                    message: e.to_string(),
                }),
            }
        }
    }

    let _ = app.emit(
        "profile-complete",
        serde_json::json!({
            "steps": all_steps,
            "backupPath": backup_path,
        }),
    );

    Ok(ProfileResult {
        steps: all_steps,
        backup_path,
    })
}

#[tauri::command]
pub async fn create_backup(
    app: AppHandle,
    label: Option<String>,
) -> Result<BackupInfo, String> {
    backup::create_backup(&app, label).map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn rollback(app: AppHandle, backup_path: String) -> Result<Vec<StepResult>, String> {
    backup::rollback(&app, backup_path)
        .map_err(|e| e.to_string())
        .map(|steps| {
            emit_steps(&app, &steps);
            steps
        })
}

#[tauri::command]
pub async fn list_backups(app: AppHandle) -> Result<Vec<BackupInfo>, String> {
    backup::list_backups(&app).map_err(|e| e.to_string())
}

fn extract_steps(result: &serde_json::Value) -> Vec<StepResult> {
    result
        .get("steps")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_else(|| {
            vec![StepResult {
                step: "result".into(),
                success: result
                    .get("success")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(true),
                message: result
                    .get("message")
                    .or_else(|| result.get("error"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("Completed")
                    .to_string(),
            }]
        })
}

fn emit_step(app: &AppHandle, step: &str, message: &str) {
    let _ = app.emit(
        "operation-progress",
        serde_json::json!({
            "step": step,
            "success": true,
            "message": message,
        }),
    );
}

fn emit_steps(app: &AppHandle, steps: &[StepResult]) {
    for step in steps {
        let _ = app.emit("operation-progress", step);
    }
}
