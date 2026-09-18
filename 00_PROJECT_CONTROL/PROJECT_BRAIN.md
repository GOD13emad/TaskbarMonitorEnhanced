# PROJECT BRAIN — Taskbar Monitor Enhanced

## Authority

- Public stable release remains v1.1.1.
- R20 rollback authority: local commit 539c8f7 — process-isolated sensor-access baseline.
- Active candidate: v1.1.2-rc2 / R21 Production Hardening on audit/r21-production-hardening.
- Do not claim FINAL/STABLE until the elevated split-supervisor install and installed soak gates pass.

## R21 objective

Increase long-run stability and observability without regressing the accepted taskbar behavior. The main mutation objective is native-sensor failure containment plus telemetry hot-path reduction; Diagnostics/update-security improvements are downstream extensions of that architecture.

## Implemented

- Independent CPU/GPU/storage LHM worker processes.
- Staggered worker startup and bounded retry/backoff.
- Fresh transport health separated from data availability.
- Power-aware telemetry pause/reset/recycle.
- Native GetSystemTimes CPU usage.
- Cached CPU/network topology.
- GPU WDDM fallback on demand.
- CPU fallback throttling and stale-data invalidation.
- Diagnostics tab, saved reports, repair action, CLI health probe.
- Immutable-release + SHA-256 automatic-update trust gate.
- Installer task restart/multiple-instance hardening.
- Installer multi-lane R21 supervisor health gate.
- Pinned LHM 0.9.6 production dependency; newer nightly tested but not promoted.

## Evidence summary

See docs/R21_ACCEPTANCE_STATUS.md and local r21_evidence/. Core builds and deterministic/visual/canary gates pass. Existing elevated hardware evidence confirms CPU and three storage temperatures; candidate user-context GPU worker confirms RTX 3080 temperature and detailed telemetry.

## Open blocker

Fresh R21 split supervisor has not yet run under an elevated token because Remote Commander is non-elevated. UAC approval is required for the final installed sensor gate.

## Next authoritative actions

- Rebuild setup from the final source.
- Commit R21 source/docs.
- Produce manifest/hashes and RC return package.
- With UAC approval: install candidate, run --healthprobe, validate split GPU/storage output, then soak.
- Publish/promote only after installed gates pass.
