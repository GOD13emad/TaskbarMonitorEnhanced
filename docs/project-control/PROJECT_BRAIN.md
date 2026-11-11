## R414 — Windows Install.cmd PowerShell7 to CMD to Windows PowerShell 5.1 module shadowing corrected (real Windows 10 and Windows 11 local PASS; Hosted PENDING)

- Goal: one robust Windows10/11 full offline prerequisite-aware install/upgrade/start preserving v1.6-style user UI, safe upgrades and settings; PR #106 remains draft based on blocked security PR #98. Exact starting feature head 3b7decf7901e3255dffb7afc47aa61216b1138fb. R411/R412 had previously accepted genuine Windows11 disposable full install and official 1.7.9 to 1.7.10 upgrade; do not extend those results to untested environments.
- Real fault reproduced on Emad_Server Windows10 Enterprise build 19045: source Install.cmd SHA A1E1FC3742BB22F17754EA795DA330B8D0837F2043C0F8F1CC203695E81E017B invoked via PowerShell7 to CMD with a genuine official GitHub v1.7.10 Setup, and -CheckOnly failed with exit 1 / R409_BOOTSTRAP_FAILED: Get-FileHash not recognized. The same source launcher .ps1 invoked directly under WindowsPowerShell5.1 passed. Explicit parallel process diagnostics: direct WinPS51 PSModulePath had only Desktop modules and GetFileHashPresent=true; WinPS51 via CMD inherited earlier PS7 module paths and GetFileHashPresent=false. Microsoft documents precisely this intermediate-process PSModulePath shadowing and recommends clearing PSModulePath in CMD before starting WinPS51: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath .
- Root cause addressed in existing packaging/windows/Install.cmd: after setlocal, set "PSModulePath=" clears only the child CMD process inherited variable, allowing Windows PowerShell 5.1 to restore its own default module directories. No global/user environment, execution policy, UAC or registry changes. Fixed exact source CMD SHA 3E1A9DC7D5D3C2028AB4250BF23C2C091DD77EA136B45D22BAEAEFBF3E428DC6. On same real Win10 PS7-contaminated parent, exact fixed CMD -CheckOnly returned exit0, Platform Windows10-x64, FrameworkRelease 533325, verified exact official GitHub v1.7.10 Setup SHA 1D0326CF11CEE069AD295112A9CA49D9FCBDB58ECDAB46FFE9C0F7172CE26D7E, no execution and parent PSModulePath unchanged. Host receipt .local/audit/r414-windows-cmd-autoload-fix/R414_windows10_real_cmd_root_cause_proof.json SHA 6DAC3DB20C8B81F4758839BE8382A17A808C9C5ED3E9810DEFD84E1812CEADC2.
- Existing pack tester now injects real PS7 module directories ahead of WindowsPowerShell modules and tests Install.cmd under the polluted environment. On Windows11 owner native read-only test, full new bundled ZIP local SHA BDBD681E34FDE4D34D0E5CF6F330821DDC576D69F082A8A870EC4270D388C3A8 (128521891 bytes) passed PS7-polluted CMD CheckOnly, genuine Microsoft .NET Framework 4.8 Authenticode+SHA, pinned EXE /verify and denied writer, rejection of modified Setup, manifest and runtime, and unchanged owner Main/config SHA. This local candidate was rebuilt with pinned older local Setup SHA FEDFD3F1F364130CC07B172D35290EF317D48DD8F281B51B1FBE9273A45B0537; it is not assumed equal to exact Hosted Setup. Hosted workflow now requires R414_PASS_HOSTED_WINPS51_CMD_CLEARS_INHERITED_PS7_MODULE_PATH on signed Offline -VerifyOfflineRuntime (without executing product Setup), and still rejects Windows Server for installation. README describes the process-scoped fix.
- A separate Microsoft Framework download attempt on Windows10 host timed out after 37804947 bytes; the unverified partial was renamed .partial-not-executed and not launched. Therefore Windows10 signed Offline bundle actual validation and full Windows10 installation, missing-.NET UAC/reboot, Windows10 previous-version upgrade, optional sensor-driver installation and native Linux/macOS packages remain NOT TESTED/BLOCKED. No owner installed app or public Release changed. Durable local receipt .local/audit/r414-windows-cmd-autoload-fix/R414_acceptance.json SHA 9DF6971D6DD51543EB2D0027CC085E5CC9ECFC87AA35DF179BCEE81FCAD9F928.
- Remaining security gate: independent last-push review and six critical CodeQL command-line taint findings on security PR #98; the previously requested reviewer is not self-approved and alerts are not dismissed. Draft PR #106 must not be merged before required security acceptance. Next: commit/push and verify exact-head R414 CI + Artifact; later disposable Windows10/missing-runtime UAC/reboot and true native macOS/Linux ports.
## R413 — Actual Windows 10 Enterprise 19045 native prerequisite/platform preflight PASS (synthetic non-executable package; NO installation)

- Primary objective is one reliable Windows 10/11 x64 dependency-aware offline installer that checks the official Microsoft framework, supports real per-user install/upgrade/start and preserves settings, without bypassing pending security gates. R411 and R412 already accepted Windows 11 disposable fresh and official v1.7.9->v1.7.10 upgrades with Main launched and settings preserved; no R413 code changes have been made. Active feature draft PR #106 depends on security PR #98.
- Discovered existing remote Emad_Server is **Microsoft Windows 10 Enterprise x64 build 19045** (real CLIENT ProductType=1, administrator session), not Windows Server. Its TaskbarMonitorEnhanced per-user root was absent. No disposable Hyper-V/Sandbox environment was available there (Get-VM unavailable, VMMS absent, WindowsSandbox.exe absent), so a full program or Microsoft prerequisite installation on that live host was NOT authorized or performed. The separate Emad-PC Windows 11 Sandbox was occupied by another independent R58 run and was not modified.
- In a new isolated C:\temp\tbme-r413-win10-preflight fixture on the Windows 10 host, transferred the exact source launcher packaging/windows/Install-TaskbarMonitorEnhanced.ps1 SHA-256 C8DFB750F4835F513CC3A6D443F1B43B3299284C1ED93426F8A492122A61973F. Created a **non-PE non-executable 58-byte synthetic Setup sentinel**, SHA C560946C4A0DC8D9695E63C91DA384B3ED872AE44D7745ACEE2E80DD3EEFF367 and a schema-valid manifest referencing it. The launcher was deliberately invoked **ONLY with -CheckOnly** under native Windows PowerShell 5.1: exit 0, Platform Windows10-x64, FrameworkRelease 533325 (>=528040), WillInstallFramework=false, ExecutedSetup=false, ModifiedOwnerSettings=false, Manifest OfficialRuntimeBundled=false. No genuine Setup or .NET runtime was run on Windows 10.
- Two independent negative fixtures were copied from that synthetic scope; invoking -CheckOnly refused a mutated manifest/bundled-runtime mismatch with R409_PACKAGE_MANIFEST_INVALID and refused modified sentinel bytes with R409_SETUP_HASH_MISMATCH. Original synthetic fixture and the host's absent product root remained unchanged; no machine-wide changes.
- Durable read-only Windows 10 host receipt at C:\temp\tbme-r413-win10-preflight\R413_windows10_native_preflight_receipt.json was copied SHA-verified to ignored .local/audit/r413_windows10_real_client_preflight_receipt.json at project root, SHA-256 FB636593BCF84DC9A95E1E1605C876D06C4221EA1B28F5A9F1F26FF946EFF0EC. Scope is Windows 10 OS detection, prerequisite registry read and fail-closed package integrity checks with a non-executable synthetic fixture; this is NOT real Windows 10 full offline ZIP acceptance or missing-.NET, UAC, reboot, device-driver acceptance.
- Additional real public release acceptance: fetched official GitHub v1.7.10 Setup EXE on Windows 10 Enterprise 19045, verified its public Release SHA-256 1D0326CF11CEE069AD295112A9CA49D9FCBDB58ECDAB46FFE9C0F7172CE26D7E and size 8,613,376 bytes. Reused exact hashed R413 source bootstrap under native PowerShell 5.1 in a new isolated fixture with the **actual** public Setup and matching manifest: -CheckOnly returned Windows10-x64 and FrameworkRelease 533325 with no Setup execution or settings change. An independent copied genuine Setup corrupted by appended data failed closed with R409_SETUP_HASH_MISMATCH; original public file unchanged. Host read-only addendum copied to project ignored .local/audit/r413_windows10_genuine_public_setup_checkonly_receipt.json, SHA-256 FAF76D984B3F48C704C2092CF606F570D13A2B387B67974175B9128AAB1AB64B. Scope excludes actual installation, missing-framework UAC, reboot, hardware helpers and the experimental R410 Setup.
- Security PR #98 remains BLOCKED with six critical CodeQL command-line taint findings and a genuinely independent reviewer already requested. Its code and alerts remain unchanged, with exact six-sink technical review brief posted (https://github.com/GOD13emad/TaskbarMonitorEnhanced/pull/98#issuecomment-6800694882). No self-approval, hidden alerts, merge, public release, user installed app mutation, administrative reconfiguration or restart.
- Next: obtain a genuine disposable Windows 10 x64 client with absent .NET Framework 4.8 when possible, perform real offline prerequisite/UAC/restart/fresh and previous-version upgrade/launch, preserving data. Separately obtain actual independent security disposition for six CodeQL findings before merging PR #98 then #106 or publishing. Linux/macOS require real native ports, not repackaging Windows Setup.
## R412 — Actual published v1.7.9 to verified full-offline v1.7.10 Windows 11 client upgrade PASS

- R411 (real Windows 11 clean installation and same-version upgrade) was accepted at head 8bedc955445aafc23e334a3aa81ecfd325714af7. R412 extended acceptance to an actual published earlier version with user settings preservation, on a fresh disposable Windows 11 Enterprise build 26100 Sandbox guest, not the owner PC. Exact public v1.7.9 Setup 8,577,536 bytes was verified in two independent local copies against immutable public GitHub release SHA-256 3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E. An interrupted new GitHub download produced a SHA-mismatched partial and timed out; it was isolated and never executed. Existing official SHA-matching copies were preserved and one was staged. Target full-offline v1.7.10 GitHub artifact SHA-256 668F879EC3DFBA30766DFF3DF35ACB38091A68D5BDF1816D5A6B2C78666CFB42, plus verified real signed Microsoft Framework 4.8.
- Guest username WDAGUtilityAccount, OS Windows 11 Enterprise build 26100, .NET Framework Release 533320. Verified no prior product root. Sandbox configuration networking/clipboard/vGPU disabled; input mapped read-only, output was a distinct auditable folder. No installed owner app, desktop settings, home paths or other user's active sandbox were touched. Previous R412 launch attempt was intentionally refused because another unrelated R58 Sandbox session was active; once it was gone, a fresh independent R412 guest was started.
- Guest actually ran official 1.7.9 Setup /install /quiet /desktop=0 /startup=0 with exit 0, Main present and install_state Version/PublicVersion 1.7.9. Created 3 synthetic user canaries: config.json, config.json.bak, and extra install_state.json UserCanary plus independent file outside product root. Then invoked actual signed offline bootstrap for v1.7.10: exit 0, Main file present and matching process running, install_state Version/PublicVersion 1.7.10, config and backup SHA-256 unchanged, extra state canary and outside file preserved, no machine-wide installation in Program Files. Child stderr empty. This is PASS for the observed guest+artifact, NOT for Windows 10, absent .NET Framework, reboot/UAC, untested sensor drivers or all possible update origins.
- Independent durable owner-host receipt under ignored .local/audit/r412-windows11-official-v179-upgrade-sandbox/R412_host_acceptance.json, SHA-256 291D1BF934ED05BB25833FAE1D924273820022DFA8CFE970DEFE9D7B0ECE5C85; original raw guest receipt and child logs also retained. Only the exact R412 Sandbox instance was closed after PASS. Parent PR #98 still BLOCKED by 6 CodeQL critical findings and independent human review; dependent PR #106 remains draft. Public release and installed owner program unchanged.
- Remaining independent gates: missing-.NET Framework 4.8 real UAC+reboot on disposable older Windows; Windows 10 clean install/upgrade; valid independent security review/CodeQL disposition on PR #98; only then merge/publish. Linux/macOS require native port, not relabeling EXE.
 ## R411 — Actual full offline fresh/install/launch and guarded same-version upgrade PASS on disposable Windows 11 Sandbox

- Objective: advance R410 complete Windows 10/11 dependency-aware Offline pack from static integrity/CheckOnly to an actual Windows CLIENT desktop installation in isolation. Exact source head e722584560ea81154dcf9a687cfee2fc520f6cc9, still dependent draft PR #106 targeting blocked security PR #98. The GitHub-built R410 offline ZIP used was the independently downloaded artifact from run 43019213098, SHA-256 668F879EC3DFBA30766DFF3DF35ACB38091A68D5BDF1816D5A6B2C78666CFB42; this is source-equivalent to the R410 latest code, whose follow-up commit modified documentation only.
- A fresh Microsoft Windows 11 Enterprise 26100 Windows Sandbox guest with username WDAGUtilityAccount was launched from owner Windows 11 Pro. WindowsSandbox optional feature reported InstallState=1 (enabled), actual WSB XML used Networking Disable, Clipboard Disable, vGPU Disable; only the exact isolated input folder was mounted read-only and the dedicated output folder writable. No owner app root or user data was mapped, no guest networking, no Windows updates, no owner OS/service changes. Guest did not already have TaskbarMonitorEnhanced installed and had .NET Framework Release 533320 (meets 528040); this does NOT test missing-framework installation.
- Initial guest attempt failed before any install due to a disposable PowerShell test harness parameter using reserved automatic variable $args, which passed a null ArgumentList to Start-Process. Evidence preserved in isolated R411_attempt1_harness_error.json; it is not a product installer failure. Renamed the harness argument to $cliArgs, verified AST parses and reran a new, independently fresh Sandbox instance. No product code was changed for this harness-only problem.
- Second Windows 11 Sandbox acceptance PASS: verified downloaded Offline ZIP SHA, actual bundled Microsoft runtime SHA and Authenticode signer; non-install CheckOnly PASS; full real bootstrap invoked Setup /install /quiet successfully with exit code 0; installed Main exe existed and its process was running; rerunning identical bootstrap performed real guarded same-version in-place update with exit code 0, Main existed and was running afterwards, and SHA-256 of Main and TaskbarMonitorEnhanced.exe.config were preserved across upgrade. Both child stdout logs contain exact R409_BOOTSTRAP_SUCCESS_FRAMEWORK_SETUP_AND_MAIN and all child stderr logs are empty.
- Independent host-side receipt validates guest account, Windows build, registry Release, real signed dependency, preflight result, absence of preexisting product, both exit codes, Main launch/process presence, SHA persistence and original-host isolation. Exact local ignored files: .local/audit/r411-windows-sandbox-guest/R411_host_acceptance.json, SHA-256 6F714BFEECBA17970DE0CDBD44C9DAEBBA09EFE0CAF3BBBA3348DB5418C67A18; guest output R411_guest_status.json, SHA-256 0B570375F193BE54FF9276217AD40CCB902F1FF9D70226944E9852AC69C34DA0. Exact-owned Sandbox window/session was then closed and the isolated evidence persisted. Owner app/config not touched.
- Gate scope: Windows 11 x64 disposable desktop fresh install and same-version upgrade/start is PASS for that one full offline artifact/guest; this is not Windows 10 acceptance, a real older-version in-place upgrade test, missing .NET Framework installation, UAC denial/reboot tests, automatic driver/PawnIO installation, or proof of native Linux/macOS support. Keep all those as PENDING/BLOCKED. The original branch, installed user's app and public v1.7.10 release stay unchanged. Independent last-push review and six CodeQL critical alerts remain security PR #98 blockers.
- Next: only test remaining missing-framework UAC/reboot and Windows 10/older-version upgrades on another disposable client with matching capabilities; investigate security PR #98 CodeQL failure and obtain actual independent human review. Keep PR #106 draft until security and full acceptance permit release.
## R410 - full offline Windows dependency pack with actual signed Microsoft runtime (local plus hosted PASS; desktop installation PENDING)

- Context: user-requested per-OS prerequisite-aware install/update/run. Windows 10/11 x64 is a native .NET Framework 4.8/WinForms/Win32 product. macOS/Linux remain BLOCKED pending actual native UI, panel and sensor ports; their installers cannot honestly be made by repackaging Windows binaries. Existing public v1.7.10, security PR #98 and the actual owner install/config remain unchanged. Isolated existing feature/r409-platform-bootstrap branch at prechange head 2ec98adcefeb3dd6219a63358030c608d3c7430c.
- Verified Microsoft dependency (never executed): Microsoft's fixed .NET Framework 4.8 offline URL returned HTTP 200 and 121,307,088 bytes. Downloaded file SHA-256 68C9986A8DCC0214D909AA1F31BEE9FB5461BB839EDCA996A75B08DDFFC1483F exactly matches pinned official package; Windows Authenticode Status Valid, signer CN=Microsoft Corporation. Scratch executable is stored only in ignored R409 .local/audit, not source, deployment or installed user root.
- R410 packaging: existing Windows pack builder now accepts an optional verified -RuntimePath, checks exact filename, SHA-256 and Microsoft Authenticode before copy, then checks staged contents and emits a separate complete Offline ZIP. Original smaller online-only candidate route remains available and unchanged when no RuntimePath is passed. The same single Windows bootstrap now validates manifest/runtime bundle consistency and provides read-only -VerifyOfflineRuntime that works on Windows Server for CI without running or installing any component.
- Security hardening: before invoking the official prerequisite with native UAC only when required, the child opens a read-only FileStream with FileShare.Read, hashes the opened file and verifies Authenticode while holding the handle, retaining the deny-write/deny-delete-sharing handle for the entire UAC and installer lifetime. This mitigates later leaf replacement after prior verification. Native harmless Setup /verify executed successfully while held under identical read-only sharing; separate attempted write-open was refused. This is a scoped Windows file-share property, not a proof against all malicious directory races or UAC impersonation.
- Local complete Offline ZIP with six entries, exact SHA-256 C9EDDC84F741155B134A9B46998E1F75F69B682C694FC15ED7C7A0442B0BEF1F and size 128,521,027 bytes. Source 1.7.10 Setup SHA FEDFD3F1F364130CC07B172D35290EF317D48DD8F281B51B1FBE9273A45B0537. Full local Windows 11 x64 fixture PASS: signed real runtime verified in pack (no execution), native pinned Setup /verify PASS, write-open sharing refused, actual Install.cmd -CheckOnly and script preflight PASS, modified Setup and manifest fail closed, altered offline Microsoft EXE fail closed, owner Main/config hashes unchanged. PS5 parser and workflow YAML passed. No real runtime installation, UAC, reboot, full app install, or Windows 10 desktop acceptance was performed.
- CI: updated existing single audit-r409-windows-bootstrap.yml workflow (not a new duplicate) to download official Microsoft package on disposable GitHub Windows Server, verify SHA/Authenticode, compile the four-product components, package full Offline ZIP, test no-install read-only signature verification and refusal of Windows Server, and upload short-lived CANDIDATE artifact. Exact-head hosted run 43019213098 at commit e191464142c7c477f8cae6d450e1c8638f782d16 SUCCESS (build, Microsoft Authenticode/SHA verification, full offline ZIP, Windows Server refusal, short-lived artifact upload). Hosted Windows Server verification still does not count as Windows 10/11 client desktop installation acceptance.
- Exact-head Github artifact ID 13854536662 independently downloaded from run 43019213098: Windows offline ZIP 128,521,217 bytes, SHA-256 668F879EC3DFBA30766DFF3DF35ACB38091A68D5BDF1816D5A6B2C78666CFB42. On owner Windows 11 read-only, downloaded CI-built ZIP again PASS: real Install.cmd -CheckOnly, actual Microsoft runtime Authenticode/hash, native pinned Setup /verify and blocked writer, modified Setup/Manifest/runtime each rejected, unchanged user-installed Main/config SHA. Scoped ignored receipt .local/audit/r410-exacthead-hosted-offline-acceptance-20261111.json SHA DCC2CB063C2EE9F980B80D6439FB43761D7A2C0B3E5D9E3C8A0029C3DDC733DE. New dependent draft PR #106 targets the blocked security PR #98 branch; neither merged nor published. Source/product branch Git remains clean.
- Pending: reproduce missing framework and UAC/reboot/complete fresh-install and update/start on disposable Windows 10/11 desktop, resolve six critical CodeQL alerts and obtain independent human review on PR #98 before merge/public Release. Do not claim macOS/Linux packs until ported.
## R409 - Windows 10/11 x64 prerequisite-aware installer (local archive and negative tests PASS; hosted pending)

- New request: per-OS installer that automatically detects needed prerequisites, installs/upgrades only what is missing, and then starts the product. Existing native app is Windows-only .NET Framework 4.8, WinForms and Win32 taskbar/sensors. Linux/macOS require separate native UI and platform integrations: status BLOCKED_NATIVE_PORT_REQUIRED, not falsely packaged EXEs.
- Isolation: feature/r409-platform-bootstrap worktree, forked from R408 SHA 9e6f40e2b3690e94bbd2ce2fe41ffba88fedbf1e. Existing security PR #98, installed user app/config and immutable public release v1.7.10 remain unchanged.
- Windows pack: Install.cmd launches system 64-bit Windows PowerShell 5.1; the script refuses unsupported non-Windows/32-bit/Windows Server/older builds, checks its package manifest and exact bundled Setup SHA-256, detects .NET Framework Release >=528040 from 64-bit registry. It never re-installs or downgrades an adequate runtime. When missing, it obtains only official Microsoft offline .NET Framework 4.8 (CDN URL pinned), validates SHA-256 68C9986A8DCC0214D909AA1F31BEE9FB5461BB839EDCA996A75B08DDFFC1483F and Microsoft Authenticode before requesting native UAC. Exit codes 1641/3010 require reboot/retry; denial, invalid SHA or install failure fail closed. All other OS/global dependency upgrades are out of scope.
- Existing Setup /install /quiet manages fresh or guarded in-place update, without elevating the whole per-user Setup (R385). Native Setup may separately request UAC for optional protected sensors. Launcher verifies Setup exit and installed app existence and starts Main only if not already running.
- Local Windows x64 staged archive 7,291,895 bytes: build/_out/InstallerPacks/TaskbarMonitorEnhanced-Windows10-11-x64-v1.7.10.zip, SHA-256 6E8632431904FC3AEF907830890F7944936E61CF014DADA4F624ADD413F13DC5. Embedded built 1.7.10 Setup SHA FEDFD3F1F364130CC07B172D35290EF317D48DD8F281B51B1FBE9273A45B0537. ZIP builder validates all five entries and refuses accidental overwrite.
- Local proof: Windows PowerShell 5.1 parser of 3 scripts and workflow YAML PASS; real desktop read-only CheckOnly PASS with .NET Framework Release 534296, modified Setup and altered package manifest each rejected, live Main and owner config SHA unchanged. No actual prerequisite installation, OS changes, fresh install, owner update or owner process launch was performed.
- Disposable GitHub Windows Server workflow builds product and package, verifies ZIP, tests refusal of unsupported server OS, and uploads short-lived candidate artifact. It does not prove Windows 10/11 native install. Hosted CI PENDING at branch commit. Windows 10/11 fresh/install/reboot/missing-runtime compatibility still requires disposable desktop witnesses. All other PR #98 CodeQL security and independent review requirements remain mandatory.
- First hosted run 43010837086 compiled the four-component app successfully and built an exact ZIP. The workflow nevertheless failed because Windows PowerShell retained a stale $LASTEXITCODE after the successful pure-PowerShell pack builder. The workflow now reads the builder JSON receipt, validates file existence and SHA-256 instead. R409 bootstrap also rehashes Setup and manifest directly before executing Setup, after any long prerequisite installation. The local ignored ZIP was rebuilt in-place only after verifying its previous SHA, and read-only, mutated Setup and mutated manifest tests all PASS again. New hosted retest PENDING, first failure preserved in history.
- Hosted exact-head workflow run 43011430537 against SHA 5782f298b0bbf65415cf2fe354fdb0bd89f33686 PASS: four-part build, candidate ZIP, fail-closed Windows Server rejection, artifact retention. A further local launch-readiness improvement uses process-scoped PowerShell ExecutionPolicy Bypass from Install.cmd (without changing global policy) and forwards -CheckOnly to the child. Windows 11 actual Install.cmd -CheckOnly, modified Setup/manifest refusals and unchanged installed owner Main/config SHA all PASS. This third local candidate ZIP has the new SHA listed above; hosted recheck of the latest branch commit remains PENDING. Real installation and reboot/UAC acceptance are not claimed.
- Next: commit/push isolated installer branch, collect exact-head CI and artifact; exercise complete install/update and missing .NET/restart flows only on disposable Windows 10/11 desktops. Do not release publicly until required checks/reviews; port Linux/macOS separately.
## R408 - Broker independently validates mode/output authority (local PASS; hosted pending)

- Parent: exact PR #98 branch R407 commit 2068c2499efee649fcf65d3ef1421c6b21a2e834. No owner binary/config/release modification. Preserve stable public v1.7.10.
- Root cause: R406/R407 Supervisor restricts Broker launch paths/argv, but the Broker executable itself accepted a caller-provided output destination and passed it to AtomicWrite, including in the fatal-error path. Observed owner sensor Broker telemetry reports IsElevated=true, so an unexpected destination could have elevated write consequences; this is a security risk, not a demonstrated harmful owner-file overwrite.
- R408 repair: a separate compiled BrokerOutputBoundary independently permits only --run-cpu, --run-gpu, --once-storage paired with fixed JSON leaves in the current Windows profile LocalAppData TaskbarMonitorEnhanced root. It rejects old aliases, arbitrary/relative/UNC paths, escaped quotes/control characters, mismatched profile, wrong leaves, non-existing owner root and all existing reparse-point components. Main validates before hardware initialization; AtomicWrite remains restricted to the accepted output and acquires validated native directory handles before creating a unique CreateNew temp file and committing.
- Genuine negative finding: in a temporary fixture Windows allowed renaming the owner directory while native no-delete directory handles were held. Therefore directory handles alone cannot be claimed to make the write path atomic. R408 additionally reads GetFinalPathNameByHandleW for each live handle and checks its accepted canonical path immediately before replace/move. The compiled test detected the changed directory, refused write, restored fixture and verified normal post-release rename. A narrow concurrent rename between revalidation and filesystem commit remains outside the proof; do NOT mark all NTFS races closed.
- Local acceptance: full four-component build, deterministic build and integrated Main self-tests PASS (0 warnings, 0 errors). Compiled Windows PowerShell 5.1 R408 tests: 3 allowed mode/output bindings PASS; 14 invalid combinations REJECT; native held-directory move DETECTED and rejected; real built Broker exe called with an external canary path returned exit 2 before sensor startup with untouched canary SHA. Existing R407 compiled launch-lease regression PASS. Exact owner real LocalAppData paths for CPU/GPU/storage all validated read-only; no real owner writes/changes. CI YAML and PS5 syntax validation PASS.
- Added fail-closed R408 GitHub hosted validation: the synthetic temporary owner profile exercises native FileMode.CreateNew plus File.Replace and checks external canary preservation without ever modifying a runner existing LocalAppData or the owner installation. A fresh exact-head CI receipt is PENDING. The six critical CodeQL alerts and independent human review remain open.
- R408 first exact-head CI run 43003898271 found a test-only failure: the hosted runner had an existing LocalAppData TaskbarMonitorEnhanced root, and the new R408 test correctly refused to touch it. Instead of deleting existing runner data, extracted private AtomicWriteUnderLease core while the caller-facing AtomicWrite retains the BoundOutput mode/path check and validated native PinCurrent lease. The hosted R408 test now creates/replaces JSON only within its own synthetic temp owner profile. In the same first CI head, R367 hosted candidate A/B 43003889358 failed because its older native hardlink test used reflection to invoke the formerly unguarded AtomicWrite directly. Adapted only the candidate R367 fixture to acquire a valid native lease on its synthetic owner root and call private AtomicWriteUnderLease. Baseline R367 test branch logic is left unchanged. After these targeted corrections both R408 and R367 candidate synthetic hardlink native fixtures PASS locally on Windows PowerShell 5.1, including the external canaries. This does not claim the private write core can be invoked from untrusted command-line input or close all NTFS races.
- Second exact-head hosted Build/Verification 43005151387 PASS 4/4: compiled R408 synthetic owner-root native AtomicWrite create/replace and R404-R407, reproducible build, R298 recovery, R299 public 1.7.9-to-1.7.10 in-place upgrade, and R300 fresh install. This passed the first hosted R408 fixture failure without deleting preexisting runner LocalAppData.
- Remaining R367 exact-head hosted candidate A/B run 43005151388 FAIL at a new environmental path check: the temporary fixture root used raw TEMP, potentially involving Windows 8.3/full-path representation at BrokerOutputBoundary.Acquire; that explanation remains a hypothesis pending the hosted test diagnostic, a known analogous issue solved in R406. The R367 candidate fixture now constructs testRoot using System.IO.Path.GetFullPath and asserts direct equality of the input, absolute canonical output and fixed expected mode-specific output before invoking the compiled lease. Baseline vulnerability tests remain unchanged; local R367 candidate 4/4 PASS and R408 independent fixture PASS after correction. Hosted R367 repeatability is PENDING; do not count it as passed until exact-head CI reports it. No production code changes in this follow-up; this is only disposable test-fixture canonicalization.- Next: push R408, verify hosted actual Broker write/replace and downstream R298/R299/R300, R404-R407 regressions and CodeQL; fix any CI failure from real evidence. Do not merge until required security scanning and genuinely independent last-push review are satisfied.
## R407 — Broker executable + ancestor native launch pin (local verified; hosted and independent security review pending)

- Baseline: PR #98 branch `security/r347-r349-helper-hardening-v1710`, parent/source HEAD `27160f83b9770019e900ec2511d4e4fa5e860094` (R406), originally clean and identical locally/remotely; immutable public v1.7.10 and owner installed product untouched.
- Root cause: R406 checks trusted OS-known broker executable, owner LocalAppData output and exactly three modes at each restart, but check-to-`Process.Start` path race remained. R407 pins each existing protected/owner ancestor with Windows no-delete-sharing `CreateFileW` handles and pins the broker executable under a read-only `GENERIC_READ` handle, verifies reparse tags and native canonical handle paths, revalidates arguments under leases, then releases sharing immediately after process creation. Both CPU/GPU worker and storage launches use the same shared guard. Optional existing output leaf is also pinned during launch; absent output may be created by the child later. This is not a general elevation or complete NTFS-race security proof.
- Genuine local negative finding: first R407 fixture **FAIL** because `FILE_READ_ATTRIBUTES` on the broker file did not prevent same-user `WriteAllText` despite `FILE_SHARE_READ`. Corrected to `GENERIC_READ` for regular files (directory opens remain attribute-only), then retested **PASS**: 10 broker/output/file/ancestor overwrite/rename attempts refused while pinned; file swaps allowed after disposal; CPU and storage legitimate modes accepted, invalid mode refused, outside canary SHA unchanged. Owner fixture starts no process. This failure and correction must not be erased from the evidence lineage.
- Repeated original R404, R405, R406 compiled native fixture tests **PASS** with exit code 0; all four .NET Framework product components build **0 warnings / 0 errors**, deterministic build and built-in self-tests PASS; Windows PowerShell 5.1 parser, workflow YAML parser and `git diff --check` PASS. Windows hosted `-HostedGuest` mode additionally launches a harmless freshly compiled executable while pinned; **not run on owner device** and must not be marked PASS before hosted receipt.
- `.github/workflows/ci.yml` adds the R407 compiled native runtime gate; current PR #98 still has six critical CodeQL command-line alerts from exact R406 and no approved independent human security review. No alert was dismissed, no PR merged, no release or user installation modified. Reference: [Microsoft CreateFile sharing rules](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew).
- Next: commit/push R407, obtain exact-head hosted `CreateProcess` proof and relevant R404–R407 regressions; inspect any fresh CodeQL or runtime failure, then require legitimate independent last-push review before any merge.

## R397 — in-process SHA256 and bounded hosted preflight wait — local PASS, exact-head CI pending

- R396 exact-head PR [Build/Verification 42858789063](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42858789063) succeeded 4/4 including R299. Downloaded actual R299 acceptance receipt SHA256 `A0C2383A983BCE4DAFD5C556E592C3B18538DC21ED727D11D86CB08FB0F74A58` matches PR synthetic merge SHA `90528e40970d4225bf6686ee8dac596e448beaa7` and confirms genuine public v1.7.9-to-v1.7.10 Setup update, interrupted COMMITTING recovery, preservation of protected canaries, idempotent second update and four same-user restricted-Medium tokens. R360 three-cycle Windows 2022/2025, R291 Start/Settings and R385 security matrices also passed.
- Independent manual R396 [Build/Verification 42858662091](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42858662091) on the same branch HEAD failed only R299: GUI child verified exact hosted identity and checked out HEAD, then its last checkpoint was `BEFORE_BINARY_PINS`, after which it remained RUNNING at the 30-second arm timeout. The three `Get-FileHash` calls are the discriminating stall boundary; their PowerShell.Utility module loading and host scheduling are candidates, not confirmed root causes. PR success proves one real hosted upgrade, not cross-trigger repeatability.
- R397 bounded test-only repair: replace crash-child `Get-FileHash` preflight and post-stage calls with in-process read-only `SHA256.Create()` file streams and exact uppercase hash comparison. Require absolute paths, detect mutated bytes and record each of three binary pins separately. Increase only the disposable Windows crash-child COMMITTING wait from 200x150ms to 600x150ms (90s) while retaining fail-closed timeout and GitHub job 15-minute budget. No product/Setup/R385 changes or permission loosening.
- Local tests PASS: Windows PowerShell 5.1 parse both scripts; in-process hash equals Get-FileHash for binary bytes, fails on tamper, rejects non-absolute paths; no crash-child hash Cmdlet remains; YAML parse and `git diff --check` PASS. Owner installation/public v1.7.10 release untouched.
- Next: exact-head R397 PR and independent manual Build/Verification to establish reliable R299 crash staging/recovery/idempotence. Keep security PR #98 unmerged until required checks and independent human security review, already requested from the collaborator, are complete. Do not push evidence-only commits after full green CI merely to force another exact-head rerun.
## R396 — bounded R299 crash-child checkpoints to locate hosted preflight stall — local PASS, hosted pending

- R395 exact-head [Build and Verification 42855656529](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42855656529) completed 3/4: build, R298, R300 PASS; only R299 FAIL. All other exact-head checks PASS (29/30). R299 successfully verified the genuine public v1.7.9 Setup SHA and predecessor pins and refused tampered `Source/StudioThemes.cs`. The restricted Medium GUI child wrote both `GUI_BOOTSTRAP_STARTED` and `HOSTED_IDENTITY_VERIFIED` with correct PID, run ID and SHA; after ~30 seconds it remained RUNNING with no preflight/startup, COMMITTING or error receipt. No real Setup recovery or idempotence was exercised.
- R395's removal of child-native `git.exe` and `csc.exe` dependencies did not prove that the GUI child would finish preflight. The blocked operation is not known. Do not weaken security or assume a cause without an exact checkpoint.
- R396 test-only modification: a single overwritten `$Signal+'.checkpoint.json'` is created **only after exact hosted-runner identity and runner-scoped signal path verification**. It records no private data: just PID, Git SHA, run ID, bounded phase and UTC. Checkpoints bracket checkout resolution, exact Git HEAD, canonical root, binary hashes, process and state checks, then Setup staging/COMMITTING. On the existing 30s failure bound, the parent includes the last checkpoint in its failure message; stale per-run checkpoint is refused. Production Setup/R385 and real crash-staging assertions are untouched.
- Local checks PASS: Windows PowerShell 5.1 parsing of both modified scripts, C# launcher compile, workflow YAML parse, isolated in-memory AST-extracted checkpoint function writing/overwriting a temporary JSON receipt, owner/nonhosted negative refusal with no receipt files, and `git diff --check`. No local Setup update or owner install mutation.
- Remaining: inspect R396 exact-head hosted R299 last checkpoint and address only the proven stall. PR #98 remains open/unmerged with independent human review absent. Public v1.7.10 release and installed product unchanged.

## R395 — eliminate native console subprocesses from hosted restricted-Medium GUI crash script — local PASS, exact-head CI pending

