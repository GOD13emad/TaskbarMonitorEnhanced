# Third-Party Notices

Taskbar Monitor Enhanced uses third-party open-source components for hardware telemetry and low-level sensor access.

## LibreHardwareMonitor

Project: LibreHardwareMonitor  
Used for hardware sensor access, including CPU temperature telemetry.  
The project is distributed under its upstream open-source license. Taskbar Monitor Enhanced v1.1.1 and the v1.1.2-rc5 R21 candidate use LibreHardwareMonitor 0.9.6 in the protected sensor backend.

For the R21 reproducible build, the official upstream LibreHardwareMonitor.zip release asset is pinned by SHA-256:

086D9F1B5A99E643EDC2CFAAAC16051685B551E4C5AC0B32A57C58C0E529C001

Upstream copyrights and license terms remain with the LibreHardwareMonitor project and its contributors.

## PawnIO

PawnIO is used by the protected sensor layer where low-level hardware access is required.

PawnIO and its setup components remain subject to the licensing terms published by their upstream project. Taskbar Monitor Enhanced does not claim ownership of PawnIO.

The R21 candidate pins PawnIO Setup 2.2.0 from its official upstream release asset with SHA-256:

1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032

The Taskbar Monitor Enhanced uninstaller intentionally leaves PawnIO installed because other hardware-monitoring software on the same machine may depend on it.

## Windows and other names

Windows, Microsoft, NVIDIA, Intel, and other product names may be trademarks of their respective owners. Their mention describes compatibility or telemetry sources and does not imply endorsement.

For the project-level GPL terms and upstream application attribution, see `LICENSE`, `COPYRIGHT_AND_ATTRIBUTION.md`, and `UPSTREAM_REFERENCE_GPL_NOTICE.md`.
