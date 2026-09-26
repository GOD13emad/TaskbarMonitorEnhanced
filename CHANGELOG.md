# Changelog

## 1.1.2 — R21 Production Hardening

- finalize the RC10-accepted 15-second truthful UI freshness / 60-second CPU hard-stall watchdog behavior
- retain process-isolated protected sensors, Medium-integrity Main, official Windows resume notification handling, WINDOWS_GUI sensor processes and Job containment
- complete controlled CPU soft/hard stall acceptance, corrected post-fault soak, real S3 acceptance and downstream taskbar/module/integrity/EventLog validation
- publish all 14 live-data theme proofs plus compact 592/500-pixel zero-overflow evidence
- derive final v1.1.2 from accepted RC10 with release-identity/documentation changes only and guard affected source against behavior drift

## 1.1.2-rc9 — R21 Resume-Notification Ordering Hardening (candidate; not Stable)

- register the official Windows suspend/resume callback and treat PBT_APMRESUMEAUTOMATIC as the primary early resume signal
- defer worker freshness checks across the suspend transition and consume resume before CPU/GPU/storage health evaluation
- recycle CPU/GPU/storage on resume before stale-output decisions; retain the existing >15-second loop-gap detector as a fallback
- expose power-notification registration/count in supervisor state and add a bounded registration probe
- RC8 real S3 evidence is retained as a failed gate: GPU stale output was reported one iteration before the old wall-clock long-gap detector fired
- protected Broker/Supervisor are versioned and hash-pinned as an exact RC9 pair; older RC7/RC8 protected pairs are not reused as compatible

## 1.1.2-rc8 — R21 Main Integrity Boundary Hardening (candidate; not Stable)

- preserve the exact accepted RC7 Broker/Supervisor binaries and windowless sensor behavior
- prevent whole-Setup elevation from auto-launching TaskbarMonitorEnhanced.exe with a High-integrity token
- normal non-elevated Setup still auto-launches Main; elevated Setup records SKIPPED_ELEVATED_SETUP instead
- reuse the exact RC7 protected sensor pair only after hash, fresh state, Job containment, transport and data-health gates pass
- record MainLaunchMode in install_state.json so the least-privilege launch decision is auditable

## 1.1.2-rc7 — R21 Supervisor Observation-Gap Hardening (candidate; not Stable)

- prevent a single transient output-file observation gap from killing an otherwise healthy CPU/GPU sensor worker
- retain the existing 15-second freshness budget: persistent missing/unreadable output beyond the last-known-good window still forces bounded restart
- preserve startup failure detection when a new worker never produces its first output
- older RC4/RC5/RC6 protected sensor pairs are not eligible for compatible reuse because RC7 changes Supervisor failure semantics; upgrading to RC7 requires the protected Supervisor update
- regression evidence requires baseline reproduction of the short-gap false positive plus RC7 proof that a 3-second gap is tolerated while a >15-second gap still restarts
- build Broker and Supervisor as Windows GUI-subsystem executables so Task Scheduler/direct launches stay windowless while sensor/watchdog behavior and exit codes remain unchanged; Build-R21 now enforces PE subsystem=2

## 1.1.2-rc6 — R21 Component-Aware Least-Privilege Finalization (candidate; not Stable)

- add hash-pinned compatible protected-layer reuse for app-only updates
- reuse is allowed only for an exact known Broker/Supervisor SHA-256 pair with a matching BrokerVersion, <15s supervisor state, Job Object containment and healthy CPU/GPU/storage transport+data lanes
- current embedded RC6 protected payload is also recognized by exact embedded-resource hashes
- known-compatible RC4/RC5 protected pairs are explicitly allowlisted because their protected-source diff is version identity only
- unknown, modified, stale or unhealthy protected layers continue through the existing elevated transactional install/rollback path
- explicit Repair Hardware Sensors continues to force the elevated current protected payload
- install_state now records SensorLayerVersion and SensorLayerMode for transparent component provenance
- objective: remove unnecessary UAC from safe app-only upgrades without weakening the protected Program Files boundary
- release gates: deterministic RC6 build, live RC4->RC6 compatible-reuse install, self-heal/log-pressure regression, taskbar/module/EventLog checks, GitHub attestation run and real suspend/resume soak

## 1.1.2-rc5 — R21 Final Log-Pressure Hardening (candidate; not Stable)

- retain RC4 automatic Sensor Supervisor self-heal and signed provenance/SBOM CI
- fix GPU stale-state log amplification during a protected-sensor outage by normalizing dynamic age states
- throttle repeated GPU stale-state logs to at most one every 30 seconds while preserving immediate state-transition logging
- RC4 live fault injection proved Main-driven task recovery, one Supervisor, correct broker parenting and healthprobe PASS
- release gates: deterministic RC5 build, installed RC5 canary, repeat self-heal fault injection with bounded stale logging, then real suspend/resume soak before Stable/Latest

## 1.1.2-rc4 — R21 Self-Heal + Supply-Chain Finalization (candidate; not Stable)

- add conservative non-elevated automatic recovery when a READY Sensor Supervisor state is missing/stale for more than 90 seconds
- use the existing pre-authorized Scheduled Task only; no ACL, task-definition or protected-binary mutation is performed by Main
- enforce a 90-second startup grace and 180-second retry cooldown to prevent restart loops
- add self-heal policy coverage to the built-in self-test and Diagnostics report
- generate an SPDX 2.3 SBOM from the pinned dependency lock and deterministic build manifest
- add GitHub/Sigstore build-provenance and Setup SBOM attestations for non-PR CI builds
- pin checkout/setup-dotnet/attest/upload-artifact Actions to exact commit SHAs
- inherit the RC3 OS-level Job Object kill-on-close containment and full installed healthy baseline
- release gates: deterministic RC4 clean-clone build, RC4 installed canary including forced Supervisor-stop auto-recovery, then extended real suspend/resume soak before Stable/Latest

## 1.1.2-rc3 — R21 Production Hardening (candidate; not Stable)

- isolate LibreHardwareMonitor CPU, GPU and storage access into independent worker processes
- stagger sensor-worker startup and apply bounded exponential backoff / termination-pending protection
- place all sensor workers in a Windows kill-on-close Job Object so abrupt supervisor termination cannot orphan CPU/GPU/storage workers
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
