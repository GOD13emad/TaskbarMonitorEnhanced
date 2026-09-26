# PROJECT BRAIN — Taskbar Monitor Enhanced

Brain Version: PB-2026-09-26-R22-FINAL-V1.1.2
Status: CURRENT
Updated: 2026-09-26T17:45:52.6601678+03:30


## CURRENT AUTHORITY — 2026-09-26 FINAL RUNTIME ACCEPTED

This section supersedes older Current authority, Current installed state, Current critical gate, UNPROVEN/PENDING, and Exact next action sections below where they conflict. Those older sections are retained as historical provenance.

- Final objective remains immutable public v1.1.2 with deterministic build, exact install/runtime acceptance, GitHub provenance/SBOM attestation, immutable publication, then control-plane closeout.
- Current branch: release/v1.1.2-final.
- Final source authority: 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6.
- Accepted RC10 precursor: eac234860c31d8e2a6c0ba7d61c7bf5248717db5.
- Final identity behavior equivalence: PASS 7/7.
- Final build/determinism/SBOM: PASS.
- Exact installed v1.1.2 identity/hashes/config preservation: PASS.
- Proportional final runtime regression R2: PASS.
- Installed identity: 1.1.2 / V1_1_2_R21_PRODUCTION_HARDENING / 1.1.2+r21 / READY.
- Exact final hashes:
  - Main DFF69CFC96C0A0567DD32C04EBD45414CFF045172A76A84EE1060814921DFE9E
  - Broker 182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833
  - Supervisor 38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196
  - Setup 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB
  - SBOM B324745F6041FA8E8C8FA888977B40B41100B787C6A8E087ED80EB23AC148578
- Runtime: freshness R2 6/6 healthy (0.188–4.573 s); taskbar 12/12 direct Shell_TrayWnd 1100x48; Main RID8192; LHM-in-Main=0; protected PE GUI=2/2; sensor conhost=0; relevant Application/TaskScheduler errors=0.
- RC10 soft/hard stall, post-fault soak and real S3 acceptance are inherited via 7/7 behavior equivalence and were not blindly rerun.
- Known harness failure/prevention: ConvertFrom-Json timestamp auto-conversion plus local string reparse created +03:30 false age. Prevention: -DateKind String plus round-trip DateTimeOffset.
- Current critical path: GitHub exact-final attestation → accepted control commit/push → immutable v1.1.2 Stable/Latest publication → final Brain/Knowledge closeout.
- Public Stable/Latest remains v1.1.1 until the publication gate closes.
- Exact next action: run/verify exact-final GitHub provenance+SBOM workflow from the accepted final authority/control commit; do not rebuild or reinstall locally unless an attestation discrepancy requires it.

## CURRENT AUTHORITY — 2026-09-26 GITHUB ATTESTED / PUBLICATION READY

This section supersedes older current-state sections where they conflict; historical sections remain provenance.

- Immutable v1.1.2 release authority: aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0.
- Behavior/build authority: 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6.
- Final local build/runtime: PASS.
- GitHub workflow run 36244774522: PASS, including deterministic clean-clone build, SPDX generation, binary provenance attestation, Setup-SBOM attestation and evidence upload.
- GitHub evidence artifact 10907450490: binary hashes PASS 4/4 exact.
- SBOM raw hash differs by document-instance fields only; semantic normalized hash PASS at BFBB7FB00FF3C8DD9ED26DBD17C0E3CAED5B4F666BE5373E7C329549AEEB7BAA.
- Initial GitHub run 36244394685 failed before build from shallow checkout; root cause fixed with minimum sufficient fetch-depth 2 and fresh run PASS.
- Public v1.1.2 tag/release was absent at pre-publication audit.
- Critical path: create immutable v1.1.2 at exact attested commit -> verify assets/Latest -> final Brain/Knowledge closeout.
- Exact next action: publish v1.1.2 once at aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0 with exact accepted assets; never move/force the tag.

## CURRENT AUTHORITY — FINAL v1.1.2 PUBLIC RELEASE ACCEPTED

This section is the final current authority for v1.1.2 and supersedes older current-state/open-gate sections where they conflict. Historical sections remain provenance.

- Project lifecycle: FINAL for v1.1.2 Definition of Done.
- Brain Status: CURRENT
- Behavior/build authority: 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6.
- Immutable public release authority: tag v1.1.2 -> aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0.
- Publication-control commit before release: d9f3ed150abab77d0ecce7a88cc71ed150f9a42d.
- Public release: https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.2.
- Release is non-draft, non-prerelease and Latest/Stable.
- Release assets: 8/8 uploaded; 0 digest mismatches; 0 size mismatches.
- Exact Setup SHA256: 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB.
- GitHub CI/provenance/SBOM attestation: PASS.
- Local install/runtime acceptance: PASS.
- RC10 soft/hard watchdog, post-fault soak and physical S3 remain inherited PASS via tracked 7/7 behavior equivalence.
- SPDX raw document hashes differ only by documentNamespace/git-head and creation timestamp; semantic-normalized hash is identical and PASS.
- Open blockers: none.
- Open gates: none.
- Exact next action: none for v1.1.2. Any future change starts a new maintenance/release scope; do not move or overwrite tag v1.1.2.
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
- RC10 binary-source self-hosted GitHub run: `35460297804` = SUCCESS at `e89aebd...`.
- RC10 control-head self-hosted GitHub run: `35460716964` = SUCCESS at `238d93e...`.
- RC10 draft prerelease target: `238d93eeeadd83e31aa1de002cf00dee0778da41`, draft/prerelease only; binary source authority remains `e89aebd...` because the later commit changes only control records.
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
**Obtain a new explicit administrator-consent approval, then install exact protected RC10 pair and execute fault-injection/runtime acceptance.**

