# Taskbar Monitor Enhanced

A lightweight Windows taskbar system monitor built to keep useful system telemetry visible without opening another dashboard.

## Current stable release

**1.0.0** is the currently published GitHub release. **1.0.1 has completed final lifecycle acceptance and is ready for publication.**

Accepted 1.0.1 artifacts:

- `TaskbarMonitorEnhanced_Setup_1.0.1.exe`
  - SHA-256: `4fd7d1055917eebb6598ba78e68294845f51fb190c93889b78f313ec1f3aed54`
- `TaskbarMonitorEnhanced_1.0.1_SOURCE.zip`
  - SHA-256: `32b69949b1bb8067739c53737b805274b069c63d98b96d84e4855ae826b0cc35`

> The installer is not Authenticode-signed. Windows SmartScreen may display an **Unknown publisher** warning.

## Why this project exists

Taskbar Monitor Enhanced is designed to feel like part of Windows rather than a separate monitoring application: compact enough to leave running all day, useful at a glance, customizable without being distracting, and resilient when the Windows shell restarts.

## Highlights

- CPU, RAM, disk, GPU, VRAM, upload and download monitoring
- CPU Package / vendor-neutral CPU temperature telemetry
- NVIDIA, AMD, and Intel GPU telemetry paths
- 14 built-in themes
- Live sparklines and theme-aware network graphs
- Left, center, and right taskbar placement
- Adaptive Safe Placement on smaller Windows 11 taskbars
- Compact metric layout for narrow free taskbar regions
- Right-click context menu
- Automatic Explorer/taskbar recovery
- Non-elevated main application
- Protected hardware-sensor broker with watchdog supervision
- Start-with-Windows support
- Desktop and Start Menu shortcuts
- Upgrade, uninstall, and clean-install tested

## 1.0.1 acceptance

The exact 1.0.1 Setup binary passed:

- upgrade installation
- configuration preservation
- complete uninstall
- clean installation using the same Setup binary
- AMD Ryzen 7 7730U CPU temperature validation using `Core (Tctl/Tdie)`
- AMD Radeon integrated-GPU load/memory telemetry
- zero Windows taskbar-control overlap
- windowless Sensor Supervisor validation
- 120-second clean-install lifetime validation

See `RELEASE_NOTES_v1.0.1.md` and `docs/FINAL_ACCEPTANCE_v1.0.1.md` for the release record.

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
