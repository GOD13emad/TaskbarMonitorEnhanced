# Official downloads — Taskbar Monitor Enhanced

## v1.3.0 — Current public release

Official immutable release:

https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.3.0

Published assets:

- `TaskbarMonitorEnhanced_Setup_1.3.0.exe`
- `TaskbarMonitorEnhanced_1.3.0_SOURCE.zip`
- `SHA256SUMS_v1.3.0.txt`
- `RELEASE_MANIFEST_v1.3.0.json`
- `SBOM_v1.3.0.spdx.json`
- `V1_3_0_R33_RELIABILITY_ALERTS_SUPPORT_ACCEPTANCE.json`
- `RELEASE_NOTES_v1.3.0.md`

The release is non-draft, non-prerelease, immutable and marked Latest. All seven published asset sizes and SHA-256 digests were verified against the pre-publication staging set.

The Windows installer SHA-256 is:

`508bb69f48d992ffc5af240f3f775b5e2caa1b052bfdb48302dec40364b521bf`

Verify the full published checksum file before running an installer.

## Visual verification

- [9-page Settings contact sheet](docs/screenshots/settings/settings-contact-sheet.png)
- [28-theme contact sheet](docs/screenshots/themes/theme-contact-sheet.png)
- [500 px compact contact sheet](docs/screenshots/compact/compact-contact-sheet-500.png)
- [592 px compact contact sheet](docs/screenshots/compact/compact-contact-sheet-592.png)
- [Screenshot gallery](docs/screenshots/README.md)

## Previous immutable release

Public v1.2.0 remains available from GitHub Releases and has not been rewritten or retagged.

## Code signing

v1.3.0 does not claim a publicly trusted Authenticode signature. Treat it as unsigned unless independent trusted-signature evidence is present.

See [CODE_SIGNING.md](CODE_SIGNING.md) and [PRIVACY.md](PRIVACY.md).

## Uninstall

Use **Windows Settings > Apps > Installed apps > Taskbar Monitor Enhanced > Uninstall**, or run:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe /uninstall`

PawnIO is intentionally retained because another hardware-monitoring application may depend on it.
