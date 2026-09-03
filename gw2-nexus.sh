#!/usr/bin/env bash
set -e
# Universal GW2 + Nexus + TaimiHUD bootstrap - drop into any Guild Wars 2/ and set Launch Options to: "/path/to/gw2-nexus.sh" %command%
# Auto-downloads Nexus and Tekkit marker pack if missing.
# Sources: Nexus https://github.com/RaidcoreGG/Nexus/releases/latest/download/d3d11.dll
#          Tekkit  https://www.tekkitsworkshop.net/download?download=1:tw-all-in-one (fallback direct)

# --- Portable GW2DIR detection (script location) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GW2DIR="$SCRIPT_DIR"
# Fallback: if not in GW2 dir (Gw2-64.exe missing), parse GAMEDIR from Steam %command%
if [ ! -f "$GW2DIR/Gw2-64.exe" ]; then
  cmd="$*"
  if echo "$cmd" | grep -q "waitforexitandrun"; then
    PARSED=$(echo "$cmd" | awk -F '" "' '{for(i=1;i<=NF;i++) if($i=="waitforexitandrun"){print $(i+1)}}' | sed 's/\/Gw2-64.exe//;s/"//g' | head -1)
    [ -n "$PARSED" ] && [ -f "$PARSED/Gw2-64.exe" ] && GW2DIR="$PARSED"
  fi
fi
GW2DIR="$(realpath "$GW2DIR" 2>/dev/null || echo "$GW2DIR")"

LOGFILE="$GW2DIR/gw2-nexus.log"
NEXUS_DLL="$GW2DIR/d3d11.dll"
NEXUS_URL="https://github.com/RaidcoreGG/Nexus/releases/latest/download/d3d11.dll"
TAIMI_PATHING_DIR="$GW2DIR/addons/Taimi/pathing"
TEKKIT_DEST="$TAIMI_PATHING_DIR/tw_ALL_IN_ONE.taco"
TEKKIT_URL="https://www.tekkitsworkshop.net/download?download=1:tw-all-in-one"
TEKKIT_FALLBACK_URL="https://www.tekkitsworkshop.net/downloads/tw_ALL_IN_ONE.taco"

# --- Logging ---
mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || LOGFILE="/tmp/gw2-nexus.log"
if [ -f "$LOGFILE" ] && [ "$(stat -c%s "$LOGFILE" 2>/dev/null || echo 0)" -gt 2097152 ]; then tail -n 500 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"; fi
exec > >(tee -a "$LOGFILE") 2>&1
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
trap 'log "ERROR line $LINENO (exit $?)"' ERR

log "=== GW2 Bootstrap (Nexus + TaimiHUD) ==="
log "GW2DIR=$GW2DIR"
log "SCRIPT_DIR=$SCRIPT_DIR"
log "LOGFILE=$LOGFILE"
log "Args count: $#"
cd "$GW2DIR" || { log "ERROR: GW2DIR not found: $GW2DIR"; exit 1; }
log "PWD: $(pwd)"

# --- Helpers ---
have_cmd() { command -v "$1" >/dev/null 2>&1; }
download_file() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  log "Downloading $url -> $dest"
  if have_cmd curl; then
    curl -L -A "Mozilla/5.0" -o "$dest.tmp" "$url" --referer "https://www.tekkitsworkshop.net/" --connect-timeout 15 --retry 2 2>&1 | sed 's/^/  curl: /' || true
  elif have_cmd wget; then
    wget -q --header="Referer: https://www.tekkitsworkshop.net/" --header="User-Agent: Mozilla/5.0" -O "$dest.tmp" "$url" 2>&1 | sed 's/^/  wget: /' || true
  else
    log "ERROR: neither curl nor wget found"
    return 1
  fi
  if [ ! -s "$dest.tmp" ]; then log "ERROR: download empty/failed: $url"; rm -f "$dest.tmp"; return 1; fi
  # Validate Zip for taco, PE for dll
  if echo "$dest" | grep -q "\.dll$"; then
    if ! file "$dest.tmp" | grep -q "PE32"; then log "ERROR: $dest.tmp not PE DLL: $(file "$dest.tmp")"; rm -f "$dest.tmp"; return 1; fi
  else
    if ! file "$dest.tmp" | grep -q "Zip"; then log "WARN: $dest.tmp not Zip (trying anyway): $(file "$dest.tmp")"; fi
    if [ "$(stat -c%s "$dest.tmp" 2>/dev/null || echo 0)" -lt 10000000 ]; then log "WARN: $dest.tmp suspiciously small: $(stat -c%s "$dest.tmp") bytes"; fi
  fi
  mv -f "$dest.tmp" "$dest"
  log "Saved $dest ($(ls -lh "$dest" | awk '{print $5}'))"
  return 0
}

