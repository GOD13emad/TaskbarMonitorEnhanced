# Installer sources

The public 1.0.0 installer keeps the visible taskbar application non-elevated. Administrator approval is requested only when the protected hardware-sensor layer must be installed or removed.

`TaskbarMonitorEnhanced_Setup.cs` implements the public installer/uninstaller. `TBME_Setup_Elevated_Helper.ps1` installs the protected sensor broker and supervisor under Program Files and registers the elevated Scheduled Task.

The exact accepted installer binary is available from the `v1.0.0` GitHub Release.