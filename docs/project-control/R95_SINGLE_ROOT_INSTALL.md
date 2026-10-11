# R95 — One canonical installation, no duplicate or silent data overwrite

**Purpose:** Complete the remaining fresh-install entry-point guard in the already accepted R94 data-preserving unsigned update engine. The user requires an UPDATE in the existing installation, never an uninstall/reinstall to replace an older version, and no duplicate executable, startup entry or discarded user data.

## Source authority
- Parent is R94 sanitized updater `cf59074170e23cb2ebab4b67b724fb7cda3755c3`; final inherited R94 candidate Setup SHA256 `2DC02CDBAE39C5CF0F4677EF8035060FE00B78B883AA703FA9F83F50B9FCD05F`; R94 cumulative Brain `0C5A86CADED2A889602E97D6DE5C459E70E58329BB839F78A80B7BF16804D1FD`.
- R95 experimental Setup source SHA256 `38C89A12D85DAC49BB640A2C6B2F78E4C405879D83330725F49CF30C486B8F14`, initial zero-warning local Build Setup `63B811A5343C4FD066F39927F428C1F49CF2581A9348FF281B3260E0C860A5ED`. Main product SHA remains `63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70`.
- Immutable public unsigned Preview1 still `v1.7.0-unsigned-preview.1` at source `eeac48c2ff201326c6a59e7ccc21c72c9a676160`; latest formal Stable v1.6.0 remains unchanged. **R95 is TEST ONLY — do not promote without independent hosted evidence.**

## Need → requirement → action → verification → acceptance

**One mutation objective:** Existing installed app still follows `UpgradeExisting()`; new installs must first run `CheckFreshInstallNoCollision()` before creating directories, killing processes, creating shortcuts, registering startup or installing any package.

- If `%LOCALAPPDATA%\TaskbarMonitorEnhanced` already exists but lacks a trusted uninstall registration or Main, **FAIL CLOSED**: user data/orphan identity cannot be overwritten.
- If a separate `Program Files\TaskbarMonitorEnhanced` or `Program Files (x86)\TaskbarMonitorEnhanced` has content, **FAIL CLOSED**: no second per-user binary. Truly empty historical folder is not an active product by itself and is never deleted automatically.
- If machine-wide HKLM 32/64-bit uninstall registration, existing HKCU Startup product entry, existing product shortcut or product process exists, **FAIL CLOSED**: do not silently replace or kill the user's active work.
- On clean Windows, install once to the single per-user directory, retain one uninstall registration, verify immutable embedded Main, then rerun the identical Setup via `/install`; this must route to a byte-preserving in-place NO-OP, not create another copy.
- Existing official v1.6 → 1.7 and public unsigned Preview1 → corrected same-version Setup paths still run in two independent fresh Windows after the isolated SHA-pinned builder. R92 caught rollback and R93 abrupt updater process termination were tested on **different test-only binaries**, never claimed as rerun on the sanitized public-facing candidate.
- Validate SHA of source/compiled Setup and absence of any `TBME_TEST_`/FailFast/exception-writer code; reject 12 negative sanitization samples. Test three negative conflicting installation scenarios on a **third isolated GitHub-hosted Windows VM** with test-owned one-file synthetic fixtures removed ONLY after exact SHA and inventory checks. Never perform these tests on a user's installed PC.

## Limits and handoff
The scope is single current-user installation plus tested machine-wide Program Files/registry indicators; other offline PCs/user profiles cannot be asserted empty. Installer uninstall behavior is separate from Update; nobody should uninstall an existing version as part of an upgrade.

No personal software, user data, wallpaper, historical Project Brain files, other-project folders, or unknown files are deleted by R95. The 131/136 probable stale broker temp files remain **quarantine candidates only**, with five protected; they are not evidence of installed duplicate versions.

**Next action:** Exact four-hosted-job CI for R95 → download raw receipt SHA and independently verify all fresh negative/positive and inherited upgrade paths → append cumulative Brain and decide optional unsigned non-Latest update delivery. Formal interactive G13/G14 and G16 Stable are independent and still OPEN.
