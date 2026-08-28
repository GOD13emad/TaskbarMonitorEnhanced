# Final acceptance — Taskbar Monitor Enhanced v1.1.1

## Release decision

v1.1.1 is approved for direct public Stable/Latest release.

Authority revision:

`TBME_STABLE_CHILD_LOW_PRESSURE_AND_SETTINGS_R18`

Accepted result:

- `PASS_R18_LOW_PRESSURE_CHILD_CANDIDATE_RETAINED`
- user verdict: `PASS`
- rollback: `false`
- Explorer PID remained stable during acceptance
- Explorer Event 1000: `0`
- Explorer Event 1002: `0`

## Included fixes

- accepted R15 suppression of default NVIDIA-SMI realtime polling
- R18 low-pressure taskbar-child shell integration
- watchdog 500 ms
- host poll 1000 ms
- style health 5000 ms
- placement health 5000 ms
- event/geometry-driven Safe Placement work
- single-instance Settings behavior

## Publication authorization

- GitHub v1.1.1 Stable: APPROVED
- GitHub v1.1.1 Latest: APPROVED
- direct in-app update discovery to v1.1.1: APPROVED
- v1.1.0 remains available as the previous release
