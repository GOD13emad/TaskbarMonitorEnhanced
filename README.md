# Taskbar Monitor Enhanced

A lightweight Windows taskbar system monitor that keeps useful hardware and performance telemetry visible without forcing you to open a separate dashboard.

## Official download

**Current stable release: 1.1.1**

Download the official build from the [Taskbar Monitor Enhanced 1.1.1 release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.1).

Accepted release assets:

- `TaskbarMonitorEnhanced_Setup_1.1.1.exe`
  - SHA-256: `DEC349FF188EA73BF7AA991110B9534851ED3F017B536D3F9DC24C286FBCEF1B`
- `TaskbarMonitorEnhanced_1.1.1_SOURCE.zip`
  - SHA-256: `BAF407D5B41395F8A9BCAC3BDBB27C26A522C18CC89CFF0A3D40669D50C86FDA`

The release also includes `SHA256SUMS_v1.1.1.txt` and `RELEASE_MANIFEST_v1.1.1.json` for independent verification.

> **Do not use Code > Download ZIP as the accepted release package.** GitHub repository snapshots are not the authoritative v1.1.1 source package. Use the explicitly attached, hash-identified `TaskbarMonitorEnhanced_1.1.1_SOURCE.zip` release asset.

## What's new in 1.1.1

Version 1.1.1 is a stability-hardening release.

- external `nvidia-smi.exe` polling is disabled by default, eliminating the dominant console-process hot path observed during diagnosis
- WDDM and LibreHardwareMonitor remain the normal GPU telemetry paths
- diagnostic NVIDIA SMI opt-in remains available through `TBME_ENABLE_NVIDIA_SMI=1`
- shell watchdog frequency reduced from every 40 ms to every 250 ms
- style-integrity checks reduced from every 500 ms to every 2000 ms
- heavy Safe Placement UI-Automation scanning removed from the watchdog hot path
- normal placement reevaluation throttled to at least 5000 ms
- all accepted v1.1.0 multi-hardware, storage, hover, recovery and verified-update features retained

## Release validation

The accepted R06 v1.1.1 stability candidate completed build, self-test, runtime smoke and real-use acceptance. Explorer PID remained unchanged, no relevant Explorer Event 1000/1002 was recorded during the acceptance window, and the user verdict was PASS. The installed accepted hashes are:

- main EXE: `D2112BCB9C14D3916CD888449101701F4EC3E3FFF61EE2C83C7BB6DD97840CB4`
- main source: `125E48D3054025AA98F2E1459060E1BAEF7B99548A6C771FB99C99600BD84BBA`

See [`docs/FINAL_ACCEPTANCE_v1.1.1.md`](docs/FINAL_ACCEPTANCE_v1.1.1.md) and [`RELEASE_NOTES_v1.1.1.md`](RELEASE_NOTES_v1.1.1.md) for the evidence and residual-risk statement.

## Code signing status

The published 1.1.1 installer is **not Authenticode-signed**, so Windows Defender SmartScreen may show **Unknown publisher** on first launch.

The project has applied / is applying for the SignPath Foundation open-source code-signing program for future releases: **Free code signing provided by SignPath.io, certificate by SignPath Foundation.** This statement is conditional on project acceptance by SignPath Foundation; the current 1.1.1 release remains unsigned.

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
