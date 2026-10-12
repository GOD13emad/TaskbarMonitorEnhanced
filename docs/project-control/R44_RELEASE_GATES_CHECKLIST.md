# R44 — Release checklist and zero-alpha foreground chart acceptance

**Product:** TaskbarMonitorEnhanced v1.7.0. **Exact parent source:** R42 `5a6c7e5b9537e9694b4447b13e07e86de77b8696` on release/v1.7.0-r42-safety. **Proposed source:** feature/v1.7.0-r44-chart-foreground. **Previous accepted and installed:** immutable v1.6.0; installed Main expected SHA256 `05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377`. Original checkout in `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`; isolated current source in `.local\r41-work`.

## Goal and definition of done
For all 49 themes, background-only opacity must range from 0 to 100%, **text and all sparkline/bars/LCD/dots graph primitives must retain independent visible ink at 0%**, and at ≤30% their foreground color/halo must adapt to the effective sampled taskbar lightness. Respect manual ShowSparklines OFF and High Contrast override. Preserve real metric history, no fictitious production telemetry; no change to protected sensor, wallpaper/slideshow or installed v1.6 while qualifying the candidate. Gate level evidence cannot be substituted for installed validation.

## Completed feature development and developer-level verification
- R44 redraws core line/bars and Studio quantized LCD/dot charts into `glassInkCanvas` foreground and optional `glassHaloCanvas`, with geometry clipping and antialiasing. At opacity 100%, ordinary theme rendering stays the source of truth. Contrast selection remains `TaskbarGlassPixels.Compose`.
- **Regression-first RED**: required proof-only `SeedChartHistoryForProof` did not exist, compiler CS1061, saved `.local/r44/RED_CHART_BUILD.log`. Only proof instances receive this deterministic history; no runtime fake metrics.
- **GREEN**: main Release build zero errors/warnings; `--chartglassproof` tested 49 themes × 2 dark/light taskbar colors × alpha 0/29 = **196 PASS pairs**, comparing charts ON/OFF at actual pixel level with alpha and contrast conditions; boundary opacities 1/15/30/31/50/99/100 and ShowSparklines OFF included. Minimum visible graph pixel difference 776; minimum high-opacity foreground chart pixels 317; minimum adapted ink pixels 251. Raw JSON in `.local/r44/CHART_PROOF_DEV/CHART_GLASS_PROOF.json`.
- **Regression**: 10/10 visual & feature suites PASS (previous R42 9 plus R44 chartproof); themeproof 49, workspace 8 pages, settings, 210 distinct wallpapers, 196 glass text proofs retained.
- **Live Emad visual-only smoke**: actual temporary **top-level, click-through, nonactivating window over an empty taskbar area** using the R44 production pixel renderer. 24 real history samples, 1,788 additional chart ink pixels against manual ShowSparklines OFF baseline, opacity 0, native update and screenshot verified. Real captured strip `.local/r44/LIVE_CHART_SMOKE/TASKBAR_ZERO_OPACITY_R44.png`; receipt `LIVE_PREVIEW_R44.json`, status EXPIRED_CLEAN. **Not** a replacement for the installed overlay and **not** an installed taskbar-child integration acceptance.
- Previous R43 trial child windows were obscured by the Windows 11 taskbar compositor, despite native upload; corrected by a disposable click-through top-level *preview* only. Previous R43 visual-only smoke and baseline v1.6 preserved.

## Acceptance gates (release order)

