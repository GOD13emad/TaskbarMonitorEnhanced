# Taskbar Monitor Enhanced v1.7.0

v1.7.0 extends the accepted v1.6.0 Performance Workspace and Theme Studio with Wallpaper Studio. The protected sensor architecture remains unchanged.

Owner-authorized official Stable v1.7.0: distributed **without Authenticode signing**. Windows may display Unknown publisher. Verify the complete SHA-256 on the official GitHub Release before running.

IMPORTANT: If official v1.6.0 or public unsigned Preview1 is already installed, close the running monitor and use this same Setup. It upgrades **in place** with one canonical installation and preserves config, files, Startup and Wallpaper; do **not** uninstall first. For an existing recognized version, use `/update /quiet`. Unknown or user-modified managed program files cause a safe refusal without uninstalling.

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
- The official PawnIO 2.2.0 installer is not bundled in the OSS signing candidate (it has separate upstream binary license).
- If PawnIO 2.2.0 or later is already installed, protected sensors can reuse it.
- Otherwise monitoring remains available but protected sensor temperatures show N/A. Optional driver installation is a separate user decision via https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0 ; Setup performs no silent driver download.
- No cloud telemetry or background upload is introduced.
- No publicly trusted Authenticode signature is claimed unless independently verifiable on the published binary.

Project: https://github.com/GOD13emad/TaskbarMonitorEnhanced
License: GNU GPL v3.0
- Per-theme taskbar background transparency from 0% to 100%; below 30% adaptive text contrast sampled from the taskbar, High Contrast forced opaque.
- Wallpaper Apply refuses Slideshow/Spotlight/solid-color/unknown Windows background modes before mutation; static Picture uses hashed previous-image backup and checked rollback.
- R44: charts (line, bar, LCD/dots) remain visible at 0% background opacity without synthetic production metric history. R113 actual native 8/8 passed on two Windows hosts; R114 exact public-release in-place upgrades passed on separate hosts.
- R46: Windows 11 native true-alpha uses a taskbar-anchored top-level no-activate PArgb window below 100%, returning to the opaque taskbar child at 100% and High Contrast. R113 hosted true installed native UI validation passed; external signed laboratory certification remains unverified.
