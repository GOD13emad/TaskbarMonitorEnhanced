# R22 RC10 Accepted Precursor — 2026-09-26

Status: ACCEPTED PRECURSOR FOR FINAL v1.1.2 IDENTITY DERIVATION

This record preserves the evidence-backed RC10 runtime acceptance reached before final release identity mutation. It does not promote RC10 to public Stable/Latest.

## Accepted RC10 gates

- Exact protected RC10 install: PASS. Installed hashes matched RC10 manifest:
  - Main: 6BBD6BF7A559DE4C2C59FE4027FA2BA30EC82765B3C6F4000FF34375C72B2550
  - Broker: 7BA4E75514D69EC20D7FD478C3F8769A2D22BB48AC1B19900D946DF4FB64D907
  - Supervisor: FE5EB08FC2ED2D2C7CAA70F7EA48965C409E2093E3BB054CE8AE60003D85D97D
  - Setup: 488FAC9FE5C98943F8A90DE58EBF70B999EE0C4AD4E01933B0090FDEA73BC400
- Theme proof: PASS for all 14 themes using the real RC10 renderer.
- Compact proof: PASS at 592 px and 500 px; 126 layout checks, zero overflow.
- CPU 25 s soft stall: PASS. Slow/stale condition was observed while PID and restart count remained unchanged; the same worker recovered.
- CPU >60 s hard stall: PASS. Supervisor emitted STALE_OUTPUT_HARD at about 60.7 s, replaced the worker, incremented restart count, and restored healthy telemetry.
- Post-fault soak: PASS. Corrected harness completed 45/45 samples with zero bad samples; PID/restart count stayed stable and failure counter returned to zero.
- Real S3 suspend/resume: PASS. Physical S3 cycle wall gap 68.848 s; resume notification observed; no new worker/storage failures; post-S3 45-sample soak PASS with zero bad samples.
- Downstream runtime audit: PASS:
  - Main integrity RID 8192 / Medium.
  - 300 Main module samples; zero LibreHardwareMonitor modules loaded in Main.
  - 24/24 taskbar geometry/parenting samples stable at 1100x48 with direct Shell_TrayWnd parent.
  - Broker and Supervisor PE subsystem = 2 / WINDOWS_GUI.
  - Zero sensor-owned console hosts.
  - Relevant Application and TaskScheduler error count = 0 in audit window.
  - Health = PASS / STABLE.

## Confirmed harness-only false negatives

Two failures were confirmed as test-harness defects rather than product defects and were corrected without blind product reruns:
1. Hard-stall harness initially required CpuConsecutiveFailures=0 too early, although RC10 intentionally clears that counter only after 60 s continuous health.
2. Initial post-fault soak double-applied the +03:30 offset after ConvertFrom-Json materialized TimestampUtc as DateTime. R1 used DateTime/DateTimeOffset correctly and PASSed.

The post-S3 active-beacon screen capture also failed while the foreground desktop was Windows Default Lock Screen. Win32 overlay state remained Visible=true, ParentOk=true, Cloaked=0, Rect=1100x48. This is an environmental screen-capture false negative, not a taskbar structural failure.

## External authoritative evidence

Current evidence root:
C:\Users\Aa.Emad\AppData\Local\TaskbarMonitorEnhanced\00_PROJECT_CONTROL\EVIDENCE\R22_FINAL_THEME_RELEASE_20260926

Key evidence:
- R22_RC10_THEME_WATCHDOG_ACCEPTANCE.json
- CPU_WATCHDOG_FAULT_INJECTION_RESULT.json
- POSTFAULT_SOAK_90S_R1.json
- RC10_REAL_S3.json
- R22_DOWNSTREAM_AUDIT.json
- THEME_CONTACT_SHEET.png
- themeproof\THEME_PROOF_MANIFEST.json
- compactproof\COMPACT_PROOF_MANIFEST.json

## Finalization rule

Final v1.1.2 must be derived from this accepted RC10 behavior with only release-identity / release-control / documentation-gallery changes. Any behavioral code change reopens affected runtime gates.
