# Taskbar Monitor Enhanced v1.7.0 — Wallpaper Studio & Sekiro

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
