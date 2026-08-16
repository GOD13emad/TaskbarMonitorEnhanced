# Taskbar Monitor Enhanced

A lightweight Windows taskbar system monitor built to keep useful telemetry visible without turning monitoring into another full-screen application.

Taskbar Monitor Enhanced shows CPU, memory, disk, network, GPU, VRAM, and temperature information directly on the Windows taskbar. It is designed to stay readable, recover cleanly when Windows Explorer restarts, and keep the visible application running without administrator privileges.

## Download

**Current release: v1.0.0**

- [Download the Windows installer](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.0.0/TaskbarMonitorEnhanced_Setup_1.0.0.exe)
- [Download the corresponding source archive](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.0.0/TaskbarMonitorEnhanced_1.0.0_SOURCE.zip)
- [View release notes](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.0.0)

Installer SHA-256:

`57196706279272fa2d605331f34b5386a5ba3fba8f0f64e12ee65e4288f5a4e7`

Source archive SHA-256:

`82ddae1701aae2d427aac08e08d5c249d3efe52e599794effd90fe9c861b01af`

> The 1.0.0 installer is not Authenticode-signed. Windows SmartScreen may therefore show an **Unknown publisher** warning. The hashes above identify the exact files that passed final release acceptance.

## Real-world preview

The image below is a real Windows 11 capture from the validation machine, not a mockup.

![Taskbar Monitor Enhanced running in the Windows 11 taskbar](docs/screenshots/desktops/desktop-dark-minimal.webp)

### Theme previews

![Dark Minimal](docs/screenshots/strips/theme-dark-minimal.webp)

![Sleek White](docs/screenshots/strips/theme-sleek-white.webp)

![Honeycomb Tech](docs/screenshots/strips/theme-honeycomb-tech.webp)

![Fluent Glass](docs/screenshots/strips/theme-fluent-glass.webp)

![OLED Mono](docs/screenshots/strips/theme-oled-mono.webp)

![Retro Terminal](docs/screenshots/strips/theme-retro-terminal.webp)

[Open the screenshot gallery](docs/screenshots/README.md)

## Highlights

- CPU, RAM, disk, GPU and VRAM monitoring
- Separate upload and download telemetry
- CPU Package and GPU temperature monitoring
- 14 built-in visual themes
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

## Source code

The release includes the exact corresponding-source ZIP used for the accepted 1.0.0 installer. Key components are also browsable in this repository:

- [`src/sensors/TaskbarMonitorSensorBroker.cs`](src/sensors/TaskbarMonitorSensorBroker.cs)
- [`src/sensors/TaskbarMonitorSensorSupervisor.cs`](src/sensors/TaskbarMonitorSensorSupervisor.cs)
- [`installer/TaskbarMonitorEnhanced_Setup.cs`](installer/TaskbarMonitorEnhanced_Setup.cs)
- [`installer/TBME_Setup_Elevated_Helper.ps1`](installer/TBME_Setup_Elevated_Helper.ps1)
- [`src/README.md`](src/README.md)

The full main-runtime source remains part of the exact corresponding-source archive linked above.

## Release validation

Version 1.0.0 completed a controlled acceptance cycle covering upgrade installation, configuration preservation, complete uninstall, clean installation, protected sensor startup, CPU temperature continuity, and post-install runtime stability.

## Documentation languages

English is the primary project language. User-facing documentation is also available in:

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

GNU General Public License v3.0. See `LICENSE`, `COPYRIGHT_AND_ATTRIBUTION.md`, `THIRD_PARTY_NOTICES.md`, and `UPSTREAM_REFERENCE_GPL_NOTICE.md`.