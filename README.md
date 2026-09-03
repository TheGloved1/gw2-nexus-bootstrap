# gw2-nexus-bootstrap

Universal, drop-in bootstrap for Guild Wars 2 on Linux (Steam/Proton) with **Raidcore Nexus** + **TaimiHUD** + **Tekkit's All-In-One** markers. Put one script in any `Guild Wars 2/` install and it just works.

Single-file, no hardcoded paths, auto-downloads missing components, preserves Steam `%command%` quoting, logs everything.

> Ported from the Universal-Blue guide: https://universal-blue.discourse.group/t/a-guide-to-addons-for-guild-wars-2-on-linux/8942  
> TaimiHUD renders *inside* GW2 via Nexus, no external overlay/window-rule needed. Works in `gamescope` and on Wayland.

## Features

* **Portable** - detects `GW2DIR` from script location (`SCRIPT_DIR`) or parses `GAMEDIR` from Steam `%command%` `waitforexitandrun` (guide method). No `/home/...` hardcoded.
* **Auto-download Nexus** - `https://github.com/RaidcoreGG/Nexus/releases/latest/download/d3d11.dll` (7.3M PE32+) -> `Guild Wars 2/d3d11.dll` if missing/invalid.
* **Auto-download Tekkit** - `https://www.tekkitsworkshop.net/download?download=1:tw-all-in-one` (primary) with `Referer` + `User-Agent`, fallback `https://www.tekkitsworkshop.net/downloads/tw_ALL_IN_ONE.taco` -> `Guild Wars 2/addons/Taimi/pathing/tw_ALL_IN_ONE.taco` (47M Zip). Validates size >10M and `file` type; won't overwrite valid >10M unless `--force`.
* **Preserved launch** - `"$@"` exec keeps `Guild Wars 2/Gw2-64.exe` spaces, `DXVK_ASYNC=1` `MANGOHUD=0`, duplicate logging `exec > >(tee -a)` to `gw2-nexus.log` with rotation.
* **Idempotent** - dry-run with no args just checks and exits `0`.

## Prerequisites

* Guild Wars 2 installed via Steam (even for ArenaNet accounts - launcher will prompt `Portal` login). Proton `GE-Proton11-6` or `Experimental` recommended.
* `curl` or `wget` + `file` + `stat` + `realpath` (all present on Bazzite/Cachy/niri).
* No `ScopeBuddy` required (optional - guide uses `scb -- %command%` for ArcDPS `yad` updater; Nexus now handles ArcDPS via in-game Library).

## Quick Start

```bash
# 1. Grab the script
wget -O gw2-nexus.sh https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/gw2-nexus.sh
# or git clone
git clone https://github.com/TheGloved1/gw2-nexus-bootstrap.git

# 2. Drop it into your GW2 install (where Gw2-64.exe lives)
cp gw2-nexus.sh "/home/$USER/.steam/steam/steamapps/common/Guild Wars 2/"
chmod +x "/home/$USER/.steam/steam/steamapps/common/Guild Wars 2/gw2-nexus.sh"

# 3. Steam -> Library -> Guild Wars 2 -> Properties -> Launch Options:
"/home/$USER/.steam/steam/steamapps/common/Guild Wars 2/gw2-nexus.sh" %command%
# For ArenaNet account add after %command% handling is inside script already - no need for "-provider Portal" manually.

# 4. Launch GW2 once - script will download missing Nexus + Tekkit and create addons/Taimi/pathing/
tail -f "/home/$USER/.steam/steam/steamapps/common/Guild Wars 2/gw2-nexus.log"
```

First launch creates:
```
Guild Wars 2/
├── d3d11.dll                         # Nexus 7.3M
├── gw2-nexus.sh                      # this script
├── gw2-nexus.log                     # log
└── addons/
    ├── Taimi/
    │   ├── pathing/
    │   │   ├── GW2TacO Markers.taco  # 992K (stock)
    │   │   └── tw_ALL_IN_ONE.taco    # 47M Tekkit (auto-downloaded)
    │   └── markers/...
    └── Nexus/...
```

## Detailed Setup

### 1. Place Script

The script must live *inside* `Guild Wars 2/` next to `Gw2-64.exe`. It uses `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` so `GW2DIR="$SCRIPT_DIR"` - portable to any library location (`~/.steam/steam/`, `~/.local/share/Steam/`, external drive).

If you keep the script elsewhere, it parses `GAMEDIR` from `Steam %command%`:
```bash
# %command% expands to: .../steam-launch-wrapper ... pressure-vessel ... proton waitforexitandrun "/.../Guild Wars 2/Gw2-64.exe" -provider Steam
# Script does: awk -F '" "' '/waitforexitandrun/{print next}' | sed 's/\/Gw2-64.exe//'
```

