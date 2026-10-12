# Taskbar Monitor Enhanced v1.7.0 — Wallpaper Studio & Sekiro

## Official public release verification (unsigned)

**v1.7.0 is an owner-authorized official Stable release without an Authenticode publisher signature.** No trusted external laboratory signature or physical mains-power-loss certification is claimed. Existing immutable releases remain available and unchanged.

The R113 Main passed **eight out of eight real installed runtime/UI diagnostics on each of two independent temporary Windows hosts**, including Start, Shell, genuine protected R33 supervisor Health, true screen pixels and exact taskbar/display restoration. The R114 Setup restored hash-pinned, journaled transactional updates; separate fresh Windows hosts verified in-place upgrades from the actual public v1.6.0 and unsigned Preview1 releases, preservation of user config/backups/unknown files/Startup, one canonical installation, rejection of untrusted edits, and same-build idempotence.

For existing installations, close the running app normally and run Setup; do not uninstall. For an existing recognized installation, `/update /quiet` is supported. The latest Main, Setup and release asset hashes are in the official GitHub Release manifest.


v1.7.0 adds a wallpaper layer to the v1.6.0 Theme Studio while preserving the accepted monitoring workspace and protected sensor architecture.

## Wallpaper Studio

- 21 Studio themes now expose exactly 10 wallpaper variants each.
- Total Studio wallpaper catalog: **210**.
- Wallpapers are rendered as real PNG images from deterministic theme palette/geometry rather than downloaded or bundled external wallpaper packs.
- Theme Studio provides wallpaper preview, single-PNG export, export-all-10, and explicit desktop apply.
- Export uses 3840×2160 output; validation also renders a complete 1280×720 proof set for pixel hashing.
- Desktop apply preserves the previous wallpaper path, WallpaperStyle and TileWallpaper in a JSON pre-state record. If the Windows apply path fails after mutation begins, the previous registry style/tile and wallpaper are restored/attempted before failure is reported.

## Sekiro Studio theme

A new **Sekiro** Studio theme is included, bringing the built-in catalog to 49 themes and the Studio subset to 21. Its visuals are original shinobi/ink-inspired geometry and palette. No copied game screenshot, logo, character art or third-party wallpaper asset is included.

## Evidence-driven acceptance targets

v1.7.0 promotion requires:
- zero-warning application and setup builds,
- 49-theme / 21-Studio self-test contracts,
- 49/49 theme proof,
- 210/210 wallpaper proof with unique pixel-file SHA-256 values,
- workspace and accessibility regressions,
- exact package resource verification including WallpaperStudio.cs,
- clean-clone determinism,
- one reversible live wallpaper apply/rollback canary,
- installed-runtime regression,
- CI/provenance and published asset digest verification before any FINAL release claim.

## Privacy and safety

- Wallpaper rendering/export is local-only.
- No background wallpaper rotation is added.
- No rapid multi-theme or wallpaper mutation loop is used.
- Existing traffic-history opt-in, process read-only behavior and no-cloud-telemetry policy remain unchanged.
- Current user configuration and protected sensor preferences are outside the wallpaper import/export surface.

## Protected sensor layer

In v1.7.0, the official PawnIO 2.2.0 installer is **not bundled or automatically downloaded** by the OSS-signed application Setup. It has its own upstream binary license. When PawnIO is already installed (version 2.2.0 or newer), the existing protected sensor layer can reuse it. Otherwise the application still runs but protected temperatures may show N/A; a user who wants this optional support can independently download and explicitly install PawnIO from https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0 . Setup does not modify existing drivers to work around missing approval.

Unchanged from v1.6.0:
- Broker protocol: 1.1.2+r21
- Sensor Supervisor: 1.3.0+r33

## Scope

Wallpaper Studio is a presentation feature. It does not change sensor polling, privileged hardware access, startup policy or monitoring data semantics.


## Taskbar glass and adaptive legibility (R41)
- All 49 built-in themes support 0–100% **background** opacity, independent of glyph opacity.
- At 0%, theme panels and background wash are transparent; metric text remains visible.
- At or below 30%, text automatically switches between white/black using the observed taskbar RGB outside the overlay. A contrasting 1-pixel glyph edge improves readability on uneven backgrounds.
- The taskbar color is sampled locally at an interval, with a Windows light/dark fallback; no screenshot is saved or uploaded.
- Windows High Contrast deliberately overrides the transparency choice and keeps the overlay opaque.
- Completely transparent pixels can pass mouse interactions through to the taskbar; the tray menu still provides Settings access.
- Windows child-layered-window rendering uses per-pixel alpha rather than whole-window WinForms Opacity. If native compositing fails, the overlay falls back to a fully opaque usable display instead of hiding the metrics.
- Native on-taskbar proof validated 0/10/29/30/100% opacity; representative color #132A27 yielded 15.1:1 contrast for selected text. Evidence remains under .local/r41 and must be revalidated after changing source/installer.

