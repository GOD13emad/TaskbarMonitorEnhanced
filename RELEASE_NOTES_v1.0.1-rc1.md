# Taskbar Monitor Enhanced 1.0.1 RC

This release candidate focuses on laptop portability.

## CPU sensor installer resilience
- protected CPU sensor activation is non-fatal
- PawnIO installation is bounded instead of waiting indefinitely
- reboot-required is handled as a recoverable state
- setup stays usable if CPU temperature cannot be activated
- sensor result/log files are persisted
- Start Menu sensor-repair action can retry the hardware sensor layer

## AMD / Intel integrated GPU portability
- 1.0.0 used `nvidia-smi` as its GPU telemetry path
- 1.0.1 adds a vendor-neutral LibreHardwareMonitor fallback for AMD and Intel integrated GPUs
- integrated graphics may report shared GPU memory rather than dedicated VRAM
- unavailable GPU temperature remains `N/A` rather than causing an error

The accepted 1.0.0 taskbar UI, themes, placement, Explorer recovery, and non-elevated main-app architecture remain unchanged.
