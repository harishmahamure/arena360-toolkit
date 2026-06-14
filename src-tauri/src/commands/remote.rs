use tauri::{AppHandle, Emitter};

use crate::profiles::GamingProfileOptions;
use crate::winrm::{self, RemoteProgress, RemoteTarget};

#[tauri::command]
pub async fn test_winrm_connection(
    app: AppHandle,
    hostname: String,
    username: String,
    password: String,
) -> Result<bool, String> {
    let target = RemoteTarget {
        hostname,
        username,
        password,
    };
    winrm::test_connection(&app, &target).map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn remote_apply_profile(
    app: AppHandle,
    targets: Vec<RemoteTarget>,
    options: GamingProfileOptions,
) -> Result<Vec<RemoteProgress>, String> {
    let opts_json = serde_json::to_value(&options).map_err(|e| e.to_string())?;

    let results = winrm::apply_profile_remote(&app, targets, opts_json)
        .map_err(|e| e.to_string())?;

    for result in &results {
        let _ = app.emit("remote-progress", result);
    }

    Ok(results)
}
