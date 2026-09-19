# R21 Acceptance Status — Taskbar Monitor Enhanced 1.1.2-rc10

Status: RELEASE CANDIDATE / NOT STABLE
Updated: 2026-09-19T22:01:00+03:30

## Authority

- Branch: `audit/r21-final-hardening-rc10`
- Source authority: `e89aebd9012f95d050771283562069f9cb5f5515`
- Public Stable/Latest: `v1.1.1`
- RC10 binary-source GitHub self-hosted run: `35460297804` = SUCCESS at `e89aebd...`
- RC10 control-head GitHub self-hosted run: `35460716964` = SUCCESS at `238d93e...`
- RC10 draft prerelease target: control head `238d93eeeadd83e31aa1de002cf00dee0778da41`; binary source authority remains `e89aebd...`; draft/prerelease only.

## RC10 objective

Preserve 15-second CPU temperature freshness while preventing transient LibreHardwareMonitor/PawnIO CPU read stalls from causing repeated worker restart storms. CPU hard process watchdog = 60 seconds; GPU behavior remains unchanged.

## Evidence-backed PASS

- Four-component build: 0 warnings / 0 errors.
- Built-in self-test: PASS; RC10 identity and CPU 60-second watchdog marker present.
- Setup embedded-resource/policy verification: PASS.
- Broker/Supervisor PE windowless guard: PASS.
- Canonical embedded-text payload: PASS.
- Clean-clone byte-for-byte determinism: PASS.
- SPDX 2.3 SBOM: PASS.
- GitHub self-hosted RC10 build/determinism/SBOM/provenance/Setup-SBOM/evidence upload: PASS.
- Draft prerelease is non-public and points at the exact RC10 source authority.
- Main RC10 binary has been installed in user space.

## RC10 deterministic outputs

- Main: `6BBD6BF7A559DE4C2C59FE4027FA2BA30EC82765B3C6F4000FF34375C72B2550`
- Broker: `7BA4E75514D69EC20D7FD478C3F8769A2D22BB48AC1B19900D946DF4FB64D907`
- Supervisor: `FE5EB08FC2ED2D2C7CAA70F7EA48965C409E2093E3BB054CE8AE60003D85D97D`
- Setup: `488FAC9FE5C98943F8A90DE58EBF70B999EE0C4AD4E01933B0090FDEA73BC400`
- SBOM: `E3659486DA78AE92E9F079EE76E10DF65518A3A5C25E00811A1B78C1958D894B`

## Current installed acceptance

**RC10 NOT INSTALLED / LIVE SYSTEM SAFELY ROLLED BACK TO ACCEPTED RC9**

- The hash-pinned RC10 elevation reached Windows Secure Desktop but Windows returned: `The operation was canceled by the user.`
- No automatic elevation retry was attempted after that denial.
- Exact accepted RC9 Setup `48DADB48072344E4627A939971313B931E84365A0311F79E48FC793BB029CBC8` was then used for rollback.
- Live Main/Broker/Supervisor hashes now exactly match accepted RC9.
- `install_state.json`: `1.1.2-rc9 / READY / CURRENT_EXACT_RC9`.
- Post-rollback HealthProbe: `PASS / STABLE`; all CPU/GPU/storage lanes healthy; active consecutive failures = 0.
- Windowless tree proof: one Supervisor, two Brokers, zero sensor-owned console children.
- RC10 fault-injection and physical S3 acceptance remain blocked until a **new explicit administrator consent** installs the exact RC10 protected pair.

## Root-cause chain leading to RC10

1. RC8 physical S3 exposed resume-ordering race.
2. RC9 official Windows resume callback fixed the race; real S3 passed with no worker failure.
3. RC9 post-S3 soak exposed a separate CPU worker stall: STALE_OUTPUT then NO_CURRENT_OUTPUT_AFTER_GRACE.
4. Broker emitted no fatal exception; isolated storage-contention probe did not reproduce a hang.
5. UI freshness already rejects CPU data older than 15 seconds.
6. RC10 therefore keeps freshness=15s but changes CPU hard-stall watchdog/startup grace to 60s, with explicit slow-output observability.

## Open acceptance gates

1. New explicit administrator consent, then exact protected RC10 install / READY state.
2. Soft-stall 25s fault injection: no restart; recovery required.
3. Hard-stall >60s fault injection: bounded restart required.
4. Post-fault 90s soak: restart counters stable; all samples healthy; zero new failures.
5. Real S3 on installed RC10: notification + recovery + no false worker failure.
6. Taskbar geometry, Main no-LHM module isolation, windowless process tree, Medium integrity and Event Log regression.
7. Current Brain/manifest acceptance update.
8. Final v1.1.2 identity build/determinism/install/attestation and immutable publication.

## Promotion rule

RC10 is not the public release. Stable/Latest promotion is prohibited until a separate exact final `v1.1.2` identity is built, installed and accepted with all gates above PASS.

## Evidence

- `RC_MANIFEST_v1.1.2-rc10.json`
- `SHA256SUMS_v1.1.2-rc10.txt`
- `r21_evidence/RC9_REAL_SUSPEND_RESUME.json`
- `r21_evidence/RC9_POST_S3_SOAK_90S.json`
- `r21_evidence/rc9_contention_probe/RC9_SENSOR_CONTENTION_PROBE.json`
- GitHub run `35460297804`
