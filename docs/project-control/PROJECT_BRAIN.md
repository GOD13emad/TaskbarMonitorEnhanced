# PROJECT BRAIN — Taskbar Monitor Enhanced

Brain Version: PB-2026-09-27-R31-V1.2.0-CANDIDATE
Status: CURRENT
Updated: 2026-09-27T16:24:00+03:30


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

## CURRENT MAINTENANCE — R23 DEVELOPMENT CODE SIGNING

This maintenance scope does not modify the immutable v1.1.2 release.

- Branch: maintenance/code-signing.
- Development Authenticode identity: CN=Taskbar Monitor Enhanced Development Code Signing.
- Thumbprint: 4673165CCB579F868EFE5F52FCDA761780F49989.
- Certificate: RSA / sha256RSA / Code Signing EKU.
- Private key: CurrentUser\My only; not exported and not committed.
- Public certificate SHA256: 217EC08DF0C2A23F9AEB3925FA40D7561FC21DE61039458514067FAAC0753A10.
- Signing probe: PASS on an evidence copy only; signed probe SHA256 65168AD41EAA0C5B562FACE9E3DDEBACDA9EBC38606C94C42D4E9C55AA6AAFCD.
- Verification negative tests: unsigned file rejected; tampered signed copy rejected.
- Windows trust result: UnknownError because the self-signed development root is not publicly trusted. This is expected and is not presented as Trusted Publisher status.
- Immutable v1.1.2 Setup remains 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB; tag remains aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0.
- Development signing tooling supports SHA256 Authenticode and optional RFC3161 timestamping.
- Public-trust blocker: obtain a CA-issued Code Signing certificate or approved managed signing identity.
- Exact next action for a publicly trusted signed release: use the CA identity to sign binaries before packaging, sign/timestamp installer last, regenerate hashes/SBOM/attestation and publish a NEW version. Never rewrite v1.1.2.

## CURRENT MAINTENANCE — R24 PUBLIC-TRUST SIGNING READINESS

This section supersedes R23 as the current maintenance authority where they conflict. Immutable public v1.1.2 remains unchanged.

- Working branch: `maintenance/signpath-readiness`, based on accepted R23 commit `41963f94013ecb8745897839ccc6e9b220be5d71`.
- Public-trust route selected: SignPath Foundation open-source signing application. Acceptance is external and PENDING; no release is claimed SignPath-signed.
- Repository is public; GitHub account `GOD13emad` has 2FA enabled.
- Root license declaration remains GPL-3.0-or-later; truncated root LICENSE was replaced with the already-accepted full GNU GPL v3 text without changing the declared license family.
- README and DOWNLOAD now expose the exact Code signing policy terminology, required SignPath provider attribution, privacy link, immutable-release rule, and explicit install/uninstall instructions.
- Actual updater/privacy audit: default HTTPS release check targets GitHub Releases API and can be disabled; installer download requires user confirmation; monitoring telemetry/config/hardware readings are not uploaded to a project-operated service.
- Actual PE metadata gate: PASS for Main, Broker, Supervisor and Setup. ProductName = Taskbar Monitor Enhanced; ProductVersion = 1.1.2+r21; FileVersion = 1.1.2.0; Company/FileDescription populated.
- Actual uninstall gate: PASS from installer source. Windows per-user Installed apps registration includes DisplayName, DisplayVersion, Publisher, UninstallString and QuietUninstallString; uninstaller path is `%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe`.
- SignPath application surface: `https://signpath.org/apply.html`, HubSpot portal `145110231`, form `bf62807d-bb72-4e45-9bde-1f3a53ba2472`; browser page loaded and Tagline/Description fields were observed.
- Hard external interaction gate: Remote Commander rejects browser input with `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`. Chat authorization cannot override this platform gate. Application submission therefore remains NOT SUBMITTED.
- Prepared application packet: `docs/security/SIGNPATH_APPLICATION_PACKET.json`, status `READY_TO_SUBMIT_DIRECT_USER_GUI_ACTION_REQUIRED`.
- Immutable release regression remains PASS: tag v1.1.2 -> `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`; Setup SHA256 `25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB`.
- Publicly trusted signature status: PENDING. Development Authenticode pipeline remains PASS but does not provide public publisher trust.
- Current critical path: commit/push readiness docs -> fast-forward default `main` to the accepted readiness commit without force -> verify immutable release -> user/direct-GUI submission of SignPath application -> SignPath Foundation review/acceptance -> create a NEW signed release, never rewrite v1.1.2.

## R24 REPOSITORY-SIDE READINESS CLOSEOUT

