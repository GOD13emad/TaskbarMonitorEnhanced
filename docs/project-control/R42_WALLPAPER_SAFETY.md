# R42 — Wallpaper Studio transactional safety

Project: TaskbarMonitorEnhanced. Previous accepted public/installed v1.6.0 (release SHA 1652989b80c5c6d301c6f05818c48c5207fd9b7a); installed binary expected 05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377. Canonical root C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced; active isolated worktree .local\r41-work; R41 baseline d14768fb1d1d2110aec5cb7ddb48427d76d85166. This is the only R42 mutation objective: guard and verify wallpaper apply/rollback.

## Failure evidence
Active host wallpaper uses HKCU Explorer Wallpapers BackgroundType 2 (Slideshow). Read-only observation recorded image file hash changing during a 45-second session. R40 ApplyDesktop originally stored WallPaper/WallpaperStyle/TileWallpaper only and could not reconstruct slideshow playlist/options. Official Microsoft IDesktopWallpaper methods GetStatus, GetSlideshow and GetSlideshowOptions describe separate dynamic wallpaper state. Therefore actual Apply on the host slideshow MUST FAIL CLOSED. Do not replace personal dynamic wallpaper for the sake of a canary.

## R42 change and tests
- Require BackgroundType 0 (static Picture) BEFORE generating any image or touching desktop state. Unknown/Spotlight/Slideshow/solid-colour reject with clear text. No auto-disable.
- For static Picture, capture exact original image bytes+SHA, path/style/tile in a unique local backup. Recheck mode/path/hash immediately before mutation.
- Failed SPI apply attempts rollback and *verifies* original file SHA/path/registry/SPI. If rollback fails report AggregateException, preserve backup, mark UNRESOLVED. No silent success.
- Regression-first RED: WorkspaceSelfTest produced CS0117 for missing IsSafePictureBackgroundType, with raw RED_BUILD.txt. GREEN: app build 0 warnings/0 errors and workspace-selftest PASS. Original and new code backed up locally.
- Negative live host canary: Windows PowerShell 5.1 invoked real WallpaperStudio.ApplyDesktop through reflection while BackgroundType=2; product threw NotSupportedException before desktop mutation; verification PASS, path/style/tile and slideshow mode preserved. Evidence .local/r42/LIVE_NEGATIVE_ACCEPTANCE.json. Two earlier harness failures (Windows PowerShell Get-FileHash unavailable and MethodInvocationException wrapper) were classed as harness only; preserved negative.err and negative2.err and fixed in negative3.
- Positive real Windows apply/verify/restore must occur only in isolated Sandbox static-picture environment. It is OPEN until raw evidence is produced.

## Lifecycle, position and critical path
DISCOVERY→DEFINITION→BASELINE→DEVELOPMENT complete for this one objective. VERIFICATION: app RED→GREEN pass, full clean-clone and CI pending. VALIDATION: negative host refusal pass; positive isolated live canary pending. DELIVERY/RELEASE and CLOSURE/FINAL pending. Whole-project progress UNPROVEN without weighting; no false percentage.

Full roadmap: freeze R42 source → exact build/determinism → exact-head CI/provenance → isolated Sandbox positive canary → installed v1.7 runtime tests with prestate/rollback → main exact commit CI → immutable GitHub 7-asset release and checksums → Brain archive/current handoff.

Authority: feature R41 source plus R42 safety delta; previous immutable v1.6 remains published and installed. SUPERSEDED—DO NOT RUN: pre-R42 Wallpaper Studio on dynamic host, 25-resource v1.7 setup, early PowerShell negative harness wrappers. Previous history preserved. Risk: High Contrast and per-pixel taskbar transparency in R41 previously validated; no sensor code change. Brain CURRENT_FOR_CANDIDATE R41 but STALE for new R42 until cumulative ZIP includes this delta. Exact next action: positive canary in isolated Windows Sandbox, never live host slideshow. If isolation fails, release must remain blocked.
