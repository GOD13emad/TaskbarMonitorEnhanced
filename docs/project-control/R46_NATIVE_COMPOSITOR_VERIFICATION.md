# R46 — Windows 11 taskbar compositor: real on-screen foreground acceptance

Project: TaskbarMonitorEnhanced, upcoming v1.7.0. Parent exact commit a019ee72e676c8fa2f3cdd1d5ac28f9b0f1060cf, R45. Canonical root C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced; isolated development worktree .local\r41-work. Public and installed immutable baseline: v1.6.0, installed Main SHA256 05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377. Personal config SHA256 0E397F5EC24A8243EB6AD996923FECAFA6D8500B80B5CECAA6BCC4466DF72650; Windows background mode 2 rotating Slideshow. Both protected.

## Goal and definition of done

All 49 theme backgrounds may fade to zero without losing foreground glyphs or line/bar/LCD/dot microcharts, with adaptive taskbar contrast at opacity ≤30%. The real Windows 11 taskbar must visibly display that ink — an accepted Win32 API return code alone does not prove on-screen pixels. Changes 0→30→97→100→0 must preserve the graphics and restore the original 100% opaque child mode when required. Prove with actual OverlayForm production code in a disposable proof-mode instance while the resident installed v1.6 stays online. For public Stable, an installed v1.7 acceptance with full interactive start/sensor/hover/Explorer recovery/config rollback is still required, plus authorized static wallpaper positive canary and public signing.

## Critical discovery: the old native child acceptance was incomplete

- R41 TaskbarGlassLiveProof used a temporary Shell_TrayWnd child to upload alpha images at 0,10,29,30,100 and checked that UpdateLayeredWindow returned success, not visible screen pixels.
- R43 visual inspection already showed Win11 could hide the child behind the shell even when native upload succeeded. A top-level proof preview was visible; that visual-only tool was not the production OverlayForm.
- R46 recreated the production-style child in unused taskbar pixels, overlayed real telemetry and took actual before/after screenshots. With WS_EX_COMPOSITED + WS_EX_LAYERED, native upload failed Win32 ERROR_INVALID_PARAMETER=87 (the direct layered-child proof was not useful); evidence .local/r46/CHILD_VISIBILITY_CANARY.
- R46 A/B removed ONLY WS_EX_COMPOSITED in the temporary child: UpdateLayeredWindow succeeded, but real foreground comparison was zero text pixels and zero chart pixels — the actual taskbar compositor obscured the child. Evidence .local/r46/CHILD_NOCOMP_AB_TEST. Neither result can be called PASS. No installed program, keyboard/mouse or personal wallpaper was modified.
- R46 source production candidate now uses a taskbar-anchored, no-activate, topmost layered popup for background opacity below 100%, but retains the accepted direct taskbar child mode at 100% or Windows High Contrast. This preserves taskbar-native layout/position, original click handlers and the tray menu. No synthetic production telemetry.
- WS_EX_COMPOSITED is intentionally excluded from true-alpha popups, and WS_EX_TRANSPARENT is excluded to preserve text/right-click interaction; fully transparent pixels may be click-through by native hit test. Screen coordinates, not child-relative coordinates, are supplied to SetWindowPos and UpdateLayeredWindow for the popup. The original UIAutomation TaskbarLayout gap choice prevents covering Windows taskbar buttons.
- WinForms CreateParams executes before the OverlayForm constructor initializes config: a null guard prevents the initial NullReferenceException found by R46 regression.
- GetParent of a top-level WinForms popup that has ShowInTaskbar=false may return its hidden OWNER, not a real WS_CHILD parent. Native mode validation and recovery now use WS_CHILD/WS_POPUP, not GetParent==IntPtr.Zero. Diagnostic evidence: styleBefore 0x16010000, styleAfter 0x96010000, popup owner valid; corrected source reports TOPLEVEL_GLASS_STYLE_REPAIR pass=True.
- A 100%-opaque fallback might have used SetLayeredWindowAttributes; before a switch back to sub-100%, the candidate clears and readds WS_EX_LAYERED to permit per-pixel UpdateLayeredWindow. Settings and Workspace Apply reattach to the mode rather than assuming positioning alone is enough. Host context/visibility watchdogs and recovery treat a true popup separately from a taskbar child.

## Real production code and evidence (not just a separate image renderer)

