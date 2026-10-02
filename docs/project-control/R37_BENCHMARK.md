# R37 capability benchmark and release boundary

Primary-source review: 2026-10-02. This is a capability map, not an exhaustive claim that one product dominates all others. Product scope and hardware support differ. Sources were read directly; no third-party rankings are used.

## Primary sources

1. TrafficMonitor upstream README: https://github.com/zhongyang219/TrafficMonitor — taskbar display, skins, adapter selection, network details/history, hardware information and executable plugins.
2. HWiNFO official overview: https://www.hwinfo.com/about-software/ — deep hardware inventory, live sensors, tables/graphs/tray/OSD, reporting/logging, alerts and extension/shared-memory interfaces.
3. Microsoft Process Explorer documentation: https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer — process inspection, opened handles, loaded DLLs and search across those objects.

## Need -> implementation -> verification

| Need inspired by source | R37 implementation | Evidence/gate | Boundary |
|---|---|---|---|
| Taskbar monitoring and personalization (1) | Existing taskbar metrics, 48 themes including 20 new geometry renderers | Theme proof and same-palette geometry uniqueness, actual preview/apply actions | Not a compatible TrafficMonitor skin loader |
| Traffic history and adapter selection (1) | Pinned adapter counters, bounded 90-day buckets, budget, CSV; opt-in disk persistence | Reset/gap/unavailable/switch/retention/coalescing tests | Observed traffic only, not ISP-billed totals |
| Hardware inventory/reporting (2) | CPU topology, RAM modules, GPU clocks/power/fans/PCIe, storage/network inventory; CSV/JSON | Availability/NaN unit tests and real Hardware page | Coverage depends on existing sensor backend; cached CPU inventory is labelled |
| Graphs and analysis (2) | 3,600-sample history, selectable time window, min/max/average/P95, PNG/JSON/CSV | Bounded history, statistic tests, real-data chart proof | No continuous multi-day full-sensor database |
| Alerts (1,2) | Temperature plus sustained usage/capacity alerts, hysteresis, cooldown, quiet hours, snooze | Boundary/nonfinite/dwell/cooldown tests; real policy controls | No arbitrary external command execution |
| Process visibility (3) | Read-only filtered/sorted process CPU, memory, threads and handle counts; CSV | Local process sampler and UI page; permission errors handled | Does not enumerate kernel handles or DLLs like Process Explorer |
| User control and repeatable configuration | Presentation-only allowlisted profiles, backup, presets, group ordering | Invalid/oversized/security-field imports; real renderer after UI actions | No startup/sensor/telemetry permissions imported |
| Low-risk extensibility | Modular internal C# source, reusable existing snapshot, standard export files | Compile/packaging and source integrity checks | No arbitrary executable plugin SDK in this release |

## Explicitly deferred / not claimed

Arbitrary third-party executable plugins; kernel handle/DLL/thread-stack inspection; overclocking/fan control; SMART self-tests or inferred drive-health scores; game injection OSD; ARM64 support; cloud/remote monitoring; complete parity with HWiNFO's hardware-support matrix. These require their own scope, threat model, licensing/dependency assessment and hardware validation. Omitting them is not a test failure of the finite R37 release scope.

## Final objective for this release

Deliver a coherent taskbar monitor and eight-page workspace with 20 new, distinct themes; preserve v1.5 settings and protected sensors; provide reproducible source/binaries and evidence-backed runtime validation. Release gates are tracked in R37_VERIFICATION.md. Universal superiority remains UNPROVEN and is never used as an acceptance result.
