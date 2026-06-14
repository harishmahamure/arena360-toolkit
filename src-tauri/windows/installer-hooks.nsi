!macro NSIS_HOOK_POSTINSTALL
  DetailPrint "Running Game Zone Optimizer post-install setup..."
  nsExec::ExecToLog 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { $$paths = @(\"$INSTDIR\scripts\Invoke-PostInstallSetup.ps1\", \"$INSTDIR\resources\scripts\Invoke-PostInstallSetup.ps1\"); foreach ($$p in $$paths) { if (Test-Path $$p) { & $$p; exit 0 } }; Write-Host \"Post-install script not found\" }"'
  Pop $0
  DetailPrint "Post-install setup exit code: $0"
!macroend
