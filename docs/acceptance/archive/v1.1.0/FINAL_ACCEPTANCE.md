# Final Acceptance Record — Taskbar Monitor Enhanced v1.1.0

## Accepted baseline

- Functional baseline: `DISK_TEMP_BROKER_RESTORE_R02R6`
- Final seal: `TBME_V1_1_0_FINAL_ACCEPTANCE_SEAL_R02R6R2`
- Local acceptance status: `PASS_V1_1_0_LOCAL_FINAL_ACCEPTED_R02R6`

## Accepted installed hashes

| Component | SHA-256 |
|---|---|
| `TaskbarMonitorEnhanced.exe` | `1A8DF8F3733E9B73EE14A541412259B90554EF492FB74ED94976DE3490546A28` |
| `TaskbarMonitorEnhanced.cs` | `143BE229CBD4AE2151C1ED1C4374EF7B65E0757C4319D2F098EFCFA2894ECCFD` |
| acceptance `config.json` | `9A6452CB17CF23CF4A2B44BA5AE9EF01ED8DD1C3FE64C4530D50087F7A25A79C` |
| `TaskbarMonitorSensorBroker.exe` | `B3CE8F7636FD5B0157DE5CC69CBB2DD633A1A67FCA567491C0ADFDB8CF295AD3` |
| `TaskbarMonitorSensorBroker.cs` | `6FE057411725A4D25F05772C429D50E0AFA3C9C7B09723D48AE7ECE8C1D2A325` |

The config hash documents the validation environment; a public installer must not replace a user's existing personal configuration with this acceptance file.

## Shell acceptance

The accepted v1.0.2 taskbar child-window shell architecture was restored without changing its eight audited core blocks.

Acceptance evidence:

- ShellState PRE: PASS
- ShellState POST: PASS
- direct taskbar child relationship: PASS
- visible: PASS
- active visual beacon: PASS
- manual Start open/close x5: PASS
- TBME remained visible/fixed through the manual Start checks

The automated StartProbe was classified as diagnostic-only after a proven focus-interference false negative. Real user Start x5 plus objective ShellState PRE/POST are the accepted interaction gates.

## Storage-temperature acceptance

The elevated LibreHardwareMonitor storage-temperature provider returned all four physical-drive temperatures. Windows USB bridge rows were correlated to physical SSD telemetry using LibreHardwareMonitor storage hardware IDs / physical-drive indices before model-name fallback.

Validated mapping:

| Windows disk | Volume | LHM storage | Hardware ID |
|---|---|---|---|
| Samsung SSD 990 PRO 2TB | C: | Samsung SSD 990 PRO 2TB | `/nvme/0` |
| Samsung SSD 980 PRO 2TB | D: | Samsung SSD 980 PRO 2TB | `/nvme/1` |
| JMicron Tech SCSI Disk Device | E: | TwinMOS SSD | `/nvme/2` |
| Lenovo USB 3.1 SCSI Disk Device | H: | CT1000BX500SSD1 | `/ssd/3` |

Acceptance gates:

- predeploy hardware probe: 4/4 PASS
- runtime identity map: 4/4 PASS
- user-visible disk temperature gate: PASS
- final hardware probe: 4/4 PASS
- final-seal current hardware probe: 4/4 PASS

## Runtime soak

R02R6 completed a 600-second acceptance soak:

- samples: 300/300
- non-responsive samples: 0
- maximum consecutive non-responsive: 0
- TBME PID drift: 0 during accepted run
- Explorer PID drift: 0 during accepted run
- new Explorer Event 1002 during accepted run: 0

## Post-acceptance Explorer forensic record

Two real Explorer `Application Hang` Event 1002 records occurred after the accepted R02R6 window:

1. 2026-08-21 00:11:51 +03:30 — Explorer PID 27992
2. 2026-08-21 00:12:51 +03:30 — Explorer PID 34444

Forensic classification:

`POST_ACCEPTANCE_EXPLORER_HANG_X2_CAUSALITY_UNPROVEN_RECOVERY_PASS`

Facts:

- both hangs were after the accepted R02R6 window;
- TBME itself did not crash;
- the TBME process survived the Explorer restarts;
- TBME reattached to the new Explorer process;
- current ShellState was PASS at final seal;
- current four-disk temperature telemetry was PASS at final seal;
- causality of the two Explorer hangs to TBME remains unproven.

This record is a residual-risk disclosure, not proof that TBME caused the Explorer hangs.

## Publication rule

The accepted local application/Broker code must not be modified merely for packaging. Public release packaging must preserve the accepted payload hashes or, if a binary is rebuilt, it must be treated as a new unaccepted binary until its release lifecycle is separately validated.

The official GitHub Release must publish an explicitly named installer artifact and an explicitly named corresponding-source ZIP with SHA-256 values recorded in the release notes and download documentation.
