# R54 — Windows 11 Start/Search compositor: true-alpha text/chart visibility

Project: TaskbarMonitorEnhanced v1.7 candidate. Parent source: R51 0a706f700e4623c24c6cd4e622ac071dcf5f6073. Branch feature/v1.7.0-r53-start-compositor-visibility. Public/installed v1.6.0 immutable. Personal Slideshow BackgroundType 2 untouched, secondary SAEID host declined.

## Reproduced failure

R52 actual installed-path normal v1.7 binary-only guarded canary showed 2,901 text / 2,407 chart pixels with live CPU/RAM/GPU/network and 0% backdrop; StartProbe then observed SearchHost 24/24 foreground samples, native HWND valid/visible/top-level/uncloaked and stable 24/24 but 0/24 visible screen ink. The initial R53 disposable actual OverlayForm test, safe RIGHT-side taskbar gap, showed:
- Unmodified native popup: 0/6 real visible ink.
- Reassert HWND_TOPMOST every frame: 0/6.
- Demote to HWND_NOTOPMOST then promote noactivate: 0/6.
- Native UpdateLayeredWindow upload plus TOPMOST: 0/6.
All native API/style checks reported success. Windows Start/Search higher compositor band still covered the taskbar surface; do not call native API success visible.
- Temporarily lift identical 48px overlay 60px ABOVE bottom taskbar: real text + graph visible 6/6 on RIGHT, and separately 6/6 on LEFT matching user's position setting.
- After Start closes, repeated ULW/TopMost at original taskbar position still 0 visible. Hide/Show of the SAME WinForms OverlayForm HWND restored 2,181 glyph and 1,906 chart visible pixels. RecreateHandle and a fresh OverlayForm also succeeded, but are unnecessary.

Proofs are local taskbar-only 900x48 PNGs, 24 real metrics and sample metadata. No full desktop screenshot uploaded, no original installed v1.6/config modifications, no wallpaper change, no sensor service changes and no secondary computer.

## Production R54 implementation

- For opacity below 100% and not High Contrast only, the actual existing StartGuardTick now detects SearchHost/Start foreground and temporarily sets the exact same PArgb OverlayForm to original taskbar safe-gap X/width/height but Y = pre-Start Y − (height + 12). The lifted strip remains nonactivating, taskbar-adjacent, topmost, inside the virtual desktop, per-pixel native with live foreground and charts. It is not the normal application main HWND replacement or a new popup object.
- While Start is foreground, the 500ms watchdog preserves the lifted position and real metric commits keep re-uploading PArgb charts. On shell exit the existing HWND is Hide/Shown nonactivating (empirically required to restore DWM compositing), then placed at EXACT cached pre-Start taskbar gap without a transient UIAutomation re-scan, and re-uploaded. After settling, ordinary periodic placement scans may adjust a genuinely changed taskbar safe-gap.
- Original 100% / Windows High Contrast direct Shell_TrayWnd child remains unchanged, no Start float. Mouse handler, tray, metric provider, workspace and startup continue as before. If lifted area is offscreen, skip rather than covering taskbar controls.
- During Start/Search, graphs temporarily float in a strip immediately ABOVE the taskbar instead of remaining within the occluded taskbar band. This is an explicit user-visible UX tradeoff. The user has not separately approved this transient layout for public release; this is a private source candidate only.

## Actual production-form screen acceptance

New disposable read-only command --startfloatliveproof uses actual OverlayForm/StartGuardTick code and screen-only taskbar strips with 24 genuine metric samples, Win key then Escape. The first R54 attempt measured 24/24 visible in Start and exact lifted geometry, but FAILed exact-return check because a transient taskbar re-scan moved the right safe gap by 32px; failure preserved. Source fixed by restoring cached pre-Start coordinates first.

After fix, actual on-EMAD-PC production-form proof with Main SHA256 F08DD5BD7A7ED801E2DA3331C14BCFA3C2D84CBB2C0ABBE97EF617727DB754A3: 24/24 Search shell, 24/24 lifted exact geometry, 24/24 real screen visible native text and charts, ORIGINAL taskbar rectangle return PASS, 2,171 text and 2,027 chart pixels still visible after Start closed. Evidence .local/r54/START_FLOAT_EXACT_RESTORE_DEV/R54_PRODUCTION_START_FLOAT_PROOF.json and cropped PNGs. Never misrepresent disposable proof-mode result as installed v1.7 acceptance.

## Hard release gate and real installed Start policy

Read-only build/Test-Release-Gates.ps1 adds independent G12 requiring exact Main-SHA-bound R54 actual native 24/24 shell, 24/24 text/chart pixels, 24/24 safe lifted bounds, real no-mutation and exact post-Start text+chart return. Original four Stable external blockers are renumbered G13..G16, NOT removed.

The distinct eight-case StartProbe for a real resident non-proof app was updated to require 24/24 native PID/style/bounds, exact floating offset for 0..99%, >=18/24 actual Start shell, all 24 screen captures with >=300 bright/saturated ink AND >=100 foreground changed pixels in BOTH text/chart bands, no cloak/missing HWND, and original cached HWND must return to original taskbar location with ink visible after Start. This replaces ONLY the native popup geometry policy; the original 100%/High Contrast direct-child immobility gate remains. The dynamic temporary float is explicitly recorded in its receipt rather than mislabeled as fixed nonmoving geometry. Screenshots of transparent Start tests now crop only target strips, no desktop-wide imagery.

The real normal installed-path R54 binary-only eight-case test, exact-source clean clone and GitHub CI/provenance are PENDING at document authoring. Do not claim source Stable or installed 8/8 before those independent results.

## Four independent Stable blockers

G13 authorized real static-Picture Wallpaper Studio ApplyDesktop then RestoreDesktopPreState with exact image SHA/path/style; live user Slideshow mode2 preserved, Sandbox application-control HRESULT 0x800711C7 denied prior unsigned candidate and user declined SAEID host.
G14 actually installed v1.7 full Setup (not merely temporary main binary), true native Start/Search and Explorer recovery, 8 interactive tests, sensors/hover/menu/config transactional rollback.
G15 public-trust RFC3161-timestamped Authenticode on both Main and Setup with external SignPath Foundation/provider approval. GitHub attestation does not equal publisher signature.
G16 approved exact main promotion, main CI and immutable seven public release assets verified with hashes.

No public Stable/FINAL, no OS security bypass, no personal wallpaper mutation, no unwanted secondary host use. Preserve R38–R53 history, R52 failed Start and exact rollback, and every R53 unsuccessful native test. Whole project weighted percentage remains UNPROVEN.

Authority: R54 source and live proof, R51/R49/R46 control docs, exact future commit and CI, cumulative Brain.
