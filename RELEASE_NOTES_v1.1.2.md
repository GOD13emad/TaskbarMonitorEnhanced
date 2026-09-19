# Taskbar Monitor Enhanced v1.1.2-rc6 — R21 Production Hardening

Release-candidate engineering build focused on long-run stability, lower telemetry overhead, sensor failure containment, diagnostics, and update trust.

## Runtime and sensor architecture

- LibreHardwareMonitor is no longer loaded in the main UI process.
- CPU and GPU native sensor reads run in independent broker processes.
- Storage temperature probing runs as a bounded one-shot worker.
- Supervisor health distinguishes fresh transport from actual sensor-data availability.
- CPU, GPU, and storage workers start in a staggered sequence to reduce low-level hardware contention.
- Stale/hung workers use bounded exponential backoff and termination-pending protection to prevent restart storms.
- All isolated workers are attached to a Windows Job Object with kill-on-close semantics, so abrupt Supervisor termination also tears down children at the OS boundary.
- Long suspend/resume gaps recycle native sensor workers before reuse.

## Performance

- CPU usage uses Windows GetSystemTimes instead of Processor PerformanceCounter polling.
- Static CPU topology is cached for five minutes.
- Static disk topology is cached for five minutes and RAM-module topology for ten minutes; suspend/resume invalidates these caches immediately.
- Network-interface topology is cached for 30 seconds.
- GPU WDDM/WMI telemetry is now fallback-only when the isolated GPU broker has no usable load data.
- User telemetry sampling is clamped to 1000–5000 ms.
- CPU temperature data automatically becomes unavailable when it is stale instead of displaying an old value as current.
- CPU broker JSON now uses the same shared-read/retry path as GPU and storage, eliminating brief file-sharing races while the broker atomically replaces telemetry output.

## Diagnostics and updates

- Added --healthprobe <json> for machine-readable supervisor and broker freshness/transport checks.
- Added an explicit Repair protected sensors action in Diagnostics; elevation is requested only after user confirmation.
- Bounded the administrator-consent launch itself: if UAC/ShellExecute does not complete within 30 seconds, Setup continues as a clearly marked DEGRADED install instead of remaining half-installed indefinitely.
- install_state.json records SensorLayerStatus so a degraded/mixed sensor layer cannot be mistaken for a fully healthy R21 installation.
- Protected sensor installation is transactional: the previous Program Files sensor payload and Scheduled Task definition are captured before mutation and restored automatically if R21 task setup or transport-health validation fails.
- Rollback deletes R21 split telemetry before restarting the previous sensor layer, preventing stale GPU/storage/supervisor JSON from leaking across architectures.
- Added a Diagnostics tab and taskbar-menu shortcut.
- Diagnostics show runtime paths, sensor supervisor state, telemetry freshness, build identity, and current hardware availability.
- Diagnostic reports can be saved as text for support/auditing.
- Automatic update installation now requires both GitHub SHA-256 asset metadata and an immutable GitHub Release. Mutable releases remain available for manual review only.

## RC6 hardening additions

- Configuration persistence now uses atomic replacement with a recoverable backup instead of direct overwrite.
- Main logs have bounded retention; protected sensor logs rotate at 4 MiB with bounded backup generations.
- Automatic updates require the exact setup filename for the advertised version and an exact sha256:64-hex digest.
- Health output includes supervisor uptime, worker age, last-failure reason/time, last-recovery time and a resilience state.
- CPU package power and GPU power/fan telemetry are optional fields produced only by the isolated brokers; missing/invalid values remain unavailable instead of being guessed.
- Live RC6 broker validation on the RTX 3080 produced valid power and fan telemetry; the CPU zero-watt false-positive found during testing was rejected by a >0.1 W validity guard.
- Supervisor test lanes pass steady state, stale-worker isolation, long-gap recycle, log rotation and failure-to-recovery timestamp propagation.

## RC6 final log-pressure hardening

- GPU stale-state logging is normalized so a changing age value no longer creates a new log state every telemetry poll.
- Repeated GPU stale-state messages are bounded to one every 30 seconds while immediate READY/STALE transitions remain observable.
- The production-threshold RC4 Supervisor-stop fault injection proved the inherited Main self-heal path end to end before this narrow logging change.

## RC6 least-privilege component reuse

- Normal install/update first checks whether the existing protected Broker/Supervisor pair is an exact allowlisted SHA-256 pair and whether its live state is younger than 15 seconds, version-matched, Job-contained and healthy on CPU/GPU/storage transport and data lanes.
- If those gates pass, Setup reuses the protected layer without requesting administrator consent; unknown, modified, stale or unhealthy layers still use the transactional elevated install/rollback path.
- Explicit Repair Hardware Sensors still forces the current protected payload and therefore remains an administrator operation.
- The live RC4-protected -> RC6-Main canary completed in 2.38 seconds with no UAC. install_state recorded READY / REUSED_COMPATIBLE_RC4, the RC4 protected hashes remained unchanged, healthprobe stayed PASS and the transient prior CPU recovery state cleared to zero active failures.

## Dependency decision

- LibreHardwareMonitor 0.9.6 remains the pinned production backend for this candidate.
- A current upstream nightly was tested separately during R21 engineering but did not improve the observed CPU worker behavior, so it was not promoted into the production dependency set.

## Validation status

Engineering evidence includes zero-warning builds of the app/broker/supervisor/setup, self-test PASS, 14-theme proof PASS, compact proof at 592/500 px with zero overflow, deterministic stale-worker recovery PASS, and a no-screen Windows taskbar canary with 24/24 stable direct-child geometry samples. Live validation read CPU temperature through the elevated broker, full RTX 3080 telemetry including temperature through the isolated GPU broker, and three elevated storage-temperature sensors on the validation machine.

This is a release candidate, not a final public release. RC6 build/self-test/SBOM/determinism gates pass and its Main canary is installed with exact hash; the protected Broker/Supervisor are still RC4 because the RC6 administrator/UAC completion was not approved: healthprobe reports PASS, CPU/GPU/storage transport and data availability are healthy, the isolated RTX 3080 lane reports temperature/load/VRAM/clocks, three storage-temperature records are available, the installed main UI contains no LibreHardwareMonitor module, taskbar geometry remains stable, and Windows Event Log shows no TBME/Explorer crash or hang event in the observed post-install window.

After the one contained CPU worker recovery, the supervisor returned to HEALTHY_DATA and recorded no further worker failures during the observed installed window. The shared-read main patch then ran without CPU broker read/stale/unavailable log events.

RC6 promotion remains blocked on protected-layer administrator completion, GitHub-side provenance/SBOM attestation execution, and then a longer soak that includes a real suspend/resume cycle; this RC is not yet declared Stable/Latest.
