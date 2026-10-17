# Code signing policy

Taskbar Monitor Enhanced is an open-source Windows project distributed under **GNU GPL v3.0**. The authoritative repository is:

https://github.com/GOD13emad/TaskbarMonitorEnhanced

## Owner-authorized unsigned distribution

The owner explicitly accepted official unsigned distribution. The current release channel has no claimed SignPath or other public-trust publisher signature. Check the actual installer signature and versioned hashes on [the official latest Release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/latest). `NotSigned` is disclosed rather than treated as a trusted signature. Previous releases through the independently observed **v1.7.8** remain immutable, including their owner-accepted unsigned installers.

Any future trusted signing must use a new independently versioned release. Hash verification and GitHub artifact attestations establish file provenance, not antivirus clearance or publisher Authenticode signing.

## Provider and current status

**Potential provider option: SignPath Foundation. A previous open-source application was not approved; a new application has not been accepted and public-trust signing is unavailable.**

The repository contains technical preparation for a potential future SignPath Foundation application. **A prior submission was declined; provider acceptance and a production public-trust signature do not exist.** Reapplication requires a new provider review and stronger independent public-adoption evidence; repository readiness alone is insufficient. The self-signed development certificate documented under `docs/security/` validates the signing pipeline only and is not public publisher trust.

### SignPath Foundation program attribution (conditional; no endorsement or certificate yet)

The following exact wording is required by the SignPath Foundation code-signing policy for projects that are approved to use its certificate:

> Free code signing provided by SignPath.io, certificate by SignPath Foundation

**Current status: a previous Foundation application was not accepted; no current approved signing account or certificate is evidenced, and no published Taskbar Monitor Enhanced binary is claimed to be signed by SignPath Foundation.** This required attribution is included for application readiness, not as a statement that the service, certificate or production signing is available.

