# Taskbar Monitor Enhanced 1.1.1

## Stability hardening

- External `nvidia-smi.exe` polling is disabled by default in the real-time GPU telemetry path. Windows WDDM and LibreHardwareMonitor remain the normal GPU data sources.
- NVIDIA SMI remains available only as an explicit diagnostic opt-in with `TBME_ENABLE_NVIDIA_SMI=1`.
- Shell visibility watchdog interval increased from 40 ms to 250 ms.
- Style-integrity checks reduced from every 500 ms to every 2000 ms.
- Heavy UI Automation Safe Placement scanning was removed from the watchdog hot path.
- Normal Safe Placement reevaluation is throttled to at least 5000 ms.
- v1.1.0 multi-hardware telemetry, disk temperature/throughput, hover details, Explorer recovery, themes, configuration, and SHA-256-verified GitHub updates are retained.

## Why this update

A Windows Security Event 4688 capture on the affected validation workstation recorded 132 `conhost.exe` creations parented by `nvidia-smi.exe` during an approximately 134-second observation window. This was by far the dominant console-process path and matched the repeated visible console flashes reported during gaming.

Version 1.1.1 removes that external-process polling hot path by default. Separately, v1.1.0 had residual Windows Explorer Application Hang events whose causality to TBME remained unproven. Version 1.1.1 therefore also reduces periodic shell/UI-Automation pressure without claiming those historical Explorer hangs were definitively caused by TBME.

## Local acceptance for 1.1.1

Accepted stability candidate: `TBME_V1_1_1_STABILITY_HARDENING_R06`.

- build: PASS
- self-test: PASS
- installed file version: `1.1.1.0`
- user acceptance verdict: PASS
- Explorer PID before/after acceptance: unchanged (`3992`)
- Explorer Application Error 1000 during acceptance window: `0`
- Explorer Application Hang 1002 during acceptance window: `0`
- rollback required: NO
- candidate committed locally: YES
- external NVIDIA-SMI polling default: OFF
- shell watchdog: 250 ms
- style-integrity interval: 2000 ms
- placement refresh minimum: 5000 ms
- watchdog UI-Automation placement scan: OFF

## Accepted engineering hashes

- Main EXE: `D2112BCB9C14D3916CD888449101701F4EC3E3FFF61EE2C83C7BB6DD97840CB4`
- Main source: `125E48D3054025AA98F2E1459060E1BAEF7B99548A6C771FB99C99600BD84BBA`

The public installer and corresponding-source package are separately hash-identified after release packaging.

## Compatibility

- Windows x64.
- Main application remains non-elevated.
- Existing hardware-sensor broker/supervisor components are unchanged in this stability revision.
- Existing settings are intended to be preserved during upgrade.
- No configuration migration is required.

## Residual risk

The R06 gate was a targeted real-use acceptance window, not a new multi-hour endurance campaign. Historical Explorer hangs from v1.1.0 remain causally unproven. The release therefore records the specific local acceptance evidence above rather than claiming universal elimination of all possible Explorer/taskbar hangs.

## License

GNU General Public License v3.0.
