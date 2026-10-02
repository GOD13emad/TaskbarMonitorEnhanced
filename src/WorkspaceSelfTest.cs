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
        private static void CheckTrafficLedger()
        {
            string dir=Path.Combine(Path.GetTempPath(),"tbme_traffic_test_"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);
            try
            {
                DateTime day=DateTime.Today;string path=Path.Combine(dir,"traffic.json");var cfg=new AppConfig();
                var state=new MetricsSnapshot();var a=new NetworkDeviceSnapshot{Id="A",Name="Fixture adapter A",Active=true,CountersAvailable=true,ReceivedBytesTotal=100,SentBytesTotal=50,LinkSpeedBitsPerSec=1000000000};
                state.NetworkDevices.Add(a);var ledger=new TrafficLedger(path);ledger.Observe(state,cfg,day,0);
                Check(ledger.SessionDownload==0&&!File.Exists(path),"traffic first sample baseline and no implicit persistence");
                a.ReceivedBytesTotal=500;a.SentBytesTotal=250;ledger.Observe(state,cfg,day,1);
                Check(ledger.SessionDownload==400&&ledger.SessionUpload==200,"traffic counter deltas");
                a.ReceivedBytesTotal=20;a.SentBytesTotal=10;ledger.Observe(state,cfg,day,2);
                Check(ledger.SessionDownload==400&&ledger.SessionUpload==200,"traffic reset excluded");
                a.ReceivedBytesTotal=120;a.SentBytesTotal=60;ledger.Observe(state,cfg,day,3);
                a.ReceivedBytesTotal=2120;a.SentBytesTotal=1060;ledger.Observe(state,cfg,day,40);
                Check(ledger.SessionDownload==500&&ledger.SessionUpload==250,"traffic long gap excluded");
                a.ReceivedBytesTotal=2320;a.SentBytesTotal=1160;ledger.Observe(state,cfg,day,41);
                var b=new NetworkDeviceSnapshot{Id="B",Name="Fixture adapter B",Active=true,CountersAvailable=true,ReceivedBytesTotal=10000,SentBytesTotal=5000};state.NetworkDevices.Add(b);
                cfg.TrafficAdapterId="B";ledger.Observe(state,cfg,day,42);
                Check(ledger.SessionDownload==700&&ledger.SessionUpload==350,"adapter switch baseline");
                b.ReceivedBytesTotal+=100;b.SentBytesTotal+=100;ledger.Observe(state,cfg,day,43);
                b.CountersAvailable=false;b.ReceivedBytesTotal+=1000;ledger.Observe(state,cfg,day,44);
                b.CountersAvailable=true;ledger.Observe(state,cfg,day,45);
                Check(ledger.SessionDownload==800&&ledger.SessionUpload==450,"unavailable counters do not backfill");
                Check(!File.Exists(path),"traffic opt-out never writes observed history");
                cfg.RecordTrafficHistory=true;ledger.Observe(state,cfg,day,46);Check(ledger.FlushAndWait(3000),"traffic explicit opt-in flush completes");
                var stored=new JavaScriptSerializer().Deserialize<TrafficDay[]>(File.ReadAllText(path));
                Check(stored.Length==1&&stored[0].DownloadBytes==800&&stored[0].UploadBytes==450,"traffic exact persisted totals");
                for(int i=0;i<100;i++){b.ReceivedBytesTotal+=10;b.SentBytesTotal+=20;ledger.Observe(state,cfg,day,47+i);ledger.FlushAsync();}
                Check(ledger.FlushAndWait(3000),"traffic coalesced writer drain");
                stored=new JavaScriptSerializer().Deserialize<TrafficDay[]>(File.ReadAllText(path));
                Check(stored[0].DownloadBytes==1800&&stored[0].UploadBytes==2450,"coalescing retains latest snapshot");
                string bad=Path.Combine(dir,"bad.json"),original="{ invalid retained evidence";File.WriteAllText(bad,original);
                var damaged=new TrafficLedger(bad);damaged.Observe(state,cfg,day,0);
                Check(!damaged.FlushAndWait(100)&&File.ReadAllText(bad)==original&&damaged.LastError!=null,"corrupt history preserved fail closed");
                cfg.RecordTrafficHistory=false;string retentionPath=Path.Combine(dir,"retention.json");var retention=new TrafficLedger(retentionPath);
                for(int i=0;i<=100;i++){b.ReceivedBytesTotal++;b.SentBytesTotal++;retention.Observe(state,cfg,day.AddDays(i-100),i);}
                Check(retention.Snapshot().Length==90,"traffic retention 90 daily buckets");
                Check(retention.Snapshot().All(x=>String.CompareOrdinal(x.Day,day.AddDays(-89).ToString("yyyy-MM-dd",CultureInfo.InvariantCulture))>=0),"traffic oldest retained date");
                Check(!File.Exists(retentionPath),"retention opt-out stays memory only");
                var snap=retention.Snapshot();snap[0].DownloadBytes=999999;
                Check(retention.Snapshot()[0].DownloadBytes!=999999,"traffic snapshot isolation");
                string coldPath=Path.Combine(dir,"cold.json");
                File.WriteAllText(coldPath,new JavaScriptSerializer().Serialize(new[]{new TrafficDay{Day=day.ToString("yyyy-MM-dd",CultureInfo.InvariantCulture),DownloadBytes=321,UploadBytes=123}}));
                var cold=new TrafficLedger(coldPath);
                Check(cold.FlushAndWait(3000),"cold shutdown flush completes");
                var coldRows=new JavaScriptSerializer().Deserialize<TrafficDay[]>(File.ReadAllText(coldPath));
                Check(coldRows.Length==1&&coldRows[0].DownloadBytes==321&&coldRows[0].UploadBytes==123,"shutdown before first sample preserves existing traffic history");
                string coldBadPath=Path.Combine(dir,"cold-bad.json");File.WriteAllText(coldBadPath,"{ unreadable original");
                var coldBad=new TrafficLedger(coldBadPath);
                Check(!coldBad.FlushAndWait(3000)&&File.ReadAllText(coldBadPath)=="{ unreadable original","cold corrupt history preserved without overwrite");
                string unwritable=Path.Combine(dir,"destination-is-directory");Directory.CreateDirectory(unwritable);
                var failedWrite=new TrafficLedger(unwritable);
                Check(!failedWrite.FlushAndWait(3000)&&failedWrite.LastError!=null,"flush must report write failure rather than successful queue drain");
            }
            finally {try{Directory.Delete(dir,true);}catch{}}
        }
        private static void CheckProfileAndStatistics()
        {
            var r=MetricStatistics.Calculate(Enumerable.Range(1,20).Select(x=>(double?)x));
            Check(r.Count==20&&r.P95==19&&r.Average==10.5,"nearest-rank P95 and arithmetic mean");
            Check(MetricStatistics.Calculate(new double?[]{null,Double.NaN,Double.PositiveInfinity}).Count==0,"nonfinite statistics excluded");
            string path=Path.Combine(Path.GetTempPath(),"tbme_profile_guard_"+Guid.NewGuid().ToString("N")+".json");
            try
            {
                var c=new AppConfig{StartWithWindows=true,RecordTrafficHistory=false,EnableUsageNotifications=false};
                File.WriteAllText(path,"{\"Format\":\"TBME-Presentation-1\",\"Theme\":\"Swiss Grid\",\"StartWithWindows\":false,\"RecordTrafficHistory\":true,\"EnableUsageNotifications\":true}");
                WorkspaceExport.ImportProfile(c,path);
                Check(c.Theme=="Swiss Grid"&&c.StartWithWindows&&!c.RecordTrafficHistory&&!c.EnableUsageNotifications,"profile unknown/security fields ignored");
                string before=WorkspaceExport.Profile(c);File.WriteAllText(path,"{\"Format\":\"TBME-Presentation-1\",\"Theme\":\"Stained Glass\",\"Opacity\":\"not a number\"}");
                bool blocked=false;try{WorkspaceExport.ImportProfile(c,path);}catch{blocked=true;}
                Check(blocked&&before==WorkspaceExport.Profile(c),"invalid import transactional preservation");
                File.WriteAllText(path,new string('x',65537));blocked=false;try{WorkspaceExport.ImportProfile(c,path);}catch(InvalidDataException){blocked=true;}
                Check(blocked&&before==WorkspaceExport.Profile(c),"oversized profile blocked without mutation");
            }
            finally{try{File.Delete(path);}catch{}}
        }

        private static double Luminance(Color c)
        {Func<byte,double> channel=b=>{double v=b/255d;return v<=.04045?v/12.92:Math.Pow((v+.055)/1.055,2.4);};return .2126*channel(c.R)+.7152*channel(c.G)+.0722*channel(c.B);}
        private static void CheckHardwareAndContrast()
        {
            foreach(var t in StudioThemes.Create()){
                double a=Luminance(t.Foreground),b=Luminance(t.Background2);
                Check((Math.Max(a,b)+.05)/(Math.Min(a,b)+.05)>=4.5,"Studio primary text contrast "+t.Name);
            }
            Check(HardwareInventory.Read(null).Count==0,"null hardware snapshot");
            var s=new MetricsSnapshot();s.GpuDevices.Add(new GpuDeviceSnapshot{Name="Fixture GPU",UsageAvailable=false,PowerAvailable=true,PowerW=float.NaN});
            var rows=HardwareInventory.Read(s);
            Check(rows.First(r=>r.Group=="GPU"&&r.Metric=="Usage").Status=="Unavailable","unavailable GPU sensor remains blank");
            Check(rows.First(r=>r.Group=="GPU"&&r.Metric=="Power").Status=="Unavailable","nonfinite sensor remains unavailable");
        }
        internal static int Run()
        {
            try
            {
                Check(BuildInfo.PublicVersion=="1.6.0","version");
                for(int schema=0;schema<7;schema++){
                    var legacy=new AppConfig{ConfigSchemaVersion=schema,EnableTemperatureNotifications=true,CpuTempWarningC=0,FontSize=Double.NaN,Opacity=Double.NaN};legacy.Normalize();
                    Check(legacy.ConfigSchemaVersion==7,"all legacy schemas migrate "+schema);
                    if(schema<6)Check(!legacy.EnableTemperatureNotifications,"legacy notification opt-in "+schema);
                    if(schema<4)Check(legacy.CpuTempWarningC==85,"legacy thermal default "+schema);
                    Check(MetricStatistics.Finite(legacy.FontSize)&&MetricStatistics.Finite(legacy.Opacity),"finite presentation "+schema);
                }
                Check(!SustainedAlertGate.IsQuiet(true,22,8,new DateTime(2026,10,2,12,0,0)),"quiet daytime");
                Check(SustainedAlertGate.IsQuiet(true,22,8,new DateTime(2026,10,2,23,0,0)),"quiet midnight wrap");
                Check(SustainedAlertGate.IsQuiet(true,4,4,DateTime.Now),"all day quiet");
                Check(!SustainedAlertGate.IsQuiet(false,4,4,DateTime.Now),"disabled quiet");
                var invalidTemp=new TemperatureNotificationState();
                Check(!invalidTemp.ShouldNotify("CPU",true,float.NaN,85,DateTime.UtcNow),"NaN temperature blocked");
                Check(!invalidTemp.ShouldNotify("CPU",true,float.PositiveInfinity,85,DateTime.UtcNow),"infinite temperature blocked");
                SessionTelemetryHistory.ClearForTest();SessionTelemetryHistory.Add(new MetricsSnapshot());
                Check(!WorkspaceMetric.Value(SessionTelemetryHistory.Snapshot()[0],2).HasValue,"GPU unavailable chart gap");
                Check(!WorkspaceMetric.Value(SessionTelemetryHistory.Snapshot()[0],4).HasValue,"network unavailable chart gap");
                Check(!WorkspaceMetric.Value(SessionTelemetryHistory.Snapshot()[0],6).HasValue,"disk unavailable chart gap");
                var copied=SessionTelemetryHistory.Snapshot();copied[0].CpuPercent=999;
                Check(SessionTelemetryHistory.Snapshot()[0].CpuPercent!=999,"history snapshot isolated");SessionTelemetryHistory.ClearForTest();
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

                Check(WorkspaceExport.CsvCell("  =1+2").StartsWith("\"'"),"CSV leading-space formula blocked");
                var reordered=new AppConfig{MetricOrder="NET;VRAM;GPU;RAM;CPU;DISK"};reordered.Normalize();
                using(var renderer=new OverlayForm(reordered,true)){
                    string[] keys=renderer.WorkspaceMetricKeysForProof();
                    Check(keys.Length==6&&keys[0]=="NET"&&keys[1]=="VRAM"&&keys[2]=="GPU","renderer applies group ordering with independent VRAM");
                }
                CheckTrafficLedger();CheckProfileAndStatistics();CheckHardwareAndContrast();
                Console.WriteLine("TBME_WORKSPACE_SELFTEST=PASS THEMES=48 STUDIO=20 SCHEMA=7 LEGACY_SCHEMA_RANGE=0..6 ORDER_INTEGRATED=TRUE UNAVAILABLE_GAPS=TRUE");
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
                Native.EnableDpi();
                Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
                bool paused=false;Dictionary<string,object> actions=null;int geometry=0;
                using(var renderer=new OverlayForm(c,true))
                {
                    renderer.PrimeSettingsThemePreviewFromLiveMetrics(15,250);
                    var ledger=new TrafficLedger(Path.Combine(outputDirectory,"traffic-proof.json"));
                    ledger.Observe(renderer.WorkspaceSnapshotForProof(),c,DateTime.Now,0);
                    System.Threading.Thread.Sleep(250);renderer.WorkspaceReadForProof();
                    ledger.Observe(renderer.WorkspaceSnapshotForProof(),c,DateTime.Now,.25);
                    using(var f=new WorkspaceForm(c,renderer.WorkspaceSnapshotForProof,()=>paused,b=>paused=b,ledger,()=>new AlertRecord[0],()=>{},()=>{},renderer.RenderSettingsThemePreview,true))
                    {
                        f.PrepareProofProcesses();f.Show();Application.DoEvents();
                        actions=f.VerifyActualActions(renderer.WorkspaceMetricKeysForProof,renderer.WorkspaceNetworkTextForProof);
                        geometry=renderer.VerifyStudioGeometry();
                        f.CapturePages(outputDirectory);
                        f.Size=new Size(900,620);Application.DoEvents();f.CapturePages(Path.Combine(outputDirectory,"minimum"));f.Close();
                    }
                }
                string[] pages={"overview.png","processes.png","network.png","storage.png","alerts.png","themes.png","profiles.png","hardware.png"};
                foreach(string p in pages)CheckFile(Path.Combine(outputDirectory,p));
                var manifest=new Dictionary<string,object>{{"Version",BuildInfo.Version},{"PublicVersion",BuildInfo.PublicVersion},{"GeneratedUtc",DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)},{"Status","PASS"},{"NoSyntheticMetricData",true},{"LiveSampleCount",SessionTelemetryHistory.Count},{"UIActions",actions},{"GeometryUniqueSamePalette",geometry},{"MinimumSizePages",8},{"ThemeCount",ThemeCatalog.Names.Length},{"StudioThemeCount",20},{"Pages",pages}};
                File.WriteAllText(Path.Combine(outputDirectory,"WORKSPACE_PROOF_MANIFEST.json"),new JavaScriptSerializer().Serialize(manifest),new UTF8Encoding(false));
                Console.WriteLine("TBME_WORKSPACE_PROOF=PASS PAGES=8 THEMES=48 DIR="+outputDirectory);
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
