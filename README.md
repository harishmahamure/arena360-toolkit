# Game Zone Optimizer

**All-in-one Windows toolkit for gaming cafes and game zones.** Discover LAN devices, debloat stations, disable telemetry and Windows Update, audit services, apply gaming optimizations, and manage everything from one admin PC — locally or over WinRM.

| | |
|---|---|
| **Stack** | Tauri v2 (Rust) + React 19 + TypeScript + PowerShell 5.1+ |
| **Platform** | Windows 10 / 11 only |
| **Elevation** | Administrator required (UAC on launch + installer hook) |
| **Version** | 0.1.0 |

---

## Table of Contents

1. [How to Use This Application](#how-to-use-this-application)
2. [Installation](#installation)
3. [Deployment Workflows](#deployment-workflows)
4. [Page-by-Page Guide](#page-by-page-guide)
5. [LAN Discovery & Bulk Setup](#lan-discovery--bulk-setup)
6. [Safety & Rollback](#safety--rollback)
7. [What It Does](#what-it-does)
8. [Requirements](#requirements)
9. [Building from Source](#building-from-source)
10. [Customizing Manifests](#customizing-manifests)
11. [Troubleshooting](#troubleshooting)
12. [Windows Update Warning](#windows-update-warning)

---

## How to Use This Application

### Before you start

1. **Use Windows 10 or 11** — the app does not run optimizations on macOS or Linux (UI dev only).
2. **Run as Administrator** — right-click the app or installer → **Run as administrator**. A yellow banner appears at the top if you are not elevated; system changes are blocked until you restart elevated.
3. **Use the same local admin password** on every gaming PC (typical game-zone setup). Default username is `Administrator`; change it in the **LAN** or **Remote** tab if your venue uses a different account.
4. **Connect the admin PC to the same LAN** as gaming stations (Ethernet recommended).

### Navigation

The left sidebar has nine sections:

| Tab | Purpose |
|-----|---------|
| **Dashboard** | One-click full optimization + rollback |
| **LAN** | Discover stations, deploy installer, bulk optimize |
| **Uninstall** | Remove bloatware with presets |
| **Services** | Audit and disable non-essential services |
| **Privacy** | Turn off telemetry and consumer features |
| **Windows Update** | Disable or re-enable automatic updates |
| **Gaming** | Apply performance tweaks only |
| **Remote** | Push profile to specific PCs by hostname/IP |
| **Logs** | View all operation results |

Every action writes to **Logs** automatically. Open **Logs** anytime to see success/failure per step.

---

### Scenario 1 — Optimize one gaming PC (local)

Use this when you are sitting at a single station.

1. Install the app (see [Installation](#installation)) and launch **as Administrator**.
2. Open **Dashboard**.
3. Confirm the status cards show **Windows detected** and **Running elevated**.
4. Click **Apply Gaming Profile**.
5. Wait for completion. Each step (backup, restore point, debloat, telemetry, services, Windows Update, gaming tweaks) appears in **Logs**.
6. Reboot the PC and test games.

**What the profile does automatically:**

- Creates a JSON settings backup
- Creates a system restore point (when OS allows)
- Disables telemetry
- Removes bloatware (Standard preset)
- Disables recommended non-essential services
- Fully disables Windows Update
- Applies gaming performance tweaks
- Removes desktop shortcuts (when enabled in `gaming-profile.json`)

**To undo:** On **Dashboard**, click **Rollback Last Backup** (restores services/registry from the last JSON backup).

---

### Scenario 2 — Manage an entire game zone from one admin PC (recommended)

Use this when you have one management PC and many gaming stations on the LAN.

#### Phase A — Prepare stations (pick one method)

**Method 1: Remote installer (no physical access needed after WinRM)**

1. On the admin PC, install Game Zone Optimizer and run **as Administrator**.
2. Open **LAN**.
3. Under **Remote Installer Deployment**, confirm the setup `.exe` is detected, or click **Browse Installer** to select `Game Zone Optimizer_*_x64-setup.exe`.
4. Enter **Username** and **Password** (shared local admin).
5. Click **Scan LAN**.
6. Select Windows stations in the device table.
7. If stations lack WinRM, click **Enable WinRM on Selected** first.
8. Click **Deploy Installer to Selected** — copies the installer over SMB and runs silent install (`/S`) on each PC.
9. Post-install hook on each station enables WinRM automatically.

**Method 2: USB / manual install on each PC**

1. Copy `Game Zone Optimizer_*_x64-setup.exe` to each gaming PC.
2. Run the installer **as Administrator** on each station.
3. Post-install automatically copies scripts and enables WinRM.

#### Phase B — Optimize all stations from admin PC

1. On the admin PC, open **LAN**.
2. Enter admin **Username** and **Password**.
3. Click **Scan LAN** — review tabs: **All**, **Windows**, **Other**, **WinRM Ready**, **Needs WinRM**.
4. Select all Windows gaming stations (checkboxes in the table).
5. Run in order:
   - **Enable WinRM on Selected** (skip if already WinRM Ready)
   - **Copy Setup Files** (copies PowerShell scripts to `C:\ProgramData\GameZoneOptimizer\`)
   - **Optimize Selected** (full gaming profile on each station remotely)
6. Optional — under **Desktop Customization**:
   - **Choose Wallpaper** → pick a `.jpg`/`.png`/`.bmp`
   - **Apply Wallpaper & Clean Desktop** (sets wallpaper + removes all desktop shortcuts)
7. Check **Logs** for per-station results.

#### Phase C — Verify

- [ ] All stations appear under **WinRM Ready**
- [ ] **Logs** shows successful optimize steps for each IP
- [ ] Boot one station and confirm games launch cleanly
- [ ] Confirm desktops match your venue branding (if wallpaper applied)

---

### Scenario 3 — Customize individual modules

Use individual tabs when you do not want the full profile, or need fine-grained control.

| Goal | Tab | Steps |
|------|-----|-------|
| Remove specific apps only | **Uninstall** | **Scan** loads installed bloatware → pick preset (Light / Standard / Aggressive) or check items manually → enable **Dry run** to preview → **Apply** |
| Disable specific services | **Services** | **Refresh Audit** → filter by category → **Select recommended** or pick services → **Dry run** → **Disable Selected** |
| Telemetry only | **Privacy** | **Preview Changes** → **Apply Telemetry Off** |
| Windows Update only | **Windows Update** | **Preview Disable** → **Disable Windows Update** (confirmation dialog) |
| Performance tweaks only | **Gaming** | **Preview** → **Apply Gaming Tweaks** |
| One-off remote PC | **Remote** | Enter hostname/IP + credentials → **Test WinRM** → add to target list → **Push Gaming Profile** |

**Dry run tip:** **Uninstall**, **Services**, **LAN** (Desktop Customization checkbox), and several other pages support dry run. Always preview on one test PC before bulk LAN operations.

---

### Scenario 4 — Brand desktops across the LAN

1. Open **LAN** on the admin PC.
2. Under **Desktop Customization**, click **Choose Wallpaper** and select your venue image.
3. Enter admin credentials and scan/select stations.
4. Click **Apply Wallpaper & Clean Desktop**.

**What happens on each station:**

- Wallpaper copied to `C:\ProgramData\GameZoneOptimizer\wallpaper.jpg`
- Wallpaper set for Default user template and all existing profiles
- All `.lnk` and `.url` shortcuts removed from Public and user desktops
- Recycle Bin is **not** removed

**Shortcuts only:** Click **Remove Shortcuts Only** if you do not want to change wallpaper.

**Warning:** Game launchers stored on the Desktop will be removed. Keep launchers in the Start menu or taskbar.

---

### Scenario 5 — Ongoing maintenance

| Task | How |
|------|-----|
| Check what ran | **Logs** tab |
| Undo last local changes | **Dashboard** → **Rollback Last Backup** |
| Re-enable Windows Update | **Windows Update** → **Re-enable Windows Update** |
| Patch stations manually | Re-enable updates temporarily, or use WSUS/offline media |
| Add a new gaming PC | **LAN** → deploy installer or enable WinRM → **Optimize Selected** |
| Update bloatware list | Edit manifests, rebuild installer (see [Customizing Manifests](#customizing-manifests)) |

---

## Installation

### Download / build the installer

**From CI artifacts:** Download `game-zone-optimizer-windows-x64` from GitHub Actions after a successful build.

**Build locally:**

```powershell
pnpm install
pnpm tauri build
```

Output:

```
src-tauri/target/release/bundle/nsis/Game Zone Optimizer_0.1.0_x64-setup.exe
```

### Install on a gaming PC

1. Run `Game Zone Optimizer_*_x64-setup.exe` (double-click is fine — elevation is requested automatically).
2. Complete the NSIS wizard (per-user install).
3. **Administrator prompt** — after install, a dialog explains that admin access is needed, then Windows shows a **UAC prompt**. Click **Yes**, or enter administrator username/password if you are on a standard account.
4. Post-install runs automatically (elevated):
   - Copies scripts to `C:\ProgramData\GameZoneOptimizer\scripts\`
   - Copies manifests to `C:\ProgramData\GameZoneOptimizer\manifests\`
   - Enables **WinRM** (firewall rule on port 5985)
   - Writes `C:\ProgramData\GameZoneOptimizer\install-state.json` (`winrm_ready: true` on success)
5. Launch the app **as Administrator** and click **Apply Gaming Profile** on **Dashboard** (optional if you will optimize remotely from admin PC).

If you cancel the UAC prompt, the app still installs but WinRM setup is skipped. Re-run post-install manually (see below) or use **LAN → Enable WinRM on Selected** from the admin PC.

### Install on the admin PC

Install the same application on your management PC. You will primarily use the **LAN** and **Remote** tabs from this machine.

### Manual post-install (if hook did not run)

Double-click or run — the script prompts for admin automatically:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\Programs\Game Zone Optimizer\resources\scripts\Invoke-PostInstallSetup.ps1"
```

Or from Program Files if installed per-machine:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:ProgramFiles\Game Zone Optimizer\resources\scripts\Invoke-PostInstallSetup.ps1"
```

---

## Deployment Workflows

```
┌─────────────────────────────────────────────────────────────────┐
│  WORKFLOW A — Install on every PC (simplest)                    │
│  For each PC: run installer → Dashboard → Apply Gaming Profile  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  WORKFLOW B — Admin PC manages entire LAN (recommended)         │
│  Admin PC: LAN → Scan → Enable WinRM → Copy Setup → Optimize    │
│  Optional: Deploy Installer / Wallpaper from same LAN tab       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  WORKFLOW C — Hybrid                                            │
│  Critical stations: local install + profile                     │
│  Remaining stations: LAN tab bulk actions                       │
│  One-offs: Remote tab                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Page-by-Page Guide

### Dashboard

| Element | Action |
|---------|--------|
| Status cards | Shows platform, elevation, and last backup time |
| **Apply Gaming Profile** | Runs all optimization modules in one click |
| **Rollback Last Backup** | Restores prior service/registry state from JSON backup |

Blocked when not elevated. Creates backup + restore point before changes.

### LAN

| Section | Buttons | Purpose |
|---------|---------|---------|
| Network cards | — | Shows interface, gateway, scan range (default pool `.100`–`.200`) |
| Remote Installer Deployment | **Browse Installer**, **Deploy Installer to Selected** | Push NSIS setup to stations via SMB + silent install |
| Desktop Customization | **Choose Wallpaper**, **Apply Wallpaper & Clean Desktop**, **Remove Shortcuts Only** | Brand desktops across LAN |
| Admin Credentials | Username / Password fields | Shared local admin for all remote actions |
| Toolbar | **Scan LAN**, **Enable WinRM on Selected**, **Copy Setup Files**, **Optimize Selected** | Core bulk setup flow |
| Device table | Checkboxes + filter tabs | Select targets; filter by Windows / WinRM status |

**Dry run** checkbox (Desktop Customization): previews wallpaper/shortcut changes and remote installer copy without applying.

### Uninstall

1. Apps load automatically on page open.
2. Choose preset: **Light**, **Standard**, or **Aggressive**.
3. Check/uncheck individual apps.
4. **Dry run** is on by default — uncheck to actually remove.
5. Click **Apply Selected**.

| Preset | Typical removals |
|--------|------------------|
| Light | Candy Crush, News, Weather, Solitaire |
| Standard | Light + Teams consumer, Copilot, Skype |
| Aggressive | Standard + Xbox Game Bar, OneDrive (optional items) |

### Services

1. **Refresh Audit** loads all services with category badges.
2. Filter: Essential / Gaming safe disable / Contextual / Unknown.
3. **Select recommended** pre-selects gaming-safe disables.
4. **Dry run** then **Disable Selected**.

Essential services (RpcSs, PlugPlay, Winmgmt, etc.) are never modified.

### Privacy

- **Preview Changes** — dry run
- **Apply Telemetry Off** — disables DiagTrack, CEIP tasks, advertising ID, consumer features

### Windows Update

- **Preview Disable** — dry run
- **Disable Windows Update** — requires confirmation dialog; stops `wuauserv`, `UsoSvc`, `WaaSMedicSvc`
- **Re-enable Windows Update** — restores update services

### Gaming

- **Preview** — dry run of performance tweaks
- **Apply Gaming Tweaks** — power plan, Game Mode, SysMain/Search off, network latency tweaks, etc.

Does not include debloat, telemetry, or Windows Update (use **Dashboard** profile for those).

### Remote

1. Enter hostname or IP, username, password.
2. **Test WinRM** — verify connectivity.
3. **Add Target** — build a target list.
4. **Push Gaming Profile** — applies full profile to all targets (no local restore point on remote).

### Logs

Live feed of every operation: timestamp, step name, success/failure, message. Use this to debug failed LAN or remote operations.

---

## LAN Discovery & Bulk Setup

### Scan process

1. **Scan LAN** pings the configured pool range (ICMP, 1-second timeout per address).
2. Resolves hostnames via DNS reverse lookup.
3. Reads MAC addresses from the ARP table.
4. Classifies devices by open ports (445 SMB → Windows; 5985 → WinRM).
5. Tests WinRM with credentials when password is provided.

### Filter tabs

| Tab | Shows |
|-----|-------|
| All | Every discovered device |
| Windows | Devices with SMB port 445 open |
| Other | Non-Windows (phones, routers, consoles) |
| WinRM Ready | Windows PCs with WinRM reachable |
| Needs WinRM | Windows PCs without WinRM |

### Bulk actions

| Button | Effect |
|--------|--------|
| **Enable WinRM on Selected** | Remotely runs WinRM bootstrap |
| **Copy Setup Files** | Copies PS scripts to `C:\ProgramData\GameZoneOptimizer\` |
| **Optimize Selected** | Full gaming profile on each station |
| **Deploy Installer to Selected** | SMB copy + silent NSIS install |
| **Apply Wallpaper & Clean Desktop** | Wallpaper + shortcut cleanup |

### Remote installer details

**Auto-detect order for setup `.exe`:**

1. `%APPDATA%\GameZoneOptimizer\staging\installer.exe`
2. Directory of the running app (`*setup*.exe` or `Game Zone Optimizer*.exe`)
3. Parent of install directory
4. `%USERPROFILE%\Downloads\*setup*.exe` (newest)

**Per-station flow:**

- Copy to `\\<ip>\C$\ProgramData\GameZoneOptimizer\installer.exe`
- WinRM runs `installer.exe /S`
- Verifies install via uninstall registry keys
- Skips if already installed

**Requirements:** WinRM enabled, File and Printer Sharing (SMB), shared local admin credentials.

---

## Safety & Rollback

| Feature | Description |
|---------|-------------|
| Administrator check | Yellow banner if not elevated; destructive actions blocked |
| Restore point | Created before full Gaming Profile (when OS allows) |
| JSON backup | `%APPDATA%\GameZoneOptimizer\backups\backup_YYYY-MM-DD_HH-mm-ss.json` |
| Rollback | **Dashboard** → **Rollback Last Backup** |
| Dry run | Preview on Uninstall, Services, Privacy, Gaming, Windows Update, LAN |
| Essential service guard | Critical services never disabled |
| Danger dialog | Windows Update disable requires explicit confirmation |

---

## What It Does

| Module | What it does |
|--------|----------------|
| **LAN Discovery** | Auto-detect subnet, scan devices, classify Windows vs other, check WinRM |
| **Remote Installer** | Push NSIS setup from admin PC via SMB + silent install |
| **Desktop Customize** | Admin-picked wallpaper + remove desktop shortcuts across LAN |
| **Bulk LAN Setup** | Enable WinRM, copy scripts, optimize multiple stations |
| **Debloat** | Remove bloatware (Light / Standard / Aggressive presets) |
| **Telemetry Off** | Disable DiagTrack, CEIP, advertising ID, consumer features |
| **Windows Update** | Fully disable automatic updates (re-enable available) |
| **Services Audit** | List services; recommend safe-to-disable items for gaming |
| **Gaming Tweaks** | High performance power plan, Game Mode, network/input tweaks |
| **Gaming Profile** | One-click orchestration of all modules |
| **Remote Push** | Apply profile to specific targets over WinRM |
| **Rollback** | Restore services and registry from JSON backup |

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  React UI (Dashboard, LAN, Uninstall, Services, Remote…)   │
└──────────────────────────┬──────────────────────────────────┘
                           │ Tauri invoke / events
┌──────────────────────────▼──────────────────────────────────┐
│  Rust backend (commands, profile orchestration, backup)      │
└──────────────────────────┬──────────────────────────────────┘
                           │ powershell.exe -File script.ps1
┌──────────────────────────▼──────────────────────────────────┐
│  Bundled PowerShell modules + JSON manifests                  │
└──────────────────────────┬──────────────────────────────────┘
                           │ WinRM (admin → gaming PCs)
┌──────────────────────────▼──────────────────────────────────┐
│  Remote gaming stations                                     │
└─────────────────────────────────────────────────────────────┘
```

Rust orchestrates; PowerShell performs Windows operations; JSON manifests hold venue-specific lists.

---

## Requirements

### Admin PC

| Requirement | Notes |
|-------------|-------|
| Windows 10 or 11 | Build and runtime are Windows-only |
| Administrator account | UAC elevation required |
| PowerShell 5.1+ | Included with Windows |
| Ethernet LAN | Same subnet as gaming stations |
| Shared local admin creds | Same username/password on all gaming PCs |

### Gaming PCs

| Requirement | Notes |
|-------------|-------|
| Windows 10 or 11 | Pro recommended for WinRM |
| Local Administrator | Same credentials as admin PC |
| Network connectivity | Reachable on LAN (ping + SMB/WinRM) |

### Development

| Tool | Version |
|------|---------|
| Node.js | 18+ |
| pnpm | 9+ |
| Rust | stable (MSVC on Windows) |
| Visual Studio Build Tools | C++ workload for Windows builds |

---

## Building from Source

### Windows (full build)

```powershell
git clone <your-repo-url> game-zone-setup
cd game-zone-setup
pnpm install
pnpm tauri build
```

### Development

```powershell
pnpm install
pnpm tauri dev    # Full app (run as Administrator on Windows)
```

```bash
# macOS — UI only; PowerShell commands return "Windows only"
pnpm install
pnpm dev
```

### npm scripts

| Script | Purpose |
|--------|---------|
| `pnpm dev` | Frontend dev server |
| `pnpm build` | Production frontend bundle |
| `pnpm tauri dev` | Full app in dev mode |
| `pnpm tauri build` | NSIS installer |

### CI

GitHub Actions workflow `.github/workflows/build-windows.yml` builds the NSIS installer on `windows-latest` and uploads artifact `game-zone-optimizer-windows-x64`.

---

## Customizing Manifests

Edit JSON in `src-tauri/resources/manifests/`, then rebuild (`pnpm tauri build`).

### `bloatware-apps.json` / `bloatware-appx.json`

```json
{
  "id": "xbox-game-bar",
  "name": "Xbox Game Bar",
  "kind": "appx",
  "optional": true,
  "presets": ["aggressive"],
  "patterns": ["*XboxGamingOverlay*"]
}
```

### `services-baseline.json`

Categories: `essential`, `gaming_safe_disable`, `contextual`, `unknown`

### `gaming-profile.json`

```json
{
  "powerPlan": "high_performance",
  "gameMode": true,
  "removeDesktopShortcuts": true,
  "applyWallpaper": false
}
```

Set `removeDesktopShortcuts: true` to include desktop cleanup in **Apply Gaming Profile** on the local PC.

---

## Troubleshooting

### "Run as Administrator" banner persists

Right-click the app → **Run as administrator**.

### LAN scan finds 0 devices

- Confirm admin PC is on the same subnet
- Check Windows Firewall allows ICMP on private network
- Verify stations are powered on and on Ethernet
- Review scan range in `Get-SubnetConfig.ps1` pool settings

### WinRM connection failed

1. On gaming PC: run `Enable-WinRM.ps1` as Administrator (or use **Enable WinRM on Selected**)
2. From admin PC: `Test-WSMan -ComputerName <ip>`
3. Confirm credentials match local admin account
4. Check firewall rule **Game Zone Optimizer WinRM** (port 5985 TCP)

### Remote optimize partially fails

- Review **Logs** for per-step failures
- Some AppX packages may already be removed (non-fatal)
- Restore point may fail if System Protection is disabled (optimization still proceeds)

### Installer deploy fails

- Enable **File and Printer Sharing** on target PCs
- Ensure WinRM is enabled before deploy
- Large installer deploys sequentially — watch **Logs** for progress

### Build fails on Windows

- Install [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) with C++ workload
- Install WebView2 runtime (pre-installed on most Windows 11 systems)
- Run `rustup default stable-msvc`

### App opens but every action fails / does nothing

**Most common causes:**

1. **Not running as Administrator** — right-click the app → **Run as administrator**. The yellow banner at the top means system changes are blocked.
2. **Opened in browser instead of Tauri** — use `pnpm tauri dev`, not `pnpm dev`. The browser has no backend bridge; all buttons fail silently.
3. **Running on macOS/Linux** — only the UI shell works; optimizations require a Windows build.
4. **UAC declined at launch** — the app manifest requires admin; declining UAC means the app never starts.

Check the **Logs** tab after any action. If steps show empty config or "no matching packages", rebuild with the latest `_Common.ps1` fix (PowerShell 5.1 compatibility).

### Apply Gaming Profile runs but changes nothing

- Confirm **Running elevated** on Dashboard status card
- Open **Logs** — look for `ScriptNotFound` or step failures
- Run this in PowerShell to verify scripts exist:
  ```powershell
  Test-Path "$env:ProgramFiles\Game Zone Optimizer\resources\scripts\Invoke-DebloatApply.ps1"
  ```
- In dev mode, run `pnpm tauri dev` from the repo root so script fallbacks resolve

---

## Windows Update Warning

**Disabling Windows Update removes automatic security patches.**

Gaming PCs will not receive critical updates until you:

- Re-enable via **Windows Update** → **Re-enable Windows Update**, or
- Patch through WSUS, offline media, or a scheduled maintenance process

This is intentional for game zones where automatic restarts disrupt sessions. Plan periodic maintenance to patch stations.

---

## New Venue Checklist

- [ ] Admin PC installed and running elevated
- [ ] Gaming PCs installed (or WinRM enabled via script/LAN tab)
- [ ] Shared admin credentials documented
- [ ] **LAN** scan finds all stations
- [ ] **WinRM Ready** tab shows all Windows PCs
- [ ] **Optimize Selected** applied to all stations
- [ ] One station tested: boots cleanly, games run
- [ ] Backup/rollback tested once on a test PC
- [ ] Maintenance schedule defined for manual Windows updates

---

## License

Private — Game Zone internal use.