## Wallpaper Studio transactional safety
If Windows is running Slideshow, Spotlight, a solid-color background or an unknown background mode, the Apply command safely refuses without changing user personalization. Only a confirmed static Picture background is eligible. Before Apply, the current image is copied with SHA-256 into a unique local prestate backup along with its path and registry style/tile. On SPI failure, the app attempts to restore and verify original bytes, path and style; an unverified restoration is explicitly reported rather than silently accepted. This safeguard is separate from the per-pixel taskbar glass feature.

## R44: microcharts stay visible when background opacity is 0%

All 49 themes preserve the microchart foreground at zero-background opacity, including line, terminal/mission bars, Studio LCD/dots. Text and charts use taskbar-aware adaptive black or white plus a halo at opacity 30% or less. Manual Show sparklines OFF still hides graphs. All regular chart history remains observed data; proof fixture samples are proof-mode only. This remains an UNRELEASED candidate until positive wallpaper and installed acceptance.

## R46 Windows 11 true-alpha rendering visibility

Windows 11's taskbar compositor can hide a transparent layered child window even when native UpdateLayeredWindow succeeds. For background opacity below 100%, v1.7's candidate uses a taskbar-anchored nonactivating top-level layered window placed in the existing safe taskbar gap, preserving opaque text and line/bar/LCD/dot charts. At 100% and Windows High Contrast the established opaque taskbar-child mode is used. Switching back from opaque to transparent re-arms the layered style, and Settings/Workspace reattach to the correct mode. A disposable production OverlayForm live proof on Emad verified foreground visibility and mode changes using real screen pixels. This is an **unreleased candidate**; official installed behavior, authorized wallpaper restore, public Authenticode and public stable are not yet accepted.

## R49: telemetry-driven glass redraw after real metric commits

WinForms layered top-level windows using UpdateLayeredWindow may not honor ordinary Invalidate/WM_PAINT requests. The normal v1.7 installed-location canary previously showed static cold-start zero readings and invisible charts, although disposable proof-mode graphics were correct. The candidate now uploads fresh native PArgb foreground pixels directly from CommitMetricsSnapshot on every real telemetry snapshot, and on theme changes. A real production-form proof confirmed two native updates following actual real metric commits and visible graphics, without fabricating production telemetry. **This fix is an uninstalled release candidate** until a real installed-location runtime canary and separate Stable gates are met.

## R51: correct Start-menu verification for Windows 11 native transparent mode

The strict Start-menu acceptance now recognizes the actual product's taskbar-anchored, nonactivating layered popup below 100% opacity, with exact source PID/Win32 style/taskbar geometry checks. At 100% and High Contrast it continues to require the original direct Shell_TrayWnd child. Start-shell observation, visible ink and stability thresholds are unchanged. R50 real installed-path binary-only canary already proved live text/chart 3174/2898 real pixels after telemetry update but failed the outdated child-only probe; this correction still requires an independent real eight-case installed runtime retest and does not promote unsigned v1.7 to Stable.

## R54 Windows 11 Start/Search visible zero-opacity charts (UNRELEASED)

Windows 11 overlays the taskbar with a higher-compositor Start/Search surface which can visually cover even topmost layered windows. The new experimental candidate temporarily lifts the existing 48px noactivate glass metrics strip exactly 60px above its own taskbar gap for the duration of Start/Search, retains live text and charts there, and returns it via same-HWND Hide/Show and exact cached taskbar geometry after the shell closes. A real disposable production OverlayForm proof on EMAD-PC showed 24/24 Start, 24/24 text+chart visible at strict safe lifted bounds and exact original taskbar return with 2291 glyph / 1907 chart pixels. Opacity100/HighContrast child mode is unchanged. **This changes placement only while Start is open and remains an unapproved private release candidate, NOT installed Stable.** Public signed release, real installed eight-case suite including Explorer recovery and authorized static Picture Wallpaper Studio canary remain separate open requirements.

## R56 mode-aware native active ShellBeacon (UNRELEASED)

The source candidate now verifies the actual PID-owned Windows 11 taskbar-anchored layered popup used below 100% background opacity, instead of incorrectly requiring a Shell_TrayWnd WS_CHILD; 100% and High Contrast keep the original child rule. Active visual beacon colors are synchronously uploaded through native PArgb UpdateLayeredWindow and the screen test requires both colors to be actually visible and then cleared, and real glyph/chart signal. R55 genuine temporary installed-location Main-only test passed seven of eight interactive suites including Start 24/24 actual text+charts, but ShellState FAILed a legacy direct-child check. That historical R55 result has been superseded by R113 two-host installed full 8/8 and R114 two-host public-release in-place upgrade tests. Public-trust publisher signing is explicitly waived for the official unsigned release; external lab certification and physical AC-power-loss proof remain unverified.