- R394 exact-head [Build and Verification 42846214839](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42846214839) finished build/R298/R300 PASS, R299 FAIL; 29/30 exact-head checks passed. R360 push [42845937625](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42845937625) completed successfully on Windows Server 2022 and 2025. PR #98 remained open, unmerged, mergeable and without independent human security reviews.
- R394's GUI bootstrap proved the restricted-Medium child started and executed the original PowerShell script: `GUI_BOOTSTRAP_STARTED` and `HOSTED_IDENTITY_VERIFIED` receipts were present for the same child PID, commit SHA and run. The child then exited 81 with `You cannot call a method on a null-valued expression` inside original preflight, before `PREFLIGHT_PASSED` and `COMMITTING`. The only vulnerable native-output `.Trim()` in that preflight was `(git -C $repo rev-parse HEAD).Trim()`; a console-subsystem `git.exe` can fail to launch in this restricted-host context and produce null stdout. This causal interpretation is testable, not yet full hosted proof.
- Bounded R395 modification to **test-only** `build/Test-R299-HostedCrashChild.ps1`: resolve Git HEAD from read-only `.git/HEAD` directly in the embedded PowerShell runspace, supporting detached HEAD and loose/packed branch refs; reject traversal, malformed/ambiguous refs and any mismatch to exact `GITHUB_SHA`. Parent R299 continues to independently check `git rev-parse HEAD` before launching. No detached or workspace boundary is weakened.
- Eliminate another potential console child: the crash script previously called `Add-Type` (which can launch `csc.exe`) solely to define `R299FileBridge.ReplaceNoBackup`. Use the already present .NET `System.IO.File.Replace(string,string,string)` reflection overload with **true null backup**. No process/compiler spawn, same two original file replacements and original Setup journal/security assertions. PowerShell's direct binder can coerce null backup to invalid empty path, so explicit reflection arguments are necessary.
- Local tests PASS: Windows PowerShell 5.1 AST parse of child/parent; live Git HEAD readback against real repo; detached, loose and packed ref lookup; malformed-ref/traversal and invalid SHA refusal; file replacement of harmless temporary bytes with no backup under the true-null reflection call; scan verifying no child `git.exe` or `Add-Type/csc.exe` calls; owner/nonhosted negative test exits 1 before creating any signal/error/entry file; workflow YAML parse and `git diff --check`. No real Setup or owner installation updated.
- **Not yet accepted:** R395 GitHub-hosted crash child startup/COMMITTING/kill, real official v1.7.9-to-v1.7.10 Setup replay/update, canaries and second-update idempotence. No code changed in production Setup/R385 or immutable public v1.7.10, and PR #98 requires independent human security review before merge.
- Next: commit/push R395 exact head, inspect the first hosted R299 receipt after GUI entry and close only verified acceptance gates.

## R394 — eliminate console-subsystem loader failure using a GUI-hosted PowerShell crash fixture — local integration PASS; hosted pending

- R393 exact-head [Build/Verification 42842652486](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42842652486) finished build/R298/R300 PASS, R299 FAIL; 29/30 other exact-head checks PASS. R360 push [42842321660](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42842321660) succeeded Windows Server 2022/2025. PR #98 at `65c4dd5e5e502e4a3aa70f9f9ad55cce1565bc58` remained open/unmerged/mergeable but blocked on CI and independent human security review.
- Root boundary: exact immutable public v1.7.9 Setup SHA, 22 predecessor pins, five negative identities and exact StudioThemes.cs tamper refusal passed. SetupUpdate and CrashChild processes were created with same-user restricted Medium token (IL 0x2000, Administrators disabled) via `CreateProcessAsUserW`. Even `CREATE_NEW_CONSOLE` did not initialize `powershell.exe`: exit code -1073741502 = 0xC0000142 STATUS_DLL_INIT_FAILED before entry/startup/error/COMMITTING receipts. The three console launch modes (CREATE_NO_WINDOW, default, new console) have not proven a viable hosted PowerShell child. No genuine crash recovery/idempotence occurred. Microsoft [CreateProcessAsUserW](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessasuserw) notes successful process creation can precede DLL initialization failure.
- R394 technical decision: preserve the original `build/Test-R299-HostedCrashChild.ps1` and all original acceptance gates, but host it through a new compiled GUI-subsystem `build/R299-HostedCrashGuiBootstrap.cs` with `System.Management.Automation.PowerShell` in-process. Compile the WindowsApplication binary only after the exact disposable-runner guard, to RUNNER_TEMP; verify PE subsystem 2, retain its source via exact repo SHA and emit the compiled binary SHA. Bootstrap checks exact GitHub-hosted Windows repo, run/SHA formats and runner-scoped signal path before writing, then emits a PID/run/SHA `.gui.entered.txt` receipt and invokes the same PS script. All Setup/CrashChild processes use the already verified same-user Medium token and no console; Setup still uses unchanged CREATE_NO_WINDOW. The parent requires GUI bootstrap entry, original script entry/preflight, COMMITTING proof, forced kill and real Setup replay, and records bounded bootstrap errors. CI requires `R299_HOSTED_CRASH_CHILD_GUI_HOST=PASS` and `R299_HOSTED_CRASH_GUI_BOOTSTRAP=PASS` in addition to the original recovery/canary/idempotence markers.
- Local validation PASS: Windows PowerShell 5.1 parse of both scripts; compiled existing Medium launcher C#; compiled Windows-subsystem GUI exe with PE Subsystem=2; benign embedded PowerShell in-process test successfully invoked a synthetic script and wrote the expected marker; real GUI bootstrap launched as a verified Medium-integrity child without Administrators and failed closed on the owner/nonhosted machine (exit 81, no files); workflow YAML parse; six essential CI markers match; git diff --check. No production Setup or owner data changed.
- Scope/risk: this is a test-only workaround for an observed console host initialization fault, not a demonstrated fix for product Setup. The new GUI bootstrap adds no installation, registry or sensor mutation of its own; the original child script remains guarded and unchanged. The entire real hosted v1.7.9-to-v1.7.10 interrupted COMMITTING upgrade/recovery, canary preservation and idempotent second update remain pending CI. PR #98 independent human review remains missing.
- Next: commit/push R394 exact head, inspect GUI bootstrap receipt then original script receipt, stage/kill/recovery and idempotence. Do not merge PR #98 until exact-head CI plus independent security review pass.

## R393 — isolate hosted restricted-Medium PowerShell crash console, require early entry receipt — locally validated; hosted pending

