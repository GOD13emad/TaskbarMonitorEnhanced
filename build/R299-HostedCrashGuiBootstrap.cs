// Hosted CI-only Windows-subsystem bootstrap for the original PowerShell
// COMMITTING crash fixture. Does not create a visible console or modify Setup.
// All destructive test writes remain inside Test-R299-HostedCrashChild.ps1,
// which rechecks the same exact disposable-runner identity and binary pins.
using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Globalization;
using System.Diagnostics;
using System.Management.Automation;

internal static class R299HostedCrashGuiBootstrap
{
    private static string Env(string name)
    {
        return Environment.GetEnvironmentVariable(name) ?? String.Empty;
    }

    private static void Require(bool condition, string marker)
    {
        if (!condition) throw new InvalidOperationException(marker);
    }

    private static void WriteOnce(string path, string value)
    {
        byte[] bytes = new UTF8Encoding(false).GetBytes(value);
        using (var file = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            file.Write(bytes, 0, bytes.Length);
    }

    [STAThread]
    public static int Main(string[] args)
    {
        string signal = null;
        bool disposableContextVerified = false;
        try
        {
            Require(args != null && args.Length == 7, "R299_GUI_BOOTSTRAP_REQUIRES_SEVEN_EXACT_ARGUMENTS");
            Require(Environment.OSVersion.Platform == PlatformID.Win32NT &&
                Env("GITHUB_ACTIONS") == "true" &&
                Env("RUNNER_ENVIRONMENT") == "github-hosted" &&
                Env("RUNNER_OS") == "Windows" &&
                Env("GITHUB_REPOSITORY") == "GOD13emad/TaskbarMonitorEnhanced",
                "R299_GUI_BOOTSTRAP_REQUIRES_DISPOSABLE_GITHUB_WINDOWS");
            string runId = Env("GITHUB_RUN_ID");
            string sha = Env("GITHUB_SHA");
            Require(Regex.IsMatch(runId, @"^[0-9]{5,20}$") &&
                Regex.IsMatch(sha, @"^[a-f0-9]{40}$"),
                "R299_GUI_BOOTSTRAP_UNPINNED_RUN_OR_COMMIT");
            Require(!Regex.IsMatch(Env("COMPUTERNAME"), "(?i)EMAD|ALIEMAD|LAPTOP|SAEID"),
                "R299_GUI_BOOTSTRAP_REFUSES_OWNER_MACHINE");
            string temp = Env("RUNNER_TEMP");
            string workspace = Env("GITHUB_WORKSPACE");
            Require(Path.IsPathRooted(temp) && Path.IsPathRooted(workspace),
                "R299_GUI_BOOTSTRAP_REQUIRES_ABSOLUTE_HOSTED_PATHS");
            signal = args[2];
            string exactSignal = Path.Combine(temp, "R299_ABRUPT_COMMITTING_ARMED_" + runId + ".json");
            Require(Path.IsPathRooted(signal) &&
                String.Equals(Path.GetFullPath(signal), Path.GetFullPath(exactSignal),
                    StringComparison.OrdinalIgnoreCase),
                "R299_GUI_BOOTSTRAP_SIGNAL_NOT_EXACT_RUNNER_TEMP");
            Require(Directory.Exists(temp) && Directory.Exists(workspace) &&
                String.Equals(Path.GetFileName(Path.GetFullPath(workspace).TrimEnd(
                    Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)),
                    "TaskbarMonitorEnhanced", StringComparison.OrdinalIgnoreCase),
                "R299_GUI_BOOTSTRAP_WORKSPACE_NOT_EXPECTED");
            disposableContextVerified = true;

            string script = Path.Combine(workspace, "build", "Test-R299-HostedCrashChild.ps1");
            Require(File.Exists(script), "R299_GUI_BOOTSTRAP_CRASH_SCRIPT_MISSING");
            Require(!File.Exists(signal) && !File.Exists(signal + ".gui.entered.txt") &&
                !File.Exists(signal + ".entered.txt") &&
                !File.Exists(signal + ".started.txt") &&
                !File.Exists(signal + ".error.txt") &&
                !File.Exists(signal + ".bootstrap.error.txt"),
                "R299_GUI_BOOTSTRAP_RECEIPT_ALREADY_EXISTS");

            int pid = Process.GetCurrentProcess().Id;
            string entry = String.Format(CultureInfo.InvariantCulture,
                "{{\"Pid\":{0},\"Phase\":\"GUI_BOOTSTRAP_STARTED\",\"GitSha\":\"{1}\",\"RunId\":\"{2}\"}}",
                pid, sha, runId);
            WriteOnce(signal + ".gui.entered.txt", entry);

            // PowerShell 5.1 engine in the GUI process; no powershell.exe console
            // process exists at Medium integrity. The original script's complete
            // fail-closed preflight and real Setup reflection run unchanged.
            using (PowerShell shell = PowerShell.Create())
            {
                shell.AddCommand(script)
                    .AddParameter("CandidateSetup", args[0])
                    .AddParameter("App", args[1])
                    .AddParameter("Signal", signal)
                    .AddParameter("ExpectedSetupSha", args[3])
                    .AddParameter("ExpectedPriorSetupSha", args[4])
                    .AddParameter("ExpectedPriorMainSha", args[5])
                    .AddParameter("ExpectedNewMainSha", args[6]);
                shell.Invoke();
                if (shell.HadErrors)
                {
                    string detail = shell.Streams.Error.Count == 0
                        ? "UNKNOWN_POWERSHELL_ENGINE_ERROR"
                        : shell.Streams.Error[0].ToString();
                    throw new InvalidOperationException("R299_GUI_BOOTSTRAP_EMBEDDED_SCRIPT_FAILED: " + detail);
                }
            }
            throw new InvalidOperationException("R299_GUI_BOOTSTRAP_SCRIPT_RETURNED_WITHOUT_KILL");
        }
        catch (Exception error)
        {
            // Only emit diagnostics after exact hosted Windows identity and
            // runner-scoped signal have been verified. Never write on owner host.
            if (disposableContextVerified && !String.IsNullOrEmpty(signal))
            {
                try { WriteOnce(signal + ".bootstrap.error.txt", error.ToString()); }
                catch { }
            }
            return 81;
        }
    }
}