- Repository readiness commit: `b6c13838624e99d1d6ba4811b295834e22e45947`.
- `origin/main` and `origin/maintenance/signpath-readiness` were both verified at that commit after an ordinary non-force fast-forward of main.
- GitHub Actions exact run `36250864888` for head SHA `b6c13838624e99d1d6ba4811b295834e22e45947`: COMPLETED / SUCCESS.
- CI job `build`: all steps PASS, including checkout, whitespace, reproducible build, deterministic clean-clone verification, SPDX SBOM generation, binary provenance attestation, Setup SBOM attestation and evidence upload.
- Repository-side SignPath Foundation readiness: PASS.
- External application state: NOT SUBMITTED. Remote Commander browser input is blocked by `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`; this platform gate cannot be bypassed by chat authorization.
- Publicly trusted Authenticode release state: PENDING external SignPath Foundation review/acceptance and a future NEW release. Development self-signed signing remains test-only.
- Immutable public v1.1.2 remains unchanged: tag `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`, Setup SHA256 `25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB`.
- Exact next action: in a direct user browser session, submit the already-prepared SignPath application using `docs/security/SIGNPATH_APPLICATION_PACKET.json`; after external acceptance, create and validate a separately versioned signed release. Never rewrite v1.1.2.

## R24 FINAL SIGNPATH APPLICATION GATE

- Official application surface re-audited from public SignPath/HubSpot resources: portal `145110231`, form `bf62807d-bb72-4e45-9bde-1f3a53ba2472`, region `eu1`.
- Public render-definition SHA256: `bf122cf482f6887667fb30661e3be8bafdcdac0c15c05c5a79a72f5337aeb570`.
- Exact required fields are known and prepared in `docs/security/SIGNPATH_APPLICATION_PACKET.json`, including Project/Repository/Homepage, Tagline, Description, Reputation, Build System, First/Last Name, Email and Discovery Channel.
- Truthful reputation audit: this new repository currently has 0 stars, 0 forks, 0 subscribers and 0 v1.1.2 release-asset downloads. No adoption claim is made. Declared GPL upstream `leandrosa81/taskbar-monitor` currently has 540 stars, 42 forks and 13 subscribers; those metrics are recorded only as upstream heritage.
- Trust evidence supplied instead of inflated adoption claims: deterministic clean-clone GitHub Actions build, SPDX 2.3 SBOM, GitHub build/SBOM attestations, immutable SHA256 release manifests and documented Windows runtime acceptance.
- Required first-person external attestations identified:
  1. agree to SignPath Foundation Code of Conduct and certificate-revocation terms;
  2. agree to SignPath storage/processing of personal data.
- Optional SignPath marketing consent remains intentionally unchecked unless separately requested.
- Form also contains reCAPTCHA2. It is a human anti-bot control and must not be bypassed or solved programmatically.
- User explicitly authorized mouse/keyboard use in the current chat. ChatGPT app permission for Remote Commander is already `Allow all actions`; server reports GUI mouse/keyboard capability and `explicit-current-request-only`.
- Connector limitation: the tool schema exposed to this ChatGPT session for `gui_session_begin` accepts only `ttlSeconds` and always creates an observe-only lease. The server-side intended takeover parameters (`mode=takeover`, `explicitUserAuthorization`) are not exposed through this session. Direct takeover therefore cannot be acquired; workflow takeover is separately blocked by `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`.
- Security decision: no raw MCP request, SendInput, UIAutomation, Chrome DevTools Protocol or shell-based injection will be used to circumvent the takeover/CAPTCHA gates.
- Official application and Code of Conduct pages were opened on the user's Windows desktop; application page was reopened as the newest browser tab.
- Application status: `READY_FOR_EXPLICIT_CONSENT_AND_RECAPTCHA`; Submitted = FALSE.
- Repository-side public-signing readiness remains PASS. Publicly trusted signing remains PENDING SignPath submission/review/acceptance and a future NEW signed release. v1.1.2 remains immutable.
- Exact next action: user must personally attest the two mandatory consent statements and complete reCAPTCHA on the already-open official form. After submission evidence is available, update packet/Brain and proceed with SignPath review/acceptance and a new signed release.

## R25 / v1.1.3 STARTUP RESILIENCE — LOCAL ACCEPTANCE

- Trigger: after a real power-loss/restart event, application configuration still had `StartWithWindows=true` and Windows StartupApproved was enabled, but the actual HKCU Run value `TaskbarMonitorEnhanced` was absent. The protected sensor supervisor still started independently. The exact external remover of the Run value remains UNPROVEN.
- Bootstrap defect in v1.1.2: Main could repair its Run value only after Main was already running; losing the sole Main launch registration therefore prevented self-heal.
- v1.1.3 design: two independent per-user registrations when Start with Windows is enabled:
  1. primary HKCU Run value for immediate launch;
  2. current-user Startup-folder recovery shortcut invoking `--startup-recovery`.
