# Taskbar Monitor Enhanced 1.1.0

Taskbar Monitor Enhanced 1.1.0 promotes the locally accepted R02R6 engineering baseline and its R02R6R2 final seal.

## Highlights

- Multi-disk telemetry with per-disk read/write activity, capacity, and temperature.
- Elevated LibreHardwareMonitor storage-temperature broker with four-drive validation.
- Generic physical-disk identity correlation using LibreHardwareMonitor storage hardware IDs before model-name fallback.
- USB bridge temperature mapping validated for both JMicron and Lenovo USB storage bridges.
- Restored accepted taskbar child-window shell architecture for stable Start/Search/taskbar behavior.
- Automatic recovery after Windows Explorer restarts while keeping the main TBME process alive.
- Existing v1.1.0 multi-hardware, theme, hover-detail, updater, GPU, CPU, network, and disk telemetry retained.

## Accepted storage mapping on the validation system

- `C:` Samsung SSD 990 PRO 2TB -> `/nvme/0`
- `D:` Samsung SSD 980 PRO 2TB -> `/nvme/1`
- `E:` JMicron Tech SCSI Disk Device -> TwinMOS SSD -> `/nvme/2`
- `H:` Lenovo USB 3.1 SCSI Disk Device -> CT1000BX500SSD1 -> `/ssd/3`

The implementation does not hard-code JMicron or Lenovo model names for normal matching. It prefers the LibreHardwareMonitor physical storage index and falls back to model matching only when necessary.

## Final local acceptance

The accepted v1.1.0 application baseline completed:

- manual Start open/close x5 with TBME remaining visible and fixed;
- ShellState PRE = PASS;
- ShellState POST = PASS;
- four real disk temperatures with zero `Temp N/A` on the accepted validation system;
- runtime storage identity mapping 4/4;
- final hardware probe 4/4;
- 600-second / 300-sample soak with 300/300 responsive samples;
- stable TBME PID during the accepted run;
- stable Explorer PID during the accepted run;
- zero new Explorer Application Hang events during the accepted R02R6 window;
- Broker committed;
- Candidate committed.

## Explorer residual-risk disclosure

Two real Windows Explorer `Application Hang` Event 1002 records occurred after the accepted R02R6 window. Causality to TBME is **unproven**. The TBME process survived the Explorer restarts and successfully reattached to the restarted shell. Current ShellState and four-disk temperature telemetry were PASS at final seal.

This residual risk is intentionally disclosed rather than silently ignored or attributed to TBME without evidence.

## Accepted engineering hashes

- Main EXE: `1A8DF8F3733E9B73EE14A541412259B90554EF492FB74ED94976DE3490546A28`
- Main source: `143BE229CBD4AE2151C1ED1C4374EF7B65E0757C4319D2F098EFCFA2894ECCFD`
- Config used during acceptance: `9A6452CB17CF23CF4A2B44BA5AE9EF01ED8DD1C3FE64C4530D50087F7A25A79C`
- Sensor Broker EXE: `B3CE8F7636FD5B0157DE5CC69CBB2DD633A1A67FCA567491C0ADFDB8CF295AD3`
- Sensor Broker source: `6FE057411725A4D25F05772C429D50E0AFA3C9C7B09723D48AE7ECE8C1D2A325`

The public release installer and corresponding-source package must be separately hash-identified when attached to the GitHub Release.

## Compatibility

- Windows x64.
- Main application remains non-elevated.
- Administrator approval is limited to the protected hardware-sensor layer.
- Existing settings are intended to be preserved during upgrade.

## Open-source origin and AI-assisted development

Taskbar Monitor Enhanced is derived from the GPL-licensed `leandrosa81/taskbar-monitor` project. Upstream attribution and GNU GPL licensing are preserved.

AI-assisted tools were used for engineering support including diagnostics, code drafting, refactoring, test scaffolding, documentation, and iterative review. Requirements, validation, acceptance decisions, and release responsibility remain under human control.

## License

GNU General Public License v3.0.
