# Taskbar Monitor Enhanced 1.0.1 — Final Acceptance

Status: **PASS_PUBLIC_1_0_1_FINAL_ACCEPTANCE**

Accepted on the real AMD laptop after the exact same Setup binary completed the full release lifecycle.

## Accepted artifacts

- Setup: `TaskbarMonitorEnhanced_Setup_1.0.1.exe`
  - SHA-256: `4fd7d1055917eebb6598ba78e68294845f51fb190c93889b78f313ec1f3aed54`
- Corresponding source: `TaskbarMonitorEnhanced_1.0.1_SOURCE.zip`
  - SHA-256: `32b69949b1bb8067739c53737b805274b069c63d98b96d84e4855ae826b0cc35`
- Runtime EXE SHA-256: `caf87a4961486a45b351f9a3107ec0081d796b0094d5a915463ca108c8abcb8a`
- Runtime source SHA-256: `e20dc0a164648dced105a22d2237e164f021eb60c582f8ce8ef18e621ede042c`

## Lifecycle gates

- Setup resource verification: PASS — 19 resources, version 1.0.1
- Upgrade install: PASS
- Upgrade configuration preservation: PASS
- Complete uninstall: PASS
- Clean install using the exact same Setup binary: PASS
- Operator configuration restoration after acceptance: PASS

## Hardware/runtime gates

Validated hardware:

- CPU: AMD Ryzen 7 7730U with Radeon Graphics
- CPU sensor: `Core (Tctl/Tdie)`
- GPU: AMD Radeon (TM) Graphics
- GPU source: `LHM_GPU:GpuAmd:AMD Radeon (TM) Graphics`

Accepted runtime behavior:

- vendor-neutral CPU temperature readiness: PASS
- CPU broker elevated + x64 + fresh: PASS
- AMD iGPU load/memory telemetry: PASS
- GPU temperature: `N/A` when not exposed by the hardware/backend; no fabricated values
- taskbar-control overlap: 0
- Sensor Supervisor window: none (`MainWindowHandle = 0`)
- 120-second clean-install lifetime: PASS
- lifetime samples: 24
- Supervisor PID stayed constant
- Broker PID stayed constant
- Supervisor restart count stayed constant
- task remained Running for all samples
- max broker-data age: 1.684 s

## Release policy

This acceptance applies to the exact Setup and source artifacts identified by the hashes above. The public release should use those exact files without rebuilding them.

The installer is currently not Authenticode-signed. Windows SmartScreen may therefore display an Unknown Publisher warning.
