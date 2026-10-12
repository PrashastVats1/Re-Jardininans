# Desktop export plan

Status: planned only. No export presets exist yet; exports are set up in
Milestone 4.

## Targets

| Platform | Architecture | Notes |
|---|---|---|
| Linux | x86_64 | Single executable with embedded PCK |
| Windows | x86_64 | Single `.exe` with embedded PCK |
| macOS | universal (x86_64 + arm64) | `.zip` containing the `.app` |

Android and iOS are optional future targets and are not covered here.

## Setup

1. In the editor: **Editor → Manage Export Templates**, install templates for
   exactly **4.7.2**. Templates must match the editor version.
2. **Project → Export**, add one preset per platform. Enable
   *Embed PCK* where available.
3. Commit `export_presets.cfg`. Godot 4 keeps signing secrets separately in
   `.godot/export_credentials.cfg`, which is git-ignored.

## Building from the command line

```bash
godot --headless --path . --export-release "Linux" /path/to/build/linux/re-jardinians.x86_64
godot --headless --path . --export-release "Windows Desktop" /path/to/build/windows/re-jardinians.exe
godot --headless --path . --export-release "macOS" /path/to/build/macos/re-jardinians.zip
```

Preset names must match those in `export_presets.cfg`.

## Where to put builds

This repository lives on an NTFS partition. NTFS does not store real Unix
permissions, so every file looks executable and archives made from it carry
wrong permission bits. Write export output to a folder on a Linux-native
filesystem (e.g. `~/builds/re-jardinians/`), not inside this repository.

## Platform notes

### Windows

- Setting the `.exe` icon and file metadata requires the external `rcedit`
  tool (and Wine when exporting from Linux). Without it, disable
  *Application → Modify Resources* in the preset; the game still runs, with
  the default icon.

### macOS

- Use ad-hoc code signing. This is sufficient for family sharing.
- On first launch, recipients must right-click the app and choose **Open**, or
  run:

  ```bash
  xattr -dr com.apple.quarantine "/Applications/Re-Jardinians!.app"
  ```

- Notarization requires a paid Apple Developer account and a Mac; it is out of
  scope for this project.

### Linux

- Ship the executable inside a `.tar.gz` created on a Linux-native filesystem
  so only the binary has the executable bit.
