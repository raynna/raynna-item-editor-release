# Raynna Item Editor Launcher

Avalon-style self-contained Windows launcher.

It:
- reads `manifest.json` from the release repo
- installs Java 21 locally if missing
- downloads the latest packaged editor zip
- verifies SHA-256
- extracts it locally
- launches the editor
- runs standalone from `ItemEditorLauncher.exe`; `launcher-config.json` is optional

Build with:

```text
launcher/build-launcher.bat
```

Primary output:

```text
launcher/dist/ItemEditorLauncher.exe
```

Fallback output if `dist` is locked:

```text
launcher/dist-build/ItemEditorLauncher.exe
```
