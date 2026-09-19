# PROJECT BRAIN — Taskbar Monitor Enhanced

Brain Version: PB-2026-09-19-R21-RC10-PENDING-INSTALL1
Status: CURRENT
Updated: 2026-09-19T21:44:26+03:30

## Project definition

Taskbar Monitor Enhanced is a Windows taskbar-integrated hardware/system monitor. R21 hardens the product for long-run daily use: isolated native hardware-sensor access, bounded self-healing, windowless protected sensor workers, least-privilege Main UI, deterministic builds, auditable supply-chain provenance and safe installation/update behavior.

## Final Objective / DoD

Release immutable public v1.1.2 only when the exact final source/build/install identity has:
- zero-warning/zero-error reproducible build and clean-clone byte determinism;
- pinned LibreHardwareMonitor/PawnIO dependency hashes and SPDX SBOM;
- Main at Medium integrity with no LibreHardwareMonitor loaded in Main;
- protected Broker/Supervisor in Program Files, windowless PE GUI subsystem, correct Job containment and scheduled-task policy;
- truthful CPU/GPU/storage telemetry with 15-second UI freshness;
- bounded recovery from transient sensor stalls without restart storms and a hard watchdog for true stalls;
- real S3 suspend/resume acceptance with no false freshness failure;
- taskbar geometry/module/EventLog/runtime soak acceptance;
- exact GitHub provenance/SBOM attestations and immutable release assets;
- clean Start Menu/startup/uninstall surface;
- current cumulative Brain and acceptance evidence sufficient for account transfer.

## Current authority

