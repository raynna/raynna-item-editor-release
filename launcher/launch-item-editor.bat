@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%launch-item-editor.ps1"
if errorlevel 1 (
    echo.
    echo Launcher failed.
    pause
    exit /b 1
)
exit /b 0
