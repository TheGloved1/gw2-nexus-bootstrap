@echo off
rem gw2-nexus-bootstrap easy installer (Windows)
rem CMD (Recommended): powershell -c "irm https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/windows/install.bat -OutFile install.bat" & install.bat
rem PowerShell: irm https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/windows/install.bat -OutFile install.bat; .\install.bat
rem    or: install.bat --verbose --gw2-dir "C:\Program Files\Guild Wars 2"
setlocal EnableDelayedExpansion

if defined GW2_BOOTSTRAP_RAW_URL (
  set "RAW_URL=%GW2_BOOTSTRAP_RAW_URL%"
) else (
  set "RAW_URL=https://raw.githubusercontent.com/TheGloved1/gw2-nexus-bootstrap/main/windows/gw2-nexus.bat"
)
set "GW2_DIR="
set "DO_UNINSTALL="
set "STEAM_WAS_OPEN=0"
set "VERBOSE=0"
set "STEAM_PATH="
set "STEAM_EXE="

:parse_args
if "%~1"=="" goto end_parse
if /i "%~1"=="--gw2-dir" (
  set "GW2_DIR=%~2"
  shift
  shift
  goto parse_args
)
if /i "%~1"=="--raw-url" (
  set "RAW_URL=%~2"
  shift
  shift
  goto parse_args
)
if /i "%~1"=="--uninstall" ( set "DO_UNINSTALL=1" & shift & goto parse_args )
if /i "%~1"=="--remove" ( set "DO_UNINSTALL=1" & shift & goto parse_args )
if /i "%~1"=="--clean" ( set "DO_UNINSTALL=1" & shift & goto parse_args )
if /i "%~1"=="--verbose" ( set "VERBOSE=1" & shift & goto parse_args )
if /i "%~1"=="-h" goto show_help
if /i "%~1"=="--help" goto show_help
shift
goto parse_args
:end_parse

call :find_steam

rem --- Find Guild Wars 2 ---
if defined GW2_DIR (
  call :vlog "Using --gw2-dir: %GW2_DIR%"
) else (
  call :log "Looking for Guild Wars 2..."
  call :find_gw2_via_vdf
  if not defined GW2_DIR call :find_gw2_via_common
  if not defined GW2_DIR call :find_gw2_via_where
  if defined GW2_DIR (
    call :log "Found Guild Wars 2 at: %GW2_DIR%"
  ) else (
    call :log "Could not find it automatically."
    call :prompt_manual
  )
)

if not defined GW2_DIR (
  call :err "Could not find Guild Wars 2."
  call :err "Try: install.bat --gw2-dir 'C:\path\to\Guild Wars 2'"
  exit /b 1
)
if not exist "%GW2_DIR%\Gw2-64.exe" (
  call :err "No Gw2-64.exe in: %GW2_DIR%"
  call :err "Try: install.bat --gw2-dir 'C:\path\to\Guild Wars 2'"
  exit /b 1
)
for %%F in ("%GW2_DIR%") do set "GW2_DIR=%%~fF"
call :vlog "GW2 directory: %GW2_DIR%"

if "%DO_UNINSTALL%"=="1" goto do_uninstall

rem --- Install ---
call :log "Installing..."
set "DEST=%GW2_DIR%\gw2-nexus.bat"
call :vlog "Downloading gw2-nexus.bat from %RAW_URL%"
if not exist "%GW2_DIR%" mkdir "%GW2_DIR%" >nul 2>&1
set "DL_OK=0"
where curl.exe >nul 2>&1
if "!ERRORLEVEL!"=="0" (
  curl.exe -fsSL -A "Mozilla/5.0" -o "%DEST%.tmp" "%RAW_URL%" >nul 2>&1
  if exist "%DEST%.tmp" (
    for %%A in ("%DEST%.tmp") do set "SZ=%%~zA"
    if !SZ! GTR 0 set "DL_OK=1"
  )
)
if "!DL_OK!"=="0" (
  if exist "%DEST%.tmp" del /f /q "%DEST%.tmp" >nul 2>&1
  powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%RAW_URL%' -OutFile '%DEST%.tmp' -UserAgent 'Mozilla/5.0' -UseBasicParsing; exit 0 } catch { exit 1 }" >nul 2>&1
  if exist "%DEST%.tmp" (
    for %%A in ("%DEST%.tmp") do set "SZ=%%~zA"
    if !SZ! GTR 0 set "DL_OK=1"
  )
)
if "!DL_OK!"=="0" ( call :err "Download failed" & exit /b 1 )
findstr /c:"GW2 Bootstrap" "%DEST%.tmp" >nul 2>&1
if errorlevel 1 ( call :err "Download looks wrong" & del /f /q "%DEST%.tmp" >nul 2>&1 & exit /b 1 )
move /y "%DEST%.tmp" "%DEST%" >nul 2>&1
call :log "Installed launcher to Guild Wars 2 folder."
call :log "Checking for game addons..."
call "%DEST%" >nul 2>&1
call :vlog "Bootstrap check done"
call :log "Addons ready."

