# Taskbar Monitor Enhanced 1.0.2

Taskbar Monitor Enhanced 1.0.2 promotes the long-run accepted post-1.0.1 engineering baseline.

## Highlights

- AMD Radeon GPU temperature support through AMD ADLX 1.1 when LibreHardwareMonitor exposes no AMD GPU temperature sensor.
- Compact taskbar rendering keeps CPU/GPU temperature readable at narrow widths.
- Download and upload telemetry automatically stack vertically when the Network card cannot fit both values inline.
- Direct left-click and right-click interaction without click-through behavior.
- No-activate shell interaction so opening settings or context menus does not steal taskbar focus unnecessarily.
- Stable taskbar geometry during Start/search/taskbar transient UI changes.
- Persistent shell-style definition plus runtime self-heal protection against WinForms/taskbar style drift.
- 14 themes retained with wide and compact regression coverage.

## Validation completed before packaging

The installed engineering baseline completed a 600-second long-run acceptance campaign with:

- 582 window-style/geometry samples.
- width fixed at 532 px and height fixed at 48 px for the entire campaign.
- zero invalid window-style samples.
- zero style-repair events required during the campaign.
- taskbar parent relationship preserved throughout.
- `WS_EX_NOACTIVATE` present throughout and `WS_EX_TRANSPARENT` absent throughout.
- AMD GPU temperature source continuously validated as `AMD_ADLX_1.1`.
- 14-theme wide proof and 14-theme compact proof at 592x48 and 500x48 with zero measured text overflow.

## Compatibility and behavior

- Windows x64.
- Main application remains non-elevated.
- Protected CPU sensor broker/supervisor architecture is retained.
- Existing settings are intended to be preserved during upgrade.

## Open-source origin and AI-assisted development

Taskbar Monitor Enhanced is derived from the GPL-licensed `leandrosa81/taskbar-monitor` project. Upstream attribution and GNU GPL licensing are preserved.

AI-assisted tools were used for engineering support including diagnostics, code drafting, refactoring, test scaffolding, documentation, and iterative review. Requirements, validation, acceptance decisions, and release responsibility remain under human control.

## License

GNU General Public License v3.0.
