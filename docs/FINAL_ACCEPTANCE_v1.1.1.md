# Final Acceptance — Taskbar Monitor Enhanced 1.1.1

## Decision

**PASS — local v1.1.1 stability candidate committed and eligible for public-release packaging.**

Authority revision: `TBME_V1_1_1_STABILITY_HARDENING_R06`

## Baseline before mutation

- installed version: `1.1.0.0`
- main EXE SHA-256: `1A8DF8F3733E9B73EE14A541412259B90554EF492FB74ED94976DE3490546A28`
- main source SHA-256: `143BE229CBD4AE2151C1ED1C4374EF7B65E0757C4319D2F098EFCFA2894ECCFD`
- Explorer PID: `3992`

## Accepted v1.1.1 candidate

- installed version: `1.1.1.0`
- main EXE SHA-256: `D2112BCB9C14D3916CD888449101701F4EC3E3FFF61EE2C83C7BB6DD97840CB4`
- main source SHA-256: `125E48D3054025AA98F2E1459060E1BAEF7B99548A6C771FB99C99600BD84BBA`
- build: PASS (`csc.exe /noconfig` with pinned .NET Framework 4.8 references)
- self-test: PASS
- runtime smoke: PASS
- process count after install: 1

## Stability hardening state

- external NVIDIA-SMI polling default: `false`
- shell watchdog interval: `250 ms`
- shell style-integrity interval: `2000 ms`
- Safe Placement refresh minimum: `5000 ms`
- watchdog performs UI-Automation placement scan: `false`

## User acceptance

The user exercised the installed candidate in the real environment that had previously produced repeated console flashes and taskbar instability and returned verdict `PASS`.

- Explorer PID before acceptance: `3992`
- Explorer PID after acceptance: `3992`
- Explorer restarted: NO
- Explorer relevant events: `0`
- Application Error Event 1000: `0`
- Application Hang Event 1002: `0`
- rollback: NOT REQUIRED
- candidate retained: YES

## Root-cause evidence motivating the update

A prior Windows Security Event 4688 capture showed `132` `conhost.exe` creations parented by `nvidia-smi.exe` during roughly 134 seconds, compared with only a small number of other console-host paths. TBME v1.1.0 directly polled `nvidia-smi.exe` in its real-time GPU path. Version 1.1.1 disables that external-process polling by default and keeps WDDM + LibreHardwareMonitor as normal GPU telemetry sources.

## Residual-risk statement

Historical Explorer Application Hang events observed after the v1.1.0 accepted window had **unproven causality** to TBME. Version 1.1.1 reduces shell/UI-Automation pressure and passed the targeted local acceptance above. This record does not claim that all future Explorer or taskbar failures are impossible.
