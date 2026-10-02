// Read-only diagnostics, bounded analytics and opt-in local traffic retention.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

namespace TaskbarMonitorEnhanced
{
    public sealed partial class AppConfig
    {
        public bool EnableUsageNotifications { get; set; }
        public int CpuUsageWarningPercent { get; set; }
        public int RamUsageWarningPercent { get; set; }
        public int GpuUsageWarningPercent { get; set; }
        public int DiskSpaceWarningPercent { get; set; }
        public int SustainedAlertSeconds { get; set; }
        public int UsageAlertCooldownMinutes { get; set; }
        public bool QuietHoursEnabled { get; set; }
        public int QuietHoursStart { get; set; }
        public int QuietHoursEnd { get; set; }
        public bool RecordTrafficHistory { get; set; }
        public string TrafficAdapterId { get; set; }
        public int MonthlyTrafficBudgetGB { get; set; }
        public bool NetworkRateInBits { get; set; }
        public string FavoriteThemes { get; set; }
        public string MetricOrder { get; set; }
        private void InitializeWorkspaceDefaults()
        {
            EnableUsageNotifications=false; CpuUsageWarningPercent=95; RamUsageWarningPercent=90; GpuUsageWarningPercent=95;
            DiskSpaceWarningPercent=95; SustainedAlertSeconds=30; UsageAlertCooldownMinutes=10;
            QuietHoursEnabled=false; QuietHoursStart=22; QuietHoursEnd=8; RecordTrafficHistory=false;
            TrafficAdapterId=""; MonthlyTrafficBudgetGB=0; NetworkRateInBits=false; FavoriteThemes="";
            MetricOrder="CPU;RAM;DISK;GPU;VRAM;NET";
        }
        private void NormalizeWorkspace()
        {
            if(ConfigSchemaVersion<7){InitializeWorkspaceDefaults();ConfigSchemaVersion=7;}
            CpuUsageWarningPercent=Clamp(CpuUsageWarningPercent,50,100);RamUsageWarningPercent=Clamp(RamUsageWarningPercent,50,100);
            GpuUsageWarningPercent=Clamp(GpuUsageWarningPercent,50,100);DiskSpaceWarningPercent=Clamp(DiskSpaceWarningPercent,50,100);
            SustainedAlertSeconds=Clamp(SustainedAlertSeconds,5,300);UsageAlertCooldownMinutes=Clamp(UsageAlertCooldownMinutes,1,120);
            QuietHoursStart=Clamp(QuietHoursStart,0,23);QuietHoursEnd=Clamp(QuietHoursEnd,0,23);
            TrafficAdapterId=(TrafficAdapterId??"").Trim(); if(TrafficAdapterId.Length>256)TrafficAdapterId="";
            MonthlyTrafficBudgetGB=Clamp(MonthlyTrafficBudgetGB,0,100000);
            FavoriteThemes=SelectionUtil.Join(SelectionUtil.Parse(FavoriteThemes).Where(x=>ThemeCatalog.Names.Contains(x)));
            string[] groups={"CPU","RAM","DISK","GPU","VRAM","NET"};
            MetricOrder=String.Join(";",(MetricOrder??"").Split(';').Where(x=>groups.Contains(x)).Concat(groups).Distinct().ToArray());
        }
        private static int Clamp(int value,int min,int max){return Math.Max(min,Math.Min(max,value));}
    }