### 2. Steam Launch Options

*Steam -> Properties -> Launch Options* must be exactly (quotes required for space):
```
"/full/path/to/Guild Wars 2/gw2-nexus.sh" %command%
```
Do **not** use `gamescope` prefix unless you know niri/Wayland needs it - TaimiHUD runs inside GW2, no external overlay.

Verify stored:
```bash
grep -A2 '"1284210"' ~/.local/share/Steam/userdata/*/config/localconfig.vdf
# should show LaunchOptions with gw2-nexus.sh
```
If you edit `localconfig.vdf` manually, `steam -shutdown` first - Steam overwrites on exit.

### 3. First Run - Auto-Downloads

Dry-run without Steam (checks only):
```bash
"/path/to/Guild Wars 2/gw2-nexus.sh"
# logs: Checking Nexus... Tekkit tw_ALL_IN_ONE.taco present: 47M or Downloading...
```

Full run via Steam as above logs to `gw2-nexus.log`:
```
[2026-09-03 12:13:34] Checking Nexus... d3d11.dll present: 7.3M
[2026-09-03 12:13:34] Checking Tekkit markers... Tekkit not found - downloading...
[2026-09-03 12:13:34] Downloading https://www.tekkitsworkshop.net/download?download=1:tw-all-in-one -> .../tw_ALL_IN_ONE.taco
[2026-09-03 12:13:37] Saved .../tw_ALL_IN_ONE.taco (47M)
```

If `403 Forbidden` on `downloads/tw_ALL_IN_ONE.taco` (TaimiHUD `Nexus.log` shows it), the primary `download?download=1:tw-all-in-one` with `Referer` header succeeds (tested 46.28M).

Manual fallback if offline:
```bash
cp ~/Downloads/tw_ALL_IN_ONE.taco "Guild Wars 2/addons/Taimi/pathing/tw_ALL_IN_ONE.taco"
```

### 4. In-Game - Nexus + TaimiHUD

1. Launch GW2 - accept Nexus legal popup and open the Nexus Library to install `ArcDPS` and `TaimiHUD`.
2. `TaimiHUD` -> `Data Sources` tab - `Tekkit's All-In-One` should show as installed (we pre-placed file). If not, `Add` URL `https://www.tekkitsworkshop.net/download?download=1:tw-all-in-one` or `Import .taco`.
3. `TaimiHUD` -> `Pathing` enable `Tekkit's Guides` categories. Also `Teh's Trails` available via `Data Sources` -> `Teh's Trails - Map Completion` `https://github.com/xrandox/TehsTrails/raw/main/TehsTrails/TehsTrails.taco` (speedrun 5k markers, lighter than Tekkit 49k).

TaimiHUD settings live in `addons/Taimi/settings.json` and `sources.toml` (pre-filled with `ReActif`, `LadyElyssa`, `Teh's`).

### 5. Troubleshooting

* **Log:** `tail -f "Guild Wars 2/gw2-nexus.log"` and `addons/Nexus/Nexus.log` (`TaimiHUD` `Failed to get Wayland objects` was `gamescope` + `niri` conflict - we removed gamescope).
* **Tekkit 403:** Expected on TaimiHUD auto-update - manual `tw_ALL_IN_ONE.taco` in `addons/Taimi/pathing/` suppresses it.
* **GW2 stops after launcher:** Was `CMD_STR="$*"` + `eval` splitting `Guild Wars 2` space -> fixed to `"$@"`; also `gamescope -W` inside `niri` Wayland caused `Failed to get Wayland objects` -> remove gamescope prefix.
* **Nexus not loading:** Ensure `d3d11.dll` 7.3M `file d3d11.dll | grep PE32` and `Gw2-64.exe` sibling. Protontricks optional: `d3dcompiler_43/47` via `winetricks`.

### 6. Uninstall

```bash
rm "Guild Wars 2/d3d11.dll" "Guild Wars 2/addons/Taimi/pathing/tw_ALL_IN_ONE.taco"
# or full: rm -rf Guild Wars 2/addons
# Steam -> Properties -> Launch Options -> clear
```

### 7. Scripts

* `gw2-nexus.sh` - this bootstrap (Nexus + Tekkit, portable, TaimiHUD)

### 8. Credits

* Guide: HikariKnight Universal-Blue https://universal-blue.discourse.group/t/a-guide-to-addons-for-guild-wars-2-on-linux/8942
* Nexus: Raidcore https://raidcore.gg/Nexus https://github.com/RaidcoreGG/Nexus/releases/latest/download/d3d11.dll
* TaimiHUD: https://taimihud.com https://github.com/TaimiHUD/TaimiHUD
* Tekkit: https://www.tekkitsworkshop.net/markers/all-in-one-marker-pack

MIT - drop in, no warranty. PRs welcome.
