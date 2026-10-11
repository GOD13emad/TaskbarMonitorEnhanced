# R94 — Sanitized Same-Root Unsigned In-Place Updater (Draft / Not Public)

**Project:** TaskbarMonitorEnhanced. **Source parent:** exact R92 accepted upgrade source `e116b2bbf9203edeb7c84371dcc368f0a9603578`, distinct from separate R93 **test-only** crash-hook source `d2663aa6bb92222b6cdc20c93de54d77ce3261f1`. Current immutable public unsigned Preview1 source is `eeac48c2ff201326c6a59e7ccc21c72c9a676160`, `v1.6.0` remains Latest Stable. The R94 source must **never overwrite either published release**, and is not a formally accepted public build.

## One mutation objective

Create an **opt-in release-candidate Setup** supporting exactly one application instance/root on a user's Windows profile, with preservation of their config, backup, sensor library, unknown data, Startup option and current app data; no uninstall/reinstall prerequisite, no duplicate old managed files, safe journal rollback; **remove every experimental crash/fault/diagnostic injection from the actual EXE shipped to users**.

New Setup source explicitly removes the R92 `TBME_TEST_FAIL_AFTER_INDEX` injection branch, its unused counters, the R92 CI `TBME_TEST_UPGRADE_ERROR_PATH` / WriteHostedUpgradeFailure method, and excludes the R93 `Environment.FailFast` crash-hook source entirely. Official Main embedded in candidate remains exact SHA `63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70`.

## Need -> Action -> Verification -> Evidence -> Acceptance

1. **Source and binary sanitization:** independently require Setup source and 8+ MB compiled binary have no `FailFast`, `TBME_TEST_`, `WriteHostedUpgradeFailure`, or other runner-only fault injection strings (plain ASCII and UTF-16LE). A standalone verifier executes **12 hostile mutations** and must reject every test-hook variant; source must retain canonical-root/rollback/old-baseline manifest logic.
2. **Build integrity:** produce exact setup with locked OSS dependencies and **zero warnings/errors**, still NotSigned, PawnIO not bundled, exact Main SHA; pin its full SHA-256 and require an independently downloaded GitHub-hosted artifact to match before any install.
3. **Actual official v1.6 migration:** fresh Windows host installs immutable v1.6 Setup once, seeds synthetic config/backup/unknown owned sentinel, verifies refusal to overwrite user-edited managed Docs, then tries an **in-place update with all previous crash/fault environment variables maliciously set**: it must still succeed with no Fault/FailFast/diagnostic artifact. Validate Main, registration, user data/backend/Startup exact unchanged, one install root, no owned transaction stage, true no-op on same version rerun.
4. **Actual published Preview1 maintenance:** distinct fresh Windows host installs immutable unsigned Preview1 once, seeds SHA-bound synthetic user config/backup/unknown sentinel, then tries the same sanitized candidate with all test-hook environment variables set. Main stays identical; exactly one per-user maintenance Uninstall.exe updates, install_state remains v1.7, config, backend and Startup preserved; no old duplicate root source, no staging and idempotent rerun.
5. **Prior regression reused by source lineage, not falsely rerun:** R92 `INDEPENDENT_R92_ACCEPTANCE.json` proved dual fault-injection **caught exception** rollback; R93 `INDEPENDENT_R93_ACCEPTANCE.json` proved real hosted process death after four managed changes and 21/23 old managed SHA recovery. R94 sanitized candidate **does not** include injection hooks, and must not claim to have repeated the R93 crash simulation.
6. **Delivery boundaries:** unsigned *opt-in* maintenance preview is considered only after fresh R94 SHA and hosted V&V, cumulative Project Brain update and explicit release authority; no new public release or tagging from CI, no unverified auto-update, no desktop GUI change, no reboot, no disabling Windows security, no personal host migration.

## Open blockers / risk

**Fatal before any public install:** loss of config/Backup/unknown user file, wrong canonical root, unintended Program Files duplication, old installer Run/Startup preference mutation, any test-only FailFast symbol in distributed binary, or missing rollback journal/failed previous SHA check. Unknown historical/personal/source/BRAIN files are **not automatic deletion candidates**.

**Still OPEN after this branch:** actual migration under the maintainer's personal config/profile, real power-cut + storage-controller flush durability, full positive independent static-Picture G13, full G14 8/8/Explorer and sensor rollback, public signing G15 deferred for unsigned distribution, and formal G16 Stable. User's v1.6 app/config/Slideshow must remain unchanged until approved safe update. Global weighted project percent remains **UNPROVEN**; Stable gate count historically 12/16.

**Cleanup:** R92 audited 136 temporary sensor PID files; 131 eligible only for later ownership/age/lock revalidation and quarantine, five protected. The current R94 mutation is *not* cleanup; no personal file deletion is part of this revision.

**Brain authority at R94 discovery:** R93 cumulative SHA `D0AF70CF600124F55E29DCA6B7717F08A04FDB6B4562504346BA595FE0F76B39` with 421 entries and 420 hashes, BrainStatus INCOMPLETE only due legacy R64/R68/R69 full raw missing. R94 successor must include raw positive CI receipts / negative regression proofs and exact source hashes before promotion.

**Exact Next Action:** complete fresh sanitized GitHub three-job workflow, independently verify the actual binary plus two host receipts; then update cumulative Brain and propose a separate voluntary unsigned update Preview (without overwriting published Preview1 or v1.6 Latest).
