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

1. [What It Does](#what-it-does)
2. [Architecture](#architecture)
3. [Requirements](#requirements)
4. [Quick Start](#quick-start)
5. [Installation](#installation)
6. [Deployment Workflows](#deployment-workflows)
7. [LAN Discovery & Bulk Setup](#lan-discovery--bulk-setup)
8. [Feature Reference](#feature-reference)
9. [Post-Install Behavior](#post-install-behavior)
10. [Safety & Rollback](#safety--rollback)
11. [Remote Administration](#remote-administration)
12. [Customizing Manifests](#customizing-manifests)
13. [Project Structure](#project-structure)
14. [Building from Source](#building-from-source)
15. [Troubleshooting](#troubleshooting)
16. [Windows Update Warning](#windows-update-warning)

---

## What It Does

Game Zone Optimizer is designed for venues that run many Windows gaming PCs on a LAN. It combines **network discovery**, **system debloating**, **privacy hardening**, and **gaming performance tuning** into a single desktop app.

### Core capabilities

| Module | What it does |
|--------|----------------|
| **LAN Discovery** | Auto-detect subnet, scan all connected devices, classify Windows vs other, check WinRM readiness |
| **Remote Installer** | Push NSIS setup from admin PC to LAN stations via SMB + silent install |
| **Desktop Customize** | Admin-picked wallpaper + remove all desktop shortcuts across LAN stations |
| **Bulk LAN Setup** | Enable WinRM, copy setup scripts, optimize multiple stations from admin PC |
| **Debloat** | Remove bloatware (AppX + classic) using Light / Standard / Aggressive presets |
| **Telemetry Off** | Disable DiagTrack, CEIP tasks, advertising ID, consumer experience features |
| **Windows Update** | Fully disable automatic updates (services, registry policies, scheduled tasks) |
| **Services Audit** | List all services; recommend safe-to-disable items for gaming |
| **Gaming Tweaks** | High performance power plan, Game Mode, SysMain/Search off, network latency tweaks |
| **Gaming Profile** | One-click orchestration of all optimization modules |
| **Remote Push** | Apply profile to specific targets over WinRM |
| **Rollback** | Restore services and registry from JSON backup |

---

## Architecture

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

**Design principle:** Rust orchestrates; PowerShell performs Windows system operations; manifests hold venue-specific lists (bloatware, services, gaming flags) so you can tune behavior without recompiling.

---

## Requirements

### Admin PC (recommended primary install)

| Requirement | Notes |
|-------------|-------|
| Windows 10 or 11 | Build and runtime are Windows-only |
| Administrator account | App requests elevation via UAC |
| PowerShell 5.1+ | Included with Windows |
| Ethernet LAN | Admin PC on same subnet as gaming stations |
| Shared local admin creds | Same username/password on all gaming PCs (typical game-zone setup) |

### Gaming PCs (stations)

| Requirement | Notes |
|-------------|-------|
| Windows 10 or 11 | Pro recommended for WinRM |
| Local Administrator account | Same credentials as admin PC |
| Network connectivity | Reachable on LAN (ping + SMB/WINRM ports) |

### Development machine

| Tool | Version |
|------|---------|
| Node.js | 18+ |
| pnpm | 8+ |
| Rust | stable (for `tauri build` on Windows) |
| Visual Studio Build Tools | Required on Windows for Rust MSVC linker |

---

## Quick Start

### Run in development (Windows, as Administrator)

```powershell
git clone <your-repo-url> game-zone-setup
cd game-zone-setup
pnpm install
pnpm tauri dev
```

### Build production installer

```powershell
pnpm tauri build
```

Installer output:

```
src-tauri/target/release/bundle/nsis/Game Zone Optimizer_0.1.0_x64-setup.exe
```

---

## Installation

### On each gaming PC (station install)

1. Run `Game Zone Optimizer_*_x64-setup.exe` **as Administrator**.
2. The NSIS installer automatically runs **post-install setup**:
   - Copies PowerShell scripts to `C:\ProgramData\GameZoneOptimizer\scripts\`
   - Enables **WinRM** (port 5985 firewall rule)
   - Writes install marker to `C:\ProgramData\GameZoneOptimizer\install-state.json`
3. Optionally open the app and click **Apply Gaming Profile** for local optimization.

### On admin PC (control station)

1. Install the same application on the admin/management PC.
2. Open the **LAN** tab to discover and manage all stations.
3. Use bulk actions to enable WinRM, copy setup files, and optimize stations you haven't installed locally yet.

---

## Deployment Workflows

### Workflow A — Install on every PC (simplest)

```
For each gaming PC:
  1. Run installer (post-install enables WinRM automatically)
  2. Open app → Dashboard → Apply Gaming Profile
```

Best when you can physically access each station once.

### Workflow B — Admin PC manages entire LAN (recommended for cafes)

```
One-time per gaming PC (if not using installer):
  Run scripts\Enable-WinRM.ps1 as Administrator
  — OR —
  Install app (post-install hook runs automatically)

On admin PC:
  1. Open LAN tab
  2. Scan LAN
  3. Select Windows stations
  4. Enable WinRM (if needed) → Copy Setup Files → Optimize Selected
```

Best when you have one management PC and many stations.

### Workflow C — Hybrid

```
- Install + optimize critical stations locally
- Use admin PC LAN tab for remaining devices
- Use Remote tab for manual one-off targets
```

---

## LAN Discovery & Bulk Setup

The **LAN** page is the central hub for multi-PC game zone setup.

### Step-by-step

1. **Open LAN tab** on the admin PC (must be on the same subnet).
2. **Review network info** — interface, gateway, scan range (default pool `.100`–`.200`).
3. **Enter admin credentials** — shared local admin username/password for gaming PCs.
4. **Click Scan LAN** — pings the pool range, resolves hostnames, reads ARP for MAC addresses.
5. **Review segregated tabs:**

   | Tab | Shows |
   |-----|-------|
   | All | Every discovered device |
   | Windows | Devices with SMB port 445 open (likely Windows) |
   | Other | Non-Windows devices (phones, routers, consoles) |
   | WinRM Ready | Windows PCs with WinRM reachable |
   | Needs WinRM | Windows PCs without WinRM (candidates for enable) |

6. **Select stations** and run bulk actions:

   | Action | Effect |
   |--------|--------|
   | **Enable WinRM on Selected** | Remotely runs WinRM bootstrap on stations |
   | **Copy Setup Files** | Copies PS scripts to `C:\ProgramData\GameZoneOptimizer\` on each PC |
   | **Optimize Selected** | Pushes full gaming profile (debloat, telemetry, WU off, services, gaming tweaks) |
   | **Apply Wallpaper & Clean Desktop** | Copies admin-picked image + removes all desktop shortcuts on selected PCs |
   | **Remove Shortcuts Only** | Deletes all `.lnk` and `.url` from Public and user desktops (Recycle Bin kept) |
   | **Deploy Installer to Selected** | Copies setup `.exe` to each PC and runs silent NSIS install (`/S`) |

### Remote installer deployment

From the **Remote Installer Deployment** card on the LAN page, push the Game Zone Optimizer NSIS installer from the admin PC to selected stations:

1. **Auto-detect** — on page load the app searches for a setup `.exe` in this order:
   - `%APPDATA%\GameZoneOptimizer\staging\installer.exe` (previously staged)
   - Directory of the running app — `*setup*.exe` or `Game Zone Optimizer*.exe`
   - Parent of the install directory (common when setup sits next to the install folder)
   - `%USERPROFILE%\Downloads\*setup*.exe` (newest by modified time)
2. **Browse Installer** — pick any valid setup `.exe` (must be at least 1 MB); file is staged to `%APPDATA%\GameZoneOptimizer\staging\installer.exe`.
3. Select target Windows stations and enter admin credentials.
4. Enable **Dry run** (shared checkbox in Desktop Customization) to preview SMB copy only — no install.
5. Click **Deploy Installer to Selected**.

**Per-station flow:**
- SMB copy to `\\<ip>\C$\ProgramData\GameZoneOptimizer\installer.exe`
- WinRM `Invoke-Command` runs `installer.exe /S` (silent per-user NSIS install)
- Verifies install via Windows uninstall registry keys
- Post-install NSIS hook (`installer-hooks.nsi`) enables WinRM on the remote PC automatically

**Requirements:**
- Shared local admin credentials on target PCs
- WinRM enabled on targets (use **Enable WinRM on Selected** first; app warns if selected PCs lack WinRM)
- File and Printer Sharing enabled for SMB admin share access
- Large installer (~50–100 MB) — deploys sequentially per device; progress appears in **Logs**

**Already installed:** if the uninstall registry key exists, the station is skipped with an "Already installed" message.

### Desktop customization (wallpaper + shortcuts)

From the **Desktop Customization** card on the LAN page:

1. **Choose Wallpaper** — pick a `.jpg`, `.png`, or `.bmp` from the admin PC (stored in app staging).
2. Preview the image and confirm the filename.
3. Select target stations (WinRM required).
4. Click **Apply Wallpaper & Clean Desktop** to:
   - Copy wallpaper to `C:\ProgramData\GameZoneOptimizer\wallpaper.jpg` on each PC
   - Set wallpaper for Default user template + all existing user profiles
   - Apply HKLM wallpaper policy and refresh the active session
   - Remove all `.lnk` and `.url` shortcuts from `C:\Users\Public\Desktop` and each `C:\Users\<user>\Desktop`

**Shortcut removal rules:**
- Removes **all** shortcut files (`.lnk`, `.url`)
- Does **not** remove Recycle Bin (shell folder, not a file)
- Does **not** delete `desktop.ini`
- Game launchers on the Desktop will be removed — keep launchers in Start menu or shell instead

**Dry run:** enable the checkbox to preview wallpaper registry changes and shortcut counts without applying.

**Local Gaming Profile:** when `removeDesktopShortcuts` is `true` in `gaming-profile.json`, shortcut cleanup also runs on the local PC during **Apply Gaming Profile** (no wallpaper unless configured separately on LAN).

### LAN scan technical details

- Uses `Test-Connection` (ICMP ping) with 1-second timeout per address
- Resolves hostnames via DNS reverse lookup
- Reads MAC addresses from ARP table
- Classifies Windows devices by open ports (445 SMB, 5985 WinRM)
- Tests WinRM with `Test-WSMan` when credentials are provided

---

## Feature Reference

### Dashboard

- Platform and elevation status
- Last backup timestamp
- **Apply Gaming Profile** — runs all modules in order:
  1. Create JSON backup
  2. System restore point
  3. Telemetry off
  4. Standard debloat
  5. Disable recommended services
  6. Disable Windows Update
  7. Gaming optimizations
  8. Remove desktop shortcuts (when enabled in gaming-profile.json)
- **Rollback Last Backup** — restores prior service/registry state

### Uninstall / Debloat

| Preset | Removes |
|--------|---------|
| **Light** | Obvious bloat (Candy Crush, News, Weather, Solitaire) |
| **Standard** | Light + Teams consumer, Copilot, Skype (gaming cafe default) |
| **Aggressive** | Standard + Xbox Game Bar, OneDrive (optional items) |

Supports **dry run** to preview without removing.

### Services

- Full service audit with category badges
- **Essential** services are never modified
- **Gaming safe disable** — DiagTrack, SysMain, WSearch, Fax, etc.
- **Contextual** — Spooler, Bluetooth (user decides)

### Privacy / Telemetry

- `AllowTelemetry = 0`
- Disables DiagTrack, dmwappushservice
- Disables CEIP scheduled tasks
- Turns off consumer features, tips, advertising ID

### Windows Update

- Stops and disables `wuauserv`, `UsoSvc`, `WaaSMedicSvc`
- Sets `NoAutoUpdate` registry policy
- Disables Windows Update scheduled tasks
- **Re-enable** button restores update services

### Gaming

- High Performance (or Ultimate) power plan
- Game Mode on
- SysMain and Windows Search disabled
- Delivery Optimization off
- Hibernation off
- Mouse acceleration off
- TCP Nagle tweaks per network adapter

### Remote

- Manually add targets by hostname/IP
- Test WinRM connectivity
- Push gaming profile to target list

### Logs

- Live operation log with timestamps
- Success/failure per step

---

## Post-Install Behavior

When the NSIS installer finishes, it runs `Invoke-PostInstallSetup.ps1` automatically:

```
1. Create C:\ProgramData\GameZoneOptimizer\scripts\
2. Copy bundled .ps1 scripts
3. Run Enable-WinRM.ps1
4. Write install-state.json
```

This means **gaming PCs are WinRM-ready immediately after install**, so the admin PC can discover and optimize them from the LAN tab without manual script execution.

To run post-install setup manually:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Program Files\Game Zone Optimizer\scripts\Invoke-PostInstallSetup.ps1"
```

---

## Safety & Rollback

| Safety feature | Description |
|----------------|-------------|
| **Administrator check** | Banner shown if not elevated; destructive actions blocked |
| **Restore point** | Created before full Gaming Profile (when OS allows) |
| **JSON backup** | Saved to `%APPDATA%\GameZoneOptimizer\backups\` |
| **Rollback** | Restores tracked services and registry keys from backup |
| **Dry run** | Preview debloat, services, telemetry, gaming, and WU changes |
| **Essential service guard** | RpcSs, PlugPlay, Winmgmt, etc. never disabled |
| **Danger dialog** | Windows Update disable requires explicit confirmation |

### Backup location

```
%APPDATA%\GameZoneOptimizer\backups\backup_YYYY-MM-DD_HH-mm-ss.json
```

---

## Remote Administration

### Prerequisites on gaming PCs

WinRM must be enabled. This happens automatically via:

- **Installer post-install hook** (recommended), or
- **Manual script:** `scripts\Enable-WinRM.ps1`, or
- **LAN tab:** Enable WinRM on Selected

### WinRM verification

From admin PC PowerShell:

```powershell
Test-WSMan -ComputerName 192.168.1.50
```

Or use **Test WinRM** in the Remote or LAN tab.

### Firewall

The bootstrap script creates an inbound rule:

```
Name: Game Zone Optimizer WinRM
Port: 5985 TCP
```

### Credentials

Use the **same local Administrator password** on all gaming stations. Domain/AD credentials are not required for typical game-zone setups.

---

## Customizing Manifests

Edit JSON files in `src-tauri/resources/manifests/` to tune per venue:

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

- `optional: true` — unchecked by default in UI
- `presets` — which debloat preset includes this app

### `services-baseline.json`

```json
{
  "name": "DiagTrack",
  "category": "gaming_safe_disable",
  "description": "Connected User Experiences and Telemetry"
}
```

Categories: `essential`, `gaming_safe_disable`, `contextual`, `unknown`

### `gaming-profile.json`

```json
{
  "powerPlan": "high_performance",
  "gameMode": true,
  "hags": false,
  "disableSysMain": true,
  "networkTweaks": true
}
```

After editing manifests, rebuild the installer (`pnpm tauri build`).

---

## Project Structure

```
game-zone-setup/
├── package.json              # Frontend deps + scripts
├── vite.config.ts
├── src/
│   ├── App.tsx               # Main shell + routing
│   ├── pages/
│   │   ├── DashboardPage.tsx
│   │   ├── LanPage.tsx       # LAN discovery + bulk setup
│   │   ├── UninstallPage.tsx
│   │   ├── ServicesPage.tsx
│   │   ├── PrivacyPage.tsx
│   │   ├── WinUpdatePage.tsx
│   │   ├── GamingPage.tsx
│   │   ├── RemotePage.tsx
│   │   └── LogsPage.tsx
│   ├── components/
│   ├── hooks/
│   └── types/
├── scripts/                  # Dev copies of PowerShell (mirrors bundle)
│   └── Enable-WinRM.ps1
└── src-tauri/
    ├── tauri.conf.json       # NSIS + resource bundling
    ├── windows/
    │   ├── app.manifest      # requireAdministrator
    │   └── installer-hooks.nsi  # Post-install WinRM setup
    ├── resources/
    │   ├── scripts/          # Bundled into installer
    │   │   ├── Get-SubnetConfig.ps1
    │   │   ├── Invoke-LanScan.ps1
    │   │   ├── Invoke-DeviceClassify.ps1
    │   │   ├── Invoke-LanBulkSetup.ps1
    │   │   ├── Invoke-DesktopCustomize.ps1
    │   │   ├── Invoke-PostInstallSetup.ps1
    │   │   ├── Enable-WinRM.ps1
    │   │   └── … (debloat, telemetry, gaming, etc.)
    │   └── manifests/
    └── src/
        ├── commands/
        │   ├── local.rs      # Optimization commands
        │   ├── lan.rs        # LAN discovery + bulk setup
        │   └── remote.rs     # WinRM remote push
        ├── powershell.rs     # PS bridge
        ├── backup.rs
        ├── profiles.rs
        └── winrm.rs
```

---

## Building from Source

### Windows (production build)

```powershell
# Prerequisites: Node 18+, pnpm, Rust, VS Build Tools
pnpm install
pnpm tauri build
```

### macOS (UI development only — system commands won't run)

```bash
pnpm install
pnpm dev          # Frontend only
pnpm tauri dev    # UI shell; PowerShell commands return "Windows only"
```

System optimization commands require a **Windows build machine** for full testing.

### npm scripts

| Script | Command | Purpose |
|--------|---------|---------|
| `dev` | `vite` | Frontend dev server |
| `build` | `tsc && vite build` | Production frontend bundle |
| `tauri dev` | `tauri dev` | Full app in dev mode |
| `tauri build` | `tauri build` | NSIS installer |

---

## Troubleshooting

### "Run as Administrator" banner persists

- Right-click the app → **Run as administrator**
- The installer should request elevation; if not, run installer as admin

### LAN scan finds 0 devices

- Confirm admin PC is on the same subnet as gaming stations
- Check Windows Firewall allows ICMP (ping) on private network
- Verify stations are powered on and connected via Ethernet
- Try expanding scan range in `Get-SubnetConfig.ps1` pool settings

### WinRM connection failed

1. On gaming PC, run: `scripts\Enable-WinRM.ps1` as Administrator
2. Verify: `Test-WSMan -ComputerName <gaming-pc-ip>` from admin PC
3. Confirm credentials match local admin account
4. Check firewall rule "Game Zone Optimizer WinRM" exists

### Remote optimize partially fails

- Review **Logs** tab for per-step failures
- Some AppX packages may already be removed (non-fatal)
- Restore point / backup may fail if System Protection is disabled (optimization still proceeds)

### Post-install hook didn't run

Run manually:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:ProgramFiles\Game Zone Optimizer\scripts\Invoke-PostInstallSetup.ps1"
```

### Build fails on Windows

- Install [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) with C++ workload
- Install WebView2 runtime (usually pre-installed on Windows 11)
- Run `rustup default stable-msvc`

---

## Windows Update Warning

**Disabling Windows Update removes automatic security patches.**

Gaming PCs will not receive critical updates until you:

- Re-enable updates via the **Windows Update** page, or
- Manually patch through WSUS / offline media / your maintenance process

This is intentional for game zones where automatic restarts and update downloads disrupt sessions. Plan a periodic maintenance window to patch stations.

---

## License

Private — Game Zone internal use.

---

## Support Checklist (new venue setup)

- [ ] Admin PC installed and elevated
- [ ] Gaming PCs installed (or WinRM enabled via script)
- [ ] Shared admin credentials documented
- [ ] LAN scan finds all stations
- [ ] WinRM Ready tab shows all Windows PCs
- [ ] Gaming Profile applied to all stations
- [ ] Test one station boots cleanly and runs games
- [ ] Backup/rollback tested once
- [ ] Maintenance schedule defined for manual Windows updates
