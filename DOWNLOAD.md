# Download Taskbar Monitor Enhanced

## Current stable release: v1.6.0

[Open the official immutable v1.6.0 release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.6.0)

[Download the Windows x64 installer](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.6.0/TaskbarMonitorEnhanced_Setup_1.6.0.exe)

The release has eight monitoring workspace pages and 48 themes, including twenty original Studio geometries. The 28 previous themes and existing settings are preserved.

| Integrity field | Accepted value |
|---|---|
| Release ID | `402214671` |
| Source commit | `1652989b80c5c6d301c6f05818c48c5207fd9b7a` |
| Published UTC | `2026-10-02T23:13:33Z` |
| Immutable / Latest | `true / true` |
| Installer bytes | `11447808` |
| Installer SHA-256 | `f5130bc2f81383e16912454fcc62e307501885a6256e7241e674a9cf10bac9c5` |
| Published asset digest matches | `7 / 7` |

Seven release files provide the installer, exact source ZIP, release notes, verified-CI SPDX SBOM, acceptance record, release manifest and SHA-256 checksums. The SBOM is the verified Setup attestation predicate with normalized JSON formatting.

## Verification and installation

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath "$env:USERPROFILE\Downloads\TaskbarMonitorEnhanced_Setup_1.6.0.exe"
```

Compare the entire SHA-256 value above before starting the installer. Use the exact filename; do not select a guessed newest/wildcard installer. Normal installation runs the main app without elevation. The optional protected sensor layer may require administrator approval; the tested upgrade reused the exact healthy existing R33/R21 layer without changes.

**Public-trust Authenticode signing is pending.** Windows may display Unknown publisher. GitHub/Sigstore provenance and SHA-256 verification do not claim a trusted publisher certificate. See [Code signing](CODE_SIGNING.md).

## Acceptance evidence

[Public acceptance](docs/acceptance/v1.6.0/PUBLIC_RELEASE_ACCEPTANCE.json) records exact build, clean-clone determinism, 15 candidate suites, 15 installed suites, 69 unchanged configuration properties, actual UI actions, 48-theme/20-geometry proof and protected-sensor preservation.

Exact-source CI: [release branch](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/37074301100) and [main](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/37075175655).

Earlier releases remain unchanged as historical baselines. Pre-integration v1.6 installers are not the accepted v1.6 release; compare the SHA-256, not just the displayed version string.
