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
