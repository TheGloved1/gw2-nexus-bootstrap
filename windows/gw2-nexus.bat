@echo off
rem Universal GW2 + Nexus + TaimiHUD bootstrap (Windows) - drop into any Guild Wars 2\ and set Steam Launch Options to: "C:\path\to\Guild Wars 2\gw2-nexus.bat" %%command%%
rem Auto-downloads Nexus and Tekkit marker pack if missing.
rem Sources: Nexus https://github.com/RaidcoreGG/Nexus/releases/latest/download/d3d11.dll
rem          Tekkit  https://www.tekkitsworkshop.net/download?download=1:tw-all-in-one (fallback direct)
setlocal EnableDelayedExpansion

rem --- Portable GW2DIR detection (script location) ---
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "GW2DIR=%SCRIPT_DIR%"
if not exist "%GW2DIR%\Gw2-64.exe" (
  rem Fallback 1: Steam passes the game exe as %%1 when Launch Options are "<bat>" %%command%%
  if /i "%~1"=="waitforexitandrun" (
    if not "%~2"=="" (
      for %%F in ("%~2") do set "CANDDIR=%%~dpF"
      if "!CANDDIR:~-1!"=="\" set "CANDDIR=!CANDDIR:~0,-1!"
      if exist "!CANDDIR!\Gw2-64.exe" set "GW2DIR=!CANDDIR!"
    )
  )
  if not exist "!GW2DIR!\Gw2-64.exe" (
    if not "%~1"=="" (
      for %%F in ("%~1") do (
        if /i "%%~nxF"=="Gw2-64.exe" (
          set "CANDDIR=%%~dpF"
          if "!CANDDIR:~-1!"=="\" set "CANDDIR=!CANDDIR:~0,-1!"
          if exist "!CANDDIR!\Gw2-64.exe" set "GW2DIR=!CANDDIR!"
        )
      )
    )
  )
  rem Fallback 2: scan all args for something ending in Gw2-64.exe
  if not exist "!GW2DIR!\Gw2-64.exe" (
    for %%A in (%*) do (
      for %%F in ("%%~A") do (
        if /i "%%~nxF"=="Gw2-64.exe" (
          if exist "%%~F" (
            set "CANDDIR=%%~dpF"
            if "!CANDDIR:~-1!"=="\" set "CANDDIR=!CANDDIR:~0,-1!"
            if exist "!CANDDIR!\Gw2-64.exe" set "GW2DIR=!CANDDIR!"
          )
        )
      )
    )
  )
)
for %%F in ("%GW2DIR%") do set "GW2DIR=%%~fF"

set "LOGFILE=%GW2DIR%\gw2-nexus.log"
set "NEXUS_DLL=%GW2DIR%\d3d11.dll"
set "NEXUS_URL=https://github.com/RaidcoreGG/Nexus/releases/latest/download/d3d11.dll"
set "TAIMI_PATHING_DIR=%GW2DIR%\addons\Taimi\pathing"
set "TEKKIT_DEST=%TAIMI_PATHING_DIR%\tw_ALL_IN_ONE.taco"
set "TEKKIT_URL=https://www.tekkitsworkshop.net/download?download=1:tw-all-in-one"
set "TEKKIT_FALLBACK_URL=https://www.tekkitsworkshop.net/downloads/tw_ALL_IN_ONE.taco"

rem --- Logging setup (2MB rotation, keep last 500 lines) ---
if not exist "%GW2DIR%" (
  echo [ERROR] GW2DIR not found: %GW2DIR%
  exit /b 1
)
if exist "%LOGFILE%" (
  for %%A in ("%LOGFILE%") do set "LOGSIZE=%%~zA"
  if !LOGSIZE! GTR 2097152 (
    powershell -NoProfile -Command "Get-Content -Tail 500 '!LOGFILE!' | Set-Content '!LOGFILE!.tmp'" >nul 2>&1
    if exist "%LOGFILE%.tmp" (
      move /y "%LOGFILE%.tmp" "%LOGFILE%" >nul 2>&1
    ) else (
      del /f /q "%LOGFILE%" >nul 2>&1
    )
  )
)

