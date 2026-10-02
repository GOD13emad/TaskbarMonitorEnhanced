# Taskbar Monitor Enhanced v1.4.0 — Windows Integration & Accessibility

v1.4.0 builds on the immutable v1.3.1 release and focuses on Windows integration, accessibility and security hardening.

## Windows integration

- **PerMonitorV2 DPI awareness** through .NET Framework 4.8 Windows Forms application configuration.
- The legacy manifest DPI override was removed to avoid conflicting DPI authorities.
- **Taskbar monitor selection** supports the primary taskbar and discovered secondary Windows taskbars.
- Missing/disconnected configured taskbars fall back safely to the primary taskbar with throttled diagnostics.
- All placement, recovery and shell-probe paths share the same taskbar selector.
- **Follow Windows app light/dark mode** can map Windows light and dark states to any two built-in TBME themes.
- Theme changes are observed through Windows user-preference notifications without restarting the monitor.

## Accessibility

- Settings interactive controls now expose explicit accessible names/descriptions.
- Ctrl+1 through Ctrl+9 navigate the nine Settings pages; Ctrl+S saves/applies; F5 refreshes Diagnostics.
- High Contrast uses Windows system colors for Settings and the taskbar renderer.
- Settings proof validates accessibility metadata and High Contrast styling.

## Security and diagnostics

- Process DLL lookup is hardened with `SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS)`.
- Automatic updates now reject draft/prerelease builds, noncanonical release tags/URLs and noncanonical installer URLs.
- The verified installer is SHA-256 checked **again immediately before launch**, and reparse-point installer paths are blocked.
- Privacy-safe local `last_crash.json` captures unhandled exception type/message/stack without exposing the user-profile or TBME data path.
- Crash snapshot is included in the user-initiated support ZIP when present.

## Preserved architecture

No protected sensor binary or protocol change is made in v1.4.0.

- Broker protocol: `1.1.2+r21`
- Sensor Supervisor: `1.3.0+r33`
- R21 process isolation retained.

## Validation scope

The release candidate must pass:

- 0-warning / 0-error deterministic build
- Setup verification including the deployed `TaskbarMonitorEnhanced.exe.config`
- built-in self-test and extended feature contract
- Settings 9/9 proof with PerMonitorV2, zero accessibility-name gaps and zero High Contrast style gaps
- 28/28 theme regression
- compact 592/500 regression with zero overflow
- hover/startup/health/shell/hardware/temperature regression
- deterministic multi-monitor target selection tests
- live installation on Emad-PC-Ultimate with exact R33 sensor-layer reuse
- exact-head GitHub CI and release-asset digest verification

The current validation host has one physical monitor/taskbar. Secondary-taskbar selection logic is deterministic-test covered, while a physical two-monitor attachment proof is recorded separately as unavailable on this host rather than fabricated.

Public trusted Authenticode signing is not claimed unless independently proven.
