# Changelog

## 1.1.2-rc3 — R21 Production Hardening (candidate; not Stable)

- isolate LibreHardwareMonitor CPU, GPU and storage access into independent worker processes
- stagger sensor-worker startup and apply bounded exponential backoff / termination-pending protection
- distinguish worker transport health from hardware data availability
- recycle native sensor workers across long suspend/resume gaps
- replace hot-loop Processor PerformanceCounter CPU usage with Windows GetSystemTimes
- cache static CPU topology for five minutes and active network topology for 30 seconds
- cache disk topology for five minutes and RAM-module topology for ten minutes, with explicit resume invalidation
- use isolated GPU telemetry first; run WDDM fallback only when needed
- invalidate stale CPU temperature and throttle expensive WMI/ACPI temperature fallback
- read CPU broker JSON with shared-read/retry semantics to avoid transient file-lock gaps during atomic broker output replacement
- add Diagnostics UI, support-report export, repair action and --healthprobe
- require immutable GitHub Releases in addition to asset SHA-256 metadata for automatic installation
- harden Scheduled Task restart policy to RestartCount=3 and MultipleInstances=IgnoreNew
- bound the UAC/ShellExecute launch phase and record degraded sensor-layer status instead of allowing an unanswered elevation prompt to leave Setup indefinitely half-complete
- transactionally snapshot and restore the previous protected sensor binaries and Scheduled Task when R21 sensor setup or transport-health validation fails
- keep LibreHardwareMonitor 0.9.6 pinned after a current upstream nightly failed to improve the CPU-worker behavior in validation
- atomic config write + backup recovery prevents interrupted saves from silently reverting to defaults
- rotate sensor logs at 4 MiB with bounded backups; retain main daily logs for 30 days
- require the exact versioned setup asset and a strict 64-hex GitHub SHA-256 digest before automatic installation
- expose supervisor uptime, worker age, last failure/recovery timestamps and resilience state in machine-readable health output
- add optional isolated CPU package-power and GPU power/fan telemetry without loading LibreHardwareMonitor into the UI process
- engineering gates: zero-warning primary build PASS, self-test PASS, real RTX 3080 power/fan probe PASS, steady/stale/long-gap/log-rotation/recovery-observability supervisor tests PASS
- remaining RC3 gates: clean-clone determinism after commit, transactional installed canary, then extended soak with a real suspend/resume before Stable/Latest

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
