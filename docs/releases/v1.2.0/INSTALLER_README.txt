# Taskbar Monitor Enhanced v1.2.0

Taskbar Monitor Enhanced is a lightweight Windows taskbar system monitor for live CPU, RAM, disk, network, GPU, VRAM and temperature telemetry.

## What is new

v1.2.0 introduces three user-facing improvements:

1. Hardware hover details are suppressed while Settings is open, preventing a hover-detail flyout from remaining stuck.
2. Settings has been redesigned with a modern left-navigation layout, clearer hierarchy, dark surfaces, consistent controls and a live theme preview.
3. The built-in theme library is doubled from 14 to 28 themes, including Aurora Borealis, Solarized Luxe, Arctic Frost, Sakura Night, Matrix Grid, Desert Sand, Royal Amethyst, Ocean Depth, Copper Industrial, Nordic Light, Ember Forge, Synthwave Sunset, Quantum Violet and Monochrome Paper.

The accepted protected sensor layer remains `1.1.2+r21`; this feature release does not replace the process-isolated CPU/GPU/storage architecture.

## Install and uninstall

The installer registers Taskbar Monitor Enhanced in Windows Installed apps and creates the per-user uninstaller at:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe`

Uninstall through Windows Settings > Apps > Installed apps, or run:

`%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe /uninstall`

The project uninstaller removes the application, shortcuts, Start-with-Windows registrations and uninstall registration. PawnIO is intentionally not removed automatically because another hardware-monitoring application may depend on it.

## Reliability and privacy

- Main UI runs non-elevated.
- Protected hardware sensing remains isolated and supervised.
- Start with Windows retains independent primary and recovery registrations.
- GitHub update checks and automatic installation remain constrained by immutable-release and SHA-256 integrity gates.
- Unsupported sensors remain N/A rather than being fabricated.
- See PRIVACY.md and CODE_SIGNING.md for network and signing policy.

## Candidate status

This document belongs to the v1.2.0 candidate build. A public release must not be claimed until the full local/runtime/GitHub release gates pass on the exact release commit.

## Project

Lead Developer & Maintainer: Dr. Ali-Akbar Emadeddin
License: GNU GPL v3.0
Repository: https://github.com/GOD13emad/TaskbarMonitorEnhanced
