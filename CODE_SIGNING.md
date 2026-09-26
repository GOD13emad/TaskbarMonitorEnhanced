# Code signing policy

Taskbar Monitor Enhanced is an open-source Windows project distributed under **GNU GPL-3.0-or-later**. The authoritative repository is:

https://github.com/GOD13emad/TaskbarMonitorEnhanced

## Provider and current status

**Free code signing provided by SignPath.io, certificate by SignPath Foundation.**

The project is prepared to apply to the SignPath Foundation open-source signing program. **Acceptance is pending; no release is currently claimed to carry a SignPath Foundation signature.** The self-signed development certificate documented under `docs/security/` is for local pipeline validation only and is not public publisher trust.

## Official release artifacts

Only artifacts attached to the official GitHub Releases page are release binaries/packages:

https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases

The immutable accepted baseline is **v1.1.2**. Its release tag remains fixed and its published installer SHA-256 is:

`25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB`

v1.1.2 is not retroactively signed or replaced. Public Authenticode signing will begin only on a **new release version** after the SignPath or other trusted-provider gate is satisfied.

## Team roles

- Committer / maintainer: `GOD13emad`
- Reviewer: `GOD13emad`
- Release and signing approver: `GOD13emad`

This is currently a single-maintainer project. Source changes from external contributors require maintainer review. Every production signing request requires explicit manual approval; signing is never an automatic consequence of a build.

## Build-origin and signing controls

A production signing request must:

1. originate from this public repository and an identified commit;
2. use the repository build scripts and pinned dependency controls;
3. build the project Main, Sensor Broker, Sensor Supervisor, and installer artifacts from source;
4. preserve GPL/upstream attribution and documented third-party notices;
5. pass deterministic build and artifact-equivalence checks applicable to that release;
6. generate or update SHA-256 manifests and SPDX SBOM evidence;
7. pass runtime and installer acceptance before public promotion;
8. receive manual release and signing approval;
9. be Authenticode-signed and RFC3161-timestamped by the approved public signing service;
10. be verified after signing and never modified after the signature is applied.

Third-party and open-source dependencies are documented in `THIRD_PARTY_NOTICES.md`. Project signing credentials must never be used to sign unrelated third-party projects or unpublished proprietary code.

## Privacy and network behavior

The application does not upload monitoring telemetry, configuration data, or personal content. By default it performs an HTTPS update check against the official GitHub Releases API; users can disable automatic update checks in Settings. Installer download occurs only after the user confirms the **Download & Install** prompt. See [PRIVACY.md](PRIVACY.md) for exact endpoints and behavior.

## Verification and release integrity

Signed status is only one release gate. Users and maintainers must also verify the release tag and commit, published SHA-256 values, SBOM and provenance evidence, and runtime acceptance for the same release identity.

Current public release authority remains immutable **v1.1.2** until a separately versioned, accepted, publicly signed release is produced.

## Security reporting

See [SECURITY.md](SECURITY.md) for vulnerability reporting. Suspected signing-key, artifact-origin, or release-integrity incidents must block signing and publication until investigated.