- Recovery behavior: waits up to 12 seconds for the primary launch path, exits early if a primary process exists, otherwise continues normal startup. Existing named mutex remains the final single-instance guard.
- Mutual repair: surviving Run launch recreates a missing recovery shortcut; surviving recovery shortcut launches Main and Main recreates the missing Run value. Disabling Start with Windows removes both. Uninstall source removes both.
- Privilege decision: a Scheduled Task fallback was rejected after a real non-elevated `schtasks /Create /SC ONLOGON` probe returned Access Denied. The accepted fallback is per-user Startup-folder based and requires no administrator privilege.
- Code + visual candidate commit: `bcbd8f8e8861e4e4a83350699214f1bb83b1132e`, branch `release/v1.1.3-startup-resilience`, parent `9fcfcd389eea85e2ccbdf03ce6cdfe8b99463e9b`.
- Build identity: `V1_1_3_R22_STARTUP_RESILIENCE`; public version 1.1.3.
- Local build gates: four project builds PASS with 0 warnings / 0 errors; Setup verify PASS; built-in selftest PASS; sensor windowless PE PASS; canonical text payload PASS; SPDX 2.3 SBOM PASS.
- Clean-clone deterministic verification on exact commit `bcbd8f8...`: `R21_REPRO_BUILD=PASS`, `R21_DETERMINISM=PASS`.
- Exact outputs at local acceptance:
  - Main: `74E7725E3C3911EFEDEC1181C21AF07571C9A22CD758EE50E06EA1373DAB7317`
  - Broker: `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833`
  - Supervisor: `38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196`
  - Setup 1.1.3: `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`
  - SBOM: `651057410EB57090E1D7ED5EB9522AB8B40284D484CAB0A1C9ADA4DC1833E192`
- Protected sensor layer remains accepted `1.1.2+r21`; exact Broker/Supervisor hashes were unchanged after v1.1.3 install; install state READY / CURRENT_EXACT_1_1_2.
- Live startup fault injection:
  - missing Run -> recovery path -> Run recreated, one Main: PASS;
  - missing recovery shortcut -> normal launch -> shortcut recreated with exact target/argument, one Main: PASS;
  - recovery launch while primary running -> fallback exit 0, same sole primary PID: PASS;
  - StartWithWindows=false -> both registrations absent and app usable; original true setting restored and both registrations returned: PASS.
- Visual qualification: all 14 themes regenerated by the real v1.1.3 renderer from 30 live samples with `NoSyntheticMetricData=true`; theme proof PASS. Compact proof PASS at 592 px and 500 px with zero recorded overflow. Current proof images/manifests are published under `docs/screenshots/themes` and `docs/screenshots/compact`.
- Sanitized acceptance record: `docs/acceptance/v1.1.3/STARTUP_RESILIENCE_ACCEPTANCE.json`.
- Immutable regression: v1.1.2 tag still `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`; v1.1.2 Setup SHA256 still `25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB`.
- Signing: v1.1.3 remains UNSIGNED unless independently verifiable public-trust Authenticode evidence exists. SignPath readiness does not equal provider acceptance.
- Current state: LOCAL ACCEPTANCE PASS. Public release is not yet claimed until final metadata commit, exact-head GitHub CI success, immutable tag/release creation, and remote asset digest verification complete.
- Exact next action: commit release-control docs -> determinism on exact metadata head -> non-force push branch/main -> exact-head GitHub CI -> immutable v1.1.3 release -> post-release digest/immutability seal.

## R25 / v1.1.3 PUBLIC RELEASE CLOSEOUT — 2026-09-27

