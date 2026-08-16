# Source overview

Taskbar Monitor Enhanced 1.0.0 is distributed under GNU GPL v3.0, with upstream attribution preserved.

The exact corresponding-source archive for the accepted installer is attached to the `v1.0.0` GitHub Release:

`TaskbarMonitorEnhanced_1.0.0_SOURCE.zip`

Browsable components in this repository include the protected CPU sensor broker, the sensor supervisor/watchdog, and the public installer sources. The full main runtime source is included in the exact release source archive so that the source package remains byte-for-byte identical to the artifact accepted during the final release process.

## Components

- `sensors/TaskbarMonitorSensorBroker.cs` — elevated CPU temperature reader based on LibreHardwareMonitor.
- `sensors/TaskbarMonitorSensorSupervisor.cs` — watchdog that supervises broker liveness and data freshness.
- `../installer/TaskbarMonitorEnhanced_Setup.cs` — public installer/uninstaller implementation.
- `../installer/TBME_Setup_Elevated_Helper.ps1` — protected sensor installation helper.

See the root attribution and third-party notice files before redistributing modified versions.