set "LAUNCH="%DEST%" %%command%%"
call :vlog "Launch string: %LAUNCH%"

call :try_close_steam
if errorlevel 1 goto manual_launch_msg
call :set_launch_options
call :try_restart_steam
call :log ""
call :log "All done! Launch Options set automatically."
call :log "Start Guild Wars 2. In-game, open Nexus to install ArcDPS and TaimiHUD."
exit /b 0

:manual_launch_msg
call :log ""
call :log "All done!"
call :log "To finish, set your Steam Launch Options to:"
call :log ""
call :log "  %DEST% wrapped as:"
call :log   "%DEST%" %%command%%
call :log ""
call :log "Steam -^> Library -^> Guild Wars 2 -^> Properties -^> Launch Options -^> paste it"
call :log "Then start Guild Wars 2. In-game, open Nexus to install ArcDPS and TaimiHUD."
exit /b 0

:do_uninstall
call :log "Uninstalling..."
for %%N in ("gw2-nexus.bat" "d3d11.dll" "gw2-nexus.log") do (
  if exist "%GW2_DIR%\%%~N" (
    call :log "Removing %%~N..."
    del /f /q "%GW2_DIR%\%%~N" >nul 2>&1
  ) else (
    call :vlog "Skip (not found): %GW2_DIR%\%%~N"
  )
)
if exist "%GW2_DIR%\addons\Taimi\pathing\tw_ALL_IN_ONE.taco" (
  call :log "Removing tw_ALL_IN_ONE.taco..."
  del /f /q "%GW2_DIR%\addons\Taimi\pathing\tw_ALL_IN_ONE.taco" >nul 2>&1
) else (
  call :vlog "Skip (not found): taco"
)
if exist "%GW2_DIR%\addons\Taimi\pathing" rmdir "%GW2_DIR%\addons\Taimi\pathing" >nul 2>&1
if exist "%GW2_DIR%\addons\Taimi" rmdir "%GW2_DIR%\addons\Taimi" >nul 2>&1
call :try_close_steam
if errorlevel 1 (
  call :log "Skipped Steam settings - clear Launch Options manually in Steam if needed."
) else (
  call :clear_launch_options
  call :try_restart_steam
)
call :log Uninstalled. You can also delete the whole addons folder if you want: rmdir /s "%GW2_DIR%\addons"
exit /b 0

:show_help
echo Usage: %~nx0 [--gw2-dir PATH] [--uninstall] [--verbose]
echo   --gw2-dir PATH   GW2 install path (auto-searched if omitted)
echo   --uninstall      Remove bootstrap files and clear Steam Launch Options
echo   --verbose        Show detailed logs
exit /b 0

rem ================= Subroutines =================

:log
echo %*
exit /b 0

:vlog
if "%VERBOSE%"=="1" echo [%TIME%] %*
exit /b 0

:err
echo ERROR: %* 1>&2
exit /b 0

rem ---- Locate Steam (sets STEAM_PATH + STEAM_EXE) ----
:find_steam
set "STEAM_PATH="
set "STEAM_EXE="
for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul') do set "STEAM_PATH=%%b"
if not defined STEAM_PATH (
  for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Valve\Steam" /v InstallPath 2^>nul') do set "STEAM_PATH=%%b"
)
if not defined STEAM_PATH (
  for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Valve\Steam" /v InstallPath 2^>nul') do set "STEAM_PATH=%%b"
)
if defined STEAM_PATH set "STEAM_PATH=!STEAM_PATH:/=\!"
if defined STEAM_PATH (
  if "!STEAM_PATH:~-1!"=="\" set "STEAM_PATH=!STEAM_PATH:~0,-1!"
)
if not defined STEAM_PATH (
  if exist "%ProgramFiles(x86)%\Steam\steam.exe" set "STEAM_PATH=%ProgramFiles(x86)%\Steam"
)
if not defined STEAM_PATH (
  if exist "%ProgramFiles%\Steam\steam.exe" set "STEAM_PATH=%ProgramFiles%\Steam"
)
if defined STEAM_PATH (
  if exist "!STEAM_PATH!\steam.exe" set "STEAM_EXE=!STEAM_PATH!\steam.exe"
)
call :vlog "Steam path: %STEAM_PATH%"
exit /b 0

