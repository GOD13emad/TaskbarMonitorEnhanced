# PROJECT BRAIN — Taskbar Monitor Enhanced

Brain Version: PB-2026-09-19-R21-RC8-INSTALLED1
Status: CURRENT
Updated: 2026-09-19T19:55:00+03:30

## Authority

- Public Stable/Latest remains v1.1.1.
- Current engineering candidate: v1.1.2-rc8 / R21 Main Integrity Boundary Hardening on `audit/r21-final-hardening-rc8`.
- Binary source authority: `6965f3852b5361169d480bab984c9bef065e1e70`.
- Build-evidence authority before installed acceptance: `d7c8d4f66b84b36949019c6789be96514f73a0b5`.
- Installed Main SHA-256: `5172A2AC11B356D678122C0FD196CA24E8636648B63894D05BDD9C126D53E000`.
- Protected Broker SHA-256: `DBB2AF15D116564E3C287D1F5EC04B62D5BBE803048E52B855D9B5BF37316FCB`.
- Protected Supervisor SHA-256: `1A9AAA02D7FBA3DAF876A6399000BCA8A21CEC158F9FD5D5E2D0D2F99FF68DF9`.
- RC8 Setup SHA-256: `12BCA03A9BEA803269712694B5FC3EAFAB5BDE514C60E2D520142B022BC496F4`.
- Do not claim public FINAL/STABLE until one real suspend/resume post-check passes and the accepted immutable public release is promoted.

## Objective / DoD

Deliver a long-run-stable Windows taskbar monitor with truthful telemetry, no LibreHardwareMonitor in Main, process-isolated protected sensor access, bounded self-healing, no persistent sensor console windows, a Medium-integrity Main UI, deterministic/reproducible release outputs, auditable update trust, and an install/uninstall surface suitable for normal daily use.

## Accepted architecture

- Main UI runs non-elevated at Medium integrity.
- CPU/GPU persistent sensor reads and storage one-shot reads run in isolated Broker processes under a Supervisor.
- Supervisor/Broker live in protected Program Files and are launched by the pre-authorized Scheduled Task at Highest run level.
- Child sensor workers are Job-contained with kill-on-close semantics.
- LibreHardwareMonitor 0.9.6 and PawnIO 2.2.0 remain dependency-lock pinned by URL and SHA-256.
- Broker and Supervisor are `WinExe` / PE `WINDOWS_GUI` subsystem=2, preventing persistent console surfaces.
- Main never loads LibreHardwareMonitor.
- RC8 reuses the exact accepted RC7 protected pair only after hash + fresh versioned health + Job containment + transport/data gates pass.
- Whole-Setup elevation does not auto-launch Main; normal non-elevated Setup launches Main at Medium integrity.
- Public update installation requires exact asset identity, SHA-256 metadata and immutable-release policy.

## Root causes closed in RC7/RC8

### Repeated NO_CURRENT_OUTPUT_AFTER_GRACE restarts
RC6 Supervisor treated a single missing/unobservable output timestamp after a healthy sample as immediate failure. Baseline regression reproduced a false restart during a 3-second output gap. RC7 now honors the existing 15-second last-known-good freshness budget; a 3-second gap is tolerated while a persistent >15-second gap still restarts.

### Persistent sensor console window
The Scheduled Task directly launched a CUI Supervisor. RC7 changes both Broker and Supervisor to `WinExe` / `WINDOWS_GUI` and Build-R21 now fails unless both PE subsystem values equal 2.

### Elevated Main inheritance
A whole-Setup elevated fallback could launch Main with the elevated parent token. RC8 skips Main auto-launch when Setup is elevated; normal non-elevated Setup launches Main itself. This follows Windows UAC least-privilege process-boundary guidance.

## Installed acceptance evidence

