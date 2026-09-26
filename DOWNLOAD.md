# Official downloads — Taskbar Monitor Enhanced

## v1.1.2 release

https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.2

Primary assets:

- TaskbarMonitorEnhanced_Setup_1.1.2.exe
- SHA256SUMS_v1.1.2.txt
- RELEASE_MANIFEST_v1.1.2.json
- R21_SBOM.spdx.json
- final acceptance/evidence package

v1.1.2 is the accepted immutable Stable/Latest baseline. Verify the published SHA-256 values before running any installer.

## Code signing policy

**Free code signing provided by SignPath.io, certificate by SignPath Foundation.**

SignPath Foundation application readiness is prepared, but external acceptance and production signing are still pending. The existing v1.1.2 release is intentionally not rewritten or re-uploaded; public Authenticode signing will begin only with a separately versioned release after a trusted signing provider accepts the project.

- [Code signing policy](CODE_SIGNING.md)
- [Privacy and update-network behavior](PRIVACY.md)

## Uninstall

Use **Windows Settings > Apps > Installed apps > Taskbar Monitor Enhanced > Uninstall**, or run:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe /uninstall`

The project uninstaller removes the application, shortcuts, startup entry, and uninstall registration. PawnIO is intentionally retained because another hardware-monitoring application may depend on it.

Previous stable releases remain available in GitHub Releases.
