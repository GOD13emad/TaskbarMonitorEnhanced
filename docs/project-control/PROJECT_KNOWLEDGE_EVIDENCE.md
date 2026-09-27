# Project Knowledge / Evidence Record — Taskbar Monitor Enhanced

## 2026-09-26 — R22 final identity/build/install/runtime acceptance

- Context: derive exact public v1.1.2 from accepted RC10 without behavioral drift.
- Claim/Decision: final identity behavior/build inputs are equivalent to accepted RC10 after approved identity-only normalization.
- Evidence/Source: docs/acceptance/R22_FINAL_IDENTITY_EQUIVALENCE.json; 7/7 covered; PASS.
- Confidence/Status: Confirmed / PASS.
- Reuse Targets: release notes, audit, Project Brain, future regression baseline.

- Claim/Decision: exact final build is deterministic and supply-chain evidence is complete locally.
- Evidence/Source: docs/acceptance/archive/v1.1.2/FINAL_BUILD_ACCEPTANCE.json, docs/releases/archive/v1.1.2/RELEASE_MANIFEST.json, docs/releases/archive/v1.1.2/SHA256SUMS.txt, R21_SBOM.spdx.json.
- Confidence/Status: Confirmed / PASS.
- Provenance: source commit 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6.

- Claim/Decision: exact final v1.1.2 is installed and accepted on the validation workstation.
- Evidence/Source: r21_evidence/R22_FINAL_INSTALLED_IDENTITY.json SHA256 0528164956E250A4D112407FFA3BBC1EF880BA7A39D59356762C5C444537532D; Main/Broker/Supervisor exact hash match; config preserved; sensor log READY.
- Confidence/Status: Confirmed / PASS.
- Reuse Targets: release manifest, GitHub release evidence, final report.

- Claim/Decision: proportional final runtime regression is PASS; heavy RC10 watchdog/S3 gates are inherited rather than rerun because final behavior equivalence is PASS.
- Evidence/Source: r21_evidence/R22_FINAL_RUNTIME_REGRESSION_R2.json SHA256 7F53FEF9BCFD81D5B7862CB30DAFAAF7F659937013D6EA895AB89182023C30D7 plus accepted RC10 precursor.
- Confidence/Status: Confirmed / PASS.
- Limitation: final local runtime validation is on the current Windows 11 validation workstation; it is not a claim of all-hardware compatibility.

- Failure/Root Cause/Prevention: first final-runtime harness reported StateAgeSec about 12600 s while every structural/health flag passed. ConvertFrom-Json had materialized trailing-Z JSON timestamps as DateTime; reparsing through a string/local path introduced the workstation +03:30 offset. Prevention is PowerShell 7.5+ ConvertFrom-Json -DateKind String followed by round-trip DateTimeOffset parsing.
- Method Source: Microsoft Learn ConvertFrom-Json documentation for PowerShell 7.5/7.6, DateKind String and trailing-Z UTC behavior.
- Confidence/Status: Confirmed harness false negative / prevention regression PASS.
- Reuse Targets: all future JSON timestamp harnesses in this project.

- Open Gate: GitHub provenance/SBOM attestation and immutable v1.1.2 Stable/Latest publication remain PENDING. No public-release PASS is claimed yet.

## 2026-09-26 — GitHub run 36244394685 shallow-checkout failure

- Date/Context: first exact-final GitHub attestation push at control commit 483367af265eae8bd6043c11570f8f6be58531de.
- Claim/Decision: failure is in CI checkout depth, not in product build/runtime.
- Evidence/Source: GitHub job 108410742894; Checkout and .NET setup succeeded; Git whitespace check failed because HEAD^ was unavailable; build/determinism/SBOM/attestation/upload were skipped.
- Root Cause: r21-ci.yml used actions/checkout default fetch-depth 1 but executed git diff --check HEAD^.
- External Method Evidence: official actions/checkout v7 documentation prescribes fetch-depth: 2 for HEAD^; action input documentation states default fetch-depth is 1.
- Prevention/Guard: add only fetch-depth: 2 to the pinned Checkout step; fetch-depth 0 is unnecessary.
- Regression: fresh exact-commit run; require every CI step PASS and artifact hashes equal accepted final hashes.
- Confidence/Status: Confirmed root cause / fix applied / regression pending.
- Reuse Targets: CI design, release audit, Project Brain, future workflow review.

## 2026-09-26 — GitHub exact-final attestation and artifact equivalence

