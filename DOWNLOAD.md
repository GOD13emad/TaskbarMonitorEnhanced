# Download Taskbar Monitor Enhanced

## Official stable download

[Open the latest immutable GitHub Release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/latest). Download the one versioned file named `TaskbarMonitorEnhanced_Setup_<version>.exe`. The same executable installs or updates the single per-user product; no portable or duplicate installation is needed. The tag and assets on that release page determine the actual published version, not the current development branch.

Before running it, compare SHA256 with `SHA256SUMS_<version>.txt` and the matching Release Manifest. Releases are unsigned by owner decision: Unknown publisher/SmartScreen can appear. Hash and GitHub provenance checks do not imply Authenticode signing or malware clearance.

## Protected in-place updating

Close the running monitor normally, then run the matching official Setup. **Do not uninstall first.** Unknown/edited program files are not silently overwritten. Configuration, backup, personal files, sensor backend and Startup preference remain protected. The versioned Release Notes list exact supported ancestors; 1.7.2 adds the genuine public 1.7.1 path, including installations previously upgraded from 1.7.0. Repeating the identical current-version installer is idempotent.

## Glass and transparency

Settings > Display contains a pill-shaped Glass ON/OFF switch. OFF retains normal background opacity from 1 to 100 percent without automatically changing to Glass below 31. ON sets background opacity to zero and disables the numeric control; OFF restores the previous value.

## Acceptance scope

Versioned changes are tested with genuine old installers, configuration and backup preservation, unsafe-update refusal, rollback after a simulated partial commit, repeated-install idempotence and downgrade rejection. Separate disposable Windows exercise actual native menu, Settings, Start, taskbar hide/restore and borderless fullscreen in four modes. Short hosted CPU measurements do not prove sustained CPU performance on a different consumer PC. Real physical power-cut testing and external antivirus-report triage remain separately tracked.

Previous immutable releases and their assets are never overwritten. Refer to [all releases](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases) for historical versions.
