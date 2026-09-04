#!/usr/bin/env bash
set -e
# gw2-nexus-bootstrap easy installer
# Usage: curl -fsSL https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh
#    or: curl -fsSL .../install.sh | sh -s -- --verbose --gw2-dir "/path/to/Guild Wars 2"

RAW_URL="${GW2_BOOTSTRAP_RAW_URL:-https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/gw2-nexus.sh}"
GW2_DIR=""
DO_UNINSTALL=""
STEAM_WAS_OPEN=0
VERBOSE=0

log() { printf "%s\n" "$*"; }
vlog() { [ "$VERBOSE" = "1" ] && printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" || true; }
err() { printf "ERROR: %s\n" "$*" >&2; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --gw2-dir) GW2_DIR="$2"; shift 2;;
    --raw-url) RAW_URL="$2"; shift 2;;
    --uninstall|--remove|--clean) DO_UNINSTALL=1; shift;;
    --verbose) VERBOSE=1; shift;;
    -h|--help)
      echo "Usage: $0 [--gw2-dir PATH] [--uninstall] [--verbose]"
      echo "  --gw2-dir PATH   GW2 install path (auto-searched if omitted)"
      echo "  --uninstall      Remove bootstrap files and clear Steam Launch Options"
      echo "  --verbose        Show detailed logs"
      echo "  curl -fsSL https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh"
      echo "  curl -fsSL .../install.sh | sh -s -- --verbose"
      echo "  curl -fsSL .../install.sh | sh -s -- --uninstall --verbose"
      exit 0;;
    *) shift;;
  esac
done

find_gw2_via_vdf() {
  local vdf path
  for vdf in \
    "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
    "$HOME/.steam/steam/config/libraryfolders.vdf" \
    "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" \
    "$HOME/.local/share/Steam/config/libraryfolders.vdf" \
    "$HOME/.steam/root/steamapps/libraryfolders.vdf" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/libraryfolders.vdf" \
    "$HOME/.var/app/com.valvesoftware.Steam/config/libraryfolders.vdf"; do
    [ -f "$vdf" ] || continue
    while IFS= read -r path; do
      path=$(echo "$path" | sed -E 's/.*\s+"([^"]+)".*/\1/')
      [ -n "$path" ] || continue
      for cand in "$path/steamapps/common/Guild Wars 2/Gw2-64.exe" "$path/Steam/steamapps/common/Guild Wars 2/Gw2-64.exe"; do
        if [ -f "$cand" ]; then echo "$(dirname "$cand")"; return 0; fi
      done
      if [ -f "$path/steamapps/appmanifest_1284210.acf" ] || [ -f "$path/Steam/steamapps/appmanifest_1284210.acf" ]; then
        for cand2 in "$path/steamapps/common/Guild Wars 2" "$path/Steam/steamapps/common/Guild Wars 2"; do
          [ -f "$cand2/Gw2-64.exe" ] && echo "$cand2" && return 0
        done
      fi
    done < <(grep -E '"path"' "$vdf" 2>/dev/null)
  done
  return 1
}

find_gw2_via_common() {
  local p
  for p in \
    "$HOME/.steam/steam/steamapps/common/Guild Wars 2/Gw2-64.exe" \
    "$HOME/.local/share/Steam/steamapps/common/Guild Wars 2/Gw2-64.exe" \
    "$HOME/.steam/root/steamapps/common/Guild Wars 2/Gw2-64.exe" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Guild Wars 2/Gw2-64.exe" \
    "/mnt/*/Steam/steamapps/common/Guild Wars 2/Gw2-64.exe" \
    "/run/media/$USER/*/Steam*/steamapps/common/Guild Wars 2/Gw2-64.exe"; do
    for cand in $p; do [ -f "$cand" ] && echo "$(dirname "$cand")" && return 0; done
  done
  return 1
}

find_gw2_via_find() {
  local found
  found=$(find "$HOME" -maxdepth 6 -type f -name "Gw2-64.exe" 2>/dev/null | head -n 5)
  if [ -n "$found" ]; then echo "$(dirname "$(echo "$found" | head -n1)")"; return 0; fi
  return 1
}