Remaining after RC10 protected install:
- 25-second soft-stall fault injection: no CPU restart; UI freshness remains truthful; same worker recovers.
- >60-second hard-stall fault injection: hard watchdog must restart stuck CPU worker and recover.
- post-fault runtime soak with stable restart counters and zero new failures.
- real S3 regression on installed RC10.
- taskbar/module/EventLog/windowless/integrity regressions on installed RC10.
- update acceptance/Brain to RC10 accepted state.
- derive exact final v1.1.2 identity from accepted RC10, rebuild/determinism/install/attest/revalidate and only then publish immutable Stable/Latest.

## Current installed state — IMPORTANT

The attempted protected RC10 elevation reached Windows Secure Desktop, but Windows returned **"The operation was canceled by the user."** Per fail-closed policy it was not automatically retried.

A transactional rollback was then completed with the exact accepted RC9 Setup:
- RC9 Setup SHA-256: `48DADB48072344E4627A939971313B931E84365A0311F79E48FC793BB029CBC8`.
- installed Main: `911D5F6303BB6CBA48FB1D9651B4CADB541A62BB6781E57312FEA52E913AE59D`.
- installed Broker: `5D4824409E34794467340741A88EE0B1EC390ADE9F090D33B5746DD92081CB9C`.
- installed Supervisor: `A0A7C711BEC1F920DB8107E4700FCA886EF7E6869E987546D0938DBEA69DFDB5`.
- `install_state.json`: `1.1.2-rc9 / READY / CURRENT_EXACT_RC9`.
- post-rollback HealthProbe: `PASS / STABLE / ActiveConsecutiveFailures=0`.
- runtime tree: 1 Supervisor, 2 persistent Brokers, 0 sensor-owned console children.
- no Setup orphan remains.

Therefore the user's live machine is back on the last accepted runtime baseline and is **not left degraded**. RC10 remains a development candidate whose exact protected installation requires a new explicit future administrator consent before runtime/fault-injection acceptance can proceed.

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

- Windows Secure Desktop UAC is the current owner gate for replacing Program Files protected binaries. The latest consent was canceled by the user; Remote Commander must not automatically retry or bypass that denial.
- LibreHardwareMonitor/PawnIO may experience transient hardware-access stalls on this MSI Z790 environment; RC10 watchdog semantics require real fault-injection and soak proof.
- Public Stable/Latest promotion is irreversible in practice under immutable-release policy; promotion is forbidden until exact final v1.1.2 identity is revalidated.

## Exact next action

1. Provide a new explicit administrator-consent approval for the hash-pinned RC10 Setup. The previous UAC was canceled and will not be retried automatically.
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
- RC10: CPU 15s freshness / 60s hard-stall separation. Build/determinism/SBOM/self-hosted CI PASS; protected-install consent was canceled, live system was rolled back cleanly to accepted RC9, and RC10 runtime validation remains pending.

- 2026-09-26 R22: final v1.1.2 identity equivalence 7/7 PASS; deterministic build/SBOM PASS; exact final install PASS with config preserved; proportional runtime R2 PASS after correcting known PowerShell timestamp harness false negative. GitHub publication remains the critical path.


## CI FAILURE / PREVENTION — 2026-09-26 RUN 36244394685

- Status: CURRENT
- Failed GitHub run: 36244394685 at control commit 483367af265eae8bd6043c11570f8f6be58531de.
- Failure point: Git whitespace check before any build or attestation step.
- Exact error: fatal: ambiguous argument HEAD^: unknown revision or path not in the working tree.
- Root cause: actions/checkout defaults to fetch-depth 1, while the next step requires parent commit HEAD^.
- Prevention: keep the pinned checkout action and add only fetch-depth: 2, the minimum history required by the official actions/checkout HEAD^ scenario.
- Regression: a fresh push run must pass whitespace, build, determinism, SBOM, provenance, Setup-SBOM and evidence upload; downloaded artifact hashes must match the already accepted final hashes.
- The failed run is not rerun blindly. Critical path remains GitHub attestation -> immutable v1.1.2 publication -> final closeout.

- 2026-09-26 R22 FINAL: v1.1.2 published and post-verified as immutable Latest/Stable at aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0; 8/8 release assets digest/size verified; no open DoD gate.
