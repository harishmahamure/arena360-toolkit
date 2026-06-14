use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use tauri::{AppHandle, Manager};
use thiserror::Error;

use crate::powershell::{self, PsError};

#[derive(Debug, Error)]
pub enum BackupError {
    #[error("Backup error: {0}")]
    General(String),
    #[error("PowerShell error: {0}")]
    Ps(#[from] PsError),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupInfo {
    pub path: String,
    pub created_at: String,
    pub label: Option<String>,
}

pub fn backup_dir(app: &AppHandle) -> Result<PathBuf, BackupError> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|e| BackupError::General(e.to_string()))?
        .join("backups");

    fs::create_dir_all(&dir).map_err(|e| BackupError::General(e.to_string()))?;
    Ok(dir)
}

pub fn create_backup(app: &AppHandle, label: Option<String>) -> Result<BackupInfo, BackupError> {
    let result = powershell::run_script(
        app,
        "Invoke-CreateBackup.ps1",
        Some(serde_json::json!({ "label": label })),
        powershell::DEFAULT_TIMEOUT,
    )?;

    let path = result
        .get("path")
        .and_then(|v| v.as_str())
        .ok_or_else(|| BackupError::General("Backup script did not return path".into()))?
        .to_string();

    let created_at = result
        .get("created_at")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    Ok(BackupInfo {
        path,
        created_at,
        label,
    })
}

pub fn rollback(app: &AppHandle, backup_path: String) -> Result<Vec<powershell::StepResult>, BackupError> {
    let result = powershell::run_script(
        app,
        "Invoke-Rollback.ps1",
        Some(serde_json::json!({ "backupPath": backup_path })),
        powershell::LONG_TIMEOUT,
    )?;

    let steps: Vec<powershell::StepResult> = result
        .get("steps")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    Ok(steps)
}

pub fn list_backups(app: &AppHandle) -> Result<Vec<BackupInfo>, BackupError> {
    let dir = backup_dir(app)?;
    let mut backups = Vec::new();

    if let Ok(entries) = fs::read_dir(&dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("json") {
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Ok(meta) = serde_json::from_str::<serde_json::Value>(&content) {
                        backups.push(BackupInfo {
                            path: path.to_string_lossy().to_string(),
                            created_at: meta
                                .get("created_at")
                                .and_then(|v| v.as_str())
                                .unwrap_or("")
                                .to_string(),
                            label: meta
                                .get("label")
                                .and_then(|v| v.as_str())
                                .map(|s| s.to_string()),
                        });
                    }
                }
            }
        }
    }

    backups.sort_by(|a, b| b.created_at.cmp(&a.created_at));
    Ok(backups)
}