- Date/Context: release/v1.1.2-final, fresh GitHub run 36244774522 at commit aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0.
- Claim/Decision: GitHub CI and supply-chain attestation are accepted for the exact release authority commit.
- Evidence/Source: GitHub job 108411834610 success; all required build/determinism/SPDX/provenance/Setup-SBOM/upload steps succeeded; artifact 10907450490 digest sha256:09cd3846e054007b736be16ffee4c9865de923526940ae474b43d20bdf099dd6.
- Artifact verification: Main, Broker, Supervisor and Setup SHA256 values are byte-identical to the locally accepted finals.
- SBOM result: raw GitHub SPDX SHA256 1C3D36B725BAC33A61BE9D886C4C6AA6E78ECAE58D5815DDA13E4F68229B1B9B differs from local B324745F6041FA8E8C8FA888977B40B41100B787C6A8E087ED80EB23AC148578. Generator audit proved the volatile fields are documentNamespace from Git HEAD and creationInfo.created from build-manifest time. Normalizing only those fields yields identical BFBB7FB00FF3C8DD9ED26DBD17C0E3CAED5B4F666BE5373E7C329549AEEB7BAA.
- Decision rationale: release tag will target aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0, the exact GitHub-attested commit. Subsequent documentation/control commits must not move the immutable tag.
- Initial failure: run 36244394685 failed before build because checkout depth 1 could not resolve HEAD^. Prevention: pinned checkout retained, fetch-depth 2 added, fresh run 36244774522 PASS.
- Confidence/Status: Confirmed / PASS / publication-ready.
- Reuse Targets: public release notes, release manifest, audit report, Project Brain, future CI/release design.
- Limitation: runtime acceptance is on the validated Windows 11 workstation and is not a claim of universal hardware compatibility.
## 2026-09-26 — v1.1.2 immutable public release accepted

- Date/Context: final publication and post-verification of Taskbar Monitor Enhanced v1.1.2.
- Claim/Decision: v1.1.2 is the accepted immutable public Stable/Latest release.
- Evidence/Source: tag v1.1.2 resolves to aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0; release https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.2 is non-draft/non-prerelease; default latest release is v1.1.2.
- Asset verification: 8/8 assets uploaded; GitHub asset digest equals local SHA256 for every asset; GitHub size equals local size for every asset.
- Setup artifact: SHA256 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB.
- Release evidence SHA256: E1E87345C6AC430420DBE56FF7B5150BA4ED71AE0E4380919F41D11334DE95FC.
- Authority model: behavior/build authority is 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6; immutable release/tag authority is aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0; branch closeout may advance but must never move tag v1.1.2.
- CI lesson: shallow checkout failure was prevented with minimum sufficient fetch-depth 2 because the workflow uses HEAD^; fresh exact-commit CI subsequently passed.
- SBOM lesson: compare document-instance fields separately from substantive package/file/dependency payload when generator intentionally embeds commit/time; normalized semantic equivalence was PASS.
- Confidence/Status: Confirmed / PASS / FINAL.
- Reuse Targets: future release checklist, CI design, audit/report, user-facing verification instructions.
- Limitation: runtime acceptance applies to the validated Windows 11 workstation; universal hardware compatibility remains outside this release claim.
## 2026-09-26 — development Authenticode signing identity and pipeline

- Context: post-v1.1.2 maintenance. Immutable public v1.1.2 must not be modified because Authenticode changes executable bytes/hashes.
- Identity: self-signed DEVELOPMENT Code Signing certificate, subject CN=Taskbar Monitor Enhanced Development Code Signing, thumbprint 4673165CCB579F868EFE5F52FCDA761780F49989, RSA/sha256RSA, Code Signing EKU 1.3.6.1.5.5.7.3.3.
- Security handling: private key remains in Cert:\CurrentUser\My, was not exported, and no PFX/P12/PVK/KEY material exists in project files. Only the public .cer is committed.
- Tooling: build/signing/Sign-Authenticode.ps1 uses Windows SDK signtool with SHA256 and optional RFC3161 timestamping; Verify-Authenticode.ps1 validates signed state, signer thumbprint, hash integrity and trust state.
- Probe evidence: unsigned Setup copy hash 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB; signed DEVELOPMENT probe hash 65168AD41EAA0C5B562FACE9E3DDEBACDA9EBC38606C94C42D4E9C55AA6AAFCD.
- Verification: exact signer thumbprint matched; unsigned file rejected; tampered signed copy rejected.
- Trust interpretation: Get-AuthenticodeSignature returns UnknownError with message that the chain terminates in an untrusted root. This is the expected result for the self-signed development certificate and is not public Publisher trust.
- Immutability regression: public tag v1.1.2 remains aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0 and release Setup digest remains sha256:25744a0a0f78b787a5fc3601577748b80353adc9dafb9fe91a111a53c56216fb.
- Production gate: obtain CA-issued Code Signing certificate or approved managed signing identity; sign/timestamp a NEW release version; then regenerate signed hashes, SBOM, provenance and runtime acceptance.
- Confidence/Status: Confirmed / DEVELOPMENT SIGNING PIPELINE PASS / PUBLIC TRUST PENDING.

## 2026-09-26 — R24 SignPath Foundation public-trust readiness

