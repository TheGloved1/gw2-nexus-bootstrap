# gw2-nexus-bootstrap

Universal, drop-in bootstrap for Guild Wars 2 on Linux (Steam/Proton) with **Raidcore Nexus** + **TaimiHUD** + **Tekkit's All-In-One** markers. Put one script in any `Guild Wars 2/` install and it just works.

Single-file, no hardcoded paths, auto-downloads missing components, preserves Steam `%command%` quoting, logs everything.

## Features

* **Portable** - detects `GW2DIR` from script location, no `/home/...` hardcoded.
* **Auto-download Nexus** - `https://github.com/RaidcoreGG/Nexus/releases/latest/download/d3d11.dll` -> `Guild Wars 2/d3d11.dll`.
* **Auto-download Tekkit** - `https://www.tekkitsworkshop.net/download?download=1:tw-all-in-one` -> `Guild Wars 2/addons/Taimi/pathing/tw_ALL_IN_ONE.taco`.
* **Preserved launch** - `"$@"` keeps `Guild Wars 2/Gw2-64.exe` spaces, logs to `gw2-nexus.log`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh
```
Auto-searches Steam `libraryfolders.vdf` for `Guild Wars 2/Gw2-64.exe`, prompts for path if not found, downloads `gw2-nexus.sh` to that folder, `chmod +x`, then prints the exact Launch Options to paste:

```
"/path/to/Guild Wars 2/gw2-nexus.sh" %command%
```

With manual path:
```bash
curl -fsSL https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh -s -- --gw2-dir "/mnt/steamlib/steamapps/common/Guild Wars 2"
```

Set that string in **Steam -> Library -> Guild Wars 2 -> Properties -> Launch Options**, launch once.

## Manual Install

```bash
wget -O gw2-nexus.sh https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/gw2-nexus.sh
cp gw2-nexus.sh "/path/to/Guild Wars 2/"
chmod +x "/path/to/Guild Wars 2/gw2-nexus.sh"
# Steam -> Properties -> Launch Options:
"/path/to/Guild Wars 2/gw2-nexus.sh" %command%
```

In-game: open Nexus Library to install `ArcDPS` and `TaimiHUD`, then `TaimiHUD -> Data Sources` and `Pathing` to enable `Tekkit's Guides`.

## Uninstall

```bash
rm "Guild Wars 2/d3d11.dll" "Guild Wars 2/addons/Taimi/pathing/tw_ALL_IN_ONE.taco"
# or full: rm -rf Guild Wars 2/addons
# Steam -> Properties -> Launch Options -> clear
```

## Credits

* Guide: HikariKnight Universal-Blue https://universal-blue.discourse.group/t/a-guide-to-addons-for-guild-wars-2-on-linux/8942
* Nexus: Raidcore https://raidcore.gg/Nexus
* TaimiHUD: https://taimihud.com
* Tekkit: https://www.tekkitsworkshop.net/markers/all-in-one-marker-pack
