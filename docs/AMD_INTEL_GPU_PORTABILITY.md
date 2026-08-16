# AMD / Intel integrated GPU portability

Taskbar Monitor Enhanced 1.0.1 adds a vendor-neutral GPU fallback for systems without NVIDIA graphics.

## Runtime behavior

- NVIDIA systems continue to prefer `nvidia-smi`.
- AMD and Intel GPUs fall back to LibreHardwareMonitor when supported by the exposed hardware sensors.
- Integrated-GPU memory uses available D3D/shared-memory telemetry when dedicated VRAM is not present.
- GPU temperature is shown only when a valid temperature sensor is exposed.
- If no valid GPU temperature sensor is available, the UI shows `N/A`; no temperature value is fabricated.

## Real AMD laptop validation

Validated on:

- CPU: AMD Ryzen 7 7730U with Radeon Graphics
- GPU: AMD Radeon (TM) Graphics
- Windows 11, 1920×1080 taskbar

Accepted 1.0.1 evidence:

- GPU source: `LHM_GPU:GpuAmd:AMD Radeon (TM) Graphics`
- GPU load telemetry: PASS
- GPU memory telemetry: PASS
- GPU temperature: `N/A` because the tested hardware/backend did not expose a valid GPU temperature sensor
- CPU sensor: `Core (Tctl/Tdie)` — READY
- vendor-neutral CPU readiness: PASS
- adaptive taskbar placement: PASS
- Windows taskbar-control overlap: 0
- windowless Sensor Supervisor: PASS
- final 120-second clean-install lifetime: PASS

The exact accepted public artifacts are recorded in `docs/FINAL_ACCEPTANCE_v1.0.1.md`.