- Context: user authorized full completion of public code signing after the R23 self-signed development Authenticode pipeline passed.
- Provider research: SignPath Foundation publishes a free open-source signing route with repository ownership, OSI-approved licensing, maintained/released documentation, visible Code signing policy, privacy/uninstall disclosure, MFA, author/reviewer/approver roles, manual approval, and verifiable source-built artifacts. Microsoft Artifact Signing is geographically restricted and therefore was not treated as the universal primary route.
- Repository evidence: GitHub repository is public; maintainer account `GOD13emad` reports two-factor authentication enabled.
- License correction: root LICENSE had only a short notice while README/CONTRIBUTING already declared GPL v3-or-later. It was replaced with the already-accepted full GNU GPL v3 license text from local project evidence; declared license family remains GPL-3.0-or-later.
- Policy/readiness docs: README, CODE_SIGNING.md, DOWNLOAD.md and PRIVACY.md now describe the current immutable v1.1.2 baseline, exact SignPath provider attribution, team roles, manual signing approval, source/build provenance gates, privacy/update behavior and uninstall route without claiming external acceptance.
- Actual updater evidence: default auto-check uses HTTPS GET to `https://api.github.com/repos/GOD13emad/TaskbarMonitorEnhanced/releases/latest`; setting can disable automatic checks; installer download occurs only after explicit Download & Install confirmation and hash/release checks.
- Actual PE metadata evidence: Main, Broker, Supervisor and Setup all PASS ProductName `Taskbar Monitor Enhanced`, ProductVersion `1.1.2+r21`, FileVersion `1.1.2.0`, populated CompanyName and FileDescription. Their hashes remain the accepted final hashes.
- Actual uninstall evidence: installer creates `%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe` and registers DisplayName, DisplayVersion, Publisher, InstallLocation, UninstallString and QuietUninstallString in the per-user Windows uninstall key. README/DOWNLOAD expose Windows Installed apps and direct uninstaller instructions.
- Application surface evidence: official SignPath apply page is a HubSpot embedded form using portal `145110231` and form `bf62807d-bb72-4e45-9bde-1f3a53ba2472`; page loaded in Chrome and Tagline/Description fields were visibly observed.
- Submission gate: browser input was rejected by Remote Commander with `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`. This is an enforced platform interaction gate; chat authorization cannot override it. Application is therefore NOT SUBMITTED.
- Ready packet: `docs/security/SIGNPATH_APPLICATION_PACKET.json` status `READY_TO_SUBMIT_DIRECT_USER_GUI_ACTION_REQUIRED`, with main-branch policy/privacy URLs, verified GitHub 2FA fact, product metadata PASS, uninstall PASS, form identifiers and submitted=false.
- Immutability: v1.1.2 tag remains `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`; Setup SHA256 remains `25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB`.
- Confidence/Status: Repository readiness Confirmed/PASS; external SignPath application submission BLOCKED by direct-user GUI gate; SignPath Foundation acceptance/public trust PENDING.
- Prevention: never substitute self-signed trust, install a development root to manufacture a PASS, rewrite immutable v1.1.2, or invent/accept external identity/legal fields. Public signing must start on a new release after external provider acceptance.

## 2026-09-26 — R24 default-branch publication and CI

- Readiness authority: commit `b6c13838624e99d1d6ba4811b295834e22e45947`.
- Default branch prestate: `main` at `ce657da44cb68590c73fafb4030a0abddb428685`; ancestry check proved it was an ancestor of the readiness authority.
- Mutation: ordinary non-force fast-forward `git push origin HEAD:main`; poststate `origin/main` and `origin/maintenance/signpath-readiness` both equal `b6c13838624e99d1d6ba4811b295834e22e45947`.
- GitHub Actions run `36250864888` at exact head SHA `b6c13838624e99d1d6ba4811b295834e22e45947`: completed success.
- CI evidence: every step in job `build` succeeded, including reproducible build, deterministic clean-clone verification, SPDX 2.3 SBOM, binary provenance attestation, Setup SBOM attestation and evidence upload.
- Release immutability remained PASS after main publication: tag `v1.1.2` -> `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`; public Setup digest remains `sha256:25744a0a0f78b787a5fc3601577748b80353adc9dafb9fe91a111a53c56216fb`.
- Decision: repository-side prerequisites for SignPath Foundation application are accepted. This is not provider acceptance and not a public-trust signature.
- External gate: official SignPath HubSpot application is loaded but Remote Commander input is blocked by `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`; application remains NOT SUBMITTED.
- Confidence/Status: Confirmed / repository readiness PASS / default branch PASS / CI PASS / external provider submission PENDING direct-user GUI action.

## 2026-09-26 — SignPath exact form schema and final human gate