- Status: FINAL_PUBLIC_RELEASE_ACCEPTED.
- Immutable release tag `v1.1.3` points exactly to `fa8c75d0b59343ccb7eae86320a351e3b4064c48`; no force push or tag rewrite was used.
- GitHub release: `https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.3`; published 2026-09-27T10:06:33Z; Latest=true; Draft=false; Prerelease=false.
- Exact-head GitHub Actions PASS on both pushed refs: main run `36311195266` and release-branch run `36311191121`. Both passed whitespace, reproducible build, deterministic clean clone, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload and manifest gates.
- GitHub main CI artifact `10929282504`, digest `sha256:537d6d902e9b99cc6fa5c8337606a7609a52e89d22b953e1c777a74ba0dab1bc`; downloaded Main/Broker/Supervisor/Setup binaries matched the accepted local hashes 4/4 exactly.
- Public release assets: 7/7 digest+size verification PASS. Setup SHA256 `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`; source ZIP SHA256 `D6B3B99AEEE7B3E816D94ECE6C41F25FDF338833923AFB08A3A4B29907F227CA`.
- Published SPDX raw document SHA differs from the exact-head CI SPDX raw document because generated document namespace/time fields differ. Semantic normalization over SPDX identity/version, packages, file hashes and relationships is identical: SHA256 `2e5375bfa63263162953f2c2a7a8c98b7cc4729bbb871cc7aad9f90b3c4238a1`; semantic equivalence PASS. Exact-head CI generated and attested its own SBOM at the release commit.
- Startup resilience acceptance remains PASS: missing Run self-heal, missing recovery-shortcut self-heal, duplicate recovery early exit, StartWithWindows=false cleanup, and restoration of the user's enabled state all passed.
- Visual qualification remains PASS: 14/14 themes, 30 live samples, NoSyntheticMetricData=true; 592 px and 500 px compact proofs have zero LayoutChecks overflow.
- Accepted protected sensor layer remains `1.1.2+r21`, READY, with Broker/Supervisor hashes unchanged.
- Public-trust signing remains PENDING external provider acceptance; v1.1.3 is not claimed as SignPath-signed and may show Unknown publisher.
- Immutable v1.1.2 regression remains PASS: tag `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`; Setup digest `sha256:25744a0a0f78b787a5fc3601577748b80353adc9dafb9fe91a111a53c56216fb`.
- Non-blocking CI maintenance note: GitHub reports that the pinned upload-artifact action declares Node.js 20 and is currently forced to Node.js 24. It did not fail any release gate.
- Final public acceptance record: `docs/acceptance/v1.1.3/PUBLIC_RELEASE_ACCEPTANCE.json`.
- Critical path for v1.1.3: CLOSED. Future public-signing work must create a separately versioned signed release and must not rewrite v1.1.3.

## POST-RELEASE CI MAINTENANCE — NODE 24 ACTION PIN

- 2026-09-27 mutation: replace pinned `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02` (v4 / Node.js 20 declaration) with official `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` (v7.0.1 / Node.js 24).
- Motivation: remove the non-blocking GitHub Actions Node.js 20 deprecation annotation observed on all accepted v1.1.3 CI runs.
- Source verification: official actions/upload-artifact latest release is v7.0.1, published 2026-04-10; tag resolves directly to commit `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`; `action.yml` declares `using: node24`.
- Scope: CI workflow only. Immutable release tag `v1.1.3` and its seven assets remain unchanged.
- Validation state at mutation: PENDING exact main CI. Do not call this maintenance PASS until the new commit completes the full R21 workflow without the Node.js 20 annotation.

### NODE 24 ACTION PIN VALIDATION — PASS

- Exact maintenance commit `1fabcfc420fa996cc2e7e44a4182d2569ddba007` completed GitHub Actions run `36311950294` successfully.
- Full R21 workflow passed: whitespace, reproducible build, deterministic clean clone, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload and manifest.
- The previous Node.js 20 deprecation annotation is absent on this run. The `actions/upload-artifact` v7.0.1 / Node.js 24 pin therefore resolves the known post-release CI warning.
- v1.1.3 release tag/assets remain untouched at `fa8c75d0b59343ccb7eae86320a351e3b4064c48`.
- CI maintenance status: PASS / CLOSED.


## R26 / REPOSITORY HYGIENE + WORKSPACE CONSOLIDATION — 2026-09-27

- Objective: professionalize the project after v1.1.3 acceptance, reduce duplicate environments/artifacts, preserve irreplaceable evidence, and keep one canonical source workspace.
- Canonical source workspace is now `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced` on `main`.
- The former linked worktree `TaskbarMonitorEnhanced_R20` was removed from Git worktree metadata after it was reduced to tracked content only. Its now-empty directory is still held open by a running process and therefore cannot yet be deleted; it contains no project data and is not an active Git worktree.
- Historical raw evidence and network-expensive caches were MOVED, not copied, to `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_cleanup`.
- Preserved archive contents include R20/R21 raw evidence, supply-chain evidence, upstream reference cache, the pinned build dependency cache, and meaningful legacy runtime-control evidence.
- Obsolete/rebuildable local material was deleted: the 2026-09-19 preinstall backup, transient build outputs, package staging, benchmark/canary/test workspaces, duplicated runner ZIP/EXE automation stores, duplicated download-control caches, and stale atomic temp files.
- Cleanup prestate covered 2,319,268,833 bytes. Preserved archive is 392,287,771 bytes. Approximate active-storage reduction / deduplication is 1,926,981,062 bytes (~1.79 GiB).
- Active source tree after phase-1 filesystem cleanup was ~1.86 MB excluding Git metadata; installed TaskbarMonitorEnhanced root was reduced to ~69.56 MB while v1.1.3 remained running with one Main process.
- `build\_deps` is now a directory junction to the preserved central dependency cache so LibreHardwareMonitor/PawnIO do not need to be downloaded again. Pinned hashes remain:
  - LibreHardwareMonitor.zip: `086D9F1B5A99E643EDC2CFAAAC16051685B551E4C5AC0B32A57C58C0E529C001`
  - PawnIO_setup.exe: `1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032`
