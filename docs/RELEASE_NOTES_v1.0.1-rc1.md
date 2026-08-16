# Taskbar Monitor Enhanced 1.0.1 RC1

This release candidate fixes a portability problem found after the first public release: on some laptops, Windows can fail or stall while activating the optional CPU-temperature sensor layer.

The visible taskbar monitor itself does not require the protected sensor driver, so the installer should never make the whole application unusable just because CPU temperature cannot be activated.

## What changed

- CPU sensor installation is now **non-fatal**.
- The main application completes installation even if PawnIO or the protected sensor task cannot be activated.
- CPU temperature falls back to `N/A` instead of failing Setup.
- PawnIO installation has a **60-second bounded timeout** instead of an unbounded wait.
- Exit code `3010` is treated as **restart required**, not as a failed application install.
- The Setup window remains responsive while waiting for the elevated sensor helper.
- Detailed sensor installation logs are written under:
  `%LOCALAPPDATA%\TaskbarMonitorEnhanced\Logs`
- The Start Menu includes **Taskbar Monitor Enhanced - Repair Hardware Sensors** so the sensor layer can be retried after a reboot or Windows security change.
- Existing application runtime, themes and monitoring behavior are unchanged from 1.0.0.

## Laptop validation requested

This is a **pre-release build** intended to validate the installer fix on the laptop where 1.0.0 reported:

`Protected sensor installation failed. Exit code: 1`

Expected result on that machine:

1. The application installs successfully.
2. If CPU temperature activates, it is shown normally.
3. If it cannot activate, the application still runs and shows `TEMP N/A`.
4. Setup writes a diagnostic result and log rather than failing the entire installation.

## Status

Pre-release / validation candidate.  
Do not replace the stable `v1.0.0` release with this build until the laptop test passes.
