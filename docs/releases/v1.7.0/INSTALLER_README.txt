# Taskbar Monitor Enhanced v1.7.0

v1.7.0 extends the accepted v1.6.0 Performance Workspace and Theme Studio with Wallpaper Studio. The protected sensor architecture remains unchanged.

Key points:
- 49 built-in themes total, including 21 Studio designs.
- New Sekiro theme: original shinobi/ink-inspired palette and renderer geometry; no copied game artwork is bundled.
- Every Studio theme has exactly 10 deterministic 16:9 wallpapers: 210 Studio wallpapers total.
- Wallpaper preview in Theme Studio.
- Export one wallpaper as PNG or export all 10 for the selected Studio theme.
- Desktop wallpaper apply is explicit only. Before a desktop change, the current wallpaper path, WallpaperStyle and TileWallpaper are recorded; failures attempt rollback to the prior state.
- Procedural GDI+ generation avoids a large bundled bitmap pack and external wallpaper dependencies.
- Existing eight-page Performance Workspace, local analytics, alerts, profiles, accessibility and updater protections remain.
- Protected sensor architecture remains process isolated; broker protocol 1.1.2+r21 and Supervisor 1.3.0+r33 are unchanged.
- No cloud telemetry or background upload is introduced.
- No publicly trusted Authenticode signature is claimed unless independently verifiable on the published binary.

Project: https://github.com/GOD13emad/TaskbarMonitorEnhanced
License: GNU GPL v3.0
- Per-theme taskbar background transparency from 0% to 100%; below 30% adaptive text contrast sampled from the taskbar, High Contrast forced opaque.
