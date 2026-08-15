# Taskbar Monitor Enhanced 1.0.0

This is the first public release of Taskbar Monitor Enhanced.

The goal is straightforward: keep useful system telemetry visible on the Windows taskbar without turning monitoring into another full-time window.

## What is included

- CPU, RAM, disk, GPU and VRAM monitoring
- separate download and upload telemetry
- CPU Package and GPU temperatures
- 14 built-in visual themes
- live sparklines and theme-aware network graphs
- left, center and right taskbar placement
- adjustable width and safe positioning
- right-click controls
- automatic recovery after Explorer/taskbar restarts
- non-elevated main application
- protected sensor broker supervised by a watchdog process
- Start-with-Windows support
- Desktop and Start Menu shortcuts

## Installer validation

The exact 1.0.0 installer passed a controlled acceptance cycle covering:

- upgrade installation
- configuration preservation
- complete uninstall
- clean installation
- protected sensor startup
- CPU temperature continuity
- post-clean-install lifetime stability

The final post-install lifetime gate completed 24/24 samples over 120 seconds with the Scheduled Task running, a stable Supervisor process, a stable Broker process, and fresh CPU Package telemetry throughout.

## Release files

### Installer

`TaskbarMonitorEnhanced_Setup_1.0.0.exe`

SHA-256:

`57196706279272fa2d605331f34b5386a5ba3fba8f0f64e12ee65e4288f5a4e7`

### Corresponding source

`TaskbarMonitorEnhanced_1.0.0_SOURCE.zip`

SHA-256:

`82ddae1701aae2d427aac08e08d5c249d3efe52e599794effd90fe9c861b01af`

## Signing note

The 1.0.0 installer is not Authenticode-signed. Windows SmartScreen may therefore show an **Unknown publisher** warning. The SHA-256 above identifies the exact installer that passed final acceptance testing.

## Credits

Lead Developer & Maintainer: **Dr. Ali-Akbar Emadeddin**

Taskbar Monitor Enhanced derives from `leandrosa81/taskbar-monitor`. Upstream attribution and GNU GPL v3.0 licensing are retained.

AI-assisted tools were used as engineering support for drafting, refactoring, diagnostics, testing, documentation, and iterative review. Architecture, hardware validation, acceptance decisions, and release responsibility remained under human control.
