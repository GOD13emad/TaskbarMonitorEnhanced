# Privacy

Taskbar Monitor Enhanced is a local Windows taskbar system-monitoring application.

## Local telemetry

The application reads system telemetry from the local computer to display CPU, memory, disk, network, GPU, VRAM, temperature, power and fan data when available, and related hardware information.

Taskbar Monitor Enhanced does **not** upload monitoring telemetry, configuration data, hardware readings, analytics events, advertising identifiers, or personal content to the project maintainer or to a project-operated cloud service.

No analytics, advertising SDK, user tracking, or project cloud-telemetry service is included.

## Local retention and exports in v1.6.0

The session chart history keeps at most 3,600 samples in memory. Alert history keeps at most 200 entries in memory. Both are lost when the process ends unless the user explicitly exports them.

**Network traffic persistence is disabled by default.** Enabling `Keep 90 days locally` on the Network page stores at most 90 daily totals in `%LOCALAPPDATA%\TaskbarMonitorEnhanced\traffic_history.json`, with a local `.bak` recovery file. Totals contain local dates and observed download/upload byte counts, not packet contents, browsing history, remote endpoints or ISP billing data. Turning the option off stops future scheduled saves; it does not silently delete the existing file or an already queued write. Files can be removed manually after closing the application.

CSV/JSON/PNG exports are user-initiated local files. Process exports include process names and identifiers; hardware inventory exports can include device names, manufacturers and part numbers. Review these files before sharing. Presentation profile backups and ordinary diagnostic/sensor logs are also local. No export is automatically uploaded.

## GitHub update checks

Automatic update checking is enabled by default and can be disabled in **Settings > Behavior > Automatically check GitHub Releases for updates**.

When an update check runs, the application performs an HTTPS GET request to the official GitHub Releases API endpoint:

`https://api.github.com/repos/GOD13emad/TaskbarMonitorEnhanced/releases/latest`

The request uses the application user-agent `TaskbarMonitorEnhanced/<version>` and GitHub's JSON media type. The application does not intentionally attach monitoring telemetry, configuration contents, hardware readings, or user documents to this request. As with any HTTPS connection, GitHub and network infrastructure can observe ordinary connection metadata such as source IP address and request headers under their own policies.

## Update downloads

If a newer eligible release is found, the application does **not** download or launch the installer silently. The user must choose **Download & Install** and confirm the prompt. The application then downloads the expected installer from `github.com`, verifies the exact GitHub-provided SHA-256 digest and immutable-release conditions, and only then launches the installer.

Opening the release page is also a user-requested action.

## Other network behavior

Normal hardware monitoring and sensor collection are local. The protected sensor broker and supervisor are local processes and are not used to transmit monitoring data to network services.

## Third-party services and components

GitHub is the update and distribution service used by the application. GitHub processes network connection data under GitHub's own privacy and service terms. Open-source and system-level software components used locally are documented in `THIRD_PARTY_NOTICES.md`.

## Contact

Maintainer: Dr. Ali-Akbar Emadeddin  
GitHub: `GOD13emad`  
Email: `aliemad1324@gmail.com`