- GitHub release hygiene: five superseded v1.1.2 RC draft releases were deleted. Published releases v1.1.2 and v1.1.3 and their immutable tags remain untouched.
- GitHub branch hygiene: 13 remote branches already merged into `main` were deleted, including obsolete audit/finalization, signing-maintenance, and completed release branches. Two unmerged historical branches were deliberately preserved because they contain unique old lineage: `fix/sensor-installer-resilience` and `release/v1.1.0`.
- v1.1.3 tag remains exactly `fa8c75d0b59343ccb7eae86320a351e3b4064c48`; v1.1.2 tag remains exactly `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`.
- Obsolete RC6-RC10 self-hosted GitHub Actions workflows are being removed from current `main`; only the current general R21 CI workflow is retained for normal validation.
- `CONTRIBUTING.md` is being upgraded with explicit branch, immutable-release, validation, and repository-hygiene rules.
- External cleanup evidence is retained in the archive as `CLEANUP_PRESTATE.json`, `CLEANUP_POSTSTATE_PHASE1.json`, `GITHUB_HYGIENE_PRESTATE.json`, and `GITHUB_HYGIENE_POSTSTATE.json`.
- Current open gate: commit and exact-main GitHub CI for this hygiene change. The empty locked legacy R20 directory is a non-blocking local cleanup residue only.


### R26 VALIDATION / CLOSEOUT — PASS

- Hygiene commit `f671bb4aee4dadc2f418e95c21471faa108322e7` passed exact-main GitHub Actions run `36313319634` in full: checkout, .NET setup, whitespace, reproducible build, deterministic clean clone, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload, and manifest.
- Local validation from the centralized dependency cache also passed with `Build-R21.ps1 -NoDownload`, built-in self-test, setup verification (19 resources), and deterministic clean-clone verification.
- Exact v1.1.3 Setup hash after cleanup remained `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`; cleanup did not mutate the published release.
- Local Git branch hygiene is complete: only `main` remains locally.
- Remote branch hygiene is intentionally conservative: `main` plus two unmerged historical branches remain; all already-merged audit/maintenance/release branches were removed.
- GitHub draft-release hygiene is complete: no draft releases remain.
- Obsolete branch-specific RC6-RC10 self-hosted workflows are removed; current validation is centralized in `.github/workflows/r21-ci.yml`.
- Current canonical source root: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`.
- Current preserved external archive: `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_cleanup`.
- Residual: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced_R20` is an empty directory only, no longer a Git worktree, but Windows reports it held open by another process. This is a cosmetic/non-blocking residue and contains zero project items.
- R26 status: PASS. Repository and local workspace are consolidated and professionally maintainable without sacrificing accepted evidence or pinned offline dependencies.


## R27 / PUBLIC-README VISUAL + ROOT ARTIFACT CLEANUP — 2026-09-27

- User-visible audit found two residual presentation issues after R26:
  1. historical v1.1.2 RC manifests/checksum files were still cluttering the repository root;
  2. README referenced `docs/screenshots/desktops/desktop-dark-minimal.webp`, but that Git object was structurally truncated.
- The RC files are historical candidate audit records, not current release assets. They were preserved with `git mv` under `docs/acceptance/archive/v1.1.2-rc/` and documented with an archive README. Root RC artifact count is now zero.
- Corrupt WebP diagnosis is exact: RIFF header declared 62,952 bytes while the tracked Git object contained only 15,008 bytes. GitHub therefore could not decode/render it, producing the apparent blank region in README.
- The corrupt desktop WebP and its obsolete subdirectory README were removed from current `main`; no false 'real desktop capture' claim remains.
- README now uses verified live-rendered application evidence: `THEME_01_DARK_MINIMAL_PRO.png` plus the 14-theme contact sheet.
- Screenshot gallery now uses only structurally valid assets and explicitly records that the truncated historical WebP was removed.
- Validation: every Markdown image link in root README and screenshot README resolves to an existing file; all screenshot PNG/WebP assets pass structural signature/container checks; no broken image links remain.
- R27 publication gate: pending commit + exact-main GitHub CI.


