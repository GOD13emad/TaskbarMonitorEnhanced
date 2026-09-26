# Project Knowledge / Evidence Record — Taskbar Monitor Enhanced

## 2026-09-26 — R22 final identity/build/install/runtime acceptance

- Context: derive exact public v1.1.2 from accepted RC10 without behavioral drift.
- Claim/Decision: final identity behavior/build inputs are equivalent to accepted RC10 after approved identity-only normalization.
- Evidence/Source: docs/acceptance/R22_FINAL_IDENTITY_EQUIVALENCE.json; 7/7 covered; PASS.
- Confidence/Status: Confirmed / PASS.
- Reuse Targets: release notes, audit, Project Brain, future regression baseline.

- Claim/Decision: exact final build is deterministic and supply-chain evidence is complete locally.
- Evidence/Source: docs/acceptance/R22_FINAL_BUILD_ACCEPTANCE.json, RELEASE_MANIFEST_v1.1.2.json, SHA256SUMS_v1.1.2.txt, R21_SBOM.spdx.json.
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
