# Official downloads — Taskbar Monitor Enhanced

## v1.1.3 — Startup Resilience

Official release page:

https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.3

Primary release assets:

- `TaskbarMonitorEnhanced_Setup_1.1.3.exe` — Windows installer
- `TaskbarMonitorEnhanced_1.1.3_SOURCE.zip` — source archive from the exact release commit
- `SHA256SUMS_v1.1.3.txt` — SHA-256 checksums for release assets
- `RELEASE_MANIFEST_v1.1.3.json` — release identity, build and validation metadata
- `R21_SBOM_v1.1.3.spdx.json` — SPDX 2.3 software bill of materials
- `V1_1_3_STARTUP_RESILIENCE_ACCEPTANCE.json` — sanitized acceptance evidence

Verify the published SHA-256 values before running the installer.

### Start-with-Windows reliability

v1.1.3 adds two independent per-user startup registrations when **Start with Windows** is enabled: the normal HKCU Run entry plus a Startup-folder recovery shortcut. If either registration is lost, the surviving launch path repairs the other. Disabling Start with Windows removes both.

### Visual verification

The repository contains current v1.1.3 live-data proofs for all 14 themes, plus 592 px and 500 px compact-layout proofs:

- [Screenshot gallery](docs/screenshots/README.md)
- [14-theme contact sheet](docs/screenshots/themes/theme-contact-sheet.png)
- [500 px compact contact sheet](docs/screenshots/compact/compact-contact-sheet-500.png)
- [592 px compact contact sheet](docs/screenshots/compact/compact-contact-sheet-592.png)

## Code signing policy

**Free code signing provided by SignPath.io, certificate by SignPath Foundation.**

SignPath Foundation application readiness has been prepared, but external acceptance and production signing are not yet proven. **v1.1.3 must be treated as unsigned unless the GitHub release itself contains independently verifiable Authenticode evidence from a publicly trusted provider.** No earlier release is rewritten to add a signature.

- [Code signing policy](CODE_SIGNING.md)
- [Privacy and update-network behavior](PRIVACY.md)

## Uninstall

Use **Windows Settings > Apps > Installed apps > Taskbar Monitor Enhanced > Uninstall**, or run:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe /uninstall`

The project uninstaller removes the application, shortcuts, both Start-with-Windows registrations, and the uninstall registration. PawnIO is intentionally retained because another hardware-monitoring application may depend on it.

Previous stable releases, including immutable v1.1.2, remain available in GitHub Releases.