The open-source maintainer, reviewers and signing approver are identified in the **Team roles** section below; project privacy and user-controlled network activity are documented in [PRIVACY.md](PRIVACY.md). See the [SignPath Foundation code of conduct](https://signpath.org/terms.html). Public-trust signing additionally requires identical project/product-version metadata for artifacts submitted together, verified GitHub-hosted source-build origin, and explicit approval for each production signing request. Untrusted self-signed development certificates must never be used as public-publisher proof.

Historical release lines, including v1.6.0 and the public v1.7.8 installer, are treated as unsigned unless their **exact** artifact has an independently verifiable Authenticode signature from a publicly trusted provider. Release evidence records `PublicTrust=UNSIGNED_PENDING_EXTERNAL_PROVIDER`; Windows may show **Unknown publisher**. Repository-side readiness is not provider acceptance or a trusted signature.

## Official release artifacts

Only artifacts attached to the official GitHub Releases page are release binaries/packages:

https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases

v1.4.0, v1.3.1, v1.3.0, v1.2.0 and earlier published releases remain immutable historical authorities. No historical tag or release asset is rewritten merely to add a signature. Any future publicly trusted signing change must use a newly versioned release unless the exact published artifact was already signed before publication.

## Team roles

- Committer / maintainer: `GOD13emad`
- Reviewer: `GOD13emad`
- Release and signing approver: `GOD13emad`

This is currently a single-maintainer project. Source changes from external contributors require maintainer review. Every production signing request requires explicit manual approval; signing is never an automatic consequence of a build.

## Build-origin and signing controls

A production signing request must:

1. originate from this public repository and an identified commit;
2. use the repository build scripts and pinned dependency controls;
3. build the Main, Sensor Broker, Sensor Supervisor, and installer artifacts from source;
4. preserve GPL/upstream attribution and documented third-party notices;
5. pass deterministic build and artifact-equivalence checks applicable to that release;
6. generate or update SHA-256 manifests and SPDX SBOM evidence;
7. pass runtime and installer acceptance before public promotion;
8. receive manual release and signing approval;
9. be Authenticode-signed and RFC3161-timestamped by the approved public signing service;
10. be verified after signing and never modified after the signature is applied.

Third-party and open-source dependencies are documented in `THIRD_PARTY_NOTICES.md`. Project signing credentials must never be used to sign unrelated third-party projects or unpublished proprietary code.

## Privacy and network behavior

The application does not upload monitoring telemetry, configuration data, or personal content. By default it performs an HTTPS update check against the official GitHub Releases API; users can disable automatic update checks in Settings. Installer download occurs only after the user confirms the **Download & Install** prompt. Support ZIP export is local and user initiated; its manifest omits machine name and absolute source paths. See [PRIVACY.md](PRIVACY.md) for exact endpoints and behavior.

## Verification and release integrity

Signed status is only one release gate. Users and maintainers must also verify the release tag and commit, published SHA-256 values, SBOM and provenance evidence, and runtime acceptance for the same release identity.

Until a qualified trusted signing provider actually signs a separately versioned release, public-trust signing remains **UNAVAILABLE / NOT APPROVED** even when repository-side release gates pass.

## Provider eligibility checkpoints (17 October 2026)

The latest independently observed public release is **v1.7.8**. Its release channel contains an explicit owner-accepted unsigned-installation evidence record. The release manifest, SHA-256 values, SPDX SBOM and source archive support file/source verification; **none of these makes its existing Windows installer Authenticode-signed**. No historical release bytes will be replaced under an existing tag.

- **SignPath Foundation:** an earlier application was declined. The repository already offers an OSI-approved GPL-3.0 license, a versioned public Windows installer, a source archive, an SPDX SBOM, and independent GitHub provenance/testing evidence. It also documents upstream attribution and explicitly excludes the separately licensed protected PawnIO binary from the project OSS installer. This technical preparation does not resolve the Foundation's independent **public reputation/adoption** criterion. No acceptance or issue of a SignPath Foundation signing credential exists; a new provider review would be required.
- **OSSign (Open Source Codesigning Initiative):** an additional potential no-fee sponsorship route for established, reviewable open-source software; **new applications are currently suspended** by OSSign due to backlog. Its published minimum requires six months of genuine activity for account/organization AND project (including limits for forks), demonstrable users/community, and publicly verifiable release automation; politically focused, controversial or primarily offensive-security software can be excluded. The actual developer account was created on **17 November 2021**, but this specific repository was only created on **15 August 2026**. The earliest simple six-month repository milestone is **15 February 2027**, not an approval date; earlier proven project development, if any, would need independent provider judgment. Legal eligibility for a subscriber or maintainer actually resident in Iran, the approved signing scope and the reopening of applications are **UNCONFIRMED**. No OSSign application or certificate exists.
- **Certum Open Source Code Signing:** a different potential issuer route for individual, genuinely noncommercial open-source distribution. This is **not** a universal certificate for proprietary, commercially distributed or unrelated projects. Certificate issuance requires identity and project verification. Certum's SimplySign cloud listing currently says `out of stock`; lawful issuance to an applicant genuinely resident in Iran, SimplySign activation there, payment availability and the certificate's exact permitted scope **have not been confirmed**. Do not order or upload identity documents before receiving a binding eligibility/fulfillment response.
- **Commercial Standard certificate:** a lawfully issued public-trust certificate could potentially sign multiple of the individual's first-party applications within its licensed scope. Provider-specific Iranian-residency compliance, identity, sanctions/export, custody, price and device/cloud availability remain unresolved.
- **Microsoft Store MSIX:** Store signing is limited to an app accepted into that distribution model. It does not sign or convert existing EXE installers, and legal/account eligibility for the actual applicant's country requires independent confirmation.

For a future newly versioned, genuinely approved release, stage the exact first-party artifacts and verify Windows Authenticode publisher/chain, timestamp, filenames and post-sign hashes independently. Never sign embedded third-party components as though they were original project binaries. Do not treat GitHub/Sigstore provenance, SHA-256 hashes or development self-signed certificates as publicly trusted Authenticode.

Primary requirements: [OSSign eligibility/status](https://ossign.org/), [SignPath Foundation terms](https://signpath.org/terms.html), [Certum Open Source product](https://shop.certum.eu/open-source-code-signing-on-simplysign.html), [Certum certificate verification](https://support.certum.eu/en/code-signing-required-documents/) and [Microsoft Windows signing options](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options).

## Security reporting

See [SECURITY.md](SECURITY.md) for vulnerability reporting. Suspected signing-key, artifact-origin, or release-integrity incidents must block signing and publication until investigated.