## R28 / PUBLIC REPOSITORY STRUCTURE CLEANUP — 2026-09-27

- User-facing GitHub cleanup continued after R27 because historical version/revision filenames were still visible in active repository locations.
- Root policy is now: current source/docs only; historical release artifacts are grouped by version under `docs/releases/archive/`; historical acceptance evidence is grouped by version under `docs/acceptance/archive/`.
- Current v1.1.3 release notes moved from versioned root filename to `docs/releases/v1.1.3/RELEASE_NOTES.md`; the build still embeds the same canonical content under its established package-resource name, so installer payload semantics are preserved.
- Current v1.1.3 acceptance records moved to `docs/acceptance/v1.1.3/` with generic filenames.
- Historical v1.0.0–v1.1.2 release notes/manifests/checksums were moved with Git history preserved into version directories using generic filenames.
- Historical FINAL_ACCEPTANCE / R21 / R22 / RC10 public-facing filenames were moved under release-specific acceptance archive directories and renamed generically where appropriate.
- Project Brain and reusable Project Knowledge moved from the special-purpose root `00_PROJECT_CONTROL` directory into `docs/project-control/`, removing the internal control-plane folder from the public repository root.
- Added `docs/releases/README.md`, `docs/acceptance/README.md`, and `docs/project-control/README.md` as navigation/index surfaces.
- Root now contains no versioned RELEASE_MANIFEST / SHA256SUMS / historical RELEASE_NOTES filenames and no `00_PROJECT_CONTROL` directory.
- Historical JSON evidence retains original embedded release-asset/local-path labels where those fields are part of the evidence record; physical repository locations are organized without rewriting historical facts.
- Build source path updated to consume `docs/releases/v1.1.3/RELEASE_NOTES.md`; output resource name remains stable.
- Publication gate: run local no-download build + deterministic verification, then exact-main GitHub CI before accepting R28.


## R29 / ACTIVE TOOLING NAME CLEANUP + IMMUTABLE BUILD PRESERVATION — 2026-09-27

- Active engineering filenames were professionalized after the release/archive reorganization:
  - `.github/workflows/r21-ci.yml` -> `.github/workflows/ci.yml`
  - `build/Build-R21.ps1` -> `build/Build.ps1`
  - generated `R21_BUILD_MANIFEST.json` -> `BUILD_MANIFEST.json`
  - generated `R21_SBOM.spdx.json` -> `SBOM.spdx.json`
  - CI artifact name `r21-build-evidence` -> `build-evidence`
- Determinism, contribution, installer, build and CI documentation now reference generic active names. Historical archive/evidence content keeps original revision identifiers where they are factual lineage.
- Public README was shortened to a current reliability/validation summary instead of exposing RC/R21 engineering history as the primary landing-page narrative.
- Critical immutability finding: because the installer embeds `README.md`, ordinary README cleanup initially changed the rebuilt v1.1.3 Setup hash even though executable code was unchanged.
- Prevention architecture: exact accepted embedded README bytes were extracted from the published immutable v1.1.3 Setup resource `Payload.README.md` and stored as `docs/releases/v1.1.3/INSTALLER_README.txt`.
- The build now embeds that frozen release payload snapshot while the public repository README can evolve independently.
- Frozen snapshot SHA256: `9808CC72828F1672A916EEDC6CBD8C7525169DAF5F5C5DF0500BEA9D00CFF7A1`.
- Local no-download rebuild after the freeze restored the exact published v1.1.3 Setup SHA256 `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`.
- Markdown-link audit after reorganization: 73 local links checked, 0 broken.
- Static hygiene: no historical release/checksum/RC files remain in repository root; no active workflow/build filenames contain Rxx/rcxx revision labels.
- Publication gate: commit reorganized tree, run deterministic clean-clone verification from exact commit, push main non-force, require exact GitHub CI PASS.


### R29 VALIDATION / CLOSEOUT — PASS

