# R80 — SignPath Foundation onboarding and signed Installer release handoff

**Status:** Technical artifact assembly is tested, but signing-provider acceptance, legal review, signed files and actual G13/G14/G16 validation remain **OPEN**. This document is not a release approval.

## Authoritative baseline

- Current public immutable release: [v1.6.0](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.6.0). Do not mutate or reupload this release.
- Accepted v1.7 candidate: `bfce93b0bb1c65d426be338bd5359b551a2a7aa5` (R59, 12/16 gates).
- R80 is experimental G15 packaging logic on top of R75 hardening. No provider-signed Main/Setup is available yet.
- Historical `SIGNPATH_APPLICATION_PACKET.json` refers to v1.1.2; **SUPERSEDED AS CURRENT APPLICATION EVIDENCE**. Retain original for provenance.

## Required real human/provider actions

1. Read SignPath Foundation OSS [terms](https://signpath.org/terms.html). Independently confirm that redistributed PawnIO 2.2.0 (official upstream binary license), other third-party payloads and the project's licensing satisfy OSS terms. Do not invent approval or remove the sensor dependency without an accepted engineering change.
2. Submit the [official application](https://signpath.org/apply.html) using the currently public v1.6.0 release and current repository. Only the actual person may accept Code of Conduct, privacy processing, MFA, and complete CAPTCHA. ChatGPT cannot supply those attestations or submit without a genuine interactive consent process.
3. After SignPath approval, create a project bound to the GitHub repository and approved GitHub trusted build system. Enforce origin verification, exact commit and protected release/main policies; configure **manual approval for each signing request**, as required by SignPath Foundation.
4. Create scoped CI API token and record it only in the GitHub Actions secret store. Do not commit any token/certificate private key to the repo, artifacts, support ZIP or PROJECT BRAIN.
5. In a trusted, approved GitHub workflow, **sign the owned Main first**. Download its actual signed bytes to `artifacts/signed/Main/TaskbarMonitorEnhanced.exe` and pin its post-signing SHA-256. Do not modify `build/_out/App` or the five deterministic G02 outputs.
6. Invoke `build/Package-Signed-Setup.ps1` with the signed Main path and exact SHA-256. It builds a NEW Setup under `artifacts/signed/Setup/TO_SIGN/` and checks that the 26 resources include the signed Main's exact hash. **This Setup is not yet signed or released.**
7. Submit that exact unsigned Setup for a second SignPath release-signing request with manual approval. Download the provider-signed Setup to `artifacts/signed/Setup/TaskbarMonitorEnhanced_Setup_1.7.0.exe`.
8. Run `build/Verify-Embedded-Main.ps1` independently against final Setup and exact signed Main digest. G15 also requires CA-valid Authenticode, matching SignPath Foundation certificates, RFC3161 timestamp, exact metadata and authenticated request/source/byte evidence for both artifacts. **Do not infer approval from the presence of a signature alone.**
9. G13 positive test only on authorized disposable Windows static-picture environment; G14 full signed-Setup interactive 8/8, Explorer, sensor and exact config rollback; then G16 approved main CI, immutable seven-asset public release, hash/SBOM reconciliation and user-ready Brain.

## Additional review: version metadata and upstream binaries

The owned Sensor Broker and Sensor Supervisor retain internal ProductVersion `1.1.2+r21` and `1.3.0+r33`, while Main and Setup use `1.7.0+r39`. SignPath Foundation metadata policies may require harmonized build product versions **if signing those sensor EXEs**. The current G15 gate covers Main and Setup; whether additional owned sensor signatures are mandatory remains a provider/maintainer decision. Do not silently overwrite protocol identity or sign upstream PawnIO files with the project's certificate.

## Machine confirmation needed before accepting FINAL

Human consent status = **MISSING**; token/organization/request IDs = **MISSING**; SignPath signed Main/Setup = **MISSING**; witness-trusted G13/G14 = **MISSING**; public v1.7 = **NOT PUBLISHED**.

Supported next source position: Draft G15 packaging candidate R80; old Main and installed stable version protected.
