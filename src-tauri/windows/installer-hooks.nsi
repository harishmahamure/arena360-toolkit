!macro NSIS_HOOK_POSTINSTALL
  DetailPrint "Running Game Zone Optimizer post-install setup (administrator required)..."

  ; Tauri bundles scripts under resources/scripts/
  IfFileExists "$INSTDIR\resources\scripts\Invoke-PostInstallSetup.ps1" postinstall_resources postinstall_scripts
  postinstall_resources:
    StrCpy $R0 "$INSTDIR\resources\scripts\Invoke-PostInstallSetup.ps1"
    Goto postinstall_run
  postinstall_scripts:
    StrCpy $R0 "$INSTDIR\scripts\Invoke-PostInstallSetup.ps1"

  postinstall_run:
  IfFileExists "$R0" postinstall_found postinstall_missing
  postinstall_found:
    ; RunAs triggers UAC / admin credential prompt when the installer is not elevated
    ExecShell "runas" "powershell.exe" "-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File $\"$R0$\" -Elevated" SW_SHOWNORMAL
    Goto postinstall_done
  postinstall_missing:
    DetailPrint "Post-install script not found: $R0"

  postinstall_done:
!macroend
