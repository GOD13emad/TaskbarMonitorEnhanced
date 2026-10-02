# Installer source

This folder contains the custom Windows installer source used by Taskbar Monitor Enhanced.

## Current public authority

This source tree targets the v1.5.0 Actionable Alerts & Session Export candidate. The immutable v1.4.0 release is the current accepted public baseline while v1.5.0 is qualified independently.

## Protected sensor baseline

The installer source targets v1.5.0. The protected R21 process-isolated architecture and Broker protocol 1.1.2+r21 are retained, and the accepted Sensor Supervisor remains 1.3.0+r33. v1.5.0 is a Main/UI-only change set adding rate-limited temperature notifications, bounded session CSV export and a Task Manager quick action on top of the v1.4.0 integration/accessibility baseline. Sensor reuse remains gated by exact payload hashes, both sensor identities and live health.

Installer behavior includes:

- non-elevated main application
- elevation only for the protected hardware-sensor layer
- independent CPU, GPU and storage sensor workers
- supervisor health validation across all protected-sensor worker lanes
- Scheduled Task restart policy limited to three retries
- MultipleInstances=IgnoreNew
- fail-closed drain of prior sensor processes before replacement
- stale split-telemetry cleanup during upgrade
- pinned LibreHardwareMonitor 0.9.6 and PawnIO 2.2.0 dependency provenance
- embedded source/license/attribution closure
- setup /verify resource gate requiring 20 resources, including TaskbarMonitorEnhanced.exe.config

The authoritative reproducible build path is ../build/Build.ps1.

PawnIO is intentionally retained on uninstall because another hardware-monitoring application may depend on it.

See ../docs/acceptance/v1.4.0/PUBLIC_RELEASE_ACCEPTANCE.json for the immutable public authority until v1.5.0 publication completes. Earlier releases remain immutable historical authorities.
