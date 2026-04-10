# Raynna Item Editor Launcher

This launcher is a compact Windows-native launcher with no extra install requirement.

It:
- checks `manifest.json` from the release repo
- downloads the newest packaged editor zip
- verifies SHA-256
- extracts it locally
- starts the packaged `run-item-editor.bat`

Players only need `launch-item-editor.bat`.
That batch file downloads the current launcher script/config automatically, then handles the rest.

## Build

From `launcher/`:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-exe.ps1
```

Or double-click:

```text
launcher/build-launcher.bat
```

Output:

```text
launcher/dist/launch-item-editor.bat
```
