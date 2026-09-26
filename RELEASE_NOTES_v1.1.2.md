# Taskbar Monitor Enhanced v1.1.2 — R21 Production Hardening

v1.1.2 is the final R21 release identity. It is derived from the RC10 runtime behavior that completed hardware, watchdog, suspend/resume, taskbar, integrity and stability acceptance. The final identity changes release/version metadata and documentation only; it does not introduce new sensor, watchdog or rendering behavior.

## Reliability architecture

- Main remains Medium integrity; LibreHardwareMonitor stays out of Main.
- CPU, GPU and storage hardware access remains process-isolated behind the protected Supervisor.
- Broker/Supervisor remain WINDOWS_GUI and sensor children remain under kill-on-close Job containment.
- CPU UI freshness remains 15 seconds; stale temperature becomes unavailable instead of being presented as current.
- CPU hard-stall watchdog remains 60 seconds.
- Windows suspend/resume notifications recycle or invalidate affected sensor state before freshness decisions.
- LibreHardwareMonitor 0.9.6 and PawnIO 2.2.0 remain pinned.

## Evidence-backed acceptance inherited from RC10

- all 14 live-data theme renders passed; compact 592 px and 500 px proofs had zero overflow;
- 25-second CPU soft stall caused no restart and the same worker recovered;
- >60-second CPU hard stall triggered bounded replacement and healthy recovery;
- corrected 90-second post-fault soak passed 45/45 samples;
- real S3 suspend/resume observed the resume notification, zero new worker/storage failures and a 45-sample post-S3 soak PASS;
- taskbar geometry/parenting passed 24/24 at 1100x48;
- Main module isolation passed 300/300 with zero LibreHardwareMonitor modules;
- Main integrity was Medium / RID 8192;
- Broker/Supervisor PE subsystem was WINDOWS_GUI / 2 with zero sensor-owned console hosts;
- relevant Application and TaskScheduler error count was zero;
- HealthProbe was PASS / STABLE.

Two apparent qualification failures were confirmed as test-harness defects: an early hard-stall recovery criterion that ignored the deliberate 60-second stable-recovery counter, and a PowerShell DateTime offset double-application in the first soak harness. Both causes were corrected and preserved in evidence.

A post-S3 active-beacon screen-capture probe ran while Windows Default Lock Screen was foreground. Win32 structural checks still reported the taskbar overlay visible, uncloaked, correctly parented and 1100x48; the capture miss is retained as an environmental false negative.

## Final release gates

The final identity still requires zero-warning/zero-error build, Setup /verify, self-test, clean-clone byte determinism, SPDX 2.3 SBOM, exact installed hash match, proportional runtime regression, and GitHub provenance/SBOM attestation before immutable Stable/Latest publication.

See docs/R21_ACCEPTANCE_STATUS.md and docs/acceptance/R22_RC10_ACCEPTED_PRECURSOR_20260926.md.
