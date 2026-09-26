# R21 Acceptance Status — Taskbar Monitor Enhanced v1.1.2

Status: FINAL RUNTIME ACCEPTED / GITHUB PUBLICATION PENDING
Updated: 2026-09-26T16:37:45.1467688+03:30

## Current authority

- Branch: release/v1.1.2-final
- Source authority commit: 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6
- Accepted precursor: RC10 commit eac234860c31d8e2a6c0ba7d61c7bf5248717db5
- Public Stable/Latest remains v1.1.1 until the immutable v1.1.2 GitHub publication gate closes.
- Final v1.1.2 identity equivalence: PASS, 7/7 behavior/build inputs.
- Final deterministic build/SBOM: PASS.
- Exact final installed runtime: PASS.
- Proportional final runtime regression: PASS.

## Exact final outputs

- Main: DFF69CFC96C0A0567DD32C04EBD45414CFF045172A76A84EE1060814921DFE9E
- Broker: 182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833
- Supervisor: 38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196
- Setup: 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB
- SPDX 2.3 SBOM: B324745F6041FA8E8C8FA888977B40B41100B787C6A8E087ED80EB23AC148578

## Final installed state

- PublicVersion=1.1.2
- InternalRuntimeBaseline=V1_1_2_R21_PRODUCTION_HARDENING
- SensorLayerVersion=1.1.2+r21
- SensorLayerStatus=READY
- Main/Broker/Supervisor installed SHA-256 values exactly match the final release manifest.
- Existing user config SHA-256 was preserved across final installation.

## Runtime acceptance

- Corrected freshness R2: 6/6 healthy samples, age range 0.188–4.573 s, zero bad samples.
- CPU/GPU restart counters remained stable.
- Taskbar structural proof: 12/12 visible, direct Shell_TrayWnd parent, 1100x48.
- Main integrity: Medium / RID 8192.
- LibreHardwareMonitor modules in Main: 0.
- Broker/Supervisor PE subsystem: WINDOWS_GUI / 2.
- Sensor-owned console hosts: 0.
- Relevant Application errors since final install: 0.
- Relevant TaskScheduler errors since final install: 0.

## Inherited RC10 validation

The 25-second soft-stall, greater-than-60-second hard-watchdog, post-fault soak and physical S3 gates are inherited from the accepted RC10 precursor rather than blindly rerun. This is justified by the tracked 7/7 final identity behavior-equivalence gate; final derivation changed release identity/control/docs only.

The first final-runtime harness incorrectly reported stale supervisor age because a PowerShell JSON timestamp had already materialized to DateTime and was then reparsed through local string semantics. R2 used PowerShell 7.5+ ConvertFrom-Json -DateKind String and round-trip DateTimeOffset parsing; all corrected freshness samples passed. This is a harness false negative, not a product failure.

## Open gates

1. GitHub provenance/SBOM attestation for the exact final authority/artifacts.
2. Commit and push the accepted final release-control delta.
3. Create immutable public v1.1.2 release and set Stable/Latest only after attestation PASS.
4. Final Project Brain / Knowledge / handoff closeout after publication.

## Evidence

- docs/acceptance/R22_FINAL_IDENTITY_EQUIVALENCE.json
- docs/acceptance/R22_FINAL_BUILD_ACCEPTANCE.json
- docs/acceptance/R22_FINAL_RUNTIME_ACCEPTANCE.json
- docs/acceptance/R22_RC10_ACCEPTED_PRECURSOR_20260926.md
- RELEASE_MANIFEST_v1.1.2.json
- SHA256SUMS_v1.1.2.txt