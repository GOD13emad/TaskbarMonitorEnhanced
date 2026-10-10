# R45 — Executable release gates and CI enforcement (v1.7.0)

Project: TaskbarMonitorEnhanced. Branch feature/v1.7.0-r44-chart-foreground, parent R44 SHA 3926bfa7b9dddb735e7b79ede1c17632848b44d8. The accepted public/installed v1.6.0 remains immutable. R45 changes only the CI checks and adds a read-only release gate evaluator; no wallpaper, Windows protections, sensor services, install or public release edits.

## Definition of done
All 49 themes must keep text plus line, bar, Studio LCD and dot charts visible with 0% background; chart and text color adapt below 30%. R44 fulfills this as isolated source and temporary visual preview. A production FINAL release additionally requires real static-Picture Wallpaper Studio apply/restore with exact image SHA/path/style, transactional installed v1.7 native taskbar/Explorer recovery/sensors/config acceptance, publicly valid setup/main Authenticode, approved main revision and immutable seven-asset v1.7 release.

## New R45 hard gates
- build/Test-Release-Gates.ps1 is a read-only evaluator. Only its optional report path is written. No installs, wallpaper changes, signing, security-policy changes, merges or publication. It evaluates Git SHA and source cleanliness; five Main/Broker/Supervisor/Setup/config SHA-256 files; exact source clean-clone determinism; 26 embedded resources; 10/10 Visual suites; 196/196 chart matrix; 196/196 text-alpha matrix; 5/5 portable runtime probes; exact-head CI/provenance receipts; and real 24-sample temporary Emad preview.
- Stable-only gates are separately enforced: authorized static Windows Picture ApplyDesktop/RestoreDesktopPreState positive canary with exact byte/path/style restore; actual installed candidate Explorer recovery and protected sensor/rollback V&V; valid Authenticode on both Setup and Main; accepted exact main revision. Unavailable proofs yield BLOCKED, never PASS. Immutable public 7-asset release confirmation remains a separate *post*-publication gate.
- Add -RequireStable to reject with code 45 if any Stable gate is BLOCKED. Candidate proof gaps exit 46. The evaluator does not perform any of the blocked actions.

## CI upgrade
.github/workflows/ci.yml now runs Test-Workspace.ps1 -Visual and checks exactly 10/10, 49 themes, 196 contrast/chart samples; then Test-Runtime.ps1 -CiContract and checks 5/5 portable cases; the full 8/8 remains the installed-host gate. These become hard CI steps between exact clean-clone determinism and SPDX SBOM/provenance. Reports are published in CI artifacts for independent inspection. Existing canonical build, five binary SHA checks, SPDX 2.3 and provenance remain required.

## Failures and evidence
- R45-F1 harness: original CI patch failed before changing files because the YAML used CRLF and splice anchor used LF. Fixed by explicit newline normalization with exact original SHA; patched.
- R45-F2 harness: initial local release evaluator incorrectly combined project root with absolute input paths, giving false BLOCKED for build/determinism/glass proofs. Fixed via IsPathRooted and confirmed expected ten candidate proofs on parent R44 (except dirty source before commit). Preserve original false and corrected receipts under ignored .local/r45; not product failures.
- R44 feature baseline: source 3926bfa; 49 themes x 4=196 chart pairs, 10/10 visual, 8/8 installed-host runtime in its earlier run, 5/5 native taskbar call proof, real 24-sample visual-only preview showed 1,788 graph pixels and expired. No real installed v1.7 acceptance.
- R42 hard blocker issue #7: original EMAD-PC runs rotating Windows Slideshow BackgroundType 2; static-picture positive canary in Windows Sandbox failed *before* product invocation due App Control 0x800711C7. User declined using alternate SAEID host. Do not bypass protection or change personal Slideshow.
- Signature: public SignPath Foundation acceptance remains UNVERIFIED, local Setup is NotSigned; self-signed development certificates do not count as public trust. See CODE_SIGNING.md.
- Draft PR #9 is authority for current source; previous #8 closed unmerged. Existing latest public v1.6.0 is immutable.

## Lifecycle, source authority and critical path
DISCOVERY/GOAL/BASELINE/DEVELOPMENT: complete. VERIFICATION: R44 PASS; R45 new hard CI gate needs exact commit/CI. VALIDATION: real temporary Emad preview PASS but installed v1.7 OPEN; positive wallpaper canary BLOCKED. DELIVERY: private hashed RC only. PUBLIC RELEASE/CLOSURE/FINAL: OPEN. Whole project progress percentage UNPROVEN without weights.

Exact next action: commit R45 CI script + evaluator, repeat exact SHA builds, ten visual/five portable runtime, clean-clone determinism, exact-head GitHub CI, run strict release preflight (must mark Stable BLOCKED rather than false PASS), update Project Brain cumulative and verified Return ZIP. Do not install or publish until separate external gates are truly met.

SUPERSEDED—DO NOT RUN: CI workflows without 10 visual/five portable runtime plus separate installed-host eight gate; early R45 preflight path-resolution wrapper; pre-R42 unguarded Wallpaper Studio; original R43 invisible child overlay. Prior records retained.


## R45-F3 - nonportable CI checks surfaced by hard enforcement

First full GitHub CI run 38049549463 on c992bbe538b0ce0e6b2c02c94620aa1535e04202 FAILED in health runtime: exit 12 DEGRADED because the hosted Windows runner has no installed protected sensor Supervisor. This is an invalid host for a positive installed-runtime health acceptance. On Emad, the same full eight-suite run failed in the interactive Start probe: 10 of required 24 shell samples, although its cached parented child HWND was valid and screen signal remained 7381 pixels. Both failures are preserved; neither is reported PASS.

Correct division without weakening an acceptance threshold: GitHub CI runs exactly five portable CLI proofs (startup, hover, hardware-inventory, temperature, support bundle), with receipt Mode=CI_PORTABLE_5; all 8 installed-host probes, including sensor health, Start and actual shell beacon, are reserved as separately required Stable installation gates. The release evaluator G08 now requires portable 5/5 and G12 additionally requires a verified installed host 8/8. A prior historical R44 host 8/8 PASS cannot substitute for new installed R45 acceptance. A new exact commit and full CI revalidation are required.

## R45-F4 - false GitHub CI failure after 5/5 real portable probes

The exact pull-request CI 38050088052 on SHA 8477761e3f94ac155ca0ceafde7454a992a2d4fc returned FAILED in its wrapper even though its raw CI log confirmed five child probes each exit=0 PASS and TBME_RUNTIME_SUITE=PASS TESTS=5. Root cause: Test-Runtime.ps1 uses System.Diagnostics.Process internally rather than invoking a native process through the parent PowerShell host. Consequently LASTEXITCODE is null in the new step, and PowerShell evaluates null -ne 0 as true. The error was a bogus wrapper check; no failed child probe occurred. R45-F4 removes only that nullable check and still enforces actual thrown exceptions, Summary.Status PASS, Mode CI_PORTABLE_5, five exact entries all PASS. Previous CI failure and logs remain accessible; new exact commit/CI is required before candidate acceptance.
