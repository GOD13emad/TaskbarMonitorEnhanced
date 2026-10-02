# R37 verified continuation — control and failure record

## Current authority

Project: Taskbar Monitor Enhanced (Windows taskbar system monitor).
Objective/DoD: deliver 20 genuinely new renderer designs plus a working, bounded, privacy-conscious monitoring workspace; verify migration, real interactions, actual-data rendering, deterministic packaging, installation and exact-release CI before calling it Released/Final.

Canonical project root: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`.
Isolated current development root: `<canonical>\.local\r37-work`.
Current branch: `release/v1.6.0-r37-verified`.
Previous accepted release: immutable v1.5.0 at `d952a87fab02fe74046b8d19ae14a2801d6da644`.
Candidate parent: `f170a8a89cafab230a9b8e0071aad3ad38e52fa6` (UNACCEPTED: empty committed StudioThemes.cs; do not install/publish that commit).

Current phase: DEVELOPMENT / integration repair -> VERIFICATION. Whole new-release progress is gate-based, not an estimated percentage. No public-final claim is made for v1.6.0.

## Roadmap and gates

| Gate | Requirement | Status at this control revision |
|---|---|---|
| Discovery / definition | Primary-source competitor matrix; finite scope with exclusions | Primary sources reviewed; matrix to be recorded |
| Baseline | Preserve v1.5 and sensor pair; isolate concurrent mutations | Complete: isolated worktree and guarded recovery |
| Development | 48 themes, real workspace actions, safe migration/persistence | Integration patch applied; fresh tests pending |
| Verification | Compile, contracts, missing-data/NaN tests, migration 0..6, live proof | Running; earlier binaries are stale evidence |
| Validation | UI interactions, contrast/layout, lifecycle, installed config/hash/runtime | Open |
| Delivery | Exact commit, deterministic clean clone, CI/provenance, immutable assets | Open |
| Closure / Final | Release acceptance, cumulative Brain ZIP with manifest | Open |

Sensor sources/protocol remain locked: Broker `1.1.2+r21`, Supervisor `1.3.0+r33`. Expected binary hashes: Broker `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833`, Supervisor `0E28911AACDE0C3B1C6997C8BC6FF141C0FAA650B58438A9991CB3AD6C13C785`.

## Failures and prevention

### R37-VF01 — concurrent candidate source truncation
- Class: source-integrity / conflicting authority; phase: pre-mutation guard.
- Trigger: StudioThemes.cs SHA changed between dry-run and apply.
- Confirmed raw evidence: candidate f170a8a commits Git empty blob `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391`; file length 0.
- Root cause: exact truncation mechanism UNVERIFIED; concurrent commit/write activity is confirmed. Do not infer the writer or claim a mechanism without evidence.
- Impact: prior successful binaries do not correspond to committed candidate source. All exact-commit acceptance invalid until corrected.
- Prevention: source-size/hash preflight, in-memory staged edits, no read/write-to-same-file pipeline, isolated worktree, no automatic promotion.
- Recovery: exact canonical build resource `build/_package_text/StudioThemes.cs`, 12,906 bytes, SHA256 `AB939F674AA961D65B71EC3F7892EF43F20E66CEF9EA76D26690EAD4E12D53ED`; copied only to isolated worktree.
- Additional EOL mismatch: new C# modules lacked explicit LF policy; normalized source equality was independently checked, then exact observed checkout hashes used. New modules now have LF attributes.
- Rollback: `<isolated>/.local/r37/PRE_INTEGRATION.zip`, plus Git candidate parent. The empty theme file is historical defective evidence, not a valid restore target.

### R37-VF02 — compiled-but-disconnected features
- Confirmed: metric-order helper, bit-rate preference and workspace-close helper had no corresponding main-runtime call sites.
- Root cause: partial integration following interrupted work; compile/self-tests only checked declarations and defaults.
- Correction: connect BuildMetricViews ordering (including independent VRAM), network renderer, cleanup, pause/reset, notification routing and placement refresh.
- Guard/regression: actual renderer key-order assertion and fresh UI interaction validation; no feature acceptance based solely on a helper existing.

### R37-VF03 — migration ordering
- Confirmed: NormalizeWorkspace set schema 7 before legacy migration branches; old schema transformations were bypassed.
- Correction: execute legacy migrations 0..6 first, workspace migration last.
- Regression: each schema 0..6; notification opt-in remains false for old schemas; temperature defaults retained; NaN font/opacity normalized.

### R37-VF04 — misleading missing data / synthetic acceptance
- Confirmed: unavailable GPU/network/disk samples became zeroes; old workspace proof populated fabricated device/metric values while other proof types used actual data.
- Correction: explicit availability flags and chart/CSV gaps, finite numeric serialization, actual live workspace proof with `NoSyntheticMetricData=true`.
- Synthetic fixtures are allowed in unit tests only and are not user-visible runtime evidence.

### R37-VF05 — local traffic shutdown/corrupt-input handling
- Confirmed risk: queued ThreadPool writes could be abandoned at process shutdown; unreadable prior history could be replaced on later flush.
- Correction: single coalescing writer, bounded shutdown wait, persistent-write block after read error; preserve original file.
- Regression still required: coalescing, reset/gap counters, adapter changes, file preservation, retention and explicit opt-in.

### R37-VF06 — proof compile error
- `Thread.Sleep` added without namespace import in proof code; compiler rejected the build before runtime tests.
- Corrected to fully qualified `System.Threading.Thread.Sleep`.
- New build/test operation: `18619848-e151-4327-8a31-b9e617c7f0ff`; verify receipt, do not infer PASS from operation creation.

## Authoritative / superseded

Authoritative candidate inputs: tracked files on this isolated branch after review, not original-worktree changes that may continue concurrently. Source/binary equality must be reverified after each code mutation.

SUPERSEDED — DO NOT RUN as release acceptance: f170a8a defective source; pre-integration binaries; fabricated workspace screenshots; prior PASS reports whose binaries differ from the evaluated commit. Historical reports remain preserved and are not globally rewritten.

Open blocker/critical path: complete fresh integration tests -> UI/lifecycle/persistence validation -> exact source freeze -> deterministic build -> installed/CI/release gates. Public-trust Authenticode remains an external dependency; no trusted-signature claim.

Brain status: INCOMPLETE for this active continuation until this delta, predecessor history, required source/evidence and exact next action are packaged with hashes into one cumulative transfer ZIP.
Exact next action: read the current build/test receipt and address demonstrated failures only; then validate real UI and bounded traffic behavior before adding any further scope.


## Eight-page completeness checkpoint

Operation `73616abd-ac9b-4e72-a208-364fee0844a6` passed compilation with 0 warnings/errors, all three contract suites, and actual-data eight-page UI proof. The proof exercised 16 actual interface actions, 58 interactive controls without missing accessible names, normal/minimum-size captures, and 20 different geometry hashes under identical color/font/data inputs. Hardware inventory is snapshot-only, availability-aware, filterable and exportable. Product feature scope is now frozen; remaining changes must address demonstrated defects or release evidence/tooling.

Additional failures: the owner-draw event initially lacked the sender parameter; compiler rejected it and the exact signature was corrected. Test-Workspace initially used Start-Process without -Wait followed by WaitForExit; Windows PowerShell returned a null ExitCode despite successful child output. That result was correctly marked FAIL, not silently accepted. The harness now owns a System.Diagnostics.Process, starts both asynchronous stream drains before waiting, retrieves its actual exit code and rejects timeouts. Parameter-root initialization was moved from default expressions into script body after one explicit-root evaluation error. Each failed run is retained as invalid evidence; no blind rerun is an acceptance gate.

Primary technical reference for redirected-pipe deadlock prevention: Microsoft .NET process documentation / official .NET team explanation (https://devblogs.microsoft.com/dotnet/process-api-improvements-in-dotnet-11/). The implementation uses the .NET Framework-compatible existing Process API, not .NET 11-only APIs.


## Source freeze readiness

Operation d884b433-6431-45ce-a8a4-44d50ae9f93a completed all seven suites with actual exit code 0: legacy, feature, workspace, eight-page live workspace/actions, 48-theme rendering, 96 compact renderings and nine Settings pages. Candidate Main SHA256 is 15D1BFFA8A01173A6BB7982283674EF4CBA6576F4F8112A05476B68BCA3869A6. New source/tooling now enters exact-revision freeze. Full setup build/clean clone, CI and installed acceptance remain mandatory.