- Exact restructuring authority: commit `80f9c95afbc419bf49384d16be6f9a63d09a05d4`.
- GitHub Actions run `36315722461` at that exact head completed SUCCESS under the generic workflow name `Build and Verification`.
- CI artifact is now `build-evidence`, artifact id `10929984813`, digest `sha256:2345bb1f03c90ce270e1ec1043b029688badcfb1fb6c3d6fd3282c77f965bb43`.
- Downloaded CI evidence confirmed generic files `BUILD_MANIFEST.json` and `SBOM.spdx.json`, plus exact binary equality for Main/Broker/Supervisor/Setup.
- CI Setup SHA256 remains exactly `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`, identical to immutable public v1.1.3.
- Main/Broker/Supervisor CI SHA256 values remain `74E7725E...`, `182D6346...`, and `38553CCE...` respectively, matching accepted release binaries.
- GitHub API post-publication audit confirms:
  - repository root contains only current project/policy entry points and standard source directories;
  - no historical RELEASE_MANIFEST / SHA256SUMS / versioned RELEASE_NOTES / RC manifest files remain in root;
  - `docs/` top-level contains only organized category directories plus `AMD_INTEL_GPU_PORTABILITY.md`;
  - active workflow surface contains only `.github/workflows/ci.yml`;
  - active build surface uses `build/Build.ps1` and generic helper names.
- Markdown relative-link audit: 74 local links checked, zero broken.
- R29 status: PASS / CLOSED.


## R30 / FINAL PUBLIC-TREE CLEANUP — 2026-09-27

- Scope: remove all obsolete release-candidate/versioned artifact filenames from the active `main` tree while preserving historical recoverability.
- Historical repository archives under `docs/releases/archive/` and `docs/acceptance/archive/` were removed from active `main`. Before removal, 42 files / 97,431 bytes were copied to:
  `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_cleanup\repository_history_removed_from_main`
  with `ARCHIVE_MANIFEST.json` SHA256 `FE6D1A1A9385D9CF5B0B8593A4899C571B4FED3EA0B50005650255F9FE44A018`.
- Historical public evidence also remains recoverable from immutable Git history, release tags, and GitHub Releases. No published tag or release asset was modified.
- `docs/AMD_INTEL_GPU_PORTABILITY.md` moved to `docs/hardware/GPU_PORTABILITY.md`; `docs/` top-level is now category-only.
- Current `docs/releases/README.md` and `docs/acceptance/README.md` describe only the current release plus GitHub/Git history as the historical authority; no local historical-archive links remain.
- Active root/path hygiene audit: zero tracked filenames matching obsolete RC/revision/versioned artifact patterns (`RC_MANIFEST`, versioned `SHA256SUMS`/`RELEASE_MANIFEST`/`RELEASE_NOTES`, `FINAL_ACCEPTANCE_v*`, `Build-R21`, `r21-ci`, `R21_*`, `R22_*`).
- Repository root contains only current standard project/policy files and source directories.
- Markdown relative-link audit: 62 links checked, 0 broken.
- Local build after cleanup: PASS with `build/Build.ps1 -NoDownload`, 0 warnings/errors, Setup verify PASS 19/19, self-test PASS, deterministic clean-clone PASS.
- Immutable v1.1.3 Setup SHA256 after cleanup remains exactly `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`.
- Current generated evidence names remain generic: `BUILD_MANIFEST.json` and `SBOM.spdx.json`.
- Publication gate: commit/push this final tree cleanup and require exact-head GitHub CI PASS before declaring R30 closed.


### R30 VALIDATION / CLOSEOUT — PASS

- Final public-tree cleanup authority commit: `ce94e70a170abdfeb6b5c4491c9cebd7d029639c`.
- Exact-head GitHub Actions run `36317306947` completed SUCCESS under `Build and Verification`.
- CI passed checkout, SDK setup, whitespace, reproducible build, deterministic clean-clone build, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload, and manifest output.
- Active `main` contains zero obsolete RC/revision/versioned artifact filenames matching the cleanup deny-list; root and `docs/` top level are category-oriented and current-release focused.
- Historical release/acceptance records removed from active `main` remain preserved in the external hashed archive and in immutable Git history/tags/GitHub Releases.
- Remaining two historical unmerged remote branches were preserved before deletion in a complete Git bundle:
  `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_cleanup\historical_unmerged_branches.bundle`
  SHA256 `736C13A830F6440D8BF972A39556798D0028ABE1442F739AA00E4FDFD3F18948`.
- Bundled branch tips:
  - `fix/sensor-installer-resilience` -> `db9a24e4f334ea5c30ab09f16fe31092fc22311e`
  - `release/v1.1.0` -> `c800eeefc89b1fba2d94c1aeb21555ac88e3f014`
- After bundle verification, both historical remote branches were deleted. Remote branch surface is now only `main`.
- Immutable public release tags remain unchanged, including `v1.1.3` -> `fa8c75d0b59343ccb7eae86320a351e3b4064c48`.
- R30 status: PASS / CLOSED. Public repository tree and branch surface are professionally consolidated without loss of recoverability.


