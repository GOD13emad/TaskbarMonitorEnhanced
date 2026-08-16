# Code signing policy

Taskbar Monitor Enhanced is an open-source Windows project distributed under the GNU General Public License v3.0.

## Official release artifacts

Only artifacts attached to the GitHub Releases page are official release binaries/packages.

For release 1.0.2, the accepted artifacts are:

- `TaskbarMonitorEnhanced_Setup_1.0.2.exe`
  - SHA-256: `56DA35F0787A5F0D79E0B46ED4FC9FE9ECACF4547A853105894EA7504A88D5D6`
- `TaskbarMonitorEnhanced_1.0.2_SOURCE.zip`
  - SHA-256: `6BC2ED8DA18F5959E9B6780C55ACF204ADC4C41FC7100C1BFEF567E56DE7E571`

GitHub's automatically generated **Source code (zip)** / **Source code (tar.gz)** and the repository **Code > Download ZIP** action are repository snapshots. They are not the byte-exact accepted corresponding-source release artifact.

## Signing provider

The project intends to use sponsored open-source code signing where available.

Free code signing provided by SignPath.io, certificate by SignPath Foundation, subject to project acceptance by SignPath Foundation and its open-source code-signing conditions.

Until a signed release is explicitly published, users must treat the current release-signature state recorded in the release notes as authoritative.

## Team roles

- Committer: `GOD13emad`
- Reviewer: `GOD13emad`
- Release/signing approver: `GOD13emad`

For a one-maintainer project these roles are currently held by the same maintainer. If additional maintainers are added, signing approval and source review responsibilities will be separated where practical.

## Build and release integrity

A release intended for signing must:

1. originate from this public repository;
2. have its version and release metadata committed before signing;
3. be built using the documented project build process;
4. preserve GNU GPL and upstream attribution requirements;
5. contain no unpublished proprietary project code;
6. pass the project's release acceptance gates before publication;
7. be signed without modifying the artifact after the signature is applied;
8. publish cryptographic hashes for the final signed artifacts.

Release binaries are never considered accepted merely because they have a signature. Runtime/lifecycle acceptance and artifact integrity remain separate release gates.

## Privacy

Taskbar Monitor Enhanced does not transmit telemetry, monitoring data, configuration data, or personal information to networked systems unless a future user-requested feature explicitly requires such communication and is separately documented.

The application reads local system telemetry for display on the local Windows taskbar. See `PRIVACY.md` for the project privacy statement.

## Security and reporting

See `SECURITY.md` for vulnerability reporting. A signing certificate must not be used for builds that have not passed the project's release process or for third-party projects.