- Authoritative baseline: commit `e25e8eaeff825a3e23be0990fd88605f3365f1b9`, PR #98 open/mergeable/unmerged and requested human security review not submitted. R392 exact-head Build/Verification [42836539517](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42836539517) succeeded build, R298 and R300 but failed R299; 29/30 checks passed overall; R360 push [42836527156](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42836527156) succeeded on Windows Server 2022 and 2025.
- Failure boundary: the exact public v1.7.9 predecessor pins and negative tamper checks pass. The genuine SetupUpdate and PowerShell CrashChild both launch using same-user restricted Medium tokens (IL 0x2000, Administrators disabled, CreateProcessAsUser); the CrashChild remained RUNNING at the 19.5-second poll boundary, without .started.txt, .error.txt or COMMITTING arm. No recovery or idempotence evidence exists from this failed attempt. Distinct console allocation, not inferred Setup corruption, is the next testable hypothesis.
- R393 test-only mutation: `R299-MediumTokenLauncher.cs` uses `CREATE_NEW_CONSOLE` (0x10) exclusively for `consoleAllowed=true`, itself strictly allowed only for the trusted system WindowsPowerShell.exe crash child. Every genuine GUI Setup child retains `CREATE_NO_WINDOW`. The CrashChild adds a `.entered.txt` receipt only after matching GitHub-hosted Windows runner identity and exact per-run runner-temp signal path; the parent checks entry PID/run/SHA/phase before the existing preflight and COMMITTING receipts. CI adds `R299_HOSTED_CRASH_CHILD_ENTRY=PASS`. Source [Microsoft Process Creation Flags](https://learn.microsoft.com/en-us/windows/desktop/ProcThread/process-creation-flags) distinguishes CREATE_NEW_CONSOLE from CREATE_NO_WINDOW; [CreateProcessAsUserW](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessasuserw) documents that successful creation does not prove child initialization.
- Local validation PASS: PowerShell 5.1 parse of both scripts, .NET Framework C# compile, CREATE_NEW_CONSOLE numeric flag 0x10, bounded creation-mode source scope, harmless default-no-window child smoke, rejection of untrusted executable requesting console mode, YAML parse, CI marker coverage, git diff --check and owner/non-hosted fail-closed negative test producing no owner-side files. No owner-side new-console launch or real Setup upgrade was performed.
- Security/scope: preserve existing R385 elevation guard and same-user Medium token validation, immutable published v1.7.10 release, owner installation/configuration, canonical runner path and all original R299 recovery/canary/idempotence assertions. Only four test/CI files changed, no changes to product Setup. R393 result remains unproven until exact-head hosted CI.
- Next: commit/push this bounded draft, inspect the hosted R299 entry and preflight receipts then COMMITTING stage, actual forced termination and real Setup recovery/idempotence; do not merge PR #98 without complete CI and independent human security review.

## R392 — R299 PowerShell wrapper success-stream pollution — one typed process object proven locally; hosted pending

- R391 exact-head Build/Verification [42835087137](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42835087137) completed 3/4 (build/R298/R300 PASS; only R299 FAIL). Hosted R299 verified SetupUpdate and CrashChild are launched via CreateProcessAsUser with same-user restricted Medium token (0x2000, Administrators disabled); crash child used `consoleAllowed=True` after the scoped CREATE_NO_WINDOW removal. The previous 0xC0000142 was not logged in this attempt, but crash-child script startup/COMMITTING were not proven.
- Precise R391 failure: `Start-R299HostedProcess` returned the literal `R299_HOSTED_CRASH_CHILD_CONSOLE_ALLOWED=PASS` on its PowerShell success stream in addition to `R299HostedProcess`. Assignment to `$crashChild` created a string+process array, so `$crashChild.Dispose()` failed with `[System.String] does not contain a method named Dispose`. This is a test harness return-type defect introduced in R391, not evidence of a product Setup failure.
- R392 objective: remove only the CI marker from the process-returning function; after the top-level `$crashChild=Start-R299HostedProcess` assignment, require `$crashChild -is [R299HostedProcess]` with `ConsoleAllowed` true, then emit the required `R299_HOSTED_CRASH_CHILD_CONSOLE_ALLOWED=PASS` marker on the script's top-level success stream. No other code changes or acceptance weakening.
- Local validation PASS: Windows PowerShell 5.1 AST parse; source-extracted `Start-R299HostedProcess` function executed with a harmless mocked `R299HostedTokenLauncher.Start` returning a simulated process (no real OS child). Both SetupUpdate and CrashChild returned exactly one typed `R299HostedProcess`; purpose-to-console boolean and invocation counters matched; git diff --check PASS. This proof validates output-stream behavior only, not hosted process execution.
- Hosted R391 R360 push [42835076925](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42835076925) was still running when recorded; the latest R391 PR checks had 27 PASS, 1 FAIL (R299), 2 running. R390 had 29/30 PASS and the prior NTSTATUS failure; its diagnostics remain preserved. Product Setup, R385 security guard, owner installed app/config and public v1.7.10 release unchanged. PR #98 open/unmerged with zero independent human security reviews.
- Next: commit/push R392 exact head, inspect real R299 crash fixture startup/COMMITTING, forced terminate, official Setup recovery/update, canary preservation and exact second-update idempotence. Do not equate the local mocked return test with end-to-end PASS.

## R391 — fix restricted-Medium console child startup without relaxing Setup security — local checks PASS, hosted pending

- R390 exact-head Build/Verification [42833174560](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42833174560) finished 3/4 (build, R298, R300 PASS; only R299 FAIL). Exact-head PR/push total: 29/30 SUCCESS including R360 [42833157723](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42833157723) on Windows Server 2022/2025. The official public v1.7.9 Setup SHA, exact predecessor pins and modified StudioThemes.cs fail-closed negative passed. R299 created verified same-user restricted Medium children for Setup and CrashChild via CreateProcessAsUser; both tokens had integrity 0x2000 with Administrators disabled.
- Critical diagnostic: CrashChild terminated before script startup with signed exit code -1073741502 = NTSTATUS 0xC0000142 STATUS_DLL_INIT_FAILED. Neither child preflight/startup nor `.error.txt` was reached, so the failure occurs in Windows process initialization, not the crash test's reflection/staging or product Setup recovery. [Microsoft NTSTATUS](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/596a1078-e883-4972-9bbc-49e60bebca55) and [Process Creation Flags](https://learn.microsoft.com/en-us/windows/desktop/ProcThread/process-creation-flags) document the status and console-mode semantics. The interaction of CREATE_NO_WINDOW with the restricted token and console-subsystem PowerShell is a testable hypothesis, not established root cause until hosted acceptance.
- R391 bounded test-only correction: add `Start(..., bool consoleAllowed)` overload with default false; only the exact trusted `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe` can pass true. With true, use `CREATE_UNICODE_ENVIRONMENT` without `CREATE_NO_WINDOW`, allowing console attachment/creation; real GUI Setup still gets unchanged CREATE_NO_WINDOW. The parent binds true exclusively to Purpose=CrashChild, checks the returned process mode, records it and CI requires `R299_HOSTED_CRASH_CHILD_CONSOLE_ALLOWED=PASS`. Same token selection, SID, Medium IL, denied Administrators, test/CI safety and all original R299 recovery/canary/idempotence assertions are preserved.
- Local validation: PowerShell 5.1 parse both scripts PASS, .NET Framework C# compile PASS, harmless current-Medium default-no-window child PASS, console-mode request for untrusted `whoami.exe` rejected PASS, YAML parse PASS, CI console marker PASS, `git diff --check` PASS. No visible owner-side console test or production Setup update was attempted. Three test-only files changed: `build/R299-MediumTokenLauncher.cs`, `build/Test-R299-HostedPublicV179Upgrade.ps1`, `.github/workflows/ci.yml`.
- Scope: product Setup/R385 guard, owner installation, data, configuration, task/service and immutable public v1.7.10 unchanged. PR #98 remains open/unmerged, independent human security review required; historical R371 Windows 2022 UI negative remains unresolved.
- Next: push R391 exact head, require the crash child to arm `COMMITTING` and prove forced recovery through the real Setup binary, preserve canaries and exact idempotent second update. If it still fails, only change the next evidenced failure boundary.

## R390 — R299 crash child exits before COMMITTING arm — preflight/startup/exit diagnostics locally validated; hosted pending

- R389 exact-head Build/Verification [42827227428](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42827227428) completed 3/4 (R298, R300 and build SUCCESS; R299 FAILURE). Other exact-head PR/push checks: 29/30 SUCCESS, R360 push [42827203984](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42827203984) SUCCESS on both Windows Server 2022 and 2025. PR #98 remains open/mergeable/unmerged and no independent review has been submitted.
- Failure boundary now narrowed: R299 downloaded and SHA-verified immutable v1.7.9 Setup; negative tampered-predecessor test produced the correct diagnostic `R129_FAIL_CLOSED_DIAGNOSTIC`, exact `Source/StudioThemes.cs` tamper refusal and phase. Both genuine SetupUpdate and CrashChild started via `CREATE_PROCESS_AS_USER` using verified same-user restricted Medium tokens (IL 0x2000, Administrators disabled) under a UAC-enabled elevated parent. CrashChild exited before writing `R299_ABRUPT_COMMITTING_ARMED`, and no `.error.txt` existed; the actual exit code and preflight fault were unrecorded. No evidence yet that COMMITTING recovery, preservation or idempotence executed in R389.
- Objective: improve ONLY R299 disposable-runner diagnostics, not product behavior or guard. The crash child now reports validated hosted-runner preflight exceptions to a bounded `.error.txt` and writes a per-run, PID, SHA and runner-context startup receipt after verifying the disposable runner, canonical app root and exact predecessor binary pins. The parent includes HasExited/ExitCode/startup/error in its failure and requires matching startup receipt before accepting the COMMITTING fixture. Exact CI requires `R299_HOSTED_CRASH_CHILD_STARTUP=PASS` and final receipt records `CrashChildStartupVerified`.
- Modified test-only files: `build/Test-R299-HostedCrashChild.ps1`, `build/Test-R299-HostedPublicV179Upgrade.ps1`, `.github/workflows/ci.yml`. Local validations PASS: Windows PowerShell 5.1 parse of both scripts, .NET Framework C# compile, YAML parse, 8/8 required CI markers, `git diff --check`; prior native named arguments + environment propagation smoke also PASS. The full hosted R299 acceptance remains pending; no claim of root-cause fix yet.
- Security and scope: preflight still refuses non-GitHub-hosted, identity-mismatched and owner-looking machines; no changes to Setup, R385, owner install, registry/service/sensor settings or immutable public v1.7.10 release. Independent human security review remains required for PR #98.
- Next: commit/push R390 in the existing security branch; inspect hosted exact-head crash-child receipt and fix only the demonstrated root cause, then prove v1.7.9-to-v1.7.10 real Setup upgrade, interrupted COMMITTING recovery, canary preservation and exact second-update idempotence before accepting R299.

## R389 — R299 hosted token policy follows R385 UAC boundary — local validation PASS; exact-head CI running

- Root cause: R388 exact-head Build/Verification [42822663126](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42822663126) failed in R299 while creating the explicit restricted Medium child through `CreateProcessWithTokenW`. The failure occurred before any Setup child was created; the R388 helper did not capture the Win32 error code. This was a test-harness process-creation failure, not evidence of a product Setup or R385 guard failure.
- R388 hosted outcomes: R360 push [42822651632](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42822651632) SUCCESS 3/3 jobs; R385 PR matrix [42822663157](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42822663157) SUCCESS 4/4; Build/Verification 3/4 with only R299 failed before Setup launch. R388's CreateProcessWithTokenW-only restricted-token attempt is superseded.
- Decision: use the actual R385 security boundary. When UAC is enabled, R299 requires a verified same-user Medium token (current Medium, linked UAC-limited, or restricted Medium). When UAC is disabled, Windows has no separate filtered Medium token; permit the current same-user administrator token only if 64-bit HKLM EnableLUA is exactly zero, token type is Primary, TokenElevationType is Default, integrity is exactly High (0x3000), and Administrators membership is enabled. Missing/unreadable UAC state fails closed. This changes test infrastructure only and does not weaken the production guard.
- Implementation: commit `83bc2c16d0b13631b929646ee6c0555c592de9c2` on `security/r347-r349-helper-hardening-v1710`, pushed and verified at the remote ref. Parent follow-up commit `50cf86a7d932452f4cb4509e333824f3830f2d80` (CreateProcessAsUserW-first restricted-token attempt) is included in the pushed branch history. R299 now records actual child TokenElevationType, integrity RID, Administrators membership, UAC state, token source and process-creation method; all four children must share one verified context. CI now requires `R299_HOSTED_TOKEN_PROCESS_CREATION=PASS`.
- Local validation: Windows PowerShell 5.1 parse PASS; .NET Framework C# compile PASS; workflow YAML parse PASS; `git diff --check` PASS; harmless current-Medium `whoami.exe /groups` child PASS (TokenElevationType=3, IL=0x2000, Administrators disabled, UAC enabled); explicit allowlisted environment propagation PASS; parent-token diagnostic and receipt-context assertions PASS; all seven CI markers match and stale Medium-only marker scan PASS. The local machine exercised only the current-Medium branch, not the hosted High/UAC-disabled branch or the real Setup update.
- Hosted R389: pushed exact head `83bc2c16d0b13631b929646ee6c0555c592de9c2`; PR #98 now points to it and remains open/mergeable/unmerged. Exact-head Build/Verification checks are running; R360 push [42827203984](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42827203984) is in progress. Other PR checks are queued or running.
- Scope: no production Setup or R385 source changes; owner installation, configuration and public v1.7.10 release unchanged. PR #98 still has zero submitted independent human reviews. Historical R371 Windows 2022 UI failure remains NON-PASS/UNPROVEN; Notion restoration remains pending explicit owner consent.
- Exact next action: inspect R389 Build/Verification and R360 results; verify the parent UAC policy, four child token receipts, exact tamper diagnostic, real 1.7.9-to-1.7.10 update, interrupted COMMITTING recovery, canary preservation and idempotence. Keep PR #98 unmerged pending all CI and independent human review.

## R388 — restricted-medium-token attempt — superseded after hosted R299 process-creation failure

- Root cause: R387 exact-head Build/Verification [42820827177](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827177) showed the hosted parent token was TokenElevationType Default, primary, High integrity 0x3000, neither an already-Medium token nor a Full UAC token with a linked limited token.
- Implementation commit `bc328976c6e7ed7bb449a52f4baed90fd7a5979d` created a restricted same-user Medium token with Administrators disabled and maximum privileges removed. Local token creation/inspection smoke passed. Follow-up local commit `50cf86a7d932452f4cb4509e333824f3830f2d80` tried CreateProcessAsUserW first with CreateProcessWithTokenW fallback; it was not independently hosted-tested before R389 superseded the approach.
- Hosted R388: Build/Verification [42822663126](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42822663126) failed in R299 before Setup launch; R360 push and R385 PR matrices passed as recorded above. No real Setup update/recovery/idempotence evidence was produced by this failed R299 attempt.
- Status: SUPERSEDED_BY_R389. Product Setup/R385 guard, owner installation and public release were not changed.

## R387 — R299 medium-token launcher supports already-medium runners and captures Setup exceptions — local smoke PASS; hosted exact-head pending

- Correction objective: make the R299 disposable-runner integration test always invoke per-user Setup at medium integrity regardless of whether the GitHub runner shell itself is already medium or is Full/elevated; also expose the exact Setup exception instead of treating generic exit 34 as a diagnosis. Product security behavior is not relaxed.
- Implementation commit: 0100e61e980419b1f325f29e751b8989ea55453c on security/r347-r349-helper-hardening-v1710; pushed and remote ref verified. R299MediumTokenLauncher uses CreateProcessW to inherit an already-medium parent token (TokenElevationType Limited or Default with Medium IL), or obtains/validates the linked UAC-limited token and uses CreateProcessWithTokenW if the parent is Full/High. It validates same user SID, expected elevation type, primary child token and Medium integrity on every created process. Environment is an explicit non-secret allowlist including the per-invocation diagnostic phase.
- R299 diagnostics: creates a fresh RUNNER_TEMP/TBME_R126_STABLE_UPDATE directory; sets NEGATIVE_USER_EDIT, POSITIVE_OFFICIAL_STABLE and IDEMPOTENT per Setup invocation; checks the negative tamper diagnostic names the exact modified Source/StudioThemes.cs predecessor and is not the R385 elevation refusal; unexpected Setup failures include their diagnostic text and upload raw R129_DIAG_*.txt artifacts on failure. CI now requires R299_MEDIUM_INTEGRITY_TOKEN_PROCESS_CREATION=PASS and the receipt records all three Setup children, one crash child and token source for each.
- Local validation: Windows PowerShell 5.1 parse PASS; C# .NET Framework compile PASS; workflow YAML parse PASS; git diff --check PASS. Local native smoke launched harmless whoami.exe /groups under a verified same-user Medium child token and returned exit 0; a second smoke proved GITHUB_SHA and TBME_UPDATE_DIAGNOSTIC_PHASE environment propagation. Token source on this host: CURRENT_MEDIUM_TOKEN. No Setup/update invocation was run on the owner device.
- Scope: test infrastructure only (.github/workflows/ci.yml, build/Test-R299-HostedPublicV179Upgrade.ps1, build/R299-MediumTokenLauncher.cs). Production Setup and R385 security guard, owner installation/configuration, sensor task/service/registry and public v1.7.10 release remain unchanged.
- Hosted exact-head CI: Build/Verification [42820827177](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827177) failed before Setup launch; parent token was Default/High integrity 0x3000. R388 supersedes this helper. R291 PR [42820827126](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827126), R385 PR [42820827224](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827224), R338 [42820827209](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827209), R367 [42820827104](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827104), R369 [42820827063](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827063), R370 [42820827139](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827139) and R290 [42820827042](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827042) completed SUCCESS. R360 push [42820814782](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820814782) was still in progress at the last check.
- Prior regressions: R291 diagnostic retry 42814404550 SUCCESS 3/3; R360 three-cycle Settings stress 42817747115 SUCCESS on Windows Server 2022 and 2025. The R291 attempt-1 hidden-HWND negative and artifact remain preserved; retry/stress success does not prove the historical R371 root cause is resolved.
- PR #98 remains open and unmerged; independent human review is still required. Historical R371 Windows 2022 UI negatives remain NON-PASS/UNPROVEN. Notion restoration remains pending explicit owner confirmation.
- Exact next action: R387 is superseded for the Default/High runner case. R388 creates and verifies a restricted same-user Medium token; validate the new exact-head hosted R299 execution and use the phase diagnostic if Setup still returns exit 34.

## R386 — R299 hosted per-user Setup test uses verified linked medium token — local static PASS; hosted exact-head pending

- Main objective: repair only the R299 hosted test launcher so the real per-user Setup update is invoked at the normal user's medium integrity even though GitHub-hosted workflow PowerShell runs elevated. Do not weaken R385 and do not change product/Setup code.
- R386 hosted outcome/correction: the exact-head Build/Verification run 42817756016 failed before creating any Setup process because this first helper version required a Full parent token, while the actual hosted Build/Verification PowerShell process was already medium-integrity. No Setup invocation occurred in that run. Separately, the earlier R299 exit 34 is the generic Setup exception exit and no phase diagnostic was captured; the prior claim that R385's elevation guard caused it was unsupported and is withdrawn.
- Implementation commit: 4f3625a81004b35603d7b0ae150dba0ea1ff0dea on security/r347-r349-helper-hardening-v1710, pushed and read back from origin. New test-only build/R299-MediumTokenLauncher.cs obtains the current elevated token's linked UAC-limited token, verifies same user SID, Limited elevation type, not elevated and Medium integrity, duplicates a primary token and launches via CreateProcessWithTokenW. It also verifies the actual created child token before returning a process handle. Environment is an explicit allowlist (no GitHub token/secret variables). All three actual Setup /update /quiet invocations (tampered negative, crash recovery update, idempotent second update) and the synthetic crash child now use this launcher. CI requires R299_MEDIUM_INTEGRITY_TOKEN_LINKED_PROCESS_CREATION=PASS and records 3 Setup + 1 crash child in the receipt.
- Local validation: Windows PowerShell 5.1 parser PASS; C# helper compiled with Windows PowerShell 5.1/.NET Framework PASS; .github/workflows/ci.yml YAML parse PASS; git diff --check PASS. No local Setup/update invocation was run; the R299 script hard-gates to a fresh GitHub-hosted disposable Windows runner.
- Scope: test infrastructure only. Production Setup, installed owner app, configuration, sensor task/service/registry, public v1.7.10 artifact/tag and release were not changed. R385's elevated per-user refusal remains intact.
- Hosted exact-head CI: Build/Verification 42817756016 failed before Setup invocation with R299_PARENT_MUST_HAVE_FULL_UAC_ELEVATION_TOKEN; this helper failure is superseded by R387. On R386, R291 PR 42817756118, R385 PR 42817755998, R338 42817756020, R367 42817756017, R369 42817756211, R370 42817756155 and R290 42817756028 all completed SUCCESS. R360 three-cycle stress 42817747115 completed SUCCESS on Windows Server 2022 and 2025.
- R291 diagnostic retry: run 42814404550 attempt 2 SUCCESS 3/3, including Windows Server 2025. All four Settings foreground transitions on that host were ready within 0–2ms; Windows 2022 also passed. Attempt-1's original 5111ms hidden-HWND negative and artifact remain preserved; the retry is not a root-cause fix or proof of zero intermittency. Windows 2025 attempt-2 artifact SHA256 66452172d85b8567b845e49509dce1b27752688f61d72d9345d36397354db58e; Windows 2022 artifact SHA256 ce09a2b5575c1886b0a5615c693919c371662c920ef270dc7843f85e0bf5b056.
- PR #98 remains open/unmerged; zero human reviews have been submitted. Historical R371 Windows 2022 UI negatives remain NON-PASS/UNPROVEN. Notion restoration remains pending explicit owner confirmation.
- Exact next action: R386 is superseded. R387 now handles an already-medium parent token and adds Setup exception diagnostics; validate the new exact-head hosted R299 execution before accepting this test infrastructure.

## R385 elevated per-user upgrade boundary — local and dedicated hosted matrices PASS; broader PR integration follow-up

- Engineering commit: `4536bc7666be3773d1f9934c7d5a0592b064c266` on `security/r347-r349-helper-hardening-v1710`; pushed to origin and read back via `git ls-remote`. PR #98 head is the same commit; PR remains open, mergeable, unmerged.
- Finding/decision: the per-user upgrade stage and recovery journal live under the user-writable AppRoot. With UAC enabled, an elevated Setup process creates a different integrity boundary and can run cleanup/recovery against that user-writable stage. R385 refuses `UpgradeExisting()` before AppRoot existence/reparse checks and before `RecoverUpgradeStageIfAny()` whenever UAC is enabled and the Setup process is Administrator-elevated. The optional protected sensor helper remains the separate elevation boundary. UAC-disabled compatibility is retained.
- Implementation: read 64-bit HKLM `EnableLUA`; absent/unreadable policy fails conservatively to UAC-enabled. Reuse the existing `WindowsPrincipal.IsInRole(Administrator)` helper; no new P/Invoke/token privilege machinery. Existing install and update call sites funnel through `UpgradeExisting()`.
- Local R385 native harness: exact production elevation/UAC helper methods compiled and checked against the current Windows token and HKLM state; six Candidate checks PASS (actual helper/token match, actual UAC registry match, combined boundary match, UAC-elevated refusal before stage recovery, medium-integrity update allowed, UAC-disabled admin compatibility). Receipt is owner-temp only: `%TEMP%\R385_candidate_LOCAL_41d2246c7f674b3fa5bdaa5cdc6b4b2b\R385_UPGRADE_BOUNDARY.json`, SHA256 `4123D51090F6BF55302A4B2D16104131589E1A2F7F7B5532D144DAAE92C94A14`. Baseline control on exact prior source `f59e1dcf410b97cf16350bc385b4fcbedbf3b093` PASS 2/2; receipt SHA256 `93EC3FDCF29C3554220152A2914CF5FDB634E969B30BB116B584E8212200C908`.
- Full local `build/Build.ps1 -NoDownload`: App/Broker/Supervisor/Setup all 0 warnings/0 errors; `selftest`, `feature-contract-selftest`, `workspace-selftest` 3/3; Setup `/verify` 25/25; `TBME_REPRO_BUILD=PASS`. Candidate Setup SHA256 `8FA5B5530D38601CE41354DCC22ED43E4AE5459C1293E3AF4EB7832A2391056B`; Main SHA256 `BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6`. Prior ignored build outputs and accepted artifact files were backed up during build and restored; candidate outputs retained separately under owner Temp.
- R385 workflow YAML parsed successfully; R385 harness parsed with Windows PowerShell 5.1; `git diff --check` PASS. Three changed files committed and pushed; working tree clean. Local source/test evidence is PASS only for these exact checks.
- Hosted R385 exact-head push run [42814394318](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42814394318) completed SUCCESS (4/4 jobs) on exact head `4536bc7666be3773d1f9934c7d5a0592b064c266`. All four typed baseline/candidate receipts for Windows Server 2022 and 2025 were downloaded and validated. Windows 2022 B: baseline 2/2, receipt SHA256 `5491A954C3B9C184404477C8077E8367D9C9F7FE4F3FBBE3A01F40F60704A158`; candidate 6/6, receipt SHA256 `D9E4BFF3661695B50DA0618D71C894069B1B01B92D0EAA6684F1CE0326050584`. Windows 2025 A: baseline 2/2, receipt SHA256 `263A43167312169D0C00BD2119B2C77168D08EC2A8EBA6E01D38CD2E4D71595F`; candidate 6/6, receipt SHA256 `B610CD008B40265511D66AFB5A48490A001BE6523F5A5FDA255EF5973092ADEC`. All four hosts record UAC enabled and actual elevated process token; baseline reaches stage recovery, candidate refuses before recovery while allowing medium-integrity and UAC-disabled admin paths. All receipts report `ChangedOwnerInstall=false`, `InvokedActualSetup=false`. Artifact ZIP digests: baseline B `A33A2938F31BC5FE16CA0CD878C468B302F182E4E44DC27BEBFB39928D392265`, candidate B `B73151F321CF1A6CD9A6039E2C17112B3D120E774EB3C6CBA28E0EFF94888B2F`, baseline A `FA5D91B7979D35FA5BFB0F0B4BCE0E7E650D44025BEE21DC9EB2D3687EDBFCBC`, candidate A `7549DD8D30CED83D903344290710909EE26CA5AF621C3D6A16228BFA417D88B2`. The exact-head PR R385 run [42814404634](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42814404634) completed SUCCESS (4/4); all four typed receipts were independently downloaded and validated. Hosted R385 is PASS on both push and PR matrices (8/8 jobs total, 16/16 candidate checks and 8/8 baseline checks across Windows Server 2022/2025 and both event types). The broader PR exact-head Build/Verification [42814404560](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42814404560) was 3/4 because the R299 real Setup update returned generic exit 34; that run did not set the hosted failure-diagnostic phase, so the underlying exception remains unknown and the earlier attribution to R385 is withdrawn. R386 exact-head run [42817756016](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42817756016) failed before Setup because the first helper required a Full parent token while the runner was already medium. R387 exact-head run [42820827177](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42820827177) also failed before Setup: the runner parent was TokenElevationType Default, primary, High integrity (0x3000), neither an already-medium token nor a Full UAC token with a linked limited token. R388 now handles this third runner state by creating a restricted same-user token: Administrators SID deny-only, maximum privileges disabled, integrity lowered to Medium; the actual child token is verified before Setup starts. R388 also retains per-phase Setup diagnostics and failure-artifact upload. No product/Setup source is changed. R291 diagnostic attempt 2 [42814404550](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42814404550) completed SUCCESS 3/3; Windows 2025's four Settings foreground transitions resolved in 0–2 ms and Windows 2022 passed. The original attempt-1 negative (`R146_SETTINGS_NOT_REAL_FOREGROUND`, `Visible=false`, `WS_VISIBLE=false`, 5111ms) and artifact remain preserved; retry is not a root-cause fix. R360 three-cycle stress [42817747115](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42817747115) completed SUCCESS on Windows Server 2022 and 2025. R291/R385/R290/R338/R367/R369/R370 exact-head PR workflows on R386 passed. R388 exact-head validation is pending; its R360 push [42822651632](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42822651632) is in progress. Do not weaken R385 or merge before all exact-head CI and independent human review.
- Scope limits: the harness compiles exact production helper methods and exercises a small extracted guard fixture; it does not run the full Setup binary, real UAC prompt or actual elevated update against an owner install. Owner installation, config and public v1.7.10 release were not changed. No merge/release was performed.
- Independent human review of PR #98 remains required (zero reviews; reviewer request still present). Historical R371 Windows 2022 UI negatives remain NON-PASS/UNPROVEN. Notion restoration remains explicitly pending; this coordination sync does not perform restoration.
- Exact next action: validate R387 exact-head Build/Verification, including the actual runner token source, all four medium-integrity child launches, exact tamper diagnostic, real 1.7.9-to-1.7.10 update, crash recovery, canary preservation and idempotent rerun; monitor R360 push and exact-head R291/R385 PR workflows; keep PR #98 unmerged pending all checks and genuine human review.

<!-- TBME:R307_R347_R349_SECURITY_FORWARDPORT:BEGIN -->
## R384 verification - stage-journal preservation, exact source/head CI; independent review and historical UI root cause open

- **R384 late-stage journal preservation (2026-11-10; local and hosted PASS).** R383's first nonrecursive cleanup correctly retained a late unknown file but deleted the five known journal markers before the final nonrecursive root deletion refused; that could leave an unrecognizable stage and block later recovery. R384 repeats the complete per-level file/directory/reparse allowlist inventory immediately before deleting ANY known entry. Three exact-source test-only injections placed a late root file, an unknown empty directory, and a nested file in old AFTER the first inventory and BEFORE the final inventory. Each candidate run refused before deletion and verified all five metadata files (owner.txt, phase.txt, index.txt, phase.tmp, previous_version.txt) and the Stage structure remained intact. The immutable R379 recursive-delete baseline still reproduced its late-file loss. Local baseline 2/2, Candidate 10/10; full Main/Broker/Supervisor/Setup build 0 warnings/0 errors, 3 selftests PASS; private Setup /verify 25/25. Engineering commit f59e1dcf410b97cf16350bc385b4fcbedbf3b093; source Git blob e3c7581bafc4a3f818d2e7d14432dc86dcc24bca; native harness Git blob 836495ff5616af543f8bb1412acd963c0c9d6774. Windows working-copy source SHA256 E7C8782DF180F40C61F7F71E1C72F0ADE174DE156C53EA92B3991C6B9DCDE95D; harness SHA256 E9150DB8BF950E281BED9517E8B6A198EE3D824A3287D341B562664CCA0DEB94.
- **R384 hosted acceptance.** Engineering source/test commit f59e1dc has 63/63 CI SUCCESS. The current PR #98 documentation-only head is 581d46a (only CURRENT_PROJECT.json and PROJECT_BRAIN.md changed since f59e1dc) and has 29/29 exact-head CI SUCCESS; production and test source blobs remain identical. R370 push run 42789591180 and PR run 42789601227: 8/8 Windows 2022/2025 baseline/candidate jobs PASS, each Candidate 10 checks and baseline 2, all eight typed raw receipts verified. R360 run 42789591343: 6 real Explorer/Settings cycles PASS (3 per Windows 2025/2022 host), 24/24 strict native Taskbar-hide samples PASS, 28–498ms (median 233.5ms), unchanged 1100ms hard limit; all six native receipts and two host summaries verified. Build/verification run 42789601278 built exact Setup SHA256 01A208F1FF0929AD6E03D895803AD08A65BB39F1B0014EB0B2A4DF4FC31D8CB9 and Main SHA256 BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6; its synthetic merge commit 7f5d6e7480f2f1d62214e51fdf23c6e730ccf011 has exact PR head as second parent. R299 real official public v1.7.9-to-v1.7.10 Setup upgrade PASS: 22 immutable managed predecessors, tampered predecessor rejection, interrupted commit recovery, user canaries preserved, second update idempotent. R300 real fresh install PASS: one canonical user install root and external canary preserved. Exact Setup bytes equal local build.
- **R371 remains a separate NON-PASS.** The two original Windows 2022 glass0 artifacts remain immutable and hash-verified: Settings-menu discovery missed at 5046ms (artifact 13690047155); Taskbar-hide invariant failed after 1100ms (artifact 13691325294). R360's new six-cycle success does NOT prove either historical intermittent root cause is resolved. No speculative product-source change was made for R371.
- **R384 evidence/claim boundary.** Aggregate owner-local receipt .local/audit/r384-hosted-acceptance-exact-head-20261110.json SHA256 66EA0AC59B24D5B0C67B2961E084CAAB8F3CE2778774D418818DB070C6A05266; local acceptance receipt .local/audit/r384-late-stage-journal-preservation-local-20261110.json SHA256 5EF13CEEEB63955FF55FB70ACCAF9FC28EEBADD5C49356CE040678C8674A9368. MMZ reviewer-host AI-assisted read-only static checks 14/14 and 39 PowerShell parses PASS, receipt SHA256 08856D5D74851E9837626FBF1796FD4DD358C118637D9342A7D2334DE962019D; this is NOT independent human review. Second inventory narrows the scan-to-delete race and preserves journal for tested late members; it is not atomic immunity to arbitrary concurrent directory rename/reparse swaps. PR #98 remains REVIEW_REQUIRED, zero genuine human reviews, requested reviewer mohammadmohammadzadeh19960-code. Owner installed Main/config/PID, public immutable v1.7.10 and its seven assets remain unchanged; no merge or public release mutation.
- **Primary goal and DoD.** Preserve the accepted v1.6 taskbar/Start/Settings behavior while supporting opt-in zero-background Glass, one per-user installation root, safe in-place update/rollback and low-overhead protected sensors. Public immutable v1.7.10 is already released as one unsigned Setup plus six companion assets: https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.7.10 ; source 6effbb8083615f5673f6df22a3b0782b33595ad3, public Setup SHA256 1D0326CF11CEE069AD295112A9CA49D9FCBDB58ECDAB46FFE9C0F7172CE26D7E. Published release, candidate security branch, owner-device installation, independent review and owner GUI acceptance are separate gates; machinewide singleton, signing, physical power interruption and malware clearance are not claimed.
- **Current source and review provenance.** Ready for review, mergeable and unmerged https://github.com/GOD13emad/TaskbarMonitorEnhanced/pull/98 on `security/r347-r349-helper-hardening-v1710`; latest security candidate is R370 source commit `8d0b43bfb5bc897aca829849f2e72861955dec06` (including the R369 App fix `f704c41266e512f90b88d01a90b0aacea69de8f8`); R364 pinned build-tooling history is commit `724be329b5468f14509d62dc460d6eec161a35d6`; R369/R370 test and workflow changes are included in current R370 head; the last exact PR branch head observed before the R367 state upsert was `92f8b8bdfef210f00ee8b03aff062fd9e2dfa8d3` (R367 product-source candidate commit; the upcoming coordination-only state commit does not change product/test source), with exact-head CI passing 30/30 and the R367 baseline/candidate matrix passing 8/8 on Windows Server 2022/2025. PR #96 was subsequently closed unmerged as superseded by #98: its R338 Supervisor and test Git blobs are identical, while #98 carries the updated SHA-pinned workflow. R367 is the first production-source delta after R357 and is limited to Supervisor/Broker temporary-file hard-link hardening; R358-R360 are native acceptance tests, R361-R364 are dependency/build/CI tooling and project-control state. The R367 exact candidate commit passed 30/30 exact-head checks, including the 8/8 hosted baseline/candidate matrix. The R358 initial harness run exposed a PowerShell `PSObject`/Reflection argument conversion error; explicit `object[]` fixed it. The R359 first harness attempt used `PipesAclExtensions`, unavailable in .NET Framework Windows PowerShell 5.1; the test now inspects the real pipe DACL with native Win32 `GetSecurityInfo`. Both exact reruns passed. The R305 same-SID elevated-token guard is intentional: standard-user UAC credential elevation runs under the administrator account whose credentials were entered, so a different effective SID is rejected before profile, log, ProgramFiles or task mutation; optional protected sensors remain degraded while the unelevated app installation can complete. This R359 evidence does not invoke real UAC or test a personal installation. The candidate originated from main 1883b4554461f06ee3be006168e37179c39a9433. Documentation-only PRs #99/#100/#101/#102 and owner-status correction PR #105 (merge commit 02c38f6176464400564099f7847a5429a2ce5233; current main) were merged separately; they did not install or publish this security candidate. The pre-R310 Helper matched upstream PR #80 blob a3a967c869b247afd8ae7fe697565cabac8ff1d2; the combined candidate's Helper blob is 53a60a9b66489644bdf13d3a1bf00ab70e7dc18a and Setup source blob is 4acf2aad9cab4d53d67ed77017d9edd0aa6bc228. R338 Supervisor logic derives from PR #96. PR #96 was closed unmerged as superseded by PR #98; PR #80 remains open as a historical v1.7.8-based review branch and is not safe to merge wholesale. The requested reviewer is `mohammadmohammadzadeh19960-code`; **zero human reviews are submitted** and PR #98 remains unmerged.

- **Production security scope.** Helper enforces canonical user Profile/LocalAppData/Temp boundaries, rejects UNC/reparse paths and unsafe backend ZIP content, embeds the trusted PowerShell script in Setup, transports its compressed content over per-launch random current-user/SYSTEM ACL-protected named pipe with child-PID pin and SHA256, pins the main executable image, validates owner-controlled protected ProgramFiles roots and shortcut ownership, and preserves existing v1.7.10 release/version and R298/R356 deferred-uninstall cleanup contracts. Supervisor rejects duplicate/unknown/missing/extra argv flags and derives trusted paths from OS-known roots while accepting valid local-volume LocalAppData redirection. R347 protects the directory chain; R349 protects Broker leaf files from pre-existing WRITE/DELETE handles. R357 additionally refuses ReadOnly Broker members during preflight and preserves the owner marker until every non-marker file and child directory has been removed.
- **Rollback fixes and exact path.** R310 requires an authenticated prior Task Scheduler XML snapshot, checks actual owner/action/trigger/settings drift, fails closed on intervening changes and restores the exact exported XML. R350 integrates the native handle-bound `TBMEProtectedBrokerTreeLease/DeleteOwnedTree` into normal Uninstall and `Restore-PreviousSensorLayer`; it checks owner marker/ACL, volume, paths, file IDs, reparse/hardlink state and bounded depth, with journal-only markerless authorization. R357 fixes a late-disposition failure edge: ReadOnly leaf and owner-marker attributes are refused before mutation; the owner marker is deliberately deleted last, after non-marker files and child directories. A mapped leaf that passes handle preflight but fails deletion now leaves the ownership marker available for authenticated rollback/cold recovery. Exact hosted Windows 2022/2025 run https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455363 passed **2/2 hosts and 30/30 checks per host**, including both ReadOnly preflight cases, mapped-leaf late failure, marker retention, junctions, hardlinks, depth limit, exact root, rename locks and outside-canary integrity. R351's exact Setup-embedded rollback function also passed again on both hosts (run 42556455452, 2/2).
- **R352 exact Install-catch runtime acceptance on current R357 head.** Host-only (never owner PC) https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455344: **3/3 SUCCESS**, comprising one isolated exact Setup build plus two fresh Windows Server 2022/2025 admin-token runtime hosts. Exact compiled Setup PE embeds the current production Helper, which runs real Install mode with one controlled throw immediately after a real new Scheduled Task registration. The original Install catch executes `Restore-PreviousSensorLayer`; both hosts pass **14/14 checks**. Prior Broker/Supervisor/backend/owner-marker bytes and exported Task XML return exactly; the prior task executes; authenticated PREPARED journal and byte-exact snapshots remain; newly produced telemetry is removed; no new sensor process remains. Temporary PawnIO version metadata is fixture-only; **no driver installed**. This PASS is limited to the injected post-registration failure point, not every possible Install failure or physical power loss.
- **R357 product-source CI — exact source/test head `07c095c43e3a96e838bfaee7f51d86707326dda8`.** All **12 workflows / 40 jobs SUCCESS (40/40)** on the exact product/test head. PR checks: Build/Verification https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556460119 **4/4**; R338 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556460213 **4/4**; R290 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556460209 **2/2**; R291 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556460114 **3/3**. Push regressions: R337 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455334 **4/4**; R338 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455447 **4/4**; R344 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455442 **8/8**; R347 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455376 **2/2**; R349 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455415 **2/2**; R350 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455363 **2/2, 30/30 native checks per host**; R351 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455452 **2/2**; R352 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42556455344 **3/3, 14/14 runtime checks per host**. Build/Verification additionally passed 10 Glass/chart suites, R272 thermal-warning red ink across all 49 themes, R244 nine-page Settings overlap, five portable runtime-contract suites, SPDX 2.3 SBOM generation and R136 manifest/SBOM equality to the exact Setup bytes. R291's real hosted Explorer witness passed Start/Settings/Glass/fullscreen visibility in `plain1`, `plain10`, `glass0`, and `opaque100` on Windows 2022/2025; it explicitly records `PersonalComputerTouched=false`, so this is not personal-device acceptance. The three build provenance/SBOM attestation steps were skipped in PR context; no new provenance-attestation claim is made. The immutable public v1.7.10 release and owner installation were not changed.
- **R358 exact-Setup named-pipe transport acceptance — test head `9130fabc5cd36b551fdf412d4a369d2a8ad523ea`.** https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42559951920 completed **3/3 jobs**: exact Setup build plus Windows Server 2025 and 2022 runtime hosts. Both hosts used the same manifest-pinned Setup SHA-256 `7639FD5B621C5C323E179ADEA164139D28F4671FBC7E858956CA5D59F02FEF06` and passed **6/6 checks each**: exact embedded Helper/source match; real Setup `CompactTrustedHelperSource` output parses under Windows PowerShell 5.1; bounded random pipe and system PowerShell `runas` bootstrap; wrong-PID client rejected without payload; intended child receives the exact SHA-256-pinned GZIP Helper and parses it; delivery completes without UAC or product mutation. `UACActuallyInvoked=false` and `ProductInstallOrMutationPerformed=false` are explicit receipt fields; this is pipe-transport acceptance, not interactive UAC or install acceptance. Raw receipts: Windows 2025 artifact 13649132053 and Windows 2022 artifact 13648124689; exact compiled Setup artifact 13648544336.
- **R359 same-account identity boundary — exact Setup test head `dc266f2d32bd4b51d6fd16c70d871e368ab8fcd0`.** https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42562923316 completed **3/3 jobs**: exact Setup build plus Windows Server 2025 and 2022. The exact same manifest-pinned Setup SHA-256 `7639FD5B621C5C323E179ADEA164139D28F4671FBC7E858956CA5D59F02FEF06` was used; both hosts passed **6/6 checks**: hosted runner admin identity and distinct well-formed target SID; exact Setup-embedded Helper/source match and R305 guard; native Win32 inspection confirms the actual Setup-created pipe has a protected DACL restricted to current owner SID and SYSTEM; embedded Helper rejects a different effective user SID with `SENSOR_BOUNDARY_ELEVATED_TOKEN_ACCOUNT_MISMATCH` before profile/install work; ProgramFiles product root, target logs/payload, Broker task and sensor processes remain unchanged; no UAC or product mutation. Different target SID is a synthetic negative fixture, not a real second account or UAC prompt. Receipts: Windows 2025 artifact 13650271363, Windows 2022 artifact 13649897524, exact Setup artifact 13650117717. This confirms the existing same-account elevation policy; it does not claim standard-user over-the-shoulder sensor installation support.
- **R359 exact PR-head regression CI — code/test head `dc266f2d32bd4b51d6fd16c70d871e368ab8fcd0`.** All four PR workflows passed **13/13 jobs**: Build/Verification https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42562928487 **4/4** (R298 original cleanup, R299 synthetic public v1.7.9-to-candidate in-place upgrade, and R300 fresh install); R338 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42562928527 **4/4**; R290 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42562928543 **2/2**; R291 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42562928545 **3/3**. The synthetic R299 upgrade is not the owner's personal upgrade receipt. PR-context provenance attestation steps remain skipped and are not claimed.

- **R360 repeated real Explorer Settings visibility stress — exact private candidate.** Run https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42568721956 passed **3/3 jobs** on exact test head `a583bcfcaa2fe8d9df5741082d31e1fc80cb2868`: exact Setup build plus Windows Server 2022/2025. Each OS ran three complete R291 cycles (fresh install plus two candidate reuses); all six cycles passed real Start/menu/Settings/fullscreen/return visibility in `plain1`, `plain10`, `glass0`, `opaque100`: **6/6 cycles, 24/24 mode executions**, zero failure diagnostics. Exact Setup SHA256 `7639FD5B621C5C323E179ADEA164139D28F4671FBC7E858956CA5D59F02FEF06`, Main SHA256 `7C046BB3A8AD8730AE561B8431CF31E5A31D11D8C967A589A9886D89C7CBADE9`; Windows 2022/2025 receipts 13651634781/13652473254, exact candidate artifact 13652511374. `PersonalComputerTouched=false`, `ProductSourceChanged=false`, `UACActuallyInvoked=false`; disposable guests only.
- **R361–R363 pinned dependency download hardening.** R361 `43a38a96e24ed021c653e818344109df8d5495df` added bounded transient retries for the immutable public v1.7.9 Setup download. R362 `d88ba4f74a4f86066f469642773b000bc5632ce4` added exact-SHA cache use, partial-file staging, bounded retry/backoff and terminal hash mismatch handling for LibreHardwareMonitor/PawnIO. R363 `a583bcfcaa2fe8d9df5741082d31e1fc80cb2868` added fixed GitHub Release Assets API IDs for LHM `355828308`, PawnIO `374375077`, and public v1.7.9 Setup `686770639`, retaining browser URL fallback and fail-closed byte/SHA pins. Local Windows PowerShell 5.1 harness downloaded all three exact assets **3/3 PASS**; fallback harness passed API 504→browser success, API 403→browser fallback, and terminal API hash mismatch. Full local Build passed App/Broker/Supervisor/Setup with **0 warnings / 0 errors**, workspace selftests **3/3**, Setup `/verify` **25 resources PASS**, `PawnIOBundled=false`; manifest Setup/Main hashes exactly match R360 candidate. R363 hosted Build 4/4, R290 2/2 and R291 3/3 passed; its R338 push run passed 4/4, while PR-triggered R338 was 3/4 because baseline A still used the old direct-download script and received HTTP 504 before product assertions. This failure was retained, not waived.
- **R364 exact-baseline CI download correction.** Commit `724be329b5468f14509d62dc460d6eec161a35d6` updates only the R338 workflow: the disposable workflow copies the candidate's current SHA-pinned `Build.ps1` and dependency lock into the isolated baseline/candidate checkout before compilation, then verifies both copied hashes and proves the product-source Git HEAD is unchanged. Local copy harness PASS. R338 push run https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42570085924 and PR run https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42570091574 each passed **4/4**. Baseline product source remained `035e8fc5db2fc020e539ec930a10770b9807d318`; candidate source was `724be32`; both downloaded and SHA-verified the same API-pinned dependencies. The baseline reproduced its expected 3-check old-argv acceptance; candidate passed its 20-check strict Supervisor trust boundary. Exact R364 PR CI passed **13/13**: Build/Verification 42570091607 4/4 (R298, R299, R300), R338 42570091574 4/4, R290 42570091569 2/2, R291 42570091577 3/3. R299 verified API asset size/SHA and the official v1.7.9-to-candidate Setup-driven hosted upgrade/recovery/idempotence on disposable guests. No owner installation, public release or production source was changed.
- **R365 owner-local exact-Setup supplemental regressions (2026-11-09).** On the owner Windows host, Windows PowerShell 5.1 ran build/Test-R335-AtomicUserLogSink-Native.ps1 against the exact compiled Setup PE SHA-256 7639FD5B621C5C323E179ADEA164139D28F4671FBC7E858956CA5D59F02FEF06 (8,781,312 bytes); **24/24 PASS**. The test verified exact embedded production Helper source, bounded SHA-pinned named-pipe delivery, current-user/SYSTEM DACL, PS5.1 parsing, five no-reparse component/file handles, rename denial while leased, separate-process denial, pinned writes, release behavior, junction rejection and outside-canary preservation. R338 compiled Supervisor trusted-argv/path regression passed **20/20** and R298 deferred-cleanup contract passed. The R335 fixture left **zero** temp directories; no UAC, elevated Helper launch, ProgramFiles change, install, product mutation or owner-process interruption occurred. Read-only owner state still showed installed v1.7.10 Main SHA-256 715CDA5E666E12C5FF2BCD46D513467CCEFEABE43A76F77689F604D4F432F2D7, Uninstall SHA-256 1D0326CF11CEE069AD295112A9CA49D9FCBDB58ECDAB46FFE9C0F7172CE26D7E, main process running and Broker/Supervisor processes active. This is local helper/pipe/handle regression evidence only, not real UAC, upgrade, GUI/audio, release or human-review acceptance.
- **R366 GitHub coordination and scoped Issue #6 audit (2026-11-09).** PR #96 was closed unmerged as superseded by PR #98 after exact Git-blob comparison confirmed identical R338 Supervisor source (d3ae5870298d3b086de018a796ee2bd4211d8853) and native test (e745536b2f9bdc143c926b9a9cdd3eaaf6dcef09); PR #98 uses the newer R338 workflow with SHA-pinned Build.ps1/dependency verification. Closure comment ID 6734460420. Public tracker Issue #7 received R365 status comment ID 6734470728. PR #98 was OPEN/MERGEABLE/UNMERGED at head da5bd840226f6a3ad71ac3a175e03eb5e4060b53 with 13/13 exact-head CI and zero submitted reviews; the independent reviewer remains requested. PR #80 remains open only as a historical v1.7.8-based review branch and is not safe to merge wholesale; PR #82 remains draft v1.7.8 provenance work. A bounded read-only owner-host Issue #6 check found zero .sys files under the current installed v1.7.10 root, the reported legacy TaskbarMonitor.sys path absent, zero R0TaskbarMonitor/WinRing0/WinRing0x64 services, and zero WinRing0/R0TaskbarMonitor/TaskbarMonitor.sys literals in current src/installer/build. This does not identify or clear the reporter's quarantined binary; Issue #6 remains open for the actual driver SHA-256 and download/install origin. A bounded inventory of the current app root and project .local depth 4 (excluding archive) found no complete personal v1.7.9-to-v1.7.10 transaction receipt; only the R303 owner Setup-verification record/script were found. The personal upgrade gate therefore remains UNVERIFIED. No product source, release or owner installation changed.
- **R368 R291 input queue stability (2026-11-09).** The real physical-click helper keeps the cursor at the target for 100 ms after SendInput, with Windows PowerShell 5.1 parse and C# compile PASS. Initial exact-head CI 20/20 PASS, but this is not a general UI proof: a later hosted Windows Server 2022 glass0 Settings-menu-not-found first attempt failed and succeeded on one controlled job rerun, with cause unproven.
- **R372 real native Settings hit-test (2026-11-09).** Test-only commit 73b548667bf83044a223ed757567d5570f5bc710 introduced WindowFromPoint-based selection of actual target-owned clickable glyph before physical right-click; original real UIA Settings-menu, foreground, Start, fullscreen, taskbar-hide and screenshot assertions are unchanged. Its first two Windows 2022/2025 hosted R291 trials failed BEFORE hit testing because PowerShell 5.1 parsed an unparenthesized coordinate array as Object[] addition; verified exact repro and fixed it in 3e5523e6f84be7f62c96980dcc92116a00c14f6f. Windows PowerShell 5.1 numeric probe 663,748, parser, native C# compilation PASS. Exact corrected test head GitHub 28/28 checks SUCCESS (0 failure/pending), including R291 four-mode real native Windows 2022/2025 run 42666822817, three-cycle R360 both OS run 42666809790 and installer, Build and prior security regressions. Eight typed hit-test receipts prove the clicked pixel HWND matched the monitor on all four modes on both systems, but all EIGHT original fixed pixels already hit the monitor, so the fallback branch was not exercised and zero-alpha click-through as cause of earlier R291 intermittent failure is NOT PROVEN. First harness failures and prior glass0 missing Settings/taskbar-hide failures remain NON-PASS and root cause OPEN. Product source src and installer unchanged since R370 commit 8d0b43b; installed and public immutable official v1.7.10 unchanged and owner hashes still match. Local scoped receipt .local/audit/r372-real-native-hittest-20261109.json SHA256 D7BC6A9B0B60FF1FBD42039C921AE0F59BA59ADF85D704807B9378F0AA0B8175. PR #98 comment 6747229188 and Issue #7 6747236498. Human security review still zero.
- **R371 hosted R291 diagnostic, NO product change (2026-11-09).** Strict Windows Server 2022 R291 first attempt on coordination head 31ea1c3 failed at glass0 Settings menu item not found after 5,046 ms. One controlled same-job rerun passed the glass0 real Settings foreground but FAILED the separate taskbar-hide original 1,100ms native visibility gate. Both are NON-PASS and their causes remain UNPROVEN. Test-only commit c0c64685156a651c61ff35fa5b304c5a9aa67e4b retains the unchanged strict fail and on that failure only captures extra 2,000ms subsequent visibility plus bounded hosted app logs and native failure JSON, without changing any compiled product source. PS5.1 and YAML syntax PASS. Current exact test head CI 28/28 SUCCESS, including R291 Windows 2022/2025 run 42662489526, three-cycle R360 stress each OS run 42662472466, full Build/Verification and security R367/R369/R370 workflows. This passing run did not trigger the new failure-only path and does NOT prove permanent UI root-cause fix. PR #98 comment 6746607139, Issue #7 comment 6746615839; local .local/audit/r371-r291-intermittent-ui-20261109.json SHA256 A096C940520B8DE40C89F70B23B6C1E6FA0119A7B6925554F8C9B037C23A0AC4.
- **R370 Installer WritePhase phase.tmp hard-link guard (2026-11-09).** Exact source baseline a8fadee compiled the production WritePhase method with only a test-root accessor and reproduced same-user NTFS outside-canary write-through via pre-created fixed phase.tmp hardlink. R370 source fix 8d0b43b uses exclusive FileMode.CreateNew/FileShare.None while preserving the fixed filename required by stage cleanup, atomic File.Replace/Move, and PREPARED/COMMITTING/COMMITTED semantics. Local baseline 1/1 reproduced; candidate 3/3 hardlink refusal, transitions, destination replacement PASS; full local App/Sensor/Setup build 0 warnings/errors, three selftests and exact embedded Setup source PASS. Hosted push 42649502780 and PR 42649521811 baseline/candidate Windows Server 2022/2025 8/8; eight typed artifacts; exact PR/product head 8d0b43b passed 63/63 checks, including R360 repeated real Explorer cycles on both hosts. Local receipt .local/audit/r370-upgrade-phase-hardlink-local-20261109.json SHA256 E50936C6BB5BB0F0DBE630FC0FA0876EEFD48EA7BB83D590E7A54BEF7A51EE8C. PR #98 review comment 6744756723, Issue #7 comment 6744763801. This fixture is source-extracted, not direct owner Setup execution; no cross-privilege or concurrent directory-writer guarantee. Official public v1.7.10 and current owner installation unchanged.
- **R369 App AtomicTextFile.Write hardlink security (2026-11-09).** Compiled exact vulnerable baseline e6d3405 used a predictable PID/TickCount temp path; pre-created same-user NTFS hardlinks wrote through to an isolated canary. Fix f704c412 creates an exclusive GUID temp with FileMode.CreateNew, then File.Replace/Move and non-overwriting first backup. Full local build 0 warning/error, selftest/feature/workspace and reproducibility PASS, native candidate 6/6, UTF-8 byte parity 6/6 including Persian. Hosted R369 push run 42643594516 and PR run 42643606514 each passed 4/4 on Windows Server 2022/2025, eight typed JSON receipts. Test-only dfd4a36 and 40e598a corrected false hosted AppData guard and attacked-file backup fixture. Test branch head 40e598a exact CI 28/28 success after one R291 Windows Server 2022 first-fail/single-rerun-PASS (both outcomes retained). Local evidence .local/audit/r369-atomictext-local-20261109.json SHA256 A8590B336CB3261EB7BCA885F893451BEB242AC0B27AB55A8ACB532969841FEE. Guarantee covers pre-existing aliases, not concurrent directory writer after close. PR #98 OPEN/mergeable/unmerged with zero independent human reviews; immutable public v1.7.10 and owner install unchanged.
- **R367 Supervisor/Broker temporary-file hard-link boundary (2026-11-09).** Exact vulnerable baseline commit 035e8fc5db2fc020e539ec930a10770b9807d318 full build and native 4/4 reproduced pre-created hard-link write-through at Supervisor StatePath.tmp and Broker PID/TickCount temp path. Candidate product commit 92f8b8bdfef210f00ee8b03aff062fd9e2dfa8d3 uses GUID+FileMode.CreateNew temp files, removes Broker File.Copy overwrite fallback and fails closed after File.Replace/Move retries; candidate full build 0 warnings/0 errors and native 4/4 passed, including both destination-hardlink replacement canaries. Hosted R367 push run 42584436249 and pull_request run 42584443225 passed 8/8 across baseline/candidate on Windows Server 2022/2025. Exact candidate PR-head CI passed 30/30 checks. Eight typed JSON receipts are retained as artifacts; local receipt .local/audit/r367-elevated-temp-hardlink-local-20261109.json SHA256 AA3485943E4C3B2C0D4DF91688F41251F8C5AF503926A4E2B890A7EFEF410736. Scope is explicit: pre-existing aliases are rejected; a concurrent directory writer after the temp handle closes is not claimed to be race-free. Official v1.7.10 and owner installation unchanged. PR #98 remains open, mergeable and unmerged with independent human review pending; zero reviews submitted. Issue #6 reporter SHA/origin, personal upgrade transaction receipt, owner GUI/audio witness and Notion restore confirmation remain open/deferred.
- **R373 native taskbar-hide latency telemetry (2026-11-09; test-only).** Product/test commit 915e9e3557f4815a0de99188f126e726a7f8a7ad changes only build/Test-R291-ExplorerStart-Settings-Glass.ps1 and .github/workflows/audit-r360-r291-settings-visibility-stress.yml; supplemental docs-only PR heads 13ad4083b8238df24047e4459834a2edbb046a6d and 38e773a40b8259a7bbbe31678ac40843fe37e497 were separately revalidated. Product source remains R370 8d0b43bfb5bc897aca829849f2e72861955dec06; public/owner v1.7.10 unchanged. R291 records native taskbar/monitor visibility transitions with the original 1,100-ms hard gate unchanged; R360 retains taskbar-hide failure JSON, generic native failure JSON and bounded app logs. Local Windows PowerShell 5.1 parser, R360 YAML/artifact-glob parse, synthetic hide-timeline and git diff --check PASS. Last tested docs-only PR head 38e773a passed 29/29 CI; code/test head 915e9e3 PR checks 28/28. R291 runs 42686996123, 42689659064 and 42691157514 each passed 3/3 jobs on Windows 2022/2025 (6/6 host executions, 24 mode executions); R360 run 42686985448 passed 3/3 jobs, 6/6 cycles and 24/24 modes. Across 12 cycles / 48 native hide samples, latency was 29-502 ms (median 224 ms); all samples had Taskbar and monitor visible before, hidden after. Candidate Setup/Main hashes are identical across all runs. R360 failure-only artifact path was configured but not exercised because no failure recurred. Primary receipt .local/audit/r373-taskbar-hide-timing-20261109.json SHA256 82ED4356E9A8BBA94939CEE533EE94CA30755A30B8306079A47D779F3A9306FD; first supplemental receipt .local/audit/r373-state-head-r291-revalidation-20261109.json SHA256 EB4FDF4D36F08C65961E76D70EB06581739747095DAD49F6D08180AF57A4E482; final supplemental receipt .local/audit/r373-final-state-head-r291-revalidation-20261109.json SHA256 4AC8BCB38C33ECC28F9B2B80BCF00B196826652426339275F860E7ABEE8B6C35. Microsoft documents that System.Windows.Forms.Timer runs on the UI thread/message pump and its interval is not guaranteed under load (https://learn.microsoft.com/en-us/dotnet/desktop/winforms/controls/limitations-of-the-timer-component-interval-property); plausible scheduling mechanism only, not proof. Historical R371 Settings-menu and taskbar-hide failures remain NON-PASS and root cause UNPROVEN. Manual dispatch R360 run 42673306730 had no jobs/artifacts; R291 run 42673124467 produced only candidate and Windows 2022 jobs, so neither is a valid two-host product failure.
- **R375 native Settings-menu failure topology (2026-11-10; test-only).** Latest test-only source commit dc625f53ff5a980617e5cf47f7ec642d8d3be2ff changes only build/Test-R291-ExplorerStart-Settings-Glass.ps1 (37 insertions); R370 8d0b43bfb5bc897aca829849f2e72861955dec06 remains latest production source. On an original documented Windows 2022 glass0 no-Settings-menu failure (run 42651408908 first attempt), the tested product PID was 1624 but the foreground PID was 6572 and no Settings UIA match was found in five seconds; the differing PID is evidence, not a proven cause. R375 preserves the original strict five-second menu absence throw and original 1,100-ms taskbar-hide failure, adding failure-only bounded Win32 HWND/class/visible/parent/owner/rectangle/foreground/hit-test JSON. The existing R291/R360 artifact globs already preserve the new _NATIVE_FAILURE.json if the failure recurs. Windows PowerShell 5.1 parser, extracted native C# compilation, strict-gate source checks, an isolated actual failure-branch JSON serialization with synthetic values, and git diff --check passed. Exact PR test head dc625f5 CI 28/28 SUCCESS; real R291 run 42697474249 passed Windows 2022/2025, and R360 run 42697462258 passed six real guest cycles across both OS hosts. Native receipt parity was verified: combined R373 and R375 20 guest host-cycles / 80 UI modes / 80 taskbar-hide samples, all taskbar and monitor visible-before/hidden-after and strictly under unchanged 1,100 ms (29-513 ms, median 239.5 ms). R375 local aggregate receipt .local/audit/r375-current-test-results-20261110.json SHA256 8B639DE35B0602F63A3DD12E0C03501F687CC6C4C9D944C39889C5F928ADABBA; synthetic failure-branch receipt .local/audit/r375-native-menu-mock-20261110.json SHA256 F1E4CB7FEDE9C791354D4C933ABA8A318DED109F3D4ED8053FB107630E2CBF72. R374 independent human review handoff was posted and read back as https://github.com/GOD13emad/TaskbarMonitorEnhanced/pull/98#issuecomment-6750739912; zero submitted human reviews, REVIEW_REQUIRED. Historical R371 failures remain NON-PASS with root cause UNPROVEN. The owner-running v1.7.10 Main hash 715CDA5E666E12C5FF2BCD46D513467CCEFEABE43A76F77689F604D4F432F2D7, active process and recent CPU/GPU/storage files were rechecked read-only; app requests temperature notifications/sound, but no speaker or red-visual witness is claimed. No candidate installation, public release, signer status or Notion restore was changed.
- **Negative results retained.** The first R352 combined build/runtime run at d16094a stopped on the pre-mutation target-collision guard because build/selftests had occupied the canonical owner profile; no failure was waived. c076fec isolated the build from fresh runtime profiles, yielding the first two-host PASS. Independent receipt inspection then found OutsideCanarySHA256After was blank despite a passing direct hash comparison; b937e25 recorded the actual post-hash and reran both hosts, producing identical non-empty canary hashes. Earlier R339/R337/R298/R85/R291/R350/R340/R347/R349 and R351 harness-specific failures/corrections remain documented in PR #98 and original run artifacts, not rewritten as PASS.
- **R355 base sync and diagnostic follow-up (2026-11-09).** Candidate branch merged existing public-documentation-only main 02c38f6176464400564099f7847a5429a2ce5233 through commit 0b4c650a11486ebcf6d42493a4a7a8a7a7f3c5cb; merge-tree was conflict-free, product/helper/build/test source was byte-unchanged, and exact-head hosted CI passed Build/Verification 4/4 (42544429315), R338 4/4 (42544429237), R290 2/2 (42544429366), R291 2/2 (42544429264). One earlier Windows 2025 R291 Settings visibility failure occurred at fa25c09 attempt 1; it was NOT waived or explained by simple z-order occlusion, although a controlled same-head rerun passed. The R355 candidate changes ONLY the disposable-host R291 test failure instrumentation to retain HWND WS_VISIBLE, parent/owner visibility and bounded failure JSON in the existing artifact glob; no product code, success threshold or timeout changed. Local Windows PowerShell 5.1 parse, native C# compile and source/file-scope checks PASS. Hosted R355 exact-test commit e1a8ac211de94fa46df8e3ab8fd9ac6e838a6ca6 passed Build and Verification 4/4 (42545438922), R338 4/4 (42545439152), R290 2/2 (42545438926), and R291 native Explorer Start/Settings/Glass 2/2 (42545438887). The hosted successful R291 runs did not exercise the failure-only JSON branch. A separate local Windows PowerShell 5.1.26100.9818 synthetic hidden-HWND harness executed the exact R291 failure block, wrote and re-read A_SETTINGS_NATIVE_FAILURE.json, and verified Visible=false, WSVisible=false, parent/owner fields and ThresholdsUnchanged=true. This is diagnostic collection/serialization PASS only, not a product UI fix or root-cause proof. PR #98 is Ready for review, not merged; one human approval is required by the active default-branch ruleset with stale-review dismissal, last-push approval and thread resolution, and the named reviewer still has not submitted an independent decision. The subsequent redacted-status exact-CI head 0b8a21668869a700f879df2540288d69e9779f60 passed Build/Verification 4/4 (42549182496), R338 4/4 (42549182488), R290 2/2 (42549182569) and R291 3/3 (42549182525), totaling 13/13.
- **Owner-device acceptance / read-only boundary (2026-11-09).** The owner explicitly states the currently running application is satisfactory and reports no outstanding functional problem. Treat this as **USER_ACCEPTED_CURRENT_FUNCTIONAL_BEHAVIOR**, not as a new instrumented Start/Settings/Glass or physical speaker/banner test, nor acceptance of the unmerged security candidate. The installed personal Main remains v1.7.10+r299 under canonical LocalAppData, previously observed SHA256 715CDA5E666E12C5FF2BCD46D513467CCEFEABE43A76F77689F604D4F432F2D7; sensor process/telemetry readback was healthy at the previous read-only check. No owner process, task, registry, settings, UI focus, installer, or immutable public release was modified for this acceptance. Instrumented same-desktop UI and speaker/banner proof remains **NOT_EXECUTED / DEFERRED (not PASS)**, because no current attested foreground takeover route exists and the owner reports no defect; avoid further intrusive attempts. Reported Issue #6 still requires the independent reporter's affected driver hash and origin.
- **R375 exact owner/candidate thermal-Glass renderer and current-mode distinction (2026-11-10; independent read-only owner-host evidence).** On Windows, exact private R370 Candidate Main SHA256 BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6 and exact official owner-installed v1.7.10 Main SHA256 715CDA5E666E12C5FF2BCD46D513467CCEFEABE43A76F77689F604D4F432F2D7 each independently passed R272 real bitmap renderer proof: 49 themes x 2 taskbar backgrounds = 98/98 cases, synthetic CPU 95 C hot produced >=2790 strong red pixels, CPU 60 C cold produced zero red, and >=22355 pixels stayed fully clear in Glass. Owner installed process PID 10892, binary and config SHA remained unchanged. Read-only owner config SHA256 3335F7BD254C48E88AA9C0F115EE54D03301E1DD421F45D2A8408634C7B8F182 reveals GlassMode=False, Opacity=0.01 (ordinary 1 percent opacity, NOT zero-background Glass), alerts/notifications/sound enabled, CPU hot threshold 90 C, current theme Mission Control; a point-in-time CPU sample was 77 C (below threshold). Follow-up exact Candidate proof-mode reflection at owner settings geometry compared synthetic hot 95 C / cold 60 C on light and dark taskbar: ordinary 1 percent mode had 0 qualifying high-opacity red pixels at hot 95 C, GlassMode=True had 3000 at 95 C, and both were zero at 60 C. This distinguishes a saved mode-selection/very-low-alpha visibility issue from a proven defect in the true Glass thermal renderer; live onscreen red and audible user witness are NOT established. Evidence local .local/audit/r375-ownerhost-thermal-rootcause-20261110.json SHA256 8C609F79C20DED2B4AB6E07A12271930C6D6CA8A151864B514F99E756EF5E7D6; Candidate acceptance SHA256 40E9E87858E3803BA3AE373E5307927F58DE1DC8C98B832C84F33C5F1BA09631; official installed acceptance SHA256 7E667429C1AB01C12267B5F4EE1656544A148B363DFC7986CCF3EA4331B46B2B. No source, owner config, process, install, public release, or Notion mutation. R375 owner live Win32 placement and sound endpoint evidence (read-only): exact running PID 10892 native child window HWND 84351036 was visible and parented to active Shell_TrayWnd HWND 65892 at 1100x48 pixels, within taskbar y=1392-1440; confirms native window structure, NOT rendered pixel legibility or Settings click persistence. Receipt .local/audit/r375-owner-native-topology-readonly-20261110.json SHA256 BF9934D85BEFA494C5295DC33D78B8462C29B2D1542DC48892E2D86F3E106246. Windows SoundExclamation scheme file exists and Audiosrv/AudioEndpointBuilder run, while CoreAudio default Multimedia/Console render endpoint was active, unmuted and scalar 1.0, mapped via device registry to Mi monitor / NVIDIA High Definition Audio. This can explain user not hearing alerts on a different physical output but NOT prove acoustic silence or audibility; 27 logged TEMPERATURE_WARNING_SOUND_REQUESTED and 0 failures in sampled recent lines are requests not witnesses. Audio receipt .local/audit/r375-audio-endpoint-readonly-20261110.json SHA256 4D3D0D6CE35153598EC13C1E8C2AA3C08635EA6DF21637BD1D7B8A2E0CB68976. No user settings/input modified. R375 same-session cropped taskbar screenshot (2026-11-09 22:36:42Z) is local-only evidence from a bounded read-only 1300x48 lower-screen crop (no full desktop image or input action), exact PNG SHA256 7D2549B00363876AF9D5190DD564449F9B5711E4CD405B7A940FD1D4CD588F0C at .local/audit/r375-owner-taskbar-visual-crop-20261110.png; visual inspection confirms NORMAL-mode CPU/RAM/GPU text and bar charts legible on taskbar with config GlassMode=False, Opacity=0.01, not a true-Glass acceptance. Captured displayed CPU temp approx. 86 C, below configured 90 C threshold, so the absence of live red alert in this frame is not a failure. Official Microsoft GetLayeredWindowAttributes documentation states it fails for surfaces configured with UpdateLayeredWindow; the failed read-only alpha query cannot be interpreted as zero alpha and no style changes were attempted (https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getlayeredwindowattributes). Read-only Windows endpoint enumeration confirms default active unmuted Mi monitor via NVIDIA with a second ACTIVE Speakers / Realtek USB Audio endpoint, but no proof of actual connected physical speaker or audibility, and no default endpoint change; local receipt .local/audit/r375-owner-audio-alternatives-readonly-20261110.json SHA256 E258BE3851658D93A8E20497CF03B35BC39ACC182D6A4BACBD1EC2F2596EF11E. Owner must choose intended physical audio endpoint. No owner UI mode, global audio preference, app process, release, or Notion mutation.
- **R375 R360 supplemental exact-head recurrence probe (2026-11-10).** Workflow-dispatch run https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42717624532 on exact source/docs HEAD 2c41cfceae202c82402ccf018864bcba7d020e80 built SHA256-pinned private Setup 2B7A2941F3F489196601F8CFF04711C8E5DA65FC12F24394B60C280FA8954547 and Main BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6 and ran three real R291 Start/Settings/Glass cycles each on disposable Windows 2022 and Windows 2025: 3/3 hosted jobs SUCCESS, 6/6 host cycles, 24/24 strict native visibility samples PASS, hide 2-528 ms median 259.5 ms under original 1100-ms gate. Raw R360 A/B and six R291_NATIVE.json receipts downloaded and SHA256/typed conditions inspected. Aggregate exact-candidate R373/R375 + supplemental R360: 26 host cycles, 104/104 visible-before/hidden-after samples PASS, hide 2-528 ms median 247.5 ms. Evidence local .local/audit/r375-c2-stress-aggregate-20261110.json SHA256 3C30763EF4F1D2AD38E78CAA8C75D4AD3C920FF5953F72AF332015CA88061CC3, with 26 per-receipt hashes. Historical R371 Windows 2022 Settings popup and taskbar-hide failures remain NON-PASS, root cause UNPROVEN; no real negative R375 native popup capture occurred on this rerun. No product, owner config/install, public release, or Notion mutation.
- **R375 owner real fullscreen and Windows notification eligibility (2026-11-10; live read-only).** On owner Windows desktop with active Chrome full-screen at 0,0,3440,1440, TaskbarMonitorEnhanced Main PID 10892 and taskbar-owned monitor HWND 84351036 remained alive, but monitor IsWindowVisible=False while app log independently recorded TASKBAR_PRESENTATION_STATE Fullscreen; that is expected current fullscreen suppression, not proof of behind-taskbar UI failure. Windows shell32 SHQueryUserNotificationState returned HRESULT S_OK and state QUNS_BUSY=2 (busy full-screen/presentation): Windows reports notifications inappropriate in this moment, but individual toast delivery is NOT proved absent. Owner log recorded a 90 C CPU temperature threshold and TEMPERATURE_WARNING_SOUND_REQUESTED while Fullscreen state active; request is NOT an acoustic witness. A separate read-only CoreAudio default-roles session probe returned SystemSounds session volume 1.0, muted=False, state 0 (inactive at probe), which does NOT prove playback or hearing. Existing default device snapshot was Mi monitor/NVIDIA; Realtek Speakers is available, but owner physical audio choice remains unknown. GlassMode remains False, ordinary Opacity 1%, so this observation is NOT a true-Glass-mode acceptance. Scoped local receipt .local/audit/r375-owner-fullscreen-system-notification-readonly-20261110.json SHA256 01A0272D0F4FFD09D68EEA40E7C845ED2887F1B63610F0D090EB5590CA2503F1. Official notification-state semantics: https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-shqueryusernotificationstate and https://learn.microsoft.com/en-us/windows/win32/api/shellapi/ne-shellapi-query_user_notification_state. Product source/install/config, OS notification policy, OS audio routing, and Notion unchanged. Historical R371 Settings failure root cause remains UNPROVEN.
- **R376 R369 time-window negative-control repair (2026-11-10; test-only, HOSTED PASS).** Previous cf104dc had R369 baseline A FAILURE (run 42721843415): 350 preseeded aliases only 850ms ahead could exhaust its setup window on a loaded guest. R376 exact test-only commit 0c2a5a48f2ff2cad00ee8a569e6e25dd0dce315f changes only build/Test-R369-AtomicTextFile-Hardlink-Native.ps1, increasing bounded lead to 8000ms, insisting on observed native compiled Write call in the seeded TickCount window, and still demanding the baseline exploit WRITE-THROUGH and safe candidate canary INTACT, backup and cleanup gates. Windows PowerShell 5.1 parser and isolated owner-host exact Candidate test PASS: 350 links, 10 time-aligned writes, 6/6 checks, canary unchanged. Two independently triggered exact-head hosted R369 runs 42724136143 and 42724144960 BOTH SUCCESS (4/4 jobs each) on Windows 2022 and 2025. All eight downloaded raw typed receipts verified: vulnerable baseline A/B twice reproduced outside-canary writes 4/4; Candidate A/B twice blocked every canary write with ten truly aligned compiled writes each 4/4. Evidence local .local/audit/r376-r369-hosted-evidence-20261110.json SHA256 A17065DE6B2C0CCA04896BCEC75CB633A71AB4398F1EA7D3027D4BFC9620EC5D includes eight receipt hashes. R376 exact-head PR CI 36/36 SUCCESS, no failures/pending. R360 stress run 42724136388 passed six new guest cycles / 24 native visibility samples with original strict 1100ms gate (49-492ms, median 277.5ms). Historical R371 UI negatives stay NON-PASS/unproven. Production R370, owner/public v1.7.10, configuration and Notion were not mutated; human security review still required for PR #98.
- **R377 preserved unknown empty upgrade-stage directories (2026-11-10; local + hosted PASS).** Targeted review of PR #98 identified that installer/TaskbarMonitorEnhanced_Setup.cs CleanOwnedStage previously checked unexpected FILES/reparse DIRECTORIES but silently deleted unexpected EMPTY ordinary directories using recursive Directory.Delete. Source commit 8ff56325a55335d130a27770b54809dc913ca233 adds a canonical allowlist of directories implied by indexed old/new stage files. The exact source method extracted into updated existing build/Test-R370-UpgradePhaseTempHardlink-Native.ps1 reproduced baseline silent empty-directory deletion (2/2 checks) and confirmed Candidate refuses/preserves unknown directory while still cleaning known nested stage paths (5/5 checks), with the existing hardlink and three journal-phase invariants retained. Full local Main, Broker, Supervisor and Setup build: 0 warnings/0 errors; 3 workspace selftests PASS. Hosted exact-source-head R370 run https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42732526897: 4/4 matrix jobs Windows 2022/2025 PASS (2/2 baseline exploit reproduction + 2/2 candidate protection), four raw receipts checked by variant, SHA256 and expected checks. Hosted R360 run https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42732511804: 6/6 real guest cycles and 24/24 native taskbar-hide samples PASS, 113–506ms median 330.5ms under unchanged 1100ms threshold. PR #98 product-source HEAD 8ff5632 had 67/67 exact-head CI checks SUCCESS, zero failed/pending; every raw R370/R360 receipt and compiled Setup binary SHA matched across guest hosts and local build: Setup SHA256 B1E8121ED9C1F121E45C6A2F6D736AEA352B5BF636489C643139CBDA89F4F9D1, Main unchanged BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6. Primary local hosted receipt .local/audit/r377-hosted-acceptance-exact-head-20261110.json SHA256 CF56B446C58E38E8C5DC4558EC360388B8EA539B3D074ECDFA4D45941649BF2F; local R377 initial evidence E643E747ACE4062FB5BCDBD978098715CA53EA99206071C7041EE2F7A7D20140. Scope: same-user transient upgrade stage, not a proof against arbitrary concurrent races or substitute for independent human review. No public release or owner installed Main/config changes. Reviewer MMZ laptop tunnel unavailable during this review; PR remains OPEN/REVIEW_REQUIRED with zero submitted independent human reviews.
- **R379 upgrade-stage reparse preflight traversal (2026-11-10; source, native hosted CI and exact hash PASS).** The prior R377 cleanup method used Directory.GetFiles(UpgradeRoot,"*",AllDirectories) before validating directory reparse attributes. An isolated, reproducible NTFS junction to a disposable directory outside the stage caused it to enumerate an outside-canary file NAME (not its contents); the strict newly-added R370 regression failed on the actual old Candidate as expected with an unknown-external-file exception. Engineering source commit 5dd6bd9919656b63b0db45b74d34ff8221ee018e replaces recursive enumeration with bounded per-level TopDirectoryOnly: verify each current directory and immediate file/child directory reparse attribute and canonical allowlist before descent or eventual deletion. Source Setup SHA256 7A6A20545A7D1CEA48A110192FA3EB8BE8791019EE3170EBCFB250A8C72A66CB, existing test harness SHA256 0F1890EAADD75F8055CDA537A42FC81E05E8564EF285D17E1ED88CEF41B733FE. Local WinPS5.1 baseline two negative controls PASS; Candidate six security/phase/preservation checks PASS including rejecting external junction before recursive traversal. Main/Broker/Supervisor/Setup full local build zero warnings/errors, 3 workspace selftests PASS; Setup /verify 25 resources PASS with no PawnIO bundled and embedded Main SHA256 BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6. Hosted exact source HEAD PR checks **63/63 PASS**; R370 independent push https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42748759572 and PR https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42748768788 8/8 total Windows 2022/2025 baseline/candidate jobs PASS, all 8 typed receipts downloaded and SHA verified. Real UI R360 https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42748759516: 6/6 guest cycles, 24/24 strict native hide samples PASS at 59-507ms median 280ms under unchanged 1100ms limit; all 6 raw native and both summary receipts validated, exact Setup SHA256 4D50FFFB0AF0751D2542AD0FA9255C6F8169AD80273B129D03FD46DE4A65F9CD (identical local/hosted) and Main BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6. Evidence .local/audit/r379-hosted-source-acceptance-20261110.json SHA256 6B8E96F4D0DA17E0563141738E14EBD0F93412BE9B1D9F731CC7DA27BAE5F9CC; predecessor local R378 isolated junction guard SHA 94FD48FDE1145CFD3336FEB4E6FD5283118943D118A793911A95D345CAAA9E4B. Scope: source-level test against same-user disposable NTFS stage; no proof against arbitrary TOCTOU/concurrent junction swap races and NO independent human security review. Latest owner official v1.7.10 Main/config and public immutable release unchanged, Notion restore unauthorized. Historical R371 intermittent UI failures remain NON-PASS/UNPROVEN.
- **R380 owner-installed synthetic Glass acceptance (2026-11-10; local proof PASS, actual owner Taskbar witness OPEN).** Executed FOUR direct safe proof paths from the currently installed public v1.7.10 owner Main binary SHA256 715CDA5E666E12C5FF2BCD46D513467CCEFEABE43A76F77689F604D4F432F2D7, not just hosted PR Candidate: (1) real overlay thermal painter on all 49 themes x dark/light backgrounds, 98 synthetic pairs CPU 95C warning 85C, min 2,790 opaque hot-red foreground pixels, ZERO cold-red pixels, at least 22,355 fully transparent background pixels; (2) real per-pixel Glass foreground at 0/29% opacity 49 themes x 2 backgrounds x 2 opacity cases, 196 samples, transparent background and readable opaque glyphs retained; (3) real Glass sparkline/chart painter 49 themes x 2 backgrounds x 2 alpha cases, 196 samples plus boundary alphas, foreground charts independent of background and WCAG ink contrast; (4) native offscreen temporary child HWND UpdateLayeredWindow alpha upload PASS (exit code 0, no taskbar input). Each invoked the exact installed executable in isolated proof mode through Start-Process -Wait, with checked JSON proofs and file hashes; owner installed Main, config SHA256 3335F7BD254C48E88AA9C0F115EE54D03301E1DD421F45D2A8408634C7B8F182, foreground taskbar and the sole live owner PID 10892 unchanged. Receipt .local/audit/r380-owner-installed-glass-acceptance-20261110.json SHA256 4C3F0AF3C0ABCF02DFE89FE700708BC0B61BE38152967B0635A688B274AC3FCA. IMPORTANT SCOPE: Synthetic offscreen renderer and temporary native upload on real owner Windows PASS, but config GlassMode stays FALSE, so on-screen actual Glass, physical red alert/audio witness are NOT proven and those acceptance gates remain OPEN. No user sound played or Windows notification emitted. This was a local verification only; no new production change, public release, merge or Notion restore. PR #98 latest e8a3a14 is 29/29 CI PASS and zero human approvals.
- **R381 real owner Taskbar Glass compositor and sound endpoint (2026-11-10; direct installed v1.7.10 owner host PASS).** On user real 3440x1440 Windows desktop, executed the EXISTING public installed v1.7.10 Main (SHA256 715CDA5E666E12C5FF2BCD46D513467CCEFEABE43A76F77689F604D4F432F2D7) in isolated temporary --topglassliveproof mode; it produced 3 owner-private PNG pixel captures and two typed JSON receipts from a real WinForms OverlayForm attached at {X=436,Y=1392,Width=900,Height=48} on the native Taskbar without interacting with user input. Real text diff pixels 2,173, charts 2,446, 2 actual native layered uploads, expected 29,084 transparent pixels; result PASS. Four actual native opacity/mode transitions (30%,97%,100%,0%) ALL PASS, with restored zero-alpha glyph 2,211 and chart 2,446 pixels; all temporary proof resources removed by proof process and primary owner PID 10892 retained. Main/config SHA unchanged, config GlassMode=FALSE remains the user default. Separately called EXACT production API System.Media.SystemSounds.Exclamation.Play once in a synthetic audio test and measured Windows default multimedia render endpoint IAudioMeterInformation.GetPeakValue: preevent 0.0, event 0.3456726, 8 device channels; independent audio PCM endpoint output signal PASS, but NOT proof of hearing/speaker playback or per-app attribution. Audio was not generated by a hot-CPU event, notifications were not sent. Source Microsoft CoreAudio endpoint peak-meter and .NET SystemSounds docs justify measurement scope. Exact all-in-one local receipt .local/audit/r381-owner-native-glass-and-audio-acceptance-20261110.json SHA256 5A4211A939A1DEFA70233DE1BF29793B72320E37E7B95E3CBDD15EFC5421F10C, source JSON screenshot and sound hashes inside; private screenshots NOT published. No owner install, config, system policy, public release, PR merge or Notion restore. Accepted: owner-machine transient actual Taskbar Glass compositor and Windows audio-endpoint signal. NOT accepted: permanently enabled Glass user preference, human hearing/witness, historic R371 intermittent root cause or security human reviewer signoff.
- **R382 separate R371 Windows 2022 failures and owner-installed Settings accessibility proof (2026-11-10; historical negatives remain NON-PASS).** Independently recovered BOTH original, same-name but distinct GitHub Action run 42651408908 Windows 2022 native guest artifacts by immutable IDs 13690047155 and 13691325294, preserving original ZIPs, raw R291_NATIVE.json and exact SHA-256. First rerun (artifact 13690047155) failed in glass0 before Settings menu ready: R146_REAL_SETTINGS_MENU_ITEM_NOT_FOUND after 5046ms, foreground PID 6572, product PID 1624; 24 native evidence records. Second rerun (artifact 13691325294) got through visible Settings, real Start and fullscreen return but FAILED glass0 strict 1100ms native Taskbar-hide invariant R146_MONITOR_IGNORES_TASKBAR_HIDE, with 32 native evidence records. Both same product Main SHA BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6 and Setup SHA 2B7A2941F3F489196601F8CFF04711C8E5DA65FC12F24394B60C280FA8954547. Original source commit 31ea1c3d3a1da67920f4692eff76d240e278578f clicked a fixed x+40, y+height/2 pixel; later R372 added actual WindowFromPoint overlay hit-test and opaque-glyph fallback. Microsoft Win32 layered-window docs confirm alpha-zero pixels let pointer events pass through, but original failing guest did NOT record WindowFromPoint at click, and two successful subsequent R373 glass0 runs DID hit the overlay with the fixed point, so this is a plausible hypothesis, NOT proven R371 root cause. Existing production VisibilityWatchdog uses a 500ms WinForms timer; official Microsoft docs say tick delivery can be delayed by UI message-pump work, so the original 1100ms hide failure also remains unexplained, with no captured old tick timing. No source or acceptance threshold changed. Separately executed the exact PUBLIC owner-installed v1.7.10 --settingsproof on private offscreen Windows forms; nine actual settings pages saved as 9 private PNGs, 73 interactive accessibility controls with 0 missing names, 152 High Contrast controls with 0 style gaps, native actual-taskbar theme preview renderer, PASS. Current owner PID 10892, binary SHA 715CDA5E666E12C5FF2BCD46D513467CCEFEABE43A76F77689F604D4F432F2D7 and config SHA 3335F7BD254C48E88AA9C0F115EE54D03301E1DD421F45D2A8408634C7B8F182 remained byte-identical. This is NOT a physical Settings foreground test. Typed private aggregate evidence .local/audit/r382-historical-2022-negatives-and-installed-settings-proof-20261110.json SHA256 41B51CFB405DF874B6F0B2889B9C8E2FFCAA8A3B3DDAEF41E92EED2595219117. Historical negatives retained; no CI rerun without new discriminating hypothesis, no public release, Notion restore or Merge.
- **R383 late upgrade-stage unindexed-file preservation (2026-11-10; engineering + local + hosted PASS).** During read-only technical analysis from the now-connected reviewer laptop, the R379 CleanOwnedStage source was found to scan exact known file/directory names before calling Directory.Delete(UpgradeRoot,true), which could recursively delete a late unindexed file created after preflight. Disposable owner-local .NET method/canary test reproduced the failure. Scoped production source commit 52f396774829379e9552da4a1bb0fa7432074ece removes only allowlisted files then known empty directories deepest-first using Directory.Delete(directory,false), refusing unknown late entries. The unchanged, exact original R379 source method was compiled with TEST-ONLY postscan canary injection and proved deletion; the new exact method compiled with the same test-only injection preserved the unknown canary and rejected nonempty root. Local native R370 baseline 2/2, Candidate 8/8 including previous hardlink, phase, empty-directory, junction checks, full Main/Broker/Supervisor/Setup build with zero warnings/errors and 3 workspace selftests PASS; private Setup /verify 25 embedded resources PASS and Main hash BAB436ACD0C531DE04DD6BF21B8A4D015F29529798997BEA1931B6FECD8803B6. Engineering source SHA256 B4DA1F7598F02B38D7058078F30F4E80C65F04040BD887D6C3FC6F34447738DE; Windows local test SHA256 86989CFD18446D4BD4002FF22A6D96639350A302F4143B92AEAC609CC58F44CD. First source push 52f3967 hosted R370 Candidate runs FAILED because source checkout was shallow, and git show for immutable 5dd6bd9 old-method negative control was unavailable; these failure receipts remain historical NON-PASS. Workflow-only follow-up commit 04ca64383dabdba6282407b503b4c09b93640276 set candidate/baseline source fetch-depth 0 while retaining exact SHA and no persisted GitHub credentials; same executable/test blobs. Both new Windows 2022/2025 push run 42783879916 and PR run 42783887647 R370 matrices 8/8 passed with all 8 typed raw receipts downloaded and SHA-checked, baseline 4 and Candidate 4; exact head 04ca643 CI **29/29 PASS** including real R291 Start/Settings jobs. Aggregate owner-local evidence .local/audit/r383-hosted-acceptance-exact-head-20261110.json SHA256 4F56BB155652731535344CE107F7C31F18C841AE82A0DBF55C89131B9542625A; reviewer Linux host AI-assisted static audit 15/15 checks and 39 PS scripts parse PASS (NOT independent human signoff), receipt SHA256 3899B3B2A9750B7FE136F1ABE2320311D0B475C4E608553A54E041A2A5FA8227. Claim boundary: same-user static/late unindexed member preservation, not universal atomic immunity to concurrent directory-swap/reparse races. Owner v1.7.10 binary/config/PID and public immutable release unchanged, NOTION restore not consented, no merge.
- **Gate graph / next action (2026-11-10; R384 source and current exact-head hosted acceptance PASS; independent review BLOCKED).** Engineering source f59e1dc (current documentation-only PR head 581d46a) has local baseline 2/2 + Candidate 10/10, zero-warning full build, 3 selftests, Setup /verify 25/25; source-head CI 63/63 and current PR-head CI 29/29, R370 push+PR 8/8, R360 6/6 real UI cycles and 24/24 hide samples, R299 public v1.7.9 in-place upgrade and R300 fresh install PASS with exact candidate Setup bytes. Main blocker is genuine independent human security review for PR #98 at current head 581d46a (requested reviewer remains, zero submitted reviews). Reviewer-host 14/14 static and 39 PowerShell parse checks are AI-assisted, not human approval. Historical R371 Windows 2022 glass0 failures remain NON-PASS/unproven despite new R360 success; Issue #6 still awaits reporter driver SHA/provenance; physical owner foreground Settings witness and human audio hearing remain separate acceptance gates. Notion R359 restore/sync remains blocked pending explicit user confirmation. Do not merge or alter public release until human review and remaining gates are resolved.

<!-- TBME:R307_R347_R349_SECURITY_FORWARDPORT:END -->

<!-- TBME:R306_R338_SUPERVISOR_ARGV_CANDIDATE:BEGIN -->
## R306 — R338 Supervisor trusted-argv forward-port candidate

- Verified 2026-11-08T06:15:13.3078879Z. Starting from current immutable main baseline 035e8fc5db2fc020e539ec930a10770b9807d318, the exact compiled original Supervisor PE SHA-256 0E28911AACDE0C3B1C6997C8BC6FF141C0FAA650B58438A9991CB3AD6C13C785 reproduced acceptance of a foreign --broker, foreign --output, and unexpected extra flags in a 3-check reflection-only proof. No Broker process was started; the external canary remained byte-identical.
- Isolated forward-port changes only src/sensors/TaskbarMonitorSensorSupervisor.cs, build/Test-R338-SupervisorTrustedArgs-Native.ps1, and .github/workflows/audit-r338-supervisor-argv-trust.yml. Candidate commit 9394071f9bf922165ca3282c45d4e4408dd12dc3 is on security/r338-supervisor-trusted-argv-v1710; PR #96 is OPEN, READY FOR REVIEW, mergeable, and not merged.
- Production parser now requires exactly four tokens and the two supported flag/value pairs, rejects null/empty, duplicate, unknown, truncated and extra arguments, and derives Broker/output paths only from the running image directory and OS-known ProgramFiles/UserProfile/LocalAppData. UNC and reparse-point components fail closed. A redirected LocalAppData on another local volume is accepted; UNC profile/LocalAppData is intentionally unsupported for this high-integrity worker path.
- Scope is explicitly limited: path/reparse checks are not an atomic rename-race or hardlink lease. This PR does not claim to close those separate LocalAppData file-operation risks. The existing PR #80 helper/broker security work remains separate.
- Local compiled candidate Supervisor SHA-256 1768789EA1C2D9B79A0B34B06276E7F32AAFDA11BC158EED6EA62DA448E852FB; 16/16 native contract checks PASS: canonical paths, local LocalAppData redirection, UNC rejection, hostile/malformed argv, output escape, real Windows broker junction refusal, recovery after junction removal, and unchanged external canary. No Broker process was started.
- Full local build/Build.ps1 -NoDownload PASS for App, Broker, Supervisor and Setup: zero warnings/errors; selftest, feature-contract-selftest and workspace-selftest all PASS. The final source delta after this local build was a comment-only clarification of the non-atomic/non-hardlink scope; the exact final PR commit then passed the hosted Build and Verification workflow.
- Read-only owner task inspection confirmed an interactive scheduled task with RunLevel Highest and exact canonical ProgramFiles Broker path plus LocalAppData CPU telemetry output matching the new accepted contract. This is configuration observation only, not candidate installation or process execution.
- Hosted checks completed successfully on exact PR head: R338 baseline/candidate Windows 2022/2025 matrix 4/4 PASS (run 42453276323); Build and Verification 4/4 PASS including original Setup upgrade, fresh install and R298 cleanup (run 42453276343); R290 native Win32 Z-order 2/2 PASS (run 42453276421); R291 real Explorer Start/Settings/Glass 2/2 PASS after retry (run 42453276218). The first Windows 2025 R291 attempt transiently failed glass0_TASKBAR_REAPPEARS; its rerun passed, and Windows 2022 passed on its first attempt. Preserve this as a flaky UI observation, not an R338 regression attribution.
- R356 pinned-directory deletion is already in current main through R298; do not re-port. The broad PR #80 remains based on v1.7.8 and must not be merged wholesale. Other R347/R349/helper hardening remains separate pending review/forward-port.
- Owner device remains unchanged: installed version 1.7.9; Main PID 21116 remains running in Session 2. Fresh R303 preflight PASSes its baseline but reports RUNNING_PROCESSES=1 and SAFE_TO_APPLY_NOW=False; the immutable official v1.7.10 Setup SHA-256 remains 1D0326CF11CEE069AD295112A9CA49D9FCBDB58ECDAB46FFE9C0F7172CE26D7E. User configuration content was not read.
- Current GUI policy still reports explicitTakeoverRequired=true, workflowTakeoverAllowed=false, ownerAuthorizedTakeover=false. No mouse/keyboard, focus, WM_CLOSE, process termination, or installer action was attempted. Personal upgrade and dynamic Start/Settings/Glass acceptance remain OPEN. Issue #6 remains OPEN awaiting the original reporter's driver SHA-256 and download/install origin.
- Exact next actions: obtain independent security review for PR #96; for owner deployment, obtain current explicit GUI takeover authorization or have the owner use the normal app context-menu Exit, rerun guarded R303 preflight, and invoke /update /quiet only when SAFE_TO_APPLY_NOW=True. Do not merge or publish new release bytes before independent review.
<!-- TBME:R306_R338_SUPERVISOR_ARGV_CANDIDATE:END -->

<!-- TBME:R305_OWNER_RUNTIME_AND_BRANCH_RECONCILIATION:BEGIN -->
## R305 — owner runtime and repository continuation check

- Verified 2026-11-08T04:58:45.9354472Z on the owner Windows 11 session as a read-only follow-up to R303/R304. No product source, user preference, or installed file was changed.
- Guarded R303 preflight remains PASS: the official v1.7.10 Setup SHA-256 matches the immutable release; installed v1.7.9 Main/Setup match the pinned predecessor. The preflight reports RUNNING_PROCESSES=1 and SAFE_TO_APPLY_NOW=False; no /update was invoked.
- One installed v1.7.9 Main, one Sensor Supervisor, and two Sensor Brokers remained present in owner Session 2. This is a process-presence snapshot, not a new sensor functional acceptance.
- In the sampled last 500 lines of the active application log, 12 CPU threshold-notification events were each paired with TEMPERATURE_WARNING_SOUND_REQUESTED; this proves application-side requests only, not an OS banner or audible physical speaker. Eight TASKBAR_ZORDER_OCCLUSION_REPAIR records all reported stillCovered=False and error=0. There were zero actual [ERROR] or [FATAL] severity records in that sample; error=0 is a success field, not an error-level log.
- The separate current-day proof log still contains TRAFFIC_HISTORY_READ ArgumentException and TRAFFIC_HISTORY_WRITE IOException warnings after OVERLAY_CLEANUP reason=DISPOSE userExit=False; the existing R303 record attributes these to intentional negative test fixtures. No new evidence links them to user data corruption.
- Read-only Win32 enumeration again found the taskbar overlay and hidden app-owned windows, while MainWindowHandle=0. Native workspace observation returned WORKSPACE_DRIVER_UNAVAILABLE; target lease returned WORKSPACE_TARGET_WINDOW_CHANGED_OR_MISSING. Current GUI policy still reports workflowTakeoverAllowed=false and ownerAuthorizedTakeover=false. No focus change, raw input, WM_CLOSE, process termination, or installer action was attempted.
- git fetch --prune origin reconciled the repository refs. Local main is clean and equals origin/main at ef4653188e9cf4cb8c72f3536fccaf0b45837773. The only non-main remote branches are development/v1.7.9-zorder-fix and pr80-security-review; both contain unique commits not merged into main and were preserved. The merged R304 documentation branch is absent locally and remotely.
- Product release acceptance remains complete for public immutable v1.7.10. Personal owner upgrade and dynamic Start/Settings/Glass witness remain open. Issue #6 remains open pending the original reporter's flagged driver SHA-256 and download/install origin. Physical AC interruption remains owner-excluded; the unsigned-release waiver is unchanged.
- Exact next action: owner performs the application's normal context-menu Exit; then rerun the guarded R303 preflight and invoke /update /quiet only when SAFE_TO_APPLY_NOW=True. Verify same-root installation, configuration/backend/startup preservation, and reopen the app before any personal UI acceptance. Do not bypass the GUI guard.
<!-- TBME:R305_OWNER_RUNTIME_AND_BRANCH_RECONCILIATION:END -->

<!-- TBME:R303_OWNER_HOST_READONLY_PREFLIGHT:BEGIN -->
## R303 - owner computer release-PE verification and unresolved personal interaction gate

- 2026-11-08T03:46:07.1871975Z: source Git main f4154e44caeb724e004b73a91dd4e4bd1a9e4176, release v1.7.10 tag 6effbb8083615f5673f6df22a3b0782b33595ad3. Public immutable release, CI and seven assets already accepted under R301; no change to published files.
- Local, read-only execution of exact released Setup 1.7.10 /verify /verifyfile in the personal Windows session PASS: 25 embedded resources, expected Main SHA256 715CDA5E666E12C5FF2BCD46D513467CCEFEABE43A76F77689F604D4F432F2D7, PawnIOBundled=false; project-local receipt .local/audit/R303_OWNER_PC_RELEASE_SETUP_VERIFY.json SHA256 8F332CC62BBF72076B2ED60D9FA17F7C9C144D51FE6724E70E603E2747BED53B. User installed v1.7.9 Main/Uninstall and running process unchanged. Official release tag fetched and checked locally without branch mutation.
- Live Win32 read-only window traversal found the current overlay hwnd 132402 directly parented to Explorer Shell_TrayWnd hwnd 65892, visible within taskbar bounds (both HWNDs ephemeral; not stable IDs). No standalone owner-controlled top-level application window was returned by Remote Commander. Provider workspace_agentos_plan BLOCKED SEMANTIC_PROVIDER_UNAVAILABLE and workspace_window_observe refused WORKSPACE_DRIVER_UNAVAILABLE. GUI policy explicitly disallows takeover without current attestation. Do NOT bypass with raw WM_CLOSE, SendInput or injected shell control.
- Real owner application source has normal context menu Exit handler (UserExitRequested=true; Close()), but actual Setup UpgradeExisting calls EnsureAppNotRunning and rejects any still-running Main without mutation. Therefore installation cannot safely proceed until normal in-app Exit is triggered by an authorized owner UI or an attested GUI control provider. This is a genuine personal-device dependency, not a failed hosted upgrade.
- Active owner log sample: no ERROR among last 800 entries; 17 CPU temperature warning events paired with sound requests, but red Glass rendering not physically witnessed. User config RecordTrafficHistory=false, no installed traffic_history.json. TRAFFIC_HISTORY_READ ArgumentException and WRITE IOException in separate short-lived daily test log match expected intentionally malformed/unwritable TrafficLedger negative fixtures in WorkspaceSelfTest; do not misclassify as active user data corruption.
- Scoped current host vulnerable-driver investigation: no exact service R0TaskbarMonitor, WinRing0 or WinRing0x64, no reported legacy C:/Program Files/TaskbarMonitor/TaskbarMonitor.sys, current source/installer direct string hits zero, and PawnIO service running. Issue #6 https://github.com/GOD13emad/TaskbarMonitorEnhanced/issues/6#issuecomment-6716850981 remains OPEN: original reporter path, SHA, Defender state and provenance not proven. Do not claim security clearance or false positive.
- Existing private Notion coordination mirror synchronized: https://app.notion.com/p/412d5b4a86f681c29173c01fc4c75842. No second technical authority.
- Next acceptance: owner uses normal app context menu Exit, or an attested same-session semantic provider with permitted input; perform exact SHA-pinned /update /quiet and verify registry/user config and sensor canaries, then re-open and physically witness Start/Settings/Glass without another forced process termination. RELEASE_FINAL=PASS; OWNER_DEVICE_FINAL=PENDING.
<!-- TBME:R303_OWNER_HOST_READONLY_PREFLIGHT:END -->

---

<!-- TBME:R301_IMMUTABLE_PUBLIC_V1710_RELEASE_VERIFIED:BEGIN -->
## R301 - Official immutable v1.7.10 published, G16 public seven-asset verification PASS

- Verified at 2026-11-08T03:27:36.7584507Z: public Latest immutable GitHub Release https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.7.10 (Release ID 438006233), published 2026-11-08T03:24:15Z; exact tag/manifest/source commit 6effbb8083615f5673f6df22a3b0782b33595ad3. Prior immutable v1.7.9 remains untouched.
- Public distribution: exactly ONE unsigned TaskbarMonitorEnhanced_Setup_1.7.10.exe (8,613,376 bytes; SHA256 1D0326CF11CEE069AD295112A9CA49D9FCBDB58ECDAB46FFE9C0F7172CE26D7E), source ZIP of 395 tracked files, SPDX 2.3 SBOM, release notes, acceptance scope, checksum list and manifest: 7 public assets total. Get-AuthenticodeSignature was NotSigned. Previous owner unsigned approval was reused transparently, not replaced with a fabricated certificate or personal approval for this version.
- Actual online, independent G16 proof downloaded and SHA-verified all seven public assets; manifest payload entries 5, checksum entries 6, immutable tag and source matched GitHub Main CI 42441872706, SUCCESS on exact 6effbb8. Receipt .local/R301_G16_PUBLIC_v1710.json SHA256 D1A741F2A1EE8C04612D9E4FDDD02B5FD1655005628B782064556D18BCB8A1A2. Scope: public package integrity, not a malware or exhaustive crash clearance.
- Real disposable Windows GitHub-hosted CI: source PR #89 final run 42440771969 all four jobs SUCCESS (reproducible build, actual fresh 1.7.10 Setup, public SHA-pinned official 1.7.9 -> 1.7.10 /update with forced two-file COMMITTING crash recovery, native deferred-uninstall/Junction safety), merged product source main 90180fe8fd414b56ee49229c9954ea37c0235585. Version-locked R289/R290/R291 jobs were diagnosed at 1.7.9 preflight rather than falsely accepted as behavior failures; PR #91 migrated R290/R291 to current version and retained R289 on the historical branch. Source final main 6effbb8083615f5673f6df22a3b0782b33595ad3.
- Exact final postmerge main CI 42441872706 ALL FOUR SUCCESS; hosted Win32 Z-order Windows 2022 and 2025 CI 42441872732 SUCCESS; real isolated Explorer Start/Settings/Glass Windows 2022 and 2025 CI 42441872710 SUCCESS. All evidence belongs to these hosted, scoped environments.
- A concurrent verified publisher created immutable public Release assets while this R301 audit was running; no duplicate upload/publish was attempted. Release 438006233 content and all hashes match the locally verified seven-asset staging receipt. Local main and personal owner install were not mutated by publishing.
- Owner PC remains running the exact original official v1.7.9 Main SHA256 04776E870A492733BBA33A550F732F5DB688A6585FC6533224A56687F1A6D88E and Uninstall/Setup SHA256 3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E; no live owner upgrade and no owner taskbar/GUI takeover performed. The user-directed personal Start/Settings/Glass dynamic transition is still OPEN; Issue #6 still needs original reporter hash/origin, physical power loss excluded by owner, and Notion project target not verified (similarly named TandemVector repository is NOT this repository).
- Next safe action: owner-directed normal application exit and one-installer in-place update only when the personal GUI/upgrade acceptance can be witnessed. Never force-close owner process, downgrade public immutable v1.7.9, or silently alter config. FINAL system-wide claim remains conditional on personal dynamic witness.
<!-- TBME:R301_IMMUTABLE_PUBLIC_V1710_RELEASE_VERIFIED:END -->

---

<!-- TBME:R299_OFFICIAL_V179_TO_V1710_HOSTED_UPGRADE_RECOVERY:BEGIN -->
## R299 - Official v1.7.9 to unreleased v1.7.10: hosted real-Setup upgrade and crash recovery

- 2026-11-08T02:35:47.3835692Z: Candidate draft PR #89 https://github.com/GOD13emad/TaskbarMonitorEnhanced/pull/89, exact tested HEAD 2f23541bc6599f8ad5f44b727fe540fcf5c28309, based on accepted main 326523274e5a90ed44226bbf75f9ba4e8984b5a0. This is a scoped candidate, NOT a public release or personal Windows upgrade.
- Original immutable public 1.7.9 installer is 8,577,536 bytes and SHA256 3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E; original Main SHA256 04776E870A492733BBA33A550F732F5DB688A6585FC6533224A56687F1A6D88E. Exactly 21 original Setup embedded resource hashes plus original Setup itself matched 22 installed managed files. Owner local read-only proof .local/audit/r299-v179-managed-pins-verified.json SHA256 12C4C9B78BA270809257CA5EC138401A4A9F424B492E2386E6590F4E91267FB8. User config not read by the inventory.
- Candidate 1.7.10 includes the R298 reviewed handle-pinned native deferred uninstall, exact public 1.7.9 predecessor 22-file hashes and identity guards, one-root in-place upgrade journal, transactional release-notes replacement and idempotence. Local Build, native junction refusal, 5 predecessor identity negatives, SBOM and R273 hostile metadata tests passed. Historical broad PR #80 remains unmerged.
- GitHub Actions https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42437886140 at exact head 03931cfe1c0fcd3f73a381212edfbd2d2ec3698d completed SUCCESS for all 3 hosted Windows jobs: Build/Determinism/G13-G16/Glass/Settings/Runtime/SBOM; pinned original Setup native delete/junction; independent real original Setup v1.7.9-to-1.7.10 /update /quiet on a fresh synthetic guest. Edited predecessor refused before mutation, external canary, user config, sensor backend, startup and registry preferences preserved; second update idempotent. Hosted artifact r299-public-v179-upgrade-receipt.
- Stronger GitHub Actions https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/42438736122 at exact head 2f23541bc6599f8ad5f44b727fe540fcf5c28309 completed SUCCESS for all 3 Windows-hosted jobs. On the fresh synthetic guest a separately spawned test child staged exact compiled Setup files and physically swapped two managed files with COMMITTING journal. Parent verified child PID, commit, stage and SHA values, then forcibly terminated only that owned synthetic child. Actual compiled candidate Setup recovered the interrupted journal then upgraded in-place; log proof R299_HOSTED_ABRUPT_TWO_FILE_COMMITTING_RECOVERED_BY_REAL_SETUP=PASS. User config, sensor backend, autorun and external canary were preserved; second update idempotent. This is TWO-MANAGED-FILE COMMITTING coverage, not exhaustive interleaving or real personal GUI acceptance.
- First crash-test harness failed before arming due to PowerShell 5.1 null File.Replace binding. The tested C# bridge replaced the test invocation only; product source unchanged. Owner v1.7.9 Main and Uninstall.exe hashes, current installation, settings and immutable seven public release assets unchanged. Candidate Draft is NOT merged or published. Owner physical Start/Settings witness remains blocked by non-attested GUI provider; Issue #6 reporter hash/origin and Notion sync quota remain external blockers.
<!-- TBME:R299_OFFICIAL_V179_TO_V1710_HOSTED_UPGRADE_RECOVERY:END -->

---

<!-- TBME:R298_PINNED_UNINSTALL_FORWARDPORT_CANDIDATE:BEGIN -->
## R298 - Hosted-tested future-version uninstall security candidate, NOT in public v1.7.9

- Evaluated at 2026-11-08T01:32:06.2390949Z: isolated draft PR #87 (https://github.com/GOD13emad/TaskbarMonitorEnhanced/pull/87), exact review head dc7e52e5679b5fdcec8e082af79a90a0999f5824 and accepted base main a07542f4fc02abfa40c3e1d40c707f04e89bfaa6. Only the deferred user-root uninstall cleanup in installer/TaskbarMonitorEnhanced_Setup.cs, a native local contract test, a hosted-only actual-PE fixture test and scoped CI wiring changed. Older 89-file PR #80 remains separate, unmerged.
- R298 replaces a mutable Temp batch-file cmd / rmdir cleanup with the earlier reviewed R356 handle-bound SetFileInformationByHandle(FileDispositionInfo) empty-directory deletion primitive. Identity policy includes canonical owner LocalAppData, SID, exact parent PID/start-time, rejection of reparse entries, final path from native handles and bounded in-memory native PowerShell. Official Microsoft CreateFileW and SetFileInformationByHandle contracts were consulted for directory and DELETE access permissions.
- Local only: exact-source modified Setup Build.ps1 -NoDownload PASS; original Setup embeds the modified C# source; PowerShell 5.1 factory argument validation, script parsing, native Add-Type, disposable empty-directory pin/deletion and external Junction/canary rejection all PASS. Candidate Setup SHA256 43B286D4B8114CD99A4E44FFDFF69CA3D67596E349A0D83DF1FD687C1018793C, distinctly NOT the immutable official public v1.7.9 installer.
- GitHub-hosted CI 42434200493 completed SUCCESS for both independent jobs. First job: full reproducible Build, deterministic clone, G13-G16, Native R298, 49-theme Glass thermal/UI settings, Sensor/PawnIO contract, runtime, Release manifest and SBOM PASS. Second fresh GitHub-hosted Windows job: no installed product/path/task/process preflight PASS, exact Setup artifact SHA matched Build Manifest, original compiled PE cleanup waited for test-owned parent to exit then deleted synthetic owner-only directory; a separate Junction to outside SHA-pinned canary was refused and outside bytes remained unchanged. No real owner uninstall was invoked. First same-job End-to-end attempt failed safely on an existing root created by Build workspace tests; it was fixed with a completely fresh runner, never by deleting existing data.
- Main/public state remains fixed: official immutable v1.7.9 source commit 479ee78a214c7ae58177016d59468e50e815f54b, seven release assets, owner-installed Main SHA256 04776E870A492733BBA33A550F732F5DB688A6585FC6533224A56687F1A6D88E and owner Uninstall/Setup SHA256 3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E remain unchanged.
- Acceptance boundary: R298 is a tested source candidate only. Do NOT merge or publish different bytes as public v1.7.9. Before promoting it, allocate a maintenance version, review compatibility with additional historical PR #80 hardening, and verify official v1.7.9 to new version in-place upgrade plus crash/recovery with separate pinned receipts. Real personal Start/Settings/Glass user-interaction witness remains open under current non-attested GUI provider; reporter issue #6 needs external original evidence. Notion sync still limited by the workspace quota. Signing waiver and physical AC-test exclusion remain unchanged.
<!-- TBME:R298_PINNED_UNINSTALL_FORWARDPORT_CANDIDATE:END -->

---

<!-- TBME:R297_HISTORIC_RC6_PRIVATE_ARCHIVE:BEGIN -->
## R297 - Verified private archival of historical RC6 CI scripts

- 2026-11-08T00:50:43.2166301Z: 25 RC6 and 5 miscellaneous original September 2026 scripts verified against November 6 manifest bytes and SHA-256 (30/30 PASS). Original loose script root paths remain absent 30/30. A bounded common token-pattern inspection found no credential fingerprints; this cannot prove total absence of secrets. No historic script was executed.
- The two complete folders moved on the same disk into the existing ignored local owner history at .local/history/legacy-rc6-ci-probes-20260919/rc6 and .local/history/legacy-rc6-ci-probes-20260919/misc. Their original manifest and README content was preserved and reverified. This R297 destination supersedes only the historic November 6 staging path in docs/project-control; the historical notes below remain unchanged.
- These old executable workflow/runner probes are PRIVATE LOCAL historical data, not active source, build helpers or technical authority. They are intentionally excluded from public GitHub source. Official immutable v1.7.9 Release, user installation, settings and live processes were not modified.
- Personal GUI Start/Settings dynamic transition is still unverified: Win32 read-only Z-order sampling found one visible Main overlay HWND before Shell_TrayWnd in taskbar bounds and a hidden app Settings HWND. This is only the static visible state, not a Start/Settings activation test. The current GUI backend retired legacy input and its native semantic provider did not attach to this window; no unsupported synthetic input was attempted.
<!-- TBME:R297_HISTORIC_RC6_PRIVATE_ARCHIVE:END -->

---

<!-- TBME:R295_IMMUTABLE_PUBLIC_V179:BEGIN -->
## R295 — Immutable public 1.7.9 released with independent seven-asset download verification

- GitHub official public release [v1.7.9](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.7.9) ID 427321765, published 2026-10-29T00:04:14Z, immutable=true, draft=false, prerelease=false, source commit 479ee78a214c7ae58177016d59468e50e815f54b. Public Latest is v1.7.9 and previous immutable releases remain unchanged.
- The scoped one-shot release workflow 40791419343 at branch release/v1.7.9-publication-r295 built exactly source 479ee78 (not the release helper branch), passed negative G16, deterministic Build, SBOM and exact Main/Setup digest checks, staged seven assets, published using repository GITHUB_TOKEN contents:write, and completed public-downloaded G16 PASS. Workflow status completed/success.
- Independent second G16 audit on the owner Windows host downloaded all seven public assets, compared public GitHub digest, manifest, SHA256SUMS and main CI: PASS_PUBLICATION_CONTENT_ONLY. Evidence .local/r295-public-g16-independent.json SHA256 BF6DBCF33ED9F7B98E010E6EB5941FF18AE5C19FFDC1D101935ABA74D8ABAEAA. Actual public Setup SHA256 3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E; matches installed maintenance and private owner-accepted exact Main SHA256 04776E870A492733BBA33A550F732F5DB688A6585FC6533224A56687F1A6D88E. Note: source zip and SBOM digests of GitHub runner packaging differ from older local staging due to tool-run generation; the public seven-asset manifest and downloaded bytes are self-consistent and separately verified.
- Public GitHub Issue #7 existing tracker semantic-upsert R295 completed with latest release, hashes, CI, limitations and preserved historical R287/R285 sections. No release tag rewrite or obsolete asset deletion.
- Owner install from R294 remains version 1.7.9, one user-session Main, sensor Supervisor/Brokers active, protected config and startup preserved and no incomplete journal. Separate owner interactive Windows 11 Start/Settings overlay dynamic transition was NOT witnessed by session-0 read-only GUI policy; hosted Windows native tests passed but are scoped to hosted environment, so personal GUI acceptance remains open. Older embedded installed RELEASE_NOTES_v1.7.9.md saying UNRELEASED is a release snapshot defect; public RELEASE_NOTES_v1.7.9.md accurately marks staged candidate at construction, immutable public release endpoint is current authority. Do not patch managed installed files behind Setup.
- Connected Notion Project Planner sync creation attempted. Notion returned entitlement_required: workspace has exhausted free block quota; no side effects, no page created. The matching existing TandemVector-Labs registry entry is unrelated and was deliberately not overwritten. NOTION_SYNC_PENDING_FREE_BLOCK_LIMIT, not release blocker.
- Security reporter Issue #6, independent physical audio/OS banner witness and personal dynamic Start/Settings remains open as externally scoped. Physical AC test and signing remain explicitly excluded. Public per-user unsigned v1.7.9 package release is COMPLETE, but whole-project FINAL requires separate acceptance of remaining mandatory user GUI behavior.
<!-- TBME:R295_IMMUTABLE_PUBLIC_V179:END -->

---

<!-- TBME:R294_OWNER_UPGRADE_AND_RELEASE_CANDIDATE:BEGIN -->
## R294 — Real owner v1.7.8 to v1.7.9 upgrade PASS; prepublication asset content verified

- The owner closed the previously running 1.7.8 normally. A one-shot Task Scheduler InteractiveToken user task ran official SHA-pinned 1.7.9 Setup /update /quiet in owner Session 1. Two predecessor helper attempts failed safely at PREFLIGHT due PowerShell alias H -> Get-History, before Setup was invoked; they were reconciled and separate receipts retained locally. A corrected third attempt completed with Setup exit 0.
- Evidence: .local/audit/r294-owner-upgrade-attempt3-receipt.json SHA256 4A95D788BBD8CD1C5FD55D03C5703B69C2DDCEA71854F07C7A66230628E764EF. Installed Main SHA256 04776E870A492733BBA33A550F732F5DB688A6585FC6533224A56687F1A6D88E; installed Uninstall/Setup SHA256 3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E. Registry, install_state, prior config/config.bak, autostart preference and sensor backend preservation PASS. No journal; one responding Main in user session and original sensor topology running. The one-shot task was unregistered after PASS.
- Exact GitHub main commit 479ee78a214c7ae58177016d59468e50e815f54b rebuilt in a temporary detached clean worktree with pinned dependencies; 0 errors/warnings, 3 workspace tests, deterministic build and SBOM all PASS. All five runtime output hashes match the previously verified candidate and owner installation. Temporary worktree was removed after preservation of release assets.
- Seven locally staged assets: .local/r294-v179-release-assets, including one Setup, exact-main public SOURCE.zip, SPDX SBOM, accurate release notes, manifest, SHA256SUMS and scoped acceptance record. SOURCE.zip SHA256 B46441B0D7636BF28AE99C3ECF6907C10A332BD69DABF8658817DB6DCEEE820A; manifest SHA256 0598D20173610D4089B91FFDE5E252CA1D32A183B96A7F4D0DDA578523086CFF. G16 validate_public_content PASS only against synthetic prepublication metadata, NOT public-GitHub asset download verification.
- The live current 1.7.9 app startup log confirms overlay HWND/taskbar attach, temperature brokers ready and no recent app ERROR/FATAL following 03:00 startup. Traffic-history WARN logs at 03:02 coincide with workspace self-tests that exercise malformed/unwritable history, not yet evidence of an owner persistent data fault; current RecordTrafficHistory=false. User-selected GlassMode=false and opacity=0.01 were preserved, not changed.
- Still OPEN: user-session Windows 11 Start/Settings/Glass dynamic interaction acceptance (read-only GUI connection cannot inject input); public v1.7.9 GitHub release creation/asset upload and live seven-asset G16 remain unexecuted because local gh token is invalid and connected GitHub app does not expose release creation/upload. Public Latest remains v1.7.8. Signing waiver and exclusion of physical AC interruption unchanged.
- Notion project sync PENDING: the sole TaskbarMonitorEnhanced title in the connected registry maps TandemVector-Labs, not canonical GOD13emad. It was not changed.
- No public GitHub release and no project-wide FINAL asserted. Priority next: native owner interactive Start/Settings witness -> authenticated official immutable v1.7.9 release of the seven staged assets -> independent real public download digest G16 -> correct-scope Notion sync.
<!-- TBME:R294_OWNER_UPGRADE_AND_RELEASE_CANDIDATE:END -->

---

<!-- TBME:R293_OWNER_DEPLOYMENT_READINESS:BEGIN -->
## R293 — Owner predeployment recovery and user-session execution verified; install/release not accepted

- Main exact 479ee78 and nine hosted CI jobs PASS remain current. Local v1.7.9 Build PASS 0 warnings/0 errors; selftest, feature-contract, workspace and repro-build PASS; actual Setup /verify Process.ExitCode=0.
- Setup SHA256: 3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E. The owner still runs official 1.7.8 Main SHA A3E9ABD7E97655AD6787B71239505F30A7C0350B77F352DE4DE83461CD170D31. No owner install mutation.
- A temporary least-privilege InteractiveToken task successfully ran in owner Session 1 under the exact logged-on user; its exit status was 0 and the task was deleted. Evidence: .local/audit/r293-owner-session-probe.json. This proves a user-local headless path without taking over desktop input.
- A private rollback archive of 22 SHA-pinned official v1.7.8 files and 3 protected user files was built, read back and verified 25/25; .local/recovery/owner-v178-pre-v179-managed-25.zip SHA256 3EB575535F250952419572958C4634DCC9BB9EDE47D38CA8ADD47D0F6E2078A5.
- Owner live upgrade remains OPEN: the only running main app is in Session 1 and has no MainWindowHandle. Installer deliberately rejects updates while it is running. No forced termination, raw GUI injection, session-security workaround or invalid SYSTEM-profile install attempted. Next user action: normal Exit from product tray icon; then run SHA-checked Setup /update /quiet via owner InteractiveToken and verify installation, settings, health and Windows 11 visual behavior.
- Official GitHub public Latest remains v1.7.8. Host gh token is invalid and push dry-run cannot authenticate; connected GitHub tool lacks Release creation/upload. Public release is NOT completed. Signing waiver and excluded physical AC test remain unchanged.
- Notion catalog title match belongs to a different TandemVector-Labs repository; no unrelated Notion record was edited. NOTION_SYNC_PENDING for the correct GOD13emad project page.
- Microsoft Learn SetWindowPos documents Windows session isolation; Task Scheduler InteractiveToken provides a supported already-logged-on-user route. CI hosted Start/Settings evidence is not personal Windows 11 acceptance.
<!-- TBME:R293_OWNER_DEPLOYMENT_READINESS:END -->

---

<!-- TBME:R292_MAIN_INTEGRATION_AND_NATIVE_EXPLORER:BEGIN -->
## R292 — Official main SOURCE integration complete; nine hosted CI jobs passed

GitHub PR #83 was merged via squash at 1fa4ddb657f62671bbb2aa000826a9a88723251f.
Follow-up main commit 479ee78a214c7ae58177016d59468e50e815f54b
retired obsolete v1.7.8-only R286 from main and enabled path-scoped
R289/R290/R291 for current main source updates. The historical R286 failure
on the intermediate squash commit was the old 1.7.8 Setup filename pin and
does NOT represent a v1.7.9 product failure. Current main has no R286 run.

ALL nine GitHub-hosted jobs for exact main 479ee78 passed:
- Full Build + Verification: 40782440671 (1/1 success).
- R289 actual v1.7.8 -> 1.7.9 isolated in-place and crash-recovery:
  40782440727 (3/3 success).
- R290 native Win32 child/top-level overlay Z-order: 40782440719
  (2/2 success; 12 native assertions per OS).
- R291 REAL Explorer Start/Settings native UI on both hosted Windows
  2022 and 2025: 40782440809 (3/3 success).
  Four modes (plain1, plain10, glass0, opaque100) tested per host.
  Each host supplied 28 native observations including 20 physical screenshot
  SHA256/pixel-ink witnesses. Start menu observed with unchanged overlay
  bounds in all four modes; Settings activation, fullscreen suppression and
  taskbar hide/show verified. This is genuine hosted UI, but NOT personal
  Windows 11 / particular monitor/DPI owner hardware acceptance.

Local source code, installer, build and all four versioned CI workflows
match remote main exactly after fetch. Local-only private project-control
history remains unpushed in the one canonical project root/worktree.

OPEN POST-MERGE DELIVERY GATES: actual user-session Windows 11 personal
UI acceptance and safe, in-place v1.7.8 -> v1.7.9 owner deployment,
new sole official Setup GitHub Release with public asset SHA and install
receipt. Connected remote shell is SYSTEM session 0; GUI takeover/input is
retired by provider policy, and local gh CLI is not authenticated. Never
claim an owner update or public release until verified. Sole existing
official setup and existing installed user files remain protected.

Evidence: .local/audit/r292-main-r291-native-acceptance-and-ci-20261029.json
<!-- TBME:R292_MAIN_INTEGRATION_AND_NATIVE_EXPLORER:END -->

---
<!-- TBME:R290_ALL_HOSTED_CI_PASS:BEGIN -->
## R290 — Full latest public candidate CI VERIFIED PASS; owner visual pending

Public-source-only candidate commit f3ffc051589f926c384cb03f372dffc64cc161b0
is live in GitHub Draft PR #83, based on immutable v1.7.8 source. No
owner-local Brain/History/evidence shipped in the 20 public changed files.

All CI for THAT SAME exact commit is completed successfully:
- R289 private build + exact installed v1.7.8 native in-place interruption/recovery:
  https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/40778327007
  3/3 GitHub-hosted Windows jobs PASS.
- R290 exact production native Win32 sibling and top-level Z-order probes:
  https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/40778327028
  Windows 2022 and 2025: 12/12 assertions EACH, both job logs explicitly
  R290_NATIVE_ZORDER_PASS and R290_TYPED_NATIVE_ZORDER_ACCEPTANCE_PASS.
- Full PR Build and Verification:
  https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/40778334157
  SUCCESS including 10 visual suites, Settings/Glass, G15 unsigned-signing
  separation, G02 reproducibility, proprietary PawnIO exclusion, SPDX SBOM
  and five hostile release metadata mutation tests rejected.

Signed/unsigned and current release metadata regressions were updated for
v1.7.9 without changing old immutable v1.7.8 upgrade SHA pins.
The owner machine's intentionally forbidden driver test was NOT run there;
the hosted equivalent passed. 101 reproduced temporary local build outputs
(42,785,497 bytes) deleted, with SHA256 receipt. Sole official setup v1.7.8
is preserved; candidate v1.7.9 remains uninstalled and unpublished.
GitHub PR #83 is still Draft and unmerged, despite successful CI.

IMPORTANT OPEN: real user interactive Windows Explorer Start/Settings and
Glass-mode intermittent taskbar occlusion acceptance on owner-equivalent
desktop and authorized correct-user deployment. Synthetic native HWND
regressions are necessary but not sufficient to prove that UI behavior.
No release, merge, or owner-install mutation until this last gate is verified.

Latest receipt: .local/audit/r290-all-ci-gates-success-20261029.json
<!-- TBME:R290_ALL_HOSTED_CI_PASS:END -->

---
<!-- TBME:R290_REAL_WIN32_PROBE_PREPARED:BEGIN -->
## R290 — Native Win32 occlusion contract on disposable Windows (pending hosted result)

Build/Test-R290-NativeZOrder-Windows.ps1 (script SHA256: 268160DCED58A3635E3B270388266F5BE1886E8ACFA7C886F4116FFBF62D74D6)
uses an isolated real user32 Win32 temporary window hierarchy on GitHub-hosted
Windows 2025/2022. It invokes production TaskbarPresentationNative.Above,
TaskbarPresentationNative.TaskbarSiblingCovers, and the exact production
ShouldRepairOcclusion guard through reflection. The twelve assertions exercise
real top-level and child sibling Z-order, transient vs persistent overlap,
Start/Settings suppression and cooldown. All native test windows are created
and destroyed on the disposable guest only; no Explorer or owner state is changed.

The workflow audit-r290-native-zorder.yml (SHA256: 30624469DEC2E3E268B32ADA7DA64EA9FAA28FA68345B61F41EBB8347153297E)
compiles the private candidate, executes the native test under Windows PowerShell
Desktop STA, checks receipt type/count/source SHA and uploads bounded evidence.
Owner-host attempted invocation correctly refused without touching the owner.
Do not conflate this synthetic native test with acceptance of actual Explorer,
Start menu, owner Settings popup, or Glass visual appearance on a real desktop.
Do not merge PR 83 or release v1.7.9 solely on this synthetic test.

<!-- TBME:R290_REAL_WIN32_PROBE_PREPARED:END -->

---
<!-- TBME:R289_HOSTED_CI_PASS:BEGIN -->
## R289 native Windows hosted upgrade and crash-recovery VERIFIED PASS

Official-source-only GitHub candidate commit 2ac17b62c7661c420d18a5e1559325456a29c4bd
was pushed on development/v1.7.9-zorder-fix; public branch contains only 12
product/source/CI files, no owner-local Brain, History or private audit receipts.
GitHub Actions run 40774004006 COMPLETED SUCCESS:
  - windows-2025 candidate build: PASS
  - windows-2025 interrupted-stage and cold native Setup retry: PASS
  - windows-2022 forced real Setup kill during rollback and native retry: PASS
Both guest job logs explicitly emitted R289_GUEST_TYPED_RECOVERY_PASS.
Three bounded GitHub artifacts preserve candidate and guest receipts; local hash
receipt .local/audit/r289-hosted-ci-acceptance-20261029.json.

GitHub PR #83 is a DRAFT, not merged. main advanced only in public
docs/project-control files; product code baseline unchanged.
Host machine's official one Setup v1.7.8, installation, settings, system registry,
taskbar and active process MUST remain untouched until the last independent
real interactive Start/Settings/Glass/overlap verification. No physical owner
GUI or real user desktop acceptance yet. Do not claim installed fix.

<!-- TBME:R289_HOSTED_CI_PASS:END -->

---
<!-- TBME:R289_HOSTED_NATIVE_TEST_READY:BEGIN -->
## R289 — Hosted Windows upgrade and interrupted recovery tests prepared, NOT YET EXECUTED

Build source candidate 1.7.9 on GitHub-hosted windows-2025; the
audit-r289-zorder-inplace-recovery workflow then tests actual setup/update
from exact SHA-pinned official 1.7.8 on windows-2025 and windows-2022
disposable runners. New files: build/Test-R289-ZOrder-InPlaceRecovery.ps1
and build/official-v178-managed.json (22 original managed file hashes).
The native test script refuses any owner/nonhosted execution, checked
via explicit negative invocation on owner without changing settings.
Parser and static workflow checks PASS. Native guest tests, source-only
GitHub candidate branch, release and real owner update are still PENDING.
No original v1.7.8 Setup has been overwritten, no new junction or checkout.

<!-- TBME:R289_HOSTED_NATIVE_TEST_READY:END -->

---
<!-- TBME:R288_DISPOSABLE_VALIDATION_BLOCKER:BEGIN -->
## R288 — Disposable Windows upgrade remains gated (2026-10-29)

This read-only iteration reverified the v1.7.9 candidate and v1.7.8 owner without mutating the installation. All 22 official predecessor managed-file hashes match, along with the sole Setup, five protected installed paths, and the responding owner process. Zero Junctions and one worktree remain.

The Windows Sandbox optional feature is enabled and a Sandbox process is present, but the connected shell is NT AUTHORITY\SYSTEM in session 0 while the owner interactive desktop is session 1. Prior GUI capture returned OWNER_GUI_RPC_REJECTED; no guest control, display visibility or isolated native upgrade has been demonstrated. Do not equate Windows Sandbox availability with a tested guest. The existing R286 native crash/recovery test explicitly refuses execution outside a GitHub-hosted disposable Windows runner. The local GitHub CLI token is invalid; the first-party GitHub connector has owner repo permissions, but there is no confirmed CI run for this candidate.

Keep v1.7.9 UNRELEASED. Required next gates: isolated original official v1.7.8 -> candidate v1.7.9 /update /quiet, native power-interruption retry/rollback, and Start/Settings/Glass taskbar Z-order observation. No host install, process kill, desktop takeover, or new unsigned Setup publication occurred.

Read-only R288 SHA256 receipt: .local/audit/r288-candidate-owner-safety-20261029.json

<!-- TBME:R288_DISPOSABLE_VALIDATION_BLOCKER:END -->

---
<!-- TBME:R287_CANDIDATE_STATUS:BEGIN -->
# Current local development candidate — v1.7.9 / R287 (2026-10-29)

The active source contains the conditional taskbar Z-order occlusion fix and is a **candidate**, not a public release. Official v1.7.8 is the sole installed and sole Setup artifact. This section supersedes the older local v1.7.8 source/development statement below.

- Based on the exact released v1.7.8 source 9960a06dba606d1c93b8ca2b84e0e3e25ca4f68d, with R287 occlusion repair. Product/version metadata now 1.7.9+r287; sources and installer compile together without warnings or errors.
- Build.ps1: App, Broker, Supervisor and Setup PASS. Setup /verify PASS. Three app contract tests PASS. Candidate binary SHA256 3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E.
- Upgrade identity guard: 22 official v1.7.8 file SHA256 values checked against the installed file set, including official v1.7.8 maintenance Setup; all matched. Isolated reflection test confirms surgical state update (Version and PublicVersion only), rejects a foreign predecessor channel, and verifies 34 target paths (23 added/updated, 11 deletions) with transactional install_state.json and Uninstall.exe.
- Preserve the EXACT old official Setup in artifacts/in-place-update/ with SHA256 4DB3C03AC7AB70B3D3123A365C156E71370F0338991B399B99169A4B5B5F8B75. Do not replace it with a candidate until real isolated Win11 v1.7.8-to-v1.7.9 upgrade, sudden interruption/rollback, Start/Settings and physical occlusion tests pass.
- The 100 generated candidate output files (42,784,832 bytes) including the duplicate candidate Setup were removed with SHA256 receipts. The tracked source can rebuild the candidate; no second Setup, second project root, Junction or extra Git worktree retained.
- The current owner's app remains running v1.7.8, settings/installed state SHA unchanged and a candidate has NOT been installed. Windows Sandbox capability is enabled locally but no interactive disposable guest acceptance was conducted. Gated future publication, native GUI acceptance, safe unattended upgrade and rollback are open.
- Authoritative receipts:
  - .local/audit/candidate-v179-build-r287-20261029.json
  - .local/audit/official-v178-installed-upgrade-identity-20261029.json
  - .local/audit/candidate-v179-pinned-predecessor-reflection-20261029.json
  - .local/audit/candidate-v179-upgrade-target-map-contract-20261029.json
  - .local/audit/candidate-v179-reproducible-output-cleanup-20261029.jsonl

<!-- TBME:R287_CANDIDATE_STATUS:END -->

---
<!-- TBME:LOCAL_ACTIVE_DEVELOPMENT_20261029:BEGIN -->
# Active local in-place development — official v1.7.8 source (2026-10-29)

This is the current local development authority. The R285 v1.7.7 public redacted mirror below remains historically valid for its older scope, but it is not the currently installed/source version.

- One canonical development worktree, branch development/v1.7.8-inplace, based exactly on the published origin/main commit 9960a06dba606d1c93b8ca2b84e0e3e25ca4f68d. The prior feature/v1.7.0-wallpaper-studio branch is retained in Git for reversible provenance, not checked out as source. No extra repo, worktree or junction.
- The sole official unsigned v1.7.8 Setup is in artifacts/in-place-update/ with SHA256 4DB3C03AC7AB70B3D3123A365C156E71370F0338991B399B99169A4B5B5F8B75. Embedded /verify PASS. The pinned standard build compiled Main, Broker, Supervisor and Setup; PE subsystem, canonical text, version/signing metadata all PASS. Rebuilt Setup SHA256 is exactly identical to the official Setup.
- Three application contract tests (selftest, feature-contract-selftest, workspace-selftest) PASS. A process-local Git safe.directory override enabled the Windows SYSTEM-run test without changing global Git config or repository ownership.
- **Candidate UI correction, NOT INSTALLED (2026-10-29):** The current v1.7.8 source checks real Z-order occlusion before restacking its glass/top-level or ordinary taskbar-child overlay. It waits two consecutive observations, cools down for 3 seconds, refuses Start/Search, fullscreen/hidden states, active Settings/menu and recovery transition, uses non-activating SetWindowPos only on its own HWND, and logs any repair result. Three app contract tests PASS, including six new deterministic fault-policy assertions; source compilation PASS. Installed owner binary and one official Setup SHA remain unchanged. Live native owner-session, visual Start/Settings and actual in-place upgrade for a future version are NOT independently verified. Evidence .local/audit/zorder-targeted-app-build-test-20261029.json SHA256 2AD723D90635A9864DDACDE529548DABC5DCFE948ECC0E44D47E801452789653; ignored build-output cleanup .local/audit/zorder-generated-output-cleanup-20261029.jsonl SHA256 33786077371150311E60EA624386E30A37E5AE9CBDC64C72C345705328B123B5.
- Six isolated updater wrapper cases PASS: older-version preflight ready, current-version preflight no-op, current-version Apply no-op, newer-version downgrade rejection, foreign identity rejection, and missing installation rejection. These are simulated guard tests and not a real old-to-new installed upgrade.
- After verification 99 generated output files totaling 42,729,705 bytes were removed with hash receipts. The only retained app Setup is the official artifact. Active dependencies live in an ordinary build/_deps directory; no heavy historical files or ETL/ETLX remain in .local.
- Historical evidence recovery remains accepted: 1,009 original files / 40,492,233 bytes independently verified in .local/archive/historical-evidence; no duplicate external archive. User installation/configuration stays under Windows LocalAppData, outside the sole source repository.
- OPEN: real installation upgrade from a genuinely older installed version to 1.7.8 on a disposable Windows target; no new publication or owner-install change performed. The prior whole-disk discovery was bounded, not exhaustive.
- Build proof: .local/audit/official-v178-repro-build-summary-20261029.json
- Six guard tests: .local/audit/inplace-wrapper-isolated-contracts-20261029.json
- Output cleanup: .local/audit/official-v178-build-output-cleanup-20261029.jsonl

<!-- TBME:LOCAL_ACTIVE_DEVELOPMENT_20261029:END -->

---
<!-- TBME:PUBLIC_CURRENT_R285:BEGIN -->
# Current public release summary — R285 / official v1.7.7 (2026-10-17)

Official immutable [v1.7.7 release](https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.7.7), ID 415382091, source commit dc68cf448173bd0808d1dfa54bc9e9bf7ca20aad. Single intentionally unsigned Setup SHA256 395AEE56006F55FD5DCCFB52E1519088CE01A10386840D7008C6BA900136A06D; shipped/owner Main SHA256 A6D4BFD00C918C0601A12D185F414E92F2B6A85927042B811537B0BC37606253. Exactly seven public assets independently re-downloaded against Manifest, SHA256SUMS and G16. This verifies content/publication, **not** independent malware certification.

**Interruption bug fixed:** Real old v1.7.6 Setup process was killed during rollback on a disposable Windows guest; the retry failed due to abandoned owned .restore scratch. Versioned 1.7.7 safely recovers only known updater-owned transient scratch after verifying the journal/index and old snapshots. Exact-main [Build 38965519302](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/38965519302) PASS 27 steps; [hosted native Windows A/B 38965519445](https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/38965519445) PASS including a real Setup-process kill in guest B. Real AC mains interruption was not tested and has been **excluded by the owner**.

**Actual owner system:** The verified existing v1.7.6 per-user installation was updated in place with the official 1.7.7 Setup, Exit 0, and launched again. A preupgrade 26-file SHA-verified protected backup was preserved; exact five build-output hashes, one Main/one Supervisor/two Brokers, one HKCU registration, no extra HKLM install and cleared journal were verified. Glass true zero background alpha, red threshold warning settings and Windows notification preference remain enabled. v1.7.7 log records a real CPU 95°C warning dispatch at configured 85°C; direct actual OS banner/audio was **not independently witnessed**. Earlier R276 physical red pixels were verified on v1.7.6, and current behavior is retained by compiled regression/owner settings; no false claim of a new v1.7.7 physical pixel count.

**Scope and residual limits:** [Reporter WinRing0 issue #6](https://github.com/GOD13emad/TaskbarMonitorEnhanced/issues/6) still needs original file SHA256/install source, and a signed local PawnIO version does not dismiss that separate reporter warning. Publisher signing is intentionally waived. One **per-user** installation is accepted; no machinewide global singleton/auto-login claim. Audible alert observation remains missing. Physical AC tests are not a required gate.

The owner-local Index/Brain remains the single operational authority. This public page and [Issue #7](https://github.com/GOD13emad/TaskbarMonitorEnhanced/issues/7) are redacted mirrors; older engineering records following this block are preserved unchanged.

<!-- TBME:PUBLIC_CURRENT_R285:END -->

---

## Historical engineering records — prior "CURRENT" headings are not current release claims

# CURRENT R56 — real Start/Search 24/24 PASS; active Native ShellBeacon contract corrected, exact CI/host retest pending

R54 exact source de6d2bb3025b551dabfd0bd792fb368a1d6f519c, 12 candidate gates plus 4 Stable blockers. R55 actual installed-path Main-only guarded seven-minute watchdog test on Emad with real CPU/RAM/GPU/network showed 2895 actual text and 2695 graph pixels. Full resident eight-case suite got 7 PASS: startup, hover, hardware, temperature, protected sensor health, support and START. START met 24/24 SearchHost real shell, 24/24 exact 60px safe float and actual per-frame glyph+chart ink, minimum 48647 foreground signal, ≥1492 text and 1625 chart changed pixels, exact native HWND return to taskbar with legible ink. Eighth ShellState FAIL DIRECT_CHILD_NOT_FOUND: stale child-only proof, expected since true-alpha 0–99% uses a top-level popup. R55 original public installed v1.6 exe/config hashes restored exact, old process running, personal Slideshow and AnyDesk protected; genuine 7/8 FAIL retained. R56 source ShellState now distinguishes real PID-owned native top-level layered/noactivate popup vs 100% opaque taskbar child; native PArgb active beacon performs synchronous real ULW upload, requires magenta/green ≥100 physical pixels and BOTH reset below100, plus real signal≥300, style/PID/geometry/uncloak. Code builds locally, actual installed eight-case retest and exact source CI pending. All external Stable gates still OPEN: approved real Picture WallpaperStudio positive apply/restore, complete installed v1.7 Setup incl Explorer/sensors/8/8 and rollback, public-trusted Authenticode, main+immutable release. Public version v1.6.0 immutable. User Slideshow mode2 untouched, SAEID host declined, no security bypass. Authority docs/project-control/R56_SHELL_BEACON_NATIVE_ACCEPTANCE.md and R54/R51/R49/R46 history, cumulative Brain R38–R55. Project weighted completion UNPROVEN.

---

# CURRENT R54 — real visible Windows 11 Start/Search glass and exact taskbar return (private candidate)

Parent accepted source SHA R51 0a706f700e4623c24c6cd4e622ac071dcf5f6073. New draft feature branch feature/v1.7.0-r53-start-compositor-visibility. R52 actual installed-path v1.7 alpha-zero popup had visible live CPU/RAM and 2901 text / 2407 microchart pixels but 0/24 pixels during Start, shell foreground 24/24 and cached HWND valid 24/24. R53 actual production OverlayForm experiments: reassert TopMost/demote-promote/native ULW 0/24 visible; temporary exact 60px lift above taskbar 6/6 visible RIGHT and 6/6 LEFT; same HWND Hide/Show after exit restores ink, new HWND also restores but unnecessary. R54 production StartGuardTick now temporarily floats the existing noactivate PArgb strip exactly height+12px above original gap while Start foreground and reverses it via same HWND Hide/Show. R54 native proof exact developer Main SHA 15CB0E5A5F5FB72C1D5D23D7055D550CB8231EDB0B538F2F94F196838A551360: Start shell 24/24, safe lifted geometry 24/24, text+chart 24/24, original geometry restored with 2291 glyphs and 1907 chart pixels. R54-F1 original rescanned taskbar gaps during Start closing causing shifted x=2210 vs original x=2242 and fail; fixed to restore exact cached original rect and defer placement scan until settled. R54-F2 500ms visibility watchdog might immediately rescan if lastTaskbarScreenRect cleared; fixed to preserve cached taskbar screen bounds until routine scan. Strict production StartProbe now requires popup at exact lifted 60px position, shell foreground >=18/24, 24/24 real native ink incl ≥100 changed text and ≥100 changed chart pixels per frame, unchanged PID/style/uncloaked, and exact visible taskbar return. For opacity100 / High Contrast original direct-child rule preserved. Release hard source gate now G12 separate exact Main SHA-bound real 24-screen-ink proof; source candidate expected 12/12 and four external Stable blockers now G13–G16. **Installed full eight runtime/Explorer rollback NOT yet accepted; unsigned public v1.7 NOT released.** Active personal Windows Slideshow mode2, v1.6 installed public Main/config SHA protected; no alternate SAEID PC; no Windows security bypass. Important UX change: a 48px overlay temporarily ABOVE taskbar while Start open; public acceptance of transient UX not separately confirmed. Authority docs/project-control/R54_START_FLOATING_NATIVE_ACCEPTANCE.md, build/Test-Release-Gates.ps1, Project Brain R38–R51 cumulative preserved. Whole project percent UNPROVEN.

---

# CURRENT R51 - actual native live microcharts pass; Start probe corrected for native window mode

R49 normal-app binary-only installed-path canary on Emad R50 produced 3174 real text and 2898 real chart pixels after real data commits, user v1.6 original exe/config and protection restored with independently verified rollback PASS. Native rendering previously R47/R48 failed zero charts, source R49 fixed by immediate PArgb upload on CommitMetricsSnapshot. R50 six of eight interactive probes passed but Start probe failed BEFORE checking Start because it hard-coded a direct Shell_TrayWnd child even for 0% alpha. R51 StartProbe now strictly validates PID, WS_POPUP, no WS_CHILD, layered noactivate, uncomposited and full taskbar bounds for alpha below 100%; 100% or high contrast retains direct-child requirement. Original Start >=18/24 shell observations, 24/24 HWND/geometry, 300 pixel ink and zero hidden/cloaked thresholds remain unchanged. R51 source 10/10 visual and 5/5 portable pass, exact freeze/CI + real installed-path eight-case retest pending. Public/installed v1.6 remains accepted, user Slideshow type2 protected, no SAEID test. Four Stable blockers remain trusted Wallpaper real static Picture positive canary, actually installed full Setup+Explorer/8 interactive, public Authenticode, approved main CI and immutable release. Brain R45/R46/R49 history retained, see docs/project-control/R51_STARTPROBE_REAL_WINDOW_MODE.md. Full FINAL unproven.

---

# CURRENT R49: metric-driven native glass refresh, real installed-path acceptance pending

Source branch feature/v1.7.0-r49-live-metric-glass-refresh, R46 parent b1c5ae23876ce88ca63b46e5468342d79ab49b90. R47 and R48 actual (not proof-mode) temporary EXE-in-installed-location tests FAILED: alpha0 text visible (2844 and 2821 real pixels) but chart 0 and CPU/RAM stayed zero even after 65s; R48 6/8 interactive probes PASS with Start FAIL, shell not reached. Both mandatory rollback scripts restored resident v1.6 main/config exact SHA; user Slideshow, signed sensor supervisor and AnyDesk untouched. R47 original wrapper falsely labelled rollback unresolved from unset LASTEXITCODE; independent reconciliation verified rollback PASS. R49 source explicitly re-renders/updates native PArgb glass on every CommitMetricsSnapshot, not relying on unreliable WS_EX_LAYERED WM_PAINT, and theme switches; proof-mode real native form ran 2/2 actual metric-driven uploads, 2206 glyph/1833 chart pixels PASS. 10 visual and 5 portable source developer suites PASS. Exact-source clean-clone and hosted CI plus new installed-location transient canary remain mandatory. Do not call disposable proof-mode success installed production success. All original R38-R46 and R47/R48 failures preserved. Public installed immutable latest v1.6.0. Stable gates G12 positive static Wallpaper, G13 installed 8/8/Explorer, G14 public Authenticode, G15 main + public assets remain BLOCKED. No SAEID use, no wallpaper change or security bypass. R49 authoritative doc: docs/project-control/R49_LIVE_METRIC_REFRESH_VERIFICATION.md. Final project progress UNPROVEN.

---

# CURRENT R46 - ACTUAL WINDOWS 11 ZERO-ALPHA TEXT AND CHART VISIBLE / UNRELEASED CANDIDATE

Exact parent R45 a019ee72e676c8fa2f3cdd1d5ac28f9b0f1060cf. New isolated candidate branch feature/v1.7.0-r46-native-visible-glass. R46 root cause: layered child UpdateLayeredWindow returning success did not mean its ink was visible above Windows 11 taskbar shell compositor; production-style child with WS_EX_COMPOSITED gave error 87; without WS_EX_COMPOSITED the child had zero actual on-screen text and chart pixels. R46 switches all opacity below 100% to taskbar-anchored no-activate top-level PArgb glass and keeps 100%/High Contrast original opaque child. Preserves UIAutomation safe gap, real metrics and original mouse/menu. User slideshow and installed v1.6 untouched. Actual PRODUCTION OverlayForm disposable proof-mode measured 2,319 real text and 2,055 graph changed pixels at 0%, and no changed fully transparent backdrop pixels; native mode transitions 0-30-97-100-0 PASS (four stages). Exact Main SHA FEF4FC84B06906D6DDAAB5D59EB0BA5A9B339130A42161B8467E2A13766795B3 in preliminary source; source freeze and exact CI still pending. R46 independent candidate release gate requires exact executable SHA, actual real screenshot foreground ink, 4/4 native mode changes, and no host mutation; 15 total candidate+stable gates once committed. Public/installed latest v1.6 immutable. Four Stable blockers remain authorized static Picture wallpaper canary, actual installed v1.7/sensor/Explorer/8 runtime+rollback, public Authenticode, approved main+immutable release. Do not run setup or change personal Windows Slideshow. R46 authority: docs/project-control/R46_NATIVE_COMPOSITOR_VERIFICATION.md and previous R44/R45 lifecycle records. SUPERSEDED: prior child-only ULW API proof or top-level render-only preview as production-visible acceptance. Whole-project percentage UNPROVEN without approved weights.

---

# R45-F4 RELEASE GATE CORRECTION - NOT PUBLIC FINAL
CI run 38050088052 recorded all five portable child proofs PASS but the GitHub workflow failed due invalid PowerShell comparison of null LASTEXITCODE with zero. Source correction removed only the false wrapper guard and preserves thrown errors and exact 5/5 summary. Exact source CI retest pending. All stable blockers remain: positive wallpaper canary, installed 8/8 runtime, public signing, main release. v1.6 and user slideshow unchanged. See R45_RELEASE_GATE_ENFORCEMENT.md.

---

# R45 CURRENT-CORRECTION - FULL CI FAILED THEN SCOPE FIXED
GitHub CI run 38049549463 FAILED at health without installed sensor Supervisor (host environment mismatch). On real Emad PC full interactive Start probe FAILED 10/24 shell observations although cached child/screen pixels remained good (minimum 7381). The source has been corrected to require 5/5 portable CI runtime tests while leaving full 8/8 installed-host acceptance a strict Stable prerequisite, plus 10/10 visual. Nothing has been installed or publicly released; local v1.6 and slideshow preserved. See R45_RELEASE_GATE_ENFORCEMENT.md. Next action exact commit/build/CI and honest release-preflight, not production promotion.

---

# CURRENT R45 - FULL CI VERIFICATION HARDENING (PUBLIC FINAL BLOCKED)

Product TaskbarMonitorEnhanced; branch feature/v1.7.0-r44-chart-foreground, parent R44 commit 3926bfa7b9dddb735e7b79ede1c17632848b44d8. R44 chart foreground alpha0 and real on-Emad noninstalled preview PASS, 49 themes, 10 visual, 8 runtime, 196 graph ink dark/light alpha cases; exact R44 CI and determinism PASS. R45 adds mandatory 10-visual and 8-runtime suite checks in GitHub workflow and a fail-closed 14-gate read-only release evaluator. R45 exact SHA CI has not yet been run at this record. Existing installed/public immutable v1.6.0 Main hash 05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377; user Slideshow BackgroundType 2 unchanged.

CRITICAL BLOCKS: Issue #7 trusted real static-Picture product Apply+exact restore positive canary missing (Windows Sandbox Application Control HRESULT 0x800711C7); user declined using separate SAEID PC; real installed v1.7 native taskbar/Explorer recovery/config rollback missing; public SignPath Foundation Authenticode not available (Get-AuthenticodeSignature NotSigned); main merge/immutable public v1.7 release not performed. Do NOT bypass protections, alter user's slideshow, replace installed v1.6 or claim Stable based on isolated CI and preview. Whole-project weighted percent UNPROVEN. R45 full roadmap and exact tests: docs/project-control/R45_RELEASE_GATE_ENFORCEMENT.md. Legacy R44/R42/R41/R38 records preserved. Exact next step commit R45 source, run exact build/CI 10+8, strict -RequireStable must fail closed, then cumulative Brain R45.

---

# CURRENT R44 — foreground charts survive alpha zero, candidate only

Source feature/v1.7.0-r44-chart-foreground derives from accepted R42 candidate 5a6c7e5b9537e9694b4447b13e07e86de77b8696. R44 re-routes sparkline, bar, LCD and dot microcharts of all 49 themes into independent glyph-like foreground and high-contrast halo. Chart ON/OFF with dark/light Windows taskbars at zero and 29%: 196/196 source proof pairs PASS; visual regression 10/10. EMAD-PC verified with temporary nonactivating click-through top-level visual-only preview: 24 real samples, 1,788 separate chart pixels, screenshot and automatic close PASS. No deployed production app replaced. Previous public/installed v1.6.0 immutable and user's slideshow unchanged. Blockers: R42 positive static wallpaper canary blocked by Windows Sandbox App Control 0x800711C7 (issue #7), installed v1.7 transactional acceptance, external signing trust, and immutable public publication. CI/determinism on R44 SHA still needs final verification. All release stages and evidence: docs/project-control/R44_RELEASE_GATES_CHECKLIST.md. Whole-project completion percentage UNPROVEN; public FINAL not achieved. SUPERSEDED—DO NOT RUN: previous obscured R43 child preview, pre-R44 candidate setup, old unguarded wallpaper apply. Exact next action: commit exact R44, build/determinism + CI, stage candidate Brain, then trusted static Picture canary and installed acceptance.

---

# CURRENT R42 — SAFETY HARDENING / NOT RELEASED

Active source worktree: C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced\.local\r41-work. Branch release/v1.7.0-r42-safety from R41 d14768fb1d1d2110aec5cb7ddb48427d76d85166. Public immutable and installed v1.6.0 remain accepted. New finding: live Windows background mode 2 Slideshow actively rotates its picture; running an unguarded Wallpaper Studio canary on host would cause persistent loss of Slideshow state. R42 safely rejects dynamic modes and records verified SHA-backed static Picture rollback. RED/green app test and real negative host guard PASS; isolated positive static Picture canary, exact build/determinism, CI, installed runtime, main and publication still OPEN. Whole project progress UNPROVEN; no final claim. Authoritative R42 safety record: docs/project-control/R42_WALLPAPER_SAFETY.md. SUPERSEDED—DO NOT RUN: pre-R42 wallpaper setup and negative test wrappers. Existing R41 Brain is STALE until new cumulative ZIP transfer verified. Exact next action: sandbox positive canary, then remaining exact-gate V&V. No host wallpaper edit or v1.7 auto promotion.

---

# CURRENT R41 — GLASS LEGIBILITY VERIFIED CANDIDATE (NOT RELEASED)

Source: isolated branch feature/v1.7.0-glass-legibility, parent 3a0663fb9ed55c77d28ca3ee8d3d928adf1d2e42. Public, installed immutable authority remains v1.6.0 at 1652989b80c5c6d301c6f05818c48c5207fd9b7a. All 49 candidate themes support 0%-100% background alpha without fading glyphs. At <=30% glyph ink switches to high-contrast black/white from off-overlay actual taskbar RGB samples, with contrasting outline, 4s refresh/fallback; Windows High Contrast forces opaque. No cloud/screen capture. Native actual taskbar child probe five modes PASS, RGB #132A27, contrast 15.13. Pixel proof 196/196, visual suites 9/9, full build 0 warning/error, setup 26/26. Main/Broker/Supervisor sensor source unchanged.

DoD for THIS FEATURE: implementation/build/finite contrast/native-host/48+1 themes PASS. Exact-commit determinism and CI pending. Whole v1.7 (including untested independent live wallpaper canary and installed acceptance) is NOT FINAL. Roadmap: discovery/definition/baseline/development DONE; verification partially passed; validation candidate only; delivery/closure OPEN. Completed: code, tests and canonical package, preserved prior public baseline. Open Critical Gates: exact source commit, clean-clone reproducibility, CI/provenance, R40 wallpaper canary, installed-runtime acceptance, final release. Current/authoritative files: src/TaskbarGlass.cs, altered src/TaskbarMonitorEnhanced.cs and StudioThemes.cs, build files, installer and versioned R41 controls. SUPERSEDED—DO NOT RUN: pre-R41 v1.7 setup as current R41 candidate, and initial proof wrappers with parent-handle/arg/count failures. Do not delete historical files. Exact next action: commit/freeze current R41 source, rerun clean-clone determinism, CI, then recheck release gates. Brain status: INCOMPLETE until cumulative transfer zip verified; previous history below remains append-only historical reference.

---
# CURRENT PRODUCT AUTHORITY - v1.6.0 RELEASED / R38

UTC 2026-10-02T23:15:56.337123+00:00. Current product: **Taskbar Monitor Enhanced v1.6.0**, eight workspace pages and 48 built-in themes (20 original Studio geometries). Public release402214671 is immutable/latest, with seven verified assets. Source/tag authority `1652989b80c5c6d301c6f05818c48c5207fd9b7a`; canonical root `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`; installed configuration preserved bit-for-bit (69 properties), exact sensors unchanged. Release and main CI, candidate 15/15 suites, installed 15/15 suites, production UI actions and independent manual UI all passed.

Read `R38_CLOSEOUT.md` and `../acceptance/v1.6.0/PUBLIC_RELEASE_ACCEPTANCE.json` first. Product lifecycle through delivery/release is complete; no in-scope critical product gate remains. Cumulative transfer archive path is `.local/r38/BRAIN_R38.zip`; its final machine-local receipt and manifest determine archive integrity/account-transfer completion. Post-release documentation is not a new product binary. The historical CURRENT/OPEN/FINAL headings below are preserved verbatim and superseded for current action.

External/deferred only: trusted Authenticode provider, physical two-monitor test, excluded specialist/kernel/plugin/control features. Exact next user action: use the installed app/Theme Studio; do not rerun any installer. Exact engineering continuation: verify newest Brain and immutable source identity, then branch a new revision for any new scope.

---

# CURRENT AUTHORITY - R38 / v1.6.0 finalization

Updated UTC: 2026-10-02T22:43:42.582431+00:00

Canonical development has been consolidated at `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`, branch `release/v1.6.0-final`, based on corrected source `182c4ed11d78fa3c52f8bbf104a7e791cd2491bf`. The isolated worktree and original candidate are retained as historical lineages, not current execution roots. Scope is eight workspace pages and 48 themes (20 new original geometries), preserving locked sensors and configuration.

A regression-first cold-shutdown traffic data-loss repair passed all three contract suites (red operation `920abe69-1532-43d2-a0e4-36966e90f094`, green operation `36c6d7b0-83ce-401c-808e-3e6c11c4bc0d`). See `R38_FINALIZATION.md` for failure class/root cause, exact guards, baseline hashes, roadmap, exclusions and next action.

Stage: VERIFICATION / exact source freeze. Full build/determinism, fresh UI/runtime, CI/provenance, configuration-preserving final installation and public immutable publication remain OPEN. Public v1.5.0 remains the accepted external release until verified v1.6 publication. Control record CURRENT; cumulative transfer ZIP INCOMPLETE until closure packaging. Earlier CURRENT/FINAL headings below are historical and superseded for the active v1.6 release.

---

# CURRENT CONTINUATION — R37 isolated integration verification

Project: Taskbar Monitor Enhanced. Canonical root is C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced; active verified development is its .local\r37-work linked worktree, branch release/v1.6.0-r37-verified. Previous public authority remains immutable v1.5.0. Original-worktree candidate f170a8a is defective (empty committed StudioThemes.cs) and MUST NOT be installed/published.

Current delta: exact-hash theme recovery; actual runtime ordering/bitrate/lifecycle hooks; schema 0..6 migration; unavailable-data gaps; finite-value guards; coalescing traffic writer with corrupt-file preservation; truthful live-data workspace proof. See R37_VERIFICATION.md for failures, evidence and rollback.

Verification checkpoint: operation 18619848-e151-4327-8a31-b9e617c7f0ff passed build with 0 warnings/errors and all three contract suites. Additional model-regression operation 2ffa3f0b-3141-4fd8-b84e-9354d6008c08 passed: counter baselines/resets/gaps/adapter switches, explicit opt-in, coalesced exact final totals, corrupt-file preservation, 90-day retention, immutable snapshots, P95/finite statistics and transactional allowlisted profile import. Actual-data workspace proof 62051440-752f-48b9-8f2b-2bd0fce2a497 captured seven pages with NoSyntheticMetricData=true and 16 live samples; four key pages were visually reviewed. These are candidate verification results, not installed-runtime/public acceptance.

Roadmap now: integration unit/contract verification COMPLETE -> final workspace completeness and UI acceptance -> exact source freeze -> full deterministic build -> CI/provenance -> configuration-preserving live upgrade + installed regression -> immutable publication -> cumulative transfer Brain and closure. Do not infer a whole-project completion percentage.

Locked: sensor sources/protocols unchanged (Broker 1.1.2+r21, Supervisor 1.3.0+r33). No reboot, no public trusted-signature claim, no universal-competitor superiority claim.

Open gates: remaining UI/lifecycle acceptance, source freeze, full build/determinism, CI, actual installed v1.6, publication. Exact next action: commit this repaired checkpoint, finish bounded workspace coverage and independent UI actions, then freeze and run the release gates. Brain status: INCOMPLETE until cumulative transfer ZIP and final gate record are generated. Older CURRENT/FINAL statements below describe historical versions only and are superseded for the active v1.6 candidate.

---
# PROJECT BRAIN — Taskbar Monitor Enhanced

Brain Version: PB-2026-10-02-R37-V1.6.0-CANDIDATE
Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
Updated: 2026-10-02T23:25:00+03:30

## CURRENT AUTHORITY - 2026-10-02 R37 / v1.6.0 LOCAL CANDIDATE

This section supersedes older current authority/progress/next-action statements where they conflict. Historical evidence below remains immutable history.

- PROJECT: Taskbar Monitor Enhanced, Windows taskbar system monitor.
- FINAL OBJECTIVE / DoD: immutable Stable/Latest v1.6.0 release from an exact Git commit; deterministic build; exact-head CI/provenance; live upgrade preserving user configuration and protected sensor compatibility; installed-runtime regression; 7-asset digest-verified publication; current account-transfer-ready Brain.
- CURRENT STAGE: VERIFICATION -> candidate commit preparation. DEVELOPMENT is complete for R37; public RELEASE is not yet accepted.
- BRANCH: feature/v1.6.0-workspace-theme-studio.
- BASELINE: public immutable v1.5.0 remains current Latest at release SHA d952a87fab02fe74046b8d19ae14a2801d6da644. Pre-R37 main/control head: 7402249276ef3b7fb87fa6cad4a26652d7f57db4.
- R37 CHANGE SET / CONFIRMED: seven-page Performance Workspace; 20 original Studio renderer modes/themes for 48 total; bounded interactive analytics; read-only process inventory; per-adapter network view; opt-in 90-day local traffic history; sustained usage/capacity alerts; quiet hours/snooze; theme favorites/search; presentation profiles; metric ordering; config schema 7.
- PRIVACY / CONFIRMED: traffic persistence defaults OFF; no cloud telemetry/background upload added; presentation-profile import is allowlisted and cannot change startup/sensor/traffic-retention/notification-sensitive settings.
- SENSOR AUTHORITY / CONFIRMED: sensor source/binaries/protocol intentionally unchanged, Broker 1.1.2+r21, Supervisor 1.3.0+r33.
- BUILD / CONFIRMED: Main/Broker/Supervisor/Setup 0 warnings / 0 errors; sensor windowless PE PASS; canonical text payload PASS; reproducible build PASS; setup resource verify 24/24.
- REGRESSION / CONFIRMED: corrected fresh regression3 suite 15/15 PASS using real child-process exit codes. Theme 48/48; Workspace 7/7; compact 96 images; Settings 9/9; startup/hover/start/shell/hardware/temp/health/support PASS. Health STABLE.
- EVIDENCE / CONFIRMED: full build operation b8afdb36-1026-43b0-afd2-d68da9263b91; accepted regression operation 14a4c0cc-4d73-440c-9c54-412b03d530fa; local evidence under .local\v1.6.0\regression3.
- PRE-COMMIT HASHES / CONFIRMED: Main 5ECE8EA77F51D9630702DEB0517683A4A4A667A630373FA4FF14FAC90C88E9FC; runtime config D2E51872D93F0793C02AD07DCBF8C2802F59708C666548372A4FDDDA5C7C5E4F; Broker 182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833; Supervisor 0E28911AACDE0C3B1C6997C8BC6FF141C0FAA650B58438A9991CB3AD6C13C785; Setup pre-commit 5722E8B7A184C40EB1967B0ECA6AF588E37A15D890DC2E358792BC7C920095F0. Setup hash is not final until exact candidate commit rebuild.
- FAILURES / PREVENTION: R37-F1 missing proof helper -> proof-only helper added; R37-F2 malformed canonical-resource Join-Path -> direct paths; R37-F3 harness null Trim and PowerShell automatic $args collision -> invalid prior PASS explicitly rejected, null-safe $arguments harness rerun from fresh evidence and 15/15 PASS.
- COMPLETED: definition, architecture, implementation, app/full build, self-tests, visual proofs, local regression, versioned release notes, candidate acceptance draft.
- OPEN CRITICAL GATES: exact candidate commit -> clean-clone determinism -> exact-head GitHub CI/provenance -> live v1.5->v1.6 upgrade/config-preservation/installed-runtime checks -> immutable 7-asset draft digest check -> public Stable/Latest publish -> post-publish verification -> closeout Brain.
- DEFERRED EXTERNAL: publicly trusted Authenticode provider remains external; no trusted-signature claim.
- AUTHORITATIVE CURRENT FILES: tracked R37 source/build/installer/docs plus docs/acceptance/v1.6.0/CANDIDATE_ACCEPTANCE.json. .local evidence is read-only validation evidence, not release source.
- SUPERSEDED—DO NOT RUN: R37 regression wrappers that used null Trim or function parameter $args; accepted harness is regression3 semantics using $arguments.
- EXACT NEXT ACTION: update remaining current-facing documentation, git diff --check, commit the exact R37 candidate, rebuild that exact commit, then run clean-clone determinism. Do not install/publish before determinism + exact-head CI.
- BRAIN STATUS: CURRENT for pre-commit R37 candidate; must be updated at exact candidate SHA, CI, install and public-release milestones.

## CURRENT AUTHORITY - 2026-10-02 R35 / v1.4.0 FINAL PUBLIC RELEASE

- FACT / CONFIRMED: Current public Latest release is `v1.4.0 — Windows Integration & Accessibility`.
- FACT / CONFIRMED: GitHub release id `401760081`; public, non-draft, non-prerelease and immutable.
- FACT / CONFIRMED: Annotated tag object `41e3ff3b96a72ec4bb03017508be47bd112712d9` peels to exact release commit `924b9bd140b531733c08ca6297d3f8beedc8bb18`.
- FACT / CONFIRMED: Exact hashes: Main `D73352AD9F6F7D195C99F65EC1266202248B2EF514B2E3A15DDDD5567F155A12`; runtime config `D2E51872D93F0793C02AD07DCBF8C2802F59708C666548372A4FDDDA5C7C5E4F`; Broker `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833`; Supervisor `0E28911AACDE0C3B1C6997C8BC6FF141C0FAA650B58438A9991CB3AD6C13C785`; Setup `7D528911113C6BE86A42AA6174957D85367D5B8D8F607C66F46D6E42E349FD6A`.
- FACT / CONFIRMED: Installed runtime on Emad-PC-Ultimate matches the exact Main/config/Broker/Supervisor build hashes and reports v1.4.0+r35.
- FACT / CONFIRMED: Candidate suite 9/9 PASS; installed post-install suite 10/10 PASS.
- FACT / CONFIRMED: Settings proof: PerMonitorV2, 67 interactive controls / zero accessibility-name gaps, 143 High Contrast checked controls / zero style gaps.
- FACT / CONFIRMED: R35 feature contract verifies Windows theme following, High Contrast, deterministic multi-monitor selector, canonical update identity, pre-launch SHA-256 rehash, DLL search hardening and privacy-safe crash snapshots.
- FACT / CONFIRMED: Current host has one physical monitor/taskbar. Secondary-taskbar selection is deterministic-test covered; no physical two-monitor attachment claim is made.
- FACT / CONFIRMED: Release-branch CI `36998041954` and main exact-release CI `37000835504` both SUCCESS and reproduce exact 5/5 hashes. Runtime config has dedicated provenance attestation.
- FACT / CONFIRMED: Public release assets 7/7 digest/size verified.
- FACT / CONFIRMED: Sensor architecture unchanged: R21 process isolation, Broker protocol `1.1.2+r21`, Supervisor `1.3.0+r33`.
- FACT / CONFIRMED: Public-trust Authenticode signing remains external/unproven; no trusted-signature claim is made.
- Product DoD: COMPLETE / FINAL_PUBLIC_RELEASE_ACCEPTED.
- Open product blockers/gates: none.
- Deferred validation only: physical secondary-monitor attachment proof requires a host with a second active Windows taskbar and is not required for single-monitor functionality.

## CURRENT AUTHORITY - 2026-10-02 R34 / v1.3.1 FINAL PUBLIC RELEASE

- FACT / CONFIRMED: Current public Latest release is v1.3.1 — Real Theme Preview.
- FACT / CONFIRMED: Release id 401668211; immutable, non-draft, non-prerelease.
- FACT / CONFIRMED: Annotated tag object `3d3734d4161cdb1cd974f6e1af2fed498be16766` peels to release commit `6e1edfe0f89ea9981360b904dd93fc198d891f04`.
- FACT / CONFIRMED: Main v1.3.1+r34 hash `8009574BD5FBB44FC699476149F8F5315BA99D2045F3884F629D550B1FA3BBCF`; Setup hash `67CC88D429FFA9E8D17609ECF8814CF6ABF2C70979B10BB1840071A1AC5FDF26`.
- FACT / CONFIRMED: Sensor layer unchanged: Broker protocol 1.1.2+r21, Supervisor 1.3.0+r33.
- FACT / CONFIRMED: Display theme preview now uses the exact taskbar renderer pipeline and live runtime snapshot/history. Palette-only mock preview was removed.
- FACT / CONFIRMED: Settings proof uses 12 live samples, no synthetic metric data, real 48 px taskbar strip and 9/9 page capture.
- FACT / CONFIRMED: Installed v1.3.1 on Emad-PC-Ultimate; CPU/GPU/Storage health PASS.
- FACT / CONFIRMED: Exact-head CI run 36986831343 SUCCESS with 4/4 binary hash equality, provenance and Setup SBOM attestation.
- FACT / CONFIRMED: Public release assets 7/7 digest-verified.
- Product DoD: COMPLETE / FINAL_PUBLIC_RELEASE_ACCEPTED.
- Open product blockers/gates: none.
- Deferred external item only: publicly trusted Authenticode signing remains unproven.

## CURRENT AUTHORITY - 2026-10-02 R33 / v1.3.0 FINAL PUBLIC RELEASE

This section supersedes older current-authority, blocker and exact-next-action statements below where they conflict. Historical release/audit evidence remains immutable history.

- FACT / CONFIRMED: Current public Latest release is `v1.3.0 — Reliability, Alerts & Support Tools`.
- FACT / CONFIRMED: GitHub release id `401629671`, public/non-draft/non-prerelease, immutable, published at `2026-10-02T07:55:32Z`.
- FACT / CONFIRMED: Annotated tag object `8d9314a60ceaaa074b5f877aaf4d224337780fb3` peels to exact release commit `fc5619d049de4a95cb23542a8c3318e12f064691`.
- FACT / CONFIRMED: Exact release hashes: Main `B11BF06BBA341AE87B46829580C19D4184FB87A39D5797DF803436F6D8331F90`; Broker `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833`; Supervisor `0E28911AACDE0C3B1C6997C8BC6FF141C0FAA650B58438A9991CB3AD6C13C785`; Setup `508BB69F48D992FFC5AF240F3F775B5E2CAA1B052BFDB48302DEC40364B521BF`.
- FACT / CONFIRMED: Release-branch CI `36980484008` and main exact-release CI `36980902415` both SUCCESS; main CI printed the exact same 4/4 hashes and created binary provenance + Setup SBOM attestations.
- FACT / CONFIRMED: Final installed runtime on Emad-PC-Ultimate matched release Main/Broker/Supervisor hashes exactly; Supervisor state reports `SupervisorVersion=1.3.0+r33`, `BrokerVersion=1.1.2+r21`, CPU/GPU/Storage transport+data healthy.
- FACT / CONFIRMED: Storage live soak: 73 samples / 5 attempt delta / 0 failure samples / max completion 292 ms / final HEALTHY_DATA.
- FACT / CONFIRMED: Continuous startup self-heal live fault injection passed on final Main: HKCU Run repaired in 16.1 s; recovery shortcut repaired in 30.1 s; no fallback restoration used; shortcut target/arguments/working directory contract passed.
- FACT / CONFIRMED: Final post-install proof suite: 15/15 PASS / 136 artifacts; Settings 9/9; themes 28/28; compact 592+500 zero overflow; Start transition 24/24 with zero visibility/parent/cloak/pixel failures.
- FACT / CONFIRMED: Support ZIP privacy manifest omits machine name/user-profile source paths; Safe Defaults backup preservation and collision-safe uniqueness self-tests pass.
- FACT / CONFIRMED: Public release assets: 7/7 uploaded and GitHub digest/size matched staging exactly.
- FACT / CONFIRMED: Public-trust Authenticode signing remains external/unproven; no trusted-signature claim is made.
- Product DoD: COMPLETE / FINAL_PUBLIC_RELEASE_ACCEPTED.
- Open product blockers/gates: none.
- Post-publication housekeeping: PASS through documentation closeout commit `10e8bfdbe4f4c62262b756c0b7dd396c1dfde539`, exact-head CI run `36982325715` SUCCESS, and deletion of merged temporary R33 branches. Remote branch surface is only `main`; release tag/assets remain immutable.

## CURRENT AUTHORITY - 2026-10-01 R32 DEEP PC AUDIT / CONSOLIDATED ROOT

This section supersedes older Current authority / Current critical gate / Exact next action statements below where they conflict. Historical release acceptance records remain immutable evidence and are not rewritten.

### Authority and scope

- FACT / CONFIRMED: Canonical project root is C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced.
- FACT / CONFIRMED: Immutable public release authority remains v1.2.0. The annotated v1.2.0 tag peels to release commit 84d22fae6638b21683ea828e86517d100ced1654. The release remains FINAL_PUBLIC_RELEASE_ACCEPTED; this R32 audit does not mutate that tag or its published assets.
- FACT / CONFIRMED: Main/control head immediately before R32 audit-record mutation was f1136bbf0501f37040162db37b85562ce0901378.
- FACT / CONFIRMED: Local forensic/history/runtime evidence is consolidated under .local and ignored by Git. Live installed runtime remains at its Windows operational paths because moving it would break the application; a full snapshot and integration-state snapshot are retained under .local\runtime-snapshots\2026-10-01.
- FACT / CONFIRMED: Only Emad-PC-Ultimate was used for the machine audit and filesystem mutations.

### Full-PC discovery and consolidation

- FACT / CONFIRMED: A recursive name/path discovery scanned all mounted data volumes C:, D:, and H:. F: existed only as an unmounted drive letter with Test-Path F:\ = false, so it had no readable filesystem to scan.
- FACT / CONFIRMED: Pre-consolidation discovery found 6,039 project-related path/name matches. D: contributed no project match; H: contributed five matches.
- FACT / CONFIRMED: Phase 1 consolidation moved 2,049 files / 1,229,439,290 bytes from the external project archive, Downloads\My Project\TBME, legacy _rc_tbme helpers, and legacy installers into the canonical root. Independent post-move SHA-256 verification passed 2,049/2,049 with zero mismatches.
- FACT / CONFIRMED: Phase 2 consolidation handled 34 source objects / 8,601 files / 3,143,198,410 bytes, including ten inactive self-hosted runner trees, sixteen historical TBME boot workspaces, predecessor taskbar-monitor residue, the SensorBroker crash dump, three H:\My app release artifacts, and safe copies of cross-system/global-backup evidence. Independent post-operation verification passed 8,601/8,601 with zero mismatches.
- FACT / CONFIRMED: Four explicit copy-suffixed download duplicates were deleted only after exact SHA-256 canonical counterparts were proven; 368,693 bytes were removed while the pre-move manifest preserves original paths and hashes.
- FACT / CONFIRMED: Inactive runner infrastructure contains 7,419 files / 3,060,754,534 logical bytes. Windows LZX archive compression processed 7,293 files at about 2.1:1 and freed about 1.53 GB on C:. Full post-compression SHA-256/size verification passed 7,419/7,419 with zero failures.
- FACT / CONFIRMED: Post-consolidation full-PC scan found 315 related matches outside the root: 313 on C:, zero on D:, and two on H:. Every remaining match is classified as live runtime/sensor/shortcut, external software cache, global Remote Commander backup, cross-system evidence, or KISH_AI cross-project mirror. No inactive TBME-owned workspace/archive remains unclassified outside the root.
- FACT / CONFIRMED: Razer cache items and KISH_AI references were copied into the root with hashes while originals were preserved because they belong to other software/projects. The two KISH_AI C:/H: mirrors are pairwise SHA-256 identical.

### Reconstructed project origin and evolution

- FACT / CONFIRMED: Taskbar Monitor Enhanced is a GPL derivative of leandrosa81/taskbar-monitor; attribution is preserved in the tracked repository.
- FACT / CONFIRMED: The enhanced project predates the public Git history. The earliest recovered local package is R9R3 from 2026-08-15 and contains a PowerShell runtime, TaskbarMonitorEnhanced.ps1. Its manifest identifies R8 as baseline and already defines R10/R11/R12/R13 follow-on work.
- FACT / CONFIRMED: The recovered Git repository is now unshallowed. Its root commit is 4307824c4c1cdb3138b81f0fca6019c00439ed2e, dated 2026-08-16T02:00:29+03:30, subject Initial public release: Taskbar Monitor Enhanced 1.0.0.
- FACT / CONFIRMED: Public release lineage is v1.0.0 -> V1.0.2 -> v1.1.0 -> v1.1.1 -> v1.1.2 -> v1.1.3 -> v1.2.0.
- FACT / CONFIRMED: Four dangling Git objects discovered after unshallow were preserved before any cleanup: two commits in .local\history\git-dangling\dangling-commits.bundle with bundle verification PASS and two exported blobs. No destructive git gc/prune was performed.

### Current build and functional validation

- FACT / CONFIRMED: Current main builds locally with Build.ps1 -NoDownload: Main, Broker, Supervisor, and Setup all compile with 0 warnings / 0 errors; windowless sensor PE, canonical text payload, and reproducible-build gates PASS.
- FACT / CONFIRMED: dependency lock is intact. LibreHardwareMonitor 0.9.6 and PawnIO 2.2.0 cached artifacts exactly match dependencies.lock.json SHA-256 values. GitHub release metadata checked from Emad PC reports both pinned versions as latest stable as of this audit.
- FACT / CONFIRMED: corrected R32 safe-proof harness produced 121 evidence artifacts and 8 PASS / 1 FAIL: selftest, hover-guard, 8-page Settings, 28-theme proof, compact 592/500 proof, hardware probe, temperature probe, and real shell/taskbar state PASS. Health probe exits 12 because the live storage lane is degraded.
- FACT / CONFIRMED: real shellstate proof reports WindowValid=true, Visible=true, ParentOk=true, active-beacon PASS, and direct taskbar parenting.
- FACT / CONFIRMED: current binary signing status is NotSigned for Main/Broker/Supervisor/Setup and installed Main/Uninstaller. Public-trust signing remains external/pending.

### Current open technical gates

1. STORAGE SENSOR HEALTH - OPEN / CURRENT RUNTIME BLOCKER FOR FULL-HEALTH CLAIM.
   - FACT: R21 process containment is healthy, CPU and GPU lanes are healthy, but StorageTransportHealthy=false / StorageDataAvailable=false during the R32 health proof.
   - FACT: Supervisor uses a fixed 12-second storage one-shot timeout and requires worker process exit before accepting success.
   - FACT: storage broker logs show valid BROKER_ONCE_PASS/data can occur near the timeout boundary, while Supervisor can still classify the attempt TIMEOUT and enter 180/300-second backoff. Later attempts sometimes fail to reach BROKER_ONCE_PASS before timeout.
   - FACT: the storage JSON has demonstrated valid readings for all three SSDs, while Main correctly marks disk temperature unavailable when that data becomes stale.
   - INFERENCE / HIGH CONFIDENCE: the failure is a one-shot completion/exit-latency contract problem around LibreHardwareMonitor storage teardown/worker termination plus an overly tight 12-second Supervisor budget, not inability to discover the disks.
   - EXACT NEXT ENGINEERING ACTION: R32-1 must change storage acceptance so fresh validated output is not discarded merely because process exit lags near the timeout, define a measured timeout/hysteresis policy, reap lingering workers safely, and add slow-exit/timeout/backoff regression tests.

2. GPU NVML DRIVER-TRANSITION CRASH - CONTAINED / HARDENING GATE.
   - FACT: on 2026-09-30 at 14:56:55 the isolated SensorBroker terminated with AccessViolationException in LibreHardwareMonitor NvidiaML.NvmlDeviceGetPowerUsage / nvml.dll.
   - FACT: Windows UserPnp events at 14:56:53-14:56:54 show NVIDIA display-driver services being re-added for the same RTX 3080 immediately before the crash.
   - FACT: the crashing NVML was version 8.17.16.1656; current NVML is 8.17.16.1714 and the old DriverStore copy is no longer present.
   - FACT: GPU broker recovered to READY within seconds and Main remained operational; no other TBME Application/.NET crash was found from the v1.2.0 release window through this audit.
   - INFERENCE / HIGH CONFIDENCE: the incident is strongly correlated with an NVIDIA driver transition/update, while exact culpability between driver/NVML and LHM call timing remains unproven.
   - PROPOSAL: add a display-driver-transition regression lane and bounded GPU worker quarantine/backoff around repeated native faults; do not weaken process isolation.

3. START-WITH-WINDOWS REDUNDANCY - LIVE STATE REPAIRED / CODE GAP OPEN.
   - FACT: config had StartWithWindows=true and the recovery Startup shortcut was valid, but the primary HKCU Run value was absent at audit start.
   - FACT: startup logs did not show a STARTUP_RUN write error at the current Main start, so the later remover is unproven.
   - FACT: StartupManager repairs registrations only when a new primary instance reaches SetEnabled; a recovery invocation exits early if an existing primary is already running. There is no continuous registration watchdog.
   - FACT: R32 preserved prestate, removed the orphan predecessor taskbar-monitor StartupApproved entry, restored the exact expected TaskbarMonitorEnhanced HKCU Run value, and verified poststate PASS.
   - PROPOSAL: bounded periodic self-check/repair while StartWithWindows=true, with explicit tests for deletion after startup.

4. PUBLIC TRUST SIGNING - OPEN EXTERNAL GATE.
   - FACT: v1.2.0 is functionally/public-release accepted but remains unsigned. SignPath/public-trust acceptance is not proven.
   - PROPOSAL: complete an external trusted signing provider workflow only for a newly versioned release or a release whose exact published artifact was already signed before publication; never rewrite immutable historical assets.

5. MAINTAINABILITY / TEST ARCHITECTURE - DEBT, NOT CURRENT RELEASE BLOCKER.
   - FACT: src\TaskbarMonitorEnhanced.cs is approximately 7,638 lines and centralizes many UI, telemetry, update, proof, and configuration responsibilities.
   - FACT: no xUnit/NUnit/MSTest project was found; quality assurance is dominated by built-in CLI proofs, deterministic build gates, and integration/runtime acceptance.
   - PROPOSAL: after R32-1 runtime health, split high-risk subsystems behind testable interfaces and add focused unit tests while retaining existing end-to-end proofs.

### Current status and critical path

- Historical v1.2.0 release acceptance: PRESERVED / IMMUTABLE.
- Repository/build integrity: PASS.
- PC-wide project consolidation: PASS.
- Current UI/taskbar/CPU/GPU operation: PASS at audit time.
- Current full sensor-health claim: FAIL / DEGRADED because storage lane is in timeout/backoff.
- Current public trusted signing: PENDING EXTERNAL PROVIDER.
- Critical path: R32-1 Storage completion/timeout contract -> R32-2 startup continuous self-heal -> GPU driver-transition hardening -> maintainability/test decomposition. Public trusted signing is a parallel external gate.
- Exact next action: implement and validate R32-1 without mutating v1.2.0 tag/assets; require build, selftest, storage fault/slow-exit regression, live health PASS, and downstream CPU/GPU/taskbar regression before promotion.

### R32 evidence roots

- .local\audit\2026-10-01
- .local\history
- .local\archive
- .local\infrastructure
- .local\forensics
- .local\runtime-snapshots\2026-10-01



## CURRENT AUTHORITY — 2026-09-26 FINAL RUNTIME ACCEPTED

This section supersedes older Current authority, Current installed state, Current critical gate, UNPROVEN/PENDING, and Exact next action sections below where they conflict. Those older sections are retained as historical provenance.

- Final objective remains immutable public v1.1.2 with deterministic build, exact install/runtime acceptance, GitHub provenance/SBOM attestation, immutable publication, then control-plane closeout.
- Current branch: release/v1.1.2-final.
- Final source authority: 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6.
- Accepted RC10 precursor: eac234860c31d8e2a6c0ba7d61c7bf5248717db5.
- Final identity behavior equivalence: PASS 7/7.
- Final build/determinism/SBOM: PASS.
- Exact installed v1.1.2 identity/hashes/config preservation: PASS.
- Proportional final runtime regression R2: PASS.
- Installed identity: 1.1.2 / V1_1_2_R21_PRODUCTION_HARDENING / 1.1.2+r21 / READY.
- Exact final hashes:
  - Main DFF69CFC96C0A0567DD32C04EBD45414CFF045172A76A84EE1060814921DFE9E
  - Broker 182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833
  - Supervisor 38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196
  - Setup 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB
  - SBOM B324745F6041FA8E8C8FA888977B40B41100B787C6A8E087ED80EB23AC148578
- Runtime: freshness R2 6/6 healthy (0.188–4.573 s); taskbar 12/12 direct Shell_TrayWnd 1100x48; Main RID8192; LHM-in-Main=0; protected PE GUI=2/2; sensor conhost=0; relevant Application/TaskScheduler errors=0.
- RC10 soft/hard stall, post-fault soak and real S3 acceptance are inherited via 7/7 behavior equivalence and were not blindly rerun.
- Known harness failure/prevention: ConvertFrom-Json timestamp auto-conversion plus local string reparse created +03:30 false age. Prevention: -DateKind String plus round-trip DateTimeOffset.
- Current critical path: GitHub exact-final attestation → accepted control commit/push → immutable v1.1.2 Stable/Latest publication → final Brain/Knowledge closeout.
- Public Stable/Latest remains v1.1.1 until the publication gate closes.
- Exact next action: run/verify exact-final GitHub provenance+SBOM workflow from the accepted final authority/control commit; do not rebuild or reinstall locally unless an attestation discrepancy requires it.

## CURRENT AUTHORITY — 2026-09-26 GITHUB ATTESTED / PUBLICATION READY

This section supersedes older current-state sections where they conflict; historical sections remain provenance.

- Immutable v1.1.2 release authority: aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0.
- Behavior/build authority: 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6.
- Final local build/runtime: PASS.
- GitHub workflow run 36244774522: PASS, including deterministic clean-clone build, SPDX generation, binary provenance attestation, Setup-SBOM attestation and evidence upload.
- GitHub evidence artifact 10907450490: binary hashes PASS 4/4 exact.
- SBOM raw hash differs by document-instance fields only; semantic normalized hash PASS at BFBB7FB00FF3C8DD9ED26DBD17C0E3CAED5B4F666BE5373E7C329549AEEB7BAA.
- Initial GitHub run 36244394685 failed before build from shallow checkout; root cause fixed with minimum sufficient fetch-depth 2 and fresh run PASS.
- Public v1.1.2 tag/release was absent at pre-publication audit.
- Critical path: create immutable v1.1.2 at exact attested commit -> verify assets/Latest -> final Brain/Knowledge closeout.
- Exact next action: publish v1.1.2 once at aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0 with exact accepted assets; never move/force the tag.

## CURRENT AUTHORITY — FINAL v1.1.2 PUBLIC RELEASE ACCEPTED

This section is the final current authority for v1.1.2 and supersedes older current-state/open-gate sections where they conflict. Historical sections remain provenance.

- Project lifecycle: FINAL for v1.1.2 Definition of Done.
- Brain Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
- Behavior/build authority: 5916db0ef7fe19fea8cc13ebde73d01021d7c3d6.
- Immutable public release authority: tag v1.1.2 -> aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0.
- Publication-control commit before release: d9f3ed150abab77d0ecce7a88cc71ed150f9a42d.
- Public release: https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.2.
- Release is non-draft, non-prerelease and Latest/Stable.
- Release assets: 8/8 uploaded; 0 digest mismatches; 0 size mismatches.
- Exact Setup SHA256: 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB.
- GitHub CI/provenance/SBOM attestation: PASS.
- Local install/runtime acceptance: PASS.
- RC10 soft/hard watchdog, post-fault soak and physical S3 remain inherited PASS via tracked 7/7 behavior equivalence.
- SPDX raw document hashes differ only by documentNamespace/git-head and creation timestamp; semantic-normalized hash is identical and PASS.
- Open blockers: none.
- Open gates: none.
- Exact next action: none for v1.1.2. Any future change starts a new maintenance/release scope; do not move or overwrite tag v1.1.2.
## Project definition

Taskbar Monitor Enhanced is a Windows taskbar-integrated hardware/system monitor. R21 hardens the product for long-run daily use: isolated native hardware-sensor access, bounded self-healing, windowless protected sensor workers, least-privilege Main UI, deterministic builds, auditable supply-chain provenance and safe installation/update behavior.

## Final Objective / DoD

Release immutable public v1.1.2 only when the exact final source/build/install identity has:
- zero-warning/zero-error reproducible build and clean-clone byte determinism;
- pinned LibreHardwareMonitor/PawnIO dependency hashes and SPDX SBOM;
- Main at Medium integrity with no LibreHardwareMonitor loaded in Main;
- protected Broker/Supervisor in Program Files, windowless PE GUI subsystem, correct Job containment and scheduled-task policy;
- truthful CPU/GPU/storage telemetry with 15-second UI freshness;
- bounded recovery from transient sensor stalls without restart storms and a hard watchdog for true stalls;
- real S3 suspend/resume acceptance with no false freshness failure;
- taskbar geometry/module/EventLog/runtime soak acceptance;
- exact GitHub provenance/SBOM attestations and immutable release assets;
- clean Start Menu/startup/uninstall surface;
- current cumulative Brain and acceptance evidence sufficient for account transfer.

## Current authority

- Public Stable/Latest: **v1.1.1**. Do not supersede until final v1.1.2 gates close.
- Current engineering candidate: **v1.1.2-rc10 / R21 CPU slow-read hardening**.
- Current branch: `audit/r21-final-hardening-rc10`.
- Source authority: `e89aebd9012f95d050771283562069f9cb5f5515`.
- Parent accepted source before RC10 mutation: RC9 `220e49824a8ccb89192e0ab173860e016c2ca7d9`.
- RC10 binary-source self-hosted GitHub run: `35460297804` = SUCCESS at `e89aebd...`.
- RC10 control-head self-hosted GitHub run: `35460716964` = SUCCESS at `238d93e...`.
- RC10 draft prerelease target: `238d93eeeadd83e31aa1de002cf00dee0778da41`, draft/prerelease only; binary source authority remains `e89aebd...` because the later commit changes only control records.
- Repository immutable releases policy is enabled.
- Local project root: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced_R20`.
- Protected sensor root: `C:\Program Files\TaskbarMonitorEnhanced\SensorBroker`.
- User runtime root: `C:\Users\Aa.Emad\AppData\Local\TaskbarMonitorEnhanced`.

## Current RC10 deterministic outputs

- Main: `6BBD6BF7A559DE4C2C59FE4027FA2BA30EC82765B3C6F4000FF34375C72B2550`
- Broker: `7BA4E75514D69EC20D7FD478C3F8769A2D22BB48AC1B19900D946DF4FB64D907`
- Supervisor: `FE5EB08FC2ED2D2C7CAA70F7EA48965C409E2093E3BB054CE8AE60003D85D97D`
- Setup: `488FAC9FE5C98943F8A90DE58EBF70B999EE0C4AD4E01933B0090FDEA73BC400`
- SPDX SBOM: `E3659486DA78AE92E9F079EE76E10DF65518A3A5C25E00811A1B78C1958D894B`
- Manifest: `RC_MANIFEST_v1.1.2-rc10.json`
- Hash list: `SHA256SUMS_v1.1.2-rc10.txt`

## Roadmap and current position

Lifecycle:
DISCOVERY → DEFINITION → BASELINE → DEVELOPMENT → VERIFICATION → **VALIDATION/ACCEPTANCE (CURRENT)** → DELIVERY/RELEASE → CLOSURE → FINAL

Evidence-backed completed:
1. R21 architecture/process isolation and protected sensor boundary.
2. Deterministic build pipeline, dependency lock, SBOM generator, self-hosted attestations.
3. Main taskbar/UI feature baseline and module isolation.
4. RC7 transient output-observation-gap fix and windowless Broker/Supervisor.
5. RC8 least-privilege Main launch boundary.
6. RC9 official Windows suspend/resume notification integration.
7. RC9 deterministic Setup canonical text staging.
8. RC9 installer single-instance/state-integrity hardening.
9. RC9 real S3 test: physical suspend/wake occurred; resume notification observed; no worker failure during resume; post-health PASS.
10. RC10 source/build/determinism/SBOM/self-hosted GitHub supply-chain gates.

Current critical gate:
**Obtain a new explicit administrator-consent approval, then install exact protected RC10 pair and execute fault-injection/runtime acceptance.**

Remaining after RC10 protected install:
- 25-second soft-stall fault injection: no CPU restart; UI freshness remains truthful; same worker recovers.
- >60-second hard-stall fault injection: hard watchdog must restart stuck CPU worker and recover.
- post-fault runtime soak with stable restart counters and zero new failures.
- real S3 regression on installed RC10.
- taskbar/module/EventLog/windowless/integrity regressions on installed RC10.
- update acceptance/Brain to RC10 accepted state.
- derive exact final v1.1.2 identity from accepted RC10, rebuild/determinism/install/attest/revalidate and only then publish immutable Stable/Latest.

## Current installed state — IMPORTANT

The attempted protected RC10 elevation reached Windows Secure Desktop, but Windows returned **"The operation was canceled by the user."** Per fail-closed policy it was not automatically retried.

A transactional rollback was then completed with the exact accepted RC9 Setup:
- RC9 Setup SHA-256: `48DADB48072344E4627A939971313B931E84365A0311F79E48FC793BB029CBC8`.
- installed Main: `911D5F6303BB6CBA48FB1D9651B4CADB541A62BB6781E57312FEA52E913AE59D`.
- installed Broker: `5D4824409E34794467340741A88EE0B1EC390ADE9F090D33B5746DD92081CB9C`.
- installed Supervisor: `A0A7C711BEC1F920DB8107E4700FCA886EF7E6869E987546D0938DBEA69DFDB5`.
- `install_state.json`: `1.1.2-rc9 / READY / CURRENT_EXACT_RC9`.
- post-rollback HealthProbe: `PASS / STABLE / ActiveConsecutiveFailures=0`.
- runtime tree: 1 Supervisor, 2 persistent Brokers, 0 sensor-owned console children.
- no Setup orphan remains.

Therefore the user's live machine is back on the last accepted runtime baseline and is **not left degraded**. RC10 remains a development candidate whose exact protected installation requires a new explicit future administrator consent before runtime/fault-injection acceptance can proceed.

## Why RC10 exists

After RC9's real-S3 resume race was fixed, a post-S3 90-second soak found a separate recurring CPU sensor stall:
- `17:55:35Z WORKER_FAILURE CPU STALE_OUTPUT_16.0S`
- `17:56:12Z WORKER_FAILURE CPU NO_CURRENT_OUTPUT_AFTER_GRACE`
- recovery at `17:57:41Z`.

Broker log showed no `BROKER_FATAL`; the worker stayed alive and was likely blocked in LibreHardwareMonitor/PawnIO hardware access. An isolated 8-case CPU/storage contention probe did not reproduce a timeout, so simple storage concurrency is UNPROVEN. Active MSI Center/Mystic Light services are a possible external contention source but are not proven root cause and must not be disabled automatically.

Windows ACPI thermal-zone fallback was rejected: available ACPI temperature was not representative of CPU Package temperature.

RC10 therefore separates data freshness from process-watchdog policy:
- UI/Main CPU temperature freshness remains **15 seconds**; stale data becomes unavailable/N/A.
- CPU Supervisor hard-stall budget is **60 seconds**.
- CPU startup grace is **60 seconds**.
- GPU keeps the established 15-second hard behavior.
- soft CPU stalls are observable via `CpuSlowOutputActive` / `WORKER_SLOW_OUTPUT`;
- recovery logs `WORKER_SLOW_OUTPUT_RECOVERED`;
- true >60s stalls still cause bounded restart.

This avoids hiding stale telemetry while reducing restart storms caused by transient low-level sensor delays.

## Verification state

RC10 PASS:
- App/Broker/Supervisor/Setup: 0 warnings / 0 errors.
- Main self-test: PASS, includes `CPU_HARD_STALL_WATCHDOG_SEC=60`.
- Setup resource/policy verify: PASS.
- Sensor PE windowless guard: PASS.
- Canonical text payload gate: PASS.
- Clean-clone byte determinism: PASS.
- SPDX 2.3 SBOM generation: PASS.
- GitHub self-hosted run `35460297804`: SUCCESS.
- GitHub steps build/determinism/SBOM/provenance/Setup-SBOM/evidence-upload: SUCCESS.
- RC10 draft evidence assets uploaded; public release not promoted.

RC10 UNPROVEN/PENDING:
- exact protected RC10 install;
- soft/hard watchdog fault injection;
- post-fault soak;
- real S3 on installed RC10;
- final installed RC10 taskbar/module/EventLog regression;
- final public v1.1.2 identity/release.

## Historical failure / prevention record

- RC6 false `NO_CURRENT_OUTPUT_AFTER_GRACE`: single transient missing file observation triggered restart. Prevention: last-known-good freshness handling; regression protects short gaps.
- RC7 CUI console window: Scheduled Task launched console-subsystem Supervisor. Prevention: Broker/Supervisor WinExe + PE subsystem build guard.
- RC8 elevation inheritance: whole elevated Setup could auto-launch high-integrity Main. Prevention: elevated Setup never auto-launches Main; normal Setup keeps Main Medium integrity.
- RC8 real-S3 race: stale GPU evaluation occurred before long-gap detection. Prevention: Windows suspend/resume callback plus transition deferral; RC9 physical S3 passed.
- RC9 Setup determinism: raw CRLF/LF text resources changed Setup bytes across checkout policies. Prevention: canonical UTF-8/LF embedded-text staging.
- RC9 installer state race: parallel Setup invocations could delete shared sensor result and write DEGRADED after successful helper. Prevention: single-instance Setup mutex + unified sensor version constant.
- RC9 post-S3 CPU stalls: recurring ~15s LHM/PawnIO CPU read stalls caused restarts. RC10 prevention under validation: 15s data freshness, 60s CPU hard watchdog.
- Do not disable MSI Center/Mystic Light or other unrelated user services without separate evidence/approval.

## Authoritative vs superseded

Authoritative/current:
- branch `audit/r21-final-hardening-rc10`
- commit `e89aebd9012f95d050771283562069f9cb5f5515`
- `build/Build-R21.ps1`
- `build/Verify-Determinism.ps1`
- `build/Generate-Sbom.ps1`
- `.github/workflows/r21-rc10-selfhosted-finalize.yml`
- `RC_MANIFEST_v1.1.2-rc10.json`
- `SHA256SUMS_v1.1.2-rc10.txt`

SUPERSEDED — DO NOT RUN as current candidate:
- RC6/RC7/RC8/RC9 release workflows, manifests and runners.
They remain historical provenance/evidence only.
- Public v1.1.1 remains valid rollback/stable authority until v1.1.2 is actually accepted and promoted.

## Key evidence

- `r21_evidence/RC9_REAL_SUSPEND_RESUME.json` — RC9 physical S3 PASS.
- `r21_evidence/RC9_POST_S3_SOAK_90S.json` — RC9 CPU-stall failure evidence; must be preserved.
- `r21_evidence/rc9_contention_probe/RC9_SENSOR_CONTENTION_PROBE.json` — simple storage contention not reproduced.
- GitHub RC10 run `35460297804`.
- RC10 draft prerelease and its build manifest/SBOM/evidence ZIP.
- Local cumulative knowledge/evidence under `%LOCALAPPDATA%\TaskbarMonitorEnhanced\00_PROJECT_CONTROL`.

## Risks / hinges

- Windows Secure Desktop UAC is the current owner gate for replacing Program Files protected binaries. The latest consent was canceled by the user; Remote Commander must not automatically retry or bypass that denial.
- LibreHardwareMonitor/PawnIO may experience transient hardware-access stalls on this MSI Z790 environment; RC10 watchdog semantics require real fault-injection and soak proof.
- Public Stable/Latest promotion is irreversible in practice under immutable-release policy; promotion is forbidden until exact final v1.1.2 identity is revalidated.

## Exact next action

1. Provide a new explicit administrator-consent approval for the hash-pinned RC10 Setup. The previous UAC was canceled and will not be retried automatically.
2. Verify installed Broker/Supervisor hashes equal the RC10 manifest and `install_state=READY/CURRENT_EXACT_RC10`.
3. Run RC10 soft-stall and hard-stall fault injections, then post-fault soak.
4. Run real S3 and full installed regressions.
5. If all PASS, record accepted RC10, derive final v1.1.2 identity, rebuild/determinism/install/attest/revalidate, then publish immutable Stable/Latest.

## Account-Transfer Test

PASS for understanding/continuation: a new account can identify project goal, root, current branch/commit, installed mixed state, historical failures, current blocker, release-chain status, remaining gates and exact next action from this Brain alone.

## HISTORY

- v1.1.1: current public stable/rollback authority.
- R21: process-isolated protected sensors, deterministic builds, supply-chain hardening and diagnostics.
- RC7: output-gap and windowless sensor fixes.
- RC8: Main integrity/elevation boundary.
- RC9: official power notification, deterministic Setup and installer state-integrity fixes; real S3 PASS but post-S3 CPU stall recurrence.
- RC10: CPU 15s freshness / 60s hard-stall separation. Build/determinism/SBOM/self-hosted CI PASS; protected-install consent was canceled, live system was rolled back cleanly to accepted RC9, and RC10 runtime validation remains pending.

- 2026-09-26 R22: final v1.1.2 identity equivalence 7/7 PASS; deterministic build/SBOM PASS; exact final install PASS with config preserved; proportional runtime R2 PASS after correcting known PowerShell timestamp harness false negative. GitHub publication remains the critical path.


## CI FAILURE / PREVENTION — 2026-09-26 RUN 36244394685

- Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
- Failed GitHub run: 36244394685 at control commit 483367af265eae8bd6043c11570f8f6be58531de.
- Failure point: Git whitespace check before any build or attestation step.
- Exact error: fatal: ambiguous argument HEAD^: unknown revision or path not in the working tree.
- Root cause: actions/checkout defaults to fetch-depth 1, while the next step requires parent commit HEAD^.
- Prevention: keep the pinned checkout action and add only fetch-depth: 2, the minimum history required by the official actions/checkout HEAD^ scenario.
- Regression: a fresh push run must pass whitespace, build, determinism, SBOM, provenance, Setup-SBOM and evidence upload; downloaded artifact hashes must match the already accepted final hashes.
- The failed run is not rerun blindly. Critical path remains GitHub attestation -> immutable v1.1.2 publication -> final closeout.

- 2026-09-26 R22 FINAL: v1.1.2 published and post-verified as immutable Latest/Stable at aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0; 8/8 release assets digest/size verified; no open DoD gate.

## CURRENT MAINTENANCE — R23 DEVELOPMENT CODE SIGNING

This maintenance scope does not modify the immutable v1.1.2 release.

- Branch: maintenance/code-signing.
- Development Authenticode identity: CN=Taskbar Monitor Enhanced Development Code Signing.
- Thumbprint: 4673165CCB579F868EFE5F52FCDA761780F49989.
- Certificate: RSA / sha256RSA / Code Signing EKU.
- Private key: CurrentUser\My only; not exported and not committed.
- Public certificate SHA256: 217EC08DF0C2A23F9AEB3925FA40D7561FC21DE61039458514067FAAC0753A10.
- Signing probe: PASS on an evidence copy only; signed probe SHA256 65168AD41EAA0C5B562FACE9E3DDEBACDA9EBC38606C94C42D4E9C55AA6AAFCD.
- Verification negative tests: unsigned file rejected; tampered signed copy rejected.
- Windows trust result: UnknownError because the self-signed development root is not publicly trusted. This is expected and is not presented as Trusted Publisher status.
- Immutable v1.1.2 Setup remains 25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB; tag remains aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0.
- Development signing tooling supports SHA256 Authenticode and optional RFC3161 timestamping.
- Public-trust blocker: obtain a CA-issued Code Signing certificate or approved managed signing identity.
- Exact next action for a publicly trusted signed release: use the CA identity to sign binaries before packaging, sign/timestamp installer last, regenerate hashes/SBOM/attestation and publish a NEW version. Never rewrite v1.1.2.

## CURRENT MAINTENANCE — R24 PUBLIC-TRUST SIGNING READINESS

This section supersedes R23 as the current maintenance authority where they conflict. Immutable public v1.1.2 remains unchanged.

- Working branch: `maintenance/signpath-readiness`, based on accepted R23 commit `41963f94013ecb8745897839ccc6e9b220be5d71`.
- Public-trust route selected: SignPath Foundation open-source signing application. Acceptance is external and PENDING; no release is claimed SignPath-signed.
- Repository is public; GitHub account `GOD13emad` has 2FA enabled.
- Root license declaration remains GPL-3.0-or-later; truncated root LICENSE was replaced with the already-accepted full GNU GPL v3 text without changing the declared license family.
- README and DOWNLOAD now expose the exact Code signing policy terminology, required SignPath provider attribution, privacy link, immutable-release rule, and explicit install/uninstall instructions.
- Actual updater/privacy audit: default HTTPS release check targets GitHub Releases API and can be disabled; installer download requires user confirmation; monitoring telemetry/config/hardware readings are not uploaded to a project-operated service.
- Actual PE metadata gate: PASS for Main, Broker, Supervisor and Setup. ProductName = Taskbar Monitor Enhanced; ProductVersion = 1.1.2+r21; FileVersion = 1.1.2.0; Company/FileDescription populated.
- Actual uninstall gate: PASS from installer source. Windows per-user Installed apps registration includes DisplayName, DisplayVersion, Publisher, UninstallString and QuietUninstallString; uninstaller path is `%LOCALAPPDATA%\TaskbarMonitorEnhanced\Uninstall.exe`.
- SignPath application surface: `https://signpath.org/apply.html`, HubSpot portal `145110231`, form `bf62807d-bb72-4e45-9bde-1f3a53ba2472`; browser page loaded and Tagline/Description fields were observed.
- Hard external interaction gate: Remote Commander rejects browser input with `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`. Chat authorization cannot override this platform gate. Application submission therefore remains NOT SUBMITTED.
- Prepared application packet: `docs/security/SIGNPATH_APPLICATION_PACKET.json`, status `READY_TO_SUBMIT_DIRECT_USER_GUI_ACTION_REQUIRED`.
- Immutable release regression remains PASS: tag v1.1.2 -> `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`; Setup SHA256 `25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB`.
- Publicly trusted signature Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
- Current critical path: commit/push readiness docs -> fast-forward default `main` to the accepted readiness commit without force -> verify immutable release -> user/direct-GUI submission of SignPath application -> SignPath Foundation review/acceptance -> create a NEW signed release, never rewrite v1.1.2.

## R24 REPOSITORY-SIDE READINESS CLOSEOUT

- Repository readiness commit: `b6c13838624e99d1d6ba4811b295834e22e45947`.
- `origin/main` and `origin/maintenance/signpath-readiness` were both verified at that commit after an ordinary non-force fast-forward of main.
- GitHub Actions exact run `36250864888` for head SHA `b6c13838624e99d1d6ba4811b295834e22e45947`: COMPLETED / SUCCESS.
- CI job `build`: all steps PASS, including checkout, whitespace, reproducible build, deterministic clean-clone verification, SPDX SBOM generation, binary provenance attestation, Setup SBOM attestation and evidence upload.
- Repository-side SignPath Foundation readiness: PASS.
- External application state: NOT SUBMITTED. Remote Commander browser input is blocked by `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`; this platform gate cannot be bypassed by chat authorization.
- Publicly trusted Authenticode release state: PENDING external SignPath Foundation review/acceptance and a future NEW release. Development self-signed signing remains test-only.
- Immutable public v1.1.2 remains unchanged: tag `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`, Setup SHA256 `25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB`.
- Exact next action: in a direct user browser session, submit the already-prepared SignPath application using `docs/security/SIGNPATH_APPLICATION_PACKET.json`; after external acceptance, create and validate a separately versioned signed release. Never rewrite v1.1.2.

## R24 FINAL SIGNPATH APPLICATION GATE

- Official application surface re-audited from public SignPath/HubSpot resources: portal `145110231`, form `bf62807d-bb72-4e45-9bde-1f3a53ba2472`, region `eu1`.
- Public render-definition SHA256: `bf122cf482f6887667fb30661e3be8bafdcdac0c15c05c5a79a72f5337aeb570`.
- Exact required fields are known and prepared in `docs/security/SIGNPATH_APPLICATION_PACKET.json`, including Project/Repository/Homepage, Tagline, Description, Reputation, Build System, First/Last Name, Email and Discovery Channel.
- Truthful reputation audit: this new repository currently has 0 stars, 0 forks, 0 subscribers and 0 v1.1.2 release-asset downloads. No adoption claim is made. Declared GPL upstream `leandrosa81/taskbar-monitor` currently has 540 stars, 42 forks and 13 subscribers; those metrics are recorded only as upstream heritage.
- Trust evidence supplied instead of inflated adoption claims: deterministic clean-clone GitHub Actions build, SPDX 2.3 SBOM, GitHub build/SBOM attestations, immutable SHA256 release manifests and documented Windows runtime acceptance.
- Required first-person external attestations identified:
  1. agree to SignPath Foundation Code of Conduct and certificate-revocation terms;
  2. agree to SignPath storage/processing of personal data.
- Optional SignPath marketing consent remains intentionally unchecked unless separately requested.
- Form also contains reCAPTCHA2. It is a human anti-bot control and must not be bypassed or solved programmatically.
- User explicitly authorized mouse/keyboard use in the current chat. ChatGPT app permission for Remote Commander is already `Allow all actions`; server reports GUI mouse/keyboard capability and `explicit-current-request-only`.
- Connector limitation: the tool schema exposed to this ChatGPT session for `gui_session_begin` accepts only `ttlSeconds` and always creates an observe-only lease. The server-side intended takeover parameters (`mode=takeover`, `explicitUserAuthorization`) are not exposed through this session. Direct takeover therefore cannot be acquired; workflow takeover is separately blocked by `WORKFLOW_GUI_TAKEOVER_REQUIRES_DIRECT_USER_SESSION`.
- Security decision: no raw MCP request, SendInput, UIAutomation, Chrome DevTools Protocol or shell-based injection will be used to circumvent the takeover/CAPTCHA gates.
- Official application and Code of Conduct pages were opened on the user's Windows desktop; application page was reopened as the newest browser tab.
- Application Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
- Repository-side public-signing readiness remains PASS. Publicly trusted signing remains PENDING SignPath submission/review/acceptance and a future NEW signed release. v1.1.2 remains immutable.
- Exact next action: user must personally attest the two mandatory consent statements and complete reCAPTCHA on the already-open official form. After submission evidence is available, update packet/Brain and proceed with SignPath review/acceptance and a new signed release.

## R25 / v1.1.3 STARTUP RESILIENCE — LOCAL ACCEPTANCE

- Trigger: after a real power-loss/restart event, application configuration still had `StartWithWindows=true` and Windows StartupApproved was enabled, but the actual HKCU Run value `TaskbarMonitorEnhanced` was absent. The protected sensor supervisor still started independently. The exact external remover of the Run value remains UNPROVEN.
- Bootstrap defect in v1.1.2: Main could repair its Run value only after Main was already running; losing the sole Main launch registration therefore prevented self-heal.
- v1.1.3 design: two independent per-user registrations when Start with Windows is enabled:
  1. primary HKCU Run value for immediate launch;
  2. current-user Startup-folder recovery shortcut invoking `--startup-recovery`.
- Recovery behavior: waits up to 12 seconds for the primary launch path, exits early if a primary process exists, otherwise continues normal startup. Existing named mutex remains the final single-instance guard.
- Mutual repair: surviving Run launch recreates a missing recovery shortcut; surviving recovery shortcut launches Main and Main recreates the missing Run value. Disabling Start with Windows removes both. Uninstall source removes both.
- Privilege decision: a Scheduled Task fallback was rejected after a real non-elevated `schtasks /Create /SC ONLOGON` probe returned Access Denied. The accepted fallback is per-user Startup-folder based and requires no administrator privilege.
- Code + visual candidate commit: `bcbd8f8e8861e4e4a83350699214f1bb83b1132e`, branch `release/v1.1.3-startup-resilience`, parent `9fcfcd389eea85e2ccbdf03ce6cdfe8b99463e9b`.
- Build identity: `V1_1_3_R22_STARTUP_RESILIENCE`; public version 1.1.3.
- Local build gates: four project builds PASS with 0 warnings / 0 errors; Setup verify PASS; built-in selftest PASS; sensor windowless PE PASS; canonical text payload PASS; SPDX 2.3 SBOM PASS.
- Clean-clone deterministic verification on exact commit `bcbd8f8...`: `R21_REPRO_BUILD=PASS`, `R21_DETERMINISM=PASS`.
- Exact outputs at local acceptance:
  - Main: `74E7725E3C3911EFEDEC1181C21AF07571C9A22CD758EE50E06EA1373DAB7317`
  - Broker: `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833`
  - Supervisor: `38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196`
  - Setup 1.1.3: `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`
  - SBOM: `651057410EB57090E1D7ED5EB9522AB8B40284D484CAB0A1C9ADA4DC1833E192`
- Protected sensor layer remains accepted `1.1.2+r21`; exact Broker/Supervisor hashes were unchanged after v1.1.3 install; install state READY / CURRENT_EXACT_1_1_2.
- Live startup fault injection:
  - missing Run -> recovery path -> Run recreated, one Main: PASS;
  - missing recovery shortcut -> normal launch -> shortcut recreated with exact target/argument, one Main: PASS;
  - recovery launch while primary running -> fallback exit 0, same sole primary PID: PASS;
  - StartWithWindows=false -> both registrations absent and app usable; original true setting restored and both registrations returned: PASS.
- Visual qualification: all 14 themes regenerated by the real v1.1.3 renderer from 30 live samples with `NoSyntheticMetricData=true`; theme proof PASS. Compact proof PASS at 592 px and 500 px with zero recorded overflow. Current proof images/manifests are published under `docs/screenshots/themes` and `docs/screenshots/compact`.
- Sanitized acceptance record: `docs/acceptance/v1.1.3/STARTUP_RESILIENCE_ACCEPTANCE.json`.
- Immutable regression: v1.1.2 tag still `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`; v1.1.2 Setup SHA256 still `25744A0A0F78B787A5FC3601577748B80353ADC9DAFB9FE91A111A53C56216FB`.
- Signing: v1.1.3 remains UNSIGNED unless independently verifiable public-trust Authenticode evidence exists. SignPath readiness does not equal provider acceptance.
- Current state: LOCAL ACCEPTANCE PASS. Public release is not yet claimed until final metadata commit, exact-head GitHub CI success, immutable tag/release creation, and remote asset digest verification complete.
- Exact next action: commit release-control docs -> determinism on exact metadata head -> non-force push branch/main -> exact-head GitHub CI -> immutable v1.1.3 release -> post-release digest/immutability seal.

## R25 / v1.1.3 PUBLIC RELEASE CLOSEOUT — 2026-09-27

- Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
- Immutable release tag `v1.1.3` points exactly to `fa8c75d0b59343ccb7eae86320a351e3b4064c48`; no force push or tag rewrite was used.
- GitHub release: `https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.1.3`; published 2026-09-27T10:06:33Z; Latest=true; Draft=false; Prerelease=false.
- Exact-head GitHub Actions PASS on both pushed refs: main run `36311195266` and release-branch run `36311191121`. Both passed whitespace, reproducible build, deterministic clean clone, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload and manifest gates.
- GitHub main CI artifact `10929282504`, digest `sha256:537d6d902e9b99cc6fa5c8337606a7609a52e89d22b953e1c777a74ba0dab1bc`; downloaded Main/Broker/Supervisor/Setup binaries matched the accepted local hashes 4/4 exactly.
- Public release assets: 7/7 digest+size verification PASS. Setup SHA256 `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`; source ZIP SHA256 `D6B3B99AEEE7B3E816D94ECE6C41F25FDF338833923AFB08A3A4B29907F227CA`.
- Published SPDX raw document SHA differs from the exact-head CI SPDX raw document because generated document namespace/time fields differ. Semantic normalization over SPDX identity/version, packages, file hashes and relationships is identical: SHA256 `2e5375bfa63263162953f2c2a7a8c98b7cc4729bbb871cc7aad9f90b3c4238a1`; semantic equivalence PASS. Exact-head CI generated and attested its own SBOM at the release commit.
- Startup resilience acceptance remains PASS: missing Run self-heal, missing recovery-shortcut self-heal, duplicate recovery early exit, StartWithWindows=false cleanup, and restoration of the user's enabled state all passed.
- Visual qualification remains PASS: 14/14 themes, 30 live samples, NoSyntheticMetricData=true; 592 px and 500 px compact proofs have zero LayoutChecks overflow.
- Accepted protected sensor layer remains `1.1.2+r21`, READY, with Broker/Supervisor hashes unchanged.
- Public-trust signing remains PENDING external provider acceptance; v1.1.3 is not claimed as SignPath-signed and may show Unknown publisher.
- Immutable v1.1.2 regression remains PASS: tag `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`; Setup digest `sha256:25744a0a0f78b787a5fc3601577748b80353adc9dafb9fe91a111a53c56216fb`.
- Non-blocking CI maintenance note: GitHub reports that the pinned upload-artifact action declares Node.js 20 and is currently forced to Node.js 24. It did not fail any release gate.
- Final public acceptance record: `docs/acceptance/v1.1.3/PUBLIC_RELEASE_ACCEPTANCE.json`.
- Critical path for v1.1.3: CLOSED. Future public-signing work must create a separately versioned signed release and must not rewrite v1.1.3.

## POST-RELEASE CI MAINTENANCE — NODE 24 ACTION PIN

- 2026-09-27 mutation: replace pinned `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02` (v4 / Node.js 20 declaration) with official `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` (v7.0.1 / Node.js 24).
- Motivation: remove the non-blocking GitHub Actions Node.js 20 deprecation annotation observed on all accepted v1.1.3 CI runs.
- Source verification: official actions/upload-artifact latest release is v7.0.1, published 2026-04-10; tag resolves directly to commit `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`; `action.yml` declares `using: node24`.
- Scope: CI workflow only. Immutable release tag `v1.1.3` and its seven assets remain unchanged.
- Validation state at mutation: PENDING exact main CI. Do not call this maintenance PASS until the new commit completes the full R21 workflow without the Node.js 20 annotation.

### NODE 24 ACTION PIN VALIDATION — PASS

- Exact maintenance commit `1fabcfc420fa996cc2e7e44a4182d2569ddba007` completed GitHub Actions run `36311950294` successfully.
- Full R21 workflow passed: whitespace, reproducible build, deterministic clean clone, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload and manifest.
- The previous Node.js 20 deprecation annotation is absent on this run. The `actions/upload-artifact` v7.0.1 / Node.js 24 pin therefore resolves the known post-release CI warning.
- v1.1.3 release tag/assets remain untouched at `fa8c75d0b59343ccb7eae86320a351e3b4064c48`.
- CI maintenance Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION


## R26 / REPOSITORY HYGIENE + WORKSPACE CONSOLIDATION — 2026-09-27

- Objective: professionalize the project after v1.1.3 acceptance, reduce duplicate environments/artifacts, preserve irreplaceable evidence, and keep one canonical source workspace.
- Canonical source workspace is now `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced` on `main`.
- The former linked worktree `TaskbarMonitorEnhanced_R20` was removed from Git worktree metadata after it was reduced to tracked content only. Its now-empty directory is still held open by a running process and therefore cannot yet be deleted; it contains no project data and is not an active Git worktree.
- Historical raw evidence and network-expensive caches were MOVED, not copied, to `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_cleanup`.
- Preserved archive contents include R20/R21 raw evidence, supply-chain evidence, upstream reference cache, the pinned build dependency cache, and meaningful legacy runtime-control evidence.
- Obsolete/rebuildable local material was deleted: the 2026-09-19 preinstall backup, transient build outputs, package staging, benchmark/canary/test workspaces, duplicated runner ZIP/EXE automation stores, duplicated download-control caches, and stale atomic temp files.
- Cleanup prestate covered 2,319,268,833 bytes. Preserved archive is 392,287,771 bytes. Approximate active-storage reduction / deduplication is 1,926,981,062 bytes (~1.79 GiB).
- Active source tree after phase-1 filesystem cleanup was ~1.86 MB excluding Git metadata; installed TaskbarMonitorEnhanced root was reduced to ~69.56 MB while v1.1.3 remained running with one Main process.
- `build\_deps` is now a directory junction to the preserved central dependency cache so LibreHardwareMonitor/PawnIO do not need to be downloaded again. Pinned hashes remain:
  - LibreHardwareMonitor.zip: `086D9F1B5A99E643EDC2CFAAAC16051685B551E4C5AC0B32A57C58C0E529C001`
  - PawnIO_setup.exe: `1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032`
- GitHub release hygiene: five superseded v1.1.2 RC draft releases were deleted. Published releases v1.1.2 and v1.1.3 and their immutable tags remain untouched.
- GitHub branch hygiene: 13 remote branches already merged into `main` were deleted, including obsolete audit/finalization, signing-maintenance, and completed release branches. Two unmerged historical branches were deliberately preserved because they contain unique old lineage: `fix/sensor-installer-resilience` and `release/v1.1.0`.
- v1.1.3 tag remains exactly `fa8c75d0b59343ccb7eae86320a351e3b4064c48`; v1.1.2 tag remains exactly `aab35e5e0e3420f3b21e8febe49bc9e2cc8bb8c0`.
- Obsolete RC6-RC10 self-hosted GitHub Actions workflows are being removed from current `main`; only the current general R21 CI workflow is retained for normal validation.
- `CONTRIBUTING.md` is being upgraded with explicit branch, immutable-release, validation, and repository-hygiene rules.
- External cleanup evidence is retained in the archive as `CLEANUP_PRESTATE.json`, `CLEANUP_POSTSTATE_PHASE1.json`, `GITHUB_HYGIENE_PRESTATE.json`, and `GITHUB_HYGIENE_POSTSTATE.json`.
- Current open gate: commit and exact-main GitHub CI for this hygiene change. The empty locked legacy R20 directory is a non-blocking local cleanup residue only.


### R26 VALIDATION / CLOSEOUT — PASS

- Hygiene commit `f671bb4aee4dadc2f418e95c21471faa108322e7` passed exact-main GitHub Actions run `36313319634` in full: checkout, .NET setup, whitespace, reproducible build, deterministic clean clone, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload, and manifest.
- Local validation from the centralized dependency cache also passed with `Build-R21.ps1 -NoDownload`, built-in self-test, setup verification (19 resources), and deterministic clean-clone verification.
- Exact v1.1.3 Setup hash after cleanup remained `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`; cleanup did not mutate the published release.
- Local Git branch hygiene is complete: only `main` remains locally.
- Remote branch hygiene is intentionally conservative: `main` plus two unmerged historical branches remain; all already-merged audit/maintenance/release branches were removed.
- GitHub draft-release hygiene is complete: no draft releases remain.
- Obsolete branch-specific RC6-RC10 self-hosted workflows are removed; current validation is centralized in `.github/workflows/r21-ci.yml`.
- Current canonical source root: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced`.
- Current preserved external archive: `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_cleanup`.
- Residual: `C:\Users\Aa.Emad\source\repos\TaskbarMonitorEnhanced_R20` is an empty directory only, no longer a Git worktree, but Windows reports it held open by another process. This is a cosmetic/non-blocking residue and contains zero project items.
- R26 Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION


## R27 / PUBLIC-README VISUAL + ROOT ARTIFACT CLEANUP — 2026-09-27

- User-visible audit found two residual presentation issues after R26:
  1. historical v1.1.2 RC manifests/checksum files were still cluttering the repository root;
  2. README referenced `docs/screenshots/desktops/desktop-dark-minimal.webp`, but that Git object was structurally truncated.
- The RC files are historical candidate audit records, not current release assets. They were preserved with `git mv` under `docs/acceptance/archive/v1.1.2-rc/` and documented with an archive README. Root RC artifact count is now zero.
- Corrupt WebP diagnosis is exact: RIFF header declared 62,952 bytes while the tracked Git object contained only 15,008 bytes. GitHub therefore could not decode/render it, producing the apparent blank region in README.
- The corrupt desktop WebP and its obsolete subdirectory README were removed from current `main`; no false 'real desktop capture' claim remains.
- README now uses verified live-rendered application evidence: `THEME_01_DARK_MINIMAL_PRO.png` plus the 14-theme contact sheet.
- Screenshot gallery now uses only structurally valid assets and explicitly records that the truncated historical WebP was removed.
- Validation: every Markdown image link in root README and screenshot README resolves to an existing file; all screenshot PNG/WebP assets pass structural signature/container checks; no broken image links remain.
- R27 publication gate: pending commit + exact-main GitHub CI.


## R28 / PUBLIC REPOSITORY STRUCTURE CLEANUP — 2026-09-27

- User-facing GitHub cleanup continued after R27 because historical version/revision filenames were still visible in active repository locations.
- Root policy is now: current source/docs only; historical release artifacts are grouped by version under `docs/releases/archive/`; historical acceptance evidence is grouped by version under `docs/acceptance/archive/`.
- Current v1.1.3 release notes moved from versioned root filename to `docs/releases/v1.1.3/RELEASE_NOTES.md`; the build still embeds the same canonical content under its established package-resource name, so installer payload semantics are preserved.
- Current v1.1.3 acceptance records moved to `docs/acceptance/v1.1.3/` with generic filenames.
- Historical v1.0.0–v1.1.2 release notes/manifests/checksums were moved with Git history preserved into version directories using generic filenames.
- Historical FINAL_ACCEPTANCE / R21 / R22 / RC10 public-facing filenames were moved under release-specific acceptance archive directories and renamed generically where appropriate.
- Project Brain and reusable Project Knowledge moved from the special-purpose root `00_PROJECT_CONTROL` directory into `docs/project-control/`, removing the internal control-plane folder from the public repository root.
- Added `docs/releases/README.md`, `docs/acceptance/README.md`, and `docs/project-control/README.md` as navigation/index surfaces.
- Root now contains no versioned RELEASE_MANIFEST / SHA256SUMS / historical RELEASE_NOTES filenames and no `00_PROJECT_CONTROL` directory.
- Historical JSON evidence retains original embedded release-asset/local-path labels where those fields are part of the evidence record; physical repository locations are organized without rewriting historical facts.
- Build source path updated to consume `docs/releases/v1.1.3/RELEASE_NOTES.md`; output resource name remains stable.
- Publication gate: run local no-download build + deterministic verification, then exact-main GitHub CI before accepting R28.


## R29 / ACTIVE TOOLING NAME CLEANUP + IMMUTABLE BUILD PRESERVATION — 2026-09-27

- Active engineering filenames were professionalized after the release/archive reorganization:
  - `.github/workflows/r21-ci.yml` -> `.github/workflows/ci.yml`
  - `build/Build-R21.ps1` -> `build/Build.ps1`
  - generated `R21_BUILD_MANIFEST.json` -> `BUILD_MANIFEST.json`
  - generated `R21_SBOM.spdx.json` -> `SBOM.spdx.json`
  - CI artifact name `r21-build-evidence` -> `build-evidence`
- Determinism, contribution, installer, build and CI documentation now reference generic active names. Historical archive/evidence content keeps original revision identifiers where they are factual lineage.
- Public README was shortened to a current reliability/validation summary instead of exposing RC/R21 engineering history as the primary landing-page narrative.
- Critical immutability finding: because the installer embeds `README.md`, ordinary README cleanup initially changed the rebuilt v1.1.3 Setup hash even though executable code was unchanged.
- Prevention architecture: exact accepted embedded README bytes were extracted from the published immutable v1.1.3 Setup resource `Payload.README.md` and stored as `docs/releases/v1.1.3/INSTALLER_README.txt`.
- The build now embeds that frozen release payload snapshot while the public repository README can evolve independently.
- Frozen snapshot SHA256: `9808CC72828F1672A916EEDC6CBD8C7525169DAF5F5C5DF0500BEA9D00CFF7A1`.
- Local no-download rebuild after the freeze restored the exact published v1.1.3 Setup SHA256 `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`.
- Markdown-link audit after reorganization: 73 local links checked, 0 broken.
- Static hygiene: no historical release/checksum/RC files remain in repository root; no active workflow/build filenames contain Rxx/rcxx revision labels.
- Publication gate: commit reorganized tree, run deterministic clean-clone verification from exact commit, push main non-force, require exact GitHub CI PASS.


### R29 VALIDATION / CLOSEOUT — PASS

- Exact restructuring authority: commit `80f9c95afbc419bf49384d16be6f9a63d09a05d4`.
- GitHub Actions run `36315722461` at that exact head completed SUCCESS under the generic workflow name `Build and Verification`.
- CI artifact is now `build-evidence`, artifact id `10929984813`, digest `sha256:2345bb1f03c90ce270e1ec1043b029688badcfb1fb6c3d6fd3282c77f965bb43`.
- Downloaded CI evidence confirmed generic files `BUILD_MANIFEST.json` and `SBOM.spdx.json`, plus exact binary equality for Main/Broker/Supervisor/Setup.
- CI Setup SHA256 remains exactly `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`, identical to immutable public v1.1.3.
- Main/Broker/Supervisor CI SHA256 values remain `74E7725E...`, `182D6346...`, and `38553CCE...` respectively, matching accepted release binaries.
- GitHub API post-publication audit confirms:
  - repository root contains only current project/policy entry points and standard source directories;
  - no historical RELEASE_MANIFEST / SHA256SUMS / versioned RELEASE_NOTES / RC manifest files remain in root;
  - `docs/` top-level contains only organized category directories plus `AMD_INTEL_GPU_PORTABILITY.md`;
  - active workflow surface contains only `.github/workflows/ci.yml`;
  - active build surface uses `build/Build.ps1` and generic helper names.
- Markdown relative-link audit: 74 local links checked, zero broken.
- R29 Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION


## R30 / FINAL PUBLIC-TREE CLEANUP — 2026-09-27

- Scope: remove all obsolete release-candidate/versioned artifact filenames from the active `main` tree while preserving historical recoverability.
- Historical repository archives under `docs/releases/archive/` and `docs/acceptance/archive/` were removed from active `main`. Before removal, 42 files / 97,431 bytes were copied to:
  `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_cleanup\repository_history_removed_from_main`
  with `ARCHIVE_MANIFEST.json` SHA256 `FE6D1A1A9385D9CF5B0B8593A4899C571B4FED3EA0B50005650255F9FE44A018`.
- Historical public evidence also remains recoverable from immutable Git history, release tags, and GitHub Releases. No published tag or release asset was modified.
- `docs/AMD_INTEL_GPU_PORTABILITY.md` moved to `docs/hardware/GPU_PORTABILITY.md`; `docs/` top-level is now category-only.
- Current `docs/releases/README.md` and `docs/acceptance/README.md` describe only the current release plus GitHub/Git history as the historical authority; no local historical-archive links remain.
- Active root/path hygiene audit: zero tracked filenames matching obsolete RC/revision/versioned artifact patterns (`RC_MANIFEST`, versioned `SHA256SUMS`/`RELEASE_MANIFEST`/`RELEASE_NOTES`, `FINAL_ACCEPTANCE_v*`, `Build-R21`, `r21-ci`, `R21_*`, `R22_*`).
- Repository root contains only current standard project/policy files and source directories.
- Markdown relative-link audit: 62 links checked, 0 broken.
- Local build after cleanup: PASS with `build/Build.ps1 -NoDownload`, 0 warnings/errors, Setup verify PASS 19/19, self-test PASS, deterministic clean-clone PASS.
- Immutable v1.1.3 Setup SHA256 after cleanup remains exactly `159D6995D16A549DAC35BD6EF69543A63D6675778C37012619BEFDABFD43598C`.
- Current generated evidence names remain generic: `BUILD_MANIFEST.json` and `SBOM.spdx.json`.
- Publication gate: commit/push this final tree cleanup and require exact-head GitHub CI PASS before declaring R30 closed.


### R30 VALIDATION / CLOSEOUT — PASS

- Final public-tree cleanup authority commit: `ce94e70a170abdfeb6b5c4491c9cebd7d029639c`.
- Exact-head GitHub Actions run `36317306947` completed SUCCESS under `Build and Verification`.
- CI passed checkout, SDK setup, whitespace, reproducible build, deterministic clean-clone build, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload, and manifest output.
- Active `main` contains zero obsolete RC/revision/versioned artifact filenames matching the cleanup deny-list; root and `docs/` top level are category-oriented and current-release focused.
- Historical release/acceptance records removed from active `main` remain preserved in the external hashed archive and in immutable Git history/tags/GitHub Releases.
- Remaining two historical unmerged remote branches were preserved before deletion in a complete Git bundle:
  `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_cleanup\historical_unmerged_branches.bundle`
  SHA256 `736C13A830F6440D8BF972A39556798D0028ABE1442F739AA00E4FDFD3F18948`.
- Bundled branch tips:
  - `fix/sensor-installer-resilience` -> `db9a24e4f334ea5c30ab09f16fe31092fc22311e`
  - `release/v1.1.0` -> `c800eeefc89b1fba2d94c1aeb21555ac88e3f014`
- After bundle verification, both historical remote branches were deleted. Remote branch surface is now only `main`.
- Immutable public release tags remain unchanged, including `v1.1.3` -> `fa8c75d0b59343ccb7eae86320a351e3b4064c48`.
- R30 Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION


## R31 / v1.2.0 MODERN SETTINGS + THEME LIBRARY — CANDIDATE CURRENT AUTHORITY — 2026-09-27

This section supersedes older current-state/next-action sections where they conflict. Published v1.1.3 remains immutable and accepted; this section describes the new unreleased candidate only.

- Candidate identity: `1.2.0 / V1_2_0_R01_MODERN_SETTINGS_THEME_LIBRARY / 1.2.0+r01`.
- Working branch: `feature/modern-settings-theme-library`.
- Public Stable/Latest remains immutable `v1.1.3`; no v1.2.0 tag/release has been created.
- Main mutation objectives:
  1. Settings-open hover flyout must never open/remain stuck.
  2. Settings UX modernized without replacing the proven WinForms/runtime architecture.
  3. Theme library doubled from 14 to 28 with seven additional renderer families rather than palette-only duplication.
- Hover root cause: Settings stopped `hoverTimer`, but overlay `MouseEnter/MouseMove` still called `HandleHardwareHover`; a flyout opened during Settings therefore lacked the watchdog that normally dismisses it.
- Hover fix: Settings-open guards now hide any visible flyout, reset hover identity state, and return before hover resolution; the watchdog has the same defensive guard.
- Hover regression: `--hoverguardproof` = PASS with `MOVE_SUPPRESSED=TRUE WATCHDOG_SUPPRESSED=TRUE FLYOUT_HIDDEN=TRUE`.
- Settings redesign: left navigation, page title/subtitle header, dark surfaces, consistent flat controls, fixed action bar, and live theme preview. Existing eight functional pages and data/config semantics are preserved.
- Settings visual proof: PASS 8 pages at 1080x760 after correcting an initial proof-harness false positive. A form that was only `CreateControl()`-initialized produced blank DrawToBitmap output; prevention is to actually Show the form off-screen, process layout/paint events, then capture.
- Theme library: 28 themes total. New themes: Aurora Borealis, Solarized Luxe, Arctic Frost, Sakura Night, Matrix Grid, Desert Sand, Royal Amethyst, Ocean Depth, Copper Industrial, Nordic Light, Ember Forge, Synthwave Sunset, Quantum Violet, Monochrome Paper.
- New renderer families: `aurora`, `luxe`, `zen`, `synth`, `matrix`, `paper`, `industrial`.
- Theme proof: PASS 28/28 from live telemetry; no synthetic metric data; manifest SHA256 `6791C6C44CA3FC7B547282E87864D7EF564BC70A02CAAB5C78A605533F47C304`.
- Compact proof: PASS 28 themes at 592 and 500 px; 252 layout checks; overflow count 0; manifest SHA256 `0D6DEB7547BD218A96A5E264C12F2FFCF692E24453EE75BF3F8C7367D7928138`.
- Settings proof manifest SHA256: `5163A4D6CE85500A959DA8A72081CA8A67B993A4B8DDE52E18DE55E5BD2A588A`.
- Full local Build.ps1 -NoDownload: PASS; Main/Broker/Supervisor/Setup 0 warnings/errors; sensor windowless PE PASS; canonical text payload PASS; Setup /verify PASS 19/19; self-test PASS.
- Current candidate hashes from `artifacts/BUILD_MANIFEST.json`:
  - Main `B90211E86AAF0AB05C3B87E2D2056A59B2D6369FCAD0ADCC8072A513FCB489D9`
  - Broker `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833` (unchanged accepted sensor layer)
  - Supervisor `38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196` (unchanged accepted sensor layer)
  - Setup `3196986C62FC7D9A91500B0E3246D5640E6292D0ED1722F736505A4DD511B3CF`
- Preserved sensor architecture: `1.1.2+r21`; Setup verify explicitly reports `REUSE_ACCEPTED_1_1_2_R21`.
- External candidate evidence root: `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_v1.2.0-candidate-evidence`.
- Evidence-backed completed: source implementation, compile, full local build, Setup resource verify, self-test, hover guard regression, theme visual proof, compact overflow proof, Settings 8-page proof.
- Open gates: commit exact candidate; clean-clone determinism; SPDX SBOM against candidate commit; live installed-main runtime/UAT on the PC; exact-head GitHub CI. Public v1.2.0 publication is explicitly deferred and not authorized by this candidate state.
- Current blocker: none technical before commit/determinism. Publication remains an irreversible later gate.
- Exact next action: commit the candidate with this Brain/Knowledge state, run clean-clone determinism and SBOM on that exact commit, then perform a reversible user-level Main deployment while preserving the protected sensor layer and verify live Settings/hover/theme behavior.

## R31B / v1.2.0 INSTALLED + PUBLIC-DOC EVIDENCE — 2026-09-27

- Code authority commit remains `5fef3787979277be30fd79c810e9f0fdeb2a653b` for the v1.2.0 implementation.
- Exact installed Main is already the candidate binary: ProductVersion `1.2.0+r01`, SHA256 `B90211E86AAF0AB05C3B87E2D2056A59B2D6369FCAD0ADCC8072A513FCB489D9`.
- Installed Apps registry reports `DisplayVersion=1.2.0`.
- Installed `Uninstall.exe` SHA256 is `3196986C62FC7D9A91500B0E3246D5640E6292D0ED1722F736505A4DD511B3CF`, exactly matching the candidate Setup.
- Installed `install_state.json`: SensorLayerStatus=READY, SensorLayerVersion=`1.1.2+r21`, SensorLayerMode=`CURRENT_EXACT_1_1_2`, MainLaunchMode=`LAUNCHED_NON_ELEVATED_SETUP`.
- Protected Broker/Supervisor hashes remain exactly accepted:
  - Broker `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833`
  - Supervisor `38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196`
- Installed health probe stdout: PASS with `R21=True JOB=True RESILIENCE=STABLE SUP=True CPU=True/True GPU=True/True STORAGE=True/True`.
- Installed hover regression: PASS with move/watchdog suppression and hidden flyout.
- Start-with-Windows remains enabled with both HKCU Run and Startup Recovery shortcut present.
- User configuration was preserved; current config remains valid schema 3.
- Foreground GUI screenshot confirms the running taskbar monitor is visible on the Windows taskbar. Direct mouse takeover was rejected by connector policy with `GUI_TAKEOVER_NOT_AUTHORIZED`; no attempt was made to bypass that control.
- This does not invalidate the automated UI evidence: Settings proof uses a real shown/painted WinForms form and captures all 8 pages; hover behavior has a dedicated installed-binary regression.
- Public-facing screenshot gallery has been synchronized to the v1.2.0 evidence: 28 theme strips, 56 compact strips, 8 Settings pages, and generated contact sheets.
- Gallery visual review: PASS for Settings hierarchy/readability, 28-theme differentiation, and 500px compact readability.
- Markdown relative-link audit: 38 Markdown files checked, 0 broken links.
- v1.2.0 candidate acceptance record added under `docs/acceptance/v1.2.0/CANDIDATE_ACCEPTANCE.json`.
- Public v1.1.3 remains immutable; no public v1.2.0 tag/release has yet been accepted at this point.
- Open critical gate: commit this documentation/evidence delta, rerun exact-head clean-clone determinism + SPDX SBOM, push branch, require exact-head GitHub CI PASS. Public release/promotion remains deferred until those gates.
- Exact next action: commit R31B documentation/evidence delta, then run exact-head build/determinism/SBOM and GitHub CI.


### R31C — i18n evidence-claim correction before PR

- Read-only pre-PR audit found 11 translated README files modified together after the prior candidate commit.
- The changes correctly advanced displayed candidate identity from 1.0.0 to 1.2.0 and theme count from 14 to 28, but also asserted that v1.2.0 itself had completed upgrade/full-uninstall/clean-install lifecycle validation.
- That lifecycle claim was not supported by current v1.2.0 evidence and was therefore rejected rather than promoted.
- The 11 translated files now state only evidence-backed candidate Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
- No code, sensor binaries, installer payload, public tag or release was changed by this correction.
- Exact next action remains: commit/push this documentation-only correction, open PR to main, require exact-head GitHub CI PASS before any merge/public promotion.

## R31D / v1.2.0 FINAL PUBLIC RELEASE — 2026-09-27

This section is the current authority and supersedes the R31/R31B/R31C candidate/open-publication state where they conflict.

- Public release: `v1.2.0 — Modern Settings & Premium Themes`.
- Release URL: `https://github.com/GOD13emad/TaskbarMonitorEnhanced/releases/tag/v1.2.0`.
- GitHub release id: `397665644`.
- Published UTC: `2026-09-27T13:45:13Z`.
- Release state: `draft=false`, `prerelease=false`, `immutable=true`, current `Latest=v1.2.0`.
- Annotated tag object: `5f4c12c2dd8ee2624e93d31ff8672894f5701311`.
- Peeled tag / exact release commit: `84d22fae6638b21683ea828e86517d100ced1654`.
- PR #5 exact-head candidate CI: run `36322439652` on `2e3f953b402e2b512096fcd59533184739127f91` = SUCCESS.
- Main exact-release-commit CI: run `36322557793` on `84d22fae6638b21683ea828e86517d100ced1654` = SUCCESS.
- Main CI success includes reproducible build, deterministic clean-clone, SPDX 2.3 SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload and manifest output.
- GitHub job log manifest equality: PASS 4/4:
  - Main `B90211E86AAF0AB05C3B87E2D2056A59B2D6369FCAD0ADCC8072A513FCB489D9`
  - Broker `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833`
  - Supervisor `38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196`
  - Setup `3196986C62FC7D9A91500B0E3246D5640E6292D0ED1722F736505A4DD511B3CF`
- Exact local `main` release commit was re-built after merge: PASS / 0 warnings / 0 errors / `TBME_REPRO_BUILD=PASS`.
- Exact local release commit clean-clone determinism: `TBME_DETERMINISM=PASS`.
- Exact release-commit SBOM SHA256: `09E38D790AEA054ECDE580EBA3515F285FE72F05758384F83A46D1B181A5A8EC`.
- Pre-publication Setup verification from staged release binary: PASS 19/19.
- Pre-publication SHA256SUMS closure: 6/6 targets match.
- Draft-release asset verification before publication: 7 local vs 7 remote, 0 missing, 0 extra, 0 digest/size mismatches.
- Final published assets, all GitHub state=uploaded and digest-verified:
  - `RELEASE_MANIFEST_v1.2.0.json` — 1893 bytes — `2f3f7c8e001092c8cf5e439ba18dbd62a740e024a75c2d0c81379e20e47a54bd`
  - `RELEASE_NOTES_v1.2.0.md` — 2317 bytes — `02ed6e71802ca0fdc819693ea713a6a02af234443257dcbe6f0fc156d2256822`
  - `SBOM_v1.2.0.spdx.json` — 4959 bytes — `09e38d790aea054ecde580eba3515f285fe72f05758384f83a46d1b181a5a8ec`
  - `SHA256SUMS_v1.2.0.txt` — 609 bytes — `d2f5aa6ba345081f2977959c522bb206d801543689bcb82b99d129b086a3ab16`
  - `TaskbarMonitorEnhanced_1.2.0_SOURCE.zip` — 2659197 bytes — `d5996a44ceb991dde019f00592128596dcadf555d0e4c4217c873699e08f5ee9`
  - `TaskbarMonitorEnhanced_Setup_1.2.0.exe` — 11074560 bytes — `3196986c62fc7d9a91500b0e3246d5640e6292d0ed1722f736505a4dd511b3cf`
  - `V1_2_0_MODERN_SETTINGS_THEME_LIBRARY_ACCEPTANCE.json` — 2192 bytes — `833f67a9ca7a236197353b34481e0c1004a75dfc3f98843a8628ef728ff52d86`
- Public acceptance record: `docs/acceptance/v1.2.0/PUBLIC_RELEASE_ACCEPTANCE.json`.
- Installed PC state remains exact v1.2.0 Main/Setup with preserved `1.1.2+r21` protected sensor layer and R21 health STABLE.
- Feature objectives are evidence-backed complete: Settings-open hover bug fixed; Settings redesigned; themes doubled from 14 to 28; live/compact/Settings proof passed.
- Foreground manual mouse UAT remains unavailable only because connector policy returned `GUI_TAKEOVER_NOT_AUTHORIZED`; this was not bypassed. Installed deterministic hover regression and real-form Settings proof passed.
- Release signing state: unsigned / no publicly trusted Authenticode claim.
- Immutability policy: release-tag payload inputs `docs/releases/v1.2.0/RELEASE_NOTES.md` and `INSTALLER_README.txt` remain frozen after publication; post-publication status is documented elsewhere so the release build hash is not rewritten.
- Optional CI artifact ZIP download was abandoned after network stalls produced no bytes. No blind rerun was performed. Instead, GitHub's successful exact-head CI, provenance/SBOM attestations and the authoritative printed CI build manifest were used for binary hash equality.
- Evidence staging root: `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_v1.2.0-publication\assets`.
- Current DoD Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
- Exact next action: commit the post-publication evidence-only delta on `main`, push, require exact-head CI success, verify release remains immutable/latest, then remove remote/local `feature/modern-settings-theme-library`.

### R31E / MERGED-BRANCH CLEANUP — PASS

- Before deleting the squash-merged feature branch, a complete Git bundle was created at:
  `C:\Users\Aa.Emad\source\archives\TaskbarMonitorEnhanced\2026-09-27_v1.2.0-publication\feature-modern-settings-theme-library.bundle`
- Bundle contains `refs/heads/feature/modern-settings-theme-library` at `2e3f953b402e2b512096fcd59533184739127f91`.
- `git bundle verify`: PASS / complete history.
- Bundle SHA256: `E13DC2AC746F85D6B64B28B3CB7099A1EF5244EBFCD16E991A817FAAC1A87E66`.
- Remote feature branch deletion: PASS.
- Local feature branch deletion: PASS.
- Post-delete remote/local branch checks: absent as intended.
- Product/release state is unchanged; immutable `v1.2.0` remains exact release authority.
- Remaining exact next action: commit and push this post-publication documentation/evidence-only delta on `main`, require its GitHub CI PASS, then perform a final release/latest/tag/worktree audit. No product mutation remains open.

### R31F / FINAL REPOSITORY CLOSEOUT — PASS

- Post-publication documentation/evidence authority commit: `60db90069c8eae74cddcb5d953db1f99adab1229`.
- GitHub Actions run `36324665609` on that exact main head: SUCCESS.
- All CI gates passed again: whitespace, reproducible build, deterministic clean-clone, SPDX SBOM, binary provenance attestation, Setup SBOM attestation, evidence upload and manifest output.
- CI reproduced the immutable release binary hashes exactly:
  - Main `B90211E86AAF0AB05C3B87E2D2056A59B2D6369FCAD0ADCC8072A513FCB489D9`
  - Broker `182D634616434AECADD3A9AF54A746BB61FD70EC0F788DC12429679AA197D833`
  - Supervisor `38553CCE30D5D3F1A22AC6765C4A0F5D4D204970A3DAD7BA9467A326235FC196`
  - Setup `3196986C62FC7D9A91500B0E3246D5640E6292D0ED1722F736505A4DD511B3CF`
- Final invariant audit:
  - GitHub release `v1.2.0`: public, non-draft, non-prerelease, immutable, 7 assets.
  - GitHub Latest: `v1.2.0`.
  - annotated tag object: `5f4c12c2dd8ee2624e93d31ff8672894f5701311`.
  - peeled release commit remains `84d22fae6638b21683ea828e86517d100ced1654`.
  - remote branch surface: only `main`.
  - worktree at audit time: clean.
- Product DoD: COMPLETE / FINAL_PUBLIC_RELEASE_ACCEPTED.
- Project Brain Status: CURRENT_LOCAL_CANDIDATE_VERIFICATION
- Open product bl