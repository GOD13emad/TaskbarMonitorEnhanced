# Taskbar Monitor Enhanced v1.7.1 (unsigned patch candidate)

- Restores fixed taskbar position from v1.6: never moves above Start/Search.
- Reasserts topmost z-order on application focus changes without activation, while leaving Settings unobstructed.
- Glass mode has its own ON/OFF slider in Settings > Display. ON fixes background opacity at 0% and locks its control; OFF restores the saved 1–100% value.
- Preserves 49 themes, independent metric glyph/graph colors and legacy v1.7.0 data.
- Settings is an independent interactive topmost window, available in Alt+Tab.
- One canonical per-user installation. Official v1.7.0 Stable/Preview1 and v1.6 upgrades require exact source/Setup SHA; no forced uninstall, blind overwrites or user data loss. Interrupted transaction rollback remains guarded.
- Installer is not Authenticode signed (explicit owner decision). This note does NOT constitute external signed-lab or physical power-failure acceptance.
- This is a test candidate until independent real Windows hosted update/visual regression and release asset SHA checks pass.
