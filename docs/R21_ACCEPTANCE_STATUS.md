# R21 Acceptance Status — Taskbar Monitor Enhanced 1.1.2-rc2

Status: RELEASE CANDIDATE / NOT STABLE

Authority baseline: Git commit 539c8f7 (R20 process-isolation baseline).
Development branch: audit/r21-production-hardening.

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
- --healthprobe correctly identifies the current older installation as DEGRADED / ArchitectureR21=false rather than falsely passing it.
- Current GitHub public release v1.1.1 has SHA-256 asset metadata but is mutable; R21 automatic-install policy correctly blocks mutable releases.
- Reproducible clean-clone build: PASS from commit 9ea1886 using freshly downloaded official dependencies.
- Binary determinism: PASS; main app, broker, supervisor and setup are byte-for-byte identical between the primary workspace and a separate clean clone.
- Short same-machine A/B UI benchmark: R21 process CPU time decreased by about 47.4% and median working set by about 23.9% versus the installed v1.1.1 across a 15-second post-warm-up window. This is a local directional benchmark, not a universal performance claim.

## Environment/test limitation

The Remote Commander execution token is non-elevated. The R21 split CPU/GPU/storage Supervisor therefore cannot be installed or tested under a fresh highest-privilege token without interactive UAC approval. This is the principal remaining acceptance gate; it is not substituted by non-elevated tests.

## Remaining release gates

1. Install TaskbarMonitorEnhanced_Setup_1.1.2-rc2.exe with UAC approval.
2. Confirm sensor_supervisor_state.json is fresh and BrokerVersion=1.1.2-rc2+r21.
3. Confirm CpuTransportHealthy, GpuTransportHealthy and StorageTransportHealthy are true.
4. Confirm GPU split JSON exposes the RTX 3080 temperature and storage split JSON exposes supported disk temperatures.
5. Run TaskbarMonitorEnhanced.exe --healthprobe <path> and require PASS.
6. Run installed UI/Start/Search/Explorer-recovery checks.
7. Run installed long-duration soak with no restart storm, geometry drift, UI exception or Explorer crash.
8. Only after those gates may R21 be considered for Stable/Latest publication.

## Dependency decision

LibreHardwareMonitor 0.9.6 remains pinned for this candidate. A master/nightly build pinned to commit dc51e75bd97b15ce17ded0885e67bad47be0765b was built and tested separately; it did not improve the CPU worker startup/hang behavior and was not promoted into the production dependency set.
