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

The ZIP may optionally include Microsoft's original `NDP48-x86-x64-AllOS-ENU.exe` for an offline install. If included, its SHA-256 and Microsoft Authenticode signature are checked exactly like a downloaded copy. The package itself is a staged candidate until PR security scanning, hosted install/upgrade/launch acceptance and authorized publication are complete.

Microsoft references: https://learn.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed and https://learn.microsoft.com/en-us/dotnet/framework/get-started/system-requirements
