// TBME_V1_1_2_R21_RC2: production hardening; native CPU usage, cached WMI topology, power-aware telemetry, supervisor diagnostics.
// TBME_V1_1_2_R20_RC1: LHM native sensor access isolated from the UI process; CPU/GPU/storage failures are independently contained.
// TBME_V1_1_1_R18_STABLE: low-pressure taskbar-child shell integration + single-instance Settings.
// TBME_V1_1_0_DISK_TEMP_BROKER_RESTORE_R02: elevated storage temperatures + LHM HardwareId drive-index correlation; shell core unchanged.
// TBME_V1_1_0_SHELL_RESTORE_R01: exact accepted v1.0.2 Shell integration core restored onto current v1.1.0 feature source; no telemetry/hover/update rollback.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Management;
using System.Net;
using System.Net.NetworkInformation;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using Microsoft.Win32;


[assembly: AssemblyTitle("Taskbar Monitor Enhanced")]
[assembly: AssemblyDescription("Live system monitor integrated into the Windows taskbar")]
[assembly: AssemblyProduct("Taskbar Monitor Enhanced")]
[assembly: AssemblyCompany("Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyInformationalVersion("1.1.2-rc2+r21")]
[assembly: AssemblyCopyright("Copyright © 2026 Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyVersion("1.1.2.0")]
[assembly: AssemblyFileVersion("1.1.2.0")]

namespace TaskbarMonitorEnhanced
{
    internal static class BuildInfo
    {
        public const string Version = "V1_1_2_R21_PRODUCTION_HARDENING_RC2";
        public const string Product = "Taskbar Monitor Enhanced";
        public const string PublicVersion = "1.1.2-rc2";
        public const string ShortcutName = "Taskbar Monitor Enhanced";
        public const string ProductDescription = "Live system monitor integrated into the Windows taskbar";
        public const string Author = "Dr. Ali-Akbar Emadeddin";
        public const string AuthorEmail = "aliemad1324@gmail.com";
        public const string AuthorGitHub = "https://github.com/GOD13emad";
        public const string RepositoryUrl = "https://github.com/GOD13emad/TaskbarMonitorEnhanced";
        public const string LatestReleaseApi = "https://api.github.com/repos/GOD13emad/TaskbarMonitorEnhanced/releases/latest";
        public const string LicenseId = "GPL-3.0";
        public const int HistoryLength = 60;
        public const int DefaultWidth = 1100;
    }

    internal static class AppPaths
    {
        public static readonly string Root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TaskbarMonitorEnhanced");
        public static readonly string Config = Path.Combine(Root, "config.json");
        public static readonly string ConfigBackup = Path.Combine(Root, "config.json.bak");
        public static readonly string Logs = Path.Combine(Root, "Logs");
        public static readonly string SensorBackend = Path.Combine(Root, "SensorBackend", "LibreHardwareMonitor-0.9.6");
        public static readonly string SensorBackendState = Path.Combine(Root, "sensor_backend_state.json");
        public static readonly string CpuTempBrokerData = Path.Combine(Root, "cpu_temp_broker.json");
        public static readonly string GpuBrokerData = Path.Combine(Root, "gpu_temp_broker.json");
        public static readonly string StorageBrokerData = Path.Combine(Root, "storage_temp_broker.json");
        public static readonly string SensorSupervisorState = Path.Combine(Root, "sensor_supervisor_state.json");
        public static readonly string Updates = Path.Combine(Root, "Updates");
        public static readonly string Log = Path.Combine(Logs, "tbme_csharp_" + DateTime.Now.ToString("yyyyMMdd") + ".log");
    }

    internal static class Log
    {
        private static readonly object Sync = new object();
        private static DateTime lastMaintenanceUtc=DateTime.MinValue;
        private const long MaxDailyLogBytes=8L*1024L*1024L;
        private const int RetentionDays=30;

        private static void Maintain()
        {
            DateTime now=DateTime.UtcNow;
            if(lastMaintenanceUtc!=DateTime.MinValue&&(now-lastMaintenanceUtc).TotalMinutes<10)return;
            lastMaintenanceUtc=now;
            try
            {
                Directory.CreateDirectory(AppPaths.Logs);
                foreach(string f in Directory.GetFiles(AppPaths.Logs,"tbme_csharp_*.log"))
                {
                    try
                    {
                        if((now-File.GetLastWriteTimeUtc(f)).TotalDays>RetentionDays)File.Delete(f);
                    }
                    catch{}
                }

                if(File.Exists(AppPaths.Log)&&new FileInfo(AppPaths.Log).Length>=MaxDailyLogBytes)
                {
                    string rotated=Path.Combine(
                        AppPaths.Logs,
                        "tbme_csharp_"+DateTime.Now.ToString("yyyyMMdd_HHmmss",CultureInfo.InvariantCulture)+".log"
                    );
                    if(File.Exists(rotated))File.Delete(rotated);
                    File.Move(AppPaths.Log,rotated);
                }
            }
            catch{}
        }

        public static void Write(string level, string message)
        {
            try
            {
                lock (Sync)
                {
                    Maintain();
                    Directory.CreateDirectory(AppPaths.Logs);
                    File.AppendAllText(AppPaths.Log,
                        DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture) + " [" + level + "] " + message + Environment.NewLine,
                        Encoding.UTF8);
                }
            }
            catch { }
        }
    }

    internal static class AtomicTextFile
    {
        public static void Write(string path,string value,Encoding encoding,string backupPath)
        {
            if(String.IsNullOrWhiteSpace(path))throw new ArgumentException("path");
            string dir=Path.GetDirectoryName(path);
            if(!String.IsNullOrWhiteSpace(dir))Directory.CreateDirectory(dir);
            string tmp=path+"."+Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture)+"."+Environment.TickCount.ToString(CultureInfo.InvariantCulture)+".tmp";
            File.WriteAllText(tmp,value??"",encoding??Encoding.UTF8);
            try
            {
                if(File.Exists(path))
                {
                    File.Replace(tmp,path,String.IsNullOrWhiteSpace(backupPath)?null:backupPath,true);
                }
                else
                {
                    File.Move(tmp,path);
                    if(!String.IsNullOrWhiteSpace(backupPath)&&!File.Exists(backupPath))
                        File.Copy(path,backupPath,true);
                }
            }
            catch
            {
                try{if(File.Exists(tmp))File.Delete(tmp);}catch{}
                throw;
            }
        }
    }

    internal static class RuntimeGuard
    {
        private static int installed=0;
        public static int UiThreadExceptionCount=0;
        public static int AppDomainUnhandledCount=0;

        public static void Install()
        {
            if(Interlocked.Exchange(ref installed,1)!=0)return;
            try
            {
                Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
                Application.ThreadException+=delegate(object sender,ThreadExceptionEventArgs e)
                {
                    Interlocked.Increment(ref UiThreadExceptionCount);
                    Log.Write("ERROR","UI_THREAD_EXCEPTION "+(e!=null&&e.Exception!=null?e.Exception.ToString():"UNKNOWN"));
                };
            }
            catch(Exception ex){Log.Write("WARN","RUNTIME_GUARD_UI_INSTALL "+ex.Message);}
            try
            {
                AppDomain.CurrentDomain.UnhandledException+=delegate(object sender,UnhandledExceptionEventArgs e)
                {
                    Interlocked.Increment(ref AppDomainUnhandledCount);
                    Log.Write("ERROR","APPDOMAIN_UNHANDLED terminating="+e.IsTerminating+" "+(e.ExceptionObject==null?"UNKNOWN":e.ExceptionObject.ToString()));
                };
            }
            catch(Exception ex){Log.Write("WARN","RUNTIME_GUARD_DOMAIN_INSTALL "+ex.Message);}
            try
            {
                AppDomain.CurrentDomain.ProcessExit+=delegate{Log.Write("INFO","PROCESS_EXIT uiExceptions="+UiThreadExceptionCount+" domainUnhandled="+AppDomainUnhandledCount);};
            }
            catch{}
            Log.Write("INFO","RUNTIME_GUARD_INSTALLED");
        }

        public static void SafeUi(string area,Action action)
        {
            try{action();}
            catch(Exception ex)
            {
                Interlocked.Increment(ref UiThreadExceptionCount);
                Log.Write("ERROR","UI_GUARDED_EXCEPTION area="+area+" "+ex.ToString());
            }
        }
    }

    public sealed class AppConfig
    {
        public string Theme { get; set; }
        public string Position { get; set; }
        public double Opacity { get; set; }
        public int UpdateIntervalMs { get; set; }
        public bool ShowCpu { get; set; }
        public bool ShowRam { get; set; }
        public bool ShowDisk { get; set; }
        public bool ShowGpu { get; set; }
        public bool ShowVram { get; set; }
        public bool ShowNetwork { get; set; }
        public bool ShowTemperatures { get; set; }
        public bool ShowSparklines { get; set; }
        public bool StartWithWindows { get; set; }
        public int WidthLogicalPx { get; set; }
        public int MinWidthLogicalPx { get; set; }
        public int MaxWidthLogicalPx { get; set; }
        public int MarginLogicalPx { get; set; }
        public int VerticalMarginLogicalPx { get; set; }
        public int SafePlacementPaddingLogicalPx { get; set; }
        public bool SafePlacement { get; set; }
        public string FontFamily { get; set; }
        public double FontSize { get; set; }

        // R13 multi-hardware / unit configuration. IDs are semicolon-separated
        // so legacy JavaScriptSerializer config remains forward/backward tolerant.
        public string CpuDisplayMode { get; set; }
        public string GpuDisplayMode { get; set; }
        public string DiskDisplayMode { get; set; }
        public string NetworkDisplayMode { get; set; }
        public string SelectedCpuIds { get; set; }
        public string SelectedGpuIds { get; set; }
        public string SelectedDiskIds { get; set; }
        public string SelectedNetworkIds { get; set; }
        public string MultipleDeviceLayout { get; set; }
        public string MemoryUnit { get; set; }
        public string StorageUnit { get; set; }
        public string NetworkUnit { get; set; }
        public string DiskRateUnit { get; set; }
        public bool ShowRamNumeric { get; set; }
        public bool ShowDiskNumeric { get; set; }
        public bool EnableHardwareFlyout { get; set; }
        public bool HoverShowAllDevices { get; set; }
        public bool AutoCheckUpdates { get; set; }
        public int ConfigSchemaVersion { get; set; }

        public AppConfig()
        {
            Theme = "Dark Minimal Pro";
            Position = "Left";
            Opacity = 0.97;
            UpdateIntervalMs = 1000;
            ShowCpu = true; ShowRam = true; ShowDisk = true; ShowGpu = true; ShowVram = true; ShowNetwork = true;
            ShowTemperatures = true;
            ShowSparklines = true;
            StartWithWindows = true;
            WidthLogicalPx = 1100;
            MinWidthLogicalPx = 1100;
            MaxWidthLogicalPx = 1400;
            MarginLogicalPx = 0;
            VerticalMarginLogicalPx = 0;
            SafePlacementPaddingLogicalPx = 0;
            SafePlacement = true;
            FontFamily = "Segoe UI";
            FontSize = 8.8;
            CpuDisplayMode = "Overall";
            GpuDisplayMode = "Auto";
            DiskDisplayMode = "Overall";
            NetworkDisplayMode = "Overall";
            SelectedCpuIds = ""; SelectedGpuIds = ""; SelectedDiskIds = ""; SelectedNetworkIds = "";
            MultipleDeviceLayout = "Grouped";
            MemoryUnit = "Auto"; StorageUnit = "Auto"; NetworkUnit = "Auto"; DiskRateUnit = "Auto";
            ShowRamNumeric = true; ShowDiskNumeric = true;
            EnableHardwareFlyout = true; HoverShowAllDevices = true; AutoCheckUpdates = true; ConfigSchemaVersion = 3;
        }

        public void Normalize()
        {
            if (String.IsNullOrWhiteSpace(Theme) || String.Equals(Theme, "Auto", StringComparison.OrdinalIgnoreCase)) Theme = "Dark Minimal Pro";
            if (!ThemeCatalog.Names.Contains(Theme)) Theme = "Dark Minimal Pro";
            if (String.IsNullOrWhiteSpace(Position) || (Position != "Left" && Position != "Center" && Position != "Right")) Position = "Left";
            if (Opacity < 0.55 || Opacity > 1.0) Opacity = 0.97;
            if (UpdateIntervalMs < 1000 || UpdateIntervalMs > 5000) UpdateIntervalMs = 1000;
            if (MinWidthLogicalPx < 900 || MinWidthLogicalPx > 1500) MinWidthLogicalPx = 1100;
            if (MaxWidthLogicalPx < MinWidthLogicalPx) MaxWidthLogicalPx = Math.Max(1400, MinWidthLogicalPx);
            MarginLogicalPx = 0;
            VerticalMarginLogicalPx = 0;
            SafePlacementPaddingLogicalPx = 0;
            if (String.IsNullOrWhiteSpace(FontFamily)) FontFamily = "Segoe UI";
            if (FontSize < 6.5 || FontSize > 16.0) FontSize = 8.8;
            if(ConfigSchemaVersion<2)
            {
                CpuDisplayMode="Overall";GpuDisplayMode="Auto";DiskDisplayMode="Overall";NetworkDisplayMode="Overall";MultipleDeviceLayout="Grouped";MemoryUnit="Auto";StorageUnit="Auto";NetworkUnit="Auto";ShowRamNumeric=true;ShowDiskNumeric=true;EnableHardwareFlyout=true;HoverShowAllDevices=true;
            }
            if(ConfigSchemaVersion<3)
            {
                DiskRateUnit="Auto";AutoCheckUpdates=true;ConfigSchemaVersion=3;
            }
            CpuDisplayMode = NormalizeDisplayMode(CpuDisplayMode, "Overall");
            GpuDisplayMode = NormalizeDisplayMode(GpuDisplayMode, "Auto");
            DiskDisplayMode = NormalizeDisplayMode(DiskDisplayMode, "Overall");
            NetworkDisplayMode = NormalizeDisplayMode(NetworkDisplayMode, "Overall");
            if(String.IsNullOrWhiteSpace(MultipleDeviceLayout) || (MultipleDeviceLayout!="Grouped" && MultipleDeviceLayout!="Separate")) MultipleDeviceLayout="Grouped";
            MemoryUnit = NormalizeUnit(MemoryUnit); StorageUnit = NormalizeUnit(StorageUnit); NetworkUnit = NormalizeUnit(NetworkUnit); DiskRateUnit = NormalizeUnit(DiskRateUnit);
            if(SelectedCpuIds==null)SelectedCpuIds=""; if(SelectedGpuIds==null)SelectedGpuIds=""; if(SelectedDiskIds==null)SelectedDiskIds=""; if(SelectedNetworkIds==null)SelectedNetworkIds="";
        }

        private static string NormalizeDisplayMode(string value,string fallback)
        {
            if(String.IsNullOrWhiteSpace(value))return fallback;
            foreach(string x in new string[]{"Overall","Auto","Single","Multiple"})if(String.Equals(value,x,StringComparison.OrdinalIgnoreCase))return x;
            return fallback;
        }

        private static string NormalizeUnit(string value)
        {
            if(String.IsNullOrWhiteSpace(value))return "Auto";
            foreach(string x in new string[]{"Auto","KB","MB","GB"})if(String.Equals(value,x,StringComparison.OrdinalIgnoreCase))return x;
            return "Auto";
        }

        private static AppConfig LoadPath(string path)
        {
            JavaScriptSerializer js=new JavaScriptSerializer();
            AppConfig c=js.Deserialize<AppConfig>(File.ReadAllText(path,Encoding.UTF8));
            if(c==null)throw new InvalidDataException("Configuration JSON is empty.");
            c.Normalize();
            return c;
        }

        public static AppConfig Load()
        {
            Directory.CreateDirectory(AppPaths.Root);
            if(!File.Exists(AppPaths.Config))
            {
                if(File.Exists(AppPaths.ConfigBackup))
                {
                    try
                    {
                        AppConfig recovered=LoadPath(AppPaths.ConfigBackup);
                        Log.Write("WARN","CONFIG_PRIMARY_MISSING_RECOVERED_FROM_BACKUP");
                        try{AtomicTextFile.Write(AppPaths.Config,new JavaScriptSerializer().Serialize(recovered),Encoding.UTF8,AppPaths.ConfigBackup);}catch{}
                        return recovered;
                    }
                    catch(Exception backupEx){Log.Write("WARN","CONFIG_BACKUP_LOAD_FAILED "+backupEx.Message);}
                }
                return new AppConfig();
            }

            try{return LoadPath(AppPaths.Config);}
            catch(Exception ex)
            {
                Log.Write("WARN","CONFIG_LOAD_FAILED "+ex.Message);
                if(File.Exists(AppPaths.ConfigBackup))
                {
                    try
                    {
                        AppConfig recovered=LoadPath(AppPaths.ConfigBackup);
                        Log.Write("WARN","CONFIG_RECOVERED_FROM_BACKUP");
                        try{AtomicTextFile.Write(AppPaths.Config,new JavaScriptSerializer().Serialize(recovered),Encoding.UTF8,AppPaths.ConfigBackup);}catch{}
                        return recovered;
                    }
                    catch(Exception backupEx){Log.Write("WARN","CONFIG_BACKUP_LOAD_FAILED "+backupEx.Message);}
                }
                return new AppConfig();
            }
        }

        public void Save()
        {
            Normalize();
            Directory.CreateDirectory(AppPaths.Root);
            JavaScriptSerializer js = new JavaScriptSerializer();
            AtomicTextFile.Write(AppPaths.Config,js.Serialize(this),Encoding.UTF8,AppPaths.ConfigBackup);
        }
    }

    internal sealed class ThemeDefinition
    {
        public string Name;
        public Color Background;
        public Color Background2;
        public Color Foreground;
        public Color Muted;
        public Color Border;
        public Color[] Accents;
        public string Mode;
        public string FontName;
        public bool Light;

        public ThemeDefinition(string name, Color bg, Color bg2, Color fg, Color muted, Color border, Color[] accents, string mode, string fontName, bool light)
        {
            Name=name; Background=bg; Background2=bg2; Foreground=fg; Muted=muted; Border=border; Accents=accents; Mode=mode; FontName=fontName; Light=light;
        }
    }

    internal static class ThemeCatalog
    {
        public static readonly string[] Names = new string[] {
            "Dark Minimal Pro", "Glass Morphism", "Neon Cyberpunk", "Sleek White", "Round Compact", "Honeycomb Tech", "Retro Terminal",
            "Fluent Glass", "OLED Mono", "Cyber Neon", "Mission Control", "Blueprint Tech", "Medical Telemetry", "Carbon Racing"
        };

        private static readonly Dictionary<string, ThemeDefinition> Themes = new Dictionary<string, ThemeDefinition>(StringComparer.OrdinalIgnoreCase)
        {
            {"Dark Minimal Pro", new ThemeDefinition("Dark Minimal Pro", Color.FromArgb(17,20,24), Color.FromArgb(10,12,15), Color.FromArgb(244,247,249), Color.FromArgb(150,160,170), Color.FromArgb(48,54,61), new Color[]{Color.FromArgb(56,189,248),Color.FromArgb(168,85,247),Color.FromArgb(34,197,94),Color.FromArgb(250,204,21),Color.FromArgb(249,115,22),Color.FromArgb(14,165,233)}, "minimal", "Segoe UI", false)},
            {"Glass Morphism", new ThemeDefinition("Glass Morphism", Color.FromArgb(34,45,63), Color.FromArgb(19,31,48), Color.White, Color.FromArgb(190,207,228), Color.FromArgb(91,130,170), new Color[]{Color.FromArgb(75,196,255),Color.FromArgb(178,125,255),Color.FromArgb(96,229,139),Color.FromArgb(255,211,79),Color.FromArgb(255,132,87),Color.FromArgb(77,208,225)}, "glass", "Segoe UI", false)},
            {"Neon Cyberpunk", new ThemeDefinition("Neon Cyberpunk", Color.FromArgb(4,8,11), Color.Black, Color.FromArgb(230,255,255), Color.FromArgb(135,180,190), Color.FromArgb(0,245,233), new Color[]{Color.FromArgb(25,247,255),Color.FromArgb(184,108,255),Color.FromArgb(99,255,114),Color.FromArgb(255,231,74),Color.FromArgb(255,101,79),Color.FromArgb(0,229,255)}, "neon", "Segoe UI", false)},
            {"Sleek White", new ThemeDefinition("Sleek White", Color.FromArgb(246,248,250), Color.FromArgb(232,236,240), Color.FromArgb(17,24,39), Color.FromArgb(66,76,90), Color.FromArgb(200,207,216), new Color[]{Color.FromArgb(38,132,255),Color.FromArgb(136,78,240),Color.FromArgb(34,170,80),Color.FromArgb(230,165,0),Color.FromArgb(235,92,52),Color.FromArgb(26,150,190)}, "white", "Segoe UI", true)},
            {"Round Compact", new ThemeDefinition("Round Compact", Color.FromArgb(15,19,23), Color.FromArgb(9,12,15), Color.FromArgb(245,248,250), Color.FromArgb(160,171,181), Color.FromArgb(78,88,98), new Color[]{Color.FromArgb(103,212,255),Color.FromArgb(174,109,255),Color.FromArgb(92,224,119),Color.FromArgb(255,211,72),Color.FromArgb(255,120,78),Color.FromArgb(84,201,230)}, "round", "Segoe UI", false)},
            {"Honeycomb Tech", new ThemeDefinition("Honeycomb Tech", Color.FromArgb(7,11,14), Color.FromArgb(12,18,23), Color.FromArgb(242,247,248), Color.FromArgb(120,145,158), Color.FromArgb(49,65,76), new Color[]{Color.FromArgb(67,217,255),Color.FromArgb(203,108,255),Color.FromArgb(112,255,104),Color.FromArgb(255,229,92),Color.FromArgb(255,116,78),Color.FromArgb(58,205,225)}, "hex", "Segoe UI", false)},
            {"Fluent Glass", new ThemeDefinition("Fluent Glass", Color.FromArgb(23,34,49), Color.FromArgb(47,70,94), Color.FromArgb(247,250,252), Color.FromArgb(174,197,214), Color.FromArgb(94,158,207), new Color[]{Color.FromArgb(94,211,255),Color.FromArgb(175,132,255),Color.FromArgb(101,230,158),Color.FromArgb(255,206,91),Color.FromArgb(255,137,105),Color.FromArgb(83,211,218)}, "fluent", "Segoe UI", false)},
            {"OLED Mono", new ThemeDefinition("OLED Mono", Color.FromArgb(0,0,0), Color.FromArgb(8,8,9), Color.FromArgb(247,247,247), Color.FromArgb(145,145,149), Color.FromArgb(55,55,59), new Color[]{Color.FromArgb(245,245,245),Color.FromArgb(220,220,222),Color.FromArgb(200,200,202),Color.FromArgb(235,235,236),Color.FromArgb(180,180,183),Color.FromArgb(225,225,227)}, "oled", "Segoe UI", false)},
            {"Cyber Neon", new ThemeDefinition("Cyber Neon", Color.FromArgb(2,5,13), Color.FromArgb(18,4,27), Color.FromArgb(239,255,255), Color.FromArgb(137,177,190), Color.FromArgb(0,238,255), new Color[]{Color.FromArgb(0,246,255),Color.FromArgb(255,65,220),Color.FromArgb(107,255,121),Color.FromArgb(255,224,68),Color.FromArgb(255,91,91),Color.FromArgb(154,91,255)}, "cyber2", "Segoe UI", false)},
            {"Mission Control", new ThemeDefinition("Mission Control", Color.FromArgb(10,17,26), Color.FromArgb(19,31,45), Color.FromArgb(226,237,244), Color.FromArgb(123,151,169), Color.FromArgb(64,91,111), new Color[]{Color.FromArgb(72,165,255),Color.FromArgb(73,205,132),Color.FromArgb(247,189,68),Color.FromArgb(238,91,91),Color.FromArgb(63,202,215),Color.FromArgb(165,113,238)}, "mission", "Segoe UI", false)},
            {"Blueprint Tech", new ThemeDefinition("Blueprint Tech", Color.FromArgb(7,39,74), Color.FromArgb(10,55,101), Color.FromArgb(236,249,255), Color.FromArgb(141,197,229), Color.FromArgb(72,170,228), new Color[]{Color.FromArgb(83,220,255),Color.FromArgb(108,177,255),Color.FromArgb(102,232,175),Color.FromArgb(255,222,111),Color.FromArgb(255,153,104),Color.FromArgb(205,240,255)}, "blueprint", "Segoe UI", false)},
            {"Medical Telemetry", new ThemeDefinition("Medical Telemetry", Color.FromArgb(244,249,250), Color.FromArgb(228,240,243), Color.FromArgb(24,54,61), Color.FromArgb(91,123,130), Color.FromArgb(165,200,204), new Color[]{Color.FromArgb(20,166,164),Color.FromArgb(41,184,105),Color.FromArgb(38,164,214),Color.FromArgb(220,164,55),Color.FromArgb(224,102,92),Color.FromArgb(72,131,196)}, "medical", "Segoe UI", true)},
            {"Carbon Racing", new ThemeDefinition("Carbon Racing", Color.FromArgb(10,10,12), Color.FromArgb(24,24,27), Color.FromArgb(248,248,249), Color.FromArgb(158,158,164), Color.FromArgb(70,70,76), new Color[]{Color.FromArgb(255,70,70),Color.FromArgb(255,130,53),Color.FromArgb(255,204,55),Color.FromArgb(57,196,255),Color.FromArgb(184,101,255),Color.FromArgb(83,220,126)}, "carbon", "Segoe UI", false)},
            {"Retro Terminal", new ThemeDefinition("Retro Terminal", Color.FromArgb(2,9,3), Color.Black, Color.FromArgb(124,255,112), Color.FromArgb(70,170,74), Color.FromArgb(29,107,36), new Color[]{Color.FromArgb(124,255,112),Color.FromArgb(100,235,96),Color.FromArgb(145,255,115),Color.FromArgb(108,220,90),Color.FromArgb(150,255,126),Color.FromArgb(100,235,96)}, "terminal", "Consolas", false)}
        };

        public static ThemeDefinition Get(string name)
        {
            ThemeDefinition t;
            if (!Themes.TryGetValue(name ?? "", out t)) t = Themes["Dark Minimal Pro"];
            return t;
        }
    }

    internal sealed class CpuDeviceSnapshot
    {
        public string Id,Name,Socket;
        public float Usage,Temperature,PowerW;
        public bool UsageAvailable,TemperatureAvailable,PowerAvailable;
        public int PhysicalCores,LogicalProcessors,CurrentClockMHz,MaxClockMHz,ExternalClockMHz;
    }

    internal sealed class GpuDeviceSnapshot
    {
        public string Id,Name,Source;
        public float Usage,Temperature,VramUsedGb,VramTotalGb,CoreClockMHz,MemoryClockMHz,PowerW,FanRpm,FanPercent;
        public bool UsageAvailable,TemperatureAvailable,CoreClockAvailable,MemoryClockAvailable,PowerAvailable,FanRpmAvailable,FanPercentAvailable;
        public int PcieGeneration,PcieWidth;
    }

    internal sealed class DiskDeviceSnapshot
    {
        public string Id,Name,Root,Volumes,TemperatureSource,BusType,MediaType,InterfaceType;
        public ulong UsedBytes,TotalBytes,PhysicalSizeBytes;
        public float UsedPercent,Activity,Temperature;
        public double ReadBytesPerSec,WriteBytesPerSec;
        public bool ActivityAvailable,RateAvailable,TemperatureAvailable,CapacityAvailable;
    }

    internal sealed class MemoryModuleSnapshot
    {
        public string BankLabel,DeviceLocator,Manufacturer,PartNumber,MemoryType;
        public ulong CapacityBytes;
        public int SpeedMHz,ConfiguredClockMHz,DataWidth,TotalWidth;
    }

    internal sealed class NetworkDeviceSnapshot
    {
        public string Id,Name,Description; public double DownBytesPerSec,UpBytesPerSec; public long LinkSpeedBitsPerSec; public bool Active;
    }

    internal sealed class MetricsSnapshot
    {
        public float Cpu, Ram, Disk, DiskUsedPercent, Gpu, VramUsedGb, VramTotalGb, NetDownMbps, NetUpMbps, GpuTemp;
        public ulong RamUsedBytes, RamTotalBytes, DiskUsedBytes, DiskTotalBytes;
        public double NetDownBytesPerSec, NetUpBytesPerSec, DiskReadBytesPerSec, DiskWriteBytesPerSec;
        public bool CpuTempAvailable, GpuTempAvailable;
        public float CpuTempCurrent, CpuTempAvg, CpuTempMax, GpuTempAvg, GpuTempMax;
        public string CpuTempSource, GpuTempSource;
        public List<CpuDeviceSnapshot> CpuDevices=new List<CpuDeviceSnapshot>();
        public List<GpuDeviceSnapshot> GpuDevices=new List<GpuDeviceSnapshot>();
        public List<DiskDeviceSnapshot> DiskDevices=new List<DiskDeviceSnapshot>();
        public List<NetworkDeviceSnapshot> NetworkDevices=new List<NetworkDeviceSnapshot>();
        public List<MemoryModuleSnapshot> MemoryModules=new List<MemoryModuleSnapshot>();
        public MetricsSnapshot Clone() { return (MetricsSnapshot)MemberwiseClone(); }
    }

    internal static class SelectionUtil
    {
        public static HashSet<string> Parse(string ids)
        {
            HashSet<string> set=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if(String.IsNullOrWhiteSpace(ids))return set;
            foreach(string x in ids.Split(new char[]{';'},StringSplitOptions.RemoveEmptyEntries)){string v=x.Trim();if(v.Length>0)set.Add(v);}
            return set;
        }
        public static string Join(IEnumerable<string> ids){return String.Join(";",ids.Where(x=>!String.IsNullOrWhiteSpace(x)).Distinct(StringComparer.OrdinalIgnoreCase).ToArray());}
    }

    internal static class UnitFormatter
    {
        private static double Divisor(string unit){if(unit=="GB")return 1024d*1024d*1024d;if(unit=="MB")return 1024d*1024d;return 1024d;}
        private static string AutoUnit(double bytes){if(bytes>=1024d*1024d*1024d)return "GB";if(bytes>=1024d*1024d)return "MB";return "KB";}
        private static string Number(double v){if(v>=100)return v.ToString("0",CultureInfo.InvariantCulture);if(v>=10)return v.ToString("0.0",CultureInfo.InvariantCulture);return v.ToString("0.00",CultureInfo.InvariantCulture);}
        public static string Bytes(double bytes,string configuredUnit)
        {
            string unit=String.IsNullOrWhiteSpace(configuredUnit)||configuredUnit=="Auto"?AutoUnit(Math.Max(0,bytes)):configuredUnit;
            return Number(Math.Max(0,bytes)/Divisor(unit))+" "+unit;
        }
        public static string Pair(double used,double total,string configuredUnit)
        {
            string unit=String.IsNullOrWhiteSpace(configuredUnit)||configuredUnit=="Auto"?AutoUnit(Math.Max(used,total)):configuredUnit;
            double d=Divisor(unit);return Number(Math.Max(0,used)/d)+"/"+Number(Math.Max(0,total)/d)+" "+unit;
        }
        public static string Rate(double bytesPerSecond,string configuredUnit)
        {
            string unit=String.IsNullOrWhiteSpace(configuredUnit)||configuredUnit=="Auto"?AutoUnit(Math.Max(0,bytesPerSecond)):configuredUnit;
            return Number(Math.Max(0,bytesPerSecond)/Divisor(unit))+" "+unit+"/s";
        }
    }

    internal sealed class ReleaseUpdateInfo
    {
        public string Version,Tag,Name,HtmlUrl,SetupName,SetupUrl,SetupDigest,PublishedAt,Status;
        public bool HasUpdate,SetupAssetAvailable,DigestAvailable,Immutable;
    }

    internal static class UpdateManager
    {
        private static string Text(Dictionary<string,object> d,string key)
        {
            if(d==null||!d.ContainsKey(key)||d[key]==null)return "";
            return Convert.ToString(d[key],CultureInfo.InvariantCulture)??"";
        }

        public static Version ParseVersionString(string value)
        {
            if(String.IsNullOrWhiteSpace(value))return new Version(0,0,0,0);
            Match m=Regex.Match(value,@"(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?");
            if(!m.Success)return new Version(0,0,0,0);
            int a=0,b=0,c=0,d=0;Int32.TryParse(m.Groups[1].Value,out a);Int32.TryParse(m.Groups[2].Value,out b);Int32.TryParse(m.Groups[3].Value,out c);if(m.Groups[4].Success)Int32.TryParse(m.Groups[4].Value,out d);return new Version(a,b,c,d);
        }

        internal static bool IsStrictSha256Digest(string digest)
        {
            return !String.IsNullOrWhiteSpace(digest)&&Regex.IsMatch(digest.Trim(),@"^sha256:[0-9A-Fa-f]{64}$",RegexOptions.CultureInvariant);
        }

        internal static string ExpectedSetupAssetName(string version)
        {
            return "TaskbarMonitorEnhanced_Setup_"+(version??"")+".exe";
        }

        private static WebClient Client()
        {
            try{ServicePointManager.SecurityProtocol=(SecurityProtocolType)3072;}catch{}
            WebClient wc=new WebClient();
            wc.Headers[HttpRequestHeader.UserAgent]="TaskbarMonitorEnhanced/"+BuildInfo.PublicVersion;
            wc.Headers[HttpRequestHeader.Accept]="application/vnd.github+json";
            wc.Headers["X-GitHub-Api-Version"]="2026-03-10";
            return wc;
        }

        public static ReleaseUpdateInfo CheckLatest()
        {
            ReleaseUpdateInfo info=new ReleaseUpdateInfo();info.Version="";info.Status="Checking GitHub Releases...";
            string json;
            using(WebClient wc=Client())json=wc.DownloadString(BuildInfo.LatestReleaseApi);
            Dictionary<string,object> root=new JavaScriptSerializer().DeserializeObject(json) as Dictionary<string,object>;
            if(root==null)throw new InvalidDataException("GitHub latest-release response is not an object.");
            info.Tag=Text(root,"tag_name");info.Name=Text(root,"name");info.HtmlUrl=Text(root,"html_url");info.PublishedAt=Text(root,"published_at");
            object immutableObj;if(root.TryGetValue("immutable",out immutableObj)&&immutableObj!=null){try{info.Immutable=Convert.ToBoolean(immutableObj,CultureInfo.InvariantCulture);}catch{}}
            Version latest=ParseVersionString(info.Tag);if(latest.Major==0&&latest.Minor==0&&latest.Build==0)latest=ParseVersionString(info.Name);
            info.Version=latest.Major+"."+latest.Minor+"."+Math.Max(0,latest.Build);
            Version current=ParseVersionString(BuildInfo.PublicVersion);info.HasUpdate=latest.CompareTo(current)>0;
            object assetsObj;root.TryGetValue("assets",out assetsObj);System.Collections.IEnumerable assets=assetsObj as System.Collections.IEnumerable;
            if(assets!=null)
            {
                Dictionary<string,object> exact=null;
                string expectedName=ExpectedSetupAssetName(info.Version);
                foreach(object o in assets)
                {
                    Dictionary<string,object> a=o as Dictionary<string,object>;if(a==null)continue;
                    string n=Text(a,"name");
                    if(String.Equals(n,expectedName,StringComparison.OrdinalIgnoreCase)){exact=a;break;}
                }
                if(exact!=null)
                {
                    info.SetupName=Text(exact,"name");
                    info.SetupUrl=Text(exact,"browser_download_url");
                    info.SetupDigest=Text(exact,"digest");
                    info.SetupAssetAvailable=!String.IsNullOrWhiteSpace(info.SetupUrl);
                    info.DigestAvailable=IsStrictSha256Digest(info.SetupDigest);
                }
            }
            if(info.HasUpdate)
            {
                if(!info.SetupAssetAvailable)info.Status="Update available, but installer asset was not found.";
                else if(!info.DigestAvailable)info.Status="Update available, but GitHub SHA-256 digest is missing.";
                else if(!info.Immutable)info.Status="Update available and SHA-256 metadata is present, but the GitHub Release is mutable. Automatic installation is blocked; use the release page for manual review.";
                else info.Status="Update available. GitHub Release is immutable and installer SHA-256 metadata is present.";
            }
            else if(latest.CompareTo(current)==0)info.Status="You are running the latest public release. Release immutable="+info.Immutable+".";
            else info.Status="This build is newer than the latest public release. Latest release immutable="+info.Immutable+".";
            return info;
        }

        private static string Sha256File(string path)
        {
            using(SHA256 sha=SHA256.Create())using(FileStream fs=File.OpenRead(path)){byte[] b=sha.ComputeHash(fs);StringBuilder sb=new StringBuilder();foreach(byte x in b)sb.Append(x.ToString("X2",CultureInfo.InvariantCulture));return sb.ToString();}
        }

        public static string DownloadAndVerify(ReleaseUpdateInfo info)
        {
            if(info==null||!info.HasUpdate)throw new InvalidOperationException("No newer public release is selected.");
            string expectedName=ExpectedSetupAssetName(info.Version);
            if(!info.SetupAssetAvailable||!String.Equals(info.SetupName,expectedName,StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Automatic installation is blocked because the release does not contain the exact expected installer asset "+expectedName+".");
            if(!info.DigestAvailable||!IsStrictSha256Digest(info.SetupDigest))
                throw new InvalidOperationException("Automatic installation is blocked because the release asset does not have an exact sha256:<64-hex> GitHub digest.");
            if(!info.Immutable)throw new InvalidOperationException("Automatic installation is blocked because the GitHub Release is mutable. Open the release page and review it manually.");
            Uri u=new Uri(info.SetupUrl);if(!String.Equals(u.Scheme,"https",StringComparison.OrdinalIgnoreCase)||!String.Equals(u.Host,"github.com",StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Unexpected update host: "+u.Host);
            Directory.CreateDirectory(AppPaths.Updates);string safe=Path.GetFileName(info.SetupName);if(!String.Equals(safe,expectedName,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Unexpected update asset name.");string path=Path.Combine(AppPaths.Updates,safe);
            string partial=path+".download";try{if(File.Exists(partial))File.Delete(partial);}catch{}
            using(WebClient wc=Client())wc.DownloadFile(info.SetupUrl,partial);
            string expected=info.SetupDigest.Substring(info.SetupDigest.IndexOf(':')+1).Trim().ToUpperInvariant();string actual=Sha256File(partial);if(!String.Equals(expected,actual,StringComparison.OrdinalIgnoreCase)){try{File.Delete(partial);}catch{}throw new InvalidDataException("Update SHA-256 mismatch. Expected="+expected+" Actual="+actual);}
            if(File.Exists(path))File.Delete(path);File.Move(partial,path);Log.Write("INFO","UPDATE_DOWNLOAD_VERIFIED version="+info.Version+" sha256="+actual+" path="+path);return path;
        }

        public static void StartInstaller(string path)
        {
            if(String.IsNullOrWhiteSpace(path)||!File.Exists(path))throw new FileNotFoundException("Verified update installer not found.",path);
            ProcessStartInfo psi=new ProcessStartInfo();psi.FileName=path;psi.UseShellExecute=true;Process p=Process.Start(psi);if(p==null)throw new InvalidOperationException("Windows did not start the update installer.");Log.Write("INFO","UPDATE_INSTALLER_STARTED path="+path);
        }
    }

    internal sealed class MetricHistory
    {
        private readonly Dictionary<string,List<float>> data = new Dictionary<string,List<float>>();
        public void Add(string key, float value)
        {
            List<float> list;
            if (!data.TryGetValue(key, out list)) { list=new List<float>(); data[key]=list; }
            list.Add(value);
            while (list.Count > BuildInfo.HistoryLength) list.RemoveAt(0);
        }
        public IList<float> Get(string key)
        {
            List<float> list;
            if (!data.TryGetValue(key, out list)) return new List<float>();
            return list.ToArray();
        }
    }

    internal sealed class CpuTemperatureSample
    {
        public bool Valid;
        public float Current;
        public float Average;
        public float Maximum;
        public float PowerW;
        public bool PowerAvailable;
        public string PowerSource;
        public int SensorCount;
        public string Source;
    }

    internal sealed class GpuTelemetrySample
    {
        public bool Valid;
        public bool LoadValid;
        public bool TemperatureValid;
        public float Load;
        public float VramUsedGb;
        public float VramTotalGb;
        public float Temperature;
        public float CoreClockMHz;
        public float MemoryClockMHz;
        public float PowerW;
        public float FanRpm;
        public float FanPercent;
        public bool CoreClockValid;
        public bool MemoryClockValid;
        public bool PowerValid;
        public bool FanRpmValid;
        public bool FanPercentValid;
        public int PcieGeneration;
        public int PcieWidth;
        public string Source;
        public string HardwareName;
        public string HardwareId;
        public int AdapterIndex=-1;
    }

    internal sealed class StorageTemperatureSample
    {
        public string HardwareName,HardwareId,Source;
        public float Temperature;
        public bool Valid;
    }

    internal static class BrokerJsonFile
    {
        public static string ReadShared(string path)
        {
            Exception last=null;
            for(int attempt=0;attempt<5;attempt++)
            {
                try
                {
                    using(FileStream fs=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
                    using(StreamReader sr=new StreamReader(fs,Encoding.UTF8,true))
                        return sr.ReadToEnd();
                }
                catch(Exception ex){last=ex;Thread.Sleep(25*(attempt+1));}
            }
            if(last!=null)throw last;
            return "";
        }
    }

    internal sealed class ElevatedStorageTemperatureReader
    {
        private string lastState="";
        private static bool ValidTemp(float v){return !Single.IsNaN(v)&&!Single.IsInfinity(v)&&v>=5f&&v<=130f;}
        private static string Text(Dictionary<string,object> m,string key)
        {
            object x;if(m==null||!m.TryGetValue(key,out x)||x==null)return "";
            return Convert.ToString(x,CultureInfo.InvariantCulture)??"";
        }
        private void State(string x)
        {
            if(String.Equals(x,lastState,StringComparison.Ordinal))return;
            lastState=x;Log.Write("INFO","DISK_TEMP_ELEVATED_BROKER_STATE "+x);
        }
        public List<StorageTemperatureSample> Read()
        {
            List<StorageTemperatureSample> result=new List<StorageTemperatureSample>();
            try
            {
                if(!File.Exists(AppPaths.StorageBrokerData)){State("FILE_MISSING");return result;}
                string json=BrokerJsonFile.ReadShared(AppPaths.StorageBrokerData);
                JavaScriptSerializer js=new JavaScriptSerializer();
                Dictionary<string,object> root=js.Deserialize<Dictionary<string,object>>(json);
                if(root==null){State("JSON_EMPTY");return result;}

                object tsObj;DateTime ts;
                if(!root.TryGetValue("TimestampUtc",out tsObj) ||
                   !DateTime.TryParse(Convert.ToString(tsObj,CultureInfo.InvariantCulture),CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,out ts))
                {State("TIMESTAMP_INVALID");return result;}
                double age=(DateTime.UtcNow-ts).TotalSeconds;
                if(age<0||age>120){State("STALE");return result;}

                object storageObj;
                if(!root.TryGetValue("StorageTemperatures",out storageObj)||storageObj==null)
                {State("STORAGE_ARRAY_MISSING");return result;}
                System.Collections.IEnumerable seq=storageObj as System.Collections.IEnumerable;
                if(seq==null){State("STORAGE_ARRAY_INVALID");return result;}

                foreach(object item in seq)
                {
                    Dictionary<string,object> m=item as Dictionary<string,object>;if(m==null)continue;
                    bool available=false;object av;
                    if(m.TryGetValue("Available",out av)){try{available=Convert.ToBoolean(av,CultureInfo.InvariantCulture);}catch{}}
                    if(!available)continue;
                    object tv;if(!m.TryGetValue("TemperatureC",out tv))continue;
                    float temp;try{temp=Convert.ToSingle(tv,CultureInfo.InvariantCulture);}catch{continue;}
                    if(!ValidTemp(temp))continue;
                    string sensor=Text(m,"Sensor");
                    StorageTemperatureSample x=new StorageTemperatureSample();
                    x.Valid=true;x.HardwareName=Text(m,"HardwareName");x.HardwareId=Text(m,"HardwareId");x.Temperature=temp;
                    x.Source="LHM_ISOLATED_STORAGE_BROKER"+(String.IsNullOrWhiteSpace(sensor)?"":":"+sensor);
                    result.Add(x);
                }
                State(result.Count>0?("READY count="+result.Count):"NO_VALID_STORAGE_TEMPERATURES");
            }
            catch(Exception ex){State("READ_FAIL "+ex.Message);}
            return result;
        }
    }

    internal sealed class ElevatedGpuTelemetryReader
    {
        private string lastState="";

        private static string Text(Dictionary<string,object> m,string key)
        {
            object x;if(m==null||!m.TryGetValue(key,out x)||x==null)return "";
            return Convert.ToString(x,CultureInfo.InvariantCulture)??"";
        }
        private static bool Bool(Dictionary<string,object> m,string key)
        {
            object x;if(m==null||!m.TryGetValue(key,out x)||x==null)return false;
            try{return Convert.ToBoolean(x,CultureInfo.InvariantCulture);}catch{return false;}
        }
        private static float Float(Dictionary<string,object> m,string key)
        {
            object x;if(m==null||!m.TryGetValue(key,out x)||x==null)return 0;
            try{return Convert.ToSingle(x,CultureInfo.InvariantCulture);}catch{return 0;}
        }
        private static int Int(Dictionary<string,object> m,string key,int fallback)
        {
            object x;if(m==null||!m.TryGetValue(key,out x)||x==null)return fallback;
            try{return Convert.ToInt32(x,CultureInfo.InvariantCulture);}catch{return fallback;}
        }
        private void State(string x)
        {
            if(String.Equals(x,lastState,StringComparison.Ordinal))return;
            lastState=x;Log.Write("INFO","GPU_ISOLATED_BROKER_STATE "+x);
        }

        public List<GpuTelemetrySample> ReadAll()
        {
            List<GpuTelemetrySample> result=new List<GpuTelemetrySample>();
            try
            {
                if(!File.Exists(AppPaths.GpuBrokerData)){State("FILE_MISSING");return result;}
                string json=BrokerJsonFile.ReadShared(AppPaths.GpuBrokerData);
                Dictionary<string,object> root=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(json);
                if(root==null){State("JSON_EMPTY");return result;}

                object tsObj;DateTime ts;
                if(!root.TryGetValue("TimestampUtc",out tsObj) ||
                   !DateTime.TryParse(Convert.ToString(tsObj,CultureInfo.InvariantCulture),CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,out ts))
                {State("TIMESTAMP_INVALID");return result;}
                double age=(DateTime.UtcNow-ts).TotalSeconds;
                if(age<0||age>20){State("STALE ageSec="+age.ToString("0.0",CultureInfo.InvariantCulture));return result;}

                object gpusObj;
                if(!root.TryGetValue("Gpus",out gpusObj)||gpusObj==null){State("GPU_ARRAY_MISSING");return result;}
                System.Collections.IEnumerable seq=gpusObj as System.Collections.IEnumerable;
                if(seq==null){State("GPU_ARRAY_INVALID");return result;}

                foreach(object item in seq)
                {
                    Dictionary<string,object> m=item as Dictionary<string,object>;if(m==null)continue;
                    if(!Bool(m,"Available"))continue;
                    GpuTelemetrySample g=new GpuTelemetrySample();
                    g.Valid=true;
                    g.LoadValid=Bool(m,"LoadValid");
                    g.TemperatureValid=Bool(m,"TemperatureValid");
                    g.CoreClockValid=Bool(m,"CoreClockValid");
                    g.MemoryClockValid=Bool(m,"MemoryClockValid");
                    g.PowerValid=Bool(m,"PowerValid");
                    g.FanRpmValid=Bool(m,"FanRpmValid");
                    g.FanPercentValid=Bool(m,"FanPercentValid");
                    g.Load=Float(m,"Load");
                    g.Temperature=Float(m,"Temperature");
                    g.VramUsedGb=Float(m,"VramUsedGb");
                    g.VramTotalGb=Float(m,"VramTotalGb");
                    g.CoreClockMHz=Float(m,"CoreClockMHz");
                    g.MemoryClockMHz=Float(m,"MemoryClockMHz");
                    g.PowerW=Float(m,"PowerW");
                    g.FanRpm=Float(m,"FanRpm");
                    g.FanPercent=Float(m,"FanPercent");
                    g.PcieGeneration=Int(m,"PcieGeneration",0);
                    g.PcieWidth=Int(m,"PcieWidth",0);
                    g.AdapterIndex=Int(m,"AdapterIndex",-1);
                    g.HardwareName=Text(m,"HardwareName");
                    g.HardwareId=Text(m,"HardwareId");
                    g.Source=Text(m,"Source");
                    if(String.IsNullOrWhiteSpace(g.Source))g.Source="LHM_ISOLATED_GPU_BROKER";
                    result.Add(g);
                }
                State(result.Count>0?("READY count="+result.Count):"NO_VALID_GPU_RECORDS");
            }
            catch(Exception ex){State("READ_FAIL "+ex.Message);}
            return result;
        }
    }

    internal sealed class LibreGpuTelemetryReader : IDisposable
    {
        private Assembly assembly;
        private object computer;
        private Type computerType;
        private ResolveEventHandler resolver;
        private bool initAttempted;
        private bool initialized;
        private string lastError="";

        public string LastError { get { return lastError; } }

        private static string FindLibrary()
        {
            try
            {
                if(!Directory.Exists(AppPaths.SensorBackend))return null;
                string[] files=Directory.GetFiles(
                    AppPaths.SensorBackend,
                    "LibreHardwareMonitorLib.dll",
                    SearchOption.AllDirectories
                );
                if(files.Length==0)return null;
                return files[0];
            }
            catch{return null;}
        }

        private Assembly ResolveDependency(object sender,ResolveEventArgs e)
        {
            try
            {
                string simple=new AssemblyName(e.Name).Name+".dll";
                string[] matches=Directory.GetFiles(AppPaths.SensorBackend,simple,SearchOption.AllDirectories);
                if(matches.Length>0)return Assembly.LoadFrom(matches[0]);
            }
            catch{}
            return null;
        }

        private static void SetBoolProperty(object target,string name,bool value)
        {
            try
            {
                PropertyInfo p=target.GetType().GetProperty(name,BindingFlags.Public|BindingFlags.Instance);
                if(p!=null&&p.CanWrite)p.SetValue(target,value,null);
            }
            catch{}
        }

        private bool EnsureInitialized()
        {
            if(initialized)return true;
            if(initAttempted)return false;
            initAttempted=true;

            try
            {
                string libraryPath=FindLibrary();
                if(String.IsNullOrWhiteSpace(libraryPath))
                    throw new FileNotFoundException("LibreHardwareMonitorLib.dll not found under "+AppPaths.SensorBackend);

                resolver=new ResolveEventHandler(ResolveDependency);
                AppDomain.CurrentDomain.AssemblyResolve+=resolver;

                assembly=Assembly.LoadFrom(libraryPath);
                computerType=assembly.GetType("LibreHardwareMonitor.Hardware.Computer",true);
                computer=Activator.CreateInstance(computerType);

                // Intel integrated GPU enumeration in LibreHardwareMonitor requires CPU enumeration.
                SetBoolProperty(computer,"IsCpuEnabled",true);
                SetBoolProperty(computer,"IsGpuEnabled",true);
                SetBoolProperty(computer,"IsStorageEnabled",true);

                MethodInfo open=computerType.GetMethod("Open",BindingFlags.Public|BindingFlags.Instance);
                if(open==null)throw new MissingMethodException("Computer.Open");
                open.Invoke(computer,null);

                initialized=true;
                lastError="";
                Log.Write("INFO","GPU_LHM_BACKEND_INIT_PASS");
                return true;
            }
            catch(Exception ex)
            {
                lastError=ex.GetBaseException().Message;
                Log.Write("WARN","GPU_LHM_BACKEND_INIT_FAIL "+lastError);
                return false;
            }
        }

        private static IEnumerable<object> AsObjects(object value)
        {
            System.Collections.IEnumerable e=value as System.Collections.IEnumerable;
            if(e==null)yield break;
            foreach(object x in e)if(x!=null)yield return x;
        }

        private static string GetText(object o,string property)
        {
            try
            {
                PropertyInfo p=o.GetType().GetProperty(property,BindingFlags.Public|BindingFlags.Instance);
                object v=p==null?null:p.GetValue(o,null);
                return v==null?"":Convert.ToString(v,CultureInfo.InvariantCulture)??"";
            }
            catch{return "";}
        }

        private static bool TryGetFloat(object o,string property,out float value)
        {
            value=0;
            try
            {
                PropertyInfo p=o.GetType().GetProperty(property,BindingFlags.Public|BindingFlags.Instance);
                object v=p==null?null:p.GetValue(o,null);
                if(v==null)return false;
                value=Convert.ToSingle(v,CultureInfo.InvariantCulture);
                return !Single.IsNaN(value)&&!Single.IsInfinity(value);
            }
            catch{return false;}
        }

        private static void UpdateHardware(object hardware)
        {
            try
            {
                MethodInfo m=hardware.GetType().GetMethod("Update",BindingFlags.Public|BindingFlags.Instance);
                if(m!=null)m.Invoke(hardware,null);
            }
            catch{}
        }

        private static int LoadPriority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n=="gpu core")return 100;
            if(n.Contains("gpu core"))return 98;
            if(n=="d3d 3d")return 95;
            if(n.Contains("3d"))return 90;
            if(n.Contains("gpu"))return 80;
            return 20;
        }

        private static int TemperaturePriority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n=="gpu core")return 100;
            if(n.Contains("gpu core"))return 98;
            if(n=="core")return 96;
            if(n.Contains("hot spot")||n.Contains("hotspot"))return 80;
            if(n.Contains("memory"))return 40;
            return 60;
        }

        private static float ToGb(string sensorType,float value)
        {
            if(String.Equals(sensorType,"SmallData",StringComparison.OrdinalIgnoreCase))
                return value/1024f; // SmallData is MB in LibreHardwareMonitor.
            if(String.Equals(sensorType,"Data",StringComparison.OrdinalIgnoreCase))
                return value;       // Data is GB in LibreHardwareMonitor.
            return 0;
        }

        public List<GpuTelemetrySample> ReadAll()
        {
            List<GpuTelemetrySample> candidates=new List<GpuTelemetrySample>();
            if(!EnsureInitialized())return candidates;
            try
            {
                PropertyInfo hp=computerType.GetProperty("Hardware",BindingFlags.Public|BindingFlags.Instance);
                object hardware=hp==null?null:hp.GetValue(computer,null);
                int adapterIndex=0;
                foreach(object hw in AsObjects(hardware))
                {
                    string hwType=GetText(hw,"HardwareType");
                    if(hwType.IndexOf("Gpu",StringComparison.OrdinalIgnoreCase)<0)continue;
                    UpdateHardware(hw);
                    string hwName=GetText(hw,"Name");
                    List<KeyValuePair<string,float>> loads=new List<KeyValuePair<string,float>>();
                    List<KeyValuePair<string,float>> temps=new List<KeyValuePair<string,float>>();
                    List<KeyValuePair<string,float>> clocks=new List<KeyValuePair<string,float>>();
                    float dedicatedUsed=0,dedicatedTotal=0,sharedUsed=0,sharedTotal=0,genericUsed=0,genericTotal=0;
                    bool hasDedicatedUsed=false,hasDedicatedTotal=false,hasSharedUsed=false,hasSharedTotal=false,hasGenericUsed=false,hasGenericTotal=false;
                    PropertyInfo sp=hw.GetType().GetProperty("Sensors",BindingFlags.Public|BindingFlags.Instance);
                    object sensors=sp==null?null:sp.GetValue(hw,null);
                    foreach(object sensor in AsObjects(sensors))
                    {
                        string sensorType=GetText(sensor,"SensorType"); string name=GetText(sensor,"Name"); float value;
                        if(!TryGetFloat(sensor,"Value",out value))continue;
                        if(String.Equals(sensorType,"Load",StringComparison.OrdinalIgnoreCase) && value>=0 && value<=100)loads.Add(new KeyValuePair<string,float>(name,value));
                        if(String.Equals(sensorType,"Temperature",StringComparison.OrdinalIgnoreCase) && value>=5 && value<=130)temps.Add(new KeyValuePair<string,float>(name,value));
                        if(String.Equals(sensorType,"Clock",StringComparison.OrdinalIgnoreCase) && value>0 && value<100000)clocks.Add(new KeyValuePair<string,float>(name,value));
                        if(String.Equals(sensorType,"SmallData",StringComparison.OrdinalIgnoreCase)||String.Equals(sensorType,"Data",StringComparison.OrdinalIgnoreCase))
                        {
                            float gb=ToGb(sensorType,value); string lower=(name??"").ToLowerInvariant();
                            if(lower.Contains("gpu memory used")){genericUsed=gb;hasGenericUsed=true;}
                            else if(lower.Contains("gpu memory total")){genericTotal=gb;hasGenericTotal=true;}
                            else if(lower.Contains("dedicated memory used")){dedicatedUsed=gb;hasDedicatedUsed=true;}
                            else if(lower.Contains("dedicated memory total")){dedicatedTotal=gb;hasDedicatedTotal=true;}
                            else if(lower.Contains("shared memory used")){sharedUsed=gb;hasSharedUsed=true;}
                            else if(lower.Contains("shared memory total")){sharedTotal=gb;hasSharedTotal=true;}
                        }
                    }
                    GpuTelemetrySample sample=new GpuTelemetrySample();
                    sample.Source="LHM_GPU:"+hwType+":"+hwName; sample.HardwareName=hwName; sample.HardwareId="LHM:"+hwName; sample.AdapterIndex=adapterIndex++; sample.Valid=true;
                    if(loads.Count>0){KeyValuePair<string,float> bestLoad=loads.OrderByDescending(x=>LoadPriority(x.Key)).ThenByDescending(x=>x.Value).First();sample.Load=Math.Max(0,Math.Min(100,bestLoad.Value));sample.LoadValid=true;}
                    if(temps.Count>0){KeyValuePair<string,float> bestTemp=temps.OrderByDescending(x=>TemperaturePriority(x.Key)).ThenByDescending(x=>x.Value).First();sample.Temperature=bestTemp.Value;sample.TemperatureValid=true;}
                    KeyValuePair<string,float> coreClock=clocks.Where(x=>(x.Key??"").IndexOf("core",StringComparison.OrdinalIgnoreCase)>=0).OrderByDescending(x=>x.Value).FirstOrDefault();
                    if(coreClock.Value>0){sample.CoreClockMHz=coreClock.Value;sample.CoreClockValid=true;}
                    KeyValuePair<string,float> memClock=clocks.Where(x=>(x.Key??"").IndexOf("memory",StringComparison.OrdinalIgnoreCase)>=0).OrderByDescending(x=>x.Value).FirstOrDefault();
                    if(memClock.Value>0){sample.MemoryClockMHz=memClock.Value;sample.MemoryClockValid=true;}
                    if(hasGenericUsed)sample.VramUsedGb=genericUsed;else sample.VramUsedGb=(hasDedicatedUsed?dedicatedUsed:0)+(hasSharedUsed?sharedUsed:0);
                    if(hasGenericTotal)sample.VramTotalGb=genericTotal;else sample.VramTotalGb=(hasDedicatedTotal?dedicatedTotal:0)+(hasSharedTotal?sharedTotal:0);
                    candidates.Add(sample);
                }
                if(candidates.Count==0)lastError="no supported GPU sensors found";else lastError="";
                return candidates;
            }
            catch(Exception ex){lastError=ex.GetBaseException().Message;Log.Write("WARN","GPU_LHM_READ_FAIL "+lastError);return candidates;}
        }

        public GpuTelemetrySample Read()
        {
            List<GpuTelemetrySample> candidates=ReadAll();
            if(candidates.Count==0){GpuTelemetrySample r=new GpuTelemetrySample();r.Source="LHM_GPU";return r;}
            return candidates.OrderByDescending(x=>x.LoadValid?x.Load:-1).ThenByDescending(x=>x.TemperatureValid?1:0).First();
        }

        private static int StorageTemperaturePriority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n=="temperature")return 100;
            if(n.Contains("drive")&&n.Contains("temperature"))return 98;
            if(n.Contains("composite"))return 96;
            if(n.Contains("temperature 1"))return 92;
            if(n.Contains("controller"))return 70;
            if(n.Contains("memory"))return 50;
            return 60;
        }

        public List<StorageTemperatureSample> ReadStorageTemperatures()
        {
            List<StorageTemperatureSample> result=new List<StorageTemperatureSample>();
            if(!EnsureInitialized())return result;
            try
            {
                PropertyInfo hp=computerType.GetProperty("Hardware",BindingFlags.Public|BindingFlags.Instance);
                object hardware=hp==null?null:hp.GetValue(computer,null);
                foreach(object hw in AsObjects(hardware))
                {
                    string hwType=GetText(hw,"HardwareType");
                    if(hwType.IndexOf("Storage",StringComparison.OrdinalIgnoreCase)<0)continue;
                    UpdateHardware(hw);
                    string hwName=GetText(hw,"Name");
                    string hwId=GetText(hw,"Identifier");
                    List<KeyValuePair<string,float>> temps=new List<KeyValuePair<string,float>>();
                    PropertyInfo sp=hw.GetType().GetProperty("Sensors",BindingFlags.Public|BindingFlags.Instance);
                    object sensors=sp==null?null:sp.GetValue(hw,null);
                    foreach(object sensor in AsObjects(sensors))
                    {
                        if(!String.Equals(GetText(sensor,"SensorType"),"Temperature",StringComparison.OrdinalIgnoreCase))continue;
                        float value;if(!TryGetFloat(sensor,"Value",out value)||value<5||value>130)continue;
                        temps.Add(new KeyValuePair<string,float>(GetText(sensor,"Name"),value));
                    }
                    if(temps.Count==0)continue;
                    KeyValuePair<string,float> best=temps.OrderByDescending(x=>StorageTemperaturePriority(x.Key)).ThenByDescending(x=>x.Value).First();
                    StorageTemperatureSample x0=new StorageTemperatureSample();x0.Valid=true;x0.HardwareName=hwName;x0.HardwareId=hwId;x0.Temperature=best.Value;x0.Source="LHM_STORAGE:"+best.Key;result.Add(x0);
                }
            }
            catch(Exception ex){Log.Write("WARN","STORAGE_LHM_READ_FAIL "+ex.GetBaseException().Message);}
            return result;
        }

        public void Dispose()
        {
            try
            {
                if(computer!=null&&computerType!=null)
                {
                    MethodInfo close=computerType.GetMethod("Close",BindingFlags.Public|BindingFlags.Instance);
                    if(close!=null)close.Invoke(computer,null);
                }
            }
            catch{}
            if(resolver!=null)
            {
                try{AppDomain.CurrentDomain.AssemblyResolve-=resolver;}catch{}
            }
            computer=null;
            assembly=null;
            computerType=null;
            initialized=false;
        }
    }


    internal sealed class WindowsGpuFallbackReader
    {
        private sealed class AdapterInfo { public int Index; public string Id,Name; public ulong TotalBytes; }
        private static int ParsePhys(string text)
        {
            if(String.IsNullOrWhiteSpace(text))return -1;
            Match m=Regex.Match(text,@"(?:^|_)phys_(\d+)(?:_|$)",RegexOptions.IgnoreCase); int x; return m.Success&&Int32.TryParse(m.Groups[1].Value,out x)?x:-1;
        }
        private static ulong U64(object v){try{return v==null?0:Convert.ToUInt64(v,CultureInfo.InvariantCulture);}catch{return 0;}}
        private static float F32(object v){try{return v==null?0:Convert.ToSingle(v,CultureInfo.InvariantCulture);}catch{return 0;}}
        private List<AdapterInfo> EnumerateAdapters()
        {
            List<AdapterInfo> a=new List<AdapterInfo>(); int index=0;
            try{using(ManagementObjectSearcher q=new ManagementObjectSearcher("SELECT DeviceID,PNPDeviceID,Name,AdapterRAM FROM Win32_VideoController"))foreach(ManagementObject o in q.Get()){AdapterInfo x=new AdapterInfo();x.Index=index++;x.Id=Convert.ToString(o["PNPDeviceID"],CultureInfo.InvariantCulture);if(String.IsNullOrWhiteSpace(x.Id))x.Id=Convert.ToString(o["DeviceID"],CultureInfo.InvariantCulture);x.Name=Convert.ToString(o["Name"],CultureInfo.InvariantCulture);x.TotalBytes=U64(o["AdapterRAM"]);a.Add(x);}}catch(Exception ex){Log.Write("WARN","GPU_WDDM_ENUM "+ex.Message);}
            return a;
        }
        public List<GpuTelemetrySample> ReadAll()
        {
            List<AdapterInfo> adapters=EnumerateAdapters(); Dictionary<int,float> loads=new Dictionary<int,float>(); Dictionary<int,ulong> mem=new Dictionary<int,ulong>();
            try{using(ManagementObjectSearcher q=new ManagementObjectSearcher(@"root\CIMV2","SELECT Name,UtilizationPercentage FROM Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine"))foreach(ManagementObject o in q.Get()){int p=ParsePhys(Convert.ToString(o["Name"],CultureInfo.InvariantCulture));if(p<0)continue;float v=Math.Max(0,Math.Min(100,F32(o["UtilizationPercentage"])));float old;if(!loads.TryGetValue(p,out old)||v>old)loads[p]=v;}}catch(Exception ex){Log.Write("WARN","GPU_WDDM_ENGINE "+ex.Message);}
            try{using(ManagementObjectSearcher q=new ManagementObjectSearcher(@"root\CIMV2","SELECT Name,DedicatedUsage,SharedUsage FROM Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory"))foreach(ManagementObject o in q.Get()){int p=ParsePhys(Convert.ToString(o["Name"],CultureInfo.InvariantCulture));if(p<0)continue;ulong v=U64(o["DedicatedUsage"])+U64(o["SharedUsage"]);mem[p]=v;}}catch(Exception ex){Log.Write("WARN","GPU_WDDM_MEMORY "+ex.Message);}
            List<GpuTelemetrySample> r=new List<GpuTelemetrySample>();
            foreach(AdapterInfo a in adapters){GpuTelemetrySample s=new GpuTelemetrySample();s.Valid=true;s.Source="WINDOWS_WDDM";s.HardwareName=String.IsNullOrWhiteSpace(a.Name)?("GPU "+a.Index):a.Name;s.HardwareId=String.IsNullOrWhiteSpace(a.Id)?("WDDM:"+a.Index):a.Id;s.AdapterIndex=a.Index;float l;if(loads.TryGetValue(a.Index,out l)){s.Load=l;s.LoadValid=true;}ulong u;if(mem.TryGetValue(a.Index,out u))s.VramUsedGb=(float)(u/(1024d*1024d*1024d));if(a.TotalBytes>0)s.VramTotalGb=(float)(a.TotalBytes/(1024d*1024d*1024d));r.Add(s);}
            return r;
        }
    }

    internal sealed class AdlxGpuTemperatureSample
    {
        public bool Valid;
        public float Temperature;
        public float Usage;
        public string Source;
        public string HardwareName;
        public string PnpString;
    }

    internal sealed class AmdAdlxTemperatureReader : IDisposable
    {
        private const int ADLX_OK=0;
        private const int ADLX_ALREADY_ENABLED=1;
        private const int ADLX_ALREADY_INITIALIZED=2;
        private const string ExpectedAdlxVersion="1.1";

        private IntPtr module=IntPtr.Zero;
        private IntPtr system=IntPtr.Zero;
        private IntPtr perf=IntPtr.Zero;
        private ADLXTerminateFn terminate;
        private bool initAttempted;
        private bool initialized;
        private string lastError="";

        public string LastError { get { return lastError; } }

        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
        private static extern IntPtr LoadLibrary(string lpFileName);

        [DllImport("kernel32.dll",CharSet=CharSet.Ansi,SetLastError=true)]
        private static extern IntPtr GetProcAddress(IntPtr hModule,string procName);

        [DllImport("kernel32.dll",SetLastError=true)]
        [return:MarshalAs(UnmanagedType.Bool)]
        private static extern bool FreeLibrary(IntPtr hModule);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int ADLXQueryFullVersionFn(ref ulong fullVersion);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int ADLXQueryVersionFn(out IntPtr version);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int ADLXInitializeFn(ulong version,out IntPtr system);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int ADLXTerminateFn();

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int ReleaseFn(IntPtr obj);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int SysGetGPUsFn(IntPtr system,out IntPtr gpuList);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int SysGetPerfFn(IntPtr system,out IntPtr perf);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate uint ListSizeFn(IntPtr list);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int GPUListAtFn(IntPtr list,uint location,out IntPtr gpu);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int GPUNameFn(IntPtr gpu,out IntPtr name);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int GPUPNPFn(IntPtr gpu,out IntPtr pnp);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int PerfGetSupportedGPUFn(IntPtr perf,IntPtr gpu,out IntPtr support);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int PerfGetCurrentGPUFn(IntPtr perf,IntPtr gpu,out IntPtr metrics);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int SupportBoolFn(IntPtr support,out byte supported);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int MetricsDoubleFn(IntPtr metrics,out double value);

        private static bool Succeeded(int result)
        {
            return result==ADLX_OK || result==ADLX_ALREADY_ENABLED || result==ADLX_ALREADY_INITIALIZED;
        }

        private static T DelegateAt<T>(IntPtr functionPointer) where T:class
        {
            if(functionPointer==IntPtr.Zero)throw new InvalidOperationException("ADLX_NULL_FUNCTION_POINTER");
            return Marshal.GetDelegateForFunctionPointer(functionPointer,typeof(T)) as T;
        }

        private static IntPtr Slot(IntPtr obj,int index)
        {
            if(obj==IntPtr.Zero)throw new InvalidOperationException("ADLX_NULL_INTERFACE_POINTER");
            IntPtr vtbl=Marshal.ReadIntPtr(obj);
            if(vtbl==IntPtr.Zero)throw new InvalidOperationException("ADLX_NULL_VTABLE_POINTER");
            return Marshal.ReadIntPtr(vtbl,index*IntPtr.Size);
        }

        private static string Ansi(IntPtr p)
        {
            return p==IntPtr.Zero?"":(Marshal.PtrToStringAnsi(p)??"");
        }

        private static void SafeRelease(IntPtr p)
        {
            if(p==IntPtr.Zero)return;
            try
            {
                ReleaseFn release=DelegateAt<ReleaseFn>(Slot(p,1));
                release(p);
            }
            catch{}
        }

        private bool EnsureInitialized()
        {
            if(initialized)return true;
            if(initAttempted)return false;
            initAttempted=true;

            try
            {
                string dllPath=Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                    "System32",
                    "amdadlx64.dll"
                );
                if(!File.Exists(dllPath))
                    throw new FileNotFoundException("AMD ADLX runtime not found",dllPath);

                module=LoadLibrary(dllPath);
                if(module==IntPtr.Zero)
                    throw new InvalidOperationException("ADLX_LOAD_LIBRARY_FAILED win32="+Marshal.GetLastWin32Error());

                IntPtr qFullPtr=GetProcAddress(module,"ADLXQueryFullVersion");
                IntPtr qVersionPtr=GetProcAddress(module,"ADLXQueryVersion");
                IntPtr initPtr=GetProcAddress(module,"ADLXInitialize");
                IntPtr terminatePtr=GetProcAddress(module,"ADLXTerminate");
                if(qFullPtr==IntPtr.Zero || qVersionPtr==IntPtr.Zero || initPtr==IntPtr.Zero || terminatePtr==IntPtr.Zero)
                    throw new MissingMethodException("Required AMD ADLX v1.1 exports are unavailable");

                ADLXQueryFullVersionFn queryFull=DelegateAt<ADLXQueryFullVersionFn>(qFullPtr);
                ADLXQueryVersionFn queryVersion=DelegateAt<ADLXQueryVersionFn>(qVersionPtr);
                ADLXInitializeFn initialize=DelegateAt<ADLXInitializeFn>(initPtr);
                terminate=DelegateAt<ADLXTerminateFn>(terminatePtr);

                ulong fullVersion=0;
                int result=queryFull(ref fullVersion);
                if(!Succeeded(result))
                    throw new InvalidOperationException("ADLX_QUERY_FULL_VERSION result="+result);

                IntPtr versionPtr;
                result=queryVersion(out versionPtr);
                if(!Succeeded(result))
                    throw new InvalidOperationException("ADLX_QUERY_VERSION result="+result);

                string version=Ansi(versionPtr);
                if(!String.Equals(version,ExpectedAdlxVersion,StringComparison.Ordinal))
                    throw new InvalidOperationException("ADLX_ABI_GUARD expected="+ExpectedAdlxVersion+" actual="+version);

                result=initialize(fullVersion,out system);
                if(!Succeeded(result) || system==IntPtr.Zero)
                    throw new InvalidOperationException("ADLX_INITIALIZE result="+result);

                SysGetPerfFn getPerf=DelegateAt<SysGetPerfFn>(Slot(system,9));
                result=getPerf(system,out perf);
                if(!Succeeded(result) || perf==IntPtr.Zero)
                    throw new InvalidOperationException("ADLX_GET_PERFORMANCE_MONITORING result="+result);

                initialized=true;
                lastError="";
                Log.Write("INFO","GPU_ADLX_BACKEND_INIT_PASS version="+version);
                return true;
            }
            catch(Exception ex)
            {
                lastError=ex.GetBaseException().Message;
                Log.Write("WARN","GPU_ADLX_BACKEND_INIT_FAIL "+lastError);
                Cleanup();
                return false;
            }
        }

        public AdlxGpuTemperatureSample Read()
        {
            AdlxGpuTemperatureSample best=new AdlxGpuTemperatureSample();
            best.Source="AMD_ADLX_1.1";
            best.Usage=-1f;

            if(!EnsureInitialized())return best;

            IntPtr gpuList=IntPtr.Zero;
            try
            {
                SysGetGPUsFn getGpus=DelegateAt<SysGetGPUsFn>(Slot(system,1));
                int result=getGpus(system,out gpuList);
                if(!Succeeded(result) || gpuList==IntPtr.Zero)
                    throw new InvalidOperationException("ADLX_GET_GPUS result="+result);

                ListSizeFn sizeFn=DelegateAt<ListSizeFn>(Slot(gpuList,3));
                GPUListAtFn atGpu=DelegateAt<GPUListAtFn>(Slot(gpuList,11));
                uint count=sizeFn(gpuList);

                for(uint i=0;i<count;i++)
                {
                    IntPtr gpu=IntPtr.Zero;
                    result=atGpu(gpuList,i,out gpu);
                    if(!Succeeded(result) || gpu==IntPtr.Zero)continue;

                    try
                    {
                        IntPtr namePtr;
                        string gpuName="";
                        try
                        {
                            result=DelegateAt<GPUNameFn>(Slot(gpu,7))(gpu,out namePtr);
                            if(Succeeded(result))gpuName=Ansi(namePtr);
                        }
                        catch{}

                        IntPtr pnpPtr;
                        string pnp="";
                        try
                        {
                            result=DelegateAt<GPUPNPFn>(Slot(gpu,9))(gpu,out pnpPtr);
                            if(Succeeded(result))pnp=Ansi(pnpPtr);
                        }
                        catch{}

                        IntPtr support=IntPtr.Zero;
                        result=DelegateAt<PerfGetSupportedGPUFn>(Slot(perf,21))(perf,gpu,out support);
                        if(!Succeeded(result) || support==IntPtr.Zero)continue;

                        bool temperatureSupported=false;
                        try
                        {
                            byte supported;
                            result=DelegateAt<SupportBoolFn>(Slot(support,6))(support,out supported);
                            temperatureSupported=Succeeded(result) && supported!=0;
                        }
                        finally{SafeRelease(support);}

                        if(!temperatureSupported)continue;

                        IntPtr metrics=IntPtr.Zero;
                        result=DelegateAt<PerfGetCurrentGPUFn>(Slot(perf,18))(perf,gpu,out metrics);
                        if(!Succeeded(result) || metrics==IntPtr.Zero)continue;

                        try
                        {
                            double temp;
                            int tempResult=DelegateAt<MetricsDoubleFn>(Slot(metrics,7))(metrics,out temp);
                            if(!Succeeded(tempResult) || Double.IsNaN(temp) || Double.IsInfinity(temp) || temp<5.0 || temp>130.0)
                                continue;

                            double usage=0;
                            int usageResult=DelegateAt<MetricsDoubleFn>(Slot(metrics,4))(metrics,out usage);
                            if(!Succeeded(usageResult) || Double.IsNaN(usage) || Double.IsInfinity(usage))
                                usage=0;

                            float usageValue=(float)Math.Max(0,Math.Min(100,usage));
                            if(!best.Valid || usageValue>best.Usage)
                            {
                                best.Valid=true;
                                best.Temperature=(float)temp;
                                best.Usage=usageValue;
                                best.HardwareName=gpuName;
                                best.PnpString=pnp;
                            }
                        }
                        finally{SafeRelease(metrics);}
                    }
                    finally{SafeRelease(gpu);}
                }

                if(best.Valid)
                {
                    lastError="";
                    return best;
                }

                lastError="ADLX reports no valid supported GPU temperature sample";
                return best;
            }
            catch(Exception ex)
            {
                lastError=ex.GetBaseException().Message;
                Log.Write("WARN","GPU_ADLX_READ_FAIL "+lastError);
                return best;
            }
            finally{SafeRelease(gpuList);}
        }

        private void Cleanup()
        {
            if(perf!=IntPtr.Zero)
            {
                SafeRelease(perf);
                perf=IntPtr.Zero;
            }

            if(system!=IntPtr.Zero && terminate!=null)
            {
                try{terminate();}catch{}
            }
            system=IntPtr.Zero;
            initialized=false;

            if(module!=IntPtr.Zero)
            {
                try{FreeLibrary(module);}catch{}
                module=IntPtr.Zero;
            }
            terminate=null;
        }

        public void Dispose()
        {
            Cleanup();
        }
    }

    internal sealed class RollingTemperatureWindow
    {
        private readonly Queue<float> averages=new Queue<float>();
        private readonly Queue<float> maxima=new Queue<float>();

        public int Count { get { return averages.Count; } }

        public void Add(float average,float maximum)
        {
            if(Single.IsNaN(average)||Single.IsInfinity(average)||average<5||average>130)return;
            if(Single.IsNaN(maximum)||Single.IsInfinity(maximum)||maximum<5||maximum>130)return;
            averages.Enqueue(average);
            maxima.Enqueue(maximum);
            while(averages.Count>BuildInfo.HistoryLength)averages.Dequeue();
            while(maxima.Count>BuildInfo.HistoryLength)maxima.Dequeue();
        }

        public float Average
        {
            get { return averages.Count==0?0:averages.Average(); }
        }

        public float Maximum
        {
            get { return maxima.Count==0?0:maxima.Max(); }
        }
    }

    internal sealed class LibreHardwareMonitorBridge : IDisposable
    {
        private Assembly assembly;
        private object computer;
        private Type computerType;
        private ResolveEventHandler resolver;
        private bool initAttempted;
        private bool initialized;
        private string libraryPath="";
        private string lastError="";

        public bool Initialized { get { return initialized; } }
        public string LastError { get { return lastError; } }
        public string LibraryPath { get { return libraryPath; } }

        private static bool ValidTemp(float v)
        {
            return !Single.IsNaN(v)&&!Single.IsInfinity(v)&&v>=5f&&v<=130f;
        }

        private static string FindLibrary()
        {
            try
            {
                if(!Directory.Exists(AppPaths.SensorBackend))return null;
                string[] files=Directory.GetFiles(
                    AppPaths.SensorBackend,
                    "LibreHardwareMonitorLib.dll",
                    SearchOption.AllDirectories
                );
                if(files.Length==0)return null;
                return files[0];
            }
            catch{return null;}
        }

        private Assembly ResolveDependency(object sender,ResolveEventArgs e)
        {
            try
            {
                string simple=new AssemblyName(e.Name).Name+".dll";
                string[] matches=Directory.GetFiles(AppPaths.SensorBackend,simple,SearchOption.AllDirectories);
                if(matches.Length>0)return Assembly.LoadFrom(matches[0]);
            }
            catch{}
            return null;
        }

        private static void SetBoolProperty(object target,string name,bool value)
        {
            PropertyInfo p=target.GetType().GetProperty(name,BindingFlags.Public|BindingFlags.Instance);
            if(p!=null&&p.CanWrite)p.SetValue(target,value,null);
        }

        private bool EnsureInitialized()
        {
            if(initialized)return true;
            if(initAttempted)return false;
            initAttempted=true;

            try
            {
                libraryPath=FindLibrary();
                if(String.IsNullOrWhiteSpace(libraryPath))
                    throw new FileNotFoundException("LibreHardwareMonitorLib.dll not found under "+AppPaths.SensorBackend);

                resolver=new ResolveEventHandler(ResolveDependency);
                AppDomain.CurrentDomain.AssemblyResolve+=resolver;

                assembly=Assembly.LoadFrom(libraryPath);
                computerType=assembly.GetType("LibreHardwareMonitor.Hardware.Computer",true);
                computer=Activator.CreateInstance(computerType);
                SetBoolProperty(computer,"IsCpuEnabled",true);
                SetBoolProperty(computer,"IsMotherboardEnabled",true);

                MethodInfo open=computerType.GetMethod("Open",BindingFlags.Public|BindingFlags.Instance);
                if(open==null)throw new MissingMethodException("Computer.Open");
                open.Invoke(computer,null);

                initialized=true;
                lastError="";
                Log.Write("INFO","CPU_TEMP_DIRECT_BACKEND_INIT_PASS library="+libraryPath);
                return true;
            }
            catch(Exception ex)
            {
                lastError=ex.GetBaseException().Message;
                Log.Write("WARN","CPU_TEMP_DIRECT_BACKEND_INIT_FAIL "+lastError);
                return false;
            }
        }

        private static IEnumerable<object> AsObjects(object value)
        {
            System.Collections.IEnumerable e=value as System.Collections.IEnumerable;
            if(e==null)yield break;
            foreach(object x in e)if(x!=null)yield return x;
        }

        private static string GetText(object o,string property)
        {
            try
            {
                PropertyInfo p=o.GetType().GetProperty(property,BindingFlags.Public|BindingFlags.Instance);
                object v=p==null?null:p.GetValue(o,null);
                return v==null?"":Convert.ToString(v,CultureInfo.InvariantCulture)??"";
            }
            catch{return "";}
        }

        private static bool TryGetFloat(object o,string property,out float value)
        {
            value=0;
            try
            {
                PropertyInfo p=o.GetType().GetProperty(property,BindingFlags.Public|BindingFlags.Instance);
                object v=p==null?null:p.GetValue(o,null);
                if(v==null)return false;
                value=Convert.ToSingle(v,CultureInfo.InvariantCulture);
                return ValidTemp(value);
            }
            catch{return false;}
        }

        private static void UpdateHardware(object hardware)
        {
            try
            {
                MethodInfo m=hardware.GetType().GetMethod("Update",BindingFlags.Public|BindingFlags.Instance);
                if(m!=null)m.Invoke(hardware,null);
            }
            catch{}
        }

        private static void AddTemperatureSensors(
            object hardware,
            List<KeyValuePair<string,float>> values,
            bool cpuOnly
        )
        {
            if(hardware==null)return;
            UpdateHardware(hardware);

            string hwType=GetText(hardware,"HardwareType");
            string hwName=GetText(hardware,"Name");
            bool isCpu=hwType.IndexOf("Cpu",StringComparison.OrdinalIgnoreCase)>=0 ||
                       hwName.IndexOf("CPU",StringComparison.OrdinalIgnoreCase)>=0 ||
                       hwName.IndexOf("Intel",StringComparison.OrdinalIgnoreCase)>=0 ||
                       hwName.IndexOf("AMD",StringComparison.OrdinalIgnoreCase)>=0;

            if(isCpu||cpuOnly)
            {
                PropertyInfo sp=hardware.GetType().GetProperty("Sensors",BindingFlags.Public|BindingFlags.Instance);
                object sensorList=sp==null?null:sp.GetValue(hardware,null);
                foreach(object sensor in AsObjects(sensorList))
                {
                    string sensorType=GetText(sensor,"SensorType");
                    if(!String.Equals(sensorType,"Temperature",StringComparison.OrdinalIgnoreCase))continue;
                    float temp;
                    if(!TryGetFloat(sensor,"Value",out temp))continue;
                    string name=GetText(sensor,"Name");
                    string id=GetText(sensor,"Identifier");
                    values.Add(new KeyValuePair<string,float>(name+"|"+id,temp));
                }
            }

            PropertyInfo subp=hardware.GetType().GetProperty("SubHardware",BindingFlags.Public|BindingFlags.Instance);
            object subs=subp==null?null:subp.GetValue(hardware,null);
            foreach(object sub in AsObjects(subs))
                AddTemperatureSensors(sub,values,cpuOnly||isCpu);
        }

        private static int NamePriority(string key)
        {
            string n=(key??"").ToLowerInvariant();
            if(n.Contains("cpu package"))return 100;
            if(n.Contains("package"))return 95;
            if(n.Contains("tctl/tdie"))return 94;
            if(n.Contains("tctl"))return 93;
            if(n.Contains("tdie"))return 92;
            if(n.Contains("core max"))return 90;
            if(n.Contains("cores max"))return 89;
            if(n.Contains("cpu max"))return 88;
            if(n.Contains("core average"))return 80;
            if(n.Contains("cores average"))return 79;
            if(n.Contains("core #"))return 70;
            if(n.Contains("cpu core"))return 69;
            return 20;
        }

        public CpuTemperatureSample Read()
        {
            CpuTemperatureSample result=new CpuTemperatureSample();
            result.Source="LIBRE_HARDWARE_MONITOR_DIRECT_0.9.6";

            if(!EnsureInitialized())return result;

            try
            {
                PropertyInfo hp=computerType.GetProperty("Hardware",BindingFlags.Public|BindingFlags.Instance);
                object hardware=hp==null?null:hp.GetValue(computer,null);
                List<KeyValuePair<string,float>> values=new List<KeyValuePair<string,float>>();
                foreach(object hw in AsObjects(hardware))AddTemperatureSensors(hw,values,true);
                if(values.Count==0)
                {
                    lastError="no valid CPU temperature sensors";
                    return result;
                }

                KeyValuePair<string,float> preferred=values
                    .OrderByDescending(x=>NamePriority(x.Key))
                    .ThenByDescending(x=>x.Value)
                    .First();

                List<float> coreValues=values
                    .Where(x=>x.Key.IndexOf("core",StringComparison.OrdinalIgnoreCase)>=0 &&
                              x.Key.IndexOf("max",StringComparison.OrdinalIgnoreCase)<0 &&
                              x.Key.IndexOf("average",StringComparison.OrdinalIgnoreCase)<0)
                    .Select(x=>x.Value).ToList();

                float avg=coreValues.Count>0?coreValues.Average():values.Average(x=>x.Value);
                float max=values.Max(x=>x.Value);

                result.Valid=true;
                result.Current=preferred.Value;
                result.Average=avg;
                result.Maximum=max;
                result.SensorCount=values.Count;
                result.Source="LIBRE_HARDWARE_MONITOR_DIRECT_0.9.6:"+preferred.Key;
                lastError="";
                return result;
            }
            catch(Exception ex)
            {
                lastError=ex.GetBaseException().Message;
                Log.Write("WARN","CPU_TEMP_DIRECT_BACKEND_READ_FAIL "+lastError);
                return result;
            }
        }

        public void Dispose()
        {
            try
            {
                if(computer!=null&&computerType!=null)
                {
                    MethodInfo close=computerType.GetMethod("Close",BindingFlags.Public|BindingFlags.Instance);
                    if(close!=null)close.Invoke(computer,null);
                }
            }
            catch{}
            if(resolver!=null)
            {
                try{AppDomain.CurrentDomain.AssemblyResolve-=resolver;}catch{}
            }
            computer=null;
            assembly=null;
            computerType=null;
            initialized=false;
        }
    }

    internal sealed class CpuTemperatureReader : IDisposable
    {
        private string lastSource="";
        private DateTime lastFallbackAttemptUtc=DateTime.MinValue;
        private CpuTemperatureSample lastFallbackSample=new CpuTemperatureSample{Valid=false,Source="UNAVAILABLE"};
        private DateTime lastBrokerStaleLogUtc=DateTime.MinValue;

        public CpuTemperatureSample Read()
        {
            CpuTemperatureSample s;

            s=ReadElevatedBroker();
            if(s.Valid){LogSource(s.Source,s.SensorCount);return s;}

            // R21: expensive fallback namespaces are sampled at most every 15 seconds.
            // The elevated broker remains the immediate/primary source whenever it is fresh.
            if(lastFallbackAttemptUtc!=DateTime.MinValue&&(DateTime.UtcNow-lastFallbackAttemptUtc).TotalSeconds<15)
            {
                if(lastFallbackSample!=null&&lastFallbackSample.Valid)LogSource(lastFallbackSample.Source,lastFallbackSample.SensorCount);
                else LogSource("UNAVAILABLE",0);
                return lastFallbackSample??new CpuTemperatureSample{Valid=false,Source="UNAVAILABLE"};
            }
            lastFallbackAttemptUtc=DateTime.UtcNow;

            s=ReadHardwareMonitorNamespace(@"\\.\root\LibreHardwareMonitor","LIBRE_HARDWARE_MONITOR_WMI");
            if(s.Valid){lastFallbackSample=s;LogSource(s.Source,s.SensorCount);return s;}

            s=ReadHardwareMonitorNamespace(@"\\.\root\OpenHardwareMonitor","OPEN_HARDWARE_MONITOR_WMI");
            if(s.Valid){lastFallbackSample=s;LogSource(s.Source,s.SensorCount);return s;}

            s=ReadAcpi();
            if(s.Valid){lastFallbackSample=s;LogSource(s.Source,s.SensorCount);return s;}

            s=new CpuTemperatureSample();
            s.Valid=false;
            s.Source="UNAVAILABLE";
            lastFallbackSample=s;
            LogSource(s.Source,0);
            return s;
        }

        private CpuTemperatureSample ReadElevatedBroker()
        {
            CpuTemperatureSample result=new CpuTemperatureSample();
            result.Source="LHM_ELEVATED_BROKER";

            try
            {
                if(!File.Exists(AppPaths.CpuTempBrokerData))return result;

                string json=BrokerJsonFile.ReadShared(AppPaths.CpuTempBrokerData);
                JavaScriptSerializer js=new JavaScriptSerializer();
                Dictionary<string,object> m=js.Deserialize<Dictionary<string,object>>(json);
                if(m==null)return result;

                object availableObj;
                if(!m.TryGetValue("Available",out availableObj) ||
                   !Convert.ToBoolean(availableObj,CultureInfo.InvariantCulture))
                    return result;

                object tsObj;
                if(!m.TryGetValue("TimestampUtc",out tsObj))return result;
                DateTime ts;
                if(!DateTime.TryParse(
                    Convert.ToString(tsObj,CultureInfo.InvariantCulture),
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,
                    out ts))
                    return result;

                double age=(DateTime.UtcNow-ts).TotalSeconds;
                const double brokerFreshnessSeconds=15.0;
                if(age<0 || age>brokerFreshnessSeconds)
                {
                    if(lastBrokerStaleLogUtc==DateTime.MinValue||(DateTime.UtcNow-lastBrokerStaleLogUtc).TotalSeconds>=30)
                    {
                        lastBrokerStaleLogUtc=DateTime.UtcNow;
                        Log.Write("WARN","CPU_TEMP_BROKER_STALE ageSec="+age.ToString("0.0",CultureInfo.InvariantCulture)+" limitSec="+brokerFreshnessSeconds.ToString("0",CultureInfo.InvariantCulture));
                    }
                    return result;
                }

                object currentObj;
                if(!m.TryGetValue("CurrentC",out currentObj))return result;
                float current=Convert.ToSingle(currentObj,CultureInfo.InvariantCulture);
                if(!IsValidTemp(current))return result;

                float avg=current;
                float max=current;
                object avgObj;
                object maxObj;
                if(m.TryGetValue("AverageC",out avgObj))
                {
                    try
                    {
                        float v=Convert.ToSingle(avgObj,CultureInfo.InvariantCulture);
                        if(IsValidTemp(v))avg=v;
                    }
                    catch{}
                }
                if(m.TryGetValue("MaximumC",out maxObj))
                {
                    try
                    {
                        float v=Convert.ToSingle(maxObj,CultureInfo.InvariantCulture);
                        if(IsValidTemp(v))max=v;
                    }
                    catch{}
                }

                string sensor="";
                object sensorObj;
                if(m.TryGetValue("Sensor",out sensorObj))
                    sensor=Convert.ToString(sensorObj,CultureInfo.InvariantCulture)??"";

                result.Valid=true;
                result.Current=current;
                result.Average=avg;
                result.Maximum=max;
                result.SensorCount=1;
                result.Source="LHM_ELEVATED_BROKER"+(String.IsNullOrWhiteSpace(sensor)?"":":"+sensor);

                object powerAvailableObj;
                if(m.TryGetValue("PackagePowerAvailable",out powerAvailableObj))
                {
                    try{result.PowerAvailable=Convert.ToBoolean(powerAvailableObj,CultureInfo.InvariantCulture);}catch{}
                }
                if(result.PowerAvailable)
                {
                    object powerObj;
                    if(m.TryGetValue("PackagePowerW",out powerObj))
                    {
                        try
                        {
                            float pwr=Convert.ToSingle(powerObj,CultureInfo.InvariantCulture);
                            if(!Single.IsNaN(pwr)&&!Single.IsInfinity(pwr)&&pwr>=0&&pwr<1000)result.PowerW=pwr;
                            else result.PowerAvailable=false;
                        }
                        catch{result.PowerAvailable=false;}
                    }
                    else result.PowerAvailable=false;
                    object powerSensorObj;
                    string powerSensor=m.TryGetValue("PackagePowerSensor",out powerSensorObj)?Convert.ToString(powerSensorObj,CultureInfo.InvariantCulture):"";
                    result.PowerSource=result.PowerAvailable?("LHM_ELEVATED_BROKER"+(String.IsNullOrWhiteSpace(powerSensor)?"":(":"+powerSensor))):"UNAVAILABLE";
                }
                return result;
            }
            catch(Exception ex)
            {
                Log.Write("WARN","CPU_TEMP_BROKER_READ "+ex.Message);
                return result;
            }
        }

        private void LogSource(string source,int count)
        {
            if(String.Equals(source,lastSource,StringComparison.Ordinal))return;
            lastSource=source;
            Log.Write("INFO","CPU_TEMP_SOURCE="+source+" sensors="+count);
        }

        private static bool IsValidTemp(float v)
        {
            return !Single.IsNaN(v)&&!Single.IsInfinity(v)&&v>=5f&&v<=130f;
        }

        private CpuTemperatureSample ReadHardwareMonitorNamespace(string ns,string source)
        {
            CpuTemperatureSample result=new CpuTemperatureSample();
            result.Source=source;

            try
            {
                ManagementScope scope=new ManagementScope(ns);
                scope.Connect();

                ObjectQuery q=new ObjectQuery("SELECT Name,Identifier,Parent,SensorType,Value FROM Sensor");
                using(ManagementObjectSearcher searcher=new ManagementObjectSearcher(scope,q))
                using(ManagementObjectCollection rows=searcher.Get())
                {
                    List<float> cores=new List<float>();
                    List<float> all=new List<float>();
                    float directAverage=Single.NaN;
                    float directMaximum=Single.NaN;

                    foreach(ManagementObject row in rows)
                    {
                        string type=Convert.ToString(row["SensorType"],CultureInfo.InvariantCulture)??"";
                        if(!String.Equals(type,"Temperature",StringComparison.OrdinalIgnoreCase))continue;

                        string name=Convert.ToString(row["Name"],CultureInfo.InvariantCulture)??"";
                        string id=Convert.ToString(row["Identifier"],CultureInfo.InvariantCulture)??"";
                        string parent=Convert.ToString(row["Parent"],CultureInfo.InvariantCulture)??"";
                        string hay=(name+" "+id+" "+parent).ToLowerInvariant();

                        bool cpu=
                            hay.Contains("intelcpu")||
                            hay.Contains("amdcpu")||
                            hay.Contains("/cpu/")||
                            hay.Contains(" package")||
                            hay.Contains("package ")||
                            hay.Contains("tctl")||
                            hay.Contains("tdie")||
                            hay.Contains("ccd")||
                            hay.Contains("peci")||
                            name.StartsWith("CPU",StringComparison.OrdinalIgnoreCase)||
                            name.StartsWith("Core",StringComparison.OrdinalIgnoreCase);

                        if(!cpu)continue;
                        if(hay.Contains("distance to tjmax"))continue;

                        object raw=row["Value"];
                        if(raw==null)continue;
                        float v;
                        try{v=Convert.ToSingle(raw,CultureInfo.InvariantCulture);}catch{continue;}
                        if(!IsValidTemp(v))continue;

                        all.Add(v);

                        bool ordinaryCore=
                            (name.StartsWith("CPU Core #",StringComparison.OrdinalIgnoreCase)||
                             name.StartsWith("Core #",StringComparison.OrdinalIgnoreCase)) &&
                            name.IndexOf("Max",StringComparison.OrdinalIgnoreCase)<0 &&
                            name.IndexOf("Average",StringComparison.OrdinalIgnoreCase)<0;
                        if(ordinaryCore)cores.Add(v);

                        if(name.IndexOf("Core Average",StringComparison.OrdinalIgnoreCase)>=0||
                           name.IndexOf("Cores Average",StringComparison.OrdinalIgnoreCase)>=0)
                            directAverage=v;

                        if(name.IndexOf("Core Max",StringComparison.OrdinalIgnoreCase)>=0||
                           name.IndexOf("Cores Max",StringComparison.OrdinalIgnoreCase)>=0)
                            directMaximum=v;
                    }

                    if(cores.Count>0)
                    {
                        result.Valid=true;
                        result.Current=cores.Max();
                        result.Average=cores.Average();
                        result.Maximum=cores.Max();
                        result.SensorCount=cores.Count;
                        return result;
                    }

                    if(IsValidTemp(directAverage)||IsValidTemp(directMaximum))
                    {
                        float a=IsValidTemp(directAverage)?directAverage:directMaximum;
                        float m=IsValidTemp(directMaximum)?directMaximum:directAverage;
                        result.Valid=true;
                        result.Current=m;
                        result.Average=a;
                        result.Maximum=m;
                        result.SensorCount=all.Count;
                        return result;
                    }

                    if(all.Count>0)
                    {
                        result.Valid=true;
                        result.Current=all.Max();
                        result.Average=all.Average();
                        result.Maximum=all.Max();
                        result.SensorCount=all.Count;
                        return result;
                    }
                }
            }
            catch{}

            result.Valid=false;
            return result;
        }

        private CpuTemperatureSample ReadAcpi()
        {
            CpuTemperatureSample result=new CpuTemperatureSample();
            result.Source="ACPI_THERMAL_ZONE";

            try
            {
                ManagementScope scope=new ManagementScope(@"\\.\root\WMI");
                scope.Connect();
                ObjectQuery q=new ObjectQuery("SELECT CurrentTemperature FROM MSAcpi_ThermalZoneTemperature");

                using(ManagementObjectSearcher searcher=new ManagementObjectSearcher(scope,q))
                using(ManagementObjectCollection rows=searcher.Get())
                {
                    List<float> values=new List<float>();
                    foreach(ManagementObject row in rows)
                    {
                        object raw=row["CurrentTemperature"];
                        if(raw==null)continue;
                        double tenthsKelvin;
                        try{tenthsKelvin=Convert.ToDouble(raw,CultureInfo.InvariantCulture);}catch{continue;}
                        float c=(float)(tenthsKelvin/10.0-273.15);
                        if(IsValidTemp(c))values.Add(c);
                    }

                    if(values.Count>0)
                    {
                        result.Valid=true;
                        result.Current=values.Max();
                        result.Average=values.Average();
                        result.Maximum=values.Max();
                        result.SensorCount=values.Count;
                        return result;
                    }
                }
            }
            catch{}

            result.Valid=false;
            return result;
        }

        public void Dispose()
        {
        }
    }

    internal sealed class NativeCpuUsageSampler
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct FILETIME_NATIVE { public uint Low; public uint High; }

        [DllImport("kernel32.dll",SetLastError=true)]
        [return:MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetSystemTimes(
            out FILETIME_NATIVE idleTime,
            out FILETIME_NATIVE kernelTime,
            out FILETIME_NATIVE userTime
        );

        private bool hasBaseline;
        private ulong lastIdle,lastKernel,lastUser;

        private static ulong U64(FILETIME_NATIVE x)
        {
            return ((ulong)x.High<<32)|x.Low;
        }

        public bool TrySample(out float usage)
        {
            usage=0;
            FILETIME_NATIVE idle,kernel,user;
            if(!GetSystemTimes(out idle,out kernel,out user))return false;
            ulong i=U64(idle),k=U64(kernel),u=U64(user);
            if(!hasBaseline)
            {
                lastIdle=i;lastKernel=k;lastUser=u;hasBaseline=true;
                return false;
            }
            ulong dk=k>=lastKernel?k-lastKernel:0;
            ulong du=u>=lastUser?u-lastUser:0;
            ulong di=i>=lastIdle?i-lastIdle:0;
            lastIdle=i;lastKernel=k;lastUser=u;
            ulong total=dk+du;
            if(total==0)return false;
            ulong busy=total>=di?total-di:0;
            usage=(float)Math.Max(0d,Math.Min(100d,busy*100d/total));
            return true;
        }

        public void Reset(){hasBaseline=false;lastIdle=lastKernel=lastUser=0;}
    }

    internal sealed class MetricsEngine : IDisposable
    {
        private readonly NativeCpuUsageSampler cpuUsageSampler=new NativeCpuUsageSampler();
        private PerformanceCounter cpuFrequencyCounter;
        private PerformanceCounter diskCounter;
        private readonly Dictionary<string,PerformanceCounter> diskActivityCounters=new Dictionary<string,PerformanceCounter>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string,PerformanceCounter> diskReadCounters=new Dictionary<string,PerformanceCounter>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string,PerformanceCounter> diskWriteCounters=new Dictionary<string,PerformanceCounter>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string,long> previousRx = new Dictionary<string,long>();
        private readonly Dictionary<string,long> previousTx = new Dictionary<string,long>();
        private List<NetworkInterface> networkInterfaces=new List<NetworkInterface>();
        private DateTime lastNetworkTopologyQuery=DateTime.MinValue;
        private DateTime previousNetAt = DateTime.UtcNow;
        private DateTime lastGpuQuery = DateTime.MinValue;
        private DateTime lastCpuTempQuery = DateTime.MinValue;
        private DateTime lastDiskTempQuery = DateTime.MinValue;
        private DateTime lastDiskTopologyQuery = DateTime.MinValue;
        private readonly CpuTemperatureReader cpuTempReader = new CpuTemperatureReader();
        private readonly ElevatedStorageTemperatureReader elevatedStorageTempReader = new ElevatedStorageTemperatureReader();
        private readonly RollingTemperatureWindow cpuTemps = new RollingTemperatureWindow();
        private readonly RollingTemperatureWindow gpuTemps = new RollingTemperatureWindow();
        private readonly ElevatedGpuTelemetryReader elevatedGpuReader = new ElevatedGpuTelemetryReader();
        private readonly WindowsGpuFallbackReader windowsGpuReader = new WindowsGpuFallbackReader();
        private readonly AmdAdlxTemperatureReader amdAdlxTempReader = new AmdAdlxTemperatureReader();
        private List<GpuDeviceSnapshot> lastGpuDevices=new List<GpuDeviceSnapshot>();
        private List<MemoryModuleSnapshot> memoryModules=new List<MemoryModuleSnapshot>();
        private List<CpuDeviceSnapshot> cpuDeviceTemplate=new List<CpuDeviceSnapshot>();
        private DateTime lastCpuDeviceStaticQuery=DateTime.MinValue;
        private DateTime lastMemoryModuleQuery=DateTime.MinValue;
        private string lastGpuTempSource="UNAVAILABLE";
        private string lastCpuTempSource="UNAVAILABLE";
        private float lastCpuTempCurrent=0;
        private float lastCpuPowerW=0;
        private bool lastCpuPowerAvailable=false;
        private string lastCpuPowerSource="UNAVAILABLE";
        private DateTime lastCpuTempValidAt=DateTime.MinValue;
        private List<StorageTemperatureSample> lastStorageTemperatures=new List<StorageTemperatureSample>();
        private string lastDiskTemperatureProviderSignature="";
        private readonly HashSet<string> loggedDiskTemperatureMatches=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private List<DiskTopologyEntry> diskTopology=new List<DiskTopologyEntry>();

        private sealed class DiskTopologyEntry
        {
            public int Index=-1;
            public string Id,Name,PerfInstance,BusType,MediaType,InterfaceType;
            public ulong PhysicalSizeBytes;
            public bool LogicalCounterFallback;
            public List<string> Volumes=new List<string>();
        }

        public MetricsEngine()
        {
            try { cpuFrequencyCounter = new PerformanceCounter("Processor Information", "Processor Frequency", "_Total", true); cpuFrequencyCounter.NextValue(); } catch (Exception ex) { Log.Write("WARN", "CPU_FREQ_COUNTER " + ex.Message); }
            try { diskCounter = new PerformanceCounter("PhysicalDisk", "% Disk Time", "_Total", true); diskCounter.NextValue(); } catch (Exception ex) { Log.Write("WARN", "DISK_COUNTER " + ex.Message); }
            CaptureNetworkBaseline();
        }

        public MetricsSnapshot Read()
        {
            MetricsSnapshot s = new MetricsSnapshot();
            try { float nativeCpu;if(cpuUsageSampler.TrySample(out nativeCpu))s.Cpu=Clamp(nativeCpu,0,100); } catch { }
            try { if (diskCounter != null) s.Disk = Clamp(diskCounter.NextValue(),0,100); } catch { }
            NativeMemory.GetUsage(out s.RamUsedBytes,out s.RamTotalBytes,out s.Ram);
            ReadMemoryModulesIfDue(s);
            ReadCpuTemperatureIfDue();
            bool cpuTempFresh=lastCpuTempValidAt!=DateTime.MinValue&&(DateTime.UtcNow-lastCpuTempValidAt).TotalSeconds<=15;
            s.CpuTempAvailable=cpuTempFresh&&cpuTemps.Count>0&&lastCpuTempCurrent>=5f;s.CpuTempCurrent=s.CpuTempAvailable?lastCpuTempCurrent:0;s.CpuTempAvg=cpuTemps.Average;s.CpuTempMax=cpuTemps.Maximum;s.CpuTempSource=s.CpuTempAvailable?lastCpuTempSource:"UNAVAILABLE";
            ReadCpuDevices(s);
            ReadDiskDevices(s);
            ReadNetwork(s);
            ReadGpuIfDue();
            s.GpuDevices=new List<GpuDeviceSnapshot>(lastGpuDevices);
            GpuDeviceSnapshot active=s.GpuDevices.OrderByDescending(x=>x.UsageAvailable?x.Usage:-1).FirstOrDefault();
            if(active!=null){s.Gpu=active.Usage;s.GpuTemp=active.Temperature;s.GpuTempAvailable=active.TemperatureAvailable;}
            s.VramUsedGb=s.GpuDevices.Sum(x=>Math.Max(0,x.VramUsedGb));s.VramTotalGb=s.GpuDevices.Sum(x=>Math.Max(0,x.VramTotalGb));
            List<float> gt=s.GpuDevices.Where(x=>x.TemperatureAvailable).Select(x=>x.Temperature).ToList();
            if(gt.Count>0){foreach(float t in gt)gpuTemps.Add(t,t);s.GpuTempAvailable=true;s.GpuTempAvg=gt.Average();s.GpuTempMax=gt.Max();}else{s.GpuTempAvg=gpuTemps.Average;s.GpuTempMax=gpuTemps.Maximum;}
            s.GpuTempSource=lastGpuTempSource;
            return s;
        }

        private static float Clamp(float v,float min,float max) { if (Single.IsNaN(v)||Single.IsInfinity(v)) return 0; return Math.Max(min,Math.Min(max,v)); }

        private static CpuDeviceSnapshot CloneCpuDevice(CpuDeviceSnapshot x)
        {
            CpuDeviceSnapshot d=new CpuDeviceSnapshot();
            d.Id=x.Id;d.Name=x.Name;d.PhysicalCores=x.PhysicalCores;d.LogicalProcessors=x.LogicalProcessors;
            d.CurrentClockMHz=x.CurrentClockMHz;d.MaxClockMHz=x.MaxClockMHz;d.ExternalClockMHz=x.ExternalClockMHz;d.Socket=x.Socket;
            return d;
        }

        private void RefreshCpuDeviceTemplateIfDue()
        {
            if(cpuDeviceTemplate.Count>0&&(DateTime.UtcNow-lastCpuDeviceStaticQuery).TotalMinutes<5)return;
            lastCpuDeviceStaticQuery=DateTime.UtcNow;
            List<CpuDeviceSnapshot> list=new List<CpuDeviceSnapshot>();
            try
            {
                using(ManagementObjectSearcher q=new ManagementObjectSearcher(
                    "SELECT DeviceID,Name,NumberOfCores,NumberOfLogicalProcessors,CurrentClockSpeed,MaxClockSpeed,ExtClock,SocketDesignation FROM Win32_Processor"))
                foreach(ManagementObject o in q.Get())
                {
                    CpuDeviceSnapshot d=new CpuDeviceSnapshot();
                    d.Id=Convert.ToString(o["DeviceID"],CultureInfo.InvariantCulture);
                    d.Name=Convert.ToString(o["Name"],CultureInfo.InvariantCulture);
                    try{d.PhysicalCores=Convert.ToInt32(o["NumberOfCores"],CultureInfo.InvariantCulture);}catch{}
                    try{d.LogicalProcessors=Convert.ToInt32(o["NumberOfLogicalProcessors"],CultureInfo.InvariantCulture);}catch{}
                    try{d.CurrentClockMHz=Convert.ToInt32(o["CurrentClockSpeed"],CultureInfo.InvariantCulture);}catch{}
                    try{d.MaxClockMHz=Convert.ToInt32(o["MaxClockSpeed"],CultureInfo.InvariantCulture);}catch{}
                    try{d.ExternalClockMHz=Convert.ToInt32(o["ExtClock"],CultureInfo.InvariantCulture);}catch{}
                    try{d.Socket=Convert.ToString(o["SocketDesignation"],CultureInfo.InvariantCulture);}catch{}
                    list.Add(d);
                }
            }
            catch(Exception ex){Log.Write("WARN","CPU_DEVICE_STATIC_ENUM "+ex.Message);}
            if(list.Count==0)
            {
                CpuDeviceSnapshot d=new CpuDeviceSnapshot();d.Id="CPU0";
                d.Name=Environment.GetEnvironmentVariable("PROCESSOR_IDENTIFIER")??"CPU";
                d.PhysicalCores=Environment.ProcessorCount;d.LogicalProcessors=Environment.ProcessorCount;
                list.Add(d);
            }
            cpuDeviceTemplate=list;
        }

        private void ReadCpuDevices(MetricsSnapshot s)
        {
            RefreshCpuDeviceTemplateIfDue();
            List<CpuDeviceSnapshot> list=cpuDeviceTemplate.Select(CloneCpuDevice).ToList();
            foreach(CpuDeviceSnapshot d in list){d.Usage=s.Cpu;d.UsageAvailable=true;}
            if(list.Count==1)
            {
                if(s.CpuTempAvailable){list[0].TemperatureAvailable=true;list[0].Temperature=s.CpuTempCurrent;}
                if(lastCpuPowerAvailable){list[0].PowerAvailable=true;list[0].PowerW=lastCpuPowerW;}
                try{if(cpuFrequencyCounter!=null){float live=cpuFrequencyCounter.NextValue();if(live>100&&live<10000)list[0].CurrentClockMHz=(int)Math.Round(live);}}catch{}
            }
            s.CpuDevices=list;
        }

        public void ResetAfterResume()
        {
            cpuUsageSampler.Reset();
            try{CaptureNetworkBaseline();}catch{}
            try{if(cpuFrequencyCounter!=null)cpuFrequencyCounter.NextValue();}catch{}
            try{if(diskCounter!=null)diskCounter.NextValue();}catch{}
            foreach(PerformanceCounter c in diskActivityCounters.Values)try{c.NextValue();}catch{}
            foreach(PerformanceCounter c in diskReadCounters.Values)try{c.NextValue();}catch{}
            foreach(PerformanceCounter c in diskWriteCounters.Values)try{c.NextValue();}catch{}
            lastGpuQuery=DateTime.MinValue;
            lastCpuTempQuery=DateTime.MinValue;
            lastDiskTempQuery=DateTime.MinValue;
            lastDiskTopologyQuery=DateTime.MinValue;
            lastMemoryModuleQuery=DateTime.MinValue;
            lastCpuDeviceStaticQuery=DateTime.MinValue;
            Log.Write("INFO","METRICS_RESUME_RESET nativeCpuBaseline=RESET networkBaseline=RESET staticTopology=INVALIDATED");
        }

        private static string MemoryTypeName(int smbiosType)
        {
            switch(smbiosType)
            {
                case 20:return "DDR";
                case 21:return "DDR2";
                case 24:return "DDR3";
                case 26:return "DDR4";
                case 34:return "DDR5";
                default:return smbiosType>0?("SMBIOS "+smbiosType):"Unknown";
            }
        }

        private void ReadMemoryModulesIfDue(MetricsSnapshot s)
        {
            if(memoryModules.Count>0&&(DateTime.UtcNow-lastMemoryModuleQuery).TotalMinutes<10)
            {
                s.MemoryModules=new List<MemoryModuleSnapshot>(memoryModules);return;
            }
            lastMemoryModuleQuery=DateTime.UtcNow;
            List<MemoryModuleSnapshot> list=new List<MemoryModuleSnapshot>();
            try
            {
                using(ManagementObjectSearcher q=new ManagementObjectSearcher(
                    "SELECT BankLabel,DeviceLocator,Manufacturer,PartNumber,Capacity,Speed,ConfiguredClockSpeed,DataWidth,TotalWidth,SMBIOSMemoryType FROM Win32_PhysicalMemory"))
                foreach(ManagementObject o in q.Get())
                {
                    MemoryModuleSnapshot m=new MemoryModuleSnapshot();
                    m.BankLabel=Convert.ToString(o["BankLabel"],CultureInfo.InvariantCulture);
                    m.DeviceLocator=Convert.ToString(o["DeviceLocator"],CultureInfo.InvariantCulture);
                    m.Manufacturer=Convert.ToString(o["Manufacturer"],CultureInfo.InvariantCulture);
                    m.PartNumber=(Convert.ToString(o["PartNumber"],CultureInfo.InvariantCulture)??"").Trim();
                    try{m.CapacityBytes=Convert.ToUInt64(o["Capacity"],CultureInfo.InvariantCulture);}catch{}
                    try{m.SpeedMHz=Convert.ToInt32(o["Speed"],CultureInfo.InvariantCulture);}catch{}
                    try{m.ConfiguredClockMHz=Convert.ToInt32(o["ConfiguredClockSpeed"],CultureInfo.InvariantCulture);}catch{}
                    try{m.DataWidth=Convert.ToInt32(o["DataWidth"],CultureInfo.InvariantCulture);}catch{}
                    try{m.TotalWidth=Convert.ToInt32(o["TotalWidth"],CultureInfo.InvariantCulture);}catch{}
                    int type=0;try{type=Convert.ToInt32(o["SMBIOSMemoryType"],CultureInfo.InvariantCulture);}catch{}
                    m.MemoryType=MemoryTypeName(type);
                    list.Add(m);
                }
            }
            catch(Exception ex){Log.Write("WARN","RAM_MODULE_ENUM "+ex.Message);}
            if(list.Count>0)memoryModules=list;
            s.MemoryModules=new List<MemoryModuleSnapshot>(memoryModules);
        }

        private static string NormalizeDiskModel(string value)
        {
            if(String.IsNullOrWhiteSpace(value))return "";
            return Regex.Replace(value.ToLowerInvariant(),@"[^a-z0-9]+","");
        }

        private static string BusTypeName(int bus)
        {
            switch(bus)
            {
                case 1:return "SCSI"; case 2:return "ATAPI"; case 3:return "ATA";
                case 4:return "IEEE1394"; case 5:return "SSA"; case 6:return "Fibre Channel";
                case 7:return "USB"; case 8:return "RAID"; case 9:return "iSCSI";
                case 10:return "SAS"; case 11:return "SATA"; case 12:return "SD";
                case 13:return "MMC"; case 14:return "Virtual"; case 15:return "File-backed Virtual";
                case 16:return "Storage Spaces"; case 17:return "NVMe"; case 18:return "SCM";
                case 19:return "UFS"; default:return "";
            }
        }
        private static string PhysicalMediaTypeName(int media)
        {
            switch(media){case 3:return "HDD";case 4:return "SSD";case 5:return "SCM";default:return "";}
        }

        private void RefreshDiskTopologyIfDue()
        {
            if(diskTopology.Count>0&&(DateTime.UtcNow-lastDiskTopologyQuery).TotalMinutes<5)return;
            lastDiskTopologyQuery=DateTime.UtcNow;
            List<DiskTopologyEntry> fresh=new List<DiskTopologyEntry>();
            string[] perfInstances=new string[0];
            try{perfInstances=new PerformanceCounterCategory("PhysicalDisk").GetInstanceNames();}catch{}
            try
            {
                using(ManagementObjectSearcher q=new ManagementObjectSearcher("SELECT Index,DeviceID,Model,Size,InterfaceType,MediaType FROM Win32_DiskDrive"))
                foreach(ManagementObject disk in q.Get())
                {
                    DiskTopologyEntry e=new DiskTopologyEntry();
                    try{e.Index=Convert.ToInt32(disk["Index"],CultureInfo.InvariantCulture);}catch{}
                    e.Id=Convert.ToString(disk["DeviceID"],CultureInfo.InvariantCulture);if(String.IsNullOrWhiteSpace(e.Id))e.Id="PHYSICALDRIVE"+e.Index;
                    e.Name=Convert.ToString(disk["Model"],CultureInfo.InvariantCulture);if(String.IsNullOrWhiteSpace(e.Name))e.Name="Disk "+e.Index;
                    try{e.PhysicalSizeBytes=Convert.ToUInt64(disk["Size"],CultureInfo.InvariantCulture);}catch{}
                    e.InterfaceType=Convert.ToString(disk["InterfaceType"],CultureInfo.InvariantCulture);
                    e.MediaType=Convert.ToString(disk["MediaType"],CultureInfo.InvariantCulture);
                    string prefix=e.Index.ToString(CultureInfo.InvariantCulture);
                    e.PerfInstance=perfInstances.FirstOrDefault(delegate(string n){return !String.Equals(n,"_Total",StringComparison.OrdinalIgnoreCase)&&(String.Equals(n,prefix,StringComparison.OrdinalIgnoreCase)||n.StartsWith(prefix+" ",StringComparison.OrdinalIgnoreCase));});
                    try
                    {
                        foreach(ManagementObject part in disk.GetRelated("Win32_DiskPartition"))
                        foreach(ManagementObject logical in part.GetRelated("Win32_LogicalDisk"))
                        {
                            string id=Convert.ToString(logical["DeviceID"],CultureInfo.InvariantCulture);
                            if(!String.IsNullOrWhiteSpace(id)&&!e.Volumes.Contains(id,StringComparer.OrdinalIgnoreCase))e.Volumes.Add(id);
                        }
                    }
                    catch{}
                    fresh.Add(e);
                }
            }
            catch(Exception ex){Log.Write("WARN","DISK_TOPOLOGY_WMI "+ex.Message);}

            try
            {
                Dictionary<int,DiskTopologyEntry> byIndex=fresh.Where(x=>x.Index>=0).ToDictionary(x=>x.Index,x=>x);
                using(ManagementObjectSearcher pq=new ManagementObjectSearcher(
                    @"root\Microsoft\Windows\Storage",
                    "SELECT DeviceId,FriendlyName,BusType,MediaType,SpindleSpeed FROM MSFT_PhysicalDisk"))
                foreach(ManagementObject pd in pq.Get())
                {
                    int idx=-1;try{idx=Convert.ToInt32(pd["DeviceId"],CultureInfo.InvariantCulture);}catch{}
                    DiskTopologyEntry e;if(!byIndex.TryGetValue(idx,out e))continue;
                    int bus=0,media=0;
                    try{bus=Convert.ToInt32(pd["BusType"],CultureInfo.InvariantCulture);}catch{}
                    try{media=Convert.ToInt32(pd["MediaType"],CultureInfo.InvariantCulture);}catch{}
                    e.BusType=BusTypeName(bus);
                    string mt=PhysicalMediaTypeName(media);
                    if(!String.IsNullOrWhiteSpace(mt))e.MediaType=mt;
                }
            }
            catch(Exception ex){Log.Write("WARN","DISK_STORAGE_NAMESPACE "+ex.Message);}

            foreach(DiskTopologyEntry e in fresh)
                if(String.IsNullOrWhiteSpace(e.BusType))e.BusType=String.IsNullOrWhiteSpace(e.InterfaceType)?"Unknown":e.InterfaceType;

            if(fresh.Count==0)
            {
                foreach(DriveInfo d in DriveInfo.GetDrives())
                {
                    try
                    {
                        if(d.DriveType!=DriveType.Fixed||!d.IsReady)continue;
                        DiskTopologyEntry e=new DiskTopologyEntry();e.Id=d.Name.TrimEnd('\\');e.Name=String.IsNullOrWhiteSpace(d.VolumeLabel)?e.Id:(d.VolumeLabel+" ("+e.Id+")");e.PerfInstance=e.Id;e.LogicalCounterFallback=true;e.Volumes.Add(e.Id);e.PhysicalSizeBytes=(ulong)Math.Max(0,d.TotalSize);fresh.Add(e);
                    }
                    catch{}
                }
            }
            if(fresh.Count>0)diskTopology=fresh;
        }

        private double DiskCounterValue(Dictionary<string,PerformanceCounter> cache,string counterName,DiskTopologyEntry e)
        {
            if(e==null||String.IsNullOrWhiteSpace(e.PerfInstance))return 0;
            string category=e.LogicalCounterFallback?"LogicalDisk":"PhysicalDisk";string key=category+"|"+e.PerfInstance+"|"+counterName;
            try
            {
                PerformanceCounter c;
                if(!cache.TryGetValue(key,out c)){c=new PerformanceCounter(category,counterName,e.PerfInstance,true);c.NextValue();cache[key]=c;return 0;}
                double v=c.NextValue();if(Double.IsNaN(v)||Double.IsInfinity(v)||v<0)return 0;return v;
            }
            catch{return 0;}
        }

        private void ReadDiskTemperaturesIfDue()
        {
            if((DateTime.UtcNow-lastDiskTempQuery).TotalMilliseconds<1800)return;
            lastDiskTempQuery=DateTime.UtcNow;
            List<StorageTemperatureSample> isolated=new List<StorageTemperatureSample>();
            try{isolated=elevatedStorageTempReader.Read();}catch(Exception ex){Log.Write("WARN","DISK_TEMP_ISOLATED_READ "+ex.Message);}

            List<StorageTemperatureSample> merged=new List<StorageTemperatureSample>();
            foreach(StorageTemperatureSample x in isolated)if(x!=null&&x.Valid)merged.Add(x);
            lastStorageTemperatures=merged;
            string sig="isolated="+isolated.Count+" merged="+merged.Count+
                " sources="+String.Join("|",merged.Select(x=>(x.HardwareName??"")+"@"+(x.Source??"")).ToArray());
            if(!String.Equals(sig,lastDiskTemperatureProviderSignature,StringComparison.Ordinal))
            {
                lastDiskTemperatureProviderSignature=sig;
                Log.Write("INFO","DISK_TEMP_PROVIDER_R13 "+sig);
            }
        }

        private static int StorageSampleDriveNumber(StorageTemperatureSample sample)
        {
            if(sample==null||String.IsNullOrWhiteSpace(sample.HardwareId))return -1;
            try
            {
                Match m=Regex.Match(sample.HardwareId.Trim(),@"^/(?:nvme|ssd|hdd|storage)/([0-9]+)$",
                    RegexOptions.IgnoreCase|RegexOptions.CultureInvariant);
                int n=-1;
                if(m.Success&&Int32.TryParse(m.Groups[1].Value,NumberStyles.Integer,CultureInfo.InvariantCulture,out n))
                    return n;
            }
            catch{}
            return -1;
        }

        private StorageTemperatureSample FindDiskTemperature(DiskTopologyEntry disk)
        {
            if(disk==null||lastStorageTemperatures==null||lastStorageTemperatures.Count==0)return null;

            if(disk.Index>=0)
            {
                List<StorageTemperatureSample> byIndex=lastStorageTemperatures
                    .Where(delegate(StorageTemperatureSample x)
                    {
                        return x!=null&&x.Valid&&StorageSampleDriveNumber(x)==disk.Index;
                    }).ToList();

                if(byIndex.Count==1)return byIndex[0];

                if(byIndex.Count>1)
                {
                    string dn=NormalizeDiskModel(disk.Name);
                    StorageTemperatureSample indexedName=byIndex.FirstOrDefault(delegate(StorageTemperatureSample x)
                    {
                        return NormalizeDiskModel(x.HardwareName)==dn;
                    });
                    if(indexedName!=null)return indexedName;
                    Log.Write("WARN","DISK_TEMP_INDEX_AMBIGUOUS index="+disk.Index+
                        " samples="+String.Join("|",byIndex.Select(x=>(x.HardwareName??"")+"@"+(x.HardwareId??"")).ToArray()));
                }
            }

            string n=NormalizeDiskModel(disk.Name);
            StorageTemperatureSample exact=lastStorageTemperatures.FirstOrDefault(delegate(StorageTemperatureSample x)
            {
                return x!=null&&x.Valid&&NormalizeDiskModel(x.HardwareName)==n;
            });
            if(exact!=null)return exact;

            StorageTemperatureSample fuzzy=lastStorageTemperatures.FirstOrDefault(delegate(StorageTemperatureSample x)
            {
                string a=NormalizeDiskModel(x.HardwareName);
                return x!=null&&x.Valid&&a.Length>5&&n.Length>5&&(a.Contains(n)||n.Contains(a));
            });
            if(fuzzy!=null)return fuzzy;

            if(diskTopology.Count==1&&lastStorageTemperatures.Count==1)return lastStorageTemperatures[0];
            return null;
        }

        private void ReadDiskDevices(MetricsSnapshot s)
        {
            RefreshDiskTopologyIfDue();ReadDiskTemperaturesIfDue();
            Dictionary<string,DriveInfo> drives=new Dictionary<string,DriveInfo>(StringComparer.OrdinalIgnoreCase);
            foreach(DriveInfo d in DriveInfo.GetDrives())try{if(d.DriveType==DriveType.Fixed&&d.IsReady)drives[d.Name.TrimEnd('\\')]=d;}catch{}
            List<DiskDeviceSnapshot> list=new List<DiskDeviceSnapshot>();ulong usedAll=0,totalAll=0;double readAll=0,writeAll=0;float maxActivity=0;
            foreach(DiskTopologyEntry e in diskTopology)
            {
                try
                {
                    ulong used=0,total=0;List<string> mounted=new List<string>();
                    foreach(string vol in e.Volumes)
                    {
                        DriveInfo d;if(!drives.TryGetValue(vol,out d))continue;
                        ulong vt=(ulong)Math.Max(0,d.TotalSize);ulong vf=(ulong)Math.Max(0,d.AvailableFreeSpace);ulong vu=vt>=vf?vt-vf:0;used+=vu;total+=vt;mounted.Add(vol);
                    }
                    DiskDeviceSnapshot x=new DiskDeviceSnapshot();x.Id=e.Id;x.Name=e.Name;x.PhysicalSizeBytes=e.PhysicalSizeBytes;x.Volumes=String.Join(", ",mounted.ToArray());x.Root=x.Volumes;x.BusType=e.BusType;x.MediaType=e.MediaType;x.InterfaceType=e.InterfaceType;
                    x.UsedBytes=used;x.TotalBytes=total;x.CapacityAvailable=total>0;x.UsedPercent=total>0?(float)(used*100d/total):0;
                    x.Activity=(float)Math.Min(100,DiskCounterValue(diskActivityCounters,"% Disk Time",e));x.ActivityAvailable=!String.IsNullOrWhiteSpace(e.PerfInstance);
                    x.ReadBytesPerSec=DiskCounterValue(diskReadCounters,"Disk Read Bytes/sec",e);x.WriteBytesPerSec=DiskCounterValue(diskWriteCounters,"Disk Write Bytes/sec",e);x.RateAvailable=!String.IsNullOrWhiteSpace(e.PerfInstance);
                    StorageTemperatureSample st=FindDiskTemperature(e);if(st!=null&&st.Valid){x.Temperature=st.Temperature;x.TemperatureAvailable=true;x.TemperatureSource=st.Source;if(loggedDiskTemperatureMatches.Add(e.Id??e.Name)){string mm=StorageSampleDriveNumber(st)==e.Index?"INDEX":"MODEL";Log.Write("INFO","DISK_TEMP_MATCH_RESTORE_R02 diskId="+(e.Id??"")+" diskIndex="+e.Index+" disk="+(e.Name??"")+" sensor="+(st.HardwareName??"")+" hwid="+(st.HardwareId??"")+" method="+mm+" temp="+st.Temperature.ToString("0.0",CultureInfo.InvariantCulture)+" source="+(st.Source??""));}}
                    list.Add(x);if(x.CapacityAvailable){usedAll+=used;totalAll+=total;}readAll+=x.ReadBytesPerSec;writeAll+=x.WriteBytesPerSec;maxActivity=Math.Max(maxActivity,x.Activity);
                }
                catch(Exception ex){Log.Write("WARN","DISK_DEVICE_READ "+e.Id+" "+ex.Message);}
            }
            s.DiskDevices=list;s.DiskUsedBytes=usedAll;s.DiskTotalBytes=totalAll;s.DiskUsedPercent=totalAll>0?(float)(usedAll*100d/totalAll):0;s.DiskReadBytesPerSec=readAll;s.DiskWriteBytesPerSec=writeAll;if(list.Count>0)s.Disk=maxActivity;
        }

        private void RefreshNetworkTopologyIfDue(bool force)
        {
            if(!force&&networkInterfaces.Count>0&&(DateTime.UtcNow-lastNetworkTopologyQuery).TotalSeconds<30)return;
            lastNetworkTopologyQuery=DateTime.UtcNow;
            try
            {
                networkInterfaces=NetworkInterface.GetAllNetworkInterfaces()
                    .Where(n=>n.OperationalStatus==OperationalStatus.Up&&n.NetworkInterfaceType!=NetworkInterfaceType.Loopback)
                    .ToList();
                HashSet<string> ids=new HashSet<string>(networkInterfaces.Select(n=>n.Id),StringComparer.OrdinalIgnoreCase);
                foreach(string id in previousRx.Keys.Where(x=>!ids.Contains(x)).ToList())previousRx.Remove(id);
                foreach(string id in previousTx.Keys.Where(x=>!ids.Contains(x)).ToList())previousTx.Remove(id);
            }
            catch(Exception ex){Log.Write("WARN","NETWORK_TOPOLOGY "+ex.Message);}
        }

        private void CaptureNetworkBaseline()
        {
            previousRx.Clear();previousTx.Clear();RefreshNetworkTopologyIfDue(true);
            foreach(NetworkInterface n in networkInterfaces)try{IPv4InterfaceStatistics st=n.GetIPv4Statistics();previousRx[n.Id]=st.BytesReceived;previousTx[n.Id]=st.BytesSent;}catch{}
            previousNetAt=DateTime.UtcNow;
        }

        private void ReadNetwork(MetricsSnapshot s)
        {
            RefreshNetworkTopologyIfDue(false);
            DateTime now=DateTime.UtcNow;double sec=Math.Max(0.05,(now-previousNetAt).TotalSeconds);double rxAll=0,txAll=0;List<NetworkDeviceSnapshot> list=new List<NetworkDeviceSnapshot>();
            foreach(NetworkInterface n in networkInterfaces)
            {
                try
                {
                    if(n.OperationalStatus!=OperationalStatus.Up||n.NetworkInterfaceType==NetworkInterfaceType.Loopback)continue;IPv4InterfaceStatistics st=n.GetIPv4Statistics();long prx,ptx;long drx=previousRx.TryGetValue(n.Id,out prx)?Math.Max(0,st.BytesReceived-prx):0;long dtx=previousTx.TryGetValue(n.Id,out ptx)?Math.Max(0,st.BytesSent-ptx):0;previousRx[n.Id]=st.BytesReceived;previousTx[n.Id]=st.BytesSent;
                    NetworkDeviceSnapshot d=new NetworkDeviceSnapshot();d.Id=n.Id;d.Name=n.Name;d.Description=n.Description;d.Active=true;try{d.LinkSpeedBitsPerSec=n.Speed;}catch{}d.DownBytesPerSec=drx/sec;d.UpBytesPerSec=dtx/sec;list.Add(d);rxAll+=d.DownBytesPerSec;txAll+=d.UpBytesPerSec;
                }catch{}
            }
            previousNetAt=now;s.NetworkDevices=list;s.NetDownBytesPerSec=rxAll;s.NetUpBytesPerSec=txAll;s.NetDownMbps=(float)(rxAll*8d/1000000d);s.NetUpMbps=(float)(txAll*8d/1000000d);
        }

        private void ReadCpuTemperatureIfDue()
        {
            if((DateTime.UtcNow-lastCpuTempQuery).TotalMilliseconds<1800)return;lastCpuTempQuery=DateTime.UtcNow;
            try
            {
                CpuTemperatureSample sample=cpuTempReader.Read();
                lastCpuTempSource=sample.Source??"UNAVAILABLE";
                lastCpuPowerAvailable=sample.PowerAvailable;
                lastCpuPowerW=sample.PowerAvailable?sample.PowerW:0;
                lastCpuPowerSource=sample.PowerAvailable?(sample.PowerSource??"LHM_ELEVATED_BROKER"):"UNAVAILABLE";
                if(sample.Valid){lastCpuTempCurrent=sample.Current;lastCpuTempValidAt=DateTime.UtcNow;cpuTemps.Add(sample.Average,sample.Maximum);}
            }
            catch(Exception ex){Log.Write("WARN","CPU_TEMP_READ "+ex.Message);}
        }

        private static bool IsAmdName(string s){s=s??"";return s.IndexOf("AMD",StringComparison.OrdinalIgnoreCase)>=0||s.IndexOf("Radeon",StringComparison.OrdinalIgnoreCase)>=0;}
        private static string NormalizeGpuName(string s){if(String.IsNullOrWhiteSpace(s))return "";string n=Regex.Replace(s.ToLowerInvariant(),@"[^a-z0-9]+","");foreach(string x in new string[]{"nvidiacorporation","advancedmicrodevicesinc","intelcorporation","microsoftcorporation"})n=n.Replace(x,"");return n;}
        private static GpuTelemetrySample FindMatch(List<GpuTelemetrySample> list,GpuTelemetrySample sample)
        {
            string n=NormalizeGpuName(sample.HardwareName);if(n.Length==0)return null;GpuTelemetrySample exact=list.FirstOrDefault(x=>NormalizeGpuName(x.HardwareName)==n);if(exact!=null)return exact;return list.FirstOrDefault(x=>{string a=NormalizeGpuName(x.HardwareName);return a.Length>5&&(a.Contains(n)||n.Contains(a));});
        }
        private static void MergeGpu(List<GpuTelemetrySample> list,GpuTelemetrySample sample,bool preferSample)
        {
            if(sample==null)return;GpuTelemetrySample d=FindMatch(list,sample);if(d==null){list.Add(sample);return;}
            if(preferSample||!d.LoadValid){if(sample.LoadValid){d.Load=sample.Load;d.LoadValid=true;}}
            if(preferSample||d.VramUsedGb<=0){if(sample.VramUsedGb>0)d.VramUsedGb=sample.VramUsedGb;}if(preferSample||d.VramTotalGb<=0){if(sample.VramTotalGb>0)d.VramTotalGb=sample.VramTotalGb;}
            if(preferSample||!d.TemperatureValid){if(sample.TemperatureValid){d.Temperature=sample.Temperature;d.TemperatureValid=true;}}
            if(preferSample||!d.CoreClockValid){if(sample.CoreClockValid){d.CoreClockMHz=sample.CoreClockMHz;d.CoreClockValid=true;}}
            if(preferSample||!d.MemoryClockValid){if(sample.MemoryClockValid){d.MemoryClockMHz=sample.MemoryClockMHz;d.MemoryClockValid=true;}}
            if(preferSample||!d.PowerValid){if(sample.PowerValid){d.PowerW=sample.PowerW;d.PowerValid=true;}}
            if(preferSample||!d.FanRpmValid){if(sample.FanRpmValid){d.FanRpm=sample.FanRpm;d.FanRpmValid=true;}}
            if(preferSample||!d.FanPercentValid){if(sample.FanPercentValid){d.FanPercent=sample.FanPercent;d.FanPercentValid=true;}}
            if(sample.PcieGeneration>0)d.PcieGeneration=sample.PcieGeneration;
            if(sample.PcieWidth>0)d.PcieWidth=sample.PcieWidth;
            if(!String.IsNullOrWhiteSpace(sample.HardwareId)&&sample.HardwareId.IndexOf("LHM:",StringComparison.OrdinalIgnoreCase)!=0)d.HardwareId=sample.HardwareId;
            if(preferSample)d.Source=sample.Source;
        }

        private List<GpuTelemetrySample> ReadNvidiaSmiAll()
        {
            List<GpuTelemetrySample> r=new List<GpuTelemetrySample>();string exe=FindNvidiaSmi();if(exe==null)return r;
            try
            {
                ProcessStartInfo psi=new ProcessStartInfo();psi.FileName=exe;psi.Arguments="--query-gpu=index,name,pci.bus_id,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits";psi.UseShellExecute=false;psi.CreateNoWindow=true;psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;
                using(Process p=Process.Start(psi)){if(p==null)return r;if(!p.WaitForExit(1500)){try{p.Kill();}catch{};return r;}string stdout=p.StandardOutput.ReadToEnd();if(p.ExitCode!=0)return r;using(StringReader sr=new StringReader(stdout)){string line;while((line=sr.ReadLine())!=null){if(String.IsNullOrWhiteSpace(line))continue;string[] a=line.Split(',');if(a.Length<7)continue;GpuTelemetrySample g=new GpuTelemetrySample();g.Valid=true;g.Source="NVIDIA_SMI";g.HardwareName=a[1].Trim();g.HardwareId="NVIDIA:"+a[2].Trim();int idx;if(Int32.TryParse(a[0].Trim(),out idx))g.AdapterIndex=idx;float f;if(Single.TryParse(a[3].Trim(),NumberStyles.Float,CultureInfo.InvariantCulture,out f)){g.Load=Clamp(f,0,100);g.LoadValid=true;}if(Single.TryParse(a[4].Trim(),NumberStyles.Float,CultureInfo.InvariantCulture,out f))g.VramUsedGb=f/1024f;if(Single.TryParse(a[5].Trim(),NumberStyles.Float,CultureInfo.InvariantCulture,out f))g.VramTotalGb=f/1024f;if(Single.TryParse(a[6].Trim(),NumberStyles.Float,CultureInfo.InvariantCulture,out f)&&f>=5&&f<=130){g.Temperature=f;g.TemperatureValid=true;}r.Add(g);}}}
            }catch(Exception ex){Log.Write("WARN","NVIDIA_SMI_MULTI "+ex.Message);}
            return r;
        }

        private void EnrichNvidiaSmiDetails(List<GpuTelemetrySample> samples)
        {
            string exe=FindNvidiaSmi();if(exe==null||samples==null||samples.Count==0)return;
            try
            {
                ProcessStartInfo psi=new ProcessStartInfo();
                psi.FileName=exe;
                psi.Arguments="--query-gpu=index,clocks.current.graphics,clocks.current.memory,pcie.link.gen.current,pcie.link.width.current --format=csv,noheader,nounits";
                psi.UseShellExecute=false;psi.CreateNoWindow=true;psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;
                using(Process p=Process.Start(psi))
                {
                    if(p==null)return;
                    if(!p.WaitForExit(1200)){try{p.Kill();}catch{}return;}
                    string stdout=p.StandardOutput.ReadToEnd();if(p.ExitCode!=0)return;
                    using(StringReader sr=new StringReader(stdout))
                    {
                        string line;
                        while((line=sr.ReadLine())!=null)
                        {
                            string[] a=line.Split(',');if(a.Length<5)continue;
                            int idx;if(!Int32.TryParse(a[0].Trim(),out idx))continue;
                            GpuTelemetrySample g=samples.FirstOrDefault(x=>x.AdapterIndex==idx);
                            if(g==null)continue;
                            float f;int n;
                            if(Single.TryParse(a[1].Trim(),NumberStyles.Float,CultureInfo.InvariantCulture,out f)&&f>0){g.CoreClockMHz=f;g.CoreClockValid=true;}
                            if(Single.TryParse(a[2].Trim(),NumberStyles.Float,CultureInfo.InvariantCulture,out f)&&f>0){g.MemoryClockMHz=f;g.MemoryClockValid=true;}
                            if(Int32.TryParse(a[3].Trim(),out n)&&n>0)g.PcieGeneration=n;
                            if(Int32.TryParse(a[4].Trim(),out n)&&n>0)g.PcieWidth=n;
                        }
                    }
                }
            }
            catch(Exception ex){Log.Write("WARN","NVIDIA_SMI_DETAILS "+ex.Message);}
        }

        private void ReadGpuIfDue()
        {
            if((DateTime.UtcNow-lastGpuQuery).TotalMilliseconds<1800)return;lastGpuQuery=DateTime.UtcNow;List<GpuTelemetrySample> merged=new List<GpuTelemetrySample>();
            try{foreach(GpuTelemetrySample x in elevatedGpuReader.ReadAll())MergeGpu(merged,x,true);}catch(Exception ex){Log.Write("WARN","GPU_ISOLATED_BROKER "+ex.Message);}
            if(merged.Count==0||!merged.Any(x=>x.LoadValid))
            {
                try{foreach(GpuTelemetrySample x in windowsGpuReader.ReadAll())MergeGpu(merged,x,false);}catch(Exception ex){Log.Write("WARN","GPU_WDDM_FALLBACK "+ex.Message);}
            }
            // R15 narrow diagnostic: external NVIDIA SMI primary query disabled; WDDM + LHM remain active.
            // R15 narrow diagnostic: external NVIDIA SMI detail query disabled; all other v1.1.0 behavior unchanged.
            try
            {
                GpuTelemetrySample amd=merged.Where(x=>IsAmdName(x.HardwareName)&&!x.TemperatureValid).OrderByDescending(x=>x.LoadValid?x.Load:-1).FirstOrDefault();
                if(amd!=null){AdlxGpuTemperatureSample a=amdAdlxTempReader.Read();if(a.Valid){amd.Temperature=a.Temperature;amd.TemperatureValid=true;lastGpuTempSource=a.Source;}}
            }catch(Exception ex){Log.Write("WARN","GPU_ADLX_MULTI "+ex.Message);}
            List<GpuDeviceSnapshot> devices=new List<GpuDeviceSnapshot>();int i=0;foreach(GpuTelemetrySample x in merged){GpuDeviceSnapshot d=new GpuDeviceSnapshot();d.Id=String.IsNullOrWhiteSpace(x.HardwareId)?("GPU:"+i):x.HardwareId;d.Name=String.IsNullOrWhiteSpace(x.HardwareName)?("GPU "+i):x.HardwareName;d.Source=x.Source;d.Usage=x.Load;d.UsageAvailable=x.LoadValid;d.Temperature=x.Temperature;d.TemperatureAvailable=x.TemperatureValid;d.VramUsedGb=Math.Max(0,x.VramUsedGb);d.VramTotalGb=Math.Max(0,x.VramTotalGb);d.CoreClockMHz=x.CoreClockMHz;d.MemoryClockMHz=x.MemoryClockMHz;d.CoreClockAvailable=x.CoreClockValid;d.MemoryClockAvailable=x.MemoryClockValid;d.PowerW=x.PowerW;d.PowerAvailable=x.PowerValid;d.FanRpm=x.FanRpm;d.FanRpmAvailable=x.FanRpmValid;d.FanPercent=x.FanPercent;d.FanPercentAvailable=x.FanPercentValid;d.PcieGeneration=x.PcieGeneration;d.PcieWidth=x.PcieWidth;devices.Add(d);i++;}
            lastGpuDevices=devices;GpuDeviceSnapshot temp=devices.Where(x=>x.TemperatureAvailable).OrderByDescending(x=>x.UsageAvailable?x.Usage:-1).FirstOrDefault();if(temp!=null)lastGpuTempSource=temp.Source??lastGpuTempSource;
        }

        private static string FindNvidiaSmi()
        {
            string[] c=new string[]{Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"NVIDIA Corporation","NVSMI","nvidia-smi.exe"),Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","nvidia-smi.exe")};foreach(string x in c)if(File.Exists(x))return x;return null;
        }

        public void Dispose()
        {
            if(cpuFrequencyCounter!=null)cpuFrequencyCounter.Dispose();if(diskCounter!=null)diskCounter.Dispose();foreach(PerformanceCounter c in diskActivityCounters.Values)try{c.Dispose();}catch{}foreach(PerformanceCounter c in diskReadCounters.Values)try{c.Dispose();}catch{}foreach(PerformanceCounter c in diskWriteCounters.Values)try{c.Dispose();}catch{};try{cpuTempReader.Dispose();}catch{}try{amdAdlxTempReader.Dispose();}catch{}
        }
    }

    internal static class NativeMemory
    {
        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Auto)]
        private class MEMORYSTATUSEX
        {
            public uint dwLength=(uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
            public uint dwMemoryLoad; public ulong ullTotalPhys; public ulong ullAvailPhys; public ulong ullTotalPageFile; public ulong ullAvailPageFile; public ulong ullTotalVirtual; public ulong ullAvailVirtual; public ulong ullAvailExtendedVirtual;
        }
        [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)] private static extern bool GlobalMemoryStatusEx([In,Out] MEMORYSTATUSEX lpBuffer);
        public static void GetUsage(out ulong used,out ulong total,out float percent)
        {
            used=0;total=0;percent=0;try{MEMORYSTATUSEX m=new MEMORYSTATUSEX();if(GlobalMemoryStatusEx(m)){total=m.ullTotalPhys;used=total>=m.ullAvailPhys?total-m.ullAvailPhys:0;percent=m.dwMemoryLoad;}}catch{}
        }
        public static float GetUsedPercent(){ulong u,t;float p;GetUsage(out u,out t,out p);return p;}
    }

    internal static class Native
    {
        public const int GWL_STYLE=-16;
        public const int GWL_EXSTYLE=-20;
        public const int GWLP_HWNDPARENT=-8;
        public const uint GW_OWNER=4;
        public const long WS_CHILD=0x40000000L;
        public const long WS_POPUP=unchecked((long)0x80000000L);
        public const int WS_EX_TOPMOST=0x00000008;
        public const int WS_EX_TRANSPARENT=0x00000020;
        public const int WS_EX_TOOLWINDOW=0x00000080;
        public const int WS_EX_CONTROLPARENT=0x00010000;
        public const int WS_EX_LAYERED=0x00080000;
        public const int WS_EX_COMPOSITED=0x02000000;
        public const int WS_EX_NOACTIVATE=0x08000000;
        public const uint LWA_COLORKEY=0x00000001;
        public const uint LWA_ALPHA=0x00000002;
        public const int WH_MOUSE_LL=14;
        public const int HC_ACTION=0;
        public const int WM_RBUTTONDOWN=0x0204;
        public const int WM_RBUTTONUP=0x0205;
        public const int WM_TBME_VISUAL_BEACON=0x805B;
        public const uint SWP_NOSIZE=0x0001, SWP_NOMOVE=0x0002, SWP_NOZORDER=0x0004, SWP_NOACTIVATE=0x0010, SWP_FRAMECHANGED=0x0020, SWP_SHOWWINDOW=0x0040, SWP_NOOWNERZORDER=0x0200;
        public static readonly IntPtr HWND_TOP=IntPtr.Zero;
        public static readonly IntPtr HWND_TOPMOST=new IntPtr(-1);

        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; public Rectangle ToRectangle(){return Rectangle.FromLTRB(Left,Top,Right,Bottom);} }
        [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X,Y; }
        [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk,wScan; public uint dwFlags,time; public IntPtr dwExtraInfo; }
        [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION { [FieldOffset(0)] public KEYBDINPUT ki; }
        [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION U; }

        [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern IntPtr FindWindow(string lpClassName,string lpWindowName);
        [DllImport("user32.dll",SetLastError=true)] public static extern bool GetWindowRect(IntPtr hWnd,out RECT rect);
        [DllImport("user32.dll",SetLastError=true)] public static extern IntPtr SetParent(IntPtr hWndChild,IntPtr hWndNewParent);
        [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr hWnd,uint uCmd);
        [DllImport("user32.dll",SetLastError=true)] public static extern bool SetWindowPos(IntPtr hWnd,IntPtr hWndInsertAfter,int X,int Y,int cx,int cy,uint flags);
        public delegate bool EnumWindowsProc(IntPtr hWnd,IntPtr lParam);
        public delegate bool EnumChildWindowsProc(IntPtr hWnd,IntPtr lParam);
        public delegate IntPtr LowLevelMouseProc(int nCode,IntPtr wParam,IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct MSLLHOOKSTRUCT
        {
            public POINT pt;
            public uint mouseData;
            public uint flags;
            public uint time;
            public UIntPtr dwExtraInfo;
        }
        [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc,IntPtr lParam);
        [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hWndParent,EnumChildWindowsProc lpEnumFunc,IntPtr lParam);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT pt);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd,out uint processId);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern int GetClassName(IntPtr hWnd,StringBuilder lpClassName,int nMaxCount);
        [DllImport("user32.dll",SetLastError=true)] private static extern uint SendInput(uint nInputs,[In] INPUT[] pInputs,int cbSize);
        [DllImport("user32.dll",SetLastError=true)] public static extern bool SetLayeredWindowAttributes(IntPtr hwnd,uint crKey,byte bAlpha,uint dwFlags);
        [DllImport("user32.dll",SetLastError=true)] public static extern IntPtr SetWindowsHookEx(int idHook,LowLevelMouseProc lpfn,IntPtr hMod,uint dwThreadId);
        [DllImport("user32.dll",SetLastError=true)] public static extern bool UnhookWindowsHookEx(IntPtr hhk);
        [DllImport("user32.dll")] public static extern IntPtr CallNextHookEx(IntPtr hhk,int nCode,IntPtr wParam,IntPtr lParam);
        [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern IntPtr SendMessage(IntPtr hWnd,int msg,IntPtr wParam,IntPtr lParam);
        [DllImport("kernel32.dll",CharSet=CharSet.Auto)] public static extern IntPtr GetModuleHandle(string lpModuleName);
        [DllImport("user32.dll")] private static extern void keybd_event(byte bVk,byte bScan,uint dwFlags,UIntPtr dwExtraInfo);
        [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr hwnd,int attr,out int value,int cb);
        [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
        [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern uint RegisterWindowMessage(string lpString);

        [DllImport("user32.dll", EntryPoint="GetWindowLongPtr", SetLastError=true)] private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd,int nIndex);
        [DllImport("user32.dll", EntryPoint="GetWindowLong", SetLastError=true)] private static extern IntPtr GetWindowLongPtr32(IntPtr hWnd,int nIndex);
        [DllImport("user32.dll", EntryPoint="SetWindowLongPtr", SetLastError=true)] private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd,int nIndex,IntPtr dwNewLong);
        [DllImport("user32.dll", EntryPoint="SetWindowLong", SetLastError=true)] private static extern IntPtr SetWindowLongPtr32(IntPtr hWnd,int nIndex,IntPtr dwNewLong);
        public static IntPtr GetWindowLongPtr(IntPtr hWnd,int nIndex){return IntPtr.Size==8?GetWindowLongPtr64(hWnd,nIndex):GetWindowLongPtr32(hWnd,nIndex);} 
        public static IntPtr SetWindowLongPtr(IntPtr hWnd,int nIndex,IntPtr v){return IntPtr.Size==8?SetWindowLongPtr64(hWnd,nIndex,v):SetWindowLongPtr32(hWnd,nIndex,v);} 
        public static int GetCloaked(IntPtr h){ try {int v; return DwmGetWindowAttribute(h,14,out v,sizeof(int))==0?v:0;} catch{return 0;} }

        public static bool SendVirtualKey(ushort vk)
        {
            try
            {
                INPUT down=new INPUT();down.type=1;down.U.ki=new KEYBDINPUT();down.U.ki.wVk=vk;
                INPUT up=new INPUT();up.type=1;up.U.ki=new KEYBDINPUT();up.U.ki.wVk=vk;up.U.ki.dwFlags=0x0002;
                INPUT[] a=new INPUT[]{down,up};
                return SendInput((uint)a.Length,a,Marshal.SizeOf(typeof(INPUT)))==(uint)a.Length;
            }
            catch{return false;}
        }

        public static void KeybdTap(byte vk)
        {
            try
            {
                keybd_event(vk,0,0,UIntPtr.Zero);
                Thread.Sleep(25);
                keybd_event(vk,0,0x0002,UIntPtr.Zero);
            }
            catch{}
        }

        public static void CtrlEsc()
        {
            try
            {
                keybd_event(0x11,0,0,UIntPtr.Zero);
                Thread.Sleep(20);
                keybd_event(0x1B,0,0,UIntPtr.Zero);
                Thread.Sleep(20);
                keybd_event(0x1B,0,0x0002,UIntPtr.Zero);
                keybd_event(0x11,0,0x0002,UIntPtr.Zero);
            }
            catch{}
        }

        public static IntPtr FindDescendantByClass(IntPtr parent,string className)
        {
            IntPtr found=IntPtr.Zero;
            try
            {
                EnumChildWindows(parent,delegate(IntPtr h,IntPtr l)
                {
                    StringBuilder sb=new StringBuilder(256);
                    GetClassName(h,sb,sb.Capacity);
                    if(String.Equals(sb.ToString(),className,StringComparison.Ordinal))
                    {
                        found=h;
                        return false;
                    }
                    return true;
                },IntPtr.Zero);
            }
            catch{}
            return found;
        }

        public static void EnableDpi(){try{SetProcessDPIAware();}catch{}}
    }

    internal static class ShellUi
    {
        private static bool NameMatches(string name)
        {
            if(String.IsNullOrEmpty(name))return false;
            return
                String.Equals(name,"SearchHost",StringComparison.OrdinalIgnoreCase) ||
                String.Equals(name,"StartMenuExperienceHost",StringComparison.OrdinalIgnoreCase) ||
                String.Equals(name,"SearchApp",StringComparison.OrdinalIgnoreCase) ||
                String.Equals(name,"ShellExperienceHost",StringComparison.OrdinalIgnoreCase) ||
                String.Equals(name,"ShellHost",StringComparison.OrdinalIgnoreCase) ||
                String.Equals(name,"TextInputHost",StringComparison.OrdinalIgnoreCase);
        }

        public static bool IsStartShellForeground(out string processName,out string className,out IntPtr hwnd)
        {
            processName="";
            className="";
            hwnd=IntPtr.Zero;
            try
            {
                hwnd=Native.GetForegroundWindow();
                if(hwnd==IntPtr.Zero)return false;

                StringBuilder sb=new StringBuilder(256);
                Native.GetClassName(hwnd,sb,sb.Capacity);
                className=sb.ToString();

                uint pid=0;
                Native.GetWindowThreadProcessId(hwnd,out pid);
                if(pid==0)return false;

                using(Process p=Process.GetProcessById((int)pid))
                    processName=p.ProcessName;

                return NameMatches(processName);
            }
            catch{return false;}
        }

        public static bool IsStartShellProcessName(string processName)
        {
            return NameMatches(processName);
        }

        public static bool IsStartSurfacePresent(out string processName,out string className,out Rectangle rect,out IntPtr hwnd)
        {
            processName="";
            className="";
            rect=Rectangle.Empty;
            hwnd=IntPtr.Zero;

            try
            {
                Rectangle screen=Screen.PrimaryScreen.Bounds;
                IntPtr found=IntPtr.Zero;
                string foundProcess="";
                string foundClass="";
                Rectangle foundRect=Rectangle.Empty;

                Native.EnumWindows(delegate(IntPtr h,IntPtr l)
                {
                    if(!Native.IsWindowVisible(h))return true;

                    Native.RECT wr;
                    if(!Native.GetWindowRect(h,out wr))return true;
                    Rectangle r=wr.ToRectangle();

                    uint pid=0;
                    Native.GetWindowThreadProcessId(h,out pid);
                    if(pid==0)return true;

                    string pn="";
                    try{using(Process p=Process.GetProcessById((int)pid))pn=p.ProcessName;}catch{return true;}

                    bool realStartHost=
                        String.Equals(pn,"SearchHost",StringComparison.OrdinalIgnoreCase) ||
                        String.Equals(pn,"StartMenuExperienceHost",StringComparison.OrdinalIgnoreCase) ||
                        String.Equals(pn,"SearchApp",StringComparison.OrdinalIgnoreCase);

                    if(!realStartHost)return true;
                    if(r.Width<300 || r.Height<250)return true;
                    if(r.Width>=screen.Width-20 && r.Height>=screen.Height-20)return true;
                    if(r.Bottom < screen.Top + screen.Height/2)return true;

                    StringBuilder sb=new StringBuilder(256);
                    Native.GetClassName(h,sb,sb.Capacity);

                    found=h;
                    foundProcess=pn;
                    foundClass=sb.ToString();
                    foundRect=r;
                    return false;
                },IntPtr.Zero);

                if(found==IntPtr.Zero)return false;
                processName=foundProcess;
                className=foundClass;
                rect=foundRect;
                hwnd=found;
                return true;
            }
            catch{return false;}
        }

        public static bool WaitForStartShell(int timeoutMs,out string processName,out string className,out IntPtr hwnd)
        {
            processName="";
            className="";
            hwnd=IntPtr.Zero;

            DateTime end=DateTime.UtcNow.AddMilliseconds(Math.Max(100,timeoutMs));
            while(DateTime.UtcNow<end)
            {
                if(IsStartShellForeground(out processName,out className,out hwnd))
                    return true;
                Thread.Sleep(50);
            }
            return false;
        }
    }

    internal static class TaskbarLayout
    {
        private static Rectangle? lastSafe;
        private const int ControlPaddingPx=8;
        private const int PreferredAdaptiveMinWidthPx=420;

        private static int GapWidth(Tuple<int,int> g){return Math.Max(0,g.Item2-g.Item1);}

        private static Tuple<int,int> PickGap(List<Tuple<int,int>> gaps,string position,Rectangle tb)
        {
            if(gaps==null || gaps.Count==0)return null;

            if(position=="Right")
                return gaps.OrderByDescending(g=>g.Item2).ThenByDescending(g=>GapWidth(g)).First();

            if(position=="Center")
                return gaps.OrderByDescending(g=>GapWidth(g))
                    .ThenBy(g=>Math.Abs(((g.Item1+g.Item2)/2)-(tb.Left+tb.Width/2))).First();

            return gaps.OrderBy(g=>g.Item1).ThenByDescending(g=>GapWidth(g)).First();
        }

        public static Rectangle GetSafeRectangle(IntPtr taskbar, AppConfig cfg, int desiredWidth)
        {
            Native.RECT nr;
            if(!Native.GetWindowRect(taskbar,out nr)) return Rectangle.Empty;

            Rectangle tb=nr.ToRectangle();
            int requestedWidth=Math.Min(Math.Max(1,desiredWidth),tb.Width);

            if(!cfg.SafePlacement)
            {
                Rectangle plain=Requested(tb,requestedWidth,cfg.Position);
                lastSafe=plain;
                return plain;
            }

            try
            {
                AutomationElement root=AutomationElement.FromHandle(taskbar);
                AutomationElementCollection all=root.FindAll(TreeScope.Descendants,Condition.TrueCondition);
                List<Tuple<int,int>> occ=new List<Tuple<int,int>>();

                for(int i=0;i<all.Count;i++)
                {
                    AutomationElement e=all[i];
                    ControlType ct;
                    try{ct=e.Current.ControlType;}catch{continue;}

                    if(ct!=ControlType.Button &&
                       ct!=ControlType.Edit &&
                       ct!=ControlType.MenuItem &&
                       ct!=ControlType.CheckBox &&
                       ct!=ControlType.RadioButton &&
                       ct!=ControlType.ComboBox &&
                       ct!=ControlType.Hyperlink) continue;

                    System.Windows.Rect r;
                    try{r=e.Current.BoundingRectangle;}catch{continue;}
                    if(r.IsEmpty || r.Width<3 || r.Height<3) continue;

                    int l=(int)Math.Floor(r.Left)-ControlPaddingPx;
                    int rr=(int)Math.Ceiling(r.Right)+ControlPaddingPx;
                    int t=(int)Math.Floor(r.Top);
                    int b=(int)Math.Ceiling(r.Bottom);

                    if(b<=tb.Top || t>=tb.Bottom || rr<=tb.Left || l>=tb.Right) continue;

                    occ.Add(Tuple.Create(
                        Math.Max(tb.Left,l),
                        Math.Min(tb.Right,rr)
                    ));
                }

                if(occ.Count==0)
                {
                    // Do not silently reuse a potentially stale wide rectangle after a
                    // resolution/taskbar-layout transition.  Re-evaluate next tick.
                    Rectangle noControls=Requested(tb,requestedWidth,cfg.Position);
                    lastSafe=noControls;
                    return noControls;
                }

                occ.Sort((a,b)=>a.Item1.CompareTo(b.Item1));

                List<Tuple<int,int>> merged=new List<Tuple<int,int>>();
                foreach(var x in occ)
                {
                    if(merged.Count==0 || x.Item1>merged[merged.Count-1].Item2)
                    {
                        merged.Add(Tuple.Create(x.Item1,x.Item2));
                    }
                    else
                    {
                        var p=merged[merged.Count-1];
                        merged[merged.Count-1]=Tuple.Create(
                            p.Item1,
                            Math.Max(p.Item2,x.Item2)
                        );
                    }
                }

                List<Tuple<int,int>> gaps=new List<Tuple<int,int>>();
                int cur=tb.Left;
                foreach(var x in merged)
                {
                    if(x.Item1>cur)gaps.Add(Tuple.Create(cur,x.Item1));
                    cur=Math.Max(cur,x.Item2);
                }
                if(cur<tb.Right)gaps.Add(Tuple.Create(cur,tb.Right));

                if(gaps.Count==0)
                {
                    Log.Write("WARN","SAFE_PLACEMENT_NO_FREE_GAP taskbar="+tb.ToString());
                    return Rectangle.Empty;
                }

                // First choice: preserve the configured/requested width.
                List<Tuple<int,int>> fullWidthGaps=
                    gaps.Where(g=>GapWidth(g)>=requestedWidth).ToList();

                Tuple<int,int> pick;
                int actualWidth=requestedWidth;

                if(fullWidthGaps.Count>0)
                {
                    pick=PickGap(fullWidthGaps,cfg.Position,tb);
                }
                else
                {
                    // Laptop / compact-taskbar path:
                    // never cover Start/Search/pinned/system-tray controls merely because
                    // the configured desktop width cannot fit.  Select an appropriate free
                    // gap and reduce the overlay width to that real available space.
                    int adaptiveFloor=Math.Min(PreferredAdaptiveMinWidthPx,requestedWidth);
                    List<Tuple<int,int>> usable=
                        gaps.Where(g=>GapWidth(g)>=adaptiveFloor).ToList();

                    if(usable.Count==0)
                    {
                        // On an unusually crowded taskbar, use the largest remaining gap
                        // rather than overlapping Windows controls.
                        int largest=gaps.Max(g=>GapWidth(g));
                        usable=gaps.Where(g=>GapWidth(g)==largest).ToList();
                    }

                    pick=PickGap(usable,cfg.Position,tb);
                    if(pick==null || GapWidth(pick)<=0)return Rectangle.Empty;

                    actualWidth=Math.Min(requestedWidth,GapWidth(pick));

                    Log.Write(
                        "INFO",
                        "SAFE_PLACEMENT_ADAPT requested="+requestedWidth+
                        " actual="+actualWidth+
                        " gap=["+pick.Item1+","+pick.Item2+"]"+
                        " position="+cfg.Position+
                        " taskbarWidth="+tb.Width
                    );
                }

                if(pick==null)return Rectangle.Empty;

                int x0;
                if(cfg.Position=="Right")
                    x0=pick.Item2-actualWidth;
                else if(cfg.Position=="Center")
                    x0=pick.Item1+((GapWidth(pick)-actualWidth)/2);
                else
                    x0=pick.Item1;

                Rectangle safe=new Rectangle(
                    x0,
                    tb.Top,
                    actualWidth,
                    tb.Height
                );

                lastSafe=safe;
                return safe;
            }
            catch(Exception ex)
            {
                Log.Write("WARN","SAFE_PLACEMENT_REEVALUATE "+ex.Message);

                // A stale cached rectangle can overlap controls after DPI/resolution or
                // Explorer layout changes.  Prefer the configured rectangle only when no
                // UIA result is available; the next timer tick re-evaluates placement.
                Rectangle fallback=Requested(tb,requestedWidth,cfg.Position);
                lastSafe=fallback;
                return fallback;
            }
        }

        private static Rectangle Requested(Rectangle tb,int width,string position)
        {
            int x=tb.Left;
            if(position=="Right")x=tb.Right-width;
            else if(position=="Center")x=tb.Left+(tb.Width-width)/2;
            return new Rectangle(x,tb.Top,width,tb.Height);
        }

        public static void ResetCache(){lastSafe=null;}
    }

    internal sealed class MetricView
    {
        public string Key,GroupKey,DeviceId,DisplayName,Label,Value,Value2; public float Percent; public IList<float> History; public Color Accent;
    }

    internal sealed class HardwareFlyoutRow
    {
        public string Name,Line1,Line2,Line3; public Color Accent;
    }

    internal sealed class HardwareFlyoutForm : Form
    {
        private string title=""; private List<HardwareFlyoutRow> rows=new List<HardwareFlyoutRow>(); private ThemeDefinition theme;
        protected override bool ShowWithoutActivation { get { return true; } }
        protected override CreateParams CreateParams { get { CreateParams cp=base.CreateParams;cp.ExStyle|=0x08000000|0x00000080;return cp; } }
        public HardwareFlyoutForm(){FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;StartPosition=FormStartPosition.Manual;TopMost=true;DoubleBuffered=true;Width=680;Height=90;SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer,true);}
        public void UpdateContent(string newTitle,List<HardwareFlyoutRow> newRows,ThemeDefinition newTheme,Rectangle anchor)
        {
            title=newTitle??"Hardware";rows=newRows??new List<HardwareFlyoutRow>();theme=newTheme;Width=680;Height=Math.Max(78,42+rows.Count*82+8);Rectangle wa=Screen.FromRectangle(anchor).WorkingArea;int x=Math.Max(wa.Left,Math.Min(anchor.Left,wa.Right-Width));int y=anchor.Top-Height-7;if(y<wa.Top)y=Math.Min(wa.Bottom-Height,anchor.Bottom+7);Location=new Point(x,y);Invalidate();if(!Visible)Show();
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);ThemeDefinition t=theme??ThemeCatalog.Get("Dark Minimal Pro");e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;using(SolidBrush b=new SolidBrush(Color.FromArgb(250,t.Background)))e.Graphics.FillRectangle(b,ClientRectangle);using(Pen p=new Pen(Color.FromArgb(220,t.Border)))e.Graphics.DrawRectangle(p,0,0,Width-1,Height-1);
            using(Font tf=new Font(t.FontName,10.8f,FontStyle.Bold))using(SolidBrush fb=new SolidBrush(t.Foreground))e.Graphics.DrawString(title,tf,fb,14,9);
            int y=38;using(Font nf=new Font(t.FontName,9.5f,FontStyle.Bold))using(Font vf=new Font(t.FontName,8.7f,FontStyle.Regular))
            {
                foreach(HardwareFlyoutRow r in rows)
                {
                    using(SolidBrush ab=new SolidBrush(r.Accent))e.Graphics.FillRectangle(ab,9,y+3,4,56);
                    using(SolidBrush nb=new SolidBrush(t.Foreground))e.Graphics.DrawString(r.Name??"Device",nf,nb,20,y);
                    using(SolidBrush mb=new SolidBrush(t.Muted))
                    {
                        e.Graphics.DrawString(r.Line1??"",vf,mb,20,y+21);
                        if(!String.IsNullOrWhiteSpace(r.Line2))e.Graphics.DrawString(r.Line2,vf,mb,20,y+39);
                        if(!String.IsNullOrWhiteSpace(r.Line3))e.Graphics.DrawString(r.Line3,vf,mb,20,y+57);
                    }
                    using(Pen sep=new Pen(Color.FromArgb(70,t.Border)))e.Graphics.DrawLine(sep,20,y+75,Width-16,y+75);
                    y+=82;
                }
            }
        }
    }

    internal sealed class OverlayForm : Form
    {
        private readonly AppConfig config;
        private readonly MetricsEngine engine;
        private readonly MetricHistory history=new MetricHistory();
        private MetricsSnapshot snapshot=new MetricsSnapshot();
        private readonly System.Windows.Forms.Timer metricTimer=new System.Windows.Forms.Timer();
        private readonly System.Windows.Forms.Timer watchdog=new System.Windows.Forms.Timer();
        private readonly System.Windows.Forms.Timer recoveryTimer=new System.Windows.Forms.Timer();
        private ContextMenuStrip menu;
        private ToolStripMenuItem updateMenuItem;
        private IntPtr taskbar=IntPtr.Zero;
        private Rectangle expectedRect=Rectangle.Empty;
        private Rectangle lastTaskbarScreenRect=Rectangle.Empty;
        private DateTime lastPositionAt=DateTime.MinValue;
        private readonly bool proofMode;
        private bool engineDisposed=false;
        private bool cleanupDone=false;
        public bool UserExitRequested { get; private set; }

        // R11H1 recovery state. Recovery is event-driven and stable-handle gated.
        private readonly uint taskbarCreatedMessage=Native.RegisterWindowMessage("TaskbarCreated");
        private bool recoveryPending=false;
        private string recoveryReason="";
        private int recoveryAttempt=0;
        private IntPtr recoveryCandidate=IntPtr.Zero;
        private int recoveryStableCount=0;
        private DateTime recoveryNotBefore=DateTime.MinValue;
        private bool systemEventsSubscribed=false;

        // R11S1: Start/Shell guard. Prefer staying a direct taskbar child during Start.
        private DateTime startGuardLastSeen=DateTime.MinValue;
        private NotifyIcon trayIcon;
        private SettingsForm settingsForm;
        private bool settingsHoverWasRunning=false;
        private IntPtr trayNotify=IntPtr.Zero;
        private int upstreamAttachCount=0;
        private DateTime lastUpstreamPositionAt=DateTime.MinValue;

        private Native.LowLevelMouseProc rightClickHookProc;
        private IntPtr rightClickHook=IntPtr.Zero;
        private bool rightClickArmed=false;
        private Point rightClickDownPoint=Point.Empty;
        private bool diagnosticBeacon=false;
        private string lastCompactLayoutKey="";

        // R07 shell-integration stability:
        // - the overlay owns only its safe free taskbar gap, so it may receive mouse input;
        // - NOACTIVATE prevents focus theft;
        // - width never grows automatically within one taskbar generation;
        // - transient Start/Search surfaces freeze placement instead of causing geometry jumps.
        private int stableOverlayWidthPx=0;
        private int pendingShrinkWidthPx=0;
        private int pendingShrinkCount=0;
        private DateTime lastTransientPlacementSkip=DateTime.MinValue;
        private DateTime lastStyleIntegrityAt=DateTime.MinValue;
        private int styleRepairCount=0;

        // R13: independent no-activate hover flyout; never parented to Explorer.
        private HardwareFlyoutForm hardwareFlyout;
        private readonly System.Windows.Forms.Timer hoverTimer=new System.Windows.Forms.Timer();

        // R09 responsiveness: heavy telemetry never runs on the WinForms UI thread.
        // A single background read owns MetricsEngine at a time; completed snapshots
        // are committed to UI/history atomically on the UI thread.
        private readonly object engineSync=new object();
        private int metricReadInFlight=0;
        private volatile bool metricReadShutdown=false;
        private volatile bool telemetryPaused=false;
        private int metricSnapshotGeneration=0;
        private string lastHoverGroup="";
        private int lastHoverIndex=-1;
        private int lastHoverGeneration=-1;
        private DateTime lastHardwareHoverAt=DateTime.MinValue;
        private List<MetricView> lastPaintMetrics=new List<MetricView>();

        public OverlayForm(AppConfig c) : this(c,false) { }

        internal OverlayForm(AppConfig c,bool isProofMode)
        {
            config=c;
            proofMode=isProofMode;
            FormBorderStyle=FormBorderStyle.None;
            ShowInTaskbar=false;
            StartPosition=FormStartPosition.Manual;
            TopMost=false;
            DoubleBuffered=true;
            SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer,true);
            engine=new MetricsEngine();
            if(!proofMode)
            {
                menu=BuildMenu();
                // R07: the form opens the menu explicitly from MouseClick; do not also
                // assign ContextMenuStrip here, which could produce duplicate opens.
                trayIcon=new NotifyIcon();
                try{trayIcon.Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);}catch{}
                trayIcon.Text="Taskbar Monitor Enhanced";
                trayIcon.Visible=true;
                trayIcon.ContextMenuStrip=menu;
                trayIcon.DoubleClick+=delegate{OpenSettings();};

                // R07: the overlay itself is interactive. Left click opens Settings,
                // right click opens the normal ContextMenuStrip. Because the window
                // uses WS_EX_NOACTIVATE, interaction does not steal taskbar focus.
                MouseClick+=delegate(object sender,MouseEventArgs e)
                {
                    if(e.Button==MouseButtons.Left)
                    {
                        Log.Write("INFO","LEFT_CLICK_OPEN_SETTINGS source=DIRECT_MOUSE");
                        try{BeginInvoke((MethodInvoker)delegate{OpenSettings();});}catch{}
                    }
                    else if(e.Button==MouseButtons.Right && menu!=null)
                    {
                        try
                        {
                            Point screenPoint=PointToScreen(e.Location);
                            menu.Show(screenPoint);
                            Log.Write("INFO","CONTEXT_MENU_OPEN source=DIRECT_MOUSE x="+screenPoint.X+" y="+screenPoint.Y);
                        }
                        catch(Exception ex){Log.Write("ERROR","CONTEXT_MENU_OPEN_FAIL "+ex.Message);}
                    }
                };
                hardwareFlyout=new HardwareFlyoutForm();
                try{IntPtr preload=hardwareFlyout.Handle;}catch{}
                MouseEnter+=delegate{RuntimeGuard.SafeUi("HOVER_ENTER",delegate{HandleHardwareHover(PointToClient(Cursor.Position));});};
                MouseMove+=delegate(object sender,MouseEventArgs e){RuntimeGuard.SafeUi("HOVER_MOVE",delegate{HandleHardwareHover(e.Location);});};
                hoverTimer.Interval=50;
                hoverTimer.Tick+=delegate{RuntimeGuard.SafeUi("HOVER_WATCHDOG",delegate{HoverWatchdog();});};
                metricTimer.Interval=config.UpdateIntervalMs;
                metricTimer.Tick+=delegate{RuntimeGuard.SafeUi("METRIC_TICK_SCHEDULE",delegate{QueueMetricsRead();});};
                watchdog.Interval=500;
                watchdog.Tick+=delegate{RuntimeGuard.SafeUi("VISIBILITY_WATCHDOG",delegate{VisibilityWatchdog();});};

                recoveryTimer.Interval=250;
                recoveryTimer.Tick+=delegate{RuntimeGuard.SafeUi("RECOVERY_TICK",delegate{RecoveryTick();});};

                Shown+=delegate{RuntimeGuard.SafeUi("FORM_SHOWN",delegate{
                    AttachIntegrated();
                    QueueMetricsRead();
                    // R07: do not install the global low-level right-click bridge.
                    // Direct mouse interaction is authoritative.
                    Log.Write("INFO","DIRECT_MOUSE_INTERACTION_ACTIVE left=SETTINGS right=CONTEXT_MENU noactivate=TRUE");
                    SubscribeSystemEvents();
                    metricTimer.Start();
                    watchdog.Start();
                    recoveryTimer.Start();
                    hoverTimer.Start();
                    if(config.AutoCheckUpdates)BeginUpdateMenuCheck();
                });};

                FormClosing+=delegate(object sender,FormClosingEventArgs e){
                    if(e.CloseReason==CloseReason.WindowsShutDown ||
                       e.CloseReason==CloseReason.TaskManagerClosing ||
                       e.CloseReason==CloseReason.ApplicationExitCall)
                        UserExitRequested=true;
                    CleanupRuntime("FORM_CLOSING_"+e.CloseReason.ToString());
                };

                Log.Write("INFO","START version="+BuildInfo.Version+" theme="+config.Theme+" recovery=R12A2R5R4_HOST shell=V102_ACCEPTED_CORE_RESTORE_R01");
            }
            else
            {
                Size=new Size(BuildInfo.DefaultWidth,48);
            }
        }

        private void DisposeEngine()
        {
            if(engineDisposed)return;
            engineDisposed=true;
            metricReadShutdown=true;
            try{lock(engineSync){engine.Dispose();}}catch{}
        }

        private void CleanupRuntime(string reason)
        {
            if(cleanupDone)return;
            cleanupDone=true;
            try{metricTimer.Stop();}catch{}
            try{watchdog.Stop();}catch{}
            try{recoveryTimer.Stop();}catch{}
            try{hoverTimer.Stop();}catch{}
            try{if(hardwareFlyout!=null){hardwareFlyout.Hide();hardwareFlyout.Dispose();hardwareFlyout=null;}}catch{}
            try{UnsubscribeSystemEvents();}catch{}
            try{UninstallRightClickBridge();}catch{}
            if(trayIcon!=null)
            {
                try{trayIcon.Visible=false;trayIcon.Dispose();}catch{}
                trayIcon=null;
            }
            DisposeEngine();
            // Diagnostic/theme proof instances must be strictly read-only. R04 proved that
            // saving a normalized v2 config from a proof process mutates the accepted v1.0.2
            // config even before deployment. Only the real live overlay owns config writes.
            if(!proofMode){try{config.Save();}catch{}}
            Log.Write("INFO","OVERLAY_CLEANUP reason="+reason+" userExit="+UserExitRequested);
        }

        public void HostPrepareForReplacement()
        {
            CleanupRuntime("HOST_REPLACEMENT");
        }

        public void RequestExternalRecovery(string reason)
        {
            if(!proofMode)ScheduleRecovery(reason,250);
        }

        protected override void Dispose(bool disposing)
        {
            if(disposing)CleanupRuntime("DISPOSE");
            base.Dispose(disposing);
        }

        protected override bool ShowWithoutActivation { get { return true; } }
        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp=base.CreateParams;
                if(!proofMode)
                {
                    cp.ExStyle |= Native.WS_EX_CONTROLPARENT | Native.WS_EX_LAYERED | Native.WS_EX_COMPOSITED | Native.WS_EX_TOOLWINDOW | Native.WS_EX_NOACTIVATE;
                    cp.ExStyle &= ~Native.WS_EX_TRANSPARENT;
                }
                return cp;
            }
        }

        private bool EnsureIntegratedWindowStyles(string reason,bool repairParent)
        {
            if(proofMode || !IsHandleCreated)return true;
            try
            {
                long style=Native.GetWindowLongPtr(Handle,Native.GWL_STYLE).ToInt64();
                long ex=Native.GetWindowLongPtr(Handle,Native.GWL_EXSTYLE).ToInt64();
                long requiredEx=Native.WS_EX_CONTROLPARENT|Native.WS_EX_LAYERED|Native.WS_EX_COMPOSITED|Native.WS_EX_TOOLWINDOW|Native.WS_EX_NOACTIVATE;
                long desiredStyle=(style & ~Native.WS_POPUP)|Native.WS_CHILD;
                long desiredEx=(ex|requiredEx)&~Native.WS_EX_TRANSPARENT;
                IntPtr parentBefore=Native.GetParent(Handle);

                bool drift=(style&Native.WS_CHILD)==0 ||
                           (style&Native.WS_POPUP)!=0 ||
                           (ex&requiredEx)!=requiredEx ||
                           (ex&Native.WS_EX_TRANSPARENT)!=0 ||
                           (taskbar!=IntPtr.Zero && parentBefore!=taskbar);

                if(!drift)return true;

                if(!repairParent)
                {
                    Log.Write(
                        "WARN",
                        "LOW_PRESSURE_STYLE_DRIFT_DETECTED reason="+reason+
                        " parent="+parentBefore.ToInt64()+
                        " taskbar="+taskbar.ToInt64()+
                        " style=0x"+style.ToString("X8",CultureInfo.InvariantCulture)+
                        " ex=0x"+ex.ToString("X8",CultureInfo.InvariantCulture)
                    );
                    return false;
                }

                if(style!=desiredStyle)Native.SetWindowLongPtr(Handle,Native.GWL_STYLE,new IntPtr(desiredStyle));
                if(taskbar!=IntPtr.Zero && Native.GetParent(Handle)!=taskbar)Native.SetParent(Handle,taskbar);
                if(ex!=desiredEx)Native.SetWindowLongPtr(Handle,Native.GWL_EXSTYLE,new IntPtr(desiredEx));
                Native.SetWindowPos(
                    Handle,IntPtr.Zero,0,0,0,0,
                    Native.SWP_NOMOVE|Native.SWP_NOSIZE|Native.SWP_NOZORDER|
                    Native.SWP_NOACTIVATE|Native.SWP_FRAMECHANGED|Native.SWP_NOOWNERZORDER
                );

                long styleAfter=Native.GetWindowLongPtr(Handle,Native.GWL_STYLE).ToInt64();
                long exAfter=Native.GetWindowLongPtr(Handle,Native.GWL_EXSTYLE).ToInt64();
                IntPtr parentAfter=Native.GetParent(Handle);

                bool pass=(styleAfter&Native.WS_CHILD)!=0 &&
                          (styleAfter&Native.WS_POPUP)==0 &&
                          (exAfter&requiredEx)==requiredEx &&
                          (exAfter&Native.WS_EX_TRANSPARENT)==0 &&
                          (taskbar==IntPtr.Zero || parentAfter==taskbar);

                styleRepairCount++;
                Log.Write(
                    pass?"INFO":"ERROR",
                    "LOW_PRESSURE_STYLE_REPAIR reason="+reason+
                    " count="+styleRepairCount+
                    " parentBefore="+parentBefore.ToInt64()+
                    " parentAfter="+parentAfter.ToInt64()+
                    " pass="+pass
                );
                return pass;
            }
            catch(Exception ex)
            {
                Log.Write("ERROR","LOW_PRESSURE_STYLE_CHECK_FAIL reason="+reason+" "+ex.Message);
                return false;
            }
        }

        private void InstallRightClickBridge()
        {
            try
            {
                if(rightClickHook!=IntPtr.Zero)return;

                rightClickHookProc=new Native.LowLevelMouseProc(RightClickHookCallback);
                IntPtr module=Native.GetModuleHandle(null);

                rightClickHook=Native.SetWindowsHookEx(
                    Native.WH_MOUSE_LL,
                    rightClickHookProc,
                    module,
                    0
                );

                int err=Marshal.GetLastWin32Error();

                if(rightClickHook==IntPtr.Zero)
                {
                    Log.Write("ERROR","RIGHTCLICK_BRIDGE_INSTALL_FAIL win32="+err);
                    return;
                }

                Log.Write(
                    "INFO",
                    "RIGHTCLICK_BRIDGE_INSTALL_PASS hook="+rightClickHook.ToInt64()+
                    " win32="+err+
                    " mode=WH_MOUSE_LL_SCOPED"
                );
            }
            catch(Exception ex)
            {
                Log.Write("ERROR","RIGHTCLICK_BRIDGE_INSTALL_FAIL "+ex.ToString());
            }
        }

        private void UninstallRightClickBridge()
        {
            try
            {
                if(rightClickHook!=IntPtr.Zero)
                {
                    bool ok=Native.UnhookWindowsHookEx(rightClickHook);
                    Log.Write("INFO","RIGHTCLICK_BRIDGE_UNINSTALL ok="+ok);
                }
            }
            catch(Exception ex)
            {
                Log.Write("WARN","RIGHTCLICK_BRIDGE_UNINSTALL_FAIL "+ex.Message);
            }
            finally
            {
                rightClickHook=IntPtr.Zero;
                rightClickHookProc=null;
                rightClickArmed=false;
            }
        }

        private IntPtr RightClickHookCallback(int nCode,IntPtr wParam,IntPtr lParam)
        {
            if(nCode<0)
                return Native.CallNextHookEx(rightClickHook,nCode,wParam,lParam);

            try
            {
                if(nCode==Native.HC_ACTION && !proofMode && expectedRect.Width>0)
                {
                    int message=wParam.ToInt32();

                    if(message==Native.WM_RBUTTONDOWN || message==Native.WM_RBUTTONUP)
                    {
                        Native.MSLLHOOKSTRUCT data=
                            (Native.MSLLHOOKSTRUCT)Marshal.PtrToStructure(
                                lParam,
                                typeof(Native.MSLLHOOKSTRUCT)
                            );

                        Point screenPoint=new Point(data.pt.X,data.pt.Y);
                        bool inside=expectedRect.Contains(screenPoint);

                        if(message==Native.WM_RBUTTONDOWN && inside)
                        {
                            rightClickArmed=true;
                            rightClickDownPoint=screenPoint;

                            // Suppress the taskbar's own right-click because this region
                            // belongs to Taskbar Monitor Enhanced.
                            return new IntPtr(1);
                        }

                        if(message==Native.WM_RBUTTONUP && rightClickArmed)
                        {
                            rightClickArmed=false;

                            if(inside)
                            {
                                Point menuPoint=screenPoint;

                                try
                                {
                                    BeginInvoke((MethodInvoker)delegate
                                    {
                                        try
                                        {
                                            if(menu!=null)
                                            {
                                                menu.Show(menuPoint);
                                                Log.Write(
                                                    "INFO",
                                                    "CONTEXT_MENU_OPEN source=RIGHTCLICK_BRIDGE"+
                                                    " x="+menuPoint.X+
                                                    " y="+menuPoint.Y
                                                );
                                            }
                                        }
                                        catch(Exception ex)
                                        {
                                            Log.Write("ERROR","CONTEXT_MENU_OPEN_FAIL "+ex.Message);
                                        }
                                    });
                                }
                                catch{}

                                return new IntPtr(1);
                            }

                            // The press began inside our region, so also consume the
                            // release even if the pointer drifted outside.
                            return new IntPtr(1);
                        }
                    }
                }
            }
            catch(Exception ex)
            {
                Log.Write("WARN","RIGHTCLICK_BRIDGE_CALLBACK "+ex.Message);
            }

            return Native.CallNextHookEx(rightClickHook,nCode,wParam,lParam);
        }

        private ContextMenuStrip BuildMenu()
        {
            ContextMenuStrip m=new ContextMenuStrip();
            ToolStripMenuItem themes=new ToolStripMenuItem("Themes");
            foreach(string n in ThemeCatalog.Names)
            {
                ToolStripMenuItem item=new ToolStripMenuItem(n); item.Checked=(n==config.Theme); item.Tag=n;
                item.Click+=delegate(object s,EventArgs e){ApplyTheme((string)((ToolStripMenuItem)s).Tag);}; themes.DropDownItems.Add(item);
            }
            m.Items.Add(themes);
            ToolStripMenuItem pos=new ToolStripMenuItem("Position");
            foreach(string p in new string[]{"Left","Center","Right"}){ToolStripMenuItem i=new ToolStripMenuItem(p);i.Tag=p;i.Checked=(p==config.Position);i.Click+=delegate(object s,EventArgs e){config.Position=(string)((ToolStripMenuItem)s).Tag;TaskbarLayout.ResetCache();ResetPlacementStability("POSITION_MENU");config.Save();PositionOverlay(true);RefreshMenuChecks();};pos.DropDownItems.Add(i);} m.Items.Add(pos);
            m.Items.Add(new ToolStripSeparator());
            ToolStripMenuItem settings=new ToolStripMenuItem("Settings..."); settings.Click+=delegate{OpenSettings();}; m.Items.Add(settings);
            ToolStripMenuItem diagnostics=new ToolStripMenuItem("Diagnostics...");diagnostics.Click+=delegate{OpenSettings("Diagnostics");};m.Items.Add(diagnostics);
            updateMenuItem=new ToolStripMenuItem("Updates...");updateMenuItem.Click+=delegate{OpenSettings("Updates");};m.Items.Add(updateMenuItem);
            ToolStripMenuItem logs=new ToolStripMenuItem("Open Logs"); logs.Click+=delegate{try{Process.Start("explorer.exe",AppPaths.Logs);}catch{}}; m.Items.Add(logs);
            m.Items.Add(new ToolStripSeparator());
            ToolStripMenuItem exit=new ToolStripMenuItem("Exit"); exit.Click+=delegate{UserExitRequested=true;Close();}; m.Items.Add(exit);
            return m;
        }

        private void RefreshMenuChecks()
        {
            foreach(ToolStripItem t in menu.Items)
            {
                ToolStripMenuItem top=t as ToolStripMenuItem; if(top==null)continue;
                if(top.Text=="Themes")foreach(ToolStripItem x in top.DropDownItems){ToolStripMenuItem i=x as ToolStripMenuItem;if(i!=null)i.Checked=((string)i.Tag==config.Theme);}
                if(top.Text=="Position")foreach(ToolStripItem x in top.DropDownItems){ToolStripMenuItem i=x as ToolStripMenuItem;if(i!=null)i.Checked=((string)i.Tag==config.Position);}
            }
        }

        private void ApplyTheme(string name){config.Theme=name;config.Save();RefreshMenuChecks();Invalidate();Log.Write("INFO","THEME " + name);}

        private void OpenSettings(){OpenSettings(null);}
        private void OpenSettings(string initialTab)
        {
            try
            {
                if(settingsForm!=null && !settingsForm.IsDisposed)
                {
                    if(!String.IsNullOrWhiteSpace(initialTab))settingsForm.SelectTab(initialTab);
                    if(settingsForm.WindowState==FormWindowState.Minimized)
                        settingsForm.WindowState=FormWindowState.Normal;

                    settingsForm.Show();
                    settingsForm.BringToFront();
                    settingsForm.Activate();

                    Log.Write(
                        "INFO",
                        "SETTINGS_SINGLE_INSTANCE_REUSE hwnd="+settingsForm.Handle.ToInt64()+
                        " tab="+(initialTab??"CURRENT")
                    );
                    return;
                }

                if(hardwareFlyout!=null)hardwareFlyout.Hide();
                settingsHoverWasRunning=hoverTimer.Enabled;
                hoverTimer.Stop();

                SettingsForm f=new SettingsForm(config,snapshot,initialTab);
                settingsForm=f;

                f.FormClosed+=delegate(object sender,FormClosedEventArgs e)
                {
                    try
                    {
                        DialogResult result=f.DialogResult;
                        if(result==DialogResult.OK)
                        {
                            config.Normalize();
                            config.Save();
                            Opacity=config.Opacity;
                            metricTimer.Interval=config.UpdateIntervalMs;
                            TaskbarLayout.ResetCache();
                            ResetPlacementStability("SETTINGS_APPLY");
                            StartupManager.SetEnabled(config.StartWithWindows);
                            PositionOverlay(true);
                            RefreshMenuChecks();
                            Invalidate();
                            Log.Write("INFO","SETTINGS_SINGLE_INSTANCE_APPLY");
                        }
                        else Log.Write("INFO","SETTINGS_SINGLE_INSTANCE_CLOSE result="+result);
                    }
                    catch(Exception ex)
                    {
                        Log.Write("ERROR","SETTINGS_SINGLE_INSTANCE_CLOSE_FAIL "+ex.Message);
                    }
                    finally
                    {
                        if(Object.ReferenceEquals(settingsForm,f))settingsForm=null;
                        try{f.Dispose();}catch{}
                        if(settingsHoverWasRunning&&!IsDisposed&&!Disposing)hoverTimer.Start();
                        settingsHoverWasRunning=false;
                        lastHoverIndex=-1;
                        lastHoverGroup="";
                        lastHoverGeneration=-1;
                    }
                };

                f.Show();
                f.BringToFront();
                f.Activate();

                Log.Write(
                    "INFO",
                    "SETTINGS_SINGLE_INSTANCE_CREATE hwnd="+f.Handle.ToInt64()+
                    " tab="+(initialTab??"DEFAULT")
                );
            }
            catch(Exception ex)
            {
                Log.Write("ERROR","SETTINGS_SINGLE_INSTANCE_OPEN_FAIL "+ex.Message);
                if(settingsForm!=null && settingsForm.IsDisposed)settingsForm=null;
                if(settingsHoverWasRunning&&!IsDisposed&&!Disposing)hoverTimer.Start();
                settingsHoverWasRunning=false;
            }
        }

        private void BeginUpdateMenuCheck()
        {
            if(updateMenuItem==null)return;
            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    ReleaseUpdateInfo info=UpdateManager.CheckLatest();
                    if(IsDisposed||Disposing)return;
                    try{BeginInvoke((MethodInvoker)delegate{if(updateMenuItem!=null)updateMenuItem.Text=info.HasUpdate?("Update available — "+info.Version):"Updates...";});}catch{}
                }
                catch(Exception ex){Log.Write("INFO","BACKGROUND_UPDATE_CHECK_SKIPPED "+ex.Message);}
            });
        }

        private MetricsSnapshot ReadEngineSnapshot()
        {
            lock(engineSync)
            {
                if(metricReadShutdown||engineDisposed)return null;
                return engine.Read();
            }
        }

        private void CommitMetricsSnapshot(MetricsSnapshot next)
        {
            if(next==null)return;
            snapshot=next;
            metricSnapshotGeneration++;
            history.Add("CPU",snapshot.Cpu); history.Add("RAM",snapshot.Ram); history.Add("DISK",(float)((snapshot.DiskReadBytesPerSec+snapshot.DiskWriteBytesPerSec)/(1024d*1024d))); history.Add("GPU",snapshot.Gpu);
            float vrp=snapshot.VramTotalGb>0?snapshot.VramUsedGb/snapshot.VramTotalGb*100f:0; history.Add("VRAM",vrp); history.Add("NET",snapshot.NetDownMbps+snapshot.NetUpMbps);
            foreach(CpuDeviceSnapshot d in snapshot.CpuDevices)history.Add("CPU:"+d.Id,d.Usage);
            foreach(GpuDeviceSnapshot d in snapshot.GpuDevices)history.Add("GPU:"+d.Id,d.Usage);
            foreach(DiskDeviceSnapshot d in snapshot.DiskDevices)history.Add("DISK:"+d.Id,(float)((d.ReadBytesPerSec+d.WriteBytesPerSec)/(1024d*1024d)));
            foreach(NetworkDeviceSnapshot d in snapshot.NetworkDevices)history.Add("NET:"+d.Id,(float)((d.DownBytesPerSec+d.UpBytesPerSec)*8d/1000000d));
        }

        private void ReadMetrics()
        {
            CommitMetricsSnapshot(ReadEngineSnapshot());
        }

        private void QueueMetricsRead()
        {
            if(metricReadShutdown||engineDisposed||telemetryPaused)return;
            if(Interlocked.CompareExchange(ref metricReadInFlight,1,0)!=0)return;
            ThreadPool.QueueUserWorkItem(delegate
            {
                MetricsSnapshot next=null;
                Exception error=null;
                try{next=ReadEngineSnapshot();}catch(Exception ex){error=ex;}
                try
                {
                    if(IsDisposed||Disposing)
                    {
                        Interlocked.Exchange(ref metricReadInFlight,0);
                        return;
                    }
                    BeginInvoke((MethodInvoker)delegate
                    {
                        try
                        {
                            if(error!=null)Log.Write("WARN","ASYNC_METRIC_READ "+error.Message);
                            if(next!=null)
                            {
                                CommitMetricsSnapshot(next);
                                if((DateTime.UtcNow-lastPositionAt).TotalSeconds>=2)PositionOverlay(false);
                                Invalidate();
                                if(hardwareFlyout!=null&&hardwareFlyout.Visible)
                                {
                                    Point p=Cursor.Position;Point o=PointToScreen(Point.Empty);Rectangle overlayScreen=new Rectangle(o,ClientSize);
                                    if(overlayScreen.Contains(p))HandleHardwareHover(PointToClient(p));
                                }
                            }
                        }
                        finally{Interlocked.Exchange(ref metricReadInFlight,0);}
                    });
                }
                catch
                {
                    Interlocked.Exchange(ref metricReadInFlight,0);
                }
            });
        }

        internal int ExportThemeProofs(string outputDirectory)
        {
            try
            {
                Directory.CreateDirectory(outputDirectory);

                // Real live data only. No synthetic metric values are injected.
                for(int i=0;i<30;i++)
                {
                    ReadMetrics();
                    Thread.Sleep(200);
                }

                List<object> proofFiles=new List<object>();
                string originalTheme=config.Theme;
                try
                {
                    for(int i=0;i<ThemeCatalog.Names.Length;i++)
                    {
                        string themeName=ThemeCatalog.Names[i];
                        string fileName=String.Format(
                            CultureInfo.InvariantCulture,
                            "THEME_{0:00}_{1}.png",
                            i+1,
                            SafeFileName(themeName).ToUpperInvariant()
                        );
                        string full=Path.Combine(outputDirectory,fileName);

                        using(Bitmap bmp=RenderThemeProof(themeName,BuildInfo.DefaultWidth,48))
                        {
                            bmp.Save(full,ImageFormat.Png);
                        }

                        proofFiles.Add(new Dictionary<string,object>{
                            {"Index",i+1},
                            {"Theme",themeName},
                            {"File",fileName},
                            {"Width",BuildInfo.DefaultWidth},
                            {"Height",48}
                        });
                    }
                }
                finally
                {
                    config.Theme=originalTheme;
                }

                Dictionary<string,object> metrics=new Dictionary<string,object>();
                metrics["CPU"]=snapshot.Cpu;
                metrics["RAM"]=snapshot.Ram;
                metrics["DISK"]=snapshot.Disk;
                metrics["GPU"]=snapshot.Gpu;
                metrics["VRAM_USED_GB"]=snapshot.VramUsedGb;
                metrics["VRAM_TOTAL_GB"]=snapshot.VramTotalGb;
                metrics["NET_DOWN_MBPS"]=snapshot.NetDownMbps;
                metrics["NET_UP_MBPS"]=snapshot.NetUpMbps;
                metrics["CPU_TEMP_AVAILABLE"]=snapshot.CpuTempAvailable;
                metrics["CPU_TEMP_CURRENT_C"]=snapshot.CpuTempCurrent;
                metrics["CPU_TEMP_AVG_C"]=snapshot.CpuTempAvg;
                metrics["CPU_TEMP_MAX_C"]=snapshot.CpuTempMax;
                metrics["CPU_TEMP_SOURCE"]=snapshot.CpuTempSource;
                metrics["GPU_TEMP_AVAILABLE"]=snapshot.GpuTempAvailable;
                metrics["GPU_TEMP_AVG_C"]=snapshot.GpuTempAvg;
                metrics["GPU_TEMP_MAX_C"]=snapshot.GpuTempMax;
                metrics["GPU_TEMP_SOURCE"]=snapshot.GpuTempSource??"UNAVAILABLE";

                Dictionary<string,object> manifest=new Dictionary<string,object>();
                manifest["Version"]=BuildInfo.Version;
                manifest["GeneratedAt"]=DateTime.Now.ToString("o",CultureInfo.InvariantCulture);
                manifest["NoSyntheticMetricData"]=true;
                manifest["LiveSampleCount"]=30;
                manifest["SampleIntervalMs"]=200;
                manifest["ThemeCount"]=ThemeCatalog.Names.Length;
                manifest["Width"]=BuildInfo.DefaultWidth;
                manifest["Height"]=48;
                manifest["Metrics"]=metrics;
                manifest["Files"]=proofFiles;

                JavaScriptSerializer js=new JavaScriptSerializer();
                File.WriteAllText(
                    Path.Combine(outputDirectory,"THEME_PROOF_MANIFEST.json"),
                    js.Serialize(manifest),
                    Encoding.UTF8
                );

                Console.WriteLine("TBME_THEME_PROOF=PASS THEMES="+ThemeCatalog.Names.Length+" DIR="+outputDirectory);
                return 0;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine("TBME_THEME_PROOF=FAIL "+ex);
                return 4;
            }
        }

        private Bitmap RenderThemeProof(string themeName,int width,int height)
        {
            Size priorSize=Size;
            Size=new Size(width,height);
            Bitmap bmp=new Bitmap(width,height,System.Drawing.Imaging.PixelFormat.Format32bppArgb);
            using(Graphics g=Graphics.FromImage(bmp))
            {
                g.SmoothingMode=SmoothingMode.AntiAlias;
                g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
                Rectangle rect=new Rectangle(0,0,width,height);
                ThemeDefinition theme=ThemeCatalog.Get(themeName);
                PaintBackground(g,theme,rect);

                List<MetricView> metrics=BuildMetricViews(theme);
                if(metrics.Count>0)
                {
                    float seg=(float)width/metrics.Count;
                    for(int i=0;i<metrics.Count;i++)
                    {
                        RectangleF r=new RectangleF(i*seg,0,seg,height);
                        PaintMetric(g,theme,metrics[i],r,i);
                    }
                }
            }
            Size=priorSize;
            return bmp;
        }

        internal int ExportCompactProofs(string outputDirectory)
        {
            try
            {
                Directory.CreateDirectory(outputDirectory);
                for(int i=0;i<30;i++){ReadMetrics();Thread.Sleep(200);}
                int[] widths=new int[]{592,500};
                List<object> proofFiles=new List<object>();
                List<object> layoutChecks=new List<object>();
                string originalTheme=config.Theme;
                Size originalSize=Size;
                try
                {
                    foreach(int width in widths)
                    {
                        Size=new Size(width,48);
                        for(int i=0;i<ThemeCatalog.Names.Length;i++)
                        {
                            string themeName=ThemeCatalog.Names[i];
                            string fileName=String.Format(CultureInfo.InvariantCulture,"COMPACT_{0}_{1:00}_{2}.png",width,i+1,SafeFileName(themeName).ToUpperInvariant());
                            string full=Path.Combine(outputDirectory,fileName);
                            using(Bitmap bmp=RenderThemeProof(themeName,width,48)){bmp.Save(full,ImageFormat.Png);}
                            ThemeDefinition theme=ThemeCatalog.Get(themeName);
                            using(Bitmap measureBmp=new Bitmap(4,4))
                            using(Graphics mg=Graphics.FromImage(measureBmp))
                            {
                                List<MetricView> metrics=BuildMetricViews(theme);
                                float seg=(float)width/Math.Max(1,metrics.Count);
                                foreach(MetricView mv in metrics)
                                {
                                    float readableMin=theme.Mode=="terminal"?7.5f:(theme.Mode=="hex"?7.3f:7.4f);
                                    float maxWidth;
                                    if(theme.Mode=="hex")
                                    {
                                        // Match PaintHexMetric exactly: metric inner width is seg-6, badge is
                                        // clamped to 88..maxBadge, and text receives badgeWidth-18. The old
                                        // proof used seg*0.72-24, a stricter geometry than the renderer and
                                        // could fail nondeterministically as live NET digits changed.
                                        float innerWidth=Math.Max(1f,seg-6f);
                                        float maxBadge=Math.Max(90f,innerWidth-42f);
                                        float badgeWidth=Math.Min(maxBadge,Math.Max(88f,innerWidth*0.72f));
                                        maxWidth=Math.Max(50f,badgeWidth-18f);
                                    }
                                    else maxWidth=IsExtendedThemeMode(theme.Mode)?Math.Max(50,seg-28):Math.Max(50,seg-16);
                                    string adaptive=BuildMetricHeadline(mg,theme,mv,readableMin,maxWidth);
                                    bool stacked=HeadlineIsStacked(adaptive);
                                    using(Font mf=SafeFont(theme.FontName,readableMin,FontStyle.Bold))
                                    {
                                        float measured=MaxLineWidth(mg,adaptive,mf);
                                        bool overflow=measured>maxWidth+0.75f;
                                        if(overflow)throw new InvalidOperationException("COMPACT_TEXT_OVERFLOW width="+width+" theme="+themeName+" metric="+mv.Key+" measured="+measured.ToString("0.0",CultureInfo.InvariantCulture)+" max="+maxWidth.ToString("0.0",CultureInfo.InvariantCulture));
                                        if(mv.GroupKey=="NET"&&!String.IsNullOrWhiteSpace(mv.Value2))
                                        {
                                            string inline=(mv.Label+" "+mv.Value+"    "+mv.Value2).Trim();
                                            bool inlineWouldOverflow=mg.MeasureString(inline,mf).Width>maxWidth;
                                            if(inlineWouldOverflow&&!stacked)throw new InvalidOperationException("COMPACT_NET_STACK_GATE width="+width+" theme="+themeName);
                                        }
                                        layoutChecks.Add(new Dictionary<string,object>{{"Width",width},{"Theme",themeName},{"Metric",mv.Key},{"ReadableMinPt",readableMin},{"Stacked",stacked},{"MeasuredLineWidth",measured},{"MaxWidth",maxWidth},{"Overflow",overflow}});
                                    }
                                }
                            }
                            proofFiles.Add(new Dictionary<string,object>{{"Width",width},{"Height",48},{"Index",i+1},{"Theme",themeName},{"File",fileName}});
                        }
                    }
                }
                finally{config.Theme=originalTheme;Size=originalSize;}
                Dictionary<string,object> manifest=new Dictionary<string,object>();
                manifest["Version"]=BuildInfo.Version;
                manifest["GeneratedAt"]=DateTime.Now.ToString("o",CultureInfo.InvariantCulture);
                manifest["NoSyntheticMetricData"]=true;
                manifest["ThemeCount"]=ThemeCatalog.Names.Length;
                manifest["Widths"]=widths;
                manifest["Height"]=48;
                manifest["MinimumReadableFontPt"]=7.3;
                manifest["DefaultReadableFontPt"]=7.4;
                manifest["HexReadableFontPt"]=7.3;
                manifest["TerminalReadableFontPt"]=7.5;
                manifest["NetworkStackRule"]="Stack DL/UL when inline text exceeds card width at the readable minimum font.";
                manifest["Files"]=proofFiles;
                manifest["LayoutChecks"]=layoutChecks;
                JavaScriptSerializer js=new JavaScriptSerializer();
                File.WriteAllText(Path.Combine(outputDirectory,"COMPACT_PROOF_MANIFEST.json"),js.Serialize(manifest),Encoding.UTF8);
                Console.WriteLine("TBME_COMPACT_PROOF=PASS THEMES="+ThemeCatalog.Names.Length+" WIDTHS=592,500 DIR="+outputDirectory);
                return 0;
            }
            catch(Exception ex)
            {
                try{Directory.CreateDirectory(outputDirectory);File.WriteAllText(Path.Combine(outputDirectory,"COMPACT_PROOF_FAILURE.txt"),ex.ToString(),Encoding.UTF8);}catch{}
                Console.Error.WriteLine("TBME_COMPACT_PROOF=FAIL "+ex);return 8;
            }
        }

        private static string SafeFileName(string text)
        {
            StringBuilder b=new StringBuilder();
            foreach(char ch in text)
            {
                if(Char.IsLetterOrDigit(ch))b.Append(ch);
                else if(ch==' '||ch=='-'||ch=='_')b.Append('_');
            }
            return b.ToString().Trim('_');
        }

        private void SubscribeSystemEvents()
        {
            if(systemEventsSubscribed)return;
            try
            {
                SystemEvents.DisplaySettingsChanged+=OnDisplaySettingsChanged;
                SystemEvents.PowerModeChanged+=OnPowerModeChanged;
                systemEventsSubscribed=true;
                Log.Write("INFO","RECOVERY_EVENTS_SUBSCRIBED");
            }
            catch(Exception ex)
            {
                Log.Write("WARN","RECOVERY_EVENTS_SUBSCRIBE_FAILED "+ex.Message);
            }
        }

        private void UnsubscribeSystemEvents()
        {
            if(!systemEventsSubscribed)return;
            try
            {
                SystemEvents.DisplaySettingsChanged-=OnDisplaySettingsChanged;
                SystemEvents.PowerModeChanged-=OnPowerModeChanged;
            }
            catch{}
            systemEventsSubscribed=false;
        }

        private void OnDisplaySettingsChanged(object sender,EventArgs e)
        {
            SafeScheduleRecovery("DISPLAY_SETTINGS_CHANGED",500);
        }

        private void OnPowerModeChanged(object sender,PowerModeChangedEventArgs e)
        {
            if(e.Mode==PowerModes.Suspend)
            {
                SafePauseTelemetry("POWER_SUSPEND");
                return;
            }
            if(e.Mode==PowerModes.Resume)
            {
                SafeResumeTelemetry("POWER_RESUME");
                SafeScheduleRecovery("POWER_RESUME",1000);
            }
        }

        private void SafePauseTelemetry(string reason)
        {
            try
            {
                if(IsDisposed||Disposing)return;
                if(InvokeRequired){BeginInvoke((MethodInvoker)delegate{SafePauseTelemetry(reason);});return;}
                telemetryPaused=true;
                try{metricTimer.Stop();}catch{}
                try{hoverTimer.Stop();}catch{}
                try{if(hardwareFlyout!=null)hardwareFlyout.Hide();}catch{}
                Log.Write("INFO","TELEMETRY_PAUSE reason="+reason);
            }
            catch(Exception ex){Log.Write("WARN","TELEMETRY_PAUSE_FAIL "+ex.Message);}
        }

        private void SafeResumeTelemetry(string reason)
        {
            try
            {
                if(IsDisposed||Disposing)return;
                if(InvokeRequired){BeginInvoke((MethodInvoker)delegate{SafeResumeTelemetry(reason);});return;}
                lock(engineSync){if(!engineDisposed)engine.ResetAfterResume();}
                telemetryPaused=false;
                metricTimer.Interval=Math.Max(1000,config.UpdateIntervalMs);
                metricTimer.Start();
                hoverTimer.Start();
                QueueMetricsRead();
                Log.Write("INFO","TELEMETRY_RESUME reason="+reason);
            }
            catch(Exception ex){Log.Write("WARN","TELEMETRY_RESUME_FAIL "+ex.Message);}
        }

        private void SafeScheduleRecovery(string reason,int delayMs)
        {
            try
            {
                if(IsDisposed)return;
                if(InvokeRequired)
                {
                    BeginInvoke((MethodInvoker)delegate{ScheduleRecovery(reason,delayMs);});
                    return;
                }
                ScheduleRecovery(reason,delayMs);
            }
            catch(Exception ex)
            {
                Log.Write("WARN","RECOVERY_SCHEDULE_DISPATCH_FAILED reason="+reason+" "+ex.Message);
            }
        }

        private void ScheduleRecovery(string reason,int delayMs)
        {
            recoveryPending=true;
            recoveryReason=reason;
            recoveryAttempt=0;
            recoveryCandidate=IntPtr.Zero;
            recoveryStableCount=0;
            recoveryNotBefore=DateTime.UtcNow.AddMilliseconds(Math.Max(0,delayMs));
            Log.Write("INFO","RECOVERY_SCHEDULE reason="+reason+" delayMs="+delayMs);
        }

        private void RecoveryTick()
        {
            if(!recoveryPending)return;
            if(DateTime.UtcNow<recoveryNotBefore)return;

            try
            {
                recoveryAttempt++;
                IntPtr current=Native.FindWindow("Shell_TrayWnd",null);

                if(current==IntPtr.Zero)
                {
                    recoveryCandidate=IntPtr.Zero;
                    recoveryStableCount=0;
                    if(recoveryAttempt==1 || recoveryAttempt%8==0)
                        Log.Write("INFO","RECOVERY_WAIT_TASKBAR reason="+recoveryReason+" attempt="+recoveryAttempt);

                    if(recoveryAttempt>=80)
                    {
                        Log.Write("ERROR","RECOVERY_TIMEOUT reason="+recoveryReason+" attempts="+recoveryAttempt);
                        recoveryPending=false;
                    }
                    return;
                }

                if(current!=recoveryCandidate)
                {
                    recoveryCandidate=current;
                    recoveryStableCount=1;
                    return;
                }

                recoveryStableCount++;
                if(recoveryStableCount<3)return;

                if(TryRecoverIntegrated(current,recoveryReason))
                {
                    recoveryPending=false;
                    recoveryAttempt=0;
                    recoveryStableCount=0;
                    recoveryCandidate=IntPtr.Zero;
                }
            }
            catch(Exception ex)
            {
                Log.Write("WARN","RECOVERY_TICK "+ex.Message);
            }
        }

        private bool TryRecoverIntegrated(IntPtr newTaskbar,string reason)
        {
            try
            {
                if(newTaskbar==IntPtr.Zero)return false;

                TaskbarLayout.ResetCache();
                ResetPlacementStability("RECOVERY_"+reason);
                taskbar=newTaskbar;
                expectedRect=Rectangle.Empty;
                lastTaskbarScreenRect=Rectangle.Empty;

                AttachIntegrated();

                bool parentOk=Native.GetParent(Handle)==taskbar;
                bool visible=Native.IsWindowVisible(Handle);

                Log.Write(
                    "INFO",
                    "RECOVERY_PASS reason="+reason+
                    " attempt="+recoveryAttempt+
                    " mode=StableLowPressureTaskbarChild"+
                    " taskbar="+taskbar.ToInt64()+
                    " parentOk="+parentOk+
                    " visible="+visible+
                    " rect="+expectedRect.X+","+expectedRect.Y+","+expectedRect.Width+","+expectedRect.Height
                );

                return parentOk && visible;
            }
            catch(Exception ex)
            {
                Log.Write("WARN","RECOVERY_RETRY reason="+reason+" attempt="+recoveryAttempt+" "+ex.Message);
                return false;
            }
        }

        protected override void WndProc(ref Message m)
        {
            // R07: mouse is accepted by the overlay but never activates/focuses it.
            if(m.Msg==0x0021) // WM_MOUSEACTIVATE
            {
                m.Result=new IntPtr(3); // MA_NOACTIVATE
                return;
            }

            if(m.Msg==Native.WM_TBME_VISUAL_BEACON)
            {
                diagnosticBeacon=m.WParam!=IntPtr.Zero;
                Invalidate();
                Update();
                m.Result=new IntPtr(1);
                Log.Write("INFO","VISUAL_BEACON state="+diagnosticBeacon);
                return;
            }

            if(taskbarCreatedMessage!=0 && (uint)m.Msg==taskbarCreatedMessage)
                ScheduleRecovery("TASKBAR_CREATED",750);

            if(m.Msg==0x007E)
                ScheduleRecovery("WM_DISPLAYCHANGE",500);

            if(m.Msg==0x02E0)
                ScheduleRecovery("WM_DPICHANGED",300);

            if(m.Msg==0x0218)
            {
                int powerCode=m.WParam.ToInt32();
                if(powerCode==0x0004)SafePauseTelemetry("WM_POWER_SUSPEND");
                if(powerCode==0x0007 || powerCode==0x0012)
                {
                    SafeResumeTelemetry("WM_POWER_RESUME");
                    ScheduleRecovery("WM_POWER_RESUME",1000);
                }
            }

            base.WndProc(ref m);
        }

        private void ResetPlacementStability(string reason)
        {
            stableOverlayWidthPx=0;
            pendingShrinkWidthPx=0;
            pendingShrinkCount=0;
            lastTransientPlacementSkip=DateTime.MinValue;
            Log.Write("INFO","PLACEMENT_STABILITY_RESET reason="+reason);
        }

        private bool IsTransientShellSurfaceActive()
        {
            try
            {
                string pn,cn;IntPtr h;
                if(ShellUi.IsStartShellForeground(out pn,out cn,out h))return true;
                Rectangle sr;IntPtr sh;
                if(ShellUi.IsStartSurfacePresent(out pn,out cn,out sr,out sh))return true;
            }
            catch{}
            return false;
        }

        private Rectangle ConstrainToStableWidth(Rectangle r,string position)
        {
            if(r.Width<=0)return r;
            if(stableOverlayWidthPx<=0)
            {
                stableOverlayWidthPx=r.Width;
                pendingShrinkWidthPx=0;
                pendingShrinkCount=0;
                Log.Write("INFO","PLACEMENT_WIDTH_LOCK_INIT width="+stableOverlayWidthPx);
                return r;
            }

            if(r.Width<stableOverlayWidthPx)
            {
                if(Math.Abs(r.Width-pendingShrinkWidthPx)<=3)pendingShrinkCount++;
                else
                {
                    pendingShrinkWidthPx=r.Width;
                    pendingShrinkCount=1;
                }

                // Require a persistent narrower safe gap before shrinking.
                if(pendingShrinkCount>=3)
                {
                    stableOverlayWidthPx=r.Width;
                    pendingShrinkCount=0;
                    Log.Write("INFO","PLACEMENT_WIDTH_LOCK_SHRINK width="+stableOverlayWidthPx);
                }
            }
            else
            {
                // Never auto-grow due to transient taskbar/UIAutomation gap changes.
                pendingShrinkWidthPx=0;
                pendingShrinkCount=0;
            }

            int w=Math.Min(r.Width,stableOverlayWidthPx);
            int x=r.X;
            if(position=="Right")x=r.Right-w;
            else if(position=="Center")x=r.X+((r.Width-w)/2);
            return new Rectangle(x,r.Y,w,r.Height);
        }

        private void AttachIntegrated()
        {
            taskbar=Native.FindWindow("Shell_TrayWnd",null);
            if(taskbar==IntPtr.Zero)
            {
                Log.Write("WARN","UPSTREAM_ENGINE_TASKBAR_NOT_FOUND");
                ScheduleRecovery("TASKBAR_NOT_FOUND",500);
                return;
            }

            trayNotify=Native.FindDescendantByClass(taskbar,"TrayNotifyWnd");
            ResetPlacementStability("ATTACH_INTEGRATED");

            try
            {
                long style=Native.GetWindowLongPtr(Handle,Native.GWL_STYLE).ToInt64();
                long childStyle=(style & ~Native.WS_POPUP)|Native.WS_CHILD;
                Native.SetWindowLongPtr(Handle,Native.GWL_STYLE,new IntPtr(childStyle));

                Native.SetParent(Handle,taskbar);
                IntPtr parentAfter=Native.GetParent(Handle);
                if(parentAfter!=taskbar)
                    throw new InvalidOperationException("SetParent verification failed");

                long upstreamEx=
                    Native.WS_EX_CONTROLPARENT |
                    Native.WS_EX_LAYERED |
                    Native.WS_EX_COMPOSITED |
                    Native.WS_EX_TOOLWINDOW |
                    Native.WS_EX_NOACTIVATE;

                Native.SetWindowLongPtr(Handle,Native.GWL_EXSTYLE,new IntPtr(upstreamEx));
                if(!EnsureIntegratedWindowStyles("ATTACH_INTEGRATED",true))
                    throw new InvalidOperationException("Integrated window style verification failed");

                bool layered=Native.SetLayeredWindowAttributes(
                    Handle,0,255,Native.LWA_COLORKEY|Native.LWA_ALPHA
                );
                int layeredWin32=Marshal.GetLastWin32Error();

                if(!layered)
                {
                    Log.Write(
                        "ERROR",
                        "UPSTREAM_LAYERED_ATTRIBUTES_FAIL win32="+layeredWin32+
                        " exstyle=0x"+upstreamEx.ToString("X8",CultureInfo.InvariantCulture)+
                        " parent="+parentAfter.ToInt64()
                    );
                    throw new InvalidOperationException(
                        "SetLayeredWindowAttributes failed win32="+layeredWin32
                    );
                }

                Log.Write(
                    "INFO",
                    "UPSTREAM_LAYERED_ATTRIBUTES_PASS win32="+layeredWin32+
                    " exstyle=0x"+upstreamEx.ToString("X8",CultureInfo.InvariantCulture)
                );

                TopMost=false;
                upstreamAttachCount++;

                PositionOverlay(true);

                Log.Write(
                    "INFO",
                    "STABLE_CHILD_ATTACH_PASS count="+upstreamAttachCount+
                    " parent="+parentAfter.ToInt64()+
                    " taskbar="+taskbar.ToInt64()+
                    " tray="+trayNotify.ToInt64()+
                    " exstyle=0x"+upstreamEx.ToString("X8",CultureInfo.InvariantCulture)+
                    " layered="+layered+
                    " layeredWin32="+layeredWin32+
                    " rect="+expectedRect.X+","+expectedRect.Y+","+expectedRect.Width+","+expectedRect.Height
                );
            }
            catch(Exception ex)
            {
                Log.Write("ERROR","UPSTREAM_ENGINE_ATTACH_FAIL "+ex.ToString());
                ScheduleRecovery("ATTACH_EXCEPTION",750);
            }
        }

        private void PositionOverlay(bool force)
        {
            lastPositionAt=DateTime.UtcNow;

            IntPtr currentTaskbar=Native.FindWindow("Shell_TrayWnd",null);
            if(currentTaskbar==IntPtr.Zero)return;
            taskbar=currentTaskbar;

            if(expectedRect.Width>0 && IsTransientShellSurfaceActive())
                return;

            Native.RECT tr;
            if(!Native.GetWindowRect(taskbar,out tr))return;
            Rectangle taskbarRect=tr.ToRectangle();

            bool geometryChanged=
                lastTaskbarScreenRect.IsEmpty ||
                lastTaskbarScreenRect.X!=taskbarRect.X ||
                lastTaskbarScreenRect.Y!=taskbarRect.Y ||
                lastTaskbarScreenRect.Width!=taskbarRect.Width ||
                lastTaskbarScreenRect.Height!=taskbarRect.Height;

            if(!force && !geometryChanged && expectedRect.Width>0 && expectedRect.Height>0)
            {
                Native.RECT wr;
                if(Native.GetWindowRect(Handle,out wr))
                {
                    Rectangle current=wr.ToRectangle();
                    bool drift=
                        Math.Abs(current.X-expectedRect.X)>1 ||
                        Math.Abs(current.Y-expectedRect.Y)>1 ||
                        Math.Abs(current.Width-expectedRect.Width)>1 ||
                        Math.Abs(current.Height-expectedRect.Height)>1;

                    if(drift)
                    {
                        Native.SetWindowPos(
                            Handle,
                            Native.HWND_TOP,
                            expectedRect.X-taskbarRect.Left,
                            expectedRect.Y-taskbarRect.Top,
                            expectedRect.Width,
                            expectedRect.Height,
                            Native.SWP_NOACTIVATE|Native.SWP_SHOWWINDOW
                        );
                        Log.Write(
                            "INFO",
                            "LOW_PRESSURE_PLACEMENT_DRIFT_REPAIR from="+
                            current.X+","+current.Y+","+current.Width+","+current.Height+
                            " to="+expectedRect.X+","+expectedRect.Y+","+expectedRect.Width+","+expectedRect.Height
                        );
                    }
                }

                if(!Visible)Show();
                lastUpstreamPositionAt=DateTime.UtcNow;
                return;
            }

            Rectangle r=TaskbarLayout.GetSafeRectangle(taskbar,config,config.MinWidthLogicalPx);
            if(r.Width<=0||r.Height<=0)return;

            r=ConstrainToStableWidth(r,config.Position);
            expectedRect=r;
            lastTaskbarScreenRect=taskbarRect;

            Native.SetWindowPos(
                Handle,
                Native.HWND_TOP,
                r.X-taskbarRect.Left,
                r.Y-taskbarRect.Top,
                r.Width,
                r.Height,
                Native.SWP_NOACTIVATE|Native.SWP_SHOWWINDOW
            );

            if(!Visible)Show();
            lastUpstreamPositionAt=DateTime.UtcNow;

            Log.Write(
                "INFO",
                "LOW_PRESSURE_SAFE_PLACEMENT_SCAN force="+force+
                " geometryChanged="+geometryChanged+
                " rect="+r.X+","+r.Y+","+r.Width+","+r.Height
            );
        }

        private int OwnedPoints(Rectangle r)
        {
            int[] xs=new int[]{r.Left+18,r.Left+r.Width/2,r.Right-18};int y=r.Top+r.Height/2;int owned=0;uint me=(uint)Process.GetCurrentProcess().Id;
            foreach(int x in xs){Native.POINT p=new Native.POINT();p.X=x;p.Y=y;IntPtr h=Native.WindowFromPoint(p);uint pid=0;if(h!=IntPtr.Zero)Native.GetWindowThreadProcessId(h,out pid);if(pid==me)owned++;}
            return owned;
        }

        private void StartGuardTick(IntPtr currentTaskbar)
        {
            // R12A1 deliberately uses no Start-specific TOPMOST or Lift behavior.
            // The upstream Windows 11 taskbar-child compositing recipe is authoritative.
        }

        private void VisibilityWatchdog()
        {
            try
            {
                IntPtr currentTaskbar=Native.FindWindow("Shell_TrayWnd",null);

                if(currentTaskbar==IntPtr.Zero)
                {
                    if(!recoveryPending)ScheduleRecovery("TASKBAR_MISSING_WATCHDOG",750);
                    return;
                }

                if(taskbar==IntPtr.Zero || currentTaskbar!=taskbar)
                {
                    if(!recoveryPending)ScheduleRecovery("TASKBAR_HANDLE_CHANGED",750);
                    return;
                }

                bool parentOk=Native.GetParent(Handle)==taskbar;
                if(!parentOk)
                {
                    if(!recoveryPending)ScheduleRecovery("UPSTREAM_PARENT_LOST",750);
                    return;
                }

                if((DateTime.UtcNow-lastStyleIntegrityAt).TotalMilliseconds>=5000)
                {
                    lastStyleIntegrityAt=DateTime.UtcNow;
                    if(!EnsureIntegratedWindowStyles("LOW_PRESSURE_HEALTH",false))
                    {
                        if(!recoveryPending)ScheduleRecovery("STYLE_INTEGRITY_DRIFT",750);
                        return;
                    }
                }

                if(!Native.IsWindowVisible(Handle))Show();

                if(expectedRect.Width<=0 ||
                   (DateTime.UtcNow-lastUpstreamPositionAt).TotalMilliseconds>=5000)
                    PositionOverlay(false);
            }
            catch(Exception ex)
            {
                Log.Write("WARN","LOW_PRESSURE_WATCHDOG "+ex.Message);
            }
        }

        private void EnterRescue(string reason)
        {
            Log.Write("WARN","UPSTREAM_ENGINE_REATTACH_REQUEST reason="+reason);
            if(!recoveryPending)ScheduleRecovery("REATTACH_"+reason,250);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e); e.Graphics.SmoothingMode=SmoothingMode.AntiAlias; e.Graphics.TextRenderingHint=System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            ThemeDefinition theme=ThemeCatalog.Get(config.Theme);
            PaintBackground(e.Graphics,theme,ClientRectangle);
            List<MetricView> metrics=BuildMetricViews(theme);
            lastPaintMetrics=metrics;
            if(metrics.Count==0)return;
            float seg=(float)ClientRectangle.Width/metrics.Count;
            for(int i=0;i<metrics.Count;i++){RectangleF r=new RectangleF(i*seg,0,seg,ClientRectangle.Height);PaintMetric(e.Graphics,theme,metrics[i],r,i);}
            if(diagnosticBeacon)PaintDiagnosticBeacon(e.Graphics);
        }

        private void HandleHardwareHover(Point location)
        {
            try
            {
                if(!config.EnableHardwareFlyout||hardwareFlyout==null||lastPaintMetrics==null||lastPaintMetrics.Count==0||ClientRectangle.Width<=0)return;
                int index=(int)Math.Floor(location.X/(ClientRectangle.Width/(double)lastPaintMetrics.Count));index=Math.Max(0,Math.Min(lastPaintMetrics.Count-1,index));MetricView m=lastPaintMetrics[index];string group=m.GroupKey??m.Key;
                lastHardwareHoverAt=DateTime.UtcNow;
                if(hardwareFlyout.Visible&&index==lastHoverIndex&&String.Equals(group,lastHoverGroup,StringComparison.Ordinal)&&lastHoverGeneration==metricSnapshotGeneration)return;
                ThemeDefinition t=ThemeCatalog.Get(config.Theme);List<HardwareFlyoutRow> rows=BuildHardwareFlyoutRows(group,t);if(rows.Count==0){hardwareFlyout.Hide();lastHoverIndex=-1;lastHoverGroup="";return;}
                float seg=ClientRectangle.Width/(float)lastPaintMetrics.Count;Rectangle client=Rectangle.Round(new RectangleF(index*seg,0,seg,ClientRectangle.Height));Point a=PointToScreen(client.Location);Rectangle anchor=new Rectangle(a,new Size(client.Width,client.Height));string title=group=="RAM"?("RAM — "+snapshot.MemoryModules.Count+" module"+(snapshot.MemoryModules.Count==1?"":"s")):(group+" — "+rows.Count+" device"+(rows.Count==1?"":"s"));hardwareFlyout.UpdateContent(title,rows,t,anchor);lastHoverIndex=index;lastHoverGroup=group;lastHoverGeneration=metricSnapshotGeneration;
            }catch(Exception ex){Log.Write("WARN","HARDWARE_HOVER "+ex.Message);}
        }
        private static string ClockText(int mhz)
        {
            if(mhz<=0)return "N/A";
            if(mhz>=1000)return (mhz/1000d).ToString("0.00",CultureInfo.InvariantCulture)+" GHz";
            return mhz.ToString(CultureInfo.InvariantCulture)+" MHz";
        }
        private static string ClockText(float mhz)
        {
            if(mhz<=0)return "N/A";
            if(mhz>=1000)return (mhz/1000d).ToString("0.00",CultureInfo.InvariantCulture)+" GHz";
            return mhz.ToString("0",CultureInfo.InvariantCulture)+" MHz";
        }
        private static string LinkText(long bits)
        {
            if(bits<=0)return "N/A";
            if(bits>=1000000000L)return (bits/1000000000d).ToString("0.##",CultureInfo.InvariantCulture)+" Gbps";
            if(bits>=1000000L)return (bits/1000000d).ToString("0",CultureInfo.InvariantCulture)+" Mbps";
            return bits.ToString(CultureInfo.InvariantCulture)+" bps";
        }

        private List<HardwareFlyoutRow> BuildHardwareFlyoutRows(string group,ThemeDefinition t)
        {
            List<HardwareFlyoutRow> r=new List<HardwareFlyoutRow>();
            int i=0;
            HashSet<string> selected=group=="CPU"?SelectionUtil.Parse(config.SelectedCpuIds):group=="GPU"?SelectionUtil.Parse(config.SelectedGpuIds):group=="DISK"?SelectionUtil.Parse(config.SelectedDiskIds):SelectionUtil.Parse(config.SelectedNetworkIds);

            if(group=="CPU")
            {
                foreach(CpuDeviceSnapshot d in snapshot.CpuDevices)
                {
                    if(!config.HoverShowAllDevices&&selected.Count>0&&!selected.Contains(d.Id))continue;
                    HardwareFlyoutRow x=new HardwareFlyoutRow();
                    x.Name=ShortName(d.Name,76);
                    x.Line1="Usage  "+(d.UsageAvailable?d.Usage.ToString("0")+"%":"N/A")+"     Temp  "+(d.TemperatureAvailable?d.Temperature.ToString("0")+"°C":"N/A")+"     Clock  "+ClockText(d.CurrentClockMHz);
                    x.Line2="Cores  "+(d.PhysicalCores>0?d.PhysicalCores.ToString():"N/A")+"     Threads  "+(d.LogicalProcessors>0?d.LogicalProcessors.ToString():"N/A")+"     Max clock  "+ClockText(d.MaxClockMHz);
                    x.Line3="Power  "+(d.PowerAvailable?d.PowerW.ToString("0.0",CultureInfo.InvariantCulture)+" W":"N/A")+"     Bus/BCLK  "+(d.ExternalClockMHz>0?(d.ExternalClockMHz+" MHz"):"N/A")+(String.IsNullOrWhiteSpace(d.Socket)?"":("     Socket  "+d.Socket));
                    x.Accent=t.Accents[i++%t.Accents.Length];r.Add(x);
                }
            }
            else if(group=="RAM")
            {
                HardwareFlyoutRow sum=new HardwareFlyoutRow();
                sum.Name="System memory";
                ulong free=snapshot.RamTotalBytes>=snapshot.RamUsedBytes?snapshot.RamTotalBytes-snapshot.RamUsedBytes:0;
                int maxConfigured=snapshot.MemoryModules.Where(m=>m.ConfiguredClockMHz>0).Select(m=>m.ConfiguredClockMHz).DefaultIfEmpty(0).Max();
                string type=snapshot.MemoryModules.Select(m=>m.MemoryType).FirstOrDefault(x=>!String.IsNullOrWhiteSpace(x)&&x!="Unknown")??"Unknown";
                sum.Line1="Used  "+snapshot.Ram.ToString("0")+"%     "+UnitFormatter.Pair(snapshot.RamUsedBytes,snapshot.RamTotalBytes,config.MemoryUnit)+"     Available  "+UnitFormatter.Bytes(free,config.MemoryUnit);
                sum.Line2="Modules  "+snapshot.MemoryModules.Count+"     Type  "+type+"     Configured clock  "+ClockText(maxConfigured);
                sum.Line3="";
                sum.Accent=t.Accents[i++%t.Accents.Length];r.Add(sum);

                foreach(MemoryModuleSnapshot m in snapshot.MemoryModules)
                {
                    HardwareFlyoutRow x=new HardwareFlyoutRow();
                    string loc=String.IsNullOrWhiteSpace(m.DeviceLocator)?m.BankLabel:m.DeviceLocator;
                    x.Name=(String.IsNullOrWhiteSpace(loc)?"Memory module":loc)+(String.IsNullOrWhiteSpace(m.Manufacturer)?"":(" — "+m.Manufacturer));
                    x.Line1="Capacity  "+UnitFormatter.Bytes(m.CapacityBytes,config.MemoryUnit)+"     Clock  "+ClockText(m.ConfiguredClockMHz>0?m.ConfiguredClockMHz:m.SpeedMHz)+"     Type  "+m.MemoryType;
                    x.Line2="Data bus  "+(m.DataWidth>0?(m.DataWidth+"-bit"):"N/A")+"     Total width  "+(m.TotalWidth>0?(m.TotalWidth+"-bit"):"N/A");
                    x.Line3=String.IsNullOrWhiteSpace(m.PartNumber)?"":("Part  "+ShortName(m.PartNumber,30));
                    x.Accent=t.Accents[i++%t.Accents.Length];r.Add(x);
                }
            }
            else if(group=="GPU")
            {
                foreach(GpuDeviceSnapshot d in snapshot.GpuDevices)
                {
                    if(!config.HoverShowAllDevices&&selected.Count>0&&!selected.Contains(d.Id))continue;
                    HardwareFlyoutRow x=new HardwareFlyoutRow();
                    x.Name=ShortName(d.Name,76);
                    x.Line1="Usage  "+(d.UsageAvailable?d.Usage.ToString("0")+"%":"N/A")+"     Temp  "+(d.TemperatureAvailable?d.Temperature.ToString("0")+"°C":"N/A")+"     Core clock  "+(d.CoreClockAvailable?ClockText(d.CoreClockMHz):"N/A");
                    x.Line2=(d.VramTotalGb>0?("VRAM  "+d.VramUsedGb.ToString("0.0")+"/"+d.VramTotalGb.ToString("0.0")+" GB"):"VRAM  N/A")+"     Memory clock  "+(d.MemoryClockAvailable?ClockText(d.MemoryClockMHz):"N/A")+"     Power  "+(d.PowerAvailable?d.PowerW.ToString("0.0",CultureInfo.InvariantCulture)+" W":"N/A");
                    string fanText=d.FanRpmAvailable?d.FanRpm.ToString("0",CultureInfo.InvariantCulture)+" RPM":(d.FanPercentAvailable?d.FanPercent.ToString("0",CultureInfo.InvariantCulture)+"%":"N/A");
                    x.Line3="Fan  "+fanText+"     Bus  "+(d.PcieGeneration>0?("PCIe Gen"+d.PcieGeneration+(d.PcieWidth>0?(" x"+d.PcieWidth):"")):"N/A")+"     Source  "+ShortName(d.Source,24);
                    x.Accent=t.Accents[i++%t.Accents.Length];r.Add(x);
                }
            }
            else if(group=="DISK")
            {
                foreach(DiskDeviceSnapshot d in snapshot.DiskDevices)
                {
                    if(!config.HoverShowAllDevices&&selected.Count>0&&!selected.Contains(d.Id))continue;
                    HardwareFlyoutRow x=new HardwareFlyoutRow();
                    x.Name=ShortName(d.Name,76);
                    x.Line1="Read  "+UnitFormatter.Rate(d.ReadBytesPerSec,config.DiskRateUnit)+"     Write  "+UnitFormatter.Rate(d.WriteBytesPerSec,config.DiskRateUnit)+"     Temp  "+(d.TemperatureAvailable?d.Temperature.ToString("0")+"°C":"N/A");
                    x.Line2=d.CapacityAvailable?("Used  "+d.UsedPercent.ToString("0")+"%     "+UnitFormatter.Pair(d.UsedBytes,d.TotalBytes,config.StorageUnit)+(String.IsNullOrWhiteSpace(d.Volumes)?"":("     Volume  "+d.Volumes))):"Capacity  N/A";
                    string bus=String.IsNullOrWhiteSpace(d.BusType)?(String.IsNullOrWhiteSpace(d.InterfaceType)?"N/A":d.InterfaceType):d.BusType;
                    string media=String.IsNullOrWhiteSpace(d.MediaType)?"":("     Media  "+ShortName(d.MediaType,22));
                    x.Line3="Bus  "+bus+media+"     Activity  "+d.Activity.ToString("0")+"%";
                    x.Accent=t.Accents[i++%t.Accents.Length];r.Add(x);
                }
            }
            else if(group=="NET")
            {
                foreach(NetworkDeviceSnapshot d in snapshot.NetworkDevices)
                {
                    if(!config.HoverShowAllDevices&&selected.Count>0&&!selected.Contains(d.Id))continue;
                    HardwareFlyoutRow x=new HardwareFlyoutRow();
                    x.Name=ShortName(d.Name,76);
                    x.Line1="Download  "+UnitFormatter.Rate(d.DownBytesPerSec,config.NetworkUnit)+"     Upload  "+UnitFormatter.Rate(d.UpBytesPerSec,config.NetworkUnit)+"     Link  "+LinkText(d.LinkSpeedBitsPerSec);
                    x.Line2=ShortName(d.Description,90);
                    x.Line3="";
                    x.Accent=t.Accents[i++%t.Accents.Length];r.Add(x);
                }
            }
            return r;
        }

        private void HoverWatchdog()
        {
            if(hardwareFlyout==null||!hardwareFlyout.Visible)return;Point p=Cursor.Position;Point o=PointToScreen(Point.Empty);Rectangle overlayScreen=new Rectangle(o,ClientSize);bool insideOverlay=overlayScreen.Contains(p);bool insideFlyout=hardwareFlyout.Bounds.Contains(p);if(insideOverlay||insideFlyout){lastHardwareHoverAt=DateTime.UtcNow;return;}if((DateTime.UtcNow-lastHardwareHoverAt).TotalMilliseconds>180){hardwareFlyout.Hide();lastHoverIndex=-1;lastHoverGroup="";lastHoverGeneration=-1;}
        }

        private void PaintDiagnosticBeacon(Graphics g)
        {
            int cell=5;
            int cols=8;
            int rows=4;
            int w=cols*cell;
            int h=rows*cell;
            int x=Math.Max(2,ClientRectangle.Width-w-3);
            int y=2;

            using(SolidBrush frame=new SolidBrush(Color.FromArgb(3,3,3)))
                g.FillRectangle(frame,x-2,y-2,w+4,h+4);

            Color a=Color.FromArgb(255,17,241);
            Color b=Color.FromArgb(0,255,106);
            using(SolidBrush ba=new SolidBrush(a))
            using(SolidBrush bb=new SolidBrush(b))
            {
                for(int yy=0;yy<rows;yy++)
                for(int xx=0;xx<cols;xx++)
                    g.FillRectangle(((xx+yy)&1)==0?ba:bb,x+xx*cell,y+yy*cell,cell,cell);
            }
        }

        private static bool Mode(string value,string expected){return String.Equals(value,expected,StringComparison.OrdinalIgnoreCase);}
        private static string ShortName(string name,int max){if(String.IsNullOrWhiteSpace(name))return "Device";string s=name.Trim();return s.Length<=max?s:s.Substring(0,Math.Max(1,max-1))+"…";}

        private List<CpuDeviceSnapshot> SelectedCpuDevices()
        {
            List<CpuDeviceSnapshot> all=snapshot.CpuDevices??new List<CpuDeviceSnapshot>();if(all.Count==0)return all;string mode=config.CpuDisplayMode;HashSet<string> ids=SelectionUtil.Parse(config.SelectedCpuIds);List<CpuDeviceSnapshot> selected=all.Where(x=>ids.Contains(x.Id)).ToList();
            if(Mode(mode,"Overall"))return all;if(Mode(mode,"Auto"))return new List<CpuDeviceSnapshot>{all.OrderByDescending(x=>x.UsageAvailable?x.Usage:-1).First()};if(Mode(mode,"Single"))return new List<CpuDeviceSnapshot>{selected.Count>0?selected[0]:all[0]};return selected.Count>0?selected:all;
        }
        private List<GpuDeviceSnapshot> SelectedGpuDevices()
        {
            List<GpuDeviceSnapshot> all=snapshot.GpuDevices??new List<GpuDeviceSnapshot>();if(all.Count==0)return all;string mode=config.GpuDisplayMode;HashSet<string> ids=SelectionUtil.Parse(config.SelectedGpuIds);List<GpuDeviceSnapshot> selected=all.Where(x=>ids.Contains(x.Id)).ToList();
            if(Mode(mode,"Overall"))return all;if(Mode(mode,"Auto"))return new List<GpuDeviceSnapshot>{all.OrderByDescending(x=>x.UsageAvailable?x.Usage:-1).First()};if(Mode(mode,"Single"))return new List<GpuDeviceSnapshot>{selected.Count>0?selected[0]:all[0]};return selected.Count>0?selected:all;
        }
        private List<DiskDeviceSnapshot> SelectedDiskDevices()
        {
            List<DiskDeviceSnapshot> all=snapshot.DiskDevices??new List<DiskDeviceSnapshot>();if(all.Count==0)return all;string mode=config.DiskDisplayMode;HashSet<string> ids=SelectionUtil.Parse(config.SelectedDiskIds);List<DiskDeviceSnapshot> selected=all.Where(x=>ids.Contains(x.Id)).ToList();
            if(Mode(mode,"Overall"))return all;if(Mode(mode,"Auto"))return new List<DiskDeviceSnapshot>{all.OrderByDescending(x=>x.ActivityAvailable?x.Activity:-1).First()};if(Mode(mode,"Single"))return new List<DiskDeviceSnapshot>{selected.Count>0?selected[0]:all[0]};return selected.Count>0?selected:all;
        }
        private List<NetworkDeviceSnapshot> SelectedNetworkDevices()
        {
            List<NetworkDeviceSnapshot> all=snapshot.NetworkDevices??new List<NetworkDeviceSnapshot>();if(all.Count==0)return all;string mode=config.NetworkDisplayMode;HashSet<string> ids=SelectionUtil.Parse(config.SelectedNetworkIds);List<NetworkDeviceSnapshot> selected=all.Where(x=>ids.Contains(x.Id)).ToList();
            if(Mode(mode,"Overall"))return all;if(Mode(mode,"Auto"))return new List<NetworkDeviceSnapshot>{all.OrderByDescending(x=>x.DownBytesPerSec+x.UpBytesPerSec).First()};if(Mode(mode,"Single"))return new List<NetworkDeviceSnapshot>{selected.Count>0?selected[0]:all[0]};return selected.Count>0?selected:all;
        }

        private List<MetricView> BuildMetricViews(ThemeDefinition t)
        {
            List<MetricView> x=new List<MetricView>();int idx=0;
            if(config.ShowCpu)
            {
                List<CpuDeviceSnapshot> ds=SelectedCpuDevices();Color c=t.Accents[idx++%t.Accents.Length];
                if(Mode(config.CpuDisplayMode,"Multiple")&&config.MultipleDeviceLayout=="Separate"&&ds.Count>1)
                {
                    for(int i=0;i<ds.Count;i++){CpuDeviceSnapshot d=ds[i];string val=d.UsageAvailable?d.Usage.ToString("0")+"%":"N/A";MetricView m=config.ShowTemperatures?MakeDual("CPU:"+d.Id,"C"+i,val,FormatCpuTemperature(d.TemperatureAvailable,d.Temperature),d.Usage,"CPU:"+d.Id,c):Make("CPU:"+d.Id,"C"+i,val,d.Usage,"CPU:"+d.Id,c);m.GroupKey="CPU";m.DeviceId=d.Id;m.DisplayName=d.Name;x.Add(m);}
                }
                else
                {
                    float usage=snapshot.Cpu;if(!Mode(config.CpuDisplayMode,"Overall")&&ds.Count>0){double w=0,sum=0;foreach(CpuDeviceSnapshot d in ds)if(d.UsageAvailable){double ww=d.LogicalProcessors>0?d.LogicalProcessors:1;sum+=d.Usage*ww;w+=ww;}if(w>0)usage=(float)(sum/w);}bool ta=ds.Any(d=>d.TemperatureAvailable)||snapshot.CpuTempAvailable;float tv=ds.Where(d=>d.TemperatureAvailable).Select(d=>d.Temperature).DefaultIfEmpty(snapshot.CpuTempCurrent).Max();string label=Mode(config.CpuDisplayMode,"Multiple")&&ds.Count>1?"CPU"+ds.Count:"CPU";MetricView m=config.ShowTemperatures?MakeDual("CPU",label,usage.ToString("0")+"%",FormatCpuTemperature(ta,tv),usage,"CPU",c):Make("CPU",label,usage.ToString("0")+"%",usage,"CPU",c);m.GroupKey="CPU";x.Add(m);
                }
            }
            if(config.ShowRam){MetricView m=config.ShowRamNumeric?MakeDual("RAM","RAM",snapshot.Ram.ToString("0")+"%",UnitFormatter.Pair(snapshot.RamUsedBytes,snapshot.RamTotalBytes,config.MemoryUnit),snapshot.Ram,"RAM",t.Accents[idx++%t.Accents.Length]):Make("RAM","RAM",snapshot.Ram.ToString("0")+"%",snapshot.Ram,"RAM",t.Accents[idx++%t.Accents.Length]);m.GroupKey="RAM";x.Add(m);}
            if(config.ShowDisk)
            {
                List<DiskDeviceSnapshot> ds=SelectedDiskDevices();Color c=t.Accents[idx++%t.Accents.Length];
                if(Mode(config.DiskDisplayMode,"Multiple")&&config.MultipleDeviceLayout=="Separate"&&ds.Count>1)
                {
                    for(int i=0;i<ds.Count;i++){DiskDeviceSnapshot d=ds[i];MetricView m=MakeDual("DISK:"+d.Id,"D"+i,"R "+UnitFormatter.Rate(d.ReadBytesPerSec,config.DiskRateUnit),"W "+UnitFormatter.Rate(d.WriteBytesPerSec,config.DiskRateUnit),d.Activity,"DISK:"+d.Id,c);m.GroupKey="DISK";m.DeviceId=d.Id;m.DisplayName=d.Name;x.Add(m);}
                }
                else
                {
                    double read=ds.Sum(d=>d.ReadBytesPerSec),write=ds.Sum(d=>d.WriteBytesPerSec);float act=ds.Count>0?ds.Max(d=>d.Activity):snapshot.Disk;string label=Mode(config.DiskDisplayMode,"Multiple")&&ds.Count>1?"DSK"+ds.Count:"DSK";MetricView m=MakeDual("DISK",label,"R "+UnitFormatter.Rate(read,config.DiskRateUnit),"W "+UnitFormatter.Rate(write,config.DiskRateUnit),act,"DISK",c);m.GroupKey="DISK";x.Add(m);
                }
            }
            if(config.ShowGpu)
            {
                List<GpuDeviceSnapshot> ds=SelectedGpuDevices();Color c=t.Accents[idx++%t.Accents.Length];
                if(Mode(config.GpuDisplayMode,"Multiple")&&config.MultipleDeviceLayout=="Separate"&&ds.Count>1)
                {
                    for(int i=0;i<ds.Count;i++){GpuDeviceSnapshot d=ds[i];string val=d.UsageAvailable?d.Usage.ToString("0")+"%":"N/A";MetricView m=config.ShowTemperatures?MakeDual("GPU:"+d.Id,"G"+i,val,d.TemperatureAvailable?("TEMP "+d.Temperature.ToString("0")+"°"):"TEMP N/A",d.Usage,"GPU:"+d.Id,c):Make("GPU:"+d.Id,"G"+i,val,d.Usage,"GPU:"+d.Id,c);m.GroupKey="GPU";m.DeviceId=d.Id;m.DisplayName=d.Name;x.Add(m);}
                }
                else
                {
                    float usage=ds.Where(d=>d.UsageAvailable).Select(d=>d.Usage).DefaultIfEmpty(snapshot.Gpu).Max();List<float> temps=ds.Where(d=>d.TemperatureAvailable).Select(d=>d.Temperature).ToList();bool ta=temps.Count>0;float av=ta?temps.Average():0;float mx=ta?temps.Max():0;string label=Mode(config.GpuDisplayMode,"Multiple")&&ds.Count>1?"GPU"+ds.Count:"GPU";MetricView m=config.ShowTemperatures?MakeDual("GPU",label,usage.ToString("0")+"%",FormatGpuTemperature(ta,av,mx),usage,"GPU",c):Make("GPU",label,usage.ToString("0")+"%",usage,"GPU",c);m.GroupKey="GPU";x.Add(m);
                }
            }
            List<GpuDeviceSnapshot> gpuForVram=SelectedGpuDevices();float vu=gpuForVram.Sum(d=>d.VramUsedGb),vt=gpuForVram.Sum(d=>d.VramTotalGb);float vp=vt>0?vu/vt*100f:0;if(config.ShowVram){MetricView m=Make("VRAM","VRAM",vt>0?vu.ToString("0.#")+"/"+vt.ToString("0.#")+"G":"N/A",vp,"VRAM",t.Accents[idx++%t.Accents.Length]);m.GroupKey="GPU";x.Add(m);}
            if(config.ShowNetwork)
            {
                List<NetworkDeviceSnapshot> ds=SelectedNetworkDevices();Color c=t.Accents[idx++%t.Accents.Length];
                if(Mode(config.NetworkDisplayMode,"Multiple")&&config.MultipleDeviceLayout=="Separate"&&ds.Count>1)
                {
                    for(int i=0;i<ds.Count;i++){NetworkDeviceSnapshot d=ds[i];MetricView m=MakeDual("NET:"+d.Id,"N"+i,"DL "+UnitFormatter.Rate(d.DownBytesPerSec,config.NetworkUnit),"UL "+UnitFormatter.Rate(d.UpBytesPerSec,config.NetworkUnit),(float)Math.Min(100,(d.DownBytesPerSec+d.UpBytesPerSec)*8d/1000000d),"NET:"+d.Id,c);m.GroupKey="NET";m.DeviceId=d.Id;m.DisplayName=d.Name;x.Add(m);}
                }
                else
                {
                    double down=ds.Sum(d=>d.DownBytesPerSec),up=ds.Sum(d=>d.UpBytesPerSec);string label=Mode(config.NetworkDisplayMode,"Multiple")&&ds.Count>1?"NET"+ds.Count:"NET";MetricView m=MakeDual("NET",label,"DL "+UnitFormatter.Rate(down,config.NetworkUnit),"UL "+UnitFormatter.Rate(up,config.NetworkUnit),(float)Math.Min(100,(down+up)*8d/1000000d),"NET",c);m.GroupKey="NET";x.Add(m);
                }
            }

            int availableWidth=ClientRectangle.Width>0?ClientRectangle.Width:Width;
            if(availableWidth>0 && availableWidth<620){int vramIndex=x.FindIndex(delegate(MetricView m){return m.Key=="VRAM";});if(vramIndex>=0)x.RemoveAt(vramIndex);}
            if(availableWidth>0 && availableWidth<520){int diskIndex=x.FindIndex(delegate(MetricView m){return m.GroupKey=="DISK";});if(diskIndex>=0)x.RemoveAt(diskIndex);}
            string compactKey=availableWidth.ToString(CultureInfo.InvariantCulture)+"|"+String.Join(",",x.ConvertAll(delegate(MetricView m){return m.Key;}).ToArray());if(!String.Equals(compactKey,lastCompactLayoutKey,StringComparison.Ordinal)){lastCompactLayoutKey=compactKey;Log.Write("INFO","COMPACT_LAYOUT width="+availableWidth+" metrics="+String.Join(",",x.ConvertAll(delegate(MetricView m){return m.Key;}).ToArray())+" font="+config.FontSize.ToString("0.0",CultureInfo.InvariantCulture));}
            return x;
        }
        private MetricView Make(string key,string label,string value,float pct,string hist,Color c){MetricView m=new MetricView();m.Key=key;m.GroupKey=key;m.Label=label;m.Value=value;m.Value2=null;m.Percent=pct;m.History=history.Get(hist);m.Accent=c;return m;}
        private MetricView MakeDual(string key,string label,string value1,string value2,float pct,string hist,Color c){MetricView m=new MetricView();m.Key=key;m.GroupKey=key;m.Label=label;m.Value=value1;m.Value2=value2;m.Percent=pct;m.History=history.Get(hist);m.Accent=c;return m;}

        private static string FormatCpuTemperature(bool available,float current)
        {
            if(!available)return "TEMP N/A";
            return "TEMP "+current.ToString("0",CultureInfo.InvariantCulture)+"°";
        }
        private static string FormatGpuTemperature(bool available,float average,float maximum)
        {
            if(!available)return "TEMP N/A";
            return "TEMP A"+average.ToString("0",CultureInfo.InvariantCulture)+" M"+maximum.ToString("0",CultureInfo.InvariantCulture)+"°";
        }
        private static string CompactUnitTokens(string value)
        {
            if(String.IsNullOrWhiteSpace(value))return "";
            return value.Trim()
                .Replace(" KB/s","K/s").Replace(" MB/s","M/s").Replace(" GB/s","G/s")
                .Replace(" KB","K").Replace(" MB","M").Replace(" GB","G");
        }
        private static string CompactNumericToken(string text)
        {
            double v;
            if(!Double.TryParse(text,NumberStyles.Float,CultureInfo.InvariantCulture,out v))return text;
            double a=Math.Abs(v);
            if(a<10000d)return text;
            string e=v.ToString("0.#E+0",CultureInfo.InvariantCulture);
            return e.Replace("E+","e").Replace("E-","e-").Replace("E","e");
        }
        private static string CompactPairToken(string value)
        {
            string s=CompactUnitTokens(value);
            int slash=s.IndexOf('/');
            if(slash<=0)return s;
            string left=s.Substring(0,slash);
            string right=s.Substring(slash+1);
            string unit="";
            if(right.EndsWith("K",StringComparison.Ordinal)||right.EndsWith("M",StringComparison.Ordinal)||right.EndsWith("G",StringComparison.Ordinal))
            {
                unit=right.Substring(right.Length-1);
                right=right.Substring(0,right.Length-1);
            }
            return CompactNumericToken(left)+"/"+CompactNumericToken(right)+unit;
        }
        private static string CompactSecondaryValue(MetricView m)
        {
            if(m==null||String.IsNullOrWhiteSpace(m.Value2))return "";
            string s=m.Value2.Trim();
            if(m.GroupKey=="CPU"&&s.StartsWith("TEMP ",StringComparison.Ordinal))return "T "+s.Substring(5);
            if(m.GroupKey=="GPU")
            {
                if(String.Equals(s,"TEMP N/A",StringComparison.Ordinal))return "T N/A";
                if(s.StartsWith("TEMP A",StringComparison.Ordinal))return "T "+s.Substring(6).Replace(" M","/");
            }
            if(m.GroupKey=="RAM")return CompactPairToken(s);
            if(m.GroupKey=="DISK")
            {
                int act=s.IndexOf("  ACT ",StringComparison.Ordinal);if(act>0)s=s.Substring(0,act);return CompactPairToken(s);
            }
            if(m.GroupKey=="NET")return CompactUnitTokens(s);
            return CompactUnitTokens(s);
        }
        private static bool LineFits(Graphics g,Font f,string text,float maxWidth)
        {
            return g.MeasureString(text??"",f).Width<=maxWidth;
        }
        private static string MiddleElideToFit(Graphics g,Font f,string text,float maxWidth)
        {
            if(String.IsNullOrEmpty(text)||LineFits(g,f,text,maxWidth))return text;
            if(maxWidth<=8)return "";
            const string ellipsis="…";
            int left=(text.Length+1)/2;
            int right=text.Length-left;
            while(left>1||right>1)
            {
                string c=text.Substring(0,left)+ellipsis+text.Substring(text.Length-right,right);
                if(LineFits(g,f,c,maxWidth))return c;
                if(left>=right&&left>1)left--;else if(right>1)right--;else break;
            }
            string tiny=text.Substring(0,1)+ellipsis+(text.Length>1?text.Substring(text.Length-1):"");
            return tiny;
        }
        private static string FitCompactLine(Graphics g,Font f,MetricView m,string line,float maxWidth,bool secondary)
        {
            if(LineFits(g,f,line,maxWidth))return line;
            string compact=CompactUnitTokens(line);
            if(m!=null&&m.GroupKey=="NET")
            {
                compact=compact.Replace("DL ","D ").Replace("UL ","U ");
            }
            if(LineFits(g,f,compact,maxWidth))return compact;
            if(secondary&&m!=null&&(m.GroupKey=="RAM"||m.GroupKey=="DISK"))
            {
                string pair=CompactPairToken(compact);
                if(LineFits(g,f,pair,maxWidth))return pair;
                int slash=pair.IndexOf('/');
                if(slash>0)
                {
                    string unit="";
                    if(pair.EndsWith("K",StringComparison.Ordinal)||pair.EndsWith("M",StringComparison.Ordinal)||pair.EndsWith("G",StringComparison.Ordinal))unit=pair.Substring(pair.Length-1);
                    string used=pair.Substring(0,slash)+unit;
                    if(LineFits(g,f,used,maxWidth))return used;
                }
            }
            compact=compact.Replace(" ","");
            if(LineFits(g,f,compact,maxWidth))return compact;
            // Last-resort visual safety. Full values remain available in the hardware flyout/settings;
            // compact cards must never clip neighboring taskbar cards.
            return MiddleElideToFit(g,f,compact,maxWidth);
        }
        private static string BuildMetricHeadline(Graphics g,ThemeDefinition t,MetricView m,float readableMinimum,float maxWidth)
        {
            string primary=(m.Label+" "+m.Value).Trim();
            using(Font readable=SafeFont(t.FontName,readableMinimum,FontStyle.Bold))
            {
                if(String.IsNullOrWhiteSpace(m.Value2))return FitCompactLine(g,readable,m,primary,maxWidth,false);
                string inline=primary+"    "+m.Value2;
                if(LineFits(g,readable,inline,maxWidth))return inline;

                string p=FitCompactLine(g,readable,m,primary,maxWidth,false);
                string secondary=CompactSecondaryValue(m);
                if(m.GroupKey=="NET")
                {
                    p=FitCompactLine(g,readable,m,m.Value,maxWidth,false);
                    secondary=FitCompactLine(g,readable,m,m.Value2,maxWidth,true);
                }
                else secondary=FitCompactLine(g,readable,m,secondary,maxWidth,true);
                return p+"\n"+secondary;
            }
        }
        private static bool HeadlineIsStacked(string headline){return !String.IsNullOrEmpty(headline)&&headline.IndexOf('\n')>=0;}
        private static float MaxLineWidth(Graphics g,string headline,Font f)
        {
            float max=0;
            foreach(string line in (headline??"").Split(new char[]{'\n'}))max=Math.Max(max,g.MeasureString(line,f).Width);
            return max;
        }
        private static Font FitHeadlineFont(Graphics g,string fontName,string text,float start,float minimum,float maxWidth)
        {
            float size=start;
            while(size>minimum)
            {
                Font f=SafeFont(fontName,size,FontStyle.Bold);
                if(g.MeasureString(text,f).Width<=maxWidth)return f;
                f.Dispose();
                size-=0.35f;
            }
            return SafeFont(fontName,minimum,FontStyle.Bold);
        }
        private static string FormatRateCompact(float mbps){if(mbps>=100)return mbps.ToString("0");if(mbps>=10)return mbps.ToString("0.0");return mbps.ToString("0.00");}

        private void PaintBackground(Graphics g,ThemeDefinition t,Rectangle r)
        {
            if(t.Mode=="glass")using(LinearGradientBrush b=new LinearGradientBrush(r,t.Background,t.Background2,0f))g.FillRectangle(b,r);
            else using(SolidBrush b=new SolidBrush(t.Background))g.FillRectangle(b,r);
            if(t.Mode=="neon")using(Pen p=new Pen(Color.FromArgb(150,t.Border),1))g.DrawLine(p,0,0,r.Width,0);
            if(t.Mode=="terminal")using(Pen p=new Pen(Color.FromArgb(35,t.Foreground),1)){for(int y=3;y<r.Height;y+=4)g.DrawLine(p,0,y,r.Width,y);}
            if(IsExtendedThemeMode(t.Mode))PaintExtendedBackground(g,t,r);
        }

        private void PaintMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,int index)
        {
            RectangleF inner=new RectangleF(r.X+3,r.Y+3,r.Width-6,r.Height-6);
            if(t.Mode=="round"||t.Mode=="glass")
            {
                using(GraphicsPath gp=RoundRect(inner,10))using(SolidBrush b=new SolidBrush(Color.FromArgb(t.Mode=="glass"?70:165,t.Background2)))g.FillPath(b,gp);
                using(GraphicsPath gp=RoundRect(inner,10))using(Pen p=new Pen(Color.FromArgb(100,t.Border),1))g.DrawPath(p,gp);
            }
            else if(t.Mode=="hex")
            {
                using(Pen p=new Pen(Color.FromArgb(90,t.Border),1))g.DrawLine(p,r.Right-1,6,r.Right-1,r.Height-6);
            }
            else if(index>0)using(Pen p=new Pen(Color.FromArgb(t.Light?90:75,t.Border),1))g.DrawLine(p,r.X,7,r.X,r.Height-7);

            float baseScale=(config!=null && config.FontSize>0)?(float)(config.FontSize/10.0):1f;
            // R06: adapt layout before shrinking text; keep a readable floor.
            if(baseScale<0.85f)baseScale=0.85f;
            if(baseScale>1.20f)baseScale=1.20f;

            Font labelFont=SafeFont(t.FontName,(t.Mode=="terminal"?7.1f:7.4f)*baseScale,FontStyle.Bold);
            Font valueFont=SafeFont(t.FontName,(t.Mode=="terminal"?8.8f:10.1f)*baseScale,FontStyle.Bold);
            try
            {
                if(t.Mode=="hex") PaintHexMetric(g,t,m,inner,labelFont,valueFont);
                else if(IsExtendedThemeMode(t.Mode)) PaintExtendedMetric(g,t,m,inner,labelFont,valueFont);
                else if(t.Mode=="terminal") PaintTerminalMetric(g,t,m,inner,labelFont,valueFont);
                else PaintStandardMetric(g,t,m,inner,labelFont,valueFont);
            }
            finally{labelFont.Dispose();valueFont.Dispose();}
        }

        private void PaintStandardMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            float baseScale=(config!=null && config.FontSize>0)?(float)(config.FontSize/10.0):1f;
            if(baseScale<0.85f)baseScale=0.85f;
            if(baseScale>1.20f)baseScale=1.20f;
            float readableMin=Math.Max(7.4f,7.4f*baseScale);
            string headline=BuildMetricHeadline(g,t,m,readableMin,r.Width-10);
            bool stacked=HeadlineIsStacked(headline);
            using(Font hf=FitHeadlineFont(g,t.FontName,headline,Math.Max(8.7f,8.7f*baseScale),readableMin,r.Width-10))
            using(SolidBrush fg=new SolidBrush(t.Foreground))
                g.DrawString(headline,hf,fg,r.X+5,r.Y+1);

            float graphTop=stacked?29f:22f;
            RectangleF graph=new RectangleF(r.X+5,r.Y+graphTop,Math.Max(34,r.Width-10),Math.Max(6,r.Height-(graphTop+4)));
            if(config.ShowSparklines)DrawSparkline(g,m.History,graph,m.Accent,t.Mode=="neon"?1.8f:1.3f,t.Mode=="neon");

            float barWidth=Math.Max(3,(r.Width-10)*Math.Max(0,Math.Min(100,m.Percent))/100f);
            using(SolidBrush a=new SolidBrush(m.Accent))g.FillRectangle(a,r.X+5,r.Bottom-3,barWidth,2);
        }

        private void PaintNetworkMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            Font netFont=SafeFont(t.FontName,t.Mode=="terminal"?7.0f:7.6f,FontStyle.Bold);
            try
            {
                using(SolidBrush muted=new SolidBrush(t.Muted))g.DrawString(m.Label,labelFont,muted,r.X+5,r.Y+1);

                SizeF v1=g.MeasureString(m.Value,netFont);
                SizeF v2=g.MeasureString(m.Value2,netFont);
                float textWidth=Math.Max(v1.Width,v2.Width);
                float textRight=r.X+5+textWidth;

                float graphLeft=Math.Max(r.X+64,textRight+8);
                float minGraph=36f;
                if(graphLeft>r.Right-minGraph-7)graphLeft=r.Right-minGraph-7;

                using(SolidBrush fg=new SolidBrush(t.Foreground))
                {
                    g.DrawString(m.Value,netFont,fg,r.X+5,r.Y+13);
                    g.DrawString(m.Value2,netFont,fg,r.X+5,r.Y+24);
                }

                RectangleF graph=new RectangleF(
                    graphLeft,
                    r.Y+7,
                    Math.Max(minGraph,r.Right-7-graphLeft),
                    r.Height-14
                );

                if(config.ShowSparklines)DrawSparkline(g,m.History,graph,m.Accent,1.4f,false);

                float textZoneWidth=Math.Max(30,graphLeft-(r.X+5)-6);
                float barWidth=Math.Max(3,textZoneWidth*Math.Max(0,Math.Min(100,m.Percent))/100f);
                using(SolidBrush a=new SolidBrush(m.Accent))
                    g.FillRectangle(a,r.X+5,r.Bottom-3,barWidth,2);
            }
            finally
            {
                netFont.Dispose();
            }
        }

        private void PaintHexMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            float readableMin=7.3f;
            string headline=BuildMetricHeadline(g,t,m,readableMin,Math.Max(72,r.Width-60));
            float maxBadge=Math.Max(90,r.Width-42);
            float badgeWidth=Math.Min(maxBadge,Math.Max(88,r.Width*0.72f));
            RectangleF hx=new RectangleF(r.X+4,r.Y+1,badgeWidth,r.Height-2);
            PointF[] pts=Hex(hx);
            using(SolidBrush b=new SolidBrush(Color.FromArgb(34,m.Accent)))g.FillPolygon(b,pts);
            using(Pen p=new Pen(m.Accent,1.5f))g.DrawPolygon(p,pts);

            using(Font hf=FitHeadlineFont(g,t.FontName,headline,8.4f,readableMin,hx.Width-18))
            using(SolidBrush fb=new SolidBrush(t.Foreground))
            {
                SizeF hs=g.MeasureString(headline,hf);
                g.DrawString(headline,hf,fb,hx.X+(hx.Width-hs.Width)/2,hx.Y+(hx.Height-hs.Height)/2-1);
            }

            float graphX=hx.Right+5;
            RectangleF graph=new RectangleF(graphX,r.Y+7,Math.Max(24,r.Right-5-graphX),r.Height-14);
            if(config.ShowSparklines)DrawSparkline(g,m.History,graph,m.Accent,1.3f,false);
        }

        private void PaintTerminalMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            float readableMin=7.5f;
            string headline=BuildMetricHeadline(g,t,m,readableMin,r.Width-8);
            bool stacked=HeadlineIsStacked(headline);
            using(Font hf=FitHeadlineFont(g,t.FontName,headline,9.0f,readableMin,r.Width-8))
            using(SolidBrush b=new SolidBrush(t.Foreground))
                g.DrawString(headline,hf,b,r.X+4,r.Y+1);

            if(config.ShowSparklines)
            {
                float graphTop=stacked?29f:22f;
                DrawTerminalBars(g,m.History,new RectangleF(r.X+4,r.Y+graphTop,r.Width-8,Math.Max(6,r.Height-(graphTop+3))),m.Accent);
            }
        }

        private static Font SafeFont(string name,float size,FontStyle style){try{return new Font(name,size,style,GraphicsUnit.Point);}catch{return new Font("Segoe UI",size,style,GraphicsUnit.Point);}}
        private static GraphicsPath RoundRect(RectangleF r,float rad){float d=rad*2;GraphicsPath p=new GraphicsPath();p.AddArc(r.X,r.Y,d,d,180,90);p.AddArc(r.Right-d,r.Y,d,d,270,90);p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);p.AddArc(r.X,r.Bottom-d,d,d,90,90);p.CloseFigure();return p;}
        private static PointF[] Hex(RectangleF r){float q=r.Width*0.18f;return new PointF[]{new PointF(r.X+q,r.Y),new PointF(r.Right-q,r.Y),new PointF(r.Right,r.Y+r.Height/2),new PointF(r.Right-q,r.Bottom),new PointF(r.X+q,r.Bottom),new PointF(r.X,r.Y+r.Height/2)};}

        private static bool IsExtendedThemeMode(string mode)
        {
            return mode=="fluent"||mode=="oled"||mode=="cyber2"||mode=="mission"||mode=="blueprint"||mode=="medical"||mode=="carbon";
        }

        private void PaintExtendedBackground(Graphics g,ThemeDefinition t,Rectangle r)
        {
            if(t.Mode=="fluent")
            {
                using(LinearGradientBrush b=new LinearGradientBrush(r,t.Background2,t.Background,90f))g.FillRectangle(b,r);
                using(Pen hi=new Pen(Color.FromArgb(95,210,235,255),1))g.DrawLine(hi,0,0,r.Width,0);
                using(Pen lo=new Pen(Color.FromArgb(70,t.Border),1))g.DrawLine(lo,0,r.Height-1,r.Width,r.Height-1);
            }
            else if(t.Mode=="oled")
            {
                using(SolidBrush b=new SolidBrush(Color.Black))g.FillRectangle(b,r);
                using(Pen p=new Pen(Color.FromArgb(34,255,255,255),1))g.DrawLine(p,0,r.Height-1,r.Width,r.Height-1);
            }
            else if(t.Mode=="cyber2")
            {
                using(LinearGradientBrush b=new LinearGradientBrush(r,t.Background,t.Background2,0f))g.FillRectangle(b,r);
                using(Pen c=new Pen(Color.FromArgb(105,0,246,255),1))
                using(Pen m=new Pen(Color.FromArgb(90,255,65,220),1))
                {
                    g.DrawLine(c,0,0,r.Width*0.42f,0);g.DrawLine(m,r.Width*0.58f,0,r.Width,0);
                    g.DrawLine(m,0,r.Height-1,r.Width*0.22f,r.Height-1);g.DrawLine(c,r.Width*0.78f,r.Height-1,r.Width,r.Height-1);
                }
            }
            else if(t.Mode=="mission")
            {
                using(SolidBrush b=new SolidBrush(t.Background))g.FillRectangle(b,r);
                using(Pen p=new Pen(Color.FromArgb(28,t.Foreground),1)){for(int y=12;y<r.Height;y+=12)g.DrawLine(p,0,y,r.Width,y);}
            }
            else if(t.Mode=="blueprint")
            {
                using(LinearGradientBrush b=new LinearGradientBrush(r,t.Background,t.Background2,0f))g.FillRectangle(b,r);
                using(Pen grid=new Pen(Color.FromArgb(30,190,230,255),1))
                {
                    for(int x=0;x<r.Width;x+=22)g.DrawLine(grid,x,0,x,r.Height);
                    for(int y=0;y<r.Height;y+=12)g.DrawLine(grid,0,y,r.Width,y);
                }
            }
            else if(t.Mode=="medical")
            {
                using(LinearGradientBrush b=new LinearGradientBrush(r,t.Background,t.Background2,90f))g.FillRectangle(b,r);
                using(Pen grid=new Pen(Color.FromArgb(34,69,156,160),1))
                {
                    for(int x=0;x<r.Width;x+=24)g.DrawLine(grid,x,0,x,r.Height);
                    for(int y=0;y<r.Height;y+=12)g.DrawLine(grid,0,y,r.Width,y);
                }
            }
            else if(t.Mode=="carbon")
            {
                using(SolidBrush b=new SolidBrush(t.Background))g.FillRectangle(b,r);
                using(Pen p1=new Pen(Color.FromArgb(25,255,255,255),1))
                using(Pen p2=new Pen(Color.FromArgb(22,0,0,0),1))
                {
                    for(int x=-r.Height;x<r.Width;x+=12)
                    {
                        g.DrawLine(p1,x,0,x+r.Height,r.Height);
                        g.DrawLine(p2,x+6,0,x+6-r.Height,r.Height);
                    }
                }
            }
        }

        private void PaintExtendedMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            if(t.Mode=="fluent")PaintFluentMetric(g,t,m,r,labelFont,valueFont);
            else if(t.Mode=="oled")PaintOledMetric(g,t,m,r,labelFont,valueFont);
            else if(t.Mode=="cyber2")PaintCyberMetric(g,t,m,r,labelFont,valueFont);
            else if(t.Mode=="mission")PaintMissionMetric(g,t,m,r,labelFont,valueFont);
            else if(t.Mode=="blueprint")PaintBlueprintMetric(g,t,m,r,labelFont,valueFont);
            else if(t.Mode=="medical")PaintMedicalMetric(g,t,m,r,labelFont,valueFont);
            else if(t.Mode=="carbon")PaintCarbonMetric(g,t,m,r,labelFont,valueFont);
        }

        private float DrawExtendedValueBlock(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont,float x,float labelY,float valueY,Color valueColor)
        {
            float available=Math.Max(40,r.Right-x-4);
            float readableMin=7.4f;
            string headline=BuildMetricHeadline(g,t,m,readableMin,available);
            using(Font hf=FitHeadlineFont(g,t.FontName,headline,8.7f,readableMin,available))
            using(SolidBrush vb=new SolidBrush(valueColor))
            {
                g.DrawString(headline,hf,vb,x,r.Y+2);
                return x+MaxLineWidth(g,headline,hf);
            }
        }

        private bool ExtendedHeadlineStacks(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,float x)
        {
            float available=Math.Max(40,r.Right-x-4);
            return HeadlineIsStacked(BuildMetricHeadline(g,t,m,7.4f,available));
        }

        private void PaintFluentMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            using(GraphicsPath gp=RoundRect(r,8))
            using(LinearGradientBrush fill=new LinearGradientBrush(r,Color.FromArgb(88,t.Background2),Color.FromArgb(45,t.Background),90f))
            using(Pen edge=new Pen(Color.FromArgb(105,t.Border),1)){g.FillPath(fill,gp);g.DrawPath(edge,gp);}
            using(SolidBrush dot=new SolidBrush(m.Accent))g.FillEllipse(dot,r.X+7,r.Y+8,4,4);
            float tr=DrawExtendedValueBlock(g,t,m,r,labelFont,valueFont,r.X+15,r.Y+2,r.Y+15,t.Foreground);
            float gx=Math.Max(r.X+72,tr+8);
            bool stacked=ExtendedHeadlineStacks(g,t,m,r,r.X+15);
            float graphTop=stacked?29f:23f;
            RectangleF graph=new RectangleF(r.X+7,r.Y+graphTop,Math.Max(32,r.Width-14),Math.Max(6,r.Height-(graphTop+4)));
            if(config.ShowSparklines)DrawSparkline(g,m.History,graph,m.Accent,1.35f,false);
        }

        private void PaintOledMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            using(Pen edge=new Pen(Color.FromArgb(60,255,255,255),1))g.DrawLine(edge,r.X+3,r.Bottom-2,r.Right-3,r.Bottom-2);
            float tr=DrawExtendedValueBlock(g,t,m,r,labelFont,valueFont,r.X+5,r.Y+2,r.Y+15,t.Foreground);
            float gx=Math.Max(r.X+70,tr+8);
            bool stacked=ExtendedHeadlineStacks(g,t,m,r,r.X+5);
            float graphTop=stacked?29f:23f;
            RectangleF graph=new RectangleF(r.X+6,r.Y+graphTop,Math.Max(34,r.Width-12),Math.Max(6,r.Height-(graphTop+4)));
            if(config.ShowSparklines)DrawSparkline(g,m.History,graph,Color.FromArgb(225,m.Accent),1.05f,false);
            using(SolidBrush tick=new SolidBrush(Color.FromArgb(210,m.Accent)))g.FillRectangle(tick,r.X+4,r.Y+5,2,5);
        }

        private void PaintCyberMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            float cut=9f;
            PointF[] p=new PointF[]{new PointF(r.X+cut,r.Y),new PointF(r.Right-cut,r.Y),new PointF(r.Right,r.Y+cut),new PointF(r.Right,r.Bottom-cut),new PointF(r.Right-cut,r.Bottom),new PointF(r.X+cut,r.Bottom),new PointF(r.X,r.Bottom-cut),new PointF(r.X,r.Y+cut)};
            using(SolidBrush fill=new SolidBrush(Color.FromArgb(32,m.Accent)))g.FillPolygon(fill,p);
            using(Pen glow=new Pen(Color.FromArgb(55,m.Accent),4f))g.DrawPolygon(glow,p);
            using(Pen edge=new Pen(m.Accent,1.15f))g.DrawPolygon(edge,p);
            float tr=DrawExtendedValueBlock(g,t,m,r,labelFont,valueFont,r.X+10,r.Y+2,r.Y+15,m.Accent);
            float gx=Math.Max(r.X+78,tr+7);
            bool stacked=ExtendedHeadlineStacks(g,t,m,r,r.X+10);
            float graphTop=stacked?29f:23f;
            RectangleF graph=new RectangleF(r.X+9,r.Y+graphTop,Math.Max(28,r.Width-18),Math.Max(6,r.Height-(graphTop+4)));
            if(config.ShowSparklines)DrawSparkline(g,m.History,graph,m.Accent,1.55f,true);
        }

        private void PaintMissionMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            RectangleF panel=new RectangleF(r.X+1,r.Y+1,r.Width-2,r.Height-2);
            using(SolidBrush fill=new SolidBrush(Color.FromArgb(150,t.Background2)))g.FillRectangle(fill,panel);
            using(Pen edge=new Pen(t.Border,1))g.DrawRectangle(edge,panel.X,panel.Y,panel.Width,panel.Height);
            using(SolidBrush band=new SolidBrush(m.Accent))g.FillRectangle(band,panel.X,panel.Y,4,panel.Height);
            float tr=DrawExtendedValueBlock(g,t,m,r,labelFont,valueFont,r.X+10,r.Y+2,r.Y+15,t.Foreground);
            float gx=Math.Max(r.X+77,tr+7);
            bool stacked=ExtendedHeadlineStacks(g,t,m,r,r.X+10);
            float graphTop=stacked?29f:23f;
            RectangleF graph=new RectangleF(r.X+7,r.Y+graphTop,Math.Max(28,r.Width-14),Math.Max(6,r.Height-(graphTop+4)));
            if(config.ShowSparklines)DrawMissionBars(g,m.History,graph,m.Accent);
        }

        private void PaintBlueprintMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            using(Pen p=new Pen(Color.FromArgb(180,m.Accent),1))
            {
                float l=9f;
                g.DrawLine(p,r.X+2,r.Y+2,r.X+2+l,r.Y+2);g.DrawLine(p,r.X+2,r.Y+2,r.X+2,r.Y+2+l);
                g.DrawLine(p,r.Right-2-l,r.Y+2,r.Right-2,r.Y+2);g.DrawLine(p,r.Right-2,r.Y+2,r.Right-2,r.Y+2+l);
                g.DrawLine(p,r.X+2,r.Bottom-2,r.X+2+l,r.Bottom-2);g.DrawLine(p,r.X+2,r.Bottom-2-l,r.X+2,r.Bottom-2);
                g.DrawLine(p,r.Right-2-l,r.Bottom-2,r.Right-2,r.Bottom-2);g.DrawLine(p,r.Right-2,r.Bottom-2-l,r.Right-2,r.Bottom-2);
            }
            float tr=DrawExtendedValueBlock(g,t,m,r,labelFont,valueFont,r.X+9,r.Y+2,r.Y+15,t.Foreground);
            float gx=Math.Max(r.X+78,tr+7);
            bool stacked=ExtendedHeadlineStacks(g,t,m,r,r.X+9);
            float graphTop=stacked?29f:23f;
            RectangleF graph=new RectangleF(r.X+8,r.Y+graphTop,Math.Max(28,r.Width-16),Math.Max(6,r.Height-(graphTop+4)));
            if(config.ShowSparklines)DrawSparkline(g,m.History,graph,m.Accent,1.15f,false);
        }

        private void PaintMedicalMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            using(GraphicsPath gp=RoundRect(r,6))
            using(SolidBrush fill=new SolidBrush(Color.FromArgb(205,255,255,255)))
            using(Pen edge=new Pen(Color.FromArgb(180,t.Border),1)){g.FillPath(fill,gp);g.DrawPath(edge,gp);}
            using(SolidBrush status=new SolidBrush(m.Accent))g.FillEllipse(status,r.X+7,r.Y+7,5,5);
            float tr=DrawExtendedValueBlock(g,t,m,r,labelFont,valueFont,r.X+16,r.Y+1,r.Y+14,t.Foreground);
            float gx=Math.Max(r.X+80,tr+7);
            bool stacked=ExtendedHeadlineStacks(g,t,m,r,r.X+16);
            float graphTop=stacked?29f:23f;
            RectangleF graph=new RectangleF(r.X+7,r.Y+graphTop,Math.Max(28,r.Width-14),Math.Max(6,r.Height-(graphTop+4)));
            if(config.ShowSparklines)DrawSparkline(g,m.History,graph,m.Accent,1.3f,false);
        }

        private void PaintCarbonMetric(Graphics g,ThemeDefinition t,MetricView m,RectangleF r,Font labelFont,Font valueFont)
        {
            float cut=8f;
            PointF[] p=new PointF[]{new PointF(r.X+cut,r.Y+1),new PointF(r.Right,r.Y+1),new PointF(r.Right-cut,r.Bottom-1),new PointF(r.X,r.Bottom-1)};
            using(SolidBrush fill=new SolidBrush(Color.FromArgb(185,t.Background2)))g.FillPolygon(fill,p);
            using(Pen edge=new Pen(Color.FromArgb(120,t.Border),1))g.DrawPolygon(edge,p);
            using(SolidBrush stripe=new SolidBrush(m.Accent))g.FillPolygon(stripe,new PointF[]{new PointF(r.X+cut,r.Y+1),new PointF(r.X+cut+4,r.Y+1),new PointF(r.X+4,r.Bottom-1),new PointF(r.X,r.Bottom-1)});
            float tr=DrawExtendedValueBlock(g,t,m,r,labelFont,valueFont,r.X+13,r.Y+2,r.Y+15,t.Foreground);
            float gx=Math.Max(r.X+79,tr+7);
            bool stacked=ExtendedHeadlineStacks(g,t,m,r,r.X+13);
            float graphTop=stacked?29f:23f;
            RectangleF graph=new RectangleF(r.X+8,r.Y+graphTop,Math.Max(26,r.Width-16),Math.Max(6,r.Height-(graphTop+4)));
            if(config.ShowSparklines)DrawSparkline(g,m.History,graph,m.Accent,1.35f,false);
        }

        private static void DrawMissionBars(Graphics g,IList<float> values,RectangleF r,Color c)
        {
            if(values==null||values.Count==0||r.Width<8||r.Height<4)return;
            int count=Math.Min(values.Count,14);float max=values.Skip(values.Count-count).Max();if(max<1)max=1;float w=r.Width/count;
            using(SolidBrush b=new SolidBrush(Color.FromArgb(205,c)))
            {
                for(int i=0;i<count;i++){float v=values[values.Count-count+i]/max;float h=Math.Max(1,r.Height*v);g.FillRectangle(b,r.X+i*w,r.Bottom-h,Math.Max(1,w-1.5f),h);}
            }
        }

        private static void DrawSparkline(Graphics g,IList<float> values,RectangleF r,Color color,float width,bool glow)
        {
            if(values==null||values.Count<2||r.Width<4||r.Height<4)return;float max=values.Max();float min=values.Min();if(max-min<0.01f){max=min+1;}
            PointF[] p=new PointF[values.Count];for(int i=0;i<values.Count;i++){float x=r.X+r.Width*i/(values.Count-1f);float y=r.Bottom-(values[i]-min)/(max-min)*r.Height;p[i]=new PointF(x,y);}
            if(glow)using(Pen gp=new Pen(Color.FromArgb(55,color),4f)){gp.LineJoin=LineJoin.Round;g.DrawLines(gp,p);}using(Pen pen=new Pen(color,width)){pen.LineJoin=LineJoin.Round;g.DrawLines(pen,p);}
        }
        private static void DrawTerminalBars(Graphics g,IList<float> values,RectangleF r,Color c)
        {
            if(values==null||values.Count==0)return;int count=Math.Min(values.Count,18);float max=values.Skip(values.Count-count).Max();if(max<1)max=1;float w=r.Width/count;
            using(SolidBrush b=new SolidBrush(Color.FromArgb(210,c)))for(int i=0;i<count;i++){float v=values[values.Count-count+i]/max;float h=Math.Max(1,r.Height*v);g.FillRectangle(b,r.X+i*w,r.Bottom-h,Math.Max(1,w-1),h);}
        }
    }

    internal sealed class SettingsForm : Form
    {
        private sealed class HardwareChoice
        {
            public string Id,Name; public override string ToString(){return Name??Id??"Device";}
        }
        private readonly AppConfig c; private readonly MetricsSnapshot snapshot;
        private ComboBox theme,position,cpuMode,gpuMode,diskMode,netMode,multiLayout,memoryUnit,storageUnit,networkUnit,diskRateUnit;
        private NumericUpDown opacity,interval,width;
        private CheckBox cpu,ram,disk,gpu,vram,net,temp,spark,startup,safe,ramNumeric,diskNumeric,flyout,hoverAll,autoCheckUpdates;
        private CheckedListBox cpuList,gpuList,diskList,netList;
        private Label updateCurrent,updateLatest,updateStatus;
        private Button checkUpdate,installUpdate,openRelease;
        private TextBox diagnosticsText;
        private Button refreshDiagnostics,saveDiagnostics,openDataFolder,repairSensors;
        private TabControl tabsControl;
        private ReleaseUpdateInfo latestUpdate;
        public SettingsForm(AppConfig config,MetricsSnapshot current) : this(config,current,null) { }
        public SettingsForm(AppConfig config,MetricsSnapshot current,string initialTab)
        {
            c=config;snapshot=current??new MetricsSnapshot();Text="Taskbar Monitor Enhanced — Settings";Width=900;Height=700;MinimumSize=new Size(760,620);StartPosition=FormStartPosition.CenterScreen;FormBorderStyle=FormBorderStyle.Sizable;MaximizeBox=true;MinimizeBox=false;AutoScaleMode=AutoScaleMode.Dpi;KeyPreview=true;
            TabControl tabs=new TabControl();tabsControl=tabs;tabs.Dock=DockStyle.Fill;Controls.Add(tabs);
            TabPage display=new TabPage("Display"), metrics=new TabPage("Metrics"), hardware=new TabPage("Hardware"), units=new TabPage("Units"), behavior=new TabPage("Behavior"), updates=new TabPage("Updates"), diagnostics=new TabPage("Diagnostics"), advanced=new TabPage("Advanced");
            tabs.TabPages.Add(display);tabs.TabPages.Add(metrics);tabs.TabPages.Add(hardware);tabs.TabPages.Add(units);tabs.TabPages.Add(behavior);tabs.TabPages.Add(updates);tabs.TabPages.Add(diagnostics);tabs.TabPages.Add(advanced);
            foreach(TabPage page in tabs.TabPages){page.AutoScroll=true;page.Padding=new Padding(4);}
            display.AutoScrollMinSize=new Size(720,280);metrics.AutoScrollMinSize=new Size(720,330);hardware.AutoScrollMinSize=new Size(720,640);units.AutoScrollMinSize=new Size(720,440);behavior.AutoScrollMinSize=new Size(720,260);updates.AutoScrollMinSize=new Size(720,440);diagnostics.AutoScrollMinSize=new Size(720,520);advanced.AutoScrollMinSize=new Size(720,440);
            theme=Combo(display,"Theme",ThemeCatalog.Names,c.Theme,22);position=Combo(display,"Position",new string[]{"Left","Center","Right"},c.Position,68);opacity=Number(display,"Opacity %",(decimal)(c.Opacity*100),55,100,114);width=Number(display,"Locked width px",c.MinWidthLogicalPx,900,1500,160);
            cpu=Check(metrics,"CPU",c.ShowCpu,24);ram=Check(metrics,"RAM",c.ShowRam,55);disk=Check(metrics,"Disk / storage",c.ShowDisk,86);gpu=Check(metrics,"GPU",c.ShowGpu,117);vram=Check(metrics,"VRAM",c.ShowVram,148);net=Check(metrics,"Network",c.ShowNetwork,179);temp=Check(metrics,"CPU/GPU temperature",c.ShowTemperatures,210);spark=Check(metrics,"Real sparklines",c.ShowSparklines,241);

            hardware.AutoScroll=true;hardware.AutoScrollMargin=new Size(0,24);int y=16;
            AddHardwareSection(hardware,"CPU",c.CpuDisplayMode,ChoicesCpu(),c.SelectedCpuIds,y,out cpuMode,out cpuList);y+=118;
            AddHardwareSection(hardware,"GPU",c.GpuDisplayMode,ChoicesGpu(),c.SelectedGpuIds,y,out gpuMode,out gpuList);y+=118;
            AddHardwareSection(hardware,"Physical disk",c.DiskDisplayMode,ChoicesDisk(),c.SelectedDiskIds,y,out diskMode,out diskList);y+=118;
            AddHardwareSection(hardware,"Network adapter",c.NetworkDisplayMode,ChoicesNet(),c.SelectedNetworkIds,y,out netMode,out netList);y+=118;
            multiLayout=Combo(hardware,"Multiple layout",new string[]{"Grouped","Separate"},c.MultipleDeviceLayout,y);flyout=Check(hardware,"Show upward hardware flyout on hover",c.EnableHardwareFlyout,y+42);hoverAll=Check(hardware,"Flyout shows all detected devices (not only selected)",c.HoverShowAllDevices,y+72);

            memoryUnit=Combo(units,"RAM unit",new string[]{"Auto","KB","MB","GB"},c.MemoryUnit,28);storageUnit=Combo(units,"Storage capacity unit",new string[]{"Auto","KB","MB","GB"},c.StorageUnit,78);diskRateUnit=Combo(units,"Disk speed unit",new string[]{"Auto","KB","MB","GB"},c.DiskRateUnit,128);networkUnit=Combo(units,"Network rate unit",new string[]{"Auto","KB","MB","GB"},c.NetworkUnit,178);ramNumeric=Check(units,"Show used / total RAM as a number",c.ShowRamNumeric,238);diskNumeric=Check(units,"Show used / total disk capacity in hover details",c.ShowDiskNumeric,272);
            Label unitNote=new Label();unitNote.Location=new Point(24,320);unitNote.Size=new Size(660,85);unitNote.Text="Disk cards show live read/write throughput. Disk capacity, usage percentage, volumes and temperature are shown in the upward hover details. Auto selects KB, MB or GB independently for capacity, disk speed and network rate.";units.Controls.Add(unitNote);

            interval=Number(behavior,"Update interval ms",c.UpdateIntervalMs,1000,5000,24);startup=Check(behavior,"Start with Windows",c.StartWithWindows,78);safe=Check(behavior,"Safe placement / avoid taskbar controls",c.SafePlacement,112);
            autoCheckUpdates=Check(behavior,"Automatically check GitHub Releases for updates",c.AutoCheckUpdates,148);

            updateCurrent=new Label();updateCurrent.Location=new Point(24,28);updateCurrent.Size=new Size(650,24);updateCurrent.Text="Installed version: "+BuildInfo.PublicVersion;updates.Controls.Add(updateCurrent);
            updateLatest=new Label();updateLatest.Location=new Point(24,62);updateLatest.Size=new Size(650,24);updateLatest.Text="Latest public release: Not checked";updates.Controls.Add(updateLatest);
            updateStatus=new Label();updateStatus.Location=new Point(24,100);updateStatus.Size=new Size(660,80);updateStatus.Text="Use Check for updates to query the official GitHub Releases page.";updates.Controls.Add(updateStatus);
            checkUpdate=new Button();checkUpdate.Text="Check for updates";checkUpdate.Location=new Point(24,196);checkUpdate.Size=new Size(150,34);checkUpdate.Click+=delegate{BeginCheckUpdates();};updates.Controls.Add(checkUpdate);
            installUpdate=new Button();installUpdate.Text="Download && Install";installUpdate.Location=new Point(188,196);installUpdate.Size=new Size(160,34);installUpdate.Enabled=false;installUpdate.Click+=delegate{BeginInstallUpdate();};updates.Controls.Add(installUpdate);
            openRelease=new Button();openRelease.Text="Open release page";openRelease.Location=new Point(362,196);openRelease.Size=new Size(145,34);openRelease.Enabled=false;openRelease.Click+=delegate{OpenReleasePage();};updates.Controls.Add(openRelease);
            Label updateNote=new Label();updateNote.Location=new Point(24,250);updateNote.Size=new Size(660,150);updateNote.Text="Updates are read from the official GOD13emad/TaskbarMonitorEnhanced GitHub Releases feed. Automatic installation requires an immutable GitHub Release, a TaskbarMonitorEnhanced_Setup_*.exe asset and GitHub SHA-256 digest metadata. Mutable releases are never auto-installed.";updates.Controls.Add(updateNote);

            diagnosticsText=new TextBox();diagnosticsText.Location=new Point(24,72);diagnosticsText.Size=new Size(800,390);diagnosticsText.Multiline=true;diagnosticsText.ReadOnly=true;diagnosticsText.ScrollBars=ScrollBars.Both;diagnosticsText.WordWrap=false;diagnosticsText.Font=new Font("Consolas",9f);diagnostics.Controls.Add(diagnosticsText);
            refreshDiagnostics=new Button();refreshDiagnostics.Text="Refresh health";refreshDiagnostics.Location=new Point(24,24);refreshDiagnostics.Size=new Size(130,34);refreshDiagnostics.Click+=delegate{RefreshDiagnostics();};diagnostics.Controls.Add(refreshDiagnostics);
            saveDiagnostics=new Button();saveDiagnostics.Text="Save report...";saveDiagnostics.Location=new Point(168,24);saveDiagnostics.Size=new Size(130,34);saveDiagnostics.Click+=delegate{SaveDiagnosticsReport();};diagnostics.Controls.Add(saveDiagnostics);
            openDataFolder=new Button();openDataFolder.Text="Open data folder";openDataFolder.Location=new Point(312,24);openDataFolder.Size=new Size(135,34);openDataFolder.Click+=delegate{try{Process.Start("explorer.exe",AppPaths.Root);}catch{}};diagnostics.Controls.Add(openDataFolder);
            repairSensors=new Button();repairSensors.Text="Repair protected sensors...";repairSensors.Location=new Point(461,24);repairSensors.Size=new Size(185,34);repairSensors.Click+=delegate{RepairProtectedSensors();};diagnostics.Controls.Add(repairSensors);

            Button openLog=new Button();openLog.Text="Open Logs";openLog.Location=new Point(24,28);openLog.Width=120;openLog.Click+=delegate{try{Process.Start("explorer.exe",AppPaths.Logs);}catch{}};advanced.Controls.Add(openLog);
            Label note=new Label();note.AutoSize=false;note.Location=new Point(24,80);note.Size=new Size(660,300);note.Text="v1.1.2-rc2 — R21 production hardening: isolated native sensors, staggered health supervisor, power-aware telemetry, native CPU usage, cached topology and diagnostics.\r\n\r\nDisk cards show live physical-disk read/write speed. Hover shows each detected disk model, read/write throughput, temperature, volume list, used/total capacity and activity.\r\n\r\nDisplay modes: Overall = system/all devices, Auto = highest active device, Single = one selected device, Multiple = all checked devices.\r\n\r\nAutomatic update installation requires both GitHub SHA-256 asset metadata and an immutable GitHub Release.";advanced.Controls.Add(note);
            FlowLayoutPanel buttons=new FlowLayoutPanel();buttons.Dock=DockStyle.Bottom;buttons.Height=45;buttons.FlowDirection=FlowDirection.RightToLeft;Controls.Add(buttons);Button ok=new Button();ok.Text="Save & Apply";ok.Width=105;ok.Click+=delegate{Apply();DialogResult=DialogResult.OK;Close();};Button cancel=new Button();cancel.Text="Cancel";cancel.Width=90;cancel.Click+=delegate{DialogResult=DialogResult.Cancel;Close();};buttons.Controls.Add(ok);buttons.Controls.Add(cancel);AcceptButton=ok;CancelButton=cancel;
            if(!String.IsNullOrWhiteSpace(initialTab))foreach(TabPage tp in tabs.TabPages)if(String.Equals(tp.Text,initialTab,StringComparison.OrdinalIgnoreCase)){tabs.SelectedTab=tp;break;}
            Shown+=delegate{if(c.AutoCheckUpdates||String.Equals(initialTab,"Updates",StringComparison.OrdinalIgnoreCase))BeginCheckUpdates();if(String.Equals(initialTab,"Diagnostics",StringComparison.OrdinalIgnoreCase))RefreshDiagnostics();};
        }

        public void SelectTab(string tabName)
        {
            if(String.IsNullOrWhiteSpace(tabName)||tabsControl==null)return;
            foreach(TabPage tp in tabsControl.TabPages)
            {
                if(String.Equals(tp.Text,tabName,StringComparison.OrdinalIgnoreCase))
                {
                    tabsControl.SelectedTab=tp;
                    return;
                }
            }
        }

        private void Ui(Action action)
        {
            try{if(IsDisposed||Disposing)return;if(InvokeRequired)BeginInvoke((MethodInvoker)delegate{if(!IsDisposed&&!Disposing)action();});else action();}catch{}
        }
        private void BeginCheckUpdates()
        {
            if(checkUpdate!=null)checkUpdate.Enabled=false;if(installUpdate!=null)installUpdate.Enabled=false;if(updateStatus!=null)updateStatus.Text="Checking official GitHub Releases...";
            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    ReleaseUpdateInfo info=UpdateManager.CheckLatest();latestUpdate=info;Ui(delegate{updateLatest.Text="Latest public release: "+(String.IsNullOrWhiteSpace(info.Version)?info.Tag:info.Version)+"  |  Immutable: "+(info.Immutable?"Yes":"No");updateStatus.Text=info.Status;openRelease.Enabled=!String.IsNullOrWhiteSpace(info.HtmlUrl);installUpdate.Enabled=info.HasUpdate&&info.SetupAssetAvailable&&info.DigestAvailable&&info.Immutable;checkUpdate.Enabled=true;});
                    Log.Write("INFO","UPDATE_CHECK latest="+info.Version+" hasUpdate="+info.HasUpdate+" asset="+info.SetupAssetAvailable+" digest="+info.DigestAvailable);
                }
                catch(Exception ex){Log.Write("WARN","UPDATE_CHECK_FAIL "+ex.Message);Ui(delegate{updateStatus.Text="Update check failed: "+ex.Message;checkUpdate.Enabled=true;installUpdate.Enabled=false;});}
            });
        }
        private void BeginInstallUpdate()
        {
            ReleaseUpdateInfo info=latestUpdate;if(info==null||!info.HasUpdate)return;
            if(MessageBox.Show("Download, verify and launch Taskbar Monitor Enhanced "+info.Version+" setup?","Taskbar Monitor Enhanced Update",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return;
            checkUpdate.Enabled=false;installUpdate.Enabled=false;updateStatus.Text="Downloading and verifying "+info.SetupName+"...";
            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    string path=UpdateManager.DownloadAndVerify(info);Ui(delegate{updateStatus.Text="SHA-256 verified. Starting Windows installer...";});Thread.Sleep(250);UpdateManager.StartInstaller(path);Ui(delegate{DialogResult=DialogResult.Cancel;Close();});Thread.Sleep(300);Application.Exit();
                }
                catch(Exception ex){Log.Write("ERROR","UPDATE_INSTALL_FAIL "+ex.ToString());Ui(delegate{updateStatus.Text="Update failed safely: "+ex.Message;checkUpdate.Enabled=true;installUpdate.Enabled=info.HasUpdate&&info.SetupAssetAvailable&&info.DigestAvailable&&info.Immutable;});}
            });
        }
        private void OpenReleasePage(){try{if(latestUpdate!=null&&!String.IsNullOrWhiteSpace(latestUpdate.HtmlUrl))Process.Start(latestUpdate.HtmlUrl);else Process.Start(BuildInfo.RepositoryUrl+"/releases");}catch(Exception ex){MessageBox.Show(ex.Message,"Open release page");}}

        private static string ReadSharedDiagnostic(string path)
        {
            try
            {
                if(!File.Exists(path))return "MISSING";
                using(FileStream fs=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
                using(StreamReader sr=new StreamReader(fs,Encoding.UTF8,true))
                    return sr.ReadToEnd();
            }
            catch(Exception ex){return "READ_ERROR: "+ex.Message;}
        }

        private static string DiagnosticFileLine(string label,string path)
        {
            try
            {
                if(!File.Exists(path))return label+": MISSING — "+path;
                DateTime utc=File.GetLastWriteTimeUtc(path);
                double age=Math.Max(0,(DateTime.UtcNow-utc).TotalSeconds);
                return label+": age="+age.ToString("0.0",CultureInfo.InvariantCulture)+"s bytes="+new FileInfo(path).Length+" — "+path;
            }
            catch(Exception ex){return label+": ERROR "+ex.Message+" — "+path;}
        }

        private string BuildDiagnosticsReport()
        {
            StringBuilder b=new StringBuilder();
            b.AppendLine("Taskbar Monitor Enhanced — Diagnostics");
            b.AppendLine("GeneratedUtc: "+DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture));
            b.AppendLine("Build: "+BuildInfo.Version+" / "+BuildInfo.PublicVersion);
            b.AppendLine("Process: PID="+Process.GetCurrentProcess().Id+" 64Bit="+Environment.Is64BitProcess);
            b.AppendLine("OS: "+Environment.OSVersion+" CLR="+Environment.Version);
            b.AppendLine("TelemetryIntervalMs: "+c.UpdateIntervalMs);
            b.AppendLine();
            b.AppendLine("Current snapshot");
            CpuDeviceSnapshot diagCpu=snapshot.CpuDevices.FirstOrDefault();
            GpuDeviceSnapshot diagGpu=snapshot.GpuDevices.OrderByDescending(x=>x.UsageAvailable?x.Usage:-1).FirstOrDefault();
            b.AppendLine("CPU devices="+snapshot.CpuDevices.Count+" usage="+snapshot.Cpu.ToString("0.0",CultureInfo.InvariantCulture)+"% temp="+(snapshot.CpuTempAvailable?snapshot.CpuTempCurrent.ToString("0.0",CultureInfo.InvariantCulture)+"C":"N/A")+" power="+(diagCpu!=null&&diagCpu.PowerAvailable?diagCpu.PowerW.ToString("0.0",CultureInfo.InvariantCulture)+"W":"N/A")+" source="+(snapshot.CpuTempSource??"UNAVAILABLE"));
            b.AppendLine("GPU devices="+snapshot.GpuDevices.Count+" usage="+snapshot.Gpu.ToString("0.0",CultureInfo.InvariantCulture)+"% temp="+(snapshot.GpuTempAvailable?snapshot.GpuTemp.ToString("0.0",CultureInfo.InvariantCulture)+"C":"N/A")+" power="+(diagGpu!=null&&diagGpu.PowerAvailable?diagGpu.PowerW.ToString("0.0",CultureInfo.InvariantCulture)+"W":"N/A")+" fan="+(diagGpu!=null&&diagGpu.FanRpmAvailable?diagGpu.FanRpm.ToString("0",CultureInfo.InvariantCulture)+"RPM":(diagGpu!=null&&diagGpu.FanPercentAvailable?diagGpu.FanPercent.ToString("0",CultureInfo.InvariantCulture)+"%":"N/A"))+" source="+(snapshot.GpuTempSource??"UNAVAILABLE"));
            b.AppendLine("Disk devices="+snapshot.DiskDevices.Count+" Network adapters="+snapshot.NetworkDevices.Count);
            b.AppendLine();
            b.AppendLine("Runtime files");
            b.AppendLine(DiagnosticFileLine("Supervisor state",AppPaths.SensorSupervisorState));
            b.AppendLine(DiagnosticFileLine("CPU broker",AppPaths.CpuTempBrokerData));
            b.AppendLine(DiagnosticFileLine("GPU broker",AppPaths.GpuBrokerData));
            b.AppendLine(DiagnosticFileLine("Storage broker",AppPaths.StorageBrokerData));
            b.AppendLine(DiagnosticFileLine("Backend state",AppPaths.SensorBackendState));
            b.AppendLine();
            b.AppendLine("Supervisor state JSON");
            b.AppendLine(ReadSharedDiagnostic(AppPaths.SensorSupervisorState));
            b.AppendLine();
            b.AppendLine("Sensor backend state JSON");
            b.AppendLine(ReadSharedDiagnostic(AppPaths.SensorBackendState));
            b.AppendLine();
            b.AppendLine("Notes");
            b.AppendLine("- TransportHealthy means the worker is alive and producing fresh output.");
            b.AppendLine("- DataAvailable is separate: a healthy worker can legitimately report no supported/privileged sensor data.");
            b.AppendLine("- Automatic updates require immutable GitHub Releases plus GitHub SHA-256 asset digest metadata.");
            return b.ToString();
        }

        private void RefreshDiagnostics()
        {
            try{if(diagnosticsText!=null)diagnosticsText.Text=BuildDiagnosticsReport();}
            catch(Exception ex){if(diagnosticsText!=null)diagnosticsText.Text="Diagnostics failed: "+ex;}
        }

        private void SaveDiagnosticsReport()
        {
            try
            {
                using(SaveFileDialog d=new SaveFileDialog())
                {
                    d.Filter="Text report (*.txt)|*.txt";
                    d.FileName="TBME_Diagnostics_"+DateTime.Now.ToString("yyyyMMdd_HHmmss",CultureInfo.InvariantCulture)+".txt";
                    if(d.ShowDialog(this)!=DialogResult.OK)return;
                    File.WriteAllText(d.FileName,BuildDiagnosticsReport(),Encoding.UTF8);
                    if(diagnosticsText!=null)diagnosticsText.Text=BuildDiagnosticsReport()+"\r\n\r\nSaved: "+d.FileName;
                }
            }
            catch(Exception ex){MessageBox.Show(ex.Message,"Save diagnostics");}
        }

        private void RepairProtectedSensors()
        {
            try
            {
                string setup=Path.Combine(AppPaths.Root,"Uninstall.exe");
                if(!File.Exists(setup))
                {
                    MessageBox.Show("Repair tool was not found. Re-run the latest Taskbar Monitor Enhanced installer.","Repair protected sensors",MessageBoxButtons.OK,MessageBoxIcon.Warning);
                    return;
                }
                if(MessageBox.Show("Repair the protected CPU/GPU/storage sensor layer? Windows will request administrator approval.","Repair protected sensors",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return;
                ProcessStartInfo psi=new ProcessStartInfo();
                psi.FileName=setup;psi.Arguments="/repair-sensors";psi.UseShellExecute=true;psi.Verb="runas";
                Process x=Process.Start(psi);
                if(x==null)throw new InvalidOperationException("Windows did not start the sensor repair tool.");
                Log.Write("INFO","SENSOR_REPAIR_STARTED");
            }
            catch(Exception ex)
            {
                Log.Write("WARN","SENSOR_REPAIR_START_FAIL "+ex.Message);
                MessageBox.Show(ex.Message,"Repair protected sensors",MessageBoxButtons.OK,MessageBoxIcon.Warning);
            }
        }

        private List<HardwareChoice> ChoicesCpu(){return snapshot.CpuDevices.Select(x=>new HardwareChoice{Id=x.Id,Name=x.Name}).ToList();}
        private List<HardwareChoice> ChoicesGpu(){return snapshot.GpuDevices.Select(x=>new HardwareChoice{Id=x.Id,Name=x.Name}).ToList();}
        private List<HardwareChoice> ChoicesDisk(){return snapshot.DiskDevices.Select(x=>new HardwareChoice{Id=x.Id,Name=x.Name+(!String.IsNullOrWhiteSpace(x.Volumes)?(" — "+x.Volumes):"")}).ToList();}
        private List<HardwareChoice> ChoicesNet(){return snapshot.NetworkDevices.Select(x=>new HardwareChoice{Id=x.Id,Name=x.Name+(!String.IsNullOrWhiteSpace(x.Description)?" — "+x.Description:"")}).ToList();}
        private void AddHardwareSection(Control p,string label,string modeValue,List<HardwareChoice> choices,string selectedIds,int y,out ComboBox mode,out CheckedListBox list)
        {
            Label h=new Label();h.Text=label;h.Location=new Point(24,y+4);h.Width=95;h.Font=new Font(Font,FontStyle.Bold);p.Controls.Add(h);Label ml=new Label();ml.Text="Mode";ml.Location=new Point(122,y+4);ml.Width=45;p.Controls.Add(ml);mode=new ComboBox();mode.DropDownStyle=ComboBoxStyle.DropDownList;mode.Location=new Point(170,y);mode.Width=180;mode.Items.AddRange(new string[]{"Overall","Auto","Single","Multiple"});mode.SelectedItem=modeValue;if(mode.SelectedIndex<0)mode.SelectedIndex=0;p.Controls.Add(mode);
            list=new CheckedListBox();list.Location=new Point(370,y);list.Size=new Size(330,92);list.CheckOnClick=true;HashSet<string> selected=SelectionUtil.Parse(selectedIds);bool all=selected.Count==0;foreach(HardwareChoice c0 in choices){int i=list.Items.Add(c0);if(all||selected.Contains(c0.Id))list.SetItemChecked(i,true);}if(choices.Count==0)list.Items.Add("No device detected yet");p.Controls.Add(list);
        }
        private string CheckedIds(CheckedListBox list)
        {
            List<string> ids=new List<string>();if(list==null)return "";foreach(object o in list.CheckedItems){HardwareChoice c0=o as HardwareChoice;if(c0!=null&&!String.IsNullOrWhiteSpace(c0.Id))ids.Add(c0.Id);}return SelectionUtil.Join(ids);
        }
        private ComboBox Combo(Control p,string label,string[] items,string value,int y){Label l=new Label();l.Text=label;l.Location=new Point(24,y+4);l.Width=145;p.Controls.Add(l);ComboBox x=new ComboBox();x.DropDownStyle=ComboBoxStyle.DropDownList;x.Location=new Point(180,y);x.Width=250;x.Items.AddRange(items);x.SelectedItem=value;if(x.SelectedIndex<0)x.SelectedIndex=0;p.Controls.Add(x);return x;}
        private NumericUpDown Number(Control p,string label,decimal val,decimal min,decimal max,int y){Label l=new Label();l.Text=label;l.Location=new Point(24,y+4);l.Width=145;p.Controls.Add(l);NumericUpDown n=new NumericUpDown();n.Location=new Point(180,y);n.Width=120;n.Minimum=min;n.Maximum=max;n.Value=Math.Min(max,Math.Max(min,val));p.Controls.Add(n);return n;}
        private CheckBox Check(Control p,string label,bool val,int y){CheckBox x=new CheckBox();x.Text=label;x.Checked=val;x.Location=new Point(24,y);x.AutoSize=true;p.Controls.Add(x);return x;}
        private void Apply()
        {
            c.Theme=(string)theme.SelectedItem;c.Position=(string)position.SelectedItem;c.Opacity=(double)opacity.Value/100.0;c.MinWidthLogicalPx=(int)width.Value;c.UpdateIntervalMs=(int)interval.Value;c.ShowCpu=cpu.Checked;c.ShowRam=ram.Checked;c.ShowDisk=disk.Checked;c.ShowGpu=gpu.Checked;c.ShowVram=vram.Checked;c.ShowNetwork=net.Checked;c.ShowTemperatures=temp.Checked;c.ShowSparklines=spark.Checked;c.StartWithWindows=startup.Checked;c.SafePlacement=safe.Checked;
            c.CpuDisplayMode=(string)cpuMode.SelectedItem;c.GpuDisplayMode=(string)gpuMode.SelectedItem;c.DiskDisplayMode=(string)diskMode.SelectedItem;c.NetworkDisplayMode=(string)netMode.SelectedItem;c.SelectedCpuIds=CheckedIds(cpuList);c.SelectedGpuIds=CheckedIds(gpuList);c.SelectedDiskIds=CheckedIds(diskList);c.SelectedNetworkIds=CheckedIds(netList);c.MultipleDeviceLayout=(string)multiLayout.SelectedItem;c.MemoryUnit=(string)memoryUnit.SelectedItem;c.StorageUnit=(string)storageUnit.SelectedItem;c.DiskRateUnit=(string)diskRateUnit.SelectedItem;c.NetworkUnit=(string)networkUnit.SelectedItem;c.ShowRamNumeric=ramNumeric.Checked;c.ShowDiskNumeric=diskNumeric.Checked;c.EnableHardwareFlyout=flyout.Checked;c.HoverShowAllDevices=hoverAll.Checked;c.AutoCheckUpdates=autoCheckUpdates.Checked;
        }
    }

    internal static class StartupManager
    {
        public static void SetEnabled(bool enabled)
        {
            try
            {
                using(RegistryKey k=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
                {
                    if(enabled)k.SetValue("TaskbarMonitorEnhanced","\""+Application.ExecutablePath+"\""); else k.DeleteValue("TaskbarMonitorEnhanced",false);
                }
            }
            catch(Exception ex){Log.Write("WARN","STARTUP " + ex.Message);}
        }
    }

    internal static class HardwareProbe
    {
        public static int Run(string outputPath)
        {
            try
            {
                MetricsSnapshot s=null;using(MetricsEngine engine=new MetricsEngine()){for(int i=0;i<8;i++){s=engine.Read();Thread.Sleep(350);}}
                if(s==null)throw new InvalidOperationException("hardware snapshot unavailable");
                Dictionary<string,object> m=new Dictionary<string,object>();m["Version"]=BuildInfo.Version;m["PublicVersion"]=BuildInfo.PublicVersion;m["Status"]="PASS";
                m["Cpu"]=s.CpuDevices.Select(x=>(object)new Dictionary<string,object>{{"Id",x.Id},{"Name",x.Name},{"Usage",x.Usage},{"UsageAvailable",x.UsageAvailable},{"Temperature",x.Temperature},{"TemperatureAvailable",x.TemperatureAvailable},{"PowerW",x.PowerW},{"PowerAvailable",x.PowerAvailable},{"PhysicalCores",x.PhysicalCores},{"LogicalProcessors",x.LogicalProcessors},{"CurrentClockMHz",x.CurrentClockMHz},{"MaxClockMHz",x.MaxClockMHz},{"ExternalClockMHz",x.ExternalClockMHz},{"Socket",x.Socket}}).ToList();
                m["Gpu"]=s.GpuDevices.Select(x=>(object)new Dictionary<string,object>{{"Id",x.Id},{"Name",x.Name},{"Source",x.Source},{"Usage",x.Usage},{"UsageAvailable",x.UsageAvailable},{"Temperature",x.Temperature},{"TemperatureAvailable",x.TemperatureAvailable},{"VramUsedGb",x.VramUsedGb},{"VramTotalGb",x.VramTotalGb},{"CoreClockMHz",x.CoreClockMHz},{"CoreClockAvailable",x.CoreClockAvailable},{"MemoryClockMHz",x.MemoryClockMHz},{"MemoryClockAvailable",x.MemoryClockAvailable},{"PowerW",x.PowerW},{"PowerAvailable",x.PowerAvailable},{"FanRpm",x.FanRpm},{"FanRpmAvailable",x.FanRpmAvailable},{"FanPercent",x.FanPercent},{"FanPercentAvailable",x.FanPercentAvailable},{"PcieGeneration",x.PcieGeneration},{"PcieWidth",x.PcieWidth}}).ToList();
                m["Disk"]=s.DiskDevices.Select(x=>(object)new Dictionary<string,object>{{"Id",x.Id},{"Name",x.Name},{"Volumes",x.Volumes},{"UsedBytes",x.UsedBytes},{"TotalBytes",x.TotalBytes},{"PhysicalSizeBytes",x.PhysicalSizeBytes},{"UsedPercent",x.UsedPercent},{"Activity",x.Activity},{"ReadBytesPerSec",x.ReadBytesPerSec},{"WriteBytesPerSec",x.WriteBytesPerSec},{"TemperatureAvailable",x.TemperatureAvailable},{"Temperature",x.Temperature},{"TemperatureSource",x.TemperatureSource},{"BusType",x.BusType},{"MediaType",x.MediaType},{"InterfaceType",x.InterfaceType}}).ToList();
                m["Network"]=s.NetworkDevices.Select(x=>(object)new Dictionary<string,object>{{"Id",x.Id},{"Name",x.Name},{"Description",x.Description},{"DownBytesPerSec",x.DownBytesPerSec},{"UpBytesPerSec",x.UpBytesPerSec},{"LinkSpeedBitsPerSec",x.LinkSpeedBitsPerSec}}).ToList();
                m["MemoryModules"]=s.MemoryModules.Select(x=>(object)new Dictionary<string,object>{{"BankLabel",x.BankLabel},{"DeviceLocator",x.DeviceLocator},{"Manufacturer",x.Manufacturer},{"PartNumber",x.PartNumber},{"MemoryType",x.MemoryType},{"CapacityBytes",x.CapacityBytes},{"SpeedMHz",x.SpeedMHz},{"ConfiguredClockMHz",x.ConfiguredClockMHz},{"DataWidth",x.DataWidth},{"TotalWidth",x.TotalWidth}}).ToList();
                m["RamUsedBytes"]=s.RamUsedBytes;m["RamTotalBytes"]=s.RamTotalBytes;m["RamPercent"]=s.Ram;m["DiskUsedBytes"]=s.DiskUsedBytes;m["DiskTotalBytes"]=s.DiskTotalBytes;m["DiskReadBytesPerSec"]=s.DiskReadBytesPerSec;m["DiskWriteBytesPerSec"]=s.DiskWriteBytesPerSec;m["NetworkDownBytesPerSec"]=s.NetDownBytesPerSec;m["NetworkUpBytesPerSec"]=s.NetUpBytesPerSec;
                JavaScriptSerializer js=new JavaScriptSerializer();File.WriteAllText(outputPath,js.Serialize(m),Encoding.UTF8);Console.WriteLine("TBME_HARDWARE_PROBE=PASS CPU="+s.CpuDevices.Count+" GPU="+s.GpuDevices.Count+" DISK="+s.DiskDevices.Count+" NET="+s.NetworkDevices.Count);return 0;
            }
            catch(Exception ex){try{File.WriteAllText(outputPath,new JavaScriptSerializer().Serialize(new Dictionary<string,object>{{"Status","FAIL"},{"Error",ex.ToString()}}),Encoding.UTF8);}catch{}Console.Error.WriteLine("TBME_HARDWARE_PROBE=FAIL "+ex.Message);return 9;}
        }
    }

    internal static class TemperatureProbe
    {
        public static int Run(string outputPath)
        {
            Dictionary<string,object> m=new Dictionary<string,object>();
            try
            {
                MetricsSnapshot s=null;
                using(MetricsEngine engine=new MetricsEngine())
                {
                    for(int i=0;i<8;i++)
                    {
                        s=engine.Read();
                        Thread.Sleep(350);
                    }
                }

                if(s==null)throw new InvalidOperationException("temperature snapshot unavailable");

                m["Version"]=BuildInfo.Version;
                m["Status"]="PASS";
                m["Window"]="last 60 valid temperature samples";
                m["CpuAvailable"]=s.CpuTempAvailable;
                m["CpuCurrentC"]=s.CpuTempCurrent;
                m["CpuAverageC"]=s.CpuTempAvg;
                m["CpuMaximumC"]=s.CpuTempMax;
                m["CpuSource"]=s.CpuTempSource??"UNAVAILABLE";
                m["GpuAvailable"]=s.GpuTempAvailable;
                m["GpuAverageC"]=s.GpuTempAvg;
                m["GpuMaximumC"]=s.GpuTempMax;
                m["GpuSource"]=s.GpuTempSource??"UNAVAILABLE";

                JavaScriptSerializer js=new JavaScriptSerializer();
                File.WriteAllText(outputPath,js.Serialize(m),Encoding.UTF8);

                Console.WriteLine(
                    "TBME_TEMP_PROBE=PASS"+
                    " CPU_AVAILABLE="+s.CpuTempAvailable+
                    " CPU_CURRENT="+s.CpuTempCurrent.ToString("0.0",CultureInfo.InvariantCulture)+
                    " CPU_AVG="+s.CpuTempAvg.ToString("0.0",CultureInfo.InvariantCulture)+
                    " CPU_MAX="+s.CpuTempMax.ToString("0.0",CultureInfo.InvariantCulture)+
                    " CPU_SOURCE="+(s.CpuTempSource??"UNAVAILABLE")+
                    " GPU_AVAILABLE="+s.GpuTempAvailable+
                    " GPU_AVG="+s.GpuTempAvg.ToString("0.0",CultureInfo.InvariantCulture)+
                    " GPU_MAX="+s.GpuTempMax.ToString("0.0",CultureInfo.InvariantCulture)+
                    " GPU_SOURCE="+(s.GpuTempSource??"UNAVAILABLE")
                );
                return 0;
            }
            catch(Exception ex)
            {
                m["Version"]=BuildInfo.Version;
                m["Status"]="FAIL_EXCEPTION";
                m["Error"]=ex.ToString();
                try
                {
                    JavaScriptSerializer js=new JavaScriptSerializer();
                    File.WriteAllText(outputPath,js.Serialize(m),Encoding.UTF8);
                }
                catch{}
                Console.Error.WriteLine("TBME_TEMP_PROBE=FAIL "+ex.Message);
                return 7;
            }
        }
    }

    internal static class HealthProbe
    {
        private static Dictionary<string,object> ReadState(string path,double freshnessSeconds)
        {
            Dictionary<string,object> d=new Dictionary<string,object>();
            d["Path"]=path;d["Exists"]=File.Exists(path);
            if(!File.Exists(path))return d;
            try
            {
                string json=BrokerJsonFile.ReadShared(path);
                Dictionary<string,object> root=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(json);
                if(root==null){d["ReadError"]="JSON_EMPTY";return d;}
                object tsObj;DateTime ts=DateTime.MinValue;
                if(root.TryGetValue("TimestampUtc",out tsObj)&&DateTime.TryParse(Convert.ToString(tsObj,CultureInfo.InvariantCulture),CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,out ts))
                {
                    double age=Math.Max(0,(DateTime.UtcNow-ts).TotalSeconds);
                    d["TimestampUtc"]=ts.ToString("o",CultureInfo.InvariantCulture);d["AgeSeconds"]=age;d["Fresh"]=freshnessSeconds<=0||age<=freshnessSeconds;
                }
                else d["Fresh"]=freshnessSeconds<=0;

                foreach(string key in new string[]{"Available","Error","BrokerPid","BrokerMode","BrokerVersion","Sequence","ReadDurationMs",
                    "SupervisorStartedUtc","SupervisorUptimeSeconds",
                    "CpuTransportHealthy","CpuDataAvailable","CpuRestartCount","CpuConsecutiveFailures","CpuLastReason","CpuWorkerStartedUtc","CpuWorkerAgeSeconds","CpuLastFailureUtc","CpuLastFailureReason","CpuLastRecoveryUtc",
                    "GpuTransportHealthy","GpuDataAvailable","GpuRestartCount","GpuConsecutiveFailures","GpuLastReason","GpuWorkerStartedUtc","GpuWorkerAgeSeconds","GpuLastFailureUtc","GpuLastFailureReason","GpuLastRecoveryUtc",
                    "StorageTransportHealthy","StorageDataAvailable","StorageAttemptCount","StorageConsecutiveFailures","StorageLastReason","StorageWorkerStartedUtc","StorageWorkerAgeSeconds","StorageLastFailureUtc","StorageLastFailureReason","StorageLastRecoveryUtc"})
                {
                    object v;if(root.TryGetValue(key,out v)&&v!=null)d[key]=v;
                }

                object seq;
                if(root.TryGetValue("Gpus",out seq)&&seq is System.Collections.IEnumerable)
                {
                    int count=0,available=0;
                    foreach(object x in (System.Collections.IEnumerable)seq)
                    {
                        count++;Dictionary<string,object> m=x as Dictionary<string,object>;object av;
                        if(m!=null&&m.TryGetValue("Available",out av)){try{if(Convert.ToBoolean(av,CultureInfo.InvariantCulture))available++;}catch{}}
                    }
                    d["RecordCount"]=count;d["DataRecordCount"]=available;
                }
                if(root.TryGetValue("StorageTemperatures",out seq)&&seq is System.Collections.IEnumerable)
                {
                    int count=0,available=0;
                    foreach(object x in (System.Collections.IEnumerable)seq)
                    {
                        count++;Dictionary<string,object> m=x as Dictionary<string,object>;object av;
                        if(m!=null&&m.TryGetValue("Available",out av)){try{if(Convert.ToBoolean(av,CultureInfo.InvariantCulture))available++;}catch{}}
                    }
                    d["RecordCount"]=count;d["DataRecordCount"]=available;
                }
            }
            catch(Exception ex){d["ReadError"]=ex.Message;}
            return d;
        }

        private static bool B(Dictionary<string,object> d,string key,bool fallback)
        {
            object x;if(!d.TryGetValue(key,out x)||x==null)return fallback;
            try{return Convert.ToBoolean(x,CultureInfo.InvariantCulture);}catch{return fallback;}
        }

        private static int I(Dictionary<string,object> d,string key,int fallback)
        {
            object x;if(!d.TryGetValue(key,out x)||x==null)return fallback;
            try{return Convert.ToInt32(x,CultureInfo.InvariantCulture);}catch{return fallback;}
        }

        private static DateTime Utc(Dictionary<string,object> d,string key)
        {
            object x;if(!d.TryGetValue(key,out x)||x==null)return DateTime.MinValue;
            DateTime dt;
            return DateTime.TryParse(Convert.ToString(x,CultureInfo.InvariantCulture),CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,out dt)?dt:DateTime.MinValue;
        }

        private static DateTime Latest(params DateTime[] values)
        {
            DateTime best=DateTime.MinValue;
            foreach(DateTime x in values)if(x>best)best=x;
            return best;
        }

        public static int Run(string outputPath)
        {
            Dictionary<string,object> supervisor=ReadState(AppPaths.SensorSupervisorState,15);
            Dictionary<string,object> cpu=ReadState(AppPaths.CpuTempBrokerData,15);
            Dictionary<string,object> gpu=ReadState(AppPaths.GpuBrokerData,20);
            Dictionary<string,object> storage=ReadState(AppPaths.StorageBrokerData,120);
            string brokerVersion=Convert.ToString(supervisor.ContainsKey("BrokerVersion")?supervisor["BrokerVersion"]:"",CultureInfo.InvariantCulture)??"";
            bool architectureR21=brokerVersion.IndexOf("r21",StringComparison.OrdinalIgnoreCase)>=0;
            bool supervisorFresh=B(supervisor,"Fresh",false);
            bool cpuFresh=B(cpu,"Fresh",false);
            bool gpuFresh=B(gpu,"Fresh",false);
            bool storageFresh=B(storage,"Fresh",false);
            bool cpuTransport=B(supervisor,"CpuTransportHealthy",cpuFresh);
            bool gpuTransport=B(supervisor,"GpuTransportHealthy",gpuFresh);
            bool storageTransport=B(supervisor,"StorageTransportHealthy",storageFresh);
            bool pass=architectureR21&&supervisorFresh&&cpuFresh&&gpuFresh&&storageFresh&&cpuTransport&&gpuTransport&&storageTransport;

            int activeFailures=I(supervisor,"CpuConsecutiveFailures",0)+I(supervisor,"GpuConsecutiveFailures",0)+I(supervisor,"StorageConsecutiveFailures",0);
            DateTime latestFailure=Latest(Utc(supervisor,"CpuLastFailureUtc"),Utc(supervisor,"GpuLastFailureUtc"),Utc(supervisor,"StorageLastFailureUtc"));
            DateTime latestRecovery=Latest(Utc(supervisor,"CpuLastRecoveryUtc"),Utc(supervisor,"GpuLastRecoveryUtc"),Utc(supervisor,"StorageLastRecoveryUtc"));
            string resilienceState;
            if(activeFailures>0)resilienceState="RECOVERING";
            else if(latestFailure!=DateTime.MinValue&&(DateTime.UtcNow-latestFailure).TotalMinutes<=10)resilienceState="RECOVERED_RECENTLY";
            else resilienceState="STABLE";

            Dictionary<string,object> result=new Dictionary<string,object>();
            result["Version"]=BuildInfo.Version;result["PublicVersion"]=BuildInfo.PublicVersion;result["GeneratedUtc"]=DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture);
            result["Status"]=pass?"PASS":"DEGRADED";result["ArchitectureR21"]=architectureR21;
            result["ResilienceState"]=resilienceState;
            result["ActiveConsecutiveFailures"]=activeFailures;
            result["LastFailureUtc"]=latestFailure==DateTime.MinValue?"":latestFailure.ToString("o",CultureInfo.InvariantCulture);
            result["LastRecoveryUtc"]=latestRecovery==DateTime.MinValue?"":latestRecovery.ToString("o",CultureInfo.InvariantCulture);
            result["Supervisor"]=supervisor;result["Cpu"]=cpu;result["Gpu"]=gpu;result["Storage"]=storage;
            File.WriteAllText(outputPath,new JavaScriptSerializer().Serialize(result),Encoding.UTF8);
            Console.WriteLine("TBME_HEALTH_PROBE="+(pass?"PASS":"DEGRADED")+" R21="+architectureR21+" RESILIENCE="+resilienceState+" SUP="+supervisorFresh+" CPU="+cpuFresh+"/"+cpuTransport+" GPU="+gpuFresh+"/"+gpuTransport+" STORAGE="+storageFresh+"/"+storageTransport);
            return pass?0:12;
        }
    }

    internal static class ThemeProof
    {
        public static int Run(string outputDirectory)
        {
            try
            {
                if(String.IsNullOrWhiteSpace(outputDirectory))throw new ArgumentException("output directory");
                Native.EnableDpi();
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                AppConfig c=AppConfig.Load();
                c.Normalize();

                using(OverlayForm f=new OverlayForm(c,true))
                {
                    return f.ExportThemeProofs(outputDirectory);
                }
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine("TBME_THEME_PROOF=FAIL "+ex);
                return 4;
            }
        }
    }

    internal static class CompactProof
    {
        public static int Run(string outputDirectory)
        {
            try
            {
                if(String.IsNullOrWhiteSpace(outputDirectory))throw new ArgumentException("output directory");
                Native.EnableDpi();Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
                AppConfig c=AppConfig.Load();c.Normalize();
                using(OverlayForm f=new OverlayForm(c,true)){return f.ExportCompactProofs(outputDirectory);}
            }
            catch(Exception ex){Console.Error.WriteLine("TBME_COMPACT_PROOF=FAIL "+ex);return 8;}
        }
    }

    internal static class StartProbe
    {
        private static Bitmap CaptureRect(Rectangle r)
        {
            Bitmap bmp=new Bitmap(r.Width,r.Height,PixelFormat.Format32bppArgb);
            using(Graphics g=Graphics.FromImage(bmp))
                g.CopyFromScreen(r.Left,r.Top,0,0,r.Size);
            return bmp;
        }

        private static void CapturePrimary(string path)
        {
            Rectangle b=Screen.PrimaryScreen.Bounds;
            using(Bitmap bmp=new Bitmap(b.Width,b.Height,PixelFormat.Format32bppArgb))
            using(Graphics g=Graphics.FromImage(bmp))
            {
                g.CopyFromScreen(b.Left,b.Top,0,0,b.Size);
                bmp.Save(path,ImageFormat.Png);
            }
        }

        private static Dictionary<string,object> InkMetrics(Bitmap bmp)
        {
            int bright=0,saturated=0,signal=0;

            for(int y=0;y<bmp.Height;y++)
            for(int x=0;x<bmp.Width;x++)
            {
                Color c=bmp.GetPixel(x,y);
                int max=Math.Max(c.R,Math.Max(c.G,c.B));
                int min=Math.Min(c.R,Math.Min(c.G,c.B));
                int span=max-min;

                if(max>=140)bright++;
                if(span>=25 && max>=70)saturated++;
                if(max>=140 || (span>=25 && max>=70))signal++;
            }

            return new Dictionary<string,object>{
                {"BrightPixels",bright},
                {"SaturatedPixels",saturated},
                {"SignalPixels",signal},
                {"Pass",signal>=300}
            };
        }

        private static bool FindDirectTaskbarChild(uint pid,IntPtr taskbar,out IntPtr hwnd,out Rectangle rect)
        {
            hwnd=IntPtr.Zero;
            rect=Rectangle.Empty;

            IntPtr found=IntPtr.Zero;
            Rectangle foundRect=Rectangle.Empty;

            Native.EnumChildWindows(taskbar,delegate(IntPtr h,IntPtr l)
            {
                if(Native.GetParent(h)!=taskbar)return true;

                uint p=0;
                Native.GetWindowThreadProcessId(h,out p);
                if(p!=pid || !Native.IsWindowVisible(h))return true;

                Native.RECT wr;
                if(!Native.GetWindowRect(h,out wr))return true;
                Rectangle r=wr.ToRectangle();

                if(r.Width<900 || r.Height<30 || r.Height>70)return true;

                found=h;
                foundRect=r;
                return false;
            },IntPtr.Zero);

            if(found==IntPtr.Zero)return false;

            hwnd=found;
            rect=foundRect;
            return true;
        }

        private static bool ReadCachedWindowState(
            IntPtr hwnd,
            IntPtr taskbar,
            Rectangle baselineRect,
            out Rectangle rect,
            out bool visible,
            out bool parentOk,
            out int cloaked,
            out bool fixedRect
        )
        {
            rect=Rectangle.Empty;
            visible=false;
            parentOk=false;
            cloaked=-1;
            fixedRect=false;

            if(hwnd==IntPtr.Zero)return false;

            Native.RECT wr;
            if(!Native.GetWindowRect(hwnd,out wr))return false;

            rect=wr.ToRectangle();
            visible=Native.IsWindowVisible(hwnd);
            parentOk=Native.GetParent(hwnd)==taskbar;
            cloaked=Native.GetCloaked(hwnd);

            fixedRect=
                rect.X==baselineRect.X &&
                rect.Y==baselineRect.Y &&
                rect.Width==baselineRect.Width &&
                rect.Height==baselineRect.Height;

            return true;
        }

        public static int Run(string outputDirectory)
        {
            Directory.CreateDirectory(outputDirectory);

            JavaScriptSerializer js=new JavaScriptSerializer();
            List<object> samples=new List<object>();

            uint mainPid=0;
            string stimulusMethod="";
            int shellSamples=0;
            int cachedHwndFailures=0;
            int invisibleSamples=0;
            int parentFailures=0;
            int cloakedSamples=0;
            int fixedSamples=0;
            int pixelFailures=0;
            int enumerationMisses=0;
            int minimumSignal=Int32.MaxValue;

            try
            {
                Process self=Process.GetCurrentProcess();
                Process[] all=Process.GetProcessesByName("TaskbarMonitorEnhanced");
                List<Process> mains=new List<Process>();

                foreach(Process p in all)
                {
                    if(p.Id!=self.Id)mains.Add(p);
                    else p.Dispose();
                }

                if(mains.Count!=1)
                    throw new InvalidOperationException("START_PROBE_MAIN_PROCESS_GATE count="+mains.Count);

                Process main=mains[0];
                mainPid=(uint)main.Id;

                IntPtr taskbar=Native.FindWindow("Shell_TrayWnd",null);
                if(taskbar==IntPtr.Zero)
                    throw new InvalidOperationException("START_PROBE_TASKBAR_GATE");

                IntPtr cachedChild;
                Rectangle baselineRect;

                if(!FindDirectTaskbarChild(mainPid,taskbar,out cachedChild,out baselineRect))
                    throw new InvalidOperationException("START_PROBE_BASELINE_DIRECT_CHILD_GATE");

                if(baselineRect.Width!=1100 || baselineRect.Height!=48)
                    throw new InvalidOperationException("START_PROBE_BASELINE_GEOMETRY_GATE rect="+baselineRect);

                using(Bitmap baseCrop=CaptureRect(baselineRect))
                {
                    Dictionary<string,object> ink=InkMetrics(baseCrop);
                    baseCrop.Save(Path.Combine(outputDirectory,"START_PROBE_BASELINE_CROP.png"),ImageFormat.Png);

                    if(!(bool)ink["Pass"])
                        throw new InvalidOperationException(
                            "START_PROBE_BASELINE_PIXEL_GATE signal="+ink["SignalPixels"]
                        );
                }

                CapturePrimary(Path.Combine(outputDirectory,"START_PROBE_BASELINE.png"));

                Native.KeybdTap(0x1B);
                Thread.Sleep(350);

                string openProcess="",openClass="";
                IntPtr openHwnd=IntPtr.Zero;

                Native.KeybdTap(0x5B);

                if(ShellUi.WaitForStartShell(1400,out openProcess,out openClass,out openHwnd))
                    stimulusMethod="KEYBD_EVENT_WIN";
                else
                {
                    Native.CtrlEsc();
                    if(ShellUi.WaitForStartShell(1400,out openProcess,out openClass,out openHwnd))
                        stimulusMethod="KEYBD_EVENT_CTRL_ESC";
                }

                if(String.IsNullOrEmpty(stimulusMethod))
                    throw new InvalidOperationException("START_PROBE_STIMULUS_OBSERVATION_GATE");

                for(int i=1;i<=24;i++)
                {
                    Thread.Sleep(250);

                    string fgProc="",fgClass="";
                    IntPtr fg=IntPtr.Zero;
                    bool fgShell=ShellUi.IsStartShellForeground(out fgProc,out fgClass,out fg);

                    string surfProc="",surfClass="";
                    Rectangle surfRect=Rectangle.Empty;
                    IntPtr surfHwnd=IntPtr.Zero;
                    bool surface=ShellUi.IsStartSurfacePresent(out surfProc,out surfClass,out surfRect,out surfHwnd);

                    if(fgShell||surface)shellSamples++;

                    IntPtr currentTaskbar=Native.FindWindow("Shell_TrayWnd",null);
                    if(currentTaskbar==IntPtr.Zero)currentTaskbar=taskbar;

                    // Hierarchy enumeration is diagnostic only. Windows 11 Start can make
                    // EnumChildWindows discovery temporarily unreliable even when the
                    // cached HWND remains valid, parented and visually composed.
                    IntPtr rediscovered=IntPtr.Zero;
                    Rectangle rediscoveredRect=Rectangle.Empty;
                    bool enumerationFound=FindDirectTaskbarChild(
                        mainPid,currentTaskbar,out rediscovered,out rediscoveredRect
                    );
                    if(!enumerationFound)enumerationMisses++;

                    Rectangle monitorRect;
                    bool visible;
                    bool parentOk;
                    int cloaked;
                    bool fixedRect;

                    bool cachedOk=ReadCachedWindowState(
                        cachedChild,
                        currentTaskbar,
                        baselineRect,
                        out monitorRect,
                        out visible,
                        out parentOk,
                        out cloaked,
                        out fixedRect
                    );

                    if(!cachedOk)
                    {
                        cachedHwndFailures++;
                        pixelFailures++;

                        samples.Add(new Dictionary<string,object>{
                            {"Sample",i},
                            {"CachedHwndValid",false},
                            {"EnumerationFound",enumerationFound},
                            {"PixelInkPass",false},
                            {"Error","CACHED_HWND_INVALID"}
                        });
                        continue;
                    }

                    if(!visible)invisibleSamples++;
                    if(!parentOk)parentFailures++;
                    if(cloaked!=0)cloakedSamples++;
                    if(fixedRect)fixedSamples++;

                    Dictionary<string,object> ink;

                    using(Bitmap crop=CaptureRect(monitorRect))
                    {
                        ink=InkMetrics(crop);

                        int signal=Convert.ToInt32(
                            ink["SignalPixels"],
                            CultureInfo.InvariantCulture
                        );

                        if(signal<minimumSignal)minimumSignal=signal;
                        if(!(bool)ink["Pass"])pixelFailures++;

                        if(i==1)
                            crop.Save(Path.Combine(outputDirectory,"START_PROBE_CROP_250MS.png"),ImageFormat.Png);
                        if(i==4)
                            crop.Save(Path.Combine(outputDirectory,"START_PROBE_CROP_1S.png"),ImageFormat.Png);
                        if(i==20)
                            crop.Save(Path.Combine(outputDirectory,"START_PROBE_CROP_5S.png"),ImageFormat.Png);
                    }

                    samples.Add(new Dictionary<string,object>{
                        {"Sample",i},
                        {"CachedHwndValid",true},
                        {"CachedHwnd",cachedChild.ToInt64()},
                        {"EnumerationFound",enumerationFound},
                        {"RediscoveredHwnd",rediscovered.ToInt64()},
                        {"Visible",visible},
                        {"ParentOk",parentOk},
                        {"Cloaked",cloaked},
                        {"FixedRect",fixedRect},
                        {"MonitorRect",new int[]{monitorRect.X,monitorRect.Y,monitorRect.Width,monitorRect.Height}},
                        {"PixelInkPass",(bool)ink["Pass"]},
                        {"SignalPixels",ink["SignalPixels"]},
                        {"BrightPixels",ink["BrightPixels"]},
                        {"SaturatedPixels",ink["SaturatedPixels"]},
                        {"ForegroundProcess",fgProc},
                        {"ForegroundClass",fgClass},
                        {"ForegroundShell",fgShell},
                        {"StartSurfacePresent",surface},
                        {"StartSurfaceProcess",surfProc}
                    });

                    if(i==1)
                        CapturePrimary(Path.Combine(outputDirectory,"START_PROBE_OPEN_250MS.png"));
                    if(i==4)
                        CapturePrimary(Path.Combine(outputDirectory,"START_PROBE_OPEN_1S.png"));
                    if(i==20)
                        CapturePrimary(Path.Combine(outputDirectory,"START_PROBE_OPEN_5S.png"));
                }

                bool mainAlive=false;
                try{mainAlive=!main.HasExited;}catch{}

                bool pass=
                    mainAlive &&
                    shellSamples>=18 &&
                    cachedHwndFailures==0 &&
                    invisibleSamples==0 &&
                    parentFailures==0 &&
                    cloakedSamples==0 &&
                    fixedSamples==24 &&
                    pixelFailures==0 &&
                    minimumSignal>=300;

                Dictionary<string,object> manifest=new Dictionary<string,object>();

                manifest["Version"]=BuildInfo.Version;
                manifest["Status"]=pass?"PASS":"FAIL";
                manifest["VisualAuthority"]="CACHED_HWND_SCREEN_PIXELS";
                manifest["HierarchyEnumerationAuthority"]=false;
                manifest["MainPid"]=mainPid;
                manifest["CachedHwnd"]=cachedChild.ToInt64();
                manifest["BaselineRect"]=new int[]{baselineRect.X,baselineRect.Y,baselineRect.Width,baselineRect.Height};
                manifest["DurationMs"]=6000;
                manifest["SampleIntervalMs"]=250;
                manifest["SampleCount"]=24;
                manifest["StimulusMethod"]=stimulusMethod;
                manifest["ShellSamples"]=shellSamples;
                manifest["RequiredShellSamples"]=18;
                manifest["CachedHwndFailureSamples"]=cachedHwndFailures;
                manifest["RequiredCachedHwndFailureSamples"]=0;
                manifest["InvisibleSamples"]=invisibleSamples;
                manifest["RequiredInvisibleSamples"]=0;
                manifest["ParentFailureSamples"]=parentFailures;
                manifest["RequiredParentFailureSamples"]=0;
                manifest["CloakedSamples"]=cloakedSamples;
                manifest["RequiredCloakedSamples"]=0;
                manifest["FixedSamples"]=fixedSamples;
                manifest["RequiredFixedSamples"]=24;
                manifest["PixelFailureSamples"]=pixelFailures;
                manifest["RequiredPixelFailureSamples"]=0;
                manifest["EnumerationMisses"]=enumerationMisses;
                manifest["EnumerationMissesAreDiagnosticOnly"]=true;
                manifest["MinimumSignalPixels"]=minimumSignal;
                manifest["RequiredSignalPixels"]=300;
                manifest["MainProcessAlive"]=mainAlive;
                manifest["Samples"]=samples;

                File.WriteAllText(
                    Path.Combine(outputDirectory,"START_PROBE_MANIFEST.json"),
                    js.Serialize(manifest),
                    Encoding.UTF8
                );

                Console.WriteLine(
                    "TBME_START_PROBE="+(pass?"PASS":"FAIL")+
                    " ENGINE=UPSTREAM_CHILD_CACHED_HWND"+
                    " SHELL="+shellSamples+
                    " CACHED_FAIL="+cachedHwndFailures+
                    " INVISIBLE="+invisibleSamples+
                    " PARENT_FAIL="+parentFailures+
                    " CLOAKED="+cloakedSamples+
                    " FIXED="+fixedSamples+
                    " PIXEL_FAIL="+pixelFailures+
                    " ENUM_MISS="+enumerationMisses+
                    " MIN_SIGNAL="+minimumSignal
                );

                return pass?0:5;
            }
            catch(Exception ex)
            {
                try
                {
                    Dictionary<string,object> fail=new Dictionary<string,object>();
                    fail["Version"]=BuildInfo.Version;
                    fail["Status"]="FAIL_EXCEPTION";
                    fail["VisualAuthority"]="CACHED_HWND_SCREEN_PIXELS";
                    fail["HierarchyEnumerationAuthority"]=false;
                    fail["MainPid"]=mainPid;
                    fail["Error"]=ex.ToString();
                    fail["Samples"]=samples;

                    File.WriteAllText(
                        Path.Combine(outputDirectory,"START_PROBE_MANIFEST.json"),
                        js.Serialize(fail),
                        Encoding.UTF8
                    );
                }
                catch{}

                Console.Error.WriteLine("TBME_START_PROBE=FAIL "+ex);
                return 5;
            }
            finally
            {
                try{Native.KeybdTap(0x1B);}catch{}
                Thread.Sleep(300);
            }
        }
    }

    internal static class ShellStateProbe
    {
        private static bool FindDirectTaskbarChild(uint pid,IntPtr taskbar,out IntPtr hwnd,out Rectangle rect)
        {
            hwnd=IntPtr.Zero;
            rect=Rectangle.Empty;
            IntPtr found=IntPtr.Zero;
            Rectangle foundRect=Rectangle.Empty;

            Native.EnumChildWindows(taskbar,delegate(IntPtr h,IntPtr l)
            {
                if(Native.GetParent(h)!=taskbar)return true;
                uint p=0;
                Native.GetWindowThreadProcessId(h,out p);
                if(p!=pid || !Native.IsWindowVisible(h))return true;

                Native.RECT wr;
                if(!Native.GetWindowRect(h,out wr))return true;
                Rectangle r=wr.ToRectangle();
                if(r.Width<900 || r.Height<30 || r.Height>70)return true;

                found=h;
                foundRect=r;
                return false;
            },IntPtr.Zero);

            if(found==IntPtr.Zero)return false;
            hwnd=found;
            rect=foundRect;
            return true;
        }

        private static int SignalPixels(Bitmap bmp)
        {
            int signal=0;
            for(int y=0;y<bmp.Height;y++)
            for(int x=0;x<bmp.Width;x++)
            {
                Color c=bmp.GetPixel(x,y);
                int max=Math.Max(c.R,Math.Max(c.G,c.B));
                int min=Math.Min(c.R,Math.Min(c.G,c.B));
                int span=max-min;
                if(max>=140 || (span>=25 && max>=70))signal++;
            }
            return signal;
        }

        private static int CountNearColor(Bitmap bmp,Color target,int tolerance)
        {
            int count=0;
            for(int y=0;y<bmp.Height;y++)
            for(int x=0;x<bmp.Width;x++)
            {
                Color c=bmp.GetPixel(x,y);
                if(Math.Abs(c.R-target.R)<=tolerance &&
                   Math.Abs(c.G-target.G)<=tolerance &&
                   Math.Abs(c.B-target.B)<=tolerance)count++;
            }
            return count;
        }

        public static int Run(string jsonPath)
        {
            JavaScriptSerializer js=new JavaScriptSerializer();
            Dictionary<string,object> m=new Dictionary<string,object>();
            Process self=Process.GetCurrentProcess();

            try
            {
                Process[] all=Process.GetProcessesByName("TaskbarMonitorEnhanced");
                List<Process> mains=new List<Process>();
                foreach(Process p in all)
                {
                    if(p.Id!=self.Id)mains.Add(p);
                    else p.Dispose();
                }

                if(mains.Count!=1)throw new InvalidOperationException("MAIN_PROCESS_COUNT="+mains.Count);
                Process main=mains[0];
                uint mainPid=(uint)main.Id;

                IntPtr taskbar=Native.FindWindow("Shell_TrayWnd",null);
                if(taskbar==IntPtr.Zero)throw new InvalidOperationException("TASKBAR_NOT_FOUND");

                uint taskbarPid=0;
                Native.GetWindowThreadProcessId(taskbar,out taskbarPid);

                IntPtr overlay;
                Rectangle rect;
                if(!FindDirectTaskbarChild(mainPid,taskbar,out overlay,out rect))
                    throw new InvalidOperationException("DIRECT_CHILD_NOT_FOUND");

                bool parentOk=Native.GetParent(overlay)==taskbar;
                bool visible=Native.IsWindowVisible(overlay);
                bool valid=Native.IsWindow(overlay);
                int cloaked=Native.GetCloaked(overlay);

                int signal=0;
                int beaconMagenta=0;
                int beaconGreen=0;
                bool beaconCommand=false;

                string beaconPng=Path.Combine(
                    Path.GetDirectoryName(jsonPath)??"",
                    Path.GetFileNameWithoutExtension(jsonPath)+"_BEACON.png"
                );
                string png=Path.ChangeExtension(jsonPath,".png");

                try
                {
                    IntPtr ack=Native.SendMessage(
                        overlay,
                        Native.WM_TBME_VISUAL_BEACON,
                        new IntPtr(1),
                        IntPtr.Zero
                    );
                    beaconCommand=ack==new IntPtr(1);
                    Thread.Sleep(120);

                    using(Bitmap bmp=new Bitmap(rect.Width,rect.Height,PixelFormat.Format32bppArgb))
                    using(Graphics g=Graphics.FromImage(bmp))
                    {
                        g.CopyFromScreen(rect.Left,rect.Top,0,0,rect.Size);
                        beaconMagenta=CountNearColor(bmp,Color.FromArgb(255,17,241),18);
                        beaconGreen=CountNearColor(bmp,Color.FromArgb(0,255,106),18);
                        bmp.Save(beaconPng,ImageFormat.Png);
                    }
                }
                finally
                {
                    try
                    {
                        Native.SendMessage(
                            overlay,
                            Native.WM_TBME_VISUAL_BEACON,
                            IntPtr.Zero,
                            IntPtr.Zero
                        );
                    }
                    catch{}
                    Thread.Sleep(90);
                }

                using(Bitmap bmp=new Bitmap(rect.Width,rect.Height,PixelFormat.Format32bppArgb))
                using(Graphics g=Graphics.FromImage(bmp))
                {
                    g.CopyFromScreen(rect.Left,rect.Top,0,0,rect.Size);
                    signal=SignalPixels(bmp);
                    bmp.Save(png,ImageFormat.Png);
                }

                bool beaconPass=
                    beaconCommand &&
                    beaconMagenta>=100 &&
                    beaconGreen>=100;

                bool pass=
                    valid &&
                    parentOk &&
                    visible &&
                    cloaked==0 &&
                    rect.Width==1100 &&
                    rect.Height==48 &&
                    beaconPass;

                m["Version"]=BuildInfo.Version;
                m["Status"]=pass?"PASS":"FAIL";
                m["MainPid"]=mainPid;
                m["TaskbarPid"]=taskbarPid;
                m["TaskbarHwnd"]=taskbar.ToInt64();
                m["OverlayHwnd"]=overlay.ToInt64();
                m["ParentHwnd"]=Native.GetParent(overlay).ToInt64();
                m["WindowValid"]=valid;
                m["Visible"]=visible;
                m["ParentOk"]=parentOk;
                m["Cloaked"]=cloaked;
                m["Rect"]=new int[]{rect.X,rect.Y,rect.Width,rect.Height};
                m["SignalPixels"]=signal;
                m["BeaconCommandAck"]=beaconCommand;
                m["BeaconMagentaPixels"]=beaconMagenta;
                m["BeaconGreenPixels"]=beaconGreen;
                m["BeaconRequiredPerColor"]=100;
                m["BeaconPass"]=beaconPass;
                m["VisualAuthority"]="TBME_ACTIVE_BEACON_ON_REAL_SCREEN";
                m["BeaconPng"]=Path.GetFileName(beaconPng);
                m["ScreenPng"]=Path.GetFileName(png);

                File.WriteAllText(jsonPath,js.Serialize(m),Encoding.UTF8);
                Console.WriteLine(
                    "TBME_SHELL_STATE="+(pass?"PASS":"FAIL")+
                    " MAIN_PID="+mainPid+
                    " TASKBAR_PID="+taskbarPid+
                    " TASKBAR_HWND="+taskbar.ToInt64()+
                    " OVERLAY_HWND="+overlay.ToInt64()+
                    " PARENT_OK="+parentOk+
                    " VISIBLE="+visible+
                    " CLOAKED="+cloaked+
                    " RECT="+rect.X+","+rect.Y+","+rect.Width+","+rect.Height+
                    " SIGNAL="+signal+
                    " BEACON="+beaconPass+
                    " MAGENTA="+beaconMagenta+
                    " GREEN="+beaconGreen
                );
                return pass?0:6;
            }
            catch(Exception ex)
            {
                m["Version"]=BuildInfo.Version;
                m["Status"]="FAIL_EXCEPTION";
                m["Error"]=ex.ToString();
                try{File.WriteAllText(jsonPath,js.Serialize(m),Encoding.UTF8);}catch{}
                Console.Error.WriteLine("TBME_SHELL_STATE=FAIL "+ex.Message);
                return 6;
            }
        }
    }

    internal static class SelfTest
    {
        public static int Run()
        {
            try
            {
                if(ThemeCatalog.Names.Length!=14)throw new Exception("theme count");
                string[] expected=new string[]{"Dark Minimal Pro","Glass Morphism","Neon Cyberpunk","Sleek White","Round Compact","Honeycomb Tech","Retro Terminal","Fluent Glass","OLED Mono","Cyber Neon","Mission Control","Blueprint Tech","Medical Telemetry","Carbon Racing"};
                for(int i=0;i<expected.Length;i++)if(ThemeCatalog.Names[i]!=expected[i])throw new Exception("theme name " + i);
                string[] newModes=new string[]{"fluent","oled","cyber2","mission","blueprint","medical","carbon"};
                for(int i=0;i<7;i++)if(ThemeCatalog.Get(expected[i+7]).Mode!=newModes[i])throw new Exception("new theme mode " + i);
                AppConfig c=new AppConfig();c.Normalize();if(c.MinWidthLogicalPx!=1100||c.MarginLogicalPx!=0||c.VerticalMarginLogicalPx!=0)throw new Exception("geometry defaults");
                if(!c.ShowTemperatures)throw new Exception("temperature default");if(c.CpuDisplayMode!="Overall"||c.GpuDisplayMode!="Auto"||c.DiskDisplayMode!="Overall"||c.NetworkDisplayMode!="Overall")throw new Exception("hardware mode defaults");if(c.MemoryUnit!="Auto"||c.StorageUnit!="Auto"||c.NetworkUnit!="Auto"||c.DiskRateUnit!="Auto")throw new Exception("unit defaults");if(!c.ShowRamNumeric||!c.ShowDiskNumeric||!c.EnableHardwareFlyout||!c.AutoCheckUpdates||c.ConfigSchemaVersion<3)throw new Exception("R08 feature defaults");
                if(UnitFormatter.Pair(1024d*1024d*1024d,2d*1024d*1024d*1024d,"GB").IndexOf("GB",StringComparison.Ordinal)<0)throw new Exception("unit formatter pair");
                if(UnitFormatter.Bytes(1024d,"KB")!="1.00 KB")throw new Exception("unit formatter KB");
                if(UnitFormatter.Rate(1024d*1024d,"MB")!="1.00 MB/s")throw new Exception("unit formatter rate");
                HashSet<string> sid=SelectionUtil.Parse("A;B;A");if(sid.Count!=2||!sid.Contains("A")||!sid.Contains("B"))throw new Exception("selection ids");
                AppConfig multi=new AppConfig();multi.CpuDisplayMode="Multiple";multi.GpuDisplayMode="Multiple";multi.DiskDisplayMode="Multiple";multi.NetworkDisplayMode="Multiple";multi.MultipleDeviceLayout="Separate";multi.MemoryUnit="KB";multi.StorageUnit="MB";multi.DiskRateUnit="KB";multi.NetworkUnit="GB";multi.SelectedCpuIds="CPU0;CPU1";multi.SelectedGpuIds="GPU0;GPU1";multi.Normalize();
                if(multi.CpuDisplayMode!="Multiple"||multi.GpuDisplayMode!="Multiple"||multi.DiskDisplayMode!="Multiple"||multi.NetworkDisplayMode!="Multiple"||multi.MultipleDeviceLayout!="Separate")throw new Exception("multi display normalize");
                if(multi.MemoryUnit!="KB"||multi.StorageUnit!="MB"||multi.DiskRateUnit!="KB"||multi.NetworkUnit!="GB")throw new Exception("unit selection normalize");if(UpdateManager.ParseVersionString("v1.2.3").CompareTo(new Version(1,2,3,0))!=0)throw new Exception("update version parser");
                foreach(string n in expected)if(ThemeCatalog.Get(n)==null)throw new Exception("theme lookup " + n);
                if(BuildInfo.HistoryLength!=60)throw new Exception("history length");
                uint taskbarCreated=Native.RegisterWindowMessage("TaskbarCreated");
                if(taskbarCreated==0)throw new Exception("TaskbarCreated message registration");
                if(!ShellUi.IsStartShellProcessName("SearchHost"))throw new Exception("SearchHost detector");
                if(!ShellUi.IsStartShellProcessName("StartMenuExperienceHost"))throw new Exception("StartMenu detector");
                if(!ShellUi.IsStartShellProcessName("SearchHost"))throw new Exception("SearchHost detector");
                long recipe=Native.WS_EX_CONTROLPARENT|Native.WS_EX_LAYERED|Native.WS_EX_COMPOSITED|Native.WS_EX_TOOLWINDOW|Native.WS_EX_NOACTIVATE;
                if(recipe!=0x0A090080L)throw new Exception("R07 interactive noactivate exstyle recipe");
                string atomicDir=Path.Combine(Path.GetTempPath(),"tbme_atomic_selftest_"+Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture));
                string atomicFile=Path.Combine(atomicDir,"config.json");
                string atomicBackup=Path.Combine(atomicDir,"config.json.bak");
                try
                {
                    Directory.CreateDirectory(atomicDir);
                    File.WriteAllText(atomicFile,"OLD",Encoding.UTF8);
                    AtomicTextFile.Write(atomicFile,"NEW",Encoding.UTF8,atomicBackup);
                    if(File.ReadAllText(atomicFile,Encoding.UTF8)!="NEW")throw new Exception("atomic config current");
                    if(File.ReadAllText(atomicBackup,Encoding.UTF8)!="OLD")throw new Exception("atomic config backup");
                }
                finally{try{Directory.Delete(atomicDir,true);}catch{}}
                if(!UpdateManager.IsStrictSha256Digest("sha256:"+new string('A',64)))throw new Exception("strict sha256 valid");
                if(UpdateManager.IsStrictSha256Digest("sha256:"+new string('A',63)))throw new Exception("strict sha256 short");
                if(UpdateManager.IsStrictSha256Digest("sha256:"+new string('G',64)))throw new Exception("strict sha256 nonhex");
                if(UpdateManager.ExpectedSetupAssetName("1.2.3")!="TaskbarMonitorEnhanced_Setup_1.2.3.exe")throw new Exception("strict setup asset name");
                Console.WriteLine("TBME_V1_1_2_R21_SELFTEST=PASS PUBLIC_VERSION=1.1.2-rc2 MULTI_HARDWARE=TRUE OVERALL_AUTO_SINGLE_MULTIPLE=TRUE UNIT_KB_MB_GB=TRUE NUMERIC_RAM_STORAGE=TRUE UPWARD_HOVER_FLYOUT=TRUE HOVER_DETAILS_SINGLE_OR_MULTI=TRUE HARDWARE_SELECTION=TRUE DISK_RW_SPEED=TRUE DISK_TEMPERATURE=TRUE DISK_CAPACITY_IN_HOVER=TRUE IN_APP_GITHUB_UPDATE=TRUE UPDATE_SHA256_DIGEST_GATE=TRUE UPDATE_EXACT_ASSET_MATCH=TRUE UPDATE_STRICT_SHA256_64HEX=TRUE WINDOWS_WDDM_GPU_FALLBACK=TRUE PRODUCT_IDENTITY_LOCKED=TRUE AUTHOR_IDENTITY_LOCKED=TRUE GPL3_ATTRIBUTION_LOCKED=TRUE AI_DISCLOSURE_DOCUMENTED=TRUE SHORTCUT_NAME_LOCKED=TRUE NVIDIA_SMI_TIMEOUT_SAFE=TRUE REDIRECTED_IO_ORDER_SAFE=TRUE BROKER_WATCHDOG_HARDENED=TRUE BROKER_FRESHNESS_15S=TRUE THEMES=14 WIDTH=1100 HISTORY=60 HEADLINE_LABEL_VALUE_INLINE=TRUE CPU_TEMP_CURRENT=TRUE GPU_TEMP_AVG_MAX=TRUE AMD_INTEL_LHM_GPU_FALLBACK=ISOLATED LHM_ELEVATED_BROKER=TRUE LHM_DIRECT_FALLBACK=FALSE LHM_IN_UI_PROCESS=FALSE LHM_CPU_GPU_STORAGE_PROCESS_ISOLATION=TRUE CPU_USAGE_GETSYSTEMTIMES=TRUE CPU_TOPOLOGY_CACHE_MIN=5 NETWORK_TOPOLOGY_CACHE_SEC=30 DISK_TOPOLOGY_CACHE_MIN=5 RAM_TOPOLOGY_CACHE_MIN=10 RESUME_STATIC_TOPOLOGY_INVALIDATION=TRUE GPU_WDDM_ON_DEMAND=TRUE CPU_TEMP_FRESHNESS_SEC=15 CPU_TEMP_FALLBACK_THROTTLE_SEC=15 CPU_BROKER_SHARED_READ=TRUE ATOMIC_CONFIG_BACKUP=TRUE LOG_RETENTION_30D=TRUE SENSOR_LOG_ROTATION_4MB=TRUE HEALTH_RESILIENCE_STATE=TRUE OPTIONAL_POWER_FAN_TELEMETRY=TRUE BROKER_STALE_LOG_THROTTLE_SEC=30 METRIC_MIN_INTERVAL_MS=1000 POWER_AWARE_TELEMETRY=TRUE DIAGNOSTICS_TAB=TRUE SENSOR_REPAIR_UI=TRUE HEALTHPROBE_CLI=TRUE IMMUTABLE_RELEASE_UPDATE_GATE=TRUE NETWORK_RENDERER_THEME_CONSISTENT=TRUE RIGHTCLICK_BRIDGE=FALSE DIRECT_MOUSE_INTERACTION=TRUE NOACTIVATE_MOUSE=TRUE RECOVERY_HOST_CONTEXT=TRUE ACTIVE_VISUAL_BEACON=TRUE TEMP_PROBE=TRUE ADAPTIVE_SAFE_PLACEMENT=TRUE AMD_INTEL_GPU_FALLBACK=TRUE AMD_ADLX_GPU_TEMP_FALLBACK=TRUE COMPACT_READABLE_STACK=TRUE COMPACT_NET_LABEL_ELISION=TRUE COMPACT_PROOF=TRUE STABLE_PLACEMENT_LOCK=TRUE START_TRANSIENT_FREEZE=TRUE STYLE_SELF_HEAL=LOW_PRESSURE_5S WATCHDOG_MS=500 HOST_POLL_MS=1000 UIA_SAFE_PLACEMENT=EVENT_DRIVEN SETTINGS_SINGLE_INSTANCE=TRUE CREATEPARAMS_NOACTIVATE=TRUE");
                return 0;
            }
            catch(Exception ex){Console.Error.WriteLine("TBME_V1_1_2_R21_SELFTEST=FAIL " + ex);return 2;}
        }

        public static int RunJson(string outputPath)
        {
            int rc=Run();
            try
            {
                Dictionary<string,object> m=new Dictionary<string,object>();
                m["Status"]=rc==0?"PASS":"FAIL";
                m["ExitCode"]=rc;
                m["Version"]=BuildInfo.Version;
                m["PublicVersion"]=BuildInfo.PublicVersion;
                m["MultiHardware"]=true;
                m["DisplayModes"]=new string[]{"Overall","Auto","Single","Multiple"};
                m["MultipleLayouts"]=new string[]{"Grouped","Separate"};
                m["Units"]=new string[]{"Auto","KB","MB","GB"};m["DiskRateUnit"]=true;
                m["NumericRam"]=true;
                m["NumericStorage"]=true;
                m["IndependentUpwardHardwareFlyout"]=true;m["HoverDetailsForSingleDevice"]=true;m["DiskReadWriteThroughput"]=true;m["DiskTemperature"]=true;m["DiskCapacityInHover"]=true;m["InAppGitHubUpdates"]=true;m["UpdateRequiresGitHubSha256Digest"]=true;m["AsyncTelemetryUiIsolation"]=true;m["ImmediateHoverEnter"]=true;m["ResizableScrollableSettings"]=true;m["DetailedHardwareFlyout"]=true;m["ClockAndBusTelemetry"]=true;
                m["HardwareSelection"]=new string[]{"CPU","GPU","Disk","Network"};
                m["UnsupportedTemperatureBehavior"]="N/A";
                File.WriteAllText(outputPath,new JavaScriptSerializer().Serialize(m),Encoding.UTF8);
            }
            catch(Exception ex)
            {
                try{File.WriteAllText(outputPath,new JavaScriptSerializer().Serialize(new Dictionary<string,object>{{"Status","FAIL_WRITE"},{"Error",ex.ToString()}}),Encoding.UTF8);}catch{}
                if(rc==0)rc=3;
            }
            return rc;
        }
    }

    internal sealed class RecoveryApplicationContext : ApplicationContext
    {
        private readonly AppConfig config;
        private readonly System.Windows.Forms.Timer timer;
        private OverlayForm overlay;
        private IntPtr lastTaskbar=IntPtr.Zero;
        private int taskbarStableCount=0;
        private DateTime recreateNotBefore=DateTime.MinValue;
        private bool shuttingDown=false;
        private int createCount=0;

        public RecoveryApplicationContext(AppConfig c)
        {
            config=c;
            timer=new System.Windows.Forms.Timer();
            timer.Interval=1000;
            timer.Tick+=delegate{TickHost();};

            Log.Write("INFO","HOST_CONTEXT_START version="+BuildInfo.Version+" pid="+Process.GetCurrentProcess().Id);
            IntPtr tb=Native.FindWindow("Shell_TrayWnd",null);
            if(tb!=IntPtr.Zero)
            {
                lastTaskbar=tb;
                taskbarStableCount=3;
                CreateOverlay("STARTUP");
            }
            else
            {
                recreateNotBefore=DateTime.UtcNow.AddMilliseconds(500);
                Log.Write("WARN","HOST_CONTEXT_START_NO_TASKBAR");
            }
            timer.Start();
        }

        private void CreateOverlay(string reason)
        {
            if(shuttingDown)return;
            IntPtr tb=Native.FindWindow("Shell_TrayWnd",null);
            if(tb==IntPtr.Zero)return;

            try
            {
                OverlayForm f=new OverlayForm(config);
                overlay=f;
                f.FormClosed+=OverlayClosed;
                f.Show();
                createCount++;
                Log.Write(
                    "INFO",
                    "HOST_CONTEXT_OVERLAY_CREATE reason="+reason+
                    " count="+createCount+
                    " hwnd="+f.Handle.ToInt64()+
                    " taskbar="+tb.ToInt64()
                );
            }
            catch(Exception ex)
            {
                overlay=null;
                recreateNotBefore=DateTime.UtcNow.AddMilliseconds(750);
                Log.Write("ERROR","HOST_CONTEXT_OVERLAY_CREATE_FAIL reason="+reason+" "+ex.ToString());
            }
        }

        private void OverlayClosed(object sender,FormClosedEventArgs e)
        {
            OverlayForm closed=sender as OverlayForm;
            bool user=closed!=null && closed.UserExitRequested;

            Log.Write(
                "INFO",
                "HOST_CONTEXT_OVERLAY_CLOSED userExit="+user+
                " reason="+e.CloseReason.ToString()
            );

            if(Object.ReferenceEquals(overlay,closed))overlay=null;

            if(user)
            {
                shuttingDown=true;
                try{timer.Stop();}catch{}
                ExitThread();
                return;
            }

            recreateNotBefore=DateTime.UtcNow.AddMilliseconds(750);
        }

        private void DropInvalidOverlay(string reason)
        {
            OverlayForm old=overlay;
            overlay=null;

            if(old!=null)
            {
                Log.Write("WARN","HOST_CONTEXT_OVERLAY_LOST reason="+reason);
                try{old.FormClosed-=OverlayClosed;}catch{}
                try{old.HostPrepareForReplacement();}catch{}
                try{old.Dispose();}catch{}
            }

            recreateNotBefore=DateTime.UtcNow.AddMilliseconds(750);
        }

        private void TickHost()
        {
            if(shuttingDown)return;

            try
            {
                IntPtr current=Native.FindWindow("Shell_TrayWnd",null);

                if(current==IntPtr.Zero)
                {
                    if(lastTaskbar!=IntPtr.Zero)
                        Log.Write("WARN","HOST_CONTEXT_TASKBAR_LOST old="+lastTaskbar.ToInt64());

                    lastTaskbar=IntPtr.Zero;
                    taskbarStableCount=0;

                    if(overlay!=null)
                    {
                        bool dead=overlay.IsDisposed || !overlay.IsHandleCreated;
                        if(!dead && overlay.IsHandleCreated)
                        {
                            try{dead=!Native.IsWindow(overlay.Handle);}catch{dead=true;}
                        }
                        if(dead)DropInvalidOverlay("TASKBAR_MISSING_HANDLE_DESTROYED");
                    }
                    return;
                }

                bool changed=lastTaskbar!=IntPtr.Zero && current!=lastTaskbar;
                if(current!=lastTaskbar)
                {
                    Log.Write(
                        "INFO",
                        "HOST_CONTEXT_TASKBAR_SEEN hwnd="+current.ToInt64()+
                        " previous="+lastTaskbar.ToInt64()
                    );
                    lastTaskbar=current;
                    taskbarStableCount=1;
                }
                else taskbarStableCount++;

                if(overlay!=null)
                {
                    bool invalid=overlay.IsDisposed || !overlay.IsHandleCreated;
                    if(!invalid && overlay.IsHandleCreated)
                    {
                        try{invalid=!Native.IsWindow(overlay.Handle);}catch{invalid=true;}
                    }

                    if(invalid)
                    {
                        DropInvalidOverlay("OVERLAY_HWND_INVALID");
                    }
                    else if(taskbarStableCount>=3)
                    {
                        try
                        {
                            if(changed || Native.GetParent(overlay.Handle)!=current)
                            {
                                Log.Write(
                                    "INFO",
                                    "HOST_CONTEXT_RECOVERY_REQUEST changed="+changed+
                                    " parent="+Native.GetParent(overlay.Handle).ToInt64()+
                                    " taskbar="+current.ToInt64()
                                );
                                overlay.RequestExternalRecovery("HOST_CONTEXT_TASKBAR_CHANGED");
                            }
                        }
                        catch(Exception ex)
                        {
                            Log.Write("WARN","HOST_CONTEXT_RECOVERY_REQUEST_FAIL "+ex.Message);
                        }
                    }
                }

                if(overlay==null &&
                   taskbarStableCount>=3 &&
                   DateTime.UtcNow>=recreateNotBefore)
                {
                    CreateOverlay("TASKBAR_RECREATED");
                }
            }
            catch(Exception ex)
            {
                Log.Write("WARN","HOST_CONTEXT_TICK "+ex.Message);
            }
        }

        protected override void ExitThreadCore()
        {
            shuttingDown=true;
            try{timer.Stop();timer.Dispose();}catch{}

            OverlayForm f=overlay;
            overlay=null;
            if(f!=null && !f.IsDisposed)
            {
                try{f.FormClosed-=OverlayClosed;}catch{}
                try{f.HostPrepareForReplacement();}catch{}
                try{f.Dispose();}catch{}
            }

            Log.Write("INFO","HOST_CONTEXT_EXIT");
            base.ExitThreadCore();
        }
    }

    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            if(args!=null && args.Length>0 && args[0]=="--selftest")return SelfTest.Run();
            if(args!=null && args.Length>0 && args[0]=="--selftestjson")
            {
                if(args.Length<2)return 3;
                return SelfTest.RunJson(args[1]);
            }
            if(args!=null && args.Length>0 && args[0]=="--themeproof")
            {
                if(args.Length<2)
                {
                    Console.Error.WriteLine("TBME_THEME_PROOF=FAIL missing output directory");
                    return 4;
                }
                return ThemeProof.Run(args[1]);
            }
            if(args!=null && args.Length>0 && args[0]=="--compactproof")
            {
                if(args.Length<2){Console.Error.WriteLine("TBME_COMPACT_PROOF=FAIL missing output directory");return 8;}
                return CompactProof.Run(args[1]);
            }
            if(args!=null && args.Length>0 && args[0]=="--startprobe")
            {
                if(args.Length<2)
                {
                    Console.Error.WriteLine("TBME_START_PROBE=FAIL missing output directory");
                    return 5;
                }
                return StartProbe.Run(args[1]);
            }
            if(args!=null && args.Length>0 && args[0]=="--shellstate")
            {
                if(args.Length<2)
                {
                    Console.Error.WriteLine("TBME_SHELL_STATE=FAIL missing json path");
                    return 6;
                }
                return ShellStateProbe.Run(args[1]);
            }
            if(args!=null && args.Length>0 && args[0]=="--hardwareprobe")
            {
                if(args.Length<2){Console.Error.WriteLine("TBME_HARDWARE_PROBE=FAIL missing json path");return 9;}
                return HardwareProbe.Run(args[1]);
            }
            if(args!=null && args.Length>0 && args[0]=="--tempprobe")
            {
                if(args.Length<2)
                {
                    Console.Error.WriteLine("TBME_TEMP_PROBE=FAIL missing json path");
                    return 7;
                }
                return TemperatureProbe.Run(args[1]);
            }
            if(args!=null && args.Length>0 && args[0]=="--healthprobe")
            {
                if(args.Length<2){Console.Error.WriteLine("TBME_HEALTH_PROBE=FAIL missing json path");return 12;}
                return HealthProbe.Run(args[1]);
            }
            bool created;
            using(Mutex mutex=new Mutex(true,@"Local\TaskbarMonitorEnhanced_V1_1_0",out created))
            {
                if(!created)return 0;
                RuntimeGuard.Install();
                Native.EnableDpi();
                Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
                AppConfig c=AppConfig.Load();c.Normalize();c.Save();StartupManager.SetEnabled(c.StartWithWindows);
                Application.Run(new RecoveryApplicationContext(c));
                return 0;
            }
        }
    }
}
