@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "LAUNCHER_ROOT=%LOCALAPPDATA%\RaynnaItemEditorLauncher"
set "PS1_PATH=%LAUNCHER_ROOT%\launch-item-editor.ps1"
set "CONFIG_PATH=%LAUNCHER_ROOT%\launcher-config.json"
set "README_PATH=%LAUNCHER_ROOT%\README.md"
set "PS1_URL=https://raw.githubusercontent.com/raynna/raynna-item-editor-release/main/launcher/launch-item-editor.ps1"
set "CONFIG_URL=https://raw.githubusercontent.com/raynna/raynna-item-editor-release/main/launcher/launcher-config.json"
set "README_URL=https://raw.githubusercontent.com/raynna/raynna-item-editor-release/main/launcher/README.md"

if not exist "%LAUNCHER_ROOT%" mkdir "%LAUNCHER_ROOT%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "Invoke-WebRequest -Uri '%PS1_URL%' -OutFile '%PS1_PATH%';" ^
  "Invoke-WebRequest -Uri '%CONFIG_URL%' -OutFile '%CONFIG_PATH%';" ^
  "Invoke-WebRequest -Uri '%README_URL%' -OutFile '%README_PATH%';"
if errorlevel 1 (
    echo.
    echo Failed to download launcher files.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1_PATH%"
if errorlevel 1 (
    echo.
    echo Launcher failed.
    pause
    exit /b 1
)
exit /b 0
