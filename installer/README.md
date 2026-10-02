# Installer source

This folder contains the custom Windows installer source used by Taskbar Monitor Enhanced.

## Current public authority

This source tree targets the v1.3.1 reliability/alerts/support candidate identity. The immutable v1.2.0 release remains the historical accepted baseline while v1.3.1 is qualified independently.

## Protected sensor baseline

The installer source targets v1.3.1. The protected R21 process-isolated architecture and Broker protocol `1.1.2+r21` are retained, and the already-accepted Sensor Supervisor remains `1.3.0+r33`. v1.3.1 is a Main/UI patch adding renderer-backed theme previews. Sensor reuse is allowed only when exact payload hashes, both sensor identities, and live health all match.

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
- setup /verify resource gate requiring 19 resources

The authoritative reproducible build path is ../build/Build.ps1.

PawnIO is intentionally retained on uninstall because another hardware-monitoring application may depend on it.

See ../docs/acceptance/v1.2.0/PUBLIC_RELEASE_ACCEPTANCE.json for the immutable previous public authority until v1.3.1 publication completes. The candidate record is retained as pre-publication evidence; v1.1.3 remains immutable historical authority.
