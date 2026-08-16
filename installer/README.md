# Installer source

This folder contains the custom Windows installer source used by Taskbar Monitor Enhanced.

For 1.0.1 the installer was validated through the full release lifecycle on the real AMD laptop:

- upgrade install
- configuration preservation
- complete uninstall
- clean install using the exact same Setup binary
- vendor-neutral CPU temperature readiness
- AMD iGPU telemetry validation
- zero Windows taskbar-control overlap
- hidden elevated helper
- windowless Sensor Supervisor
- 120-second clean-install lifetime

The exact accepted public hashes are recorded in `../docs/FINAL_ACCEPTANCE_v1.0.1.md`.

The main application remains non-elevated. Administrator approval is used only for the protected hardware-sensor layer. PawnIO is intentionally retained on uninstall because another hardware-monitoring application may depend on it.
