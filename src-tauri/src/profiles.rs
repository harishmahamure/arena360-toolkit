use serde::{Deserialize, Serialize};
use std::fs;
use tauri::AppHandle;

use crate::powershell::{self, PsError};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GamingProfileOptions {
    pub dry_run: bool,
    pub debloat_preset: String,
    pub disable_win_update: bool,
    pub disable_telemetry: bool,
    pub disable_recommended_services: bool,
    pub apply_gaming_tweaks: bool,
    pub create_restore_point: bool,
}

impl Default for GamingProfileOptions {
    fn default() -> Self {
        Self {
            dry_run: false,
            debloat_preset: "standard".to_string(),
            disable_win_update: true,
            disable_telemetry: true,
            disable_recommended_services: true,
            apply_gaming_tweaks: true,
            create_restore_point: true,
        }
    }
}

pub fn load_manifest(app: &AppHandle, name: &str) -> Result<serde_json::Value, PsError> {
    let path = powershell::resolve_manifest_path(app, name)?;
    let content = fs::read_to_string(&path)
        .map_err(|e| PsError::ExecutionFailed(format!("Failed to read manifest: {e}")))?;
    serde_json::from_str(&content)
        .map_err(|e| PsError::ParseError(format!("Invalid manifest JSON: {e}")))
}

pub fn get_debloat_ids_for_preset(
    app: &AppHandle,
    preset: &str,
) -> Result<Vec<String>, PsError> {
    let apps: serde_json::Value = load_manifest(app, "bloatware-apps.json")?;
    let appx: serde_json::Value = load_manifest(app, "bloatware-appx.json")?;

    let mut ids = Vec::new();

    for manifest in [&apps, &appx] {
        if let Some(items) = manifest.get("items").and_then(|v| v.as_array()) {
            for item in items {
                let presets = item
                    .get("presets")
                    .and_then(|v| v.as_array())
                    .map(|arr| {
                        arr.iter()
                            .filter_map(|p| p.as_str().map(|s| s.to_lowercase()))
                            .collect::<Vec<_>>()
                    })
                    .unwrap_or_default();

                let preset_lower = preset.to_lowercase();
                let include = presets.contains(&preset_lower)
                    || (preset_lower == "standard" && presets.contains(&"light".to_string()));

                if include {
                    if let Some(id) = item.get("id").and_then(|v| v.as_str()) {
                        ids.push(id.to_string());
                    }
                }
            }
        }
    }

    Ok(ids)
}

pub fn get_recommended_service_names(app: &AppHandle) -> Result<Vec<String>, PsError> {
    let baseline: serde_json::Value = load_manifest(app, "services-baseline.json")?;
    let mut names = Vec::new();

    if let Some(services) = baseline.get("services").and_then(|v| v.as_array()) {
        for svc in services {
            let category = svc
                .get("category")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            if category == "gaming_safe_disable" {
                if let Some(name) = svc.get("name").and_then(|v| v.as_str()) {
                    names.push(name.to_string());
                }
            }
        }
    }

    Ok(names)
}