- Official application page: `https://signpath.org/apply.html`.
- HubSpot form: EU1 portal `145110231`, form `bf62807d-bb72-4e45-9bde-1f3a53ba2472`.
- Public render definition: `https://forms-eu1.hsforms.com/embed/v4/render-definition/145110231/bf62807d-bb72-4e45-9bde-1f3a53ba2472`; SHA256 `bf122cf482f6887667fb30661e3be8bafdcdac0c15c05c5a79a72f5337aeb570`.
- Required factual fields: Project Name, Repository URL, Homepage URL, Tagline, Description, Reputation, Build System, First Name, Last Name, Email, Primary Discovery Channel.
- Optional factual fields: Download URL, Privacy Policy URL, Wikipedia URL, Maintainer Type, Company Name, exact discovery source.
- Prepared factual values are stored in `docs/security/SIGNPATH_APPLICATION_PACKET.json`.
- Reputation measurement for Taskbar Monitor Enhanced at observation time: 0 GitHub stars, 0 forks, 0 subscribers, 0 v1.1.2 asset downloads. The application must not imply established adoption.
- Declared GPL upstream `leandrosa81/taskbar-monitor`: 540 stars, 42 forks, 13 subscribers. These values are upstream heritage only, not adoption metrics for Taskbar Monitor Enhanced.
- Required external consent #1: agreement to SignPath Foundation Code of Conduct and understanding that certificates are issued in SignPath Foundation's name and can be revoked if terms are violated.
- Required external consent #2: agreement to allow SignPath to store/process personal data.
- Optional marketing communication checkbox is not authorized and remains unchecked.
- reCAPTCHA2 is present and is a human anti-bot gate. Programmatic solution or bypass is forbidden.
- User explicitly authorized mouse/keyboard for this current task. Plugin permission is already Allow all actions. However, this ChatGPT session's exposed `gui_session_begin` contract only accepts `ttlSeconds` and returns observe mode; takeover parameters used by the server's newer contract are absent. Workflow GUI takeover is independently rejected with `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`.
- The official application and Code of Conduct pages have been opened on the desktop and the application page was reopened last.
- Security boundary: no raw local MCP, Windows SendInput, UIAutomation, CDP or equivalent injection is used to bypass the connector's takeover gate; no CAPTCHA bypass is attempted.
- Status: repository readiness PASS; application payload READY; submission NOT SUBMITTED; explicit first-person consents + reCAPTCHA remain the only legitimate human gates.

## 2026-09-27 — v1.1.3 startup resilience and visual requalification

- Observed failure mechanism: `StartWithWindows=true` was present in config and StartupApproved was enabled, but the actual HKCU Run registration for Main was missing after a real power-loss/restart cycle. Sensor Supervisor still launched independently. Cause of the Run-value deletion is not proven.
- Prevention architecture: retain HKCU Run as primary launch and add a current-user Startup-folder shortcut as a privilege-independent recovery path. Recovery uses `--startup-recovery`, waits up to 12 seconds for the primary process, exits early on primary detection, otherwise starts normally. Existing mutex prevents duplicate long-running Main instances.
- A Scheduled Task fallback was considered but rejected after non-elevated creation of an ONLOGON task returned Access Denied on the validation PC.
- Mutual self-heal is live-proven in both directions. StartWithWindows=false removes both registrations and original true state was restored after the negative test.
- Candidate code/visual authority: commit `bcbd8f8e8861e4e4a83350699214f1bb83b1132e`.
- Main v1.1.3 hash: `74E7725E3C3911EFEDEC1181C21AF07571C9A22CD758EE50E06EA1373DAB7317`.
- Setup v1.1.3 hash: `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`.
- Existing protected Broker/Supervisor hashes remain `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833` and `38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196`; sensor layer remains 1.1.2+r21 / READY.
- Deterministic clean-clone build at the candidate commit: PASS. SPDX 2.3 SBOM SHA256 `651057410EB57090E1D7ED5EB9522AB8B40284D484CAB0A1C9ADA4DC1833E192`.
- Theme proof: PASS, 14/14 themes, 30 live samples, no synthetic metrics. Compact proof: PASS for 592 and 500 px, zero recorded overflow. Theme/compact manifests and contact sheets are now repository documentation.
- v1.1.2 immutability regression remains PASS: tag `aab35e5e...`, Setup `25744A0A...`.
- Public trust: no SignPath/CA signature is claimed. Repository readiness and application preparation are separate from actual provider acceptance.
- Status: Confirmed / LOCAL ACCEPTANCE PASS / GitHub CI and immutable publication pending.

## 2026-09-27 — v1.1.3 public release evidence

- Public release `v1.1.3` is accepted at exact tag commit `fa8c75d0b59343ccb7eae86320a351e3b4064c48` and is GitHub Latest.
- Two exact-head GitHub Actions runs passed: main `36311195266` and release branch `36311191121`. Downloaded CI Main/Broker/Supervisor/Setup binaries matched local accepted hashes exactly.
- Release upload integrity is 7/7 exact by GitHub asset digest and size. Installer SHA256 is `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`; source ZIP SHA256 is `D6B3B99AEEE7B3E816D94ECE6C41F25FDF338833923AFB08A3A4B29907F227CA`.
- The published local SPDX document and exact-head CI SPDX document have different raw hashes because their generated namespace/time fields differ; normalized semantic content (packages, file hashes, relationships and document identity fields excluding generated namespace/time) is identical with SHA256 `2e5375bfa63263162953f2c2a7a8c98b7cc4729bbb871cc7aad9f90b3c4238a1`. Treat exact-head CI attestation as source-origin evidence and the published SBOM as release-asset inventory evidence.
- Startup-resilience fault injection and all-theme/compact proof remain accepted. Protected sensor binaries are unchanged from accepted `1.1.2+r21`.
- v1.1.3 remains unsigned for public-trust purposes unless an independently verifiable trusted Authenticode signature is later proven; do not infer signing from SignPath readiness.
- v1.1.2 remains immutable and unchanged.
- Reuse target: future release checklist, startup regression suite, public-release post-verification, SBOM raw-vs-semantic equivalence handling.

## 2026-09-27 — GitHub Actions upload-artifact Node 24 maintenance