# --- Ensure Nexus ---
log "Checking Nexus..."
if [ -f "$NEXUS_DLL" ] && [ "$(stat -c%s "$NEXUS_DLL" 2>/dev/null || echo 0)" -gt 1000000 ] && file "$NEXUS_DLL" | grep -q "PE32"; then
  log "Nexus d3d11.dll present: $(ls -lh "$NEXUS_DLL" | awk '{print $5}')"
else
  log "Nexus d3d11.dll missing/invalid - downloading..."
  if ! download_file "$NEXUS_URL" "$NEXUS_DLL"; then
    log "ERROR: Nexus download failed. Manually download: $NEXUS_URL -> $NEXUS_DLL"
  else
    log "Nexus installed."
  fi
fi

# --- Ensure Taimi pathing dir ---
mkdir -p "$TAIMI_PATHING_DIR" 2>/dev/null || true

# --- Ensure Tekkit markers ---
log "Checking Tekkit markers..."
if [ -f "$TEKKIT_DEST" ] && [ "$(stat -c%s "$TEKKIT_DEST" 2>/dev/null || echo 0)" -gt 10000000 ]; then
  log "Tekkit tw_ALL_IN_ONE.taco present: $(ls -lh "$TEKKIT_DEST" | awk '{print $5}')"
else
  [ -f "$TEKKIT_DEST" ] && log "Tekkit existing file too small/invalid - re-downloading..." || log "Tekkit not found - downloading..."
  rm -f "$TEKKIT_DEST.tmp"
  if download_file "$TEKKIT_URL" "$TEKKIT_DEST"; then
    log "Tekkit installed from primary URL."
  else
    log "Primary URL failed, trying fallback $TEKKIT_FALLBACK_URL"
    rm -f "$TEKKIT_DEST.tmp"
    if download_file "$TEKKIT_FALLBACK_URL" "$TEKKIT_DEST"; then
      log "Tekkit installed from fallback URL."
    else
      log "ERROR: Tekkit download failed. Place manually: $HOME/Downloads/tw_ALL_IN_ONE.taco -> $TEKKIT_DEST"
      log "  Manual: cp ~/Downloads/tw_ALL_IN_ONE.taco \"$TEKKIT_DEST\""
    fi
  fi
fi
log "Taimi pathing dir: $(ls -lh "$TAIMI_PATHING_DIR" 2>/dev/null | sed 's/^/  /' || echo "  (missing)")"
log "Addons: $(ls -R "$GW2DIR/addons" 2>/dev/null | head -20 | sed 's/^/  /' || echo "  (none)")"

if [ $# -eq 0 ]; then
  log "No %command% - running checks only (place script in Guild Wars 2/ and set Steam Launch Options to: \"$0\" %command%)"
  log "Bootstrap complete. Nexus + Tekkit ready."
  exit 0
fi

export DXVK_ASYNC=1
export MANGOHUD=0
log "Executing GW2 via Proton (preserving spaces)..."
"$@"
EXIT_CODE=$?
log "GW2 exited $EXIT_CODE"
exit $EXIT_CODE