prompt_manual() {
  local input
  if [ -t 0 ]; then
    printf "Guild Wars 2 not found. Enter full path to your Guild Wars 2 folder: "
    read -r input || true
  elif [ -e /dev/tty ]; then
    printf "Guild Wars 2 not found. Enter full path to your Guild Wars 2 folder: " > /dev/tty
    read -r input < /dev/tty || true
  else
    err "Guild Wars 2 not found. Run with --gw2-dir \"/path/to/Guild Wars 2\""
    return 1
  fi
  input=$(echo "$input" | sed "s#^~#$HOME#" | sed 's/^"//;s/"$//')
  if [ -z "$input" ]; then err "No path entered"; return 1; fi
  if [ ! -f "$input/Gw2-64.exe" ]; then err "No Gw2-64.exe found there"; return 1; fi
  echo "$input"
  return 0
}

ask_close_steam() {
  local ans
  if [ -t 0 ]; then
    printf "Close Steam and auto-update Launch Options (Y/n): "
    read -r ans || ans=""
  elif [ -e /dev/tty ]; then
    printf "Close Steam and auto-update Launch Options (Y/n): " > /dev/tty
    read -r ans < /dev/tty || ans=""
  else
    return 1
  fi
  case "${ans:-Y}" in [Yy]*) return 0 ;; [Nn]*) return 1 ;; *) return 0 ;; esac
}

try_close_steam() {
  pgrep -x steam >/dev/null 2>&1 || return 0
  STEAM_WAS_OPEN=1
  if ! ask_close_steam; then return 1; fi
  log "Closing Steam..."
  steam -shutdown >/dev/null 2>&1 || true
  for i in $(seq 1 60); do
    if ! pgrep -x steam >/dev/null 2>&1; then
      sleep 1
      if ! pgrep -x steam >/dev/null 2>&1; then
        vlog "Steam closed."
        return 0
      fi
    fi
    sleep 0.5
  done
  err "Steam still running after 30 seconds."
  log "Please close Steam manually and run again:"
  log "  curl -fsSL https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh"
  return 1
}

try_restart_steam() {
  if [ "$STEAM_WAS_OPEN" = "1" ]; then
    if pgrep -x steam >/dev/null 2>&1; then return 0; fi
    log "Restarting Steam..."
    nohup steam >/dev/null 2>&1 &
    for i in $(seq 1 20); do
      pgrep -x steam >/dev/null 2>&1 && { vlog "Steam restarted."; return 0; }
      sleep 0.5
    done
    log "Steam restart sent - open it manually if needed."
  fi
}

# --- Find Guild Wars 2 ---
if [ -n "$GW2_DIR" ]; then
  vlog "Using --gw2-dir: $GW2_DIR"
else
  log "Looking for Guild Wars 2..."
  GW2_DIR=$(find_gw2_via_vdf 2>/dev/null || true)
  [ -z "$GW2_DIR" ] && GW2_DIR=$(find_gw2_via_common 2>/dev/null || true)
  [ -z "$GW2_DIR" ] && GW2_DIR=$(find_gw2_via_find 2>/dev/null || true)
  if [ -n "$GW2_DIR" ] && [ -f "$GW2_DIR/Gw2-64.exe" ]; then
    log "Found Guild Wars 2 at: $GW2_DIR"
  else
    log "Could not find it automatically."
    GW2_DIR=$(prompt_manual 2>/dev/null || true)
    [ -z "$GW2_DIR" ] && GW2_DIR=$(prompt_manual || true)
  fi
fi

if [ -z "$GW2_DIR" ] || [ ! -f "$GW2_DIR/Gw2-64.exe" ]; then
  err "Could not find Guild Wars 2."
  err "Try: curl -fsSL .../install.sh | sh -s -- --gw2-dir \"/path/to/Guild Wars 2\""
  exit 1
fi

GW2_DIR="$(realpath "$GW2_DIR" 2>/dev/null || echo "$GW2_DIR")"
vlog "GW2 directory: $GW2_DIR"

