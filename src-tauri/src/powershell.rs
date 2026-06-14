use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
#[cfg(target_os = "windows")]
use std::process::{Command, Stdio};
use tauri::{AppHandle, Manager};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum PsError {
    #[error("PowerShell script not found: {0}")]
    ScriptNotFound(String),
    #[error("PowerShell execution failed: {0}")]
    ExecutionFailed(String),
    #[error("Failed to parse PowerShell output: {0}")]
    ParseError(String),
    #[error("Platform not supported: PowerShell is Windows-only")]
    NotWindows,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepResult {
    pub step: String,
    pub success: bool,
    pub message: String,
}

#[cfg(target_os = "windows")]
pub fn resolve_script_path(app: &AppHandle, script_name: &str) -> Result<PathBuf, PsError> {
    let resource_dir = app
        .path()
        .resource_dir()
        .map_err(|e| PsError::ExecutionFailed(e.to_string()))?;

    let candidates = [
        resource_dir.join("scripts").join(script_name),
        resource_dir.join(script_name),
        PathBuf::from("src-tauri/resources/scripts").join(script_name),
    ];

    for path in candidates {
        if path.exists() {
            return Ok(path);
        }
    }

    Err(PsError::ScriptNotFound(script_name.to_string()))
}

pub fn resolve_manifest_path(app: &AppHandle, manifest_name: &str) -> Result<PathBuf, PsError> {
    let resource_dir = app
        .path()
        .resource_dir()
        .map_err(|e| PsError::ExecutionFailed(e.to_string()))?;

    let candidates = [
        resource_dir.join("manifests").join(manifest_name),
        resource_dir.join(manifest_name),
        PathBuf::from("src-tauri/resources/manifests").join(manifest_name),
    ];

    for path in candidates {
        if path.exists() {
            return Ok(path);
        }
    }

    Err(PsError::ScriptNotFound(manifest_name.to_string()))
}

#[cfg(target_os = "windows")]
pub fn run_script(
    app: &AppHandle,
    script_name: &str,
    args: Option<serde_json::Value>,
    _timeout_secs: u64,
) -> Result<serde_json::Value, PsError> {
    let script_path = resolve_script_path(app, script_name)?;
    run_script_at_path(&script_path, args, _timeout_secs)
}

#[cfg(not(target_os = "windows"))]
pub fn run_script(
    _app: &AppHandle,
    _script_name: &str,
    _args: Option<serde_json::Value>,
    _timeout_secs: u64,
) -> Result<serde_json::Value, PsError> {
    Err(PsError::NotWindows)
}

#[cfg(target_os = "windows")]
pub fn run_script_at_path(
    script_path: &Path,
    args: Option<serde_json::Value>,
    _timeout_secs: u64,
) -> Result<serde_json::Value, PsError> {
    let args_json = args
        .map(|v| v.to_string())
        .unwrap_or_else(|| "{}".to_string());

    let output = Command::new("powershell.exe")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            script_path.to_str().unwrap_or_default(),
            "-ConfigJson",
            &args_json,
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| PsError::ExecutionFailed(e.to_string()))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        return Err(PsError::ExecutionFailed(format!(
            "Exit {:?}: stderr={} stdout={}",
            output.status.code(),
            stderr.trim(),
            stdout.trim()
        )));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    parse_json_output(&stdout)
}

#[cfg(not(target_os = "windows"))]
pub fn run_script_at_path(
    _script_path: &Path,
    _args: Option<serde_json::Value>,
    _timeout_secs: u64,
) -> Result<serde_json::Value, PsError> {
    Err(PsError::NotWindows)
}

#[cfg(target_os = "windows")]
fn parse_json_output(stdout: &str) -> Result<serde_json::Value, PsError> {
    let trimmed = stdout.trim();
    if trimmed.is_empty() {
        return Ok(serde_json::json!({ "success": true }));
    }

    if let Ok(val) = serde_json::from_str(trimmed) {
        return Ok(val);
    }

    for line in trimmed.lines().rev() {
        let line = line.trim();
        if line.starts_with('{') || line.starts_with('[') {
            if let Ok(val) = serde_json::from_str(line) {
                return Ok(val);
            }
        }
    }

    Err(PsError::ParseError(format!(
        "No valid JSON in output: {}",
        &trimmed[..trimmed.len().min(200)]
    )))
}

pub fn is_windows() -> bool {
    cfg!(target_os = "windows")
}

#[cfg(target_os = "windows")]
pub fn is_elevated() -> bool {
    use windows::Win32::Foundation::HANDLE;
    use windows::Win32::Security::{
        GetTokenInformation, TokenElevation, TOKEN_ELEVATION, TOKEN_QUERY,
    };
    use windows::Win32::System::Threading::{GetCurrentProcess, OpenProcessToken};

    unsafe {
        let mut token = HANDLE::default();
        if OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token).is_err() {
            return false;
        }

        let mut elevation = TOKEN_ELEVATION::default();
        let mut size = 0u32;
        let result = GetTokenInformation(
            token,
            TokenElevation,
            Some(&mut elevation as *mut _ as *mut _),
            std::mem::size_of::<TOKEN_ELEVATION>() as u32,
            &mut size,
        );

        result.is_ok() && elevation.TokenIsElevated.as_bool()
    }
}

#[cfg(not(target_os = "windows"))]
pub fn is_elevated() -> bool {
    false
}

pub const DEFAULT_TIMEOUT: u64 = 120;
pub const LONG_TIMEOUT: u64 = 300;
