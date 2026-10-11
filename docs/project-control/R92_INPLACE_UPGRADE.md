# R92 — One-Root In-Place Upgrade and Data-Preservation Contract

**Project:** TaskbarMonitorEnhanced. **Current public Stable:** `v1.6.0`; **voluntary public unsigned Preview:** `v1.7.0-unsigned-preview.1` (immutable, NOT upgraded in place by any earlier Setup). The R92 candidate is a NEW experimental source revision; do not replace or overwrite any immutable public artifact. Do not run this unaccepted candidate on the maintainer's PC.

## Mutation objective / Definition of Done

Upgrade from a verified **official v1.6.0** installation to the v1.7.0 candidate **in the SAME existing per-user folder** without uninstall/reinstall, creating a second product root, deleting personal information, changing Start-with-Windows, changing the protected sensor layer, or permanently leaving release/rollback duplicates.

Need -> Requirement -> Action -> Verification -> Evidence -> Acceptance:

1. Identity: Existing HKCU uninstall key, `ProductIdentity=LOCKED`, version 1.6.0 and exact canonical `%LOCALAPPDATA%\TaskbarMonitorEnhanced`; detect conflicting Program Files executable or inconsistent/cross-user installation => FAIL CLOSED.
2. Baseline: compare **21 v1.6-managed files** or **23 existing unsigned v1.7 Preview 1-managed files** against exact embedded resources and SHA of immutable official [v1.6.0](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.6.0), rather than assuming anything named `TaskbarMonitorEnhanced` is safe to replace. In particular, if a user edited a source or docs file, do **not** overwrite it.
3. User-data safety: never edit/remove `config.json`, `config.json.bak`, any `Backups`, `Logs`, session/history/settings, user-owned unknown files, Wallpaper, scheduled tasks, installed PawnIO, or the existing LibreHardwareMonitor library during this upgrade. The test requires SHA-equal personal config, backup, custom test data and sensor library before/after. Preserve registry Startup and existing desktop shortcut preference. Updater never force-kills the real running application; it asks the user to exit normally.
4. Transaction: stage only allowlisted new binary/source/doc files plus official old managed snapshots under **one owned temporary `.tbme-upgrade`** inside the canonical root. Preflight exact old hashes, prepare all new hashes, journal owner/index/phase and then perform same-volume `File.Replace` or staged `File.Move`. Update HKCU registered DisplayVersion only on successful file replacement; never use `/uninstall` before upgrade.
5. Recovery/rollback: if any item fails, restore exact old managed versions, old install state and old HKCU DisplayVersion from SHA-bound backup, remove new-only files and verify every old digest. On a crash, the next invocation first tries recovery from the owned journal BEFORE requiring that the Main exe exists; unknown/modified journal remains untouched and status **UNRESOLVED**, no blind deletes.
6. Clean finish: after verifying Main hash, install state, preservation of config/startup/backend, remove only the exactly known staged files; collapse the old redundant root `TaskbarMonitorEnhanced.cs` (while retaining `Source\TaskbarMonitorEnhanced.cs`) and obsolete **official, unchanged** `Docs\RELEASE_NOTES_v1.6.0.md`. Retain current v1.7 documentation. Never delete unknown `Source` or `Docs` entries.
7. Idempotence: rerunning `/update` at the identical v1.7 Main SHA is an exact **no-op**. Unexpected same-version different bytes, older/downgrade, missing identity or a second active root are rejected, not repaired by creating duplicates.
8. Hosted validation: clean disposable GitHub Windows runner downloads the exact v1.6 Setup (SHA256 `F5130BC2F81383E16912454FCC62E307501885A6256E7241E674A9CF10BAC9C5`), installs it ONCE, adds synthetic user-owned data, checks refusal to overwrite an edited managed file, injects a failure after managed component #4 and proves 21 old hashes + config restored, then updates successfully IN PLACE and repeats the same-version no-op. No personal machine, no Windows wallpaper mutation.

Microsoft [.NET Framework 4.8 File.Replace](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.replace?view=netframework-4.8.1) supports on-volume replacement with a backup. A journal is still needed because many file replacements are not one atomic multi-file operation. Never mistake Build/Parse/CLI checks for a full user-data validation.

9. Same-semver maintenance: existing `v1.7.0-unsigned-preview.1` has the identical published Main SHA but an older Setup (`9A1B4F81...`). Distinguish the maintenance Setup SHA from the Main version, verify its full **23-file pinned official public-preview manifest**, then upgrade the same root without uninstall, preserve existing 1.7 install_state byte for byte, clean redundant root source, and make a subsequent retry a true no-op. Unexpected 1.7 Setup hashes are refused.

## Current controls and non-destructive cleanup

- The maintainer's v1.6 per-user app contains **154 top-level files**, of which 136 are **probable stale broker JSON .tmp** files (`cpu`: 10, `gpu`: 105, `storage`: 21). They are **not a second installed version**, and remain untouched until an explicit allowlist/time/pid/lock/writer/matching-live-state cleanup witness is accepted. User config and backup SHA match but are still user-owned; do not delete either.
- SAEID Windows has an **empty** `C:\Program Files\TaskbarMonitorEnhanced` directory but no installed Main EXE/registration in the checked profile. Treat as historical/unknown system ownership: no automatic deletion or claim that it is another installed product.
- Linux Emad-laptop: no matched application/data root at scoped paths. MMZ Linux endpoint unavailable in this audit: **MISSING**, not a claim of zero duplicates.
- Project source, old Brain, GitHub immutable release evidence and QA worktrees are **provenance**, not multiple active installations. Label obsolete runners `SUPERSEDED—DO NOT RUN` in Brain; retain only what is needed for account transfer, and never indiscriminately delete other projects/personal files.

## Authority / Critical Path

- **Accepted source R59** `bfce93b0bb1c65d426be338bd5359b551a2a7aa5` for historical formal Stable control; **R85** `eeac48c2ff201326c6a59e7ccc21c72c9a676160` published unsigned Preview; **R89 cumulative Brain** `B10950C2498FD08A8451D5B4BC1DCB7F0A03A12BFBCDAA0B29F63C6CB3E82194`.
- **Current R92**: prospective upgrade candidate in isolated worktree, NOT installed or promoted. The one relevant blocker is an independently accepted real **official v1.6 -> candidate v1.7 in-place migration** with injected failure/rollback and no duplicate/no data loss.
- **G13/G14 interactive, signing policy G15 (deferred for user's unsigned Preview) and formal G16 Stable** stay separate. Signed code is **not required** for voluntary unsigned preview distribution.
- Until the hosted upgrade witness and full source CI pass, **Do Not Run R92 Setup on real user PCs**. Never substitute uninstall/reinstall for an update.

**Exact next action:** run R92 hosted ephemeral installed upgrade workflow and inspect raw receipt; if failed, preserve historic failure and correct only the diagnosed transition, then update cumulative Project Brain and return artifacts.
