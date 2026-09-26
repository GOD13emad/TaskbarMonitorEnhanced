# Installer source

This folder contains the custom Windows installer source used by Taskbar Monitor Enhanced.

## Current public authority

This source tree targets the final v1.1.2 R21 release identity. Public Stable/Latest promotion is allowed only after exact final build, install, runtime and supply-chain gates pass.

## R21 candidate

The installer source targets v1.1.2 / R21 Production Hardening and retains the behavior accepted on RC10. The final release identity changes version/release metadata only; protected-sensor and runtime behavior remain governed by the accepted R21 gates.

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
