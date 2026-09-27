# Contributing

Contributions are welcome.

## Development workflow

- Start new work from `main`.
- Keep topic branches short-lived and focused on one change.
- Merged audit, maintenance, and release branches are deleted; published versions are preserved by immutable Git tags and GitHub Releases.
- Do not rewrite published tags or replace published release assets.
- The authoritative GitHub Actions workflow is `.github/workflows/ci.yml`.

## Validation

Before proposing a code or installer change, run the relevant local checks and keep the working tree clean. The release build path is:

```powershell
pwsh -NoProfile -File .\build\Build.ps1
pwsh -NoProfile -File .\build\Verify-Determinism.ps1
```

If the pinned dependency cache is already present, `Build.ps1 -NoDownload` may be used. GitHub CI remains the authoritative clean-environment verification.

For sensor, shell, startup, updater, installer, or recovery changes, include the hardware/Windows context and reproducible evidence needed to validate the affected path.

## Repository hygiene

Do not commit generated build output, local evidence captures, temporary installers, dependency caches, IDE state, private signing material, or machine-specific logs. Keep reusable source, tests, manifests, documentation, and acceptance records in Git; keep bulky local evidence and caches outside the source tree.

## Change quality

Explain the user-visible reason for the change. Include reproduction steps for bugs and hardware information for sensor-related issues. Large architectural changes should be discussed before implementation.

By contributing, you agree that your contribution may be distributed under the GNU GPL-3.0-or-later license.