- Official actions/upload-artifact v7.0.1 resolves to commit `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` and declares `using: node24`.
- The repository's previous pin `ea165f8d65b6e75b540449e92b4886f43607fa02` triggered a GitHub deprecation annotation because it declared Node.js 20, although GitHub forced execution under Node.js 24 and CI passed.
- Maintenance changes only `.github/workflows/r21-ci.yml`; v1.1.3 release bytes/tag are intentionally untouched.
- Validation pending exact-main workflow at the time of this entry.

### Validation result

- Commit `1fabcfc420fa996cc2e7e44a4182d2569ddba007` → GitHub Actions run `36311950294`: SUCCESS.
- All R21 gates passed and the earlier Node.js 20 deprecation annotation did not recur.
- Decision: retain `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` (v7.0.1, Node.js 24) as the current pinned upload action.


## 2026-09-27 — repository hygiene / deduplication rules

- Keep one canonical Git source workspace. Use short-lived worktrees only when needed, then remove them after evidence is committed/preserved.
- Keep immutable public release history in Git tags + GitHub Releases; merged audit/release/maintenance branches should not be kept indefinitely.
- Do not keep superseded draft RC releases after a stable release is accepted.
- Preserve irreplaceable hardware/runtime evidence by moving it to a single external archive; delete rebuildable output and duplicate runner/download stores.
- Keep dependency caches centrally and reuse them through an ignored local junction rather than downloading the same pinned binaries repeatedly.
- Pinned dependency hashes must be verified whenever a central cache is reattached.
- Historical unmerged branches with unique commits should not be deleted merely for cosmetic cleanup; preserve until their lineage is intentionally reconciled or archived.
- Release tags/assets remain immutable during repository cleanup.


### R26 validation result

- Repository-hygiene commit `f671bb4aee4dadc2f418e95c21471faa108322e7` passed GitHub Actions run `36313319634`.
- Central dependency-cache reuse was proven locally with no download; final Setup binary hash remained identical to the accepted v1.1.3 hash.
- After cleanup, only local `main` remains; remote unmerged historical lineage is preserved rather than destructively deleted.
- Superseded RC draft releases and branch-specific RC self-hosted workflows were removed from active GitHub surfaces.


## 2026-09-27 — GitHub README blank-image root cause

- `docs/screenshots/desktops/desktop-dark-minimal.webp` was not merely a browser/GitHub loading issue. The stored WebP was truncated: RIFF-declared total size 62,952 bytes vs actual Git object size 15,008 bytes.
- A broken media file can cause GitHub README to leave a large empty render area even when the Markdown path itself exists.
- Professional handling: remove invalid media, stop describing it as evidence, replace it with verified renderer output, and structurally validate all remaining media/link targets.
- Historical RC manifests/checksums should be preserved outside repository root under an explicit acceptance/archive path rather than deleted when they remain useful for auditability.


## 2026-09-27 — professional repository information architecture

- Public repository roots should contain current project entry points and standard policy files, not every historical release artifact.
- Version belongs primarily in directory hierarchy for archived records; filenames inside version directories should remain generic where practical.
- Preserve Git history with `git mv` rather than delete/recreate when reorganizing accepted evidence.
- Keep immutable historical JSON evidence semantically intact even if its physical repository path changes; document archive location externally instead of rewriting fields that describe the original release state.
- Project-control knowledge is documentation and belongs under `docs/project-control/`, not in a special root folder once the project is public and stabilized.


## 2026-09-27 — immutable installer docs vs mutable public README

- If an installer embeds the repository README, post-release documentation edits can silently produce a different installer with the same public version even when executable code is unchanged.
- Prevention: freeze release-embedded documentation as a version-scoped payload snapshot and let the public landing-page README evolve independently.
- For v1.1.3, the accepted embedded README resource was extracted directly from the immutable published Setup and stored as `docs/releases/v1.1.3/INSTALLER_README.txt`; the build maps it back to payload logical name `README.md`.
- This restored exact Setup reproducibility while allowing GitHub presentation cleanup.
- Active tooling should use stable generic names (`Build.ps1`, `ci.yml`, `BUILD_MANIFEST.json`, `SBOM.spdx.json`); release/revision identifiers belong in manifest content and historical evidence rather than active filenames.


### Repository-structure cleanup validation

- Commit `80f9c95afbc419bf49384d16be6f9a63d09a05d4` passed exact-head GitHub Actions run `36315722461`.
- CI `build-evidence` artifact id `10929984813` used generic current filenames and reproduced the immutable v1.1.3 Setup hash exactly.
- GitHub API verification confirmed the public root, docs top level, workflow list, and build directory no longer expose obsolete release-candidate/versioned artifact filenames as active files.
- Decision: use version directories + generic filenames for historical records, and stable generic filenames for active tooling; keep revision/version identifiers inside immutable evidence or manifest content only when technically meaningful.


## 2026-09-27 — final public-tree cleanup rule

- For a stabilized public repository, do not duplicate every historical release/RC artifact on current `main`; immutable tags, Git history, GitHub Releases, and an external evidence archive are sufficient historical authorities.
- Before deleting historical tracked records from the active branch, preserve a hashed external copy when local audit continuity matters.
- Keep current-release evidence in version directories with generic filenames; keep active tooling filenames version-neutral.
- Public docs should link to GitHub Releases/tags for old versions rather than retaining local archive trees that clutter browsing.
- Validation after structural cleanup must include link integrity, deterministic build, exact installer hash regression, and exact-head CI.


