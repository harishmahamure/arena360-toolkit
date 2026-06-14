mod backup;
mod commands;
mod powershell;
mod profiles;
mod winrm;

use tauri::Emitter;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .invoke_handler(tauri::generate_handler![
            commands::local::check_admin,
            commands::local::check_windows,
            commands::local::scan_bloatware,
            commands::local::apply_debloat,
            commands::local::audit_services,
            commands::local::apply_services,
            commands::local::apply_telemetry_off,
            commands::local::apply_win_update_disable,
            commands::local::apply_win_update_enable,
            commands::local::apply_gaming_optimize,
            commands::local::apply_gaming_profile,
            commands::local::create_backup,
            commands::local::rollback,
            commands::local::list_backups,
            commands::lan::get_subnet_config,
            commands::lan::scan_lan_devices,
            commands::lan::classify_lan_devices,
            commands::lan::lan_bulk_setup,
            commands::lan::stage_wallpaper_file,
            commands::lan::detect_installer_path,
            commands::lan::stage_installer_file,
            commands::lan::apply_desktop_customize,
            commands::lan::run_post_install_setup,
            commands::remote::test_winrm_connection,
            commands::remote::remote_apply_profile,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

pub fn emit_progress(app: &tauri::AppHandle, event: &str, payload: serde_json::Value) {
    let _ = app.emit(event, payload);
}
