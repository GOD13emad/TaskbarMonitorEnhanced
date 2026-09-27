# Taskbar Monitor Enhanced 1.0.1

Version 1.0.1 focuses on laptop portability and installer resilience while preserving the
taskbar-native architecture and the 14 visual themes from 1.0.0.

## Fixed and improved

- CPU sensor installation no longer blocks the whole application when optional hardware
  telemetry is unavailable or needs a reboot.
- PawnIO installation is bounded instead of waiting indefinitely.
- CPU sensor readiness is vendor-neutral: fresh elevated readings from AMD, Intel, or other
  supported CPU sensor names are accepted without hard-coding `CPU Package`.
- AMD and Intel integrated GPUs can use LibreHardwareMonitor as a fallback.
- NVIDIA systems continue to prefer `nvidia-smi`.
- Integrated-GPU memory is reported from exposed D3D/shared-memory telemetry when available.
- GPU temperature remains `N/A` when the hardware/backend does not expose a valid sensor;
  values are never fabricated.
- Safe Placement adapts automatically to smaller Windows 11 taskbars and avoids covering
  Start/Search/pinned/system-tray controls.
- Narrow layouts automatically use a more compact metric set and smaller typography.
- Elevated sensor helper execution is hidden.
- Sensor Supervisor is built as a windowless executable for release installation.

## Real laptop validation

Validated on:
- AMD Ryzen 7 7730U with Radeon Graphics
- AMD Radeon (TM) Graphics
- Windows 11 taskbar at 1920x1080

RC3R3 acceptance evidence:
- CPU sensor: Core (Tctl/Tdie) — READY
- CPU broker: elevated, x64, fresh
- AMD GPU telemetry: PASS
- taskbar control overlap: 0
- Sensor Supervisor MainWindowHandle: 0
- compact layout at ~510 px: CPU, RAM, GPU, NET

## Final lifecycle acceptance

The exact public 1.0.1 Setup binary passed:

- upgrade installation
- configuration preservation
- complete uninstall
- clean installation using the same Setup binary
- vendor-neutral AMD CPU sensor validation
- AMD iGPU telemetry validation
- zero taskbar-control overlap
- silent/windowless Sensor Supervisor validation
- 120-second clean-install lifetime validation with no broker or supervisor restart

Accepted public artifacts:

- `TaskbarMonitorEnhanced_Setup_1.0.1.exe`
  - SHA-256: `4fd7d1055917eebb6598ba78e68294845f51fb190c93889b78f313ec1f3aed54`
- `TaskbarMonitorEnhanced_1.0.1_SOURCE.zip`
  - SHA-256: `32b69949b1bb8067739c53737b805274b069c63d98b96d84e4855ae826b0cc35`

The installer is not Authenticode-signed, so Windows SmartScreen may display an Unknown Publisher warning.