### Final cleanup validation

- `ce94e70a170abdfeb6b5c4491c9cebd7d029639c` passed GitHub Actions run `36317306947`.
- Active main no longer carries historical archive trees or old RC/revision/versioned artifact filenames.
- Historical unmerged branch lineage was preserved in a verified complete Git bundle before branch deletion; bundle SHA256 is `736C13A830F6440D8BF972A39556798D0028ABE1442F739AA00E4FDFD3F18948`.
- Remote branch policy after stabilization: retain only `main`; preserve exceptional unmerged history externally before deleting stale public branches.


## 2026-09-27 — v1.2.0 modern Settings / hover guard / 28-theme candidate

### Record A — Settings-open hover flyout root cause and prevention
- Date/Context: 2026-09-27, user reported that hover explanations/details open while Settings is visible and remain open.
- Claim/Decision: CONFIRMED root cause is an interaction-state gap: opening Settings stopped the hover watchdog timer, while overlay MouseEnter/MouseMove continued to invoke the flyout-opening path.
- Evidence/Source: source audit of `OverlayForm.OpenSettings`, `HandleHardwareHover`, `HoverWatchdog`; deterministic `--hoverguardproof` result `PASS MOVE_SUPPRESSED=TRUE WATCHDOG_SUPPRESSED=TRUE FLYOUT_HIDDEN=TRUE`.
- Prevention: guard both hover resolution and watchdog when Settings exists; hide active flyout and reset hover identity state. Preserve regression CLI.
- Confidence/Status: CONFIRMED / PASS.
- Reuse Targets: maintenance regression, release acceptance, future hover/flyout changes.
- Provenance: `src/TaskbarMonitorEnhanced.cs`; candidate source SHA256 after identity update `83653DB76846C10A62C030961A0CB5295ECADE34B46327935B08459941BC4EF4`.

### Record B — Settings architecture choice
- Date/Context: 2026-09-27, professional/modern Settings redesign.
- Claim/Decision: preserve WinForms and the accepted runtime/sensor architecture; modernize presentation using a left navigation shell, page header/descriptions, constrained content, grouped surfaces, consistent spacing/controls, and persistent actions.
- Method evidence: Microsoft Windows app settings guidance recommends simple grouped settings, readable constrained-width layouts and SettingsCard-style header/description/action composition; Microsoft NavigationView guidance supports clear left navigation with a page header and consistent content margins.
- Sources:
  - https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings
  - https://learn.microsoft.com/en-us/windows/apps/design/controls/navigationview
  - https://learn.microsoft.com/en-us/windows/apps/design/basics/navigation-basics
- Trade-off: no WinUI migration. This avoids a new framework/deployment dependency and regression surface while delivering the requested UX within the existing proven desktop architecture.
- Confidence/Status: CONFIRMED design choice / visual proof PASS 8 pages.
- Reuse Targets: UI design rationale, release notes, maintenance.
- Provenance: `--settingsproof`; evidence root `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_v1.2.0-candidate-evidence\settings`; manifest SHA256 `5163A4D6CE85500A959DA8A72081CA8A67B993A4B8DDE52E18DE55E5BD2A588A`.

### Record C — visual-proof false-positive failure and guard
- Date/Context: 2026-09-27 during Settings visual qualification.
- Failure: initial Settings proof reported output files but screenshots were blank because the Form had only been CreateControl-initialized and never entered a real shown/painted WinForms state.
- Root Cause: artifact existence was incorrectly treated as rendering evidence.
- Prevention/Guard: proof harness now shows the form off-screen, pumps Windows messages/layout/paint, captures after rendering, and visual review remains required for representative pages.
- Regression: all 8 current Settings pages render nonblank after the harness correction.
- Confidence/Status: CONFIRMED failure → prevention implemented.
- Reuse Targets: all future GUI screenshot/proof harnesses.

### Record D — tooltip/flyout behavior benchmark
- Method evidence: Microsoft documents that hover tooltips disappear when pointer/focus stops hovering and advises using tooltips sparingly for supplemental information.
- Source: https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/tooltips
- Decision: a Settings-open flyout that stays open is not accepted behavior; suppression while a modal/configuration experience is active is the minimum sufficient control.
- Confidence/Status: CONFIRMED method basis.

### Record E — 28-theme renderer architecture
- Date/Context: 2026-09-27, request to roughly double theme count with high quality and meaningful differentiation.
- Claim/Decision: expand from 14 to 28 themes using seven reusable renderer families plus distinct palettes, rather than adding 14 near-duplicate custom renderers.
- New families: aurora, luxe, zen, synth, matrix, paper, industrial.
- Benefit/Trade-off: visually distinct geometry/background language with bounded code growth and shared regression paths.
- Evidence: live-data ThemeProof 28/28; compact 592/500 proof; representative visual review across every new renderer family.
- Theme manifest: `6791C6C44CA3FC7B547282E87864D7EF564BC70A02CAAB5C78A605533F47C304`.
- Compact manifest: `0D6DEB7547BD218A96A5E264C12F2FFCF692E24453EE75BF3F8C7367D7928138`; 252 layout checks, 0 overflow.
- Confidence/Status: CONFIRMED / PASS for renderer and layout proof.
- Reuse Targets: release gallery, theme documentation, regression suite.
- Provenance: `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_v1.2.0-candidate-evidence`.