- Public Stable/Latest: **v1.1.1**. Do not supersede until final v1.1.2 gates close.
- Current engineering candidate: **v1.1.2-rc10 / R21 CPU slow-read hardening**.
- Current branch: `audit/r21-final-hardening-rc10`.
- Source authority: `e89aebd9012f95d050771283562069f9cb5f5515`.
- Parent accepted source before RC10 mutation: RC9 `220e49824a8ccb89192e0ab173860e016c2ca7d9`.
- RC10 self-hosted GitHub run: `35460297804` = SUCCESS.
- RC10 draft prerelease target: `e89aebd9012f95d050771283562069f9cb5f5515`, draft/prerelease only.
- Repository immutable releases policy is enabled.
- Local project root: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced_R20`.
- Protected sensor root: `C:\Program Files\TaskbarMonitorEnhanced\SensorBroker`.
- User runtime root: `C:\Users\Aa.Emad\AppData\Local\TaskbarMonitorEnhanced`.

## Current RC10 deterministic outputs

- Main: `6BBD6BF7A559DE4C2C59FE4027FA2BA30EC82765B3C6F4000FF34375C72B2550`
- Broker: `7BA4E75514D69EC20D7FD478C3F8769A2D22BB48AC1B19900D946DF4FB64D907`
- Supervisor: `FE5EB08FC2ED2D2C7CAA70F7EA48965C409E2093E3BB054CE8AE60003D85D97D`
- Setup: `488FAC9FE5C98943F8A90DE58EBF70B999EE0C4AD4E01933B0090FDEA73BC400`
- SPDX SBOM: `E3659486DA78AE92E9F079EE76E10DF65518A3A5C25E00811A1B78C1958D894B`
- Manifest: `RC_MANIFEST_v1.1.2-rc10.json`
- Hash list: `SHA256SUMS_v1.1.2-rc10.txt`

## Roadmap and current position

Lifecycle:
DISCOVERY → DEFINITION → BASELINE → DEVELOPMENT → VERIFICATION → **VALIDATION/ACCEPTANCE (CURRENT)** → DELIVERY/RELEASE → CLOSURE → FINAL

Evidence-backed completed:
1. R21 architecture/process isolation and protected sensor boundary.
2. Deterministic build pipeline, dependency lock, SBOM generator, self-hosted attestations.
3. Main taskbar/UI feature baseline and module isolation.
4. RC7 transient output-observation-gap fix and windowless Broker/Supervisor.
5. RC8 least-privilege Main launch boundary.
6. RC9 official Windows suspend/resume notification integration.
7. RC9 deterministic Setup canonical text staging.
8. RC9 installer single-instance/state-integrity hardening.
9. RC9 real S3 test: physical suspend/wake occurred; resume notification observed; no worker failure during resume; post-health PASS.
10. RC10 source/build/determinism/SBOM/self-hosted GitHub supply-chain gates.

Current critical gate:
**Install exact protected RC10 pair and execute fault-injection/runtime acceptance.**

Remaining after RC10 protected install:
- 25-second soft-stall fault injection: no CPU restart; UI freshness remains truthful; same worker recovers.
- >60-second hard-stall fault injection: hard watchdog must restart stuck CPU worker and recover.
- post-fault runtime soak with stable restart counters and zero new failures.
- real S3 regression on installed RC10.
- taskbar/module/EventLog/windowless/integrity regressions on installed RC10.
- update acceptance/Brain to RC10 accepted state.
- derive exact final v1.1.2 identity from accepted RC10, rebuild/determinism/install/attest/revalidate and only then publish immutable Stable/Latest.

## Current installed state — IMPORTANT

The machine is temporarily in a **mixed RC10/RC9 state**, intentionally marked non-accepted:
- Main is RC10 hash `6BBD6BF7...`.
- protected Broker is still RC9 hash `5D482440...`.
- protected Supervisor is still RC9 hash `A0A7C711...`.
- `install_state.json`: PublicVersion RC10 but `SensorLayerStatus=DEGRADED`; protected RC10 install is pending Windows Secure Desktop administrator consent.
- Do not run RC10 fault-injection or claim installed RC10 acceptance until protected hashes equal the RC10 manifest.

## Why RC10 exists

After RC9's real-S3 resume race was fixed, a post-S3 90-second soak found a separate recurring CPU sensor stall:
- `17:55:35Z WORKER_FAILURE CPU STALE_OUTPUT_16.0S`
- `17:56:12Z WORKER_FAILURE CPU NO_CURRENT_OUTPUT_AFTER_GRACE`
- recovery at `17:57:41Z`.

Broker log showed no `BROKER_FATAL`; the worker stayed alive and was likely blocked in LibreHardwareMonitor/PawnIO hardware access. An isolated 8-case CPU/storage contention probe did not reproduce a timeout, so simple storage concurrency is UNPROVEN. Active MSI Center/Mystic Light services are a possible external contention source but are not proven root cause and must not be disabled automatically.

Windows ACPI thermal-zone fallback was rejected: available ACPI temperature was not representative of CPU Package temperature.

RC10 therefore separates data freshness from process-watchdog policy:
- UI/Main CPU temperature freshness remains **15 seconds**; stale data becomes unavailable/N/A.
- CPU Supervisor hard-stall budget is **60 seconds**.
- CPU startup grace is **60 seconds**.
- GPU keeps the established 15-second hard behavior.
- soft CPU stalls are observable via `CpuSlowOutputActive` / `WORKER_SLOW_OUTPUT`;
- recovery logs `WORKER_SLOW_OUTPUT_RECOVERED`;
- true >60s stalls still cause bounded restart.

This avoids hiding stale telemetry while reducing restart storms caused by transient low-level sensor delays.

## Verification state

RC10 PASS:
- App/Broker/Supervisor/Setup: 0 warnings / 0 errors.
- Main self-test: PASS, includes `CPU_HARD_STALL_WATCHDOG_SEC=60`.
- Setup resource/policy verify: PASS.
- Sensor PE windowless guard: PASS.
- Canonical text payload gate: PASS.
- Clean-clone byte determinism: PASS.
- SPDX 2.3 SBOM generation: PASS.
- GitHub self-hosted run `35460297804`: SUCCESS.
- GitHub steps build/determinism/SBOM/provenance/Setup-SBOM/evidence-upload: SUCCESS.
- RC10 draft evidence assets uploaded; public release not promoted.

RC10 UNPROVEN/PENDING:
- exact protected RC10 install;
- soft/hard watchdog fault injection;
- post-fault soak;
- real S3 on installed RC10;
- final installed RC10 taskbar/module/EventLog regression;
- final public v1.1.2 identity/release.

## Historical failure / prevention record

- RC6 false `NO_CURRENT_OUTPUT_AFTER_GRACE`: single transient missing file observation triggered restart. Prevention: last-known-good freshness handling; regression protects short gaps.
- RC7 CUI console window: Scheduled Task launched console-subsystem Supervisor. Prevention: Broker/Supervisor WinExe + PE subsystem build guard.
- RC8 elevation inheritance: whole elevated Setup could auto-launch high-integrity Main. Prevention: elevated Setup never auto-launches Main; normal Setup keeps Main Medium integrity.
- RC8 real-S3 race: stale GPU evaluation occurred before long-gap detection. Prevention: Windows suspend/resume callback plus transition deferral; RC9 physical S3 passed.
- RC9 Setup determinism: raw CRLF/LF text resources changed Setup bytes across checkout policies. Prevention: canonical UTF-8/LF embedded-text staging.
- RC9 installer state race: parallel Setup invocations could delete shared sensor result and write DEGRADED after successful helper. Prevention: single-instance Setup mutex + unified sensor version constant.
- RC9 post-S3 CPU stalls: recurring ~15s LHM/PawnIO CPU read stalls caused restarts. RC10 prevention under validation: 15s data freshness, 60s CPU hard watchdog.
- Do not disable MSI Center/Mystic Light or other unrelated user services without separate evidence/approval.

## Authoritative vs superseded

Authoritative/current:
- branch `audit/r21-final-hardening-rc10`
- commit `e89aebd9012f95d050771283562069f9cb5f5515`
- `build/Build-R21.ps1`
- `build/Verify-Determinism.ps1`
- `build/Generate-Sbom.ps1`
- `.github/workflows/r21-rc10-selfhosted-finalize.yml`
- `RC_MANIFEST_v1.1.2-rc10.json`
- `SHA256SUMS_v1.1.2-rc10.txt`

SUPERSEDED — DO NOT RUN as current candidate:
- RC6/RC7/RC8/RC9 release workflows, manifests and runners.
They remain historical provenance/evidence only.
- Public v1.1.1 remains valid rollback/stable authority until v1.1.2 is actually accepted and promoted.

## Key evidence

- `r21_evidence/RC9_REAL_SUSPEND_RESUME.json` — RC9 physical S3 PASS.
- `r21_evidence/RC9_POST_S3_SOAK_90S.json` — RC9 CPU-stall failure evidence; must be preserved.
- `r21_evidence/rc9_contention_probe/RC9_SENSOR_CONTENTION_PROBE.json` — simple storage contention not reproduced.
- GitHub RC10 run `35460297804`.
- RC10 draft prerelease and its build manifest/SBOM/evidence ZIP.
- Local cumulative knowledge/evidence under `%LOCALAPPDATA%\TaskbarMonitorEnhanced\00_PROJECT_CONTROL`.

## Risks / hinges

- Windows Secure Desktop UAC is the current owner gate for replacing Program Files protected binaries. Remote Commander cannot click or bypass Secure Desktop.
- LibreHardwareMonitor/PawnIO may experience transient hardware-access stalls on this MSI Z790 environment; RC10 watchdog semantics require real fault-injection and soak proof.
- Public Stable/Latest promotion is irreversible in practice under immutable-release policy; promotion is forbidden until exact final v1.1.2 identity is revalidated.

## Exact next action

1. Approve the currently requested Windows administrator consent for the hash-pinned RC10 Setup, or run that exact Setup interactively if the prompt was dismissed.
2. Verify installed Broker/Supervisor hashes equal the RC10 manifest and `install_state=READY/CURRENT_EXACT_RC10`.
3. Run RC10 soft-stall and hard-stall fault injections, then post-fault soak.
4. Run real S3 and full installed regressions.
5. If all PASS, record accepted RC10, derive final v1.1.2 identity, rebuild/determinism/install/attest/revalidate, then publish immutable Stable/Latest.

## Account-Transfer Test

PASS for understanding/continuation: a new account can identify project goal, root, current branch/commit, installed mixed state, historical failures, current blocker, release-chain status, remaining gates and exact next action from this Brain alone.

## HISTORY

- v1.1.1: current public stable/rollback authority.
- R21: process-isolated protected sensors, deterministic builds, supply-chain hardening and diagnostics.
- RC7: output-gap and windowless sensor fixes.
- RC8: Main integrity/elevation boundary.
- RC9: official power notification, deterministic Setup and installer state-integrity fixes; real S3 PASS but post-S3 CPU stall recurrence.
- RC10: CPU 15s freshness / 60s hard-stall separation. Build/CI PASS; exact protected install and runtime validation pending.
