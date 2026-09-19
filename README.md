# Taskbar Monitor Enhanced

A lightweight Windows taskbar system monitor for live CPU, RAM, disk, network, GPU, VRAM and temperature telemetry.

## Latest stable release: v1.1.1

Version **v1.1.1** is the current Stable/Latest release.

Existing users can update directly through the application's built-in GitHub update flow, or download the installer from:

https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.1

v1.1.1 includes:

- removal of default NVIDIA-SMI realtime polling that caused repeated console-host launches on the validation system
- low-pressure taskbar-child shell integration
- watchdog 500 ms, host poll 1000 ms, style/placement health 5000 ms
- event/geometry-driven Safe Placement work
- single-instance Settings behavior

Accepted assets and hashes are published in `SHA256SUMS_v1.1.1.txt` and `RELEASE_MANIFEST_v1.1.1.json`.


## Development candidate: v1.1.2-rc10 (R21)

v1.1.2-rc10 is the active engineering release candidate, not the current Stable/Latest release. RC10 retains the RC9 real-S3 power-notification fix and adds a CPU-specific 60-second hard stall watchdog while keeping the 15-second UI freshness boundary. This prevents short LibreHardwareMonitor/PawnIO CPU read stalls from causing restart storms while still terminating a truly stuck worker. Stable/Latest remains v1.1.1 until RC10 fault-injection, soak, physical suspend/resume, reproducibility and publication gates pass.

R21 adds:

- process-isolated CPU, GPU and storage hardware-sensor workers
- staggered worker startup, bounded exponential backoff and restart-storm containment
- Windows Job Object kill-on-close containment so abrupt Supervisor termination cannot leave orphan sensor workers
- transport health separated from sensor-data availability
- power-aware suspend/resume telemetry reset and native-worker recycling
- Windows GetSystemTimes CPU usage sampling and cached CPU/network topology
- fallback-only WDDM GPU polling and throttled CPU-temperature WMI/ACPI fallbacks
- stale-temperature invalidation instead of presenting old data as current
- Diagnostics UI with saveable support reports and protected-sensor repair action
- a --healthprobe JSON command for machine-readable sensor-supervisor health
- automatic update installation gated by both GitHub SHA-256 asset metadata and immutable GitHub Releases
- installer task policy hardened to RestartCount=3 and MultipleInstances=IgnoreNew
- conservative non-elevated Main self-heal for a stale/missing READY Sensor Supervisor task (90s grace/staleness, 180s retry cooldown)
- least-privilege component-aware installer: exact hash-pinned healthy R21 sensor layers can be reused without UAC on app-only updates; unknown/stale layers still require elevated transactional repair
- RC6 compatible-reuse live canary: PASS; install 2.38s, no UAC, READY, REUSED_COMPATIBLE_RC4, protected RC4 hashes unchanged, post-install health recovery returned to zero active failures
- SPDX 2.3 SBOM generation plus GitHub/Sigstore build-provenance and SBOM attestations in CI, with third-party actions pinned to immutable commit SHAs
- atomic configuration writes with automatic backup recovery after interrupted/corrupt saves
- bounded log retention/rotation for long-running main and protected sensor logs
- exact-version installer-asset matching plus strict sha256:64-hex validation in the updater
- machine-readable failure/recovery timestamps, worker ages and STABLE / RECOVERING / RECOVERED_RECENTLY resilience state
- optional isolated CPU package-power and GPU power/fan telemetry; unsupported sensors remain N/A

Current RC6 engineering evidence includes zero-warning builds for the app/broker/supervisor/setup, self-test PASS, SPDX 2.3 SBOM PASS, clean-clone byte-identical determinism PASS, all prior 14-theme/compact proofs, RC4 live Supervisor-stop self-heal PASS, RC5 Main exact-hash install PASS, 24/24 stable direct-taskbar-child geometry samples, 300/300 main-process module samples with no LibreHardwareMonitor, and zero relevant recent Application Event errors. Full RC5 protected-layer acceptance is intentionally not claimed until administrator/UAC completion replaces the still-healthy RC4 Broker/Supervisor.

See docs/R21_ACCEPTANCE_STATUS.md and RELEASE_NOTES_v1.1.2.md.

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