Read-only new candidate CLI --topglassliveproof launches an actual production OverlayForm in proof mode: 24 observed metrics, no user-config save, no sensor installation or tray service; it positions over a UIAutomation-validated empty taskbar gap, records only the small 900 x 48 screenshot strip, compares real screen pixels against the blank underlying taskbar and only accepts actual foreground contrast. The proof tests real opacity 0→30→97→100→0 including switching back from opaque child to top-level PArgb ink. The receipt records the exact Main executable SHA256 and rejects stale output at the build manifest gate.

- Real initial pass: 2,281 visible glyph pixels, 1,976 visible chart pixels, ZERO changed transparent-background pixels. Prior installed v1.6 alive. Evidence .local/r46/REAL_FORM_OWNER_FIXED.
- Full dynamic mode pass: all four requested switches PASS, final 0% had 2,303 glyph and 2,183 chart visible pixels. Evidence .local/r46/REAL_FORM_DYNAMIC_TRANSITIONS.
- R46 final SHA-bound production form proof: Main SHA256 FEF4FC84B06906D6DDAAB5D59EB0BA5A9B339130A42161B8467E2A13766795B3; 2,319 foreground text pixels + 2,055 chart pixels and zero changed transparent-background pixels. 4/4 mode transitions PASS; after return to zero text 2,319 and chart 2,055. Evidence .local/r46/REAL_FORM_HASHED_FINAL/TOPGLASS_REAL_VISUAL_PROOF.json and TOPGLASS_MODE_TRANSITIONS.json, plus actual screenshot and before/after photos.
- The R46 source-level read-only release gate gains G11_ACTUAL_OVERLAYFORM_TASKBAR_0_30_97_100_0_VISIBILITY, matching both receipts to the exact compiled Main SHA and requiring real pixel counts, zero-alpha, four transitions and screenshot evidence. The four previous Stable external blockers are renumbered G12–G15, not silently removed.
- The previous R44 10/10 visual suites and 5/5 portable runtime tests remain mandatory in GitHub CI. Clean-clone determinism, setup 26/26 embedded resources, binary SHA and provenance are unchanged gates.

## Failure ledger

R46-F1: First child with COMPOSITED + LAYERED native ULW failed Win32 87; test blocked.
R46-F2: Child without COMPOSITED succeeded ULW but ZERO visual text/chart pixels; native return code is inadequate.
R46-F3: Newly introduced CreateParams accessed null config before Form constructor completed; guarded; 10 visual regression PASS.
R46-F4: Original native top-level style check confused WinForms hidden popup OWNER with WS_CHILD parent, falsely failed; fixed; production form actual screenshot PASS.
R46-F5: C# proof taskbar RECT needed initial assignment in short-circuit expression; harness-only compiler error fixed.
R46-F6: User explicitly requested all gates, but installed v1.7 integration and public Authenticode/positive wallpaper still lack independent evidence; do not downgrade criteria or claim Stable.

## Lifecycle, authority and next action

Discovery, scope, R45 baseline, R46 fix development, real Windows visual candidate acceptance COMPLETE. Full exact source frozen build/CI and previous 10/5 regressions need confirmation on the new R46 SHA. The full installed v1.7 8-probe shell/sensor/Explorer/config rollback remains OPEN. The live user has rotating Windows Slideshow type 2; R42 protected it by rejecting dynamic Apply. Sandbox was blocked by Windows Application Control 0x800711C7 before actual positive Wallpaper Studio test. The user declined alternate SAEID machine. Do not modify personal wallpaper, create a hidden Windows account, disable security, or infer success from a simulated wallpaper API. No public-trust Authenticode yet; SignPath Foundation enrollment/approval requires outside authorization. Immutable public/main remains v1.6.

Before release: commit R46 onto an isolated branch, verify full deterministic clean-clone and GitHub CI on exact SHA; stage private RC with hashes, refresh Project Brain R38→R46 with previous failure receipts and verified Return. Then trusted static Picture positive canary, real installed v1.7 transactional recovery/8 runtime probes, public signing, accepted main exact CI and immutable seven-asset release. Whole-project percentage UNPROVEN without defined weights. Never merge/release while issue #7 OPEN.

Authoritative files: this R46 record, R45 release enforcement executable, R44 checklist, new exact source/CI after commit, previous R45 cumulative brain. Superseded — DO NOT RUN: R41/early R46 child native API-only proof as a visual acceptance; R43 preview-only popup as proof of installed v1.7; pre-R42 Wallpaper Studio on active Slideshow; previous unsigned private release candidates as stable. Previous records retained.