PASS:
- RC8 non-elevated install completed in 2.17 s without UAC.
- `install_state.json`: `SensorLayerStatus=READY`, `SensorLayerMode=REUSED_EXACT_RC7_FOR_RC8`, `MainLaunchMode=LAUNCHED_NON_ELEVATED_SETUP`.
- Protected Broker/Supervisor hashes remained byte-for-byte unchanged from accepted RC7.
- Main process integrity: Medium, RID 8192.
- Healthprobe: PASS; R21=true; Job containment=true; ResilienceState=STABLE; CPU/GPU/storage transport and data all healthy.
- Windowless runtime proof: one Supervisor, persistent Brokers parented to it, zero sensor-owned `conhost/OpenConsole` children.
- Taskbar canary after RC8: 24/24 samples stable, visible and direct child of `Shell_TrayWnd`; geometry 1100x48.
- Main module isolation: 300/300 samples with zero LibreHardwareMonitor module load.
- Recent relevant Application/TaskScheduler errors: 0.
- 90-second live soak: 19/19 samples healthy; CPU/GPU restart counters unchanged; zero post-RC7 `NO_CURRENT_OUTPUT_AFTER_GRACE` / observation-gap failures.
- Since the final RC7 CPU restart at 15:29:40Z, the CPU worker remained stable through the later RC8 acceptance window.

Observed but not overclaimed:
- Two CPU `WORKER_EXIT_-1` events occurred during the first two minutes after protected RC7 installation. Broker log had no `BROKER_FATAL`, Event Log had no application/.NET crash, and the condition has not recurred. Root cause remains UNVERIFIED; retained as installation-transition evidence/regression watch item.

## Install surface

PASS:
- Start Menu main shortcut points to the installed Main.
- Start Menu protected-sensor Repair shortcut points to `Uninstall.exe /repair-sensors`.
- Desktop shortcut points to installed Main.
- HKCU uninstall registration shows version 1.1.2-rc8.
- Startup uses a single HKCU Run entry; `config.json StartWithWindows=true`; no duplicate Startup-folder launcher.
- Scheduled Task is Running, Highest, Interactive, IgnoreNew, restart count=3, restart interval=PT1M.
- Non-elevated GENERIC_WRITE open on Broker and Supervisor fails with Win32 Access Denied (5).

## Build / release-chain evidence

PASS:
- App/Broker/Supervisor/Setup builds: 0 warnings / 0 errors.
- Built-in self-test: PASS / PUBLIC_VERSION=1.1.2-rc8.
- Setup resource/policy verify: PASS / RC8_APP_REUSES_EXACT_RC7_SENSOR.
- Sensor PE windowless guard: PASS.
- Clean-clone byte-for-byte determinism: PASS.
- SPDX 2.3 SBOM generation: PASS.
- GitHub self-hosted RC8 finalize run `35452831037`: SUCCESS at `d7c8d4f66b84b36949019c6789be96514f73a0b5`.
- Independent API read-back: Main provenance=1, RC8 Setup provenance=1, Setup SBOM=1; Broker/Supervisor provenance counts=2 because their exact RC7 bytes were attested in both RC7 and RC8 workflows.
- RC8 draft prerelease exists and is not public; public Stable/Latest remains v1.1.1.
- Repository Immutable Releases is enabled.

## Critical Path <- CURRENT

1. Keep RC8 installed and avoid further source/runtime mutation unless evidence shows a new defect.
2. Perform one real suspend/resume cycle and immediately rerun health/taskbar/module/EventLog/windowless checks.
3. If that physical validation passes, update acceptance records and promote the already-attested RC8 candidate through the immutable public release path.
4. If the physical validation fails, treat the exact observed failure as the single next mutation objective; do not blindly rerun or broaden the architecture.

## Evidence

- `r21_evidence/RC8_LIVE_SOAK_90S.json`
- `r21_evidence/INSTALLED_R21_TASKBAR_CANARY.json`
- `r21_evidence/INSTALLED_R21_MODULE_ISOLATION.json`
- Local cumulative evidence/knowledge under `%LOCALAPPDATA%\TaskbarMonitorEnhanced\00_PROJECT_CONTROL`.
- GitHub RC8 run `35452831037` and draft release evidence assets.

## HISTORY

- v1.1.1 remains the public rollback/stable authority.
- R20/R21 isolated native sensor access from Main and added bounded supervision, diagnostics, reproducible builds and release-chain hardening.
- RC6 introduced component-aware least-privilege reuse but retained false positive output-gap restarts.
- RC7 fixed transient output-gap restarts and CUI sensor console windows; exact windowless protected pair was installed and accepted.
- RC8 preserves that exact protected pair and hardens Main launch integrity; installed RC8 acceptance and GitHub release-chain gates pass.
- Physical suspend/resume validation is the only remaining acceptance gate before public Stable/Latest promotion.
