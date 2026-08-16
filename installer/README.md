# Installer source

This folder contains the custom Windows installer source used by Taskbar Monitor Enhanced.

For 1.0.2 the installer was validated through the full release lifecycle on the real AMD laptop:

- upgrade installation
- existing configuration preservation
- complete uninstall
- clean installation using the exact same Setup binary
- target Setup embedded resources: 19/19 PASS
- rollback Setup embedded resources: 19/19 PASS
- vendor-neutral CPU temperature readiness
- AMD Radeon GPU temperature via AMD ADLX 1.1
- compact and wide 14-theme regression proofs
- narrow Network DL/UL stacking
- final 180-second installed runtime campaign with 171 samples and zero geometry drift
- separate 600-second / 582-sample engineering long-run acceptance

The exact accepted public hashes and lifecycle evidence are recorded in `../docs/FINAL_ACCEPTANCE_v1.0.2.md`.

The main application remains non-elevated. Administrator approval is used only for the protected hardware-sensor layer. PawnIO is intentionally retained on uninstall because another hardware-monitoring application may depend on it.