rem ---- VDF path unescape not needed here; powershell handles ----
:find_gw2_via_vdf
if not defined STEAM_PATH exit /b 1
if not exist "%STEAM_PATH%\steamapps\libraryfolders.vdf" exit /b 1
call :vlog "Searching libraryfolders.vdf..."
for /f "delims=" %%P in ('powershell -NoProfile -Command "try { Select-String -Path '%STEAM_PATH%\steamapps\libraryfolders.vdf' -Pattern '\"path\"\s+\"([^\"]+)\"' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value -replace '\\\\\\\\','\' } } catch { }" 2^>nul') do (
  set "LIB=%%P"
  call :vlog "  library: !LIB!"
  if exist "!LIB!\steamapps\common\Guild Wars 2\Gw2-64.exe" (
    set "GW2_DIR=!LIB!\steamapps\common\Guild Wars 2"
    exit /b 0
  )
  if exist "!LIB!\Steam\steamapps\common\Guild Wars 2\Gw2-64.exe" (
    set "GW2_DIR=!LIB!\Steam\steamapps\common\Guild Wars 2"
    exit /b 0
  )
  if exist "!LIB!\steamapps\appmanifest_1284210.acf" (
    if exist "!LIB!\steamapps\common\Guild Wars 2\Gw2-64.exe" (
      set "GW2_DIR=!LIB!\steamapps\common\Guild Wars 2"
      exit /b 0
    )
  )
)
exit /b 1

:find_gw2_via_common
call :vlog "Searching common install locations..."
set "CANDS="
if defined STEAM_PATH set "CANDS=!CANDS!|%STEAM_PATH%\steamapps\common\Guild Wars 2"
set "CANDS=%CANDS%|%ProgramFiles(x86)%\Steam\steamapps\common\Guild Wars 2"
set "CANDS=%CANDS%|%ProgramFiles%\Steam\steamapps\common\Guild Wars 2"
set "CANDS=%CANDS%|%ProgramFiles%\Guild Wars 2"
set "CANDS=%CANDS%|%ProgramFiles(x86)%\Guild Wars 2"
set "CANDS=%CANDS%|C:\Guild Wars 2"
set "CANDS=%CANDS%|D:\SteamLibrary\steamapps\common\Guild Wars 2"
set "CANDS=%CANDS%|E:\SteamLibrary\steamapps\common\Guild Wars 2"
set "CANDS=%CANDS%|F:\SteamLibrary\steamapps\common\Guild Wars 2"
for %%D in ("%CANDS:|=" "%") do (
  set "C=%%~D"
  if defined C (
    call :vlog "  check: !C!"
    if exist "!C!\Gw2-64.exe" (
      set "GW2_DIR=!C!"
      exit /b 0
    )
  )
)
exit /b 1

:find_gw2_via_where
where Gw2-64.exe >nul 2>&1
if errorlevel 1 exit /b 1
for /f "delims=" %%F in ('where Gw2-64.exe 2^>nul') do (
  for %%D in ("%%~dpF.") do set "GW2_DIR=%%~fD"
  call :vlog "  where found: !GW2_DIR!"
  exit /b 0
)
exit /b 1

:prompt_manual
set "MANUAL="
set /p MANUAL="Guild Wars 2 not found. Enter full path to your Guild Wars 2 folder: "
if not defined MANUAL exit /b 1
set "MANUAL=!MANUAL:"=!"
if not defined MANUAL exit /b 1
if not exist "%MANUAL%\Gw2-64.exe" (
  call :err "No Gw2-64.exe found there"
  exit /b 1
)
set "GW2_DIR=%MANUAL%"
exit /b 0

:ask_close_steam
set "ANS="
set /p ANS="Close Steam and auto-update Launch Options (Y/n): "
if not defined ANS exit /b 0
if /i "%ANS:~0,1%"=="N" exit /b 1
if /i "%ANS:~0,1%"=="Y" exit /b 0
exit /b 0

