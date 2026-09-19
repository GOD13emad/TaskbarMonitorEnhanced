# PROJECT BRAIN — Taskbar Monitor Enhanced

## Authority

- Public stable release remains v1.1.1.
- R20 rollback authority: local commit 539c8f7 — process-isolated sensor-access baseline.
- Active candidate: v1.1.2-rc3 / R21 Production Hardening on audit/r21-final-hardening-rc3.
- Do not claim public FINAL/STABLE until the extended installed soak including suspend/resume passes.

## R21 objective

Increase long-run stability and observability without regressing the accepted taskbar behavior. The main mutation objective is native-sensor failure containment plus telemetry hot-path reduction; Diagnostics/update-security improvements are downstream extensions of that architecture.

## Implemented

- Independent CPU/GPU/storage LHM worker processes.
- RC3 OS-level kill-on-close Job Object containment prevents orphan sensor workers after abrupt Supervisor termination.
- Staggered worker startup and bounded retry/backoff.
- Fresh transport health separated from data availability.
- Power-aware telemetry pause/reset/recycle.
- Native GetSystemTimes CPU usage.
- Cached CPU/network topology.
- GPU WDDM fallback on demand.
- CPU fallback throttling and stale-data invalidation.
- Diagnostics tab, saved reports, repair action, CLI health probe.
- Immutable-release + SHA-256 automatic-update trust gate.
- Installer task restart/multiple-instance hardening.
- Installer multi-lane R21 supervisor health gate.
- Dependency lock is authoritative for LHM/PawnIO versions, URLs and SHA-256; CI rechecks deterministic output hashes in a clean clone.
- Bounded UAC launch; unanswered/noninteractive consent returns DEGRADED instead of leaving Setup half-installed.
- Elevated sensor mutation has an internal rollback transaction: previous Program Files payload + Scheduled Task XML are captured before mutation and restored on R21 setup/health failure.
- install_state SensorLayerStatus prevents a mixed old-sensor/new-UI installation from masquerading as healthy R21.
- Pinned LHM 0.9.6 production dependency; newer nightly tested but not promoted.
- RC3 atomic config replacement + backup recovery, bounded log retention/rotation, exact-version updater asset matching and strict 64-hex SHA-256 parsing.
- RC3 health state records supervisor/worker age plus last failure/recovery timestamps and resilience state.
- RC3 optional CPU package-power and GPU power/fan telemetry stays inside the isolated broker boundary; RTX 3080 live probe PASS.

## Evidence summary

- Installed elevated R21 split supervisor is live and healthprobe PASS with CPU/GPU/storage transport and data availability healthy.
- Installed Main/Broker/Supervisor hashes match the deterministic candidate outputs.
- Explorer shell recovery PASS: same R21 UI PID reattached to the new taskbar within 2 seconds; 18/18 post-recovery soak samples remained healthy and geometrically stable.
- Current Main module audit finds no LibreHardwareMonitor in the UI process; current post-shared-read log window has no CPU broker read/stale/unavailable events.
- Windows Event Log has no TBME/LHM or Explorer crash/hang/.NET error in the observed post-install R21 window.
- Synthetic power-path coverage PASS: main WM suspend/resume handler resets telemetry/topology and recovers placement; test-only supervisor detects an 18.5-second long gap and performs bounded staggered worker recycle.
- Clean-clone reproducible build PASS; all four release binaries are byte-for-byte deterministic across independent workspace paths.
- Same-machine short A/B indicates approximately 47.4% lower R21 UI process CPU time and 23.9% lower median working set than installed v1.1.1 in the sampled window.
See docs/R21_ACCEPTANCE_STATUS.md and local r21_evidence/. Core builds and deterministic/visual/canary gates pass. Existing elevated hardware evidence confirms CPU and three storage temperatures; candidate user-context GPU worker confirms RTX 3080 temperature and detailed telemetry.

## Open blocker

RC3 source/build hardening and clean-clone determinism are complete. The RC3 main UI is installed and accepted locally (exact hash, taskbar geometry, module isolation, recent Event Log), while the protected Broker/Supervisor remain the healthy RC2 layer because the noninteractive UAC request timed out. The immediate gate is one explicit admin/UAC completion of the protected RC3 layer; public Stable/Latest additionally requires an extended fully-installed soak with one real suspend/resume cycle.

## Next authoritative actions

- Run COMPLETE_RC3_ADMIN.ps1 with administrator/UAC approval and require exact protected-binary hashes plus ProcessContainment=true/healthprobe PASS.
- Re-run installed hashes/health/module/taskbar/EventLog gates after protected-layer completion.
- Keep the installed RC3 candidate running for a longer soak.
- Exercise one real suspend/resume cycle when operationally safe, then re-run healthprobe/module/taskbar/EventLog gates.
- Keep public Stable/Latest at v1.1.1 until those gates pass.
- For the eventual public R21 release, enable GitHub immutable releases and publish finalized assets through the immutable-release workflow.