## R31 / v1.2.0 MODERN SETTINGS + THEME LIBRARY — CANDIDATE CURRENT AUTHORITY — 2026-09-27

This section supersedes older current-state/next-action sections where they conflict. Published v1.1.3 remains immutable and accepted; this section describes the new unreleased candidate only.

- Candidate identity: `1.2.0 / V1_2_0_R01_MODERN_SETTINGS_THEME_LIBRARY / 1.2.0+r01`.
- Working branch: `feature/modern-settings-theme-library`.
- Public Stable/Latest remains immutable `v1.1.3`; no v1.2.0 tag/release has been created.
- Main mutation objectives:
  1. Settings-open hover flyout must never open/remain stuck.
  2. Settings UX modernized without replacing the proven WinForms/runtime architecture.
  3. Theme library doubled from 14 to 28 with seven additional renderer families rather than palette-only duplication.
- Hover root cause: Settings stopped `hoverTimer`, but overlay `MouseEnter/MouseMove` still called `HandleHardwareHover`; a flyout opened during Settings therefore lacked the watchdog that normally dismisses it.
- Hover fix: Settings-open guards now hide any visible flyout, reset hover identity state, and return before hover resolution; the watchdog has the same defensive guard.
- Hover regression: `--hoverguardproof` = PASS with `MOVE_SUPPRESSED=TRUE WATCHDOG_SUPPRESSED=TRUE FLYOUT_HIDDEN=TRUE`.
- Settings redesign: left navigation, page title/subtitle header, dark surfaces, consistent flat controls, fixed action bar, and live theme preview. Existing eight functional pages and data/config semantics are preserved.
- Settings visual proof: PASS 8 pages at 1080x760 after correcting an initial proof-harness false positive. A form that was only `CreateControl()`-initialized produced blank DrawToBitmap output; prevention is to actually Show the form off-screen, process layout/paint events, then capture.
- Theme library: 28 themes total. New themes: Aurora Borealis, Solarized Luxe, Arctic Frost, Sakura Night, Matrix Grid, Desert Sand, Royal Amethyst, Ocean Depth, Copper Industrial, Nordic Light, Ember Forge, Synthwave Sunset, Quantum Violet, Monochrome Paper.
- New renderer families: `aurora`, `luxe`, `zen`, `synth`, `matrix`, `paper`, `industrial`.
- Theme proof: PASS 28/28 from live telemetry; no synthetic metric data; manifest SHA256 `6791C6C44CA3FC7B547282E87864D7EF564BC70A02CAAB5C78A605533F47C304`.
- Compact proof: PASS 28 themes at 592 and 500 px; 252 layout checks; overflow count 0; manifest SHA256 `0D6DEB7547BD218A96A5E264C12F2FFCF692E24453EE75BF3F8C7367D7928138`.
- Settings proof manifest SHA256: `5163A4D6CE85500A959DA8A72081CA8A67B993A4B8DDE52E18DE55E5BD2A588A`.
- Full local Build.ps1 -NoDownload: PASS; Main/Broker/Supervisor/Setup 0 warnings/errors; sensor windowless PE PASS; canonical text payload PASS; Setup /verify PASS 19/19; self-test PASS.
- Current candidate hashes from `artifacts/BUILD_MANIFEST.json`:
  - Main `B90211E86AAF0AB05C3B87E2D2056A59B2D6369FCAD0ADCC8072A513FCB489D9`
  - Broker `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833` (unchanged accepted sensor layer)
  - Supervisor `38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196` (unchanged accepted sensor layer)
  - Setup `3196986C62FC7D9A91500B0E3246D5640E6292D0ED1722F736505A4DD511B3CF`
- Preserved sensor architecture: `1.1.2+r21`; Setup verify explicitly reports `REUSE_ACCEPTED_1_1_2_R21`.
- External candidate evidence root: `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_v1.2.0-candidate-evidence`.
- Evidence-backed completed: source implementation, compile, full local build, Setup resource verify, self-test, hover guard regression, theme visual proof, compact overflow proof, Settings 8-page proof.
- Open gates: commit exact candidate; clean-clone determinism; SPDX SBOM against candidate commit; live installed-main runtime/UAT on the PC; exact-head GitHub CI. Public v1.2.0 publication is explicitly deferred and not authorized by this candidate state.
- Current blocker: none technical before commit/determinism. Publication remains an irreversible later gate.
- Exact next action: commit the candidate with this Brain/Knowledge state, run clean-clone determinism and SBOM on that exact commit, then perform a reversible user-level Main deployment while preserving the protected sensor layer and verify live Settings/hover/theme behavior.