call :log "=== GW2 Bootstrap (Nexus + TaimiHUD) [Windows] ==="
call :log "GW2DIR=%GW2DIR%"
call :log "SCRIPT_DIR=%SCRIPT_DIR%"
call :log "LOGFILE=%LOGFILE%"
cd /d "%GW2DIR%" 2>nul || ( call :log "ERROR: GW2DIR not found: %GW2DIR%" & exit /b 1 )
call :log "PWD: %CD%"

rem --- Ensure Nexus ---
call :log "Checking Nexus..."
set "NEXUS_OK=0"
if exist "%NEXUS_DLL%" (
  for %%A in ("%NEXUS_DLL%") do set "NEXUS_SIZE=%%~zA"
  if !NEXUS_SIZE! GTR 1000000 (
    call :check_mz "%NEXUS_DLL%"
    if "!ERRORLEVEL!"=="0" set "NEXUS_OK=1"
  )
)
if "%NEXUS_OK%"=="1" (
  for %%A in ("%NEXUS_DLL%") do call :log "Nexus d3d11.dll present: %%~zA bytes"
) else (
  call :log "Nexus d3d11.dll missing/invalid - downloading..."
  call :download_file "%NEXUS_URL%" "%NEXUS_DLL%"
  if errorlevel 1 (
    call :log "ERROR: Nexus download failed. Manually download: %NEXUS_URL% -^> %NEXUS_DLL%"
  ) else (
    call :log "Nexus installed."
  )
)

rem --- Ensure Taimi pathing dir ---
if not exist "%TAIMI_PATHING_DIR%" mkdir "%TAIMI_PATHING_DIR%" >nul 2>&1

rem --- Ensure Tekkit markers ---
call :log "Checking Tekkit markers..."
set "TEKKIT_OK=0"
if exist "%TEKKIT_DEST%" (
  for %%A in ("%TEKKIT_DEST%") do set "TEKKIT_SIZE=%%~zA"
  if !TEKKIT_SIZE! GTR 10000000 set "TEKKIT_OK=1"
)
if "%TEKKIT_OK%"=="1" (
  for %%A in ("%TEKKIT_DEST%") do call :log "Tekkit tw_ALL_IN_ONE.taco present: %%~zA bytes"
) else (
  if exist "%TEKKIT_DEST%" (
    call :log "Tekkit existing file too small/invalid - re-downloading..."
  ) else (
    call :log "Tekkit not found - downloading..."
  )
  if exist "%TEKKIT_DEST%.tmp" del /f /q "%TEKKIT_DEST%.tmp" >nul 2>&1
  call :download_file "%TEKKIT_URL%" "%TEKKIT_DEST%"
  if errorlevel 1 (
    call :log "Primary URL failed, trying fallback %TEKKIT_FALLBACK_URL%"
    if exist "%TEKKIT_DEST%.tmp" del /f /q "%TEKKIT_DEST%.tmp" >nul 2>&1
    call :download_file "%TEKKIT_FALLBACK_URL%" "%TEKKIT_DEST%"
    if errorlevel 1 (
      call :log "ERROR: Tekkit download failed. Place manually: %%USERPROFILE%%\Downloads\tw_ALL_IN_ONE.taco -^> %TEKKIT_DEST%"
    ) else (
      call :log "Tekkit installed from fallback URL."
    )
  ) else (
    call :log "Tekkit installed from primary URL."
  )
)
call :log "Taimi pathing dir contents:"
dir /b "%TAIMI_PATHING_DIR%" >>"%LOGFILE%" 2>&1
dir /b "%TAIMI_PATHING_DIR%" 2>nul || ( call :log "  (missing)" )
if exist "%GW2DIR%\addons" (
  call :log "Addons tree:"
  dir /s /b "%GW2DIR%\addons" >>"%LOGFILE%" 2>&1
) else (
  call :log "Addons: (none)"
)

if "%~1"=="" (
  call :log No %%command%% - running checks only ^(place script in Guild Wars 2\ and set Steam Launch Options to: '%~f0' %%command%%^)
  call :log "Bootstrap complete. Nexus + Tekkit ready."
  exit /b 0
)

rem --- Launch GW2 (Steam %%command%% => %%1 = game exe, rest = game args) ---
set "GAME=%~1"
shift
set "ARGS="
:collect_args
if "%~1"=="" goto collected_args
if defined ARGS (
  set "ARGS=!ARGS! %1"
) else (
  set "ARGS=%1"
)
shift
goto collect_args
:collected_args
call :log Executing GW2: '%GAME%' !ARGS!
"%GAME%" %ARGS%
set "EXIT_CODE=%ERRORLEVEL%"
call :log "GW2 exited %EXIT_CODE%"
exit /b %EXIT_CODE%

