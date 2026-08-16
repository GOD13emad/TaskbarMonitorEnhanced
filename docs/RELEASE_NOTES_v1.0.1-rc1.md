# Taskbar Monitor Enhanced 1.0.1 — laptop portability work

This document tracks the RC path that led to the accepted 1.0.1 release.

## Problems reproduced on the laptop

- the 1.0.0 installer could fail the whole setup when protected CPU-sensor activation failed or took too long
- CPU readiness was accidentally tied to the Intel-oriented sensor name `CPU Package`
- AMD-only / Intel-iGPU systems had no vendor-neutral GPU fallback
- a fixed wide overlay could extend underneath centered Windows 11 taskbar controls on smaller displays
- install-time helper/supervisor windows could become visible
- narrow safe-placement widths could make the metric text too crowded

## Resolved in the accepted 1.0.1 path

- bounded PawnIO installation
- non-fatal optional sensor activation
- restart-required handling
- vendor-neutral CPU readiness based on fresh elevated sensor data, not a specific sensor name
- AMD/Intel GPU fallback through LibreHardwareMonitor, while NVIDIA keeps `nvidia-smi`
- adaptive safe placement with zero Windows taskbar-control overlap
- compact metric rendering on narrow laptop layouts
- hidden elevated PowerShell helper
- windowless Sensor Supervisor release build

## Real laptop acceptance

Validated on AMD Ryzen 7 7730U + AMD Radeon (TM) Graphics:

- CPU sensor `Core (Tctl/Tdie)`: READY
- AMD GPU load/memory telemetry: PASS
- GPU temperature: N/A when not exposed by the hardware/backend
- taskbar-control overlap: 0
- Sensor Supervisor MainWindowHandle: 0
- compact layout active on the 1920×1080 laptop

## Final lifecycle acceptance

The exact final Setup passed upgrade, configuration preservation, uninstall, clean install, AMD CPU/GPU revalidation, zero-overlap placement, silent-supervisor validation, and a 120-second clean-install lifetime.

Accepted hashes:

- Setup SHA-256: `4fd7d1055917eebb6598ba78e68294845f51fb190c93889b78f313ec1f3aed54`
- Source ZIP SHA-256: `32b69949b1bb8067739c53737b805274b069c63d98b96d84e4855ae826b0cc35`

See `RELEASE_NOTES_v1.0.1.md` and `docs/FINAL_ACCEPTANCE_v1.0.1.md` for the public release record.
