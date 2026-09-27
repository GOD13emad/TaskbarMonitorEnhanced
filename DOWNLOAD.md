# Official downloads — Taskbar Monitor Enhanced

## v1.2.0 — Current public release

Official immutable release:

https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.2.0

Published assets:

- `TaskbarMonitorEnhanced_Setup_1.2.0.exe`
- `TaskbarMonitorEnhanced_1.2.0_SOURCE.zip`
- `SHA256SUMS_v1.2.0.txt`
- `RELEASE_MANIFEST_v1.2.0.json`
- `SBOM_v1.2.0.spdx.json`
- `V1_2_0_MODERN_SETTINGS_THEME_LIBRARY_ACCEPTANCE.json`
- `RELEASE_NOTES_v1.2.0.md`

The release is non-draft, non-prerelease, immutable and marked Latest. All seven published asset sizes and SHA-256 digests were verified against the pre-publication staging set.

The Windows installer SHA-256 is:

`3196986c62fc7d9a91500b0e3246d5640e6292d0ed1722f736505a4dd511b3cf`

Verify the full published checksum file before running an installer.

## Visual verification

- [Modern Settings contact sheet](docs/screenshots/settings/settings-contact-sheet.png)
- [28-theme contact sheet](docs/screenshots/themes/theme-contact-sheet.png)
- [500 px compact contact sheet](docs/screenshots/compact/compact-contact-sheet-500.png)
- [592 px compact contact sheet](docs/screenshots/compact/compact-contact-sheet-592.png)
- [Screenshot gallery](docs/screenshots/README.md)

## Previous immutable release

Public v1.1.3 remains available from GitHub Releases and has not been rewritten or retagged.

## Code signing

v1.2.0 does not claim a publicly trusted Authenticode signature. Treat it as unsigned unless independent trusted-signature evidence is present.

See [CODE_SIGNING.md](CODE_SIGNING.md) and [PRIVACY.md](PRIVACY.md).

## Uninstall

Use **Windows Settings > Apps > Installed apps > Taskbar Monitor Enhanced > Uninstall**, or run:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe /uninstall`

PawnIO is intentionally retained because another hardware-monitoring application may depend on it.
