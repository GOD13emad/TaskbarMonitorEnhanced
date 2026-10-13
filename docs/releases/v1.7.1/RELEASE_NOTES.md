# Taskbar Monitor Enhanced v1.7.1 — Stable

**Release channel:** Stable (October 2026). **Publisher:** GOD13emad. **License:** GPL-3.0-only.
**Installer:** `TaskbarMonitorEnhanced_Setup_1.7.1.exe` — one canonical per-user installation.

## What's fixed

- **Fixed taskbar position:** the monitor stays in its original taskbar row when Windows Start/Search opens. The previous upward lift is disabled.
- **Visible over ordinary windows:** the transparent taskbar monitor keeps its nonactivating, topmost position when applications gain foreground; changes in the safe available taskbar width are handled without lifting its Y coordinate.
- **Reachable Settings:** Settings is an independently activatable, foreground-capable window and does not disappear underneath the taskbar overlay.
- **Independent Glass switch:** Settings → Display → Glass mode (OFF/ON). ON makes background opacity exactly 0% and disables its percentage control while leaving metrics, labels and graphs visible. OFF restores the previously selected 1–100% opacity; switching modes does not overwrite the saved value.
- **Compatibility:** maintains the 49 themes and existing hardware, sensor and workspace functionality; no separate second installation.

## Installation and updating

For a new installation, launch the single installer above. For an existing Taskbar Monitor Enhanced installation, use the update offered in Settings → Updates or run the new installer as an in-place upgrade. Close the currently running monitor normally before updating if prompted. **Do not uninstall first.** Existing configuration, its backup, external sensor dependencies and user-owned files are preserved by the guarded transaction. An unexpected or edited managed file causes the installer to stop rather than replace user modifications.

The in-app updater obtains the latest official GitHub Release and validates the release asset and published SHA256 digest. The released file is the same versioned installer used for new installs and upgrades.

## Independent verification

The exact release-candidate source and runtime were tested on two independent, disposable GitHub-hosted Windows systems. These checks include public v1.7.0 → v1.7.1 in-place upgrade with no duplicate root, idempotence, downgrade and edited-file guards, native Start positioning, an interactive Settings window, and real screenshots showing the Glass monitor while two ordinary windows receive actual mouse input. Image hashes and foreground HWND/position were independently verified. Historical CI and receipt links are retained in the repository's audit history.

## Security and limitations

**This installer is not Authenticode-signed**, by the product owner's explicit release decision. Windows SmartScreen may display an unknown-publisher warning; do not claim a signature that does not exist. Confirm the installer SHA256 against `SHA256SUMS_v1.7.1.txt` from this official GitHub Release.

External signed-laboratory acceptance and a destructive, physical power-outage experiment have **not** been established; passing hosted rollback simulations must not be described as those external tests.
