# Download Taskbar Monitor Enhanced

## Current official Stable: v1.7.1 — unsigned

[Official immutable v1.7.1 GitHub Release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.7.1)

[Download the only Windows x64 installer: TaskbarMonitorEnhanced_Setup_1.7.1.exe](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/download/v1.7.1/TaskbarMonitorEnhanced_Setup_1.7.1.exe)

**Installer SHA256: ABD106630F7BAB3471CAF3F5BD4313DFCF2D61DDE1DF79E72EFE91933C8F2F89**

There is **one official executable installer**, not separate new-install and update packages. This is official, Stable, immutable and **not Authenticode-signed by explicit owner decision**. Windows can display Unknown publisher/SmartScreen. Check the hash against SHA256SUMS_v1.7.1.txt attached to that same official Release before launching.

### Install or update without creating another copy

- Fresh install: launch TaskbarMonitorEnhanced_Setup_1.7.1.exe. It installs one per-user copy in LocalAppData/TaskbarMonitorEnhanced.
- Existing public v1.6.0, v1.7 Preview1 or official stable v1.7.0: normally close the running monitor first, then run **the same** v1.7.1 Setup to upgrade in place. **Do not uninstall first**. Configuration, backup, personal files, sensor backend, Startup and Wallpaper choices are protected.
- Already v1.7.1: repeating this same verified installer is an idempotent no-op, not a duplicate setup.
- Advanced existing-install command: TaskbarMonitorEnhanced_Setup_1.7.1.exe /update /quiet. Unknown or edited prior program files fail closed rather than being overwritten.
- In-app Settings → Updates: checks only the latest official immutable GitHub Stable, exact asset name and SHA256, and requires the user's confirmation to download/install.

### Glass and Settings

Go to Settings → Display → Glass mode. Turn the independent switch ON for 0% background opacity (percentage control disabled, text and graphs remain visible); turn it OFF to restore the saved 1–100% background opacity. Start/Search does not lift the monitor off the taskbar; Settings is independently accessible.

### Release provenance

The official immutable v1.7.1 release contains seven assets but **only one executable installer**: Setup, source archive, release notes, SPDX 2.3 SBOM, owner unsigned acceptance, release manifest and SHA256SUMS. Main CI plus two independent hosted Windows A/B tested real v1.7.0 → v1.7.1 same-root update, preservation and physical native UI. Independent HTTPS downloads of all seven files passed the G16 verifier. External signed laboratory and real AC power-loss experiment are **unproven**; unsigned status is explicitly disclosed.

Earlier [v1.7.0 Stable](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.7.0) and [v1.6.0](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.6.0) remain immutable historical releases. The v1.7.1 source ZIP is frozen at its tag; this current main-branch Download guide was corrected after publication to point users to the proper latest installer.
