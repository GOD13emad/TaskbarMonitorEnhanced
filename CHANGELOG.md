# Changelog

## 1.1.1 — Stable (R18)

- retain R15 removal of default NVIDIA-SMI realtime polling
- restore native taskbar-child visual behavior while reducing shell pressure
- watchdog 500 ms; host poll 1000 ms
- style and placement health 5000 ms
- Safe Placement UI Automation moved out of the continuous hot path
- Settings is single-instance and repeated clicks reuse the existing window
- R18 short acceptance: PASS; Explorer PID stable; Event 1000/1002 = 0
- released as Stable/Latest after accepted R18 validation
## 1.0.2

Release-hardening and AMD GPU-temperature release.

- AMD Radeon GPU temperature via AMD ADLX 1.1 fallback
- compact narrow Network card with vertical DL/UL stacking
- direct left/right mouse interaction without click-through
- no-activate taskbar interaction
- stable Start/Search/taskbar placement
- persistent shell-style definition with self-heal protection
- exact 19/19 installer resource closure
- full upgrade/config-preservation/uninstall/clean-install lifecycle acceptance
- 180-second final installed runtime campaign with 171 samples and zero geometry drift
- separate 600-second / 582-sample engineering long-run acceptance retained as authority

## 1.0.1

Laptop portability and installer resilience release.

- vendor-neutral CPU temperature readiness
- bounded/non-fatal protected sensor installation
- AMD/Intel integrated-GPU fallback through LibreHardwareMonitor
- NVIDIA `nvidia-smi` path retained
- adaptive safe placement for smaller Windows 11 taskbars
- compact narrow-layout rendering
- hidden elevated helper
- windowless Sensor Supervisor
- full upgrade/uninstall/clean-install lifecycle acceptance
- 120-second clean-install lifetime validation

## 1.0.0

First public release of Taskbar Monitor Enhanced.

Highlights include taskbar-native placement, 14 themes, CPU/RAM/disk/network/GPU/VRAM monitoring, CPU and GPU temperatures, live trends, right-click controls, Explorer recovery, protected sensor supervision, Windows startup support, and a tested installer/uninstaller path.
