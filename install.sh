#!/usr/bin/env bash
set -e
# gw2-nexus-bootstrap easy installer
# Usage: curl -fsSL https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh
#    or: wget -qO- https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh
#    or: bash install.sh [--gw2-dir "/path/to/Guild Wars 2"] [--raw-url URL]

RAW_URL="${GW2_BOOTSTRAP_RAW_URL:-https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/gw2-nexus.sh}"
GW2_DIR=""
MANUAL_PATH=""
DO_UNINSTALL=""

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
err() { printf '[%s] ERROR: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Parse args (supports piped sh with args: echo ... | sh -s -- --gw2-dir /path)
while [ $# -gt 0 ]; do
  case "$1" in
    --gw2-dir) GW2_DIR="$2"; shift 2;;
    --raw-url) RAW_URL="$2"; shift 2;;
    --uninstall|--remove|--clean) DO_UNINSTALL=1; shift;;
    -h|--help)
      echo "Usage: $0 [--gw2-dir PATH] [--uninstall]"
      echo "  --gw2-dir PATH   GW2 install path (auto-searched if omitted)"
      echo "  --uninstall      Remove bootstrap files and clear Steam Launch Options"
      echo "  curl -fsSL https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh"
      echo "  curl -fsSL .../install.sh | sh -s -- --uninstall"
      echo "  curl -fsSL .../install.sh | sh -s -- --uninstall --gw2-dir \"/path/to/Guild Wars 2\""
      exit 0;;
    *) shift;;
  esac
done

find_gw2_via_vdf() {
  local vdf lib path
  for vdf in \
    "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
    "$HOME/.steam/steam/config/libraryfolders.vdf" \
    "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" \
    "$HOME/.local/share/Steam/config/libraryfolders.vdf" \
    "$HOME/.steam/root/steamapps/libraryfolders.vdf" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/libraryfolders.vdf" \
    "$HOME/.var/app/com.valvesoftware.Steam/config/libraryfolders.vdf"; do
    [ -f "$vdf" ] || continue
    # Extract "path" values:  "path"  "/mnt/lib"
    while IFS= read -r path; do
      path=$(echo "$path" | sed -E 's/.*\s+"([^"]+)".*/\1/')
      [ -n "$path" ] || continue
      for cand in "$path/steamapps/common/Guild Wars 2/Gw2-64.exe" "$path/Steam/steamapps/common/Guild Wars 2/Gw2-64.exe"; do
        if [ -f "$cand" ]; then
          echo "$(dirname "$cand")"
          return 0
        fi
      done
      # Check appmanifest as fallback
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
    # Expand glob manually
    for cand in $p; do
      [ -f "$cand" ] && echo "$(dirname "$cand")" && return 0
    done
  done
  return 1
}

find_gw2_via_find() {
  # Limited depth find to avoid scanning entire HOME slowly
  local found
  found=$(find "$HOME" -maxdepth 6 -type f -name "Gw2-64.exe" 2>/dev/null | head -n 5)
  if [ -n "$found" ]; then
    echo "$(dirname "$(echo "$found" | head -n1)")"
    return 0
  fi
  return 1
}

prompt_manual() {
  local input
  # When piped (curl | sh), stdin is pipe, so read from /dev/tty
  if [ -t 0 ]; then
    printf "GW2 install not found. Enter full path to Guild Wars 2 folder (where Gw2-64.exe is): "
    read -r input || true
  elif [ -e /dev/tty ]; then
    printf "GW2 install not found. Enter full path to Guild Wars 2 folder (where Gw2-64.exe is): " > /dev/tty
    read -r input < /dev/tty || true
  else
    err "GW2 not found and no TTY for prompt. Re-run with --gw2-dir \"/path/to/Guild Wars 2\""
    return 1
  fi
  input=$(echo "$input" | sed "s#^~#$HOME#" | sed 's/^"//;s/"$//')
  if [ -z "$input" ]; then err "No path entered"; return 1; fi
  if [ ! -f "$input/Gw2-64.exe" ]; then err "No Gw2-64.exe at $input/Gw2-64.exe"; return 1; fi
  echo "$input"
  return 0
}

