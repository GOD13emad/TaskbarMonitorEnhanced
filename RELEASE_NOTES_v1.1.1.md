# Taskbar Monitor Enhanced 1.1.1

## Stable release

Version 1.1.1 is the current stable release.

This release addresses the two user-visible issues identified during validation:

1. repeated console/PowerShell-style flashing associated with the previous real-time external NVIDIA-SMI polling path;
2. excessive shell/taskbar background pressure, including aggressive watchdog, style and Safe Placement polling.

## Fixes

### Console-flash fix

- Default real-time `nvidia-smi.exe` polling is removed from the normal GPU telemetry path.
- WDDM and LibreHardwareMonitor remain the normal GPU telemetry sources.
- The accepted R15 NVIDIA-SMI suppression is retained.

### Taskbar / Start stability hardening

R18 keeps the native taskbar-child integration so the monitor behaves correctly with Windows 11 Start, while greatly reducing periodic shell work:

- watchdog: 40 ms -> 500 ms
- host-context polling: 250 ms -> 1000 ms
- style health: 500 ms -> 5000 ms
- placement health: 1000 ms -> 5000 ms
- style checks are read-only in the hot path
- Safe Placement / UI Automation work is event/geometry-driven rather than continuously repeated

### Settings behavior

- Settings is now single-instance.
- The first click opens Settings.
- Later clicks reuse and foreground the same Settings window instead of opening repeated dialogs.
- Cancel closes the existing Settings window.
- Save & Apply persists the configuration and closes the window.

## Validation

The accepted R18 validation recorded:

- user verdict: PASS
- Explorer PID unchanged during acceptance
- Explorer Application Hang 1002: 0
- Explorer Application Error 1000: 0
- Settings single-instance: PASS
- native Start/taskbar visual behavior: PASS
- rollback required: NO
- candidate retained locally: YES

## Upgrade

Existing users can update directly to v1.1.1 through the application's normal GitHub update path or by running:

`TaskbarMonitorEnhanced_Setup_1.1.1.exe`

Existing settings are intended to be preserved.

## Verification

Release assets:

- `TaskbarMonitorEnhanced_Setup_1.1.1.exe`
- `TaskbarMonitorEnhanced_1.1.1_SOURCE.zip`
- `SHA256SUMS_v1.1.1.txt`
- `RELEASE_MANIFEST_v1.1.1.json`
