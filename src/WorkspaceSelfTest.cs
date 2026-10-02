using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace TaskbarMonitorEnhanced
{
    internal static class WorkspaceSelfTest
    {
        private static void Check(bool condition,string name){if(!condition)throw new Exception(name);}
        internal static int Run()
        {
            try
            {
                Check(BuildInfo.PublicVersion=="1.6.0","version");
                Check(ThemeCatalog.Names.Length==48,"theme count");
                Check(ThemeCatalog.Names.Select(ThemeCatalog.Get).Count(t=>StudioThemes.IsStudio(t.Mode))==20,"studio theme count");
                Check(StudioThemes.Create().Select(t=>t.Name).Distinct(StringComparer.OrdinalIgnoreCase).Count()==20,"studio names distinct");

                AppConfig c=new AppConfig();c.Normalize();
                Check(c.ConfigSchemaVersion==7,"schema 7");
                Check(c.CpuUsageWarningPercent==95&&c.RamUsageWarningPercent==90&&c.GpuUsageWarningPercent==95,"usage defaults");
                Check(c.SustainedAlertSeconds==30&&c.UsageAlertCooldownMinutes==10,"alert timing defaults");
                Check(c.MetricOrder=="CPU;RAM;DISK;GPU;VRAM;NET","metric order default");

                AppConfig migrated=new AppConfig();migrated.ConfigSchemaVersion=6;migrated.CpuUsageWarningPercent=0;migrated.RecordTrafficHistory=true;migrated.StartWithWindows=false;migrated.Normalize();
                Check(migrated.ConfigSchemaVersion==7,"schema migrate");
                Check(migrated.CpuUsageWarningPercent==95,"schema migration initializes new fields");
                Check(!migrated.RecordTrafficHistory,"migration privacy default");
                Check(!migrated.StartWithWindows,"migration preserves old field");

                SustainedAlertGate gate=new SustainedAlertGate();
                Check(!gate.Observe("CPU",true,96,95,0,5,10),"alert dwell start");
                Check(!gate.Observe("CPU",true,96,95,4.9,5,10),"alert dwell wait");
                Check(gate.Observe("CPU",true,96,95,5.1,5,10),"alert dwell fire");
                Check(!gate.Observe("CPU",true,97,95,20,5,10),"alert single fire");
                Check(!gate.Observe("CPU",true,89,95,30,5,10),"alert rearm");
                Check(!gate.Observe("CPU",true,96,95,31,5,10),"alert cooldown start");
                Check(!gate.Observe("CPU",true,96,95,40,5,10),"alert cooldown enforced");

                var stats=MetricStatistics.Calculate(new double?[]{1,2,null,3,4,100});
                Check(stats.Count==5&&Math.Abs(stats.Minimum-1)<.001&&Math.Abs(stats.Maximum-100)<.001,"statistics range");
                Check(TrafficLedger.CounterDelta(100,175)==75&&TrafficLedger.CounterDelta(175,100)==0,"counter reset handling");
                Check(NetworkRateFormatter.Bits(125000).Contains("Mbit/s"),"bit rate formatting");
                Check(NetworkRateFormatter.Bits(Double.NaN)=="-","bit rate nonfinite");

                string poison=WorkspaceExport.CsvCell("=SUM(A1:A2)");
                Check(poison.StartsWith("\"'="),"csv formula hardening");

                c.StartWithWindows=false;c.EnableTemperatureNotifications=true;c.RecordTrafficHistory=true;c.Theme="Art Deco Gold";
                string profile=WorkspaceExport.Profile(c);
                Check(profile.Contains("TBME-Presentation-1"),"profile marker");
                Check(!profile.Contains("StartWithWindows")&&!profile.Contains("RecordTrafficHistory")&&!profile.Contains("EnableTemperatureNotifications"),"profile allowlist");
                string temp=Path.Combine(Path.GetTempPath(),"tbme-workspace-profile-"+Guid.NewGuid().ToString("N")+".json");
                try
                {
                    File.WriteAllText(temp,profile,new UTF8Encoding(false));
                    AppConfig imported=new AppConfig();imported.StartWithWindows=true;imported.RecordTrafficHistory=false;WorkspaceExport.ImportProfile(imported,temp);
                    Check(imported.Theme=="Art Deco Gold","profile theme import");
                    Check(imported.StartWithWindows,"profile preserves startup");
                    Check(!imported.RecordTrafficHistory,"profile preserves traffic privacy");
                } finally {try{File.Delete(temp);}catch{}}

                Console.WriteLine("TBME_WORKSPACE_SELFTEST=PASS THEMES=48 STUDIO=20 SCHEMA=7");
                return 0;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine("TBME_WORKSPACE_SELFTEST=FAIL "+ex);
                return 27;
            }
        }
    }

    internal static class WorkspaceProof
    {
        internal static int Run(string outputDirectory)
        {
            try
            {
                Directory.CreateDirectory(outputDirectory);
                AppConfig c=new AppConfig();c.Theme="Art Deco Gold";c.Normalize();
                MetricsSnapshot s=new MetricsSnapshot
                {
                    Cpu=31.5f,Ram=62.2f,Disk=12.4f,DiskUsedPercent=73.2f,Gpu=44.8f,VramUsedGb=4.1f,VramTotalGb=12f,
                    NetDownMbps=83.4f,NetUpMbps=15.8f,NetDownBytesPerSec=10425000,NetUpBytesPerSec=1975000,
                    DiskReadBytesPerSec=18.2*1048576,DiskWriteBytesPerSec=7.4*1048576,CpuTempAvailable=true,CpuTempCurrent=54.2f,
                    GpuTempAvailable=true,GpuTemp=51.6f,RamTotalBytes=32UL*1024*1024*1024,RamUsedBytes=20UL*1024*1024*1024
                };
                s.NetworkDevices.Add(new NetworkDeviceSnapshot{Id="proof-net",Name="Proof Ethernet",Active=true,CountersAvailable=true,DownBytesPerSec=10425000,UpBytesPerSec=1975000,LinkSpeedBitsPerSec=1000000000,ReceivedBytesTotal=1000000,SentBytesTotal=500000});
                s.DiskDevices.Add(new DiskDeviceSnapshot{Id="proof-disk",Name="Proof NVMe",Volumes="C:",CapacityAvailable=true,TotalBytes=1000UL*1024*1024*1024,UsedBytes=732UL*1024*1024*1024,RateAvailable=true,ReadBytesPerSec=18.2*1048576,WriteBytesPerSec=7.4*1048576,TemperatureAvailable=true,Temperature=43.5f});
                var ledger=new TrafficLedger(Path.Combine(outputDirectory,"traffic-proof.json"));
                using(var renderer=new OverlayForm(c,true))
                using(var f=new WorkspaceForm(c,()=>s,()=>false,b=>{},ledger,()=>new[]{new AlertRecord{Utc=DateTime.UtcNow,Metric="CPU usage",Message="Proof event"}},()=>{},()=>{},renderer.RenderSettingsThemePreview,true))
                {
                    f.PrepareProofProcesses();
                    f.Show();
                    Application.DoEvents();
                    f.CapturePages(outputDirectory);
                    f.Close();
                }
                string[] pages={"overview.png","processes.png","network.png","storage.png","alerts.png","themes.png","profiles.png"};
                foreach(string p in pages)CheckFile(Path.Combine(outputDirectory,p));
                var manifest=new Dictionary<string,object>{{"Version",BuildInfo.Version},{"PublicVersion",BuildInfo.PublicVersion},{"GeneratedUtc",DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)},{"Status","PASS"},{"ThemeCount",ThemeCatalog.Names.Length},{"StudioThemeCount",20},{"Pages",pages}};
                File.WriteAllText(Path.Combine(outputDirectory,"WORKSPACE_PROOF_MANIFEST.json"),new JavaScriptSerializer().Serialize(manifest),new UTF8Encoding(false));
                Console.WriteLine("TBME_WORKSPACE_PROOF=PASS PAGES=7 THEMES=48 DIR="+outputDirectory);
                return 0;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine("TBME_WORKSPACE_PROOF=FAIL "+ex);
                return 28;
            }
        }
        private static void CheckFile(string path)
        {
            if(!File.Exists(path)||new FileInfo(path).Length<4096)throw new Exception("proof missing/too small: "+path);
        }
    }
}