    internal static partial class SessionTelemetryHistory
    {
        internal static SessionTelemetrySample[] Snapshot()
        {lock(Sync)return Samples.Select(x=>x.Copy()).ToArray();}
    }
    internal sealed class MetricStatistics
    {
        internal int Count; internal double Minimum,Maximum,Average,P95;
        internal static bool Finite(double v){return !Double.IsNaN(v)&&!Double.IsInfinity(v);}
        internal static MetricStatistics Calculate(IEnumerable<double?> values)
        {
            double[] sorted=values.Where(x=>x.HasValue&&Finite(x.Value)).Select(x=>x.Value).OrderBy(x=>x).ToArray();
            var r=new MetricStatistics{Count=sorted.Length};
            if(sorted.Length==0)return r;
            r.Minimum=sorted[0];r.Maximum=sorted[sorted.Length-1];r.Average=sorted.Average();
            r.P95=sorted[Math.Max(0,(int)Math.Ceiling(sorted.Length*.95)-1)];return r;
        }
    }
    internal static class WorkspaceMetric
    {
        internal static readonly string[] Names={"CPU %","RAM %","GPU %","VRAM %","Download Mbps","Upload Mbps","Disk read MiB/s","Disk write MiB/s","CPU temperature C","GPU temperature C","Disk temperature C"};
        internal static double? Value(SessionTelemetrySample s,int metric)
        {
            switch(metric){case 0:return s.CpuPercent;case 1:return s.RamPercent;case 2:return s.GpuUsageAvailable?(double?)s.GpuPercent:null;
            case 3:return s.VramTotalGb>0?(double?)(100*s.VramUsedGb/s.VramTotalGb):null;
            case 4:return s.NetworkAvailable?(double?)s.NetDownMbps:null;case 5:return s.NetworkAvailable?(double?)s.NetUpMbps:null;case 6:return s.DiskRateAvailable?(double?)s.DiskReadMBps:null;case 7:return s.DiskRateAvailable?(double?)s.DiskWriteMBps:null;
            case 8:return s.CpuTempC;case 9:return s.GpuTempC;case 10:return s.DiskTempC;default:return null;}
        }
    }
    internal sealed class AlertRecord
    {
        public DateTime Utc {get;set;} public string Metric {get;set;} public string Message {get;set;}
    }
    internal sealed class SustainedAlertGate
    {
        private sealed class Lane {internal double Since=-1,Last=-1;internal bool Sent;internal double Threshold;}
        private readonly Dictionary<string,Lane> lanes=new Dictionary<string,Lane>();
        internal bool Observe(string id,bool available,double value,double threshold,double seconds,int dwell,int cooldownMinutes)
        {
            Lane s;if(!lanes.TryGetValue(id,out s)){s=new Lane{Threshold=threshold};lanes[id]=s;}
            if(s.Threshold!=threshold){s.Since=-1;s.Sent=false;s.Threshold=threshold;}
            if(!available||!MetricStatistics.Finite(value)||!MetricStatistics.Finite(threshold)||!MetricStatistics.Finite(seconds)){s.Since=-1;s.Sent=false;return false;}
            if(s.Since>seconds){s.Since=-1;s.Sent=false;}
            if(value<=threshold-5){s.Since=-1;s.Sent=false;return false;}
            if(value<threshold){s.Since=-1;return false;}
            if(s.Sent)return false;
            if(s.Since<0)s.Since=seconds;
            if(seconds-s.Since<dwell)return false;
            if(s.Last>=0&&seconds-s.Last<cooldownMinutes*60)return false;
            s.Sent=true;s.Last=seconds;return true;
        }
        internal void Reset(){lanes.Clear();}
        internal static bool IsQuiet(bool enabled,int start,int end,DateTime local)
        {return enabled&&(start==end||(start<end?local.Hour>=start&&local.Hour<end:local.Hour>=start||local.Hour<end));}
    }
    internal sealed class TrafficDay
    {
        public string Day {get;set;} public double DownloadBytes {get;set;} public double UploadBytes {get;set;}
    }
    internal sealed class TrafficLedger
    {
        internal const int RetentionDays=90;
        private readonly object sync=new object();
        private readonly Dictionary<string,TrafficDay> days=new Dictionary<string,TrafficDay>();
        private string adapter="", requested=""; private long rx=-1,tx=-1; private double previousSeconds=-1,lastSave=-1;
        private bool loaded,persistenceBlocked; private readonly string path;
        private readonly object saveSync=new object(); private string pendingJson; private bool saving;
        private readonly ManualResetEventSlim saved=new ManualResetEventSlim(true);
        internal string ActiveAdapterName {get;private set;}
        internal double SessionDownload {get;private set;} internal double SessionUpload {get;private set;}
        internal string LastError {get;private set;}
        internal TrafficLedger(string storagePath){path=storagePath;ActiveAdapterName="Waiting for a network sample";}
        internal void ResetBaseline(){adapter="";rx=tx=-1;previousSeconds=-1;}
        internal static double CounterDelta(long previous,long current){return previous>=0&&current>=previous?(double)(current-previous):0;}
        internal void Observe(MetricsSnapshot s,AppConfig c,DateTime now,double elapsed)
        {
            if(c.RecordTrafficHistory&&!loaded)Load();
            if(requested!=(c.TrafficAdapterId??"")){requested=c.TrafficAdapterId??"";ResetBaseline();}
            var candidates=(s.NetworkDevices??new List<NetworkDeviceSnapshot>()).Where(n=>n!=null&&n.Active&&n.CountersAvailable).ToList();
            NetworkDeviceSnapshot d=candidates.FirstOrDefault(n=>n.Id==(String.IsNullOrEmpty(requested)?adapter:requested));
            if(d==null&&String.IsNullOrEmpty(requested))d=candidates.OrderByDescending(n=>n.DownBytesPerSec+n.UpBytesPerSec).ThenByDescending(n=>n.LinkSpeedBitsPerSec).FirstOrDefault();
            if(d==null){ResetBaseline();ActiveAdapterName="Selected adapter unavailable";return;}
            ActiveAdapterName=d.Name;
            double down=0,up=0;
            if(adapter==d.Id&&previousSeconds>=0&&elapsed>previousSeconds&&elapsed-previousSeconds<=30){down=CounterDelta(rx,d.ReceivedBytesTotal);up=CounterDelta(tx,d.SentBytesTotal);}
            adapter=d.Id;rx=d.ReceivedBytesTotal;tx=d.SentBytesTotal;previousSeconds=elapsed;
            SessionDownload+=down;SessionUpload+=up;
            string key=now.ToString("yyyy-MM-dd",CultureInfo.InvariantCulture);
            lock(sync){TrafficDay day;if(!days.TryGetValue(key,out day)){day=new TrafficDay{Day=key};days[key]=day;}day.DownloadBytes+=down;day.UploadBytes+=up;Prune(now);}
            if(c.RecordTrafficHistory&&(lastSave<0||elapsed-lastSave>=60)){lastSave=elapsed;FlushAsync();}
        }
        private void Prune(DateTime now)
        {
            string oldest=now.Date.AddDays(1-RetentionDays).ToString("yyyy-MM-dd",CultureInfo.InvariantCulture);
            string newest=now.Date.ToString("yyyy-MM-dd",CultureInfo.InvariantCulture);
            foreach(string key in days.Keys.Where(k=>String.CompareOrdinal(k,oldest)<0||String.CompareOrdinal(k,newest)>0).ToArray())days.Remove(key);
            foreach(string key in days.Keys.OrderByDescending(k=>k).Skip(RetentionDays).ToArray())days.Remove(key);
        }
        private void Load()
        {
            loaded=true;
            try{
                if(!File.Exists(path))return;
                if(new FileInfo(path).Length>65536)throw new InvalidDataException("Traffic history exceeds 64 KiB.");
                TrafficDay[] old=new JavaScriptSerializer().Deserialize<TrafficDay[]>(File.ReadAllText(path,Encoding.UTF8));
                lock(sync)foreach(var d in old??new TrafficDay[0]){DateTime dt;if(d==null||!DateTime.TryParseExact(d.Day,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out dt)||d.DownloadBytes<0||d.UploadBytes<0||!MetricStatistics.Finite(d.DownloadBytes)||!MetricStatistics.Finite(d.UploadBytes))continue;
                    TrafficDay current;if(days.TryGetValue(d.Day,out current)){current.DownloadBytes+=d.DownloadBytes;current.UploadBytes+=d.UploadBytes;}else days[d.Day]=d;}
                lock(sync)Prune(DateTime.Now);
            }catch(Exception ex){persistenceBlocked=true;LastError="History preserved; persistence blocked after read failure: "+ex.GetType().Name;Log.Write("WARN","TRAFFIC_HISTORY_READ "+ex.GetType().Name);}
        }
        internal TrafficDay[] Snapshot(){lock(sync)return days.Values.OrderByDescending(d=>d.Day).Select(d=>new TrafficDay{Day=d.Day,DownloadBytes=d.DownloadBytes,UploadBytes=d.UploadBytes}).ToArray();}
        internal void FlushAsync()
        {
            if(persistenceBlocked)return;
            string json=new JavaScriptSerializer().Serialize(Snapshot());
            lock(saveSync){pendingJson=json;saved.Reset();if(saving)return;saving=true;}
            ThreadPool.QueueUserWorkItem(delegate{
                while(true){string current;lock(saveSync){current=pendingJson;pendingJson=null;}
                    try{AtomicTextFile.Write(path,current,new UTF8Encoding(false),path+".bak");LastError=null;}
                    catch(Exception ex){LastError="History save failed: "+ex.GetType().Name;Log.Write("WARN","TRAFFIC_HISTORY_WRITE "+ex.GetType().Name);}
                    lock(saveSync){if(pendingJson==null){saving=false;saved.Set();return;}}
                }
            });
        }
        internal bool FlushAndWait(int milliseconds)
        {if(persistenceBlocked)return false;FlushAsync();return saved.Wait(Math.Max(0,milliseconds));}
        internal void ExportCsv(string destination)
        {
            var b=new StringBuilder("Day,DownloadBytes,UploadBytes\r\n");foreach(var d in Snapshot())b.AppendLine(d.Day+","+d.DownloadBytes.ToString("0",CultureInfo.InvariantCulture)+","+d.UploadBytes.ToString("0",CultureInfo.InvariantCulture));
            File.WriteAllText(destination,b.ToString(),new UTF8Encoding(false));
        }
    }
    internal sealed class ProcessRow
    {
        public int Pid {get;set;} public string Name {get;set;} public double? CpuPercent {get;set;}
        public double WorkingSetMiB {get;set;} public double PrivateMiB {get;set;} public int? Threads {get;set;} public int? Handles {get;set;}
    }
    internal sealed class ProcessSampler
    {
        private sealed class Baseline{internal long Start, Cpu;internal double At;}
        private Dictionary<int,Baseline> previous=new Dictionary<int,Baseline>();
        internal List<ProcessRow> Read(double seconds)
        {
            var rows=new List<ProcessRow>();var next=new Dictionary<int,Baseline>();
            foreach(Process p in Process.GetProcesses())using(p){try{
                var row=new ProcessRow{Pid=p.Id,Name=p.ProcessName,WorkingSetMiB=p.WorkingSet64/1048576d,PrivateMiB=p.PrivateMemorySize64/1048576d};
                try{row.Threads=p.Threads.Count;row.Handles=p.HandleCount;}catch{}
                try{long start=p.StartTime.ToUniversalTime().Ticks, cpu=p.TotalProcessorTime.Ticks;Baseline b;
                    if(previous.TryGetValue(p.Id,out b)&&b.Start==start&&seconds>b.At&&seconds-b.At<=10&&cpu>=b.Cpu)row.CpuPercent=Math.Max(0,Math.Min(100,(cpu-b.Cpu)/10000000d/(seconds-b.At)/Math.Max(1,Environment.ProcessorCount)*100));
                    next[p.Id]=new Baseline{Start=start,Cpu=cpu,At=seconds};}catch{}
                rows.Add(row);
            }catch{}}
            previous=next;return rows;
        }
    }
    internal static class WorkspaceExport
    {
        internal static string CsvCell(string s)
        {s=s??"";if(s.TrimStart().Length>0&&"=+-@".IndexOf(s.TrimStart()[0])>=0)s="'"+s;return "\""+s.Replace("\"","\"\"")+"\"";}
        internal static void Processes(string path,IEnumerable<ProcessRow> rows)
        {
            var b=new StringBuilder("PID,Name,CPUPercent,WorkingSetMiB,PrivateMiB,Threads,Handles\r\n");
            foreach(var r in rows)b.AppendLine(r.Pid+","+CsvCell(r.Name)+","+(r.CpuPercent.HasValue?r.CpuPercent.Value.ToString("0.###",CultureInfo.InvariantCulture):"")+","+r.WorkingSetMiB.ToString("0.###",CultureInfo.InvariantCulture)+","+r.PrivateMiB.ToString("0.###",CultureInfo.InvariantCulture)+","+r.Threads+","+r.Handles);
            File.WriteAllText(path,b.ToString(),new UTF8Encoding(false));
        }
        // Presentation-only profiles cannot import startup commands, sensor paths, notifications or tracking preferences.
        internal static string Profile(AppConfig c)
        {return new JavaScriptSerializer().Serialize(new Dictionary<string,object>{{"Format","TBME-Presentation-1"},{"Theme",c.Theme},{"ShowSparklines",c.ShowSparklines},{"ShowTemperatures",c.ShowTemperatures},{"FontSize",c.FontSize},{"Opacity",c.Opacity},{"MetricOrder",c.MetricOrder},{"NetworkRateInBits",c.NetworkRateInBits},{"ShowCpu",c.ShowCpu},{"ShowRam",c.ShowRam},{"ShowDisk",c.ShowDisk},{"ShowGpu",c.ShowGpu},{"ShowVram",c.ShowVram},{"ShowNetwork",c.ShowNetwork}});}
        internal static void ImportProfile(AppConfig c,string path)
        {
            if(new FileInfo(path).Length>65536)throw new InvalidDataException("Profile exceeds 64 KiB.");
            var d=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(path,Encoding.UTF8));
            if(d==null||!d.ContainsKey("Format")||Convert.ToString(d["Format"])!="TBME-Presentation-1")throw new InvalidDataException("Not a TBME presentation profile.");
            AppConfig candidate=new JavaScriptSerializer().Deserialize<AppConfig>(new JavaScriptSerializer().Serialize(c));
            foreach(var p in typeof(AppConfig).GetProperties())if(d.ContainsKey(p.Name)){
                if(!(p.Name=="Theme"||p.Name=="ShowSparklines"||p.Name=="ShowTemperatures"||p.Name=="FontSize"||p.Name=="Opacity"||p.Name=="MetricOrder"||p.Name=="NetworkRateInBits"||p.Name=="ShowCpu"||p.Name=="ShowRam"||p.Name=="ShowDisk"||p.Name=="ShowGpu"||p.Name=="ShowVram"||p.Name=="ShowNetwork"))continue;
                p.SetValue(candidate,Convert.ChangeType(d[p.Name],p.PropertyType,CultureInfo.InvariantCulture),null);
            }
            candidate.Normalize();
            var allowed=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(Profile(candidate));
            foreach(var p in typeof(AppConfig).GetProperties())if(allowed.ContainsKey(p.Name))p.SetValue(c,p.GetValue(candidate,null),null);
        }
    }
}
