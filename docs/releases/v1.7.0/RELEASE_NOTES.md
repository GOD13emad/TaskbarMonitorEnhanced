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
