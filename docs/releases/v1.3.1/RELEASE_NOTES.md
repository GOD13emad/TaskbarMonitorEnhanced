# Taskbar Monitor Enhanced v1.3.1 — Real Theme Preview

v1.3.1 is a focused UI patch built on the immutable v1.3.0 public release.

## What changed

- The Display page no longer shows a synthetic palette card for the selected theme.
- The Settings theme preview now uses the **same taskbar renderer pipeline** as the live monitor:
  `PaintBackground -> BuildMetricViews -> PaintMetric`.
- In the running application, the preview is rendered from the active Overlay instance, so it uses the current live metric snapshot and the existing sparkline history.
- Theme changes redraw the real taskbar strip immediately inside Settings.
- The preview strip is rendered at the real taskbar height of **48 px**, 1:1 inside the preview surface.
- Off-screen theme rendering no longer changes the live OverlayForm size; width is passed explicitly into metric-layout selection. This prevents preview rendering from moving or resizing the taskbar monitor.
- Settings proof now records `ThemePreview=ACTUAL_TASKBAR_RENDERER`.

## Sensor layer

No sensor binary or sensor protocol behavior changes in v1.3.1.

- Broker protocol: `1.1.2+r21`
- Sensor Supervisor: `1.3.0+r33`
- R21 process-isolated architecture retained.

The installer must reuse the exact healthy accepted sensor layer and update only the Main/UI payload.

## Release gates

The exact v1.3.1 candidate must pass:

- 0-warning / 0-error build
- Setup verify
- built-in self-test with `REAL_THEME_PREVIEW=TRUE`
- 9-page Settings proof with `ACTUAL_TASKBAR_RENDERER`
- visual inspection of the Display-page preview
- 28-theme and compact renderer regression
- health/shell/hardware/temperature regression
- deterministic clean-clone build
- live install with exact sensor-layer reuse
- installed runtime health PASS
- exact-head GitHub CI and published asset digest verification

Public trusted Authenticode signing is not claimed unless independently proven.
