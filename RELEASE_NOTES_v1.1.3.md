# Taskbar Monitor Enhanced v1.1.3 — Startup Resilience

v1.1.3 is a focused reliability patch derived from the immutable v1.1.2 baseline. It does not rewrite or replace v1.1.2 and does not change the accepted protected sensor architecture.

## Fixed

- Start with Windows is resilient to loss of a single startup registration.
- When enabled, the application maintains two independent per-user registrations: the normal HKCU Run value for immediate launch and a Startup-folder recovery shortcut invoking --startup-recovery.
- If either registration disappears, the surviving path launches the app and the app recreates the missing registration.
- Recovery mode waits up to 12 seconds for the primary launch path and exits as soon as another Taskbar Monitor Enhanced process is detected. The existing named mutex remains the final single-instance guard.
- Turning Start with Windows off removes both registrations. Uninstall removes both.

## Preserved

- The accepted 1.1.2+r21 protected sensor layer is reused when exact compatibility checks pass.
- CPU/GPU/storage isolation, suspend/resume handling, taskbar recovery, update-integrity checks and the 14-theme renderer remain unchanged except for version/about text.
- v1.1.2 remains immutable and is never retagged or overwritten.

## Publication gates

Publication is allowed only after deterministic build, Setup /verify, built-in self-test, all 14 live theme proofs, compact proofs, installed startup fault-injection, GitHub Actions build/SBOM/provenance and immutable asset/hash checks pass on the exact release commit.

## Code signing

No publicly trusted Authenticode signature is claimed unless a trusted provider has actually issued and applied one. SignPath Foundation acceptance remains an external gate until independently confirmed.
