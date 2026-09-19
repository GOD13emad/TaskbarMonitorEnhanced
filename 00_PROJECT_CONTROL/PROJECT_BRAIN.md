# PROJECT BRAIN — Taskbar Monitor Enhanced

## Authority

- Public stable release remains v1.1.1.
- R20 rollback authority: local commit 539c8f7 — process-isolated sensor-access baseline.
- Active candidate: v1.1.2-rc5 / R21 Final Log-Pressure Hardening on audit/r21-final-hardening-rc5.
- Do not claim public FINAL/STABLE until the extended installed soak including suspend/resume passes.

## R21 objective

Increase long-run stability and observability without regressing the accepted taskbar behavior. The main mutation objective is native-sensor failure containment plus telemetry hot-path reduction; Diagnostics/update-security improvements are downstream extensions of that architecture.

## Implemented

- Independent CPU/GPU/storage LHM worker processes.
- RC3 OS-level kill-on-close Job Object containment prevents orphan sensor workers after abrupt Supervisor termination.
- RC4 Main self-heal restarts only the existing pre-authorized Sensor Supervisor task after conservative stale-state thresholds.
- RC5 normalizes dynamic GPU stale-age state keys and throttles repeated stale logs to 30 seconds.
- RC4 CI produces SPDX 2.3 SBOM plus GitHub/Sigstore build provenance/SBOM attestations with Actions pinned by commit SHA.
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

RC5 source/build/self-test/SBOM/clean-clone determinism are PASS. RC5 Main is installed with exact hash and passes taskbar/module/EventLog canaries. The protected Broker/Supervisor remain the healthy RC4 layer because the bounded RC5 UAC attempts were not approved, so install_state correctly remains DEGRADED. GitHub-side attestation execution and a real suspend/resume soak also remain external gates.

## Next authoritative actions

- Complete RC5 deterministic build and install exact RC5 artifacts.
- Repeat forced Supervisor-stop auto-recovery and require bounded GPU stale logs plus healthprobe PASS.
- Re-run taskbar geometry, module isolation and Event Log checks.
- Push/run the updated GitHub Actions workflow and require provenance/SBOM attestation success.
- Complete one real suspend/resume soak when operationally safe.
- Keep public Stable/Latest at v1.1.1 until the remaining external/real-power gates pass.
