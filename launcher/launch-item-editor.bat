@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%launch-item-editor.ps1" -ConfigPath "%SCRIPT_DIR%launcher-config.json"
if errorlevel 1 (
    echo.
    echo Launcher failed.
    pause
    exit /b 1
)
exit /b 0
