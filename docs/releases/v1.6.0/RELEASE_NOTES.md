# Taskbar Monitor Enhanced v1.6.0 — Performance Workspace & Theme Studio

v1.6.0 expands the v1.5.0 release with a desktop-grade monitoring workspace and twenty original theme designs. The protected sensor broker/supervisor layer remains unchanged.

## New monitoring workspace

A new eight-page Performance Workspace is available from the taskbar menu:

- **Overview** — bounded session charting for CPU, RAM, GPU, VRAM, network, disk rates and available temperatures; selectable history window; min/max/average/P95 statistics; CSV, PNG and JSON export.
- **Processes** — read-only process inventory with filter/sort, normalized CPU, working/private memory, thread count and handle count, plus visible-row CSV export.
- **Network** — per-adapter throughput/link utilization, selectable accounting adapter, optional taskbar bit/s formatting and explicit monthly traffic budget.
- **Storage** — per-device capacity, free space, read/write throughput and available disk temperature.
- **Alerts** — sustained CPU/RAM/GPU/disk-capacity thresholds, dwell time, cooldown, local-time quiet hours, 30-minute global snooze and bounded event export.
- **Themes** — searchable/filterable catalog, favorites and production-renderer preview across all 48 themes.
- **Hardware** - availability-aware CPU, RAM-module, GPU, storage and network inventory with CSV/JSON export.
- **Profiles** — presentation-only import/export, presets and taskbar metric ordering.

## Twenty original Studio themes

The release adds 20 renderer-backed designs, for 48 built-in themes total:

Bauhaus Blocks, Swiss Grid, Art Deco Gold, E Ink Ledger, Noir Cinema, Metro Signal, LCD Quartz, Oscilloscope Phosphor, Radar Vector, Aviation HUD, Isometric Prism, Ribbon Flow, Circuit Trace, Dot Matrix, Topographic Moss, Memphis Pop, Origami Snow, Kintsugi Ink, Brutalist Concrete and Stained Glass.

These designs use distinct tile/frame/graph geometry rather than palette-only recoloring.

## Local analytics and privacy

- Session history remains bounded to 3,600 samples.
- Optional traffic history is stored locally for at most 90 daily buckets.
- Traffic persistence is **off by default**.
- Traffic accounting pins one adapter to reduce VPN/physical double-counting.
- Counter resets, first samples and long gaps are excluded from persisted deltas.
- No cloud telemetry, account identifier or background upload is added.
- Process inspection is read-only and active only while the Processes page is open.

## Alerts

- Existing temperature notification behavior remains.
- New sustained-load notifications cover CPU, RAM, GPU and disk-capacity thresholds.
- Usage alerts use configurable dwell/cooldown plus 5-percentage-point rearm hysteresis.
- Quiet hours and global snooze suppress both sustained-load and temperature notifications.
- Event history is bounded to 200 in-memory entries.

## Profiles and configuration safety

Presentation profile import is allowlisted. It can change visual/presentation choices only; it cannot change startup registration, protected sensor paths, traffic retention or notification security-sensitive settings. Before an import the current configuration is backed up.

Configuration schema advances to **7**. Migration initializes new privacy-sensitive fields to conservative defaults while preserving existing settings.

## Validation targets

Release acceptance requires:
- zero-warning application and setup builds,
- legacy and v1.6 self-tests,
- 48/48 theme proof,
- 8/8 workspace-page proof,
- clean-clone determinism,
- full existing regression suite,
- installed-runtime hash/behavior checks,
- CI/provenance and final published asset digest verification.

## Protected sensor layer

Unchanged from v1.5.0:
- Broker protocol: 1.1.2+r21
- Sensor Supervisor: 1.3.0+r33

## Hardware and independent interaction verification

The Hardware page exposes existing CPU topology, cached clocks, RAM modules, GPU clocks/power/fans/PCIe, storage media and network inventory. Sensor availability remains explicit; it triggers no new privileged polling. Inventory can be filtered and exported as CSV/JSON.

The workspace validation drives real UI buttons and checks the production renderer after theme selection, favorites, presets, ordering and bit-rate changes. Twenty Studio geometries are rendered with identical colors, fonts and metrics to prove they are not palette-only duplicates. Primary text contrast is tested across the new themes. These checks supplement, not replace, installed-runtime validation.

## Scope limits

This release is not a full replacement for Process Explorer's kernel handle/DLL inspection, HWiNFO's entire hardware-support matrix or TrafficMonitor's arbitrary executable plugin system. Those capabilities need separate engineering and validation. No universal product-superiority claim is made.

## Final persistence guards

Shutdown reads existing local traffic history even when it occurs before the first sample. Corrupt history is preserved rather than overwritten. A completed queue is not treated as a successful save if the disk write failed. Regression tests reproduce the cold-shutdown loss on the prior implementation and verify these guards.
