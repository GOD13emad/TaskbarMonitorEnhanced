# R38 release closeout - v1.6.0

Record UTC: 2026-10-02T23:15:56.337123+00:00

## Result and authority

**RELEASED / ACCEPTED.** The eight-page workspace, 48-theme catalog including 20 new Studio geometries, real UI action paths, local analytics, read-only inventory, alerts and presentation profiles are delivered. Release `v1.6.0` ID `402214671` is immutable, stable/latest and has 7/7 matching uploaded digests. Authoritative product source is `1652989b80c5c6d301c6f05818c48c5207fd9b7a`. Post-release documentation commits do not move this tag or change its installed/released bits.

Canonical root: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`.
Installed root: `C:\Users\Aa.Emad\AppData\Local\TaskbarMonitorEnhanced`.
Prior accepted immutable baseline: v1.5.0 at `d952a87fab02fe74046b8d19ae14a2801d6da644`. The corrected worktree source `182c4ed...` was consolidated before final source freeze. `8f19bd2...`, empty-source `f170a8a...`, synthetic workspace evidence and pre-integration installers remain historical **SUPERSEDED — DO NOT RUN** as current release authority. No historical files were globally rewritten or deleted.

## Roadmap and progress

Discovery, definition, baseline, scoped development, verification, validation/acceptance and delivery/release gates are closed with evidence. All product gates for this finite v1.6.0 scope passed. Final handoff packaging uses `.local/r38/BRAIN_R38.zip`, `.local/r38/RUN_R38.zip` and `.local/r38/RETURN_R38.zip`; existence and integrity are determined by their generated manifest/receipt, not by this path declaration. No universal-product-superiority percentage is claimed.

## Verification and validation

All four build projects: zero warnings/errors. All five outputs match a clean clone and the cryptographically verified exact-source CI statements. Candidate visual/model suite 7/7 and runtime suite 8/8 passed; after installation, the same 7/7 and 8/8 passed again. Forty-eight themes render at normal and compact widths. Twenty Studio renderers remain distinct with identical palette/font/data. Eight workspace pages at normal/minimum size, nine Settings pages, sixteen production UI actions, fifty-eight named controls and zero accessibility-name gaps passed.

Manual remote UI validation opened the installed context menu and Workspace, observed accumulating live Overview data, used the 20-Studio filter, previewed Bauhaus and Art Deco, then closed Workspace without stopping Main or changing the configuration. No unrelated desktop content was published.

Installed Main is SHA256 `05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377`. Setup/installed Uninstall is `f5130bc2f81383e16912454fcc62e307501885a6256e7241e674a9cf10bac9c5`. All five installed outputs and all four new installed source modules match the accepted build. The 69 configuration properties and exact configuration bytes are preserved. Protected sensors remain Broker1.1.2+r21/Supervisor1.3.0+r33, exact binaries reused, health STABLE with zero active consecutive failures in final installed suite. No restart of Windows was performed.

## Failure prevention and resolution

R38-F01: cold-shutdown traffic history loss was reproduced before the correction. Flush must read existing history before writing; corrupt history fails closed; queue completion plus actual I/O result determines success. Red operation920abe69-1532-43d2-a0e4-36966e90f094 failed the new assertion; green36c6d7b0-83ce-401c-808e-3e6c11c4bc0d passed. Source remains guarded by the new regressions.

R38-F02: the validation network could not reach Azure CI-artifact/attestation storage or automatic trust-root initialization. Blind transport retries stopped. The GitHub API supplied the actual signed inline bundles. GitHub CLI verified binaries, runtime config and SPDX predicates using the official Sigstore root pinned at commit644d7f24720ff4cddbc49908ead3c6459e637616, targethash6494e21ea73fa7ee769f85f57d5a3e6a08725eae1e38c755fc3517c9e6bc0b66, exact source and workflow. All 5 signed subjects match local files. No TLS/signature check was disabled, no DNS policy was changed, and no successful CI ZIP download is claimed. Verified SBOM predicate was exported with normalized formatting. Operation6361584c-986f-4e88-8b1f-3497f663b4c9 succeeded.

R38-F03: the first installer-runner readiness check reparsed an already-UTC PowerShell DateTime through an implicit string, producing a 3.5-hour false age. It stopped before installation. The corrected runner preserves DateTimeKind or uses ISO roundtrip parsing; typed/string regression passed. Prior backup/evidence was retained. The actual installation occurred once, operation5c3387a9-2d4c-433c-9db0-5fee3e03d443, and completed all installed suites. Never rerun the mutating installer runners.

R38-F04: the new draft existed but GitHub's tag-addressed release read returned404. Reconciliation read the release collection and exact ID402214671, verified the already-uploaded seven assets and published that same draft. No duplicate release or reupload was created. Future draft verification should use the actual draft ID; a failed receipt is not a failed write.

## Evidence and remaining scope

Exact release CI37074301100 and main CI37075175655 passed. Local evidence root `.local/r38` contains BUILD_MANIFEST, DETERMINISM, CI_ACCEPTANCE, candidate/installed suites, configuration/install acceptance, signed-bundle verification, TAG_AUTHORITY, PUBLIC_VERIFICATION, manual UI and preserved pre-states. Public summary is `docs/acceptance/v1.6.0/PUBLIC_RELEASE_ACCEPTANCE.json`.

No critical product gate is open for v1.6.0. Public-trust Authenticode requires an external provider and is explicitly unsigned pending that provider. Physical dual-monitor attachment is not proven on the one-monitor host. Kernel handle/DLL inspection, arbitrary executable plugin ecosystems, exhaustive specialist sensors and overclock/fan controls are outside this accepted scope.

Exact user action: right-click the monitor, open **Theme Studio - 48 designs...**, choose **20 Studio themes**, preview a design and press **Apply selected theme**. No repair/install command is needed. Engineering continuation begins by reading the newest verified Brain, checking the canonical root/HEAD/tag and public acceptance, then creating a new branch/revision; never mutate the immutable release.
