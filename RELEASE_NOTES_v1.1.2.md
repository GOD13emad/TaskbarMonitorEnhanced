# Taskbar Monitor Enhanced v1.1.2-rc8 — R21 Production Hardening

RC8 is the current engineering candidate for the next v1.1.2 release. It is installed and passes the available local runtime, reproducibility and supply-chain gates; public Stable/Latest remains v1.1.1 until one real suspend/resume post-check is accepted.

## Runtime architecture

- LibreHardwareMonitor is not loaded in the Main UI process.
- CPU and GPU hardware reads run in independent protected broker workers.
- Storage temperature probing runs as a bounded one-shot worker.
- A protected Supervisor owns worker lifecycle, freshness, bounded backoff and recovery.
- All sensor children are attached to a kill-on-close Windows Job Object.
- CPU/GPU/storage transport health is separated from actual sensor-data availability.
- Static CPU/disk/RAM/network topology is cached; power/resume paths invalidate or recycle the appropriate state.
- Main remains a normal user application at Medium integrity.

## RC7 sensor stability and windowless hardening retained by RC8

RC7 fixed the repeated `NO_CURRENT_OUTPUT_AFTER_GRACE` false positive: after a worker has produced valid output, a transient missing/unobservable file observation is tolerated while the last-known-good sample remains within the existing 15-second freshness budget. A persistent gap beyond that budget still causes bounded restart. A dedicated regression reproduced the RC6 short-gap failure and proved that RC7 tolerates a 3-second gap but restarts after a persistent >15-second gap.

Broker and Supervisor are now built as `WinExe` / PE `WINDOWS_GUI` subsystem=2. Build-R21 explicitly rejects any regression back to a console subsystem. On the installed machine, the live sensor process tree has zero sensor-owned `conhost/OpenConsole` children.

RC8 preserves the exact accepted RC7 protected hashes:
- Broker: `DBB2AF15D116564E3C287D1F5EC04B62D5BBE803048E52B855D9B5BF37316FCB`
- Supervisor: `1A9AAA02D7FBA3DAF876A6399000BCA8A21CEC158F9FD5D5E2D0D2F99FF68DF9`

## RC8 Main integrity boundary

RC8 fixes a least-privilege edge case in whole-Setup elevation. If Setup itself is elevated, it no longer auto-launches Main from that elevated token. Normal non-elevated Setup still auto-launches Main.

The installed acceptance path used normal non-elevated Setup, reused the exact protected RC7 sensor pair without UAC, and recorded:
- `SensorLayerStatus=READY`
- `SensorLayerMode=REUSED_EXACT_RC7_FOR_RC8`
- `MainLaunchMode=LAUNCHED_NON_ELEVATED_SETUP`

The running Main was independently measured at Medium integrity (RID 8192).

## Installed acceptance

PASS:
- exact RC8 Main SHA-256: `5172A2AC11B356D678122C0FD196CA24E8636648B63894D05BDD9C126D53E000`
- exact RC8 Setup SHA-256: `12BCA03A9BEA803269712694B5FC3EAFAB5BDE514C60E2D520142B022BC496F4`
- HealthProbe PASS / R21 / Job containment / STABLE
- CPU/GPU/storage transport and data available
- zero sensor-owned console-host children
- taskbar geometry 24/24 stable at 1100x48 with correct `Shell_TrayWnd` parenting
- Main module isolation 300/300 samples with no LibreHardwareMonitor
- zero recent relevant Application/TaskScheduler errors
- 90-second live soak: 19/19 healthy snapshots; no CPU/GPU restart-counter change
- no `NO_CURRENT_OUTPUT_AFTER_GRACE` or observation-gap failure after protected RC7 installation
- Start Menu, Desktop, HKCU Run startup, uninstall registration and protected-sensor Repair entry verified
- protected Program Files Broker/Supervisor reject non-elevated GENERIC_WRITE access

Two CPU `WORKER_EXIT_-1` events occurred in the first two minutes after protected RC7 installation. No broker fatal exception or Windows application/.NET crash accompanied them, and they have not recurred. Their exact external termination cause remains unverified; the events remain recorded as a regression watch item rather than being silently discarded.

## Build and supply-chain verification

PASS:
- zero-warning/zero-error App/Broker/Supervisor/Setup build
- built-in self-test
- Setup resource/policy verification
- explicit PE subsystem=2 sensor guard
- clean-clone byte-for-byte determinism
- SPDX 2.3 SBOM
- GitHub self-hosted finalization run `35452831037`
- GitHub provenance attestations for Main/Broker/Supervisor/Setup
- GitHub SBOM attestation for Setup
- independent repository API read-back of persisted attestations
- RC8 draft prerelease evidence upload
- immutable-release repository policy enabled

Public Stable/Latest remains v1.1.1. RC8 is not promoted publicly until the remaining physical suspend/resume validation passes.

## Remaining acceptance gate

One real suspend/resume cycle must be performed on the installed RC8 system, followed immediately by:
- HealthProbe / freshness / Job containment
- taskbar geometry and parenting
- Main module isolation
- sensor windowless process-tree check
- Event Log check
- restart-counter comparison

If those checks pass, RC8 is eligible for final v1.1.2 Stable/Latest promotion. If they fail, the exact observed power-transition failure becomes the next isolated mutation objective.
