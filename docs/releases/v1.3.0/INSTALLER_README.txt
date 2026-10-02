# Taskbar Monitor Enhanced v1.3.0

Taskbar Monitor Enhanced is a lightweight Windows taskbar system monitor for live CPU, RAM, disk, network, GPU, VRAM and temperature telemetry.

## What is new

v1.3.0 improves reliability and adds operational controls without replacing the accepted process-isolated sensor architecture.

Reliability:
- Storage temperature completion no longer depends on an overly narrow process-exit window after valid data has already been written.
- Start-with-Windows registrations are continuously checked and repaired at low pressure when enabled.

New controls:
- CPU, GPU and disk temperature warning thresholds with visual hot-state highlighting.
- Adaptive battery polling.
- Session Pause / Resume monitoring.
- Configurable sparkline history depth.
- Copy Diagnostics.
- Export Support ZIP.
- Safe reset-to-defaults with timestamped backup.
- Live Diagnostics health badge.
- A dedicated Alerts Settings page.

The protected sensor architecture remains R21 process-isolated. Broker protocol compatibility remains `1.1.2+r21`, while the upgraded Sensor Supervisor build is `1.3.0+r33` and is verified independently during installation.

## Install and uninstall

The installer registers Taskbar Monitor Enhanced in Windows Installed apps and creates the per-user uninstaller at:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe`

Uninstall through Windows Settings > Apps > Installed apps, or run:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe /uninstall`

The project uninstaller removes the application, shortcuts, Start-with-Windows registrations and uninstall registration. PawnIO is intentionally not removed automatically because another hardware-monitoring application may depend on it.

## Reliability and privacy

- Main UI runs non-elevated.
- Protected hardware sensing remains isolated and supervised.
- Start with Windows uses independent primary and recovery registrations plus bounded continuous self-heal.
- GitHub update checks and automatic installation remain constrained by immutable-release and SHA-256 integrity gates.
- Unsupported or stale sensors remain N/A rather than being fabricated.
- Support ZIP export is user initiated and written locally.
- See PRIVACY.md and CODE_SIGNING.md for network and signing policy.

## Candidate status

This document belongs to the v1.3.0 candidate build. Public release status requires the exact candidate to pass local/runtime/GitHub release gates.

## Project

Lead Developer & Maintainer: Dr. Ali-Akbar Emadeddin
License: GNU GPL v3.0
Repository: https://github.com/GOD13emad/TaskbarMonitorEnhanced
