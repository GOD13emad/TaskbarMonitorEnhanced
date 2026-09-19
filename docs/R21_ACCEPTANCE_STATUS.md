# R21 Acceptance Status — Taskbar Monitor Enhanced 1.1.2-rc2

Status: RELEASE CANDIDATE / NOT STABLE

Authority baseline: Git commit 539c8f7 (R20 process-isolation baseline).
Development branch: audit/r21-production-hardening.
R21 release-source authority: 9211aa5.
R21 runtime-code authority: 7a89368.
R21 transactional-installer authority: d9953d5.
R21 build-pipeline authority: bdcd2b4.

## Evidence-backed PASS gates

- Main application build: 0 warnings / 0 errors.
- Sensor broker build: 0 warnings / 0 errors.
- Sensor supervisor build: 0 warnings / 0 errors.
- Setup build: 0 warnings / 0 errors.
- Setup embedded-resource verification: PASS, 19 resources.
- Main self-test: PASS.
- Git whitespace/error check: PASS.
- Legacy R20/rc1/250ms/RestartCount=99 scan in R21 source/installer: no matches.
- PowerShell elevated-helper parser: 0 syntax errors.
- Deterministic supervisor steady-state test: CPU HEALTHY_NO_DATA, GPU HEALTHY_DATA, storage HEALTHY_NO_DATA; no unnecessary restarts.
- Deterministic stale CPU worker test: stale detected at about 15.1 s, 5 s backoff, one controlled restart; GPU/storage stayed independent.
- Full-width theme proof: 14/14 themes, no synthetic metric data.
- Compact proof: 14 themes at 592 px and 500 px, zero layout overflows.
- Runtime no-screen canary: direct taskbar child, visible, 1100x48, 24/24 stable geometry/parent samples while Start was stimulated; candidate stayed alive and prior installed UI was restored.
- Live hardware probe: CPU=1, GPU=1, physical disks=4, network adapters=1.
- Live CPU temperature: elevated broker available.
- Candidate isolated GPU broker: RTX 3080 load/temperature/VRAM/clocks available in non-elevated test.
- Existing elevated monolithic broker evidence: three storage temperature records available (Crucial BX500, Samsung 980 PRO, Samsung 990 PRO).
- Historical downgrade/regression gate: --healthprobe correctly identified the pre-R21 installation as DEGRADED / ArchitectureR21=false rather than falsely passing it.
- Current GitHub public release v1.1.1 has SHA-256 asset metadata but is mutable; R21 automatic-install policy correctly blocks mutable releases.
- Reproducible clean-clone build: PASS from release-source commit 9211aa5 using the pinned dependency lock; an earlier clean clone also re-downloaded and verified the official dependencies.
- Binary determinism: PASS; main app, broker, supervisor and setup are byte-for-byte identical between the primary workspace and a separate clean clone.
- Automated determinism verifier: PASS from committed HEAD using build/Verify-Determinism.ps1 and build/dependencies.lock.json.
- Setup assembly identity: PASS; app, broker, supervisor and setup all expose ProductVersion 1.1.2-rc2+r21.
- Bounded-UAC regression: PASS; the noninteractive install path that previously stalled returned in 31.31 seconds, wrote SensorLayerStatus=DEGRADED, left no Setup orphan, and healthprobe correctly remained DEGRADED.
- Transactional sensor rollback fault-injection: PASS; after forced failure following candidate file replacement, the previous sensor sentinel was restored exactly, no candidate files remained, stale CPU/GPU/storage/supervisor test telemetry was removed, and the helper emitted DEGRADED_ROLLED_BACK with RollbackSucceeded=true.
- Stable rollback after the bounded-UAC test: PASS; installed v1.1.1 app SHA-256 restored exactly to 408D5DFA73871579A3FF46F9D681BE78B9AF882CFE569D0750260ACA5694D139 and resumed as a visible direct taskbar child with fresh elevated CPU telemetry.
- Short same-machine A/B UI benchmark: R21 process CPU time decreased by about 47.4% and median working set by about 23.9% versus the installed v1.1.1 across a 15-second post-warm-up window. This is a local directional benchmark, not a universal performance claim.
- Windows Event Log post-install check: PASS; no TBME/LHM or Explorer Application Error/.NET Runtime/Application Hang/WER events were found in the observed R21 install window.
- Post-Explorer soak: PASS; 18/18 five-second samples kept CPU/GPU restart counts fixed, failure counts at zero, healthy reasons, visibility and taskbar geometry.
- Explorer recovery: PASS; the taskbar shell process was deliberately restarted, the R21 UI process PID stayed unchanged, and it reattached to the new taskbar within 2 seconds at 1100x48.
- CPU worker containment: PASS; one NO_CURRENT_OUTPUT_AFTER_GRACE event produced one bounded restart with 5-second backoff, then WORKER_RECOVERY_STABLE; no further worker failures were recorded in the observed window.
- Shared-read CPU broker fix: PASS; after deployment, new main-log lines contain no CPU_TEMP_BROKER_READ, broker-stale or CPU-temperature-unavailable events in the observed window.
- Installed main-process isolation: PASS; current 100-sample module audit found no LibreHardwareMonitor module in the UI process.
- Installed live CPU/GPU/storage telemetry: PASS; CPU, RTX 3080 and three storage records are fresh and data-available.
- Installed Scheduled Task policy: PASS; RestartCount=3 and MultipleInstances=IgnoreNew.
- Installed file identity: PASS; Main/Broker/Supervisor SHA-256 values match the current deterministic candidate outputs.
- Installed elevated R21 split supervisor: PASS; install_state SensorLayerStatus=READY and healthprobe reports PASS.

## Environment/test limitation

The elevated installation gate is now closed on the validation machine. The remaining limitation is duration/power-transition coverage: the observed installed run is healthy, but a longer soak that includes an actual suspend/resume cycle has not yet been completed in this acceptance record. This is intentionally not substituted with a synthetic claim.

## Remaining release gates

1. Continue the installed R21 soak for a substantially longer window.
2. Include at least one real suspend/resume cycle and require automatic native-worker recycle/recovery without restart storm or stale UI data.
3. Re-run healthprobe, taskbar geometry, module isolation and Event Log checks after resume.
4. Before public Stable/Latest publication, enable GitHub immutable releases for the repository and publish the finalized assets through the immutable-release workflow.
5. Only after those gates may R21 be promoted from release candidate to Stable/Latest.

## Dependency decision

LibreHardwareMonitor 0.9.6 remains pinned for this candidate. A master/nightly build pinned to commit dc51e75bd97b15ce17ded0885e67bad47be0765b was built and tested separately; it did not improve the CPU worker startup/hang behavior and was not promoted into the production dependency set.
