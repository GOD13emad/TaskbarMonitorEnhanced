# R38 finalization authority

Project: Taskbar Monitor Enhanced. Objective: deliver the finite v1.6.0 eight-page workspace and 20 new distinct Studio themes as an exact-source, configuration-preserving, digest-verified public release. Universal superiority over specialist products is not an acceptance criterion.

Canonical root: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`.
Current branch: `release/v1.6.0-final`. It starts at corrected source `182c4ed11d78fa3c52f8bbf104a7e791cd2491bf`, not the superseded original-worktree candidate. The linked `.local/r37-work` remains preserved, read-only historical engineering evidence. Accepted preceding public authority is v1.5.0 at `d952a87fab02fe74046b8d19ae14a2801d6da644`.

## Completed delta

The corrected R37 source was consolidated at the canonical root without overwriting either lineage. An untracked historical `config.json` was preserved by a verified move under `.local/r38/pre`; no personal configuration entered Git. Prior-source backup is `.local/r38/PRE_R38.zip` with SHA256 `0F7C7B00F2FCA1EE00211DD92DFA13F680DC25FE8AA29B73C4F45B760A4079E5`.

R38 main mutation objective: close the demonstrated traffic-history shutdown-loss defect and report failed writes truthfully. New cold-shutdown, corrupt-input and filesystem-write-failure tests were added before the correction. Operation `920abe69-1532-43d2-a0e4-36966e90f094` compiled cleanly but failed the new cold-shutdown assertion with process exit 27. Operation `36c6d7b0-83ce-401c-808e-3e6c11c4bc0d` passed compilation with zero warnings/errors and all three contract suites after the narrow repair.

### R38-F01

Class: persistence/data preservation. Trigger: close with traffic retention enabled before the first observed sample. Root cause: flush serialized an empty in-memory ledger before loading the existing file; the queue completion flag also did not represent successful I/O. Prevention: lazy read before every first flush, fail-closed corrupt-input handling, and completed-drain plus actual write status. Regression: cold valid/corrupt files, directory-as-file I/O failure, existing reset/switch/retention/coalescing tests. Rollback: guarded source backups in `.local/r38/pre`, Git parent, and mutation hashes in `.local/r38/MUTATIONS.jsonl`.

## Roadmap and exact current position

Discovery/definition and scoped development are complete. Current stage is source freeze -> exact full build and clean-clone determinism -> fresh visual/runtime validation -> exact-head CI/provenance -> installed configuration/hash/runtime acceptance -> immutable publication with seven verified assets -> cumulative Brain/Return closure. Remaining gates are OPEN until their raw results are recorded; earlier binary results are not reused across code changes. No completion percentage is inferred from activity.

Broker source/protocol `1.1.2+r21`, Supervisor `1.3.0+r33`, existing startup preferences and personal settings are locked. No reboot, shutdown or logoff. Public-trust Authenticode and physical secondary-monitor proof remain external/deferred, not claimed.

Current source and this control revision supersede prior current-action statements. Defective empty-source `f170a8a`, disconnected `8f19bd2`, synthetic workspace proof, and old pre-integration installers are SUPERSEDED -- DO NOT RUN as release authority. Historical evidence is retained unchanged.

Exact next action: commit this reviewed source, run full Build/Verify-Determinism and fresh workspace/runtime suites, then push the exact commit for CI. Do not install or publish before the gates close. Brain is current as a control record; account-transfer ZIP is INCOMPLETE until generated with actual source/evidence and manifest.
