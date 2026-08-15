# Taskbar Monitor Enhanced

A lightweight Windows taskbar system monitor built to keep the information I actually care about visible without opening another dashboard.

Taskbar Monitor Enhanced shows CPU, memory, disk, network, GPU, VRAM, and temperature telemetry directly on the Windows taskbar. It is designed to stay readable, recover cleanly when Explorer restarts, and keep the main UI running without administrator privileges.

## Release

**Current version:** 1.0.0

- Installer: `TaskbarMonitorEnhanced_Setup_1.0.0.exe`
- Installer SHA-256: `57196706279272fa2d605331f34b5386a5ba3fba8f0f64e12ee65e4288f5a4e7`
- Corresponding source: `TaskbarMonitorEnhanced_1.0.0_SOURCE.zip`
- Source SHA-256: `82ddae1701aae2d427aac08e08d5c249d3efe52e599794effd90fe9c861b01af`

> The current installer is not Authenticode-signed. Windows SmartScreen may therefore display an **Unknown publisher** warning on some systems. The SHA-256 above identifies the exact release build that passed the project’s final acceptance tests.

## Why this project exists

I wanted a taskbar monitor that felt like part of Windows rather than a separate monitoring application: compact enough to leave running all day, useful at a glance, customizable without being distracting, and resilient when the Windows shell restarts.

That led to a taskbar-native implementation with live trends, multiple visual themes, hardware temperatures, Explorer recovery, and a separate protected sensor layer so the visible application itself does not need to run elevated.

## Highlights

- CPU, RAM, disk, GPU, VRAM, upload and download monitoring
- CPU Package and GPU temperature telemetry
- 14 built-in themes
- Live sparklines and theme-aware network graphs
- Left, center, and right taskbar placement
- Adjustable width and safe placement
- Right-click context menu
- Automatic Explorer/taskbar recovery
- Non-elevated main application
- Protected hardware-sensor broker with watchdog supervision
- Start-with-Windows support
- Desktop and Start Menu shortcuts
- Upgrade, uninstall, and clean-install tested

## Installation

1. Download `TaskbarMonitorEnhanced_Setup_1.0.0.exe` from the release assets.
2. Run the installer.
3. Windows may request administrator approval for the protected hardware-sensor component.
4. The main application itself continues to run without administrator privileges.

## Release validation

Version 1.0.0 was accepted through a controlled release process covering:

- upgrade installation
- configuration preservation
- complete uninstall
- clean installation
- sensor-task recovery
- CPU temperature continuity
- post-install runtime stability

## Documentation languages

English is the primary project language. Short user-facing documentation is also available in:

- [فارسی / Persian](docs/i18n/README.fa.md)
- [中文 / Simplified Chinese](docs/i18n/README.zh-CN.md)
- [हिन्दी / Hindi](docs/i18n/README.hi.md)
- [Español / Spanish](docs/i18n/README.es.md)
- [Français / French](docs/i18n/README.fr.md)
- [العربية / Arabic](docs/i18n/README.ar.md)
- [বাংলা / Bengali](docs/i18n/README.bn.md)
- [Português / Portuguese](docs/i18n/README.pt.md)
- [Русский / Russian](docs/i18n/README.ru.md)
- [اردو / Urdu](docs/i18n/README.ur.md)
- [Bahasa Indonesia / Indonesian](docs/i18n/README.id.md)

## Project authorship

**Lead Developer & Maintainer:** Dr. Ali-Akbar Emadeddin  
Email: `aliemad1324@gmail.com`  
GitHub: `GOD13emad`

Taskbar Monitor Enhanced is derived from the open-source `leandrosa81/taskbar-monitor` project. Upstream authorship, attribution, and GPL licensing are preserved.

AI-assisted tools were used during development for code drafting, refactoring, diagnostics, test scaffolding, documentation, and iterative review. Requirements, architecture, hardware validation, acceptance testing, and release responsibility remained under human control.

## License

GNU General Public License v3.0.

See `LICENSE`, `COPYRIGHT_AND_ATTRIBUTION.md`, and `THIRD_PARTY_NOTICES.md` for details.
