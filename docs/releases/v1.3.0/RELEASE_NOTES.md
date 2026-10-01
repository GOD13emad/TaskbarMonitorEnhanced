# Taskbar Monitor Enhanced v1.3.0 — Reliability, Alerts & Support Tools

v1.3.0 is a reliability-and-operations feature release built from the immutable v1.2.0 public baseline while retaining the accepted protected sensor compatibility layer `1.1.2+r21`.

## Reliability fixes

### Storage one-shot completion contract
- Fresh atomic storage output is validated independently from process-exit timing.
- Valid disk-temperature data is no longer discarded merely because LibreHardwareMonitor teardown exits near the timeout boundary.
- A short exit grace period is followed by bounded worker reaping.
- The no-valid-output timeout is 20 seconds.
- New diagnostics expose accepted-before-exit count, reap count, completion latency, timeout and grace values.
- `--storage-contract-selftest` verifies fresh, stale and invalid output behavior.

### Continuous Start-with-Windows self-heal
- The primary HKCU Run registration and recovery shortcut are verified every 60 seconds while Start with Windows is enabled.
- The recovery shortcut is validated by target, arguments and working directory rather than file existence alone.
- Missing or corrupt startup state is repaired only when a mismatch is observed.
- `--startup-contract-selftest` validates the shortcut contract without mutating the live registry.

## Ten new capabilities

1. Configurable CPU temperature warning threshold.
2. Configurable GPU temperature warning threshold.
3. Configurable disk temperature warning threshold.
4. High-visibility hot-state accent/border on affected metric cards.
5. Adaptive battery polling with a separate battery interval.
6. Session Pause / Resume monitoring from the taskbar context menu; user pause survives suspend/resume.
7. Configurable sparkline history depth from 30 to 300 samples.
8. Copy Diagnostics report directly to the clipboard.
9. Export a compressed support ZIP containing diagnostics, config, sensor state and recent logs.
10. Safe reset-to-defaults with a timestamped config backup and no runtime mutation until Save & Apply.

Additional UX improvement:
- Diagnostics has a live health badge and refreshes automatically when the page is selected.

## Settings and diagnostics

- Settings expands from eight to nine pages with a dedicated **Alerts** page.
- Behavior exposes adaptive battery polling and sparkline history depth.
- Diagnostics adds Copy, Support ZIP and live health summary.
- Advanced adds Safe Defaults with backup-first behavior.
- `--settingsproof <dir>` qualifies all nine pages.
- `--feature-contract-selftest` validates the new policies and support ZIP end to end.
- `--supportbundleproof <zip>` verifies support-bundle creation and ZIP readability.

## Preserved architecture

- Main UI remains non-elevated.
- CPU/GPU/storage native sensing remains isolated in protected worker processes.
- Existing 28 themes, compact-layout safeguards, taskbar parenting, hover behavior, immutable-update gates, deterministic build, SBOM and provenance controls remain in regression scope.
- v1.2.0 and all earlier public tags/assets remain immutable.

## Qualification gates

The v1.3.0 release is not accepted until the exact candidate passes: zero-warning/zero-error local build; Setup /verify; built-in self-test; storage/startup/feature contract self-tests; support ZIP proof; 28-theme proof; compact proof at 592 and 500 px; 9-page Settings proof; hover-guard proof; hardware/temperature/health/shell-state probes; deterministic clean-clone verification; live installed runtime regression and targeted startup fault injection; exact-head GitHub CI, SBOM and provenance; and release asset SHA-256 verification.

## Code signing

No publicly trusted Authenticode signature is claimed unless a trusted provider has actually issued and applied one. Public-trust signing remains an external gate.