:try_close_steam
tasklist /FI "IMAGENAME eq steam.exe" 2>nul | findstr /i "steam.exe" >nul 2>&1
if errorlevel 1 exit /b 0
set "STEAM_WAS_OPEN=1"
call :ask_close_steam
if errorlevel 1 exit /b 1
call :log "Closing Steam..."
if defined STEAM_EXE (
  "%STEAM_EXE%" -shutdown >nul 2>&1
) else (
  steam -shutdown >nul 2>&1
)
for /l %%i in (1,1,60) do (
  tasklist /FI "IMAGENAME eq steam.exe" 2>nul | findstr /i "steam.exe" >nul 2>&1
  if errorlevel 1 (
    timeout /t 1 /nobreak >nul 2>&1
    tasklist /FI "IMAGENAME eq steam.exe" 2>nul | findstr /i "steam.exe" >nul 2>&1
    if errorlevel 1 (
      call :vlog "Steam closed."
      exit /b 0
    )
  )
  timeout /t 1 /nobreak >nul 2>&1
)
call :err "Steam still running after 30 seconds."
call :log "Please close Steam manually and run again."
exit /b 1

:try_restart_steam
if not "%STEAM_WAS_OPEN%"=="1" exit /b 0
tasklist /FI "IMAGENAME eq steam.exe" 2>nul | findstr /i "steam.exe" >nul 2>&1
if not errorlevel 1 exit /b 0
call :log "Restarting Steam..."
if defined STEAM_EXE (
  start "" "%STEAM_EXE%" >nul 2>&1
) else (
  start "" steam >nul 2>&1
)
for /l %%i in (1,1,20) do (
  tasklist /FI "IMAGENAME eq steam.exe" 2>nul | findstr /i "steam.exe" >nul 2>&1
  if not errorlevel 1 (
    call :vlog "Steam restarted."
    exit /b 0
  )
  timeout /t 1 /nobreak >nul 2>&1
)
call :log "Steam restart sent - open it manually if needed."
exit /b 0

rem Uses global LAUNCH set by caller
:set_launch_options
set "NEWLAUNCH=!LAUNCH!"
call :vlog "Updating Launch Options to: !NEWLAUNCH!"
if not defined STEAM_PATH (
  call :vlog "No Steam path, skipping VDF edit"
  exit /b 0
)
set "FOUND_VDF=0"
for /d %%U in ("%STEAM_PATH%\userdata\*") do (
  if exist "%%U\config\localconfig.vdf" (
    findstr /c:"\"1284210\"" "%%U\config\localconfig.vdf" >nul 2>&1
    if not errorlevel 1 (
      set "FOUND_VDF=1"
      call :vlog "  %%U\config\localconfig.vdf"
      copy /y "%%U\config\localconfig.vdf" "%%U\config\localconfig.vdf.bak" >nul 2>&1
      set "VDF_PATH=%%U\config\localconfig.vdf"
      call :vdf_set_launch
      call :log "Launch Options updated!"
      goto :eof_done_set_launch
    )
  )
)
:eof_done_set_launch
if "%FOUND_VDF%"=="0" call :vlog "No localconfig.vdf with 1284210 found; set Launch Options manually"
exit /b 0

rem Uses globals VDF_PATH + NEWLAUNCH (avoids quote-splitting of launch string)
:vdf_set_launch
powershell -NoProfile -ExecutionPolicy Bypass -Command "$path='!VDF_PATH!'; $launch='!NEWLAUNCH!'; $d=[IO.File]::ReadAllText($path); $esc=$launch -replace '\\\\','\\\\\\\\' -replace '\"','\\\"'; $n=[regex]::Replace($d, '(\"1284210\"\\s*\\{[^}]*\"LaunchOptions\"\\s*)\"(?:[^\"\\\\]|\\\\.)*\"', '${1}\"' + $esc + '\"', 'Singleline'); [IO.File]::WriteAllText($path, $n)" >nul 2>&1
exit /b 0

:clear_launch_options
if not defined STEAM_PATH exit /b 0
for /d %%U in ("%STEAM_PATH%\userdata\*") do (
  if exist "%%U\config\localconfig.vdf" (
    findstr "gw2-nexus.bat" "%%U\config\localconfig.vdf" >nul 2>&1
    if not errorlevel 1 (
      findstr /c:"\"1284210\"" "%%U\config\localconfig.vdf" >nul 2>&1
      if not errorlevel 1 (
        call :log "Clearing Launch Options..."
        copy /y "%%U\config\localconfig.vdf" "%%U\config\localconfig.vdf.bak" >nul 2>&1
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$path='%%U\config\localconfig.vdf'; $d=[IO.File]::ReadAllText($path); $n=[regex]::Replace($d, '(\"1284210\"\\s*\\{[^}]*\"LaunchOptions\"\\s*)\"(?:[^\"\\\\]|\\\\.)*gw2-nexus\\.bat(?:[^\"\\\\]|\\\\.)*\"', '${1}\"\"', 'Singleline'); [IO.File]::WriteAllText($path, $n)" >nul 2>&1
        call :log "Launch Options cleared!"
      )
    )
  )
)
exit /b 0