# --- Resolve GW2 dir ---
if [ -n "$GW2_DIR" ]; then
  log "Using --gw2-dir: $GW2_DIR"
else
  log "Searching for Guild Wars 2 install via Steam..."
  GW2_DIR=$(find_gw2_via_vdf 2>/dev/null || true)
  [ -z "$GW2_DIR" ] && GW2_DIR=$(find_gw2_via_common 2>/dev/null || true)
  [ -z "$GW2_DIR" ] && GW2_DIR=$(find_gw2_via_find 2>/dev/null || true)
  if [ -n "$GW2_DIR" ] && [ -f "$GW2_DIR/Gw2-64.exe" ]; then
    log "Found: $GW2_DIR"
  else
    log "Auto-search failed."
    GW2_DIR=$(prompt_manual 2>/dev/null || true)
    if [ -z "$GW2_DIR" ]; then
      # Try once more with explicit prompt output
      GW2_DIR=$(prompt_manual || true)
    fi
  fi
fi

if [ -z "$GW2_DIR" ] || [ ! -f "$GW2_DIR/Gw2-64.exe" ]; then
  err "Could not determine Guild Wars 2 directory."
  err "Run: curl -fsSL https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/install.sh | sh -s -- --gw2-dir \"/path/to/Guild Wars 2\""
  exit 1
fi

GW2_DIR="$(realpath "$GW2_DIR" 2>/dev/null || echo "$GW2_DIR")"
log "GW2 directory: $GW2_DIR"

