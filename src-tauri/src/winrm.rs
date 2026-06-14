use serde::{Deserialize, Serialize};
use tauri::AppHandle;

use crate::powershell::{self, PsError};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteTarget {
    pub hostname: String,
    pub username: String,
    pub password: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteProgress {
    pub hostname: String,
    pub step: String,
    pub success: bool,
    pub message: String,
}

pub fn test_connection(app: &AppHandle, target: &RemoteTarget) -> Result<bool, PsError> {
    let result = powershell::run_script(
        app,
        "Invoke-TestWinRM.ps1",
        Some(serde_json::json!({
            "hostname": target.hostname,
            "username": target.username,
            "password": target.password,
        })),
        powershell::DEFAULT_TIMEOUT,
    )?;
    Ok(result
        .get("reachable")
        .and_then(|v| v.as_bool())
        .unwrap_or(false))
}

pub fn apply_profile_remote(
    app: &AppHandle,
    targets: Vec<RemoteTarget>,
    options: serde_json::Value,
) -> Result<Vec<RemoteProgress>, PsError> {
    let result = powershell::run_script(
        app,
        "Invoke-RemoteOptimize.ps1",
        Some(serde_json::json!({
            "targets": targets,
            "options": options,
        })),
        powershell::LONG_TIMEOUT,
    )?;

    let progress: Vec<RemoteProgress> = result
        .get("results")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    Ok(progress)
}
