# Installer source

This folder contains the custom Windows installer source used by Taskbar Monitor Enhanced.

## Current public authority

The current immutable public version is v1.6.0. The v1.7.0 candidate is not released; its OSS signing path excludes the separately licensed official PawnIO binary.

## Protected sensor baseline

The v1.7.0 candidate retains the R21 process-isolated architecture, Broker protocol 1.1.2+r21 and Sensor Supervisor 1.3.0+r33. Sensor reuse remains gated by exact payload hashes and live health. A missing optional PawnIO dependency degrades protected temperatures rather than triggering an unexpected driver download or installation.

Installer behavior includes:

- non-elevated main application
- elevation only for the protected hardware-sensor layer
- independent CPU, GPU and storage sensor workers
- supervisor health validation across all protected-sensor worker lanes
- Scheduled Task restart policy limited to three retries
- MultipleInstances=IgnoreNew
- fail-closed drain of prior sensor processes before replacement
- stale split-telemetry cleanup during upgrade
- pinned LibreHardwareMonitor 0.9.6 and optional external PawnIO 2.2.0 provenance (the official PawnIO binary is NOT bundled in the OSS Setup)
- embedded source/license/attribution closure
- setup /verify resource gate requiring 25 OSS resources with PawnIOBundled=false, including TaskbarMonitorEnhanced.exe.config

The authoritative reproducible build path is ../build/Build.ps1.

PawnIO is intentionally retained on uninstall because other hardware-monitoring apps may depend on it. Existing PawnIO >=2.2.0 is reused; otherwise protected sensors safely degrade. Users explicitly install the optional official PawnIO driver from https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0; Setup does not silently download it.

See ../docs/acceptance/v1.6.0/PUBLIC_RELEASE_ACCEPTANCE.json for the current immutable public authority. v1.5.0 and earlier releases remain immutable historical authorities.
