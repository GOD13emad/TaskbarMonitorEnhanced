# Installer source

This folder contains the custom Windows installer source used by Taskbar Monitor Enhanced.

## Current public authority

The current Stable/Latest public release remains v1.1.1.

## R21 candidate

The installer source in this branch targets v1.1.2-rc9 / R21 Production Hardening. It is a release candidate and must not be promoted to Stable until the elevated split-supervisor installation and installed soak gates pass.

R21 installer behavior includes:

- non-elevated main application
- elevation only for the protected hardware-sensor layer
- independent CPU, GPU and storage sensor workers
- R21 supervisor health validation across all worker lanes
- Scheduled Task restart policy limited to three retries
- MultipleInstances=IgnoreNew
- fail-closed drain of prior sensor processes before replacement
- stale split-telemetry cleanup during upgrade
- pinned LibreHardwareMonitor 0.9.6 and PawnIO 2.2.0 dependency provenance
- embedded source/license/attribution closure
- setup /verify resource gate requiring 19 resources

The authoritative reproducible build path is ../build/Build-R21.ps1.

PawnIO is intentionally retained on uninstall because another hardware-monitoring application may depend on it.

See ../docs/R21_ACCEPTANCE_STATUS.md for the current gate status.