| Gate | Hard acceptance | State at source freeze | Evidence / next action |
|---|---|---|---|
| 01 Goal, data & architecture | Separate bg/glyph/chart alpha, no telemetry fabrication | PASS R44 development | Source R44; isolated proof-only fixture |
| 02 All-theme chart masks | 49 × dark/light × 0/29 with ON/OFF distinct graph pixels | PASS | `.local/r44/CHART_PROOF_DEV/CHART_GLASS_PROOF.json` |
| 03 Contrast and alpha edges | ≤30% adapted black/white + halo, alpha0 clear pixels, 31/100 defined | PASS tested colors | Chart/glass proof matrices; no universal promise for dynamic mixed backdrops |
| 04 Manual graph OFF | ShowSparklines=false produces no separate graph ink | PASS | paired before/after chart pixels |
| 05 Visual and UI regressions | 10/10, 49 themes, 210 wallpapers, 8-page workspace | PASS | `.local/r44/VISUAL_DEV/SUMMARY.json` |
| 06 Real Emad screenshot | Real metrics, text + charts at 0%, visible native surface | PASS *temporary preview only* | `.local/r44/LIVE_CHART_SMOKE/TASKBAR_ZERO_OPACITY_R44.png` |
| 07 Source packaging | Main, Broker, Supervisor, Setup zero warnings, 26 exact canonical resources | TO VERIFY exact SHA | `build/Build.ps1 -NoDownload`, `Setup /verify` |
| 08 Clean-clone reproducibility | 5/5 SHA match exact HEAD | TO VERIFY exact SHA | `build/Verify-Determinism.ps1` |
| 09 Read-only candidate runtime | 8/8 checks, no app replacement | TO VERIFY exact SHA | `build/Test-Runtime.ps1` |
| 10 Exact GitHub CI/provenance | same SHA, reproducible build, SPDX & attestations, 5 local/CI matching hashes | TO VERIFY exact SHA | Push R44; wait GitHub CI |
| 11 Installed v1.6 + personalization | Exact hash unchanged, Slideshow BackgroundType 2 and config unchanged | PASS preflight | Repeat at closure; no personal wallpaper image attached |
| 12 Safe wallpaper refusal | Actual Slideshow rejects Apply before mutation | PASS R42 | `.local/r42/LIVE_NEGATIVE_ACCEPTANCE.json` |
| 13 Positive real wallpaper Apply/Restore | On authorized static-Picture environment, verify actual apply + exact image/style restore | **BLOCKED** | Issue #7; Sandbox App Control 0x800711C7, do not bypass |
| 14 Installed v1.7 transactional V&V | Snapshot+restore config, hover, click, real shell child, fonts, 0% charts, Explorer recovery, sensors | **OPEN** | No candidate install until safe acceptance path |
| 15 Distribution trust | Authenticode and licensing/supply-chain requirements documented, no false signed claims | **OPEN** | No externally trusted signing certificate established |
| 16 Main promotion and CI | Only accepted fast-forward merge after gates 13–15; exact main SHA CI | **BLOCKED** | Draft PR, do not merge prematurely |
| 17 Immutable public v1.7 release | 7 vetted assets + published SHA-256 digests, remote manifest and downloads checked | **BLOCKED** | Latest published v1.6 remains immutable |
| 18 Cumulative Project Brain & account transfer | New R44 ZIP includes R38/R41/R42 lineage, evidence, open blockers, verified SHA, transfer test | TO COMPLETE | After CI and candidate package |
| 19 Closure / FINAL | All preceding required gates PASS, no UNKNOWN accepted | **NOT ACHIEVED** | Never treat candidate tests as public installation acceptance |

## Roadmap / failure prevention / decision

DISCOVERY → REQUIREMENTS → R42 BASELINE → R44 RED/GREEN DEVELOPMENT → VISUAL VALIDATION **PASS**. VERIFICATION exact-source CI in progress at this record. Installed user acceptance **not attempted**; public DELIVERY/RELEASE, CLOSURE and FINAL explicitly **OPEN**. Whole-project weighted percentage **UNPROVEN** without defined milestones.

**Risk ledger:** Windows Slideshow on EMAD-PC-ULTIMAT actively rotates personal wallpaper; R42 guards nonstatic modes (do not switch user desktop). Windows Sandbox blocks assembly LoadFrom with `0x800711C7`, positive canary unresolved. Existing R43 child-window preview was rendered but visually hidden by shell composition; R44 uses a separate *preview-only* click-through top-level window for accurate visual inspection. Unknown Authenticode trust remains. The accepted v1.6 binary and supervisor layer are out of R44 mutation scope.

**Authority:** The R44 branch plus exact-head CI/evidence after promotion to candidate. Previous `release/v1.7.0-r42-safety` is the parent; v1.6 public is immutable. **SUPERSEDED—DO NOT RUN:** pre-R42 unguarded Wallpaper Studio on host Slideshow, R41/R42 setups as if stable, first R43 obscured taskbar-child preview, and any R44 installation absent full acceptance. Preserve raw failed and successful receipts.

**Exact next action:** freeze/commit R44 and run exact-head deterministic full Build + CI; stage a hash-verified **unreleased** RC and current cumulative Brain. To reach Stable, obtain a trusted, explicitly authorized Windows static-Picture canary and transactional installed v1.7 validation; only then merge and publish immutable v1.7.0.

## R46 addendum: actual Windows taskbar native visual acceptance

The former source/proof milestone was necessary but insufficient on Windows 11: even a successful layered child upload can be invisible beneath shell composition. R46 adds a new required candidate gate: actual production OverlayForm (run as a disposable proof instance, never installed) must show real text and chart pixels on a blank taskbar target at 0%; zero changed background pixels; preserve prior installed v1.6; and pass mode switches 0/30/97/100/0. This increases the executed release gate count from 14 to 15, with 11 candidate checks and four unchanged Stable blockers. Authority: docs/project-control/R46_NATIVE_COMPOSITOR_VERIFICATION.md. Do not treat a visual-only top-level preview or API-only Shell_TrayWnd child as installed acceptance.
