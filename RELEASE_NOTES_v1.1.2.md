# Taskbar Monitor Enhanced v1.1.2-rc2 — R21 Production Hardening

Release-candidate engineering build focused on long-run stability, lower telemetry overhead, sensor failure containment, diagnostics, and update trust.

## Runtime and sensor architecture

- LibreHardwareMonitor is no longer loaded in the main UI process.
- CPU and GPU native sensor reads run in independent broker processes.
- Storage temperature probing runs as a bounded one-shot worker.
- Supervisor health distinguishes fresh transport from actual sensor-data availability.
- CPU, GPU, and storage workers start in a staggered sequence to reduce low-level hardware contention.
- Stale/hung workers use bounded exponential backoff and termination-pending protection to prevent restart storms.
- Long suspend/resume gaps recycle native sensor workers before reuse.

## Performance

- CPU usage uses Windows GetSystemTimes instead of Processor PerformanceCounter polling.
- Static CPU topology is cached for five minutes.
- Network-interface topology is cached for 30 seconds.
- GPU WDDM/WMI telemetry is now fallback-only when the isolated GPU broker has no usable load data.
- User telemetry sampling is clamped to 1000–5000 ms.
- CPU temperature data automatically becomes unavailable when it is stale instead of displaying an old value as current.

## Diagnostics and updates

- Added --healthprobe <json> for machine-readable supervisor and broker freshness/transport checks.
- Added an explicit Repair protected sensors action in Diagnostics; elevation is requested only after user confirmation.
- Added a Diagnostics tab and taskbar-menu shortcut.
- Diagnostics show runtime paths, sensor supervisor state, telemetry freshness, build identity, and current hardware availability.
- Diagnostic reports can be saved as text for support/auditing.
- Automatic update installation now requires both GitHub SHA-256 asset metadata and an immutable GitHub Release. Mutable releases remain available for manual review only.

## Dependency decision

- LibreHardwareMonitor 0.9.6 remains the pinned production backend for this candidate.
- A current upstream nightly was tested separately during R21 engineering but did not improve the observed CPU worker behavior, so it was not promoted into the production dependency set.

## Validation status

Engineering evidence includes zero-warning builds of the app/broker/supervisor/setup, self-test PASS, 14-theme proof PASS, compact proof at 592/500 px with zero overflow, deterministic stale-worker recovery PASS, and a no-screen Windows taskbar canary with 24/24 stable direct-child geometry samples. Live validation read CPU temperature through the elevated broker, full RTX 3080 telemetry including temperature through the isolated GPU broker, and three elevated storage-temperature sensors on the validation machine.

This is a release candidate, not a final public release. Build/self-test and isolated supervisor fault-injection gates pass. Final elevated CPU/storage validation and installed canary/soak remain required before public release.
