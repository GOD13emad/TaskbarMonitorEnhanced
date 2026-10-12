# Download Taskbar Monitor Enhanced

## Official Stable v1.7.0 — unsigned

[Official v1.7.0 GitHub Release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.7.0)

[Windows x64 Setup 1.7.0](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.7.0/TaskbarMonitorEnhanced_Setup_1.7.0.exe)

**Installer SHA-256:** `148827212B716238DDB270309F393140EBE3CB935CD0E80D36233220A4BE611E`

This is an owner-authorized **official stable release without Authenticode signing**. Windows may show **Unknown publisher** or a SmartScreen warning. Verify the exact SHA-256 against the official `SHA256SUMS_v1.7.0.txt` before deciding to run the file.

### Exactly one installation: no uninstall/reinstall

- **Fresh install:** double-click `TaskbarMonitorEnhanced_Setup_1.7.0.exe`. It installs one copy to `%LOCALAPPDATA%\TaskbarMonitorEnhanced` for the active Windows user.
- **Update from official v1.6.0 or public unsigned Preview1:** first close the running monitor normally, then double-click the **same** v1.7.0 Setup. It detects a recognized previous installation and upgrades **in place**. Do not uninstall or reinstall.
- **Silent existing-install update:** run `TaskbarMonitorEnhanced_Setup_1.7.0.exe /update /quiet`. If there is no trusted existing installation, this fails safely; it does not make another copy.
- **Safety:** the updater preserves configuration, backup, unknown user files, sensor backend, Startup registration, and Wallpaper mode. Exact manifest checks reject unknown/modified managed program files. Rerunning the same fully installed version is a no-op.
- **Protected temperature sensors:** the main monitor runs even without PawnIO, with unavailable temperatures shown as N/A. Separately licensed official signed PawnIO is not bundled, silently downloaded or installed.

### Test evidence

R113 exact Main: **8/8 actual installed UI and sensor probes on both independent temporary Windows hosts**, including Start, Shell and original display/taskbar rollback. R114 exact Setup: in-place upgrades from the **genuine immutable public v1.6.0 and Preview1** were each validated on a separate fresh Windows host with preservation of data and Startup, single-root installation and idempotence. Source and SBOM, exact SHA-256 sums, release manifest and acceptance receipts accompany the Release.

The external signed laboratory witness and a physical AC-power-cut durability test were **not** independently completed. Code signing was explicitly waived by the owner; no signed publisher identity is represented.

Previous immutable public releases remain available unchanged. See [release notes](docs/releases/v1.7.0/RELEASE_NOTES.md) and the [code-signing policy](CODE_SIGNING.md).
