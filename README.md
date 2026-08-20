# Taskbar Monitor Enhanced

A lightweight Windows taskbar system monitor that keeps useful hardware and performance telemetry visible without forcing you to open a separate dashboard.

## Official download

**Current stable release: 1.1.0**

Download the official build from the [Taskbar Monitor Enhanced 1.1.0 release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.0).

Accepted release assets:

- `TaskbarMonitorEnhanced_Setup_1.1.0.exe`
  - SHA-256: `CF03BCAFC78BB5F8A01C8ED4BFD7B4E16E75A7BFDA57AC1C7A8D7594BEA4D5D6`
- `TaskbarMonitorEnhanced_1.1.0_SOURCE.zip`
  - SHA-256: `DF26B9887E72C532022E4B28F2F989F603DFCD6E19D592456AFEABE23783ADB0`

The release also includes `SHA256SUMS_v1.1.0.txt` and `RELEASE_MANIFEST_v1.1.0.json` for independent verification.

> **Do not use `Code > Download ZIP` as the accepted release package.** GitHub's repository snapshot downloads are not the authoritative v1.1.0 source package. The explicitly attached, hash-identified `TaskbarMonitorEnhanced_1.1.0_SOURCE.zip` release asset is the corresponding-source package for this release.

## What's new in 1.1.0

Version 1.1.0 focuses on storage telemetry and shell reliability while preserving the compact taskbar-native experience.

- multi-disk read/write activity, capacity, and temperature telemetry
- real temperature reporting for four validated physical drives
- storage identity mapping through LibreHardwareMonitor hardware IDs before model-name fallback
- validated USB-bridge temperature mapping for JMicron and Lenovo attached SSDs
- restored accepted taskbar child-window shell behavior for Start/Search/taskbar compatibility
- automatic recovery after Windows Explorer restarts
- CPU, RAM, GPU, VRAM, network, disk, temperature, theme, graph, and placement features retained

## Release validation

The accepted v1.1.0 engineering baseline completed:

- manual Start open/close x5: PASS
- ShellState PRE/POST: PASS
- disk temperature telemetry: 4/4 PASS
- runtime storage identity mapping: 4/4 PASS
- installer embedded resources: 19/19 PASS
- 600-second / 300-sample responsiveness campaign: 300/300 PASS
- zero Explorer Application Hang events during the accepted R02R6 validation window
- exact accepted Main application and Sensor Broker hashes embedded in the published installer
- remote GitHub re-download and SHA-256 verification of all four published release assets: PASS

Two Explorer `Application Hang` Event 1002 records occurred after the accepted validation window. Their causality to Taskbar Monitor Enhanced remains **unproven**. The TBME process survived the Explorer restarts and successfully recovered its taskbar attachment. Full details are recorded in [`docs/FINAL_ACCEPTANCE_v1.1.0.md`](docs/FINAL_ACCEPTANCE_v1.1.0.md).

See [`RELEASE_NOTES_v1.1.0.md`](RELEASE_NOTES_v1.1.0.md) for the complete release notes.

## Code signing status

The published 1.1.0 installer is **not Authenticode-signed**, so Windows Defender SmartScreen may show **Unknown publisher** on first launch.

The project has applied / is applying for the SignPath Foundation open-source code-signing program for future releases: **Free code signing provided by SignPath.io, certificate by SignPath Foundation.** This statement is conditional on project acceptance by SignPath Foundation; the current 1.1.0 release remains unsigned.

See [`CODE_SIGNING.md`](CODE_SIGNING.md) for the signing policy and [`PRIVACY.md`](PRIVACY.md) for the privacy statement.

A signed build will still be subject to the project's full runtime and lifecycle acceptance process before publication; signing alone does not promote a build to an accepted release.

## Why this project exists

Taskbar Monitor Enhanced is designed to feel like part of Windows rather than a separate monitoring application: compact enough to leave running all day, useful at a glance, customizable without being distracting, and resilient when the Windows shell restarts.

## Highlights

- CPU, RAM, disk, GPU, VRAM, upload and download monitoring
- CPU Package / vendor-neutral CPU temperature telemetry
- AMD Radeon GPU temperature fallback through AMD ADLX 1.1 when LibreHardwareMonitor does not expose an AMD GPU temperature sensor
- NVIDIA, AMD, and Intel GPU telemetry paths
- 14 built-in themes
- live sparklines and theme-aware network graphs
- left, center, and right taskbar placement
- compact taskbar rendering with vertical DL/UL stacking in narrow Network cards
- direct left-click and right-click interaction without click-through behavior
- no-activate taskbar interaction
- stable Start/Search/taskbar placement and persistent shell-style self-heal
- automatic Explorer/taskbar recovery
- non-elevated main application
- protected hardware-sensor broker with watchdog supervision
- Start-with-Windows support
- Desktop and Start Menu shortcuts
- upgrade, uninstall, clean-install, and post-install runtime validation

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
