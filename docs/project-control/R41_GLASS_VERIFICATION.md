# R41 — Per-theme glass background / adaptive text contrast

**Project:** Taskbar Monitor Enhanced. **Branch:** `feature/v1.7.0-glass-legibility`. **Canonical root:** `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`. Active isolated worktree: `<canonical>\.local\r41-work`. Previous public immutable authority: **v1.6.0**, exact release source `1652989b80c5c6d301c6f05818c48c5207fd9b7a`. Parent of the R41 worktree: `3a0663fb9ed55c77d28ca3ee8d3d928adf1d2e42` (unreleased v1.7 wallpaper candidate).

## Final Objective / Definition of Done

All **49** v1.7 candidate themes allow **background-only opacity 0% through 100%**, independent from metric text. At **30% or lower**, visible glyphs use actual taskbar brightness where a safe off-overlay sample is available, with black/white foreground and opposite-contrast halo. Windows High Contrast forces opaque presentation. Requirements: preserve taskbar child / no-activate / Explorer-recovery architecture and existing foreground controls; no cloud upload or screenshots; package canonical new C# source and verify all existing regression tests.

**IMPORTANT: v1.7 has not been installed/released by R41.** Its independent Wallpaper Studio desktop-apply rollback canary, CI provenance, installed runtime and immutable publication remain separate open gates. Do not claim public FINAL based on R41 feature tests.

## Need → Implementation → Evidence → Acceptance

| Need | R41 implementation | Independent evidence | Gate |
|---|---|---|---|
| 0–100% background opacity | `AppConfig.Normalize()`, Settings Display field 0–100, per-pixel `TaskbarGlassPixels.Compose`; removed whole-form opacity | `--glassproof` 49 themes, opacity boundaries 0/1/15/29/30/31/50/99/100; 196 theme/background permutations | PASS as rendering contract |
| Glyphs remain visible at opacity 0 | Separate glyph and halo render masks; theme renderers routed via `DrawThemeGlyph` in regular/extended/Studio modes | 196/196 sampled 0/29 light/dark; clear background + opaque glyph tests | PASS |
| Adaptive colors under 30% | Brightness sampled from *taskbar locations excluding the overlay*; median across valid off-overlay points; Windows theme fallback; 4-second read interval | Real taskbar sample `#132A27`, selected text contrast ≈15.13:1; fallback and extreme-color contrast >=4.5 | PASS for tested taskbar |
| Native transparency without eliminating text | `UpdateLayeredWindow` with 32-bit premultiplied DIB, `AC_SRC_ALPHA`; no preceding incompatible `SetLayeredWindowAttributes`; opaque fail-safe | `--glassnativeproof` hidden child PASS; `--glassliveproof` actual Shell_TrayWnd child 0,10,29,30,100 PASS | PASS for tested host |
| Preserve integration and install source | 26 canonical embedded resources and extracted C# modules incl. `TaskbarGlass.cs` | `Build.ps1 -NoDownload` 4 builds 0 warning/error; `setup /verify` 26/26; contracts 3/3 | PASS precommit |
| No regression | Original theme renderer unchanged for regular proof; visual suite `Test-Workspace.ps1 -Visual` extended by glassproof | 9/9 PASS, Windows Settings and 210 wallpaper proofs retained | PASS precommit |
| Release | Exact-source commit, deterministic clean-clone, CI provenance, separate wallpaper canary, installed acceptance, immutable assets | NOT YET completed at this record | OPEN |

## Current stage, roadmap, progress

DISCOVERY → DEFINITION → BASELINE → DEVELOPMENT: **completed for R41**. VERIFICATION: **precommit candidate PASS**, exact source/determinism PENDING. VALIDATION: actual limited taskbar probe PASS; installed runtime not tested. RELEASE/CLOSURE: not started for this revision; existing public release unchanged. **Whole-project progress: UNPROVEN** without milestone metric and remaining independent R40 gates. Product's next public milestone remains v1.7 if separately accepted.

## Errors and failure-prevention evidence

- **R41-F1 / local runner guard:** an incorrectly transcribed script hash blocked execution before any product write; exact source hash re-read; rerun only after correction.
- **R41-F2 / local summary harness:** wrapper asserted 7 tests although v1.7 suite correctly has 8. Actual JSON proof reported 8/8 PASS; corrected R41 suite now reports 9/9; false harness FAIL not product FAIL.
- **R41-F3 / native live-proof setup:** initial temporary child form had `TopLevel=false` with no WinForms parent and could not create Handle. Corrected temporary proof lifecycle, no installed mutation.
- **R41-F4 / native live-proof parent order:** Win32 SetParent before `WS_CHILD` produced parent mismatch. Source-specific live test corrected to set `WS_CHILD` first then SetParent; five opacity-mode probes pass on real Windows taskbar. Production code uses the existing successfully validated parent-first strategy through its own `AttachIntegrated` method (style set before SetParent).
- **R41-F5 / PowerShell wrapper:** malformed `Start-Process` argument concatenation failed before child launch; corrected to one `$arguments` string.

All previous invalid receipts preserved; no blind reruns, no autonomous install/auto-promote. Product feature failure count after latest exact tests: 0. Do not delete legacy backups or evidence.

## Boundaries

- Fully transparent pixels may allow click-through in Windows; the tray menu remains a Settings entry point.
- The taskbar's blurred or dynamic per-pixel content can differ from neighboring sample; no universal contrast guarantee for every wallpaper/icon/animation. Sampling is local and never stored.
- Preserves user's existing `Opacity` value (currently 0.97 in prior v1.6 config) unless explicitly changed.
- Existing high-contrast accessibility forces 100% background, documented override.
- No change in protected sensor Broker (1.1.2+r21), Supervisor (1.3.0+r33), protocols, driver or startup registration.

## Authoritative and superseded

- **Current under review:** isolated R41 source set + `.local/r41` receipts + new packaged Setup only after exact commit verification.
- **Previous immutable release:** public v1.6.0 `1652989...`; do not rewrite tag/assets.
- **SUPERSEDED — DO NOT RUN:** earlier R41 proof wrappers with incorrect test count, missing managed parent, wrong Win32 style ordering; earlier 3a0663 v1.7 installer lacks the TaskbarGlass module and is superseded as a candidate *only* on the R41 branch, not as a previous accepted public baseline.

**Open Critical Path:** Commit exact source → rebuild/clean-clone determinism → exact-head GitHub CI/provenance → pending R40 desktop wallpaper reversible live canary (separate change/risk) → installed-run V&V/config-preservation → immutable v1.7 release/digest verification → cumulative Project Brain update. No unsafe auto-promotion.

**Exact next action:** freeze and commit R41 source, then repeat the authoritative build and clean-clone determinism on that exact commit; do not claim Installed/Released until evidence. **Project Brain:** INCOMPLETE until cumulative transfer ZIP with exact SHA/lineage is verified.
