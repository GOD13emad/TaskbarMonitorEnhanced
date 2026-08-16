# Taskbar Monitor Enhanced

A lightweight Windows taskbar system monitor built to keep useful system telemetry visible without opening another dashboard.

## Current stable release

**1.0.2** is the current stable GitHub release.

Accepted 1.0.2 artifacts:

- `TaskbarMonitorEnhanced_Setup_1.0.2.exe`
  - SHA-256: `56DA35F0787A5F0D79E0B46ED4FC9FE9ECACF4547A853105894EA7504A88D5D6`
- `TaskbarMonitorEnhanced_1.0.2_SOURCE.zip`
  - SHA-256: `6BC2ED8DA18F5959E9B6780C55ACF204ADC4C41FC7100C1BFEF567E56DE7E571`

> The installer is not Authenticode-signed. Windows SmartScreen may display an **Unknown publisher** warning.

## Why this project exists

Taskbar Monitor Enhanced is designed to feel like part of Windows rather than a separate monitoring application: compact enough to leave running all day, useful at a glance, customizable without being distracting, and resilient when the Windows shell restarts.

## Highlights

- CPU, RAM, disk, GPU, VRAM, upload and download monitoring
- CPU Package / vendor-neutral CPU temperature telemetry
- AMD Radeon GPU temperature fallback through AMD ADLX 1.1 when LibreHardwareMonitor does not expose an AMD GPU temperature sensor
- NVIDIA, AMD, and Intel GPU telemetry paths
- 14 built-in themes
- Live sparklines and theme-aware network graphs
- Left, center, and right taskbar placement
- Compact taskbar rendering with vertical DL/UL stacking in narrow Network cards
- Direct left-click and right-click interaction without click-through behavior
- No-activate taskbar interaction
- Stable Start/Search/taskbar placement and persistent shell-style self-heal
- Automatic Explorer/taskbar recovery
- Non-elevated main application
- Protected hardware-sensor broker with watchdog supervision
- Start-with-Windows support
- Desktop and Start Menu shortcuts
- Upgrade, uninstall, clean-install, and post-install runtime validation

## 1.0.2 acceptance

The exact 1.0.2 Setup binary passed:

- upgrade installation
- existing configuration preservation
- complete uninstall
- clean installation
- 19/19 embedded installer resources
- CPU temperature validation
- AMD Radeon GPU temperature via `AMD_ADLX_1.1`
- 14-theme wide proof
- 14-theme compact proof with zero overflow
- Network DL/UL stacked compact rendering
- 180-second final installed runtime campaign: 171 samples, width delta 0, height delta 0
- `WS_EX_NOACTIVATE` preserved, `WS_EX_TRANSPARENT` absent, taskbar parent preserved

The underlying engineering baseline also completed a separate 600-second / 582-sample long-run acceptance before release packaging.

The authoritative corresponding source for the public binary is the explicitly attached release asset `TaskbarMonitorEnhanced_1.0.2_SOURCE.zip` with the SHA-256 above. See `RELEASE_NOTES_v1.0.2.md` and `docs/FINAL_ACCEPTANCE_v1.0.2.md` for the release record.

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
