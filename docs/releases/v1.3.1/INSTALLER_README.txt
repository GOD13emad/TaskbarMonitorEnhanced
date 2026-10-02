# Taskbar Monitor Enhanced v1.3.1

v1.3.1 is a focused Main/UI patch.

The Display Settings page now shows the selected theme through the same renderer used by the live Windows taskbar monitor, rather than a palette-only mock preview.

The protected sensor architecture is unchanged from v1.3.0:
- Broker protocol: 1.1.2+r21
- Sensor Supervisor: 1.3.0+r33
- R21 process isolation retained

The installer verifies exact sensor payload hashes and live health before reusing the existing protected sensor layer.

v1.3.0 and earlier public releases remain immutable.

Public trusted Authenticode signing is not claimed unless independently proven.
