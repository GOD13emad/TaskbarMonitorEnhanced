# Windows 10/11 x64 installer pack — TaskbarMonitorEnhanced

Run **`Install.cmd`** from the extracted ZIP. Its PowerShell execution-policy override is confined to that one child process; system-wide PowerShell policy and UAC settings are never modified. Do not run the embedded Setup directly if you need prerequisite checking. The package first verifies its manifest and embedded 1.7.10 Setup SHA-256, then checks the operating system and the installed .NET Framework release key.

- **Windows 11 x64 / Windows 10 x64 (build 17763 or later):** supported Windows native build, with Windows 10 out-of-support warning below. The launcher detects .NET Framework 4.8 or newer (Release >= 528040). When missing, it downloads only Microsoft's offline .NET Framework 4.8 runtime from an exact Microsoft CDN URL and verifies its pinned SHA-256 **and** a valid Microsoft Authenticode signature before requesting native UAC approval for that prerequisite only. The signed runtime may ask for Windows restart; the installer fails closed, and the user reruns `Install.cmd` after reboot.
- **Fresh or existing installation:** the original Setup performs `/install /quiet`, and takes its protected in-place upgrade route if the app is already installed. The launcher checks Setup exit status and installed Main existence and starts the Main only when it isn't already running. Never uninstall/reinstall to upgrade, and do not remove user settings.
- **Hardware temperature driver/service:** the original Setup handles its optional protected sensor helper through Windows UAC. Absence or denial of optional driver activation cannot be bypassed by the bootstrap. No installer silently disables security or installs an arbitrary driver.
- **No unwanted upgrades:** if .NET Framework is already adequate, it is never downgraded or reinstalled; `Build.ps1`, Git, the .NET SDK, VC++ redist and third-party package managers are *developer-only* or unnecessary for this application's runtime and are **not** installed. Updates to Windows itself are administered through Windows Update, not silently by this installer.
- **Windows 10:** mainstream support ended October 14, 2025, with extended security servicing only for eligible enrolled machines. Use a supported Windows version where possible; installing the app does not make unsupported Windows secure.
- **Windows 7/8/8.1, 32-bit Windows, Windows Server, macOS and Linux:** this Windows build does not support these operating systems. macOS/Linux require native panel integrations and platform-specific UI/telemetry; distributing an EXE under a misleading OS label is not a supported package.

To perform read-only preflight without installing or starting anything, use Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -File .\Install-TaskbarMonitorEnhanced.ps1 -CheckOnly
```

## Full offline installer pack

The recommended R410 candidate is `TaskbarMonitorEnhanced-Windows10-11-x64-v1.7.10-Offline.zip`. It embeds the **actual Microsoft-signed .NET Framework 4.8 offline installer** (121,307,088 bytes, SHA-256 `68C9986A8DCC0214D909AA1F31BEE9FB5461BB839EDCA996A75B08DDFFC1483F`). The exact Microsoft CDN source returned HTTP 200 and the downloaded file's Microsoft Authenticode signature was `Valid` on Windows. No Internet access is needed to install this particular prerequisite when the offline executable is present. The app's optional sensor helper/driver is managed by the original Setup, with its own licensing/UAC requirements; this pack does not guarantee that all hardware-specific sensor prerequisites can be activated offline.

The smaller `TaskbarMonitorEnhanced-Windows10-11-x64-v1.7.10.zip` is the online variant: it contains only Setup, scripts and the manifest; it downloads that same verified Microsoft runtime **only if** the current Windows Framework version is too old. Neither variant automatically upgrades Windows or Windows drivers.

The launcher refuses mismatches between its manifest and the bundled runtime, and validates the bundled runtime's **SHA-256 and Microsoft signature** before installation. During native UAC approval, the verified runtime executable remains open under a read-only file handle that denies write/delete sharing. If the signed prerequisite requires reboot, restart Windows and run `Install.cmd` again.

To verify the offline runtime **without installing or starting it**, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-TaskbarMonitorEnhanced.ps1 -VerifyOfflineRuntime
```

R411 disposable-client validation (November 11, 2026): the GitHub-built Offline package was actually installed from a clean **Windows 11 Enterprise build 26100 Windows Sandbox guest** with networking disabled and a read-only source mapping. Fresh `/install /quiet` and a subsequent same-version guarded in-place upgrade both returned `0`; the installed Main was running after each operation, and Main/config file hashes matched across the upgrade. This verifies that one Windows 11 guest + present-.NET-Framework scenario, **not** Windows 10, upgrading from an older product release, or installing a missing .NET Framework/UAC/reboot flow. The guest receipt is retained in the project-local R411 audit folder and the result in `docs/project-control/PROJECT_BRAIN.md`.

R412 published-version upgrade acceptance (November 11, 2026): on a second fresh, network-isolated Windows 11 Enterprise 26100 Sandbox guest, the public GitHub **v1.7.9** Setup (exact release SHA-256 `3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E`) installed with exit `0`. The **verified Offline v1.7.10** bootstrap then upgraded it with exit `0` and a running Main. The user's `config.json`, `config.json.bak`, extra state key, and an independent external canary all retained their contents; no second Program Files install appeared. This is independently evidenced in `docs/project-control/PROJECT_BRAIN.md` and the local ignored `R412_host_acceptance.json` receipt. Windows 10, missing Framework/UAC/reboot, and optional hardware-driver installation still require independent acceptance.

A signed runtime bundle and this successful disposable Windows 11 test do not authorize publication. Windows 10, older-version updates, missing-framework UAC/reboot and security approval remain separate acceptance requirements. This is still a staged candidate.

Microsoft references: https://learn.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed and https://learn.microsoft.com/en-us/dotnet/framework/get-started/system-requirements