### Record F — release identity boundary
- Decision: use `v1.2.0` candidate identity because the scope adds substantial user-facing UI/theme capability; never rebuild or retag immutable public v1.1.3 as if it contained these changes.
- Candidate: `1.2.0 / V1_2_0_R01_MODERN_SETTINGS_THEME_LIBRARY / 1.2.0+r01`.
- Sensor layer: unchanged `1.1.2+r21`.
- Current status: local build/visual/functional proof PASS; clean-clone determinism, candidate SBOM, live installed-main validation and exact-head GitHub CI remain open at this record point.
- Confidence/Status: CONFIRMED boundary / publication NOT YET ACCEPTED.
- Reuse Targets: release engineering and provenance.


## 2026-09-27 — installed v1.2.0 identity and gallery acceptance

### Record G — installed candidate identity
- Claim: installed Main and Uninstaller exactly match the locally qualified v1.2.0 candidate.
- Evidence: Main SHA256 `B90211E86AAF0AB05C3B87E2D2056A59B2D6369FCAD0ADCC8072A513FCB489D9`; Uninstall/Setup SHA256 `3196986C62FC7D9A91500B0E3246D5640E6292D0ED1722F736505A4DD511B3CF`; registry DisplayVersion `1.2.0`.
- Sensor state: READY, `1.1.2+r21`, exact Broker/Supervisor hashes preserved.
- Runtime evidence: health probe PASS, resilience STABLE, CPU/GPU/storage transport and data available.
- Confidence/Status: CONFIRMED / installed technical validation PASS.
- Reuse Targets: final acceptance, release notes, support diagnostics.
- Provenance: `%LOCALAPPDATA%\TaskbarMonitorEnhanced\install_state.json`, uninstall registry, installed binary hashes.

### Record H — GUI interaction boundary
- Observation: Remote Commander provided screenshot observation but rejected direct mouse interaction with `GUI_TAKEOVER_NOT_AUTHORIZED`.
- Decision: do not bypass connector policy using alternate input injection.
- Validation substitute: real WinForms Settings form is shown off-screen and painted before deterministic capture; all 8 pages reviewed. Installed `--hoverguardproof` directly validates the reported Settings-open flyout failure path.
- Status: foreground manual mouse UAT MISSING by tool authority; automated UI/behavior evidence PASS.
- Reuse Targets: final report and release-risk statement.

### Record I — current gallery/public documentation
- Evidence: `docs/screenshots/themes` now contains 28 full-width live-data theme proofs + manifest/contact sheet; `docs/screenshots/compact` contains 56 592/500px proofs + manifest/contact sheets; `docs/screenshots/settings` contains 8 Settings proofs + manifest/contact sheet.
- Visual review: PASS for representative and contact-sheet inspection.
- Markdown link audit: 38 files, 0 broken relative links.
- Decision: current README/DOWNLOAD/release/acceptance docs distinguish v1.2.0 candidate from immutable public v1.1.3 until exact-head CI/publication completes.
- Confidence/Status: CONFIRMED / documentation ready for CI gate.


### Record J — translated release-status false-claim prevention
- Date/Context: 2026-09-27, pre-PR repository audit.
- Observation: 11 i18n README files changed together to candidate 1.2.0/28 themes, but their validation sentence also changed from historical 1.0.0 lifecycle validation to an unsupported v1.2.0 lifecycle claim.
- Decision: do not accept the unsupported upgrade/full-uninstall/clean-install claim for v1.2.0.
- Evidence boundary: v1.2.0 currently has local full build, deterministic rebuild, visual proofs, installed identity/runtime health and preserved protected-sensor evidence; exact-head GitHub CI/publication remain open at this record point.
- Prevention: translated status text now explicitly distinguishes source candidate 1.2.0 from public release v1.1.3 and names only proven v1.2.0 gates.
- Confidence/Status: CONFIRMED / false claim removed before PR.
- Reuse Targets: release documentation, localization maintenance, evidence-boundary reviews.
- Provenance: `docs/i18n/README.{ar,bn,es,fa,fr,hi,id,pt,ru,ur,zh-CN}.md`; pre-commit diff audit.

## 2026-09-27 — v1.2.0 public publication closure

### Record K — immutable public release authority
- Date/Context: 2026-09-27 final publication after PR and main exact-head CI.
- Claim: v1.2.0 is the current public immutable Latest release.
- Evidence: GitHub release id `397665644`; tag `v1.2.0`; annotated tag object `5f4c12c2dd8ee2624e93d31ff8672894f5701311`; peeled commit `84d22fae6638b21683ea828e86517d100ced1654`; published `2026-09-27T13:45:13Z`; state non-draft, non-prerelease, immutable, Latest.
- Public URL: `https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.2.0`.
- Confidence/Status: CONFIRMED / FINAL_PUBLIC_RELEASE_ACCEPTED.
- Reuse Targets: current authority, updater/release documentation, support, provenance.