rem ================= Subroutines =================

:log
echo [%DATE% %TIME%] %*
echo [%DATE% %TIME%] %*>>"%LOGFILE%" 2>nul
exit /b 0

rem %1 = file -> errorlevel 0 if starts with MZ
:check_mz
powershell -NoProfile -Command "$p='%~1'; try { $b=[IO.File]::ReadAllBytes($p); if ($b.Length -ge 2 -and $b[0] -eq 77 -and $b[1] -eq 90) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
exit /b %ERRORLEVEL%

rem %1 = file -> errorlevel 0 if starts with PK (zip)
:check_pk
powershell -NoProfile -Command "$p='%~1'; try { $b=[IO.File]::ReadAllBytes($p); if ($b.Length -ge 2 -and $b[0] -eq 80 -and $b[1] -eq 75) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
exit /b %ERRORLEVEL%

rem %1 = url, %2 = dest
:download_file
set "DL_URL=%~1"
set "DL_DEST=%~2"
for %%F in ("%DL_DEST%") do set "DL_DIR=%%~dpF"
if not exist "!DL_DIR!" mkdir "!DL_DIR!" >nul 2>&1
call :log "Downloading !DL_URL! -^> !DL_DEST!"
set "DL_OK=0"
where curl.exe >nul 2>&1
if "!ERRORLEVEL!"=="0" (
  curl.exe -L -A "Mozilla/5.0" --referer "https://www.tekkitsworkshop.net/" --connect-timeout 15 --retry 2 -o "!DL_DEST!.tmp" "!DL_URL!" >>"%LOGFILE%" 2>&1
  if exist "!DL_DEST!.tmp" (
    for %%A in ("!DL_DEST!.tmp") do set "DL_TMP_SIZE=%%~zA"
    if !DL_TMP_SIZE! GTR 0 set "DL_OK=1"
  )
)
if "!DL_OK!"=="0" (
  if exist "!DL_DEST!.tmp" del /f /q "!DL_DEST!.tmp" >nul 2>&1
  call :log "  curl missing/failed, trying PowerShell Invoke-WebRequest..."
  powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '!DL_URL!' -OutFile '!DL_DEST!.tmp' -Headers @{'Referer'='https://www.tekkitsworkshop.net/'} -UserAgent 'Mozilla/5.0' -UseBasicParsing; exit 0 } catch { exit 1 }" >>"%LOGFILE%" 2>&1
  if exist "!DL_DEST!.tmp" (
    for %%A in ("!DL_DEST!.tmp") do set "DL_TMP_SIZE=%%~zA"
    if !DL_TMP_SIZE! GTR 0 set "DL_OK=1"
  )
)
if "!DL_OK!"=="0" (
  call :log "ERROR: download empty/failed: !DL_URL!"
  if exist "!DL_DEST!.tmp" del /f /q "!DL_DEST!.tmp" >nul 2>&1
  exit /b 1
)
for %%A in ("!DL_DEST!.tmp") do set "DL_TMP_SIZE=%%~zA"
echo "!DL_DEST!" | findstr /i "\.dll$" >nul 2>&1
if "!ERRORLEVEL!"=="0" (
  call :check_mz "!DL_DEST!.tmp"
  if "!ERRORLEVEL!" NEQ "0" (
    call :log "ERROR: !DL_DEST!.tmp is not a PE DLL (missing MZ header)"
    del /f /q "!DL_DEST!.tmp" >nul 2>&1
    exit /b 1
  )
) else (
  call :check_pk "!DL_DEST!.tmp"
  if "!ERRORLEVEL!" NEQ "0" call :log "WARN: !DL_DEST!.tmp is not Zip (trying anyway)"
  if !DL_TMP_SIZE! LSS 10000000 call :log "WARN: !DL_DEST!.tmp suspiciously small: !DL_TMP_SIZE! bytes"
)
move /y "!DL_DEST!.tmp" "!DL_DEST!" >nul 2>&1
for %%A in ("!DL_DEST!") do call :log "Saved !DL_DEST! (%%~zA bytes)"
exit /b 0
