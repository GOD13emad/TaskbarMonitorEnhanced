# AMD / Intel integrated GPU portability

Taskbar Monitor Enhanced 1.0.0 used `nvidia-smi` as its GPU telemetry path. That works well on NVIDIA systems, but it leaves AMD- or Intel-only laptops without GPU telemetry even though the rest of the application can run normally.

For 1.0.1 the GPU path is vendor-neutral:

- NVIDIA continues to prefer `nvidia-smi` when available.
- AMD and Intel GPUs can fall back to LibreHardwareMonitor.
- Integrated graphics can use D3D/shared-memory metrics where exposed by Windows/the hardware.
- GPU temperature is shown only when a real temperature sensor is available. The application does not fabricate a value.

## Laptop validation

Validated on an AMD-only laptop:

- CPU: AMD Ryzen 7 7730U with Radeon Graphics
- GPU: AMD Radeon (TM) Graphics
- GPU source: `LHM_GPU:GpuAmd:AMD Radeon (TM) Graphics`
- GPU load observed: 2%
- GPU memory observed: 0.78 GB used / 2.00 GB total
- GPU temperature: unavailable on this hardware/backend path, therefore correctly shown as `N/A`
- CPU sensor: `Core (Tctl/Tdie)`
- CPU temperature broker: elevated, x64, fresh and healthy

The same laptop also validated adaptive taskbar placement with zero overlap against Windows 11 taskbar controls.

## CPU sensor readiness portability

A separate installer bug was found during the same validation cycle: the sensor acceptance gate required the exact sensor name `CPU Package`, which is common on Intel systems but not on this AMD laptop. AMD reported `Core (Tctl/Tdie)`, so Setup incorrectly warned that the CPU sensor was unavailable even though fresh elevated temperature data existed.

The 1.0.1 fix is vendor-neutral. Setup now accepts a CPU sensor when the broker reports:

- `Available = true`
- x64 process
- elevated process
- non-empty sensor name
- plausible temperature (>0 °C and <130 °C)
- fresh timestamp (<15 seconds)

This removes the Intel-specific name dependency while preserving strict freshness and privilege checks.
