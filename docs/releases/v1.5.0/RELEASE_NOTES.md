# Taskbar Monitor Enhanced v1.5.0 — Actionable Alerts & Session Export

v1.5.0 builds on the immutable v1.4.0 release with a deliberately narrow product-completion change set. The protected sensor architecture and sensor binaries are unchanged.

## New

- Optional Windows taskbar notifications when CPU, GPU or disk temperature crosses its configured warning threshold.
- Anti-spam policy: 3 °C recovery hysteresis and 10-minute per-lane notification cooldown.
- Clicking a temperature notification opens the Alerts settings page.
- Bounded in-memory session telemetry history with CSV export from Diagnostics.
- CSV contains UTC timestamp, CPU/RAM/GPU percentages, VRAM, disk read/write throughput, network throughput and available temperatures.
- Quick Open Task Manager action in the taskbar context menu.

## Design rationale

The notification path reuses the existing WinForms NotifyIcon instead of introducing a Windows App SDK dependency. Microsoft documents ShowBalloonTip and BalloonTipClicked for the .NET Framework / Windows Forms stack used by this application.

The session history is bounded to 3,600 samples and stays in memory. It does not create background telemetry files and exports only on explicit user action.

## Privacy

No background cloud upload or persistent telemetry database is added. CSV export is user initiated and contains metric values and timestamps, not machine/user identity.

## Validation status

Candidate only until exact-commit build, deterministic verification, runtime regression, CI/provenance and immutable GitHub release verification are complete.

## Protected sensor layer

- Broker protocol: 1.1.2+r21
- Sensor Supervisor: 1.3.0+r33