# --- Uninstall ---
if [ "$DO_UNINSTALL" = "1" ]; then
  log "Uninstalling bootstrap..."
  for f in "$GW2_DIR/gw2-nexus.sh" "$GW2_DIR/d3d11.dll" "$GW2_DIR/addons/Taimi/pathing/tw_ALL_IN_ONE.taco" "$GW2_DIR/gw2-nexus.log" "$GW2_DIR/gw2-nexus.log.bak"; do
    if [ -e "$f" ]; then
      log "Removing $f"
      rm -f "$f" 2>&1 | sed 's/^/  /' || log "  rm failed: $f"
    else
      log "Skip (not found): $f"
    fi
  done
  # Optional: remove empty addons/Taimi/pathing if only our file was there
  if [ -d "$GW2_DIR/addons/Taimi/pathing" ]; then
    rmdir "$GW2_DIR/addons/Taimi/pathing" 2>/dev/null || true
    rmdir "$GW2_DIR/addons/Taimi" 2>/dev/null || true
  fi
  # Clear Steam LaunchOptions for 1284210
  if pgrep -x steam >/dev/null 2>&1; then
    log "Steam is running - cannot auto-clear LaunchOptions while running."
    log "Please clear manually: Steam -> Library -> Guild Wars 2 -> Properties -> Launch Options -> clear"
  else
    for lc in $HOME/.local/share/Steam/userdata/*/config/localconfig.vdf; do
      [ -f "$lc" ] || continue
      if grep -q '"1284210"' "$lc" 2>/dev/null; then
        if grep -A2 '"1284210"' "$lc" | grep -q 'gw2-nexus.sh'; then
          log "Clearing LaunchOptions in $lc"
          cp "$lc" "$lc.bak" 2>/dev/null || true
          python3 - "$lc" << 'PY' 2>/dev/null || log "  failed to edit $lc"
import sys, re
path=sys.argv[1]
with open(path) as f: d=f.read()
# Clear LaunchOptions that contains gw2-nexus.sh for 1284210 block
d=re.sub(r'("1284210"\s*\{[^}]*"LaunchOptions"\s*)"[^"]*gw2-nexus\.sh[^"]*"', r'\1""', d, flags=re.S)
open(path,'w').write(d)
PY
        fi
      fi
    done
  fi
  log "Uninstall complete."
  log "You may also want to: rm -rf \"$GW2_DIR/addons\" (removes all Nexus addons)"
  exit 0
fi

# --- Download bootstrap ---
DEST="$GW2_DIR/gw2-nexus.sh"
log "Downloading gw2-nexus.sh from $RAW_URL"
mkdir -p "$GW2_DIR"

if have_cmd curl; then
  if ! curl -fsSL -A "Mozilla/5.0" -o "$DEST.tmp" "$RAW_URL"; then
    err "curl failed to download $RAW_URL"
    exit 1
  fi
elif have_cmd wget; then
  if ! wget -q --header="User-Agent: Mozilla/5.0" -O "$DEST.tmp" "$RAW_URL"; then
    err "wget failed"
    exit 1
  fi
else
  err "Need curl or wget"
  exit 1
fi

if [ ! -s "$DEST.tmp" ] || ! grep -q "GW2 Bootstrap" "$DEST.tmp" 2>/dev/null; then
  err "Downloaded file invalid: $DEST.tmp"
  cat "$DEST.tmp" 2>/dev/null | head -20 >&2 || true
  rm -f "$DEST.tmp"
  exit 1
fi

mv -f "$DEST.tmp" "$DEST"
chmod +x "$DEST"
log "Installed: $DEST ($(ls -lh "$DEST" | awk '{print $5}'))"

# --- Dry-run bootstrap to fetch Nexus/Tekkit ---
log "Running bootstrap check (auto-downloads Nexus/Tekkit if missing)..."
if ! bash "$DEST" 2>&1 | sed 's/^/  /'; then
  log "Bootstrap check finished with warnings (see above)"
else
  log "Bootstrap check ok"
fi

# --- Print Launch Options ---
LAUNCH="\"$DEST\" %command%"
log ""
log "========================================"
log "Install complete!"
log "Set Steam Launch Options to:"
log ""
log "  $LAUNCH"
log ""
log "Steam -> Library -> Guild Wars 2 -> Properties -> Launch Options -> paste"
log "Then launch GW2 once. Logs: tail -f \"$GW2_DIR/gw2-nexus.log\""
log "In-game: Nexus Library (open via Nexus UI) -> install ArcDPS + TaimiHUD"
log "========================================"

# Also try to update Steam localconfig.vdf automatically if Steam not running (best-effort)
LOCALCONFIG="$HOME/.local/share/Steam/userdata"/*/config/localconfig.vdf 2>/dev/null | head -1
if pgrep -x steam >/dev/null 2>&1; then
  log "Steam is running - set Launch Options manually in Steam UI (auto-edit skipped while running)."
else
  for lc in $HOME/.local/share/Steam/userdata/*/config/localconfig.vdf; do
    [ -f "$lc" ] || continue
    if grep -q "1284210" "$lc" 2>/dev/null; then
      # Backup and try to set LaunchOptions if empty
      if grep -A2 '"1284210"' "$lc" | grep -q 'LaunchOptions.*""'; then
        log "Steam not running, auto-setting LaunchOptions in $lc (backup: $lc.bak)"
        cp "$lc" "$lc.bak" 2>/dev/null || true
        python3 - "$lc" "$LAUNCH" << 'PY' 2>/dev/null || true
import sys, re
path, launch = sys.argv[1], sys.argv[2]
with open(path) as f: d=f.read()
# Only set if LaunchOptions empty for 1284210 block
d=re.sub(r'("1284210"\s*\{[^}]*"LaunchOptions"\s*)""', r'\1"'+launch.replace('\\','\\\\').replace('"','\\"')+'"', d, flags=re.S)
open(path,'w').write(d)
PY
        break
      fi
    fi
  done
fi
