# Installer source

This folder contains the custom Windows installer source used by Taskbar Monitor Enhanced.

## Current public authority

This source tree targets the v1.3.0 reliability/alerts/support candidate identity. The immutable v1.2.0 release remains the historical accepted baseline while v1.3.0 is qualified independently.

## Protected sensor baseline

The installer source targets v1.3.0. The protected sensor layer retains the accepted internal compatibility identity `1.1.2+r21` when its exact compatibility gate passes; v1.3.0 updates the main application/reliability/UI layer without replacing that validated sensor layer.

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

See ../docs/acceptance/v1.2.0/PUBLIC_RELEASE_ACCEPTANCE.json for the immutable previous public authority until v1.3.0 publication completes. The candidate record is retained as pre-publication evidence; v1.1.3 remains immutable historical authority.
