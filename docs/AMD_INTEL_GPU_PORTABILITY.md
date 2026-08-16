# AMD / Intel integrated GPU portability

The 1.0.0 runtime uses `nvidia-smi` for GPU utilization, VRAM and temperature telemetry. On laptops with only AMD or Intel integrated graphics, that path is unavailable even though the application itself can run normally.

For 1.0.1 the GPU telemetry layer is being generalized to use LibreHardwareMonitor as a vendor-neutral fallback. LibreHardwareMonitor supports NVIDIA, AMD and Intel GPUs, including D3D load and shared-memory sensors where the hardware exposes them.

Planned behavior:

- NVIDIA: keep `nvidia-smi` as the first choice when available.
- AMD / Intel: use LibreHardwareMonitor GPU sensors.
- Integrated graphics: use D3D shared-memory telemetry when dedicated VRAM is not present.
- Missing temperature sensor: show `TEMP N/A` without affecting installation or other metrics.
- Missing dedicated VRAM: do not invent a value; use available GPU/shared-memory sensors only.

This is separate from the protected CPU-temperature sensor installer issue. A machine can have an AMD iGPU and still require the CPU-sensor fallback/repair path independently.

Current laptop observation: the application installs successfully with the resilient installer, but the protected CPU sensor remains unavailable. The laptop also has AMD integrated graphics without a discrete NVIDIA GPU, so GPU telemetry portability is now part of the same 1.0.1 laptop-validation cycle.