### Record L — release asset digest closure
- Pre-publication staging contained exactly seven release assets.
- Setup pre-publication resource verify: PASS 19/19.
- `SHA256SUMS_v1.2.0.txt`: 6/6 referenced assets matched before upload.
- Draft GitHub release comparison: 7 local assets vs 7 remote assets; 0 missing; 0 extra; 0 size/digest mismatches.
- Post-publication GitHub audit: all seven assets remain state=uploaded with the same digests.
- Setup: `3196986c62fc7d9a91500b0e3246d5640e6292d0ed1722f736505a4dd511b3cf`.
- Source ZIP: `d5996a44ceb991dde019f00592128596dcadf555d0e4c4217c873699e08f5ee9`.
- SHA256SUMS: `d2f5aa6ba345081f2977959c522bb206d801543689bcb82b99d129b086a3ab16`.
- Release manifest: `2f3f7c8e001092c8cf5e439ba18dbd62a740e024a75c2d0c81379e20e47a54bd`.
- SBOM: `09e38d790aea054ecde580eba3515f285fe72f05758384f83a46d1b181a5a8ec`.
- Acceptance asset: `833f67a9ca7a236197353b34481e0c1004a75dfc3f98843a8628ef728ff52d86`.
- Release notes asset: `02ed6e71802ca0fdc819693ea713a6a02af234443257dcbe6f0fc156d2256822`.
- Confidence/Status: CONFIRMED / PASS_7_OF_7.
- Provenance: external staging root `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_v1.2.0-publication\assets` and GitHub release asset digests.

### Record M — exact-main CI equivalence without artifact re-download
- Main run `36322557793` on exact release commit `84d22fae6638b21683ea828e86517d100ced1654` completed SUCCESS.
- CI passed reproducible build, clean-clone determinism, SPDX generation, binary provenance attestation, Setup SBOM attestation and evidence upload.
- GitHub job log printed the authoritative build manifest and confirmed exact equality of all four binary hashes with local/release values.
- A direct CI artifact ZIP download was attempted but stalled on the PC network and wrote no bytes. After bounded observation it was terminated; no blind retry loop was used.
- Decision: artifact download is not a necessary additional gate once authoritative CI log manifest + provenance/SBOM attestation + local deterministic build establish the same binary hashes.
- Confidence/Status: CONFIRMED / minimum-sufficient release evidence satisfied.
- Reuse Targets: future release process under constrained network conditions.

### Record N — post-publication immutability rule
- Decision: do not edit `docs/releases/v1.2.0/RELEASE_NOTES.md` or `docs/releases/v1.2.0/INSTALLER_README.txt` after publication because they are release payload/build inputs.
- Rationale: changing embedded release payload text after publication can change rebuilt Setup bytes and break release reproducibility/immutability.
- Current public status updates belong in public indexes, acceptance, Brain/Knowledge and current README/DOWNLOAD files instead.
- Confidence/Status: CONFIRMED preventive control.
- Reuse Targets: all future immutable releases.

### Record O — merged feature-branch preservation and cleanup
- Date/Context: 2026-09-27, after immutable v1.2.0 publication.
- Risk: squash merge means the feature branch tip is not a direct ancestor of main; deleting it without an independent record would reduce convenient recoverability of intermediate commits.
- Prevention: create and verify a complete Git bundle before branch deletion.
- Bundle: `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_v1.2.0-publication\feature-modern-settings-theme-library.bundle`.
- Bundled tip: `2e3f953b402e2b512096fcd59533184739127f91`.
- SHA256: `E13DC2AC746F85D6B64B28B3CB7099A1EF5244EBFCD16E991A817FAAC1A87E66`.
- Verification: `git bundle verify` PASS / complete history.
- Remote and local feature branch deletion then completed and absence was verified.
- Confidence/Status: CONFIRMED / PASS.
- Reuse Targets: repository hygiene, account transfer, historical recovery.

### Record P — post-publication exact-head regression and final repository invariant
- Date/Context: 2026-09-27, final repository closeout after v1.2.0 publication.
- Post-publication documentation commit: `60db90069c8eae74cddcb5d953db1f99adab1229`.
- Exact-head GitHub Actions run: `36324665609` = SUCCESS.
- Reproducible build, deterministic clean-clone, SPDX generation, binary provenance attestation and Setup SBOM attestation all passed.
- Printed CI manifest reproduced the exact immutable v1.2.0 binary hashes for Main/Broker/Supervisor/Setup.
- Release invariant audit: `v1.2.0` remains public, non-draft, non-prerelease, immutable and Latest with seven assets; tag still peels to `84d22fae6638b21683ea828e86517d100ced1654`.
- Repository invariant audit: remote branch surface contains only `main`; local worktree was clean at audit time.
- Conclusion: documentation closeout did not perturb release binaries or immutable release authority.
- Confidence/Status: CONFIRMED / PASS / FINAL.
- Reuse Targets: future release baseline, regression authority, repository maintenance.