# --- Uninstall ---
if [ "$DO_UNINSTALL" = "1" ]; then
  log "Uninstalling..."
  for f in "$GW2_DIR/gw2-nexus.sh" "$GW2_DIR/d3d11.dll" "$GW2_DIR/addons/Taimi/pathing/tw_ALL_IN_ONE.taco" "$GW2_DIR/gw2-nexus.log"; do
    if [ -e "$f" ]; then
      log "Removing $(basename "$f")..."
      vlog "  $f"
      rm -f "$f"
    else
      vlog "Skip (not found): $f"
    fi
  done
  if [ -d "$GW2_DIR/addons/Taimi/pathing" ]; then rmdir "$GW2_DIR/addons/Taimi/pathing" 2>/dev/null || true; rmdir "$GW2_DIR/addons/Taimi" 2>/dev/null || true; fi
  if try_close_steam; then
    for lc in $HOME/.local/share/Steam/userdata/*/config/localconfig.vdf; do
      [ -f "$lc" ] || continue
      if grep -q '"1284210"' "$lc" 2>/dev/null && grep -A2 '"1284210"' "$lc" | grep -q 'gw2-nexus.sh'; then
        log "Clearing Launch Options..."
        vlog "  $lc"
        cp "$lc" "$lc.bak" 2>/dev/null || true
        python3 - "$lc" << 'PY' 2>/dev/null || vlog "  failed to edit $lc"
import sys, re
path=sys.argv[1]
with open(path) as f: d=f.read()
d=re.sub(r'("1284210"\s*\{[^}]*"LaunchOptions"\s*)"[^"]*gw2-nexus\.sh[^"]*"', r'\1""', d, flags=re.S)
open(path,'w').write(d)
PY
        log "Launch Options cleared!"
      fi
    done
    try_restart_steam || true
  else
    log "Skipped Steam settings - clear Launch Options manually in Steam if needed."
  fi
  log "Uninstalled. You can also delete the whole addons folder if you want: rm -rf \"$GW2_DIR/addons\""
  exit 0
fi

# --- Install ---
log "Installing..."
DEST="$GW2_DIR/gw2-nexus.sh"
vlog "Downloading gw2-nexus.sh from $RAW_URL"
mkdir -p "$GW2_DIR"
if have_cmd curl; then
  curl -fsSL -A "Mozilla/5.0" -o "$DEST.tmp" "$RAW_URL" 2>&1 | vlog "curl: $(cat -)" || true
  if [ ! -s "$DEST.tmp" ]; then err "Download failed"; exit 1; fi
elif have_cmd wget; then
  wget -q --header="User-Agent: Mozilla/5.0" -O "$DEST.tmp" "$RAW_URL" 2>&1 | vlog "wget: $(cat -)" || true
else
  err "Need curl or wget"; exit 1
fi
if ! grep -q "GW2 Bootstrap" "$DEST.tmp" 2>/dev/null; then err "Download looks wrong"; rm -f "$DEST.tmp"; exit 1; fi
mv -f "$DEST.tmp" "$DEST"
chmod +x "$DEST"
log "Installed launcher to Guild Wars 2 folder."

log "Checking for game addons..."
if bash "$DEST" 2>&1 | vlog "$(cat -)"; then
  vlog "Bootstrap check done"
fi
log "Addons ready."

LAUNCH="\"$DEST\" %command%"

if try_close_steam; then
  UPDATED=0
  for lc in $HOME/.local/share/Steam/userdata/*/config/localconfig.vdf; do
    [ -f "$lc" ] || continue
    if grep -q "1284210" "$lc" 2>/dev/null && grep -A2 '"1284210"' "$lc" | grep -q 'LaunchOptions.*""'; then
      log "Updating Launch Options..."
      vlog "Auto-setting LaunchOptions in $lc"
      cp "$lc" "$lc.bak" 2>/dev/null || true
      python3 - "$lc" "$LAUNCH" << 'PY' 2>/dev/null || true
import sys, re
path, launch = sys.argv[1], sys.argv[2]
with open(path) as f: d=f.read()
d=re.sub(r'("1284210"\s*\{[^}]*"LaunchOptions"\s*)""', r'\1"'+launch.replace('\\','\\\\').replace('"','\\"')+'"', d, flags=re.S)
open(path,'w').write(d)
PY
      log "Launch Options updated!"
      UPDATED=1
      break
    fi
  done
  # If LaunchOptions already set, still show success
  if [ "$UPDATED" = "0" ]; then
    vlog "LaunchOptions already set or not found empty"
  fi
  try_restart_steam || true
  log ""
  log "All done! Launch Options set automatically."
  log "Start Guild Wars 2. In-game, open Nexus to install ArcDPS and TaimiHUD."
else
  log ""
  log "All done!"
  log "To finish, set your Steam Launch Options to:"
  log ""
  log "  $LAUNCH"
  log ""
  log "Steam -> Library -> Guild Wars 2 -> Properties -> Launch Options -> paste it"
  log "Then start Guild Wars 2. In-game, open Nexus to install ArcDPS and TaimiHUD."
fi
