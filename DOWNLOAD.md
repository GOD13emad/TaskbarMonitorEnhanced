# Official downloads — Taskbar Monitor Enhanced

## v1.2.0 candidate

The v1.2.0 source candidate has completed local build, deterministic rebuild, visual proof, SBOM and installed-health gates. Public promotion still requires the exact release commit to pass GitHub CI and release publication checks.

Official release page:

https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases

Expected v1.2.0 primary assets after promotion:

- `TaskbarMonitorEnhanced_Setup_1.2.0.exe`
- source archive generated from the exact release tag
- SHA-256 checksums
- release manifest
- SPDX 2.3 SBOM

Do not treat a locally built candidate as a public release asset until it appears on the official GitHub Releases page with matching hashes.

## Visual verification

- [Modern Settings contact sheet](docs/screenshots/settings/settings-contact-sheet.png)
- [28-theme contact sheet](docs/screenshots/themes/theme-contact-sheet.png)
- [500 px compact contact sheet](docs/screenshots/compact/compact-contact-sheet-500.png)
- [592 px compact contact sheet](docs/screenshots/compact/compact-contact-sheet-592.png)
- [Screenshot gallery](docs/screenshots/README.md)

## Previous immutable release

Public v1.1.3 remains available from GitHub Releases and is not rewritten or retagged.

## Code signing

Treat a release as unsigned unless the published artifact contains independently verifiable Authenticode evidence from a publicly trusted provider.

See [CODE_SIGNING.md](CODE_SIGNING.md) and [PRIVACY.md](PRIVACY.md).

## Uninstall

Use **Windows Settings > Apps > Installed apps > Taskbar Monitor Enhanced > Uninstall**, or run:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe /uninstall`

PawnIO is intentionally retained because another hardware-monitoring application may depend on it.
