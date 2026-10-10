# R51: Start-menu runtime contract for zero-opacity top-level taskbar glass

Project: TaskbarMonitorEnhanced v1.7 candidate, branch feature/v1.7.0-r49-live-metric-glass-refresh; parent R49 exact SHA ce5aa4cdbcb132f752321a274ad13fc379b01688. Public/installed stable v1.6.0 remains authority and must be restored after every controlled canary.

## Observed real installed-path root cause and accepted precursor

R47 and R48 real temporary binary-swap canaries showed readable text but **no graphs** at 0% alpha even with 65-second warmup. Both correctly restored the user-configured v1.6 Main and config bytes and protected sensor services, with independent watchdogs; R48 six runtime probes passed, but Start failed. R49 fixed WS_EX_LAYERED normal-runtime image refresh on each real telemetry commit rather than depending on ordinary WM_PAINT.

The R50 normal-app canary on EMAD-PC then showed **3,174 on-screen glyph pixels, 2,898 on-screen chart pixels, real CPU/RAM/network telemetry and 0% background**. Original v1.6 executable, user config and Windows Slideshow were restored exactly. Protected Broker/Supervisor stayed healthy; AnyDesk remained active; no reboot, Explorer restart or secondary computer. R50 full eight-case runtime suite passed startup, hover, hardware, temperature, health and support (6/8), then Start probe failed exit5 with START_PROBE_BASELINE_DIRECT_CHILD_GATE. It did not run the final shell probe because of fail-closed test ordering. Screenshot/receipts: .local/r50/LIVE_CANDIDATE_ZERO_ALPHA_R50.png; CANARY_R50.json; ROLLBACK_RECEIPT_R50.json. Do not call 8/8 PASS.

## R51: correct window-mode contract, not lower the Start quality threshold

StartProbe originally required a direct Shell_TrayWnd WS_CHILD parent for every theme/opacity, which is no longer valid at alpha<100: R46 intentionally uses a no-activate native PArgb TOPLEVEL popup to overcome Windows 11 compositor occlusion, as verified with real screen pixels. R51 routes Start probe by the exact production TaskbarGlassHostMode.RequiresTopLevel(opacity,HighContrast) policy:

- At 0..99%, discover the real visible layered top-level popup for the resident Main PID using EnumWindows (not GetParent, which may return WinForms hidden popup owner). Require WS_POPUP, !WS_CHILD, WS_EX_LAYERED, WS_EX_NOACTIVATE, !WS_EX_COMPOSITED, source PID, width >=900, height 30..70, rectangle fully contained in actual taskbar.
- At 100% or High Contrast, require the original Shell_TrayWnd direct child HWND with correct WS_CHILD and taskbar parent.
- Cached HWND visibility, no DWM cloak, unchanged original geometry on all 24 samples, real cropped screen pixel contrast with minimum 300 signal pixels, and **>=18 / 24 actual Start-shell observation samples** remain unchanged. Do not relax Start window behavior, pixel threshold or tolerated failures.
- Annotate JSON and CLI with the actual required mode, retain diagnostic-only hierarchy enumeration. If Start/shell does not maintain the original stringent 24-sample conditions, report FAIL and preserve evidence.

## Lifecycle and independent Stable blockers

Developer code compiles zero warnings/errors; ten visual and five portable source suites must be rerun on R51 head. The exact normal-app temporary binary-swap canary with the R51 Main (source SHA and built SHA bound) must run using a unique immutable v1.6 prestate, independent watchdog, and mandatory rollback. Its result may still reveal genuine Start UI instability; do not claim PASS without actual 8/8 evidence. Full Setup transactional install/Explorer recovery/rollback remains separate from a binary-only canary.

Other Stable external gates remain: (1) authorized positive real static-picture Wallpaper Studio ApplyDesktop+exact original SHA/path/style restore (EMAD-PC has rotating Slideshow mode2, Sandbox App Control 0x800711C7 and secondary SAEID declined), (2) complete installed v1.7 integration, real 8/8 plus Explorer restart, sensor reuse and config rollback, (3) publicly trusted Authenticode Main/Setup after external approval, (4) approved main exact CI/immutable seven-asset public v1.7. Existing latest remains immutable v1.6.0, never merge/release based on source-only or temporary proof.

Project Brain/historical R38 through R50 failures retained. Authority: this R51 source document, R49 live metrics ledger, current R46 native proof, release gate executable, genuine R50 receipts. Whole-project weighted percentage UNPROVEN.
