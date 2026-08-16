using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Principal;
using System.Threading;
using System.Web.Script.Serialization;
using LibreHardwareMonitor.Hardware;

namespace TaskbarMonitorSensorBroker
{
    internal sealed class UpdateVisitor : IVisitor
    {
        public void VisitComputer(IComputer computer) { computer.Traverse(this); }
        public void VisitHardware(IHardware hardware)
        {
            hardware.Update();
            foreach(IHardware subHardware in hardware.SubHardware)
                subHardware.Accept(this);
        }
        public void VisitSensor(ISensor sensor) { }
        public void VisitParameter(IParameter parameter) { }
    }

    internal sealed class TempRecord
    {
        public DateTime TimestampUtc;
        public bool Available;
        public float CurrentC;
        public float AverageC;
        public float MaximumC;
        public string Sensor;
        public string CpuName;
        public string Error;
        public bool Is64BitProcess;
        public bool IsElevated;
        public List<string> CpuTemperatureSensors = new List<string>();
    }

    internal static class Program
    {
        private static void BrokerLog(string message)
        {
            try
            {
                string path=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"sensor_broker.log");
                File.AppendAllText(path,DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)+" "+message+Environment.NewLine);
            }
            catch{}
        }

        private static bool Valid(float? v)
        {
            return v.HasValue && !Single.IsNaN(v.Value) && !Single.IsInfinity(v.Value) && v.Value >= 5f && v.Value <= 130f;
        }

        private static int Priority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n.Contains("cpu package")) return 100;
            if(n=="package" || n.Contains(" package")) return 97;
            if(n.Contains("tctl/tdie")) return 96;
            if(n.Contains("tctl")) return 95;
            if(n.Contains("tdie")) return 94;
            if(n.Contains("core max")) return 92;
            if(n.Contains("cores max")) return 91;
            if(n.Contains("core average")) return 85;
            if(n.Contains("cores average")) return 84;
            if(n.Contains("cpu core")) return 75;
            if(n.Contains("core #")) return 74;
            return 20;
        }

        private static bool IsElevated()
        {
            try
            {
                WindowsIdentity id=WindowsIdentity.GetCurrent();
                WindowsPrincipal p=new WindowsPrincipal(id);
                return p.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch { return false; }
        }

        private static TempRecord Read(Computer computer)
        {
            TempRecord r=new TempRecord();
            r.TimestampUtc=DateTime.UtcNow;
            r.Is64BitProcess=Environment.Is64BitProcess;
            r.IsElevated=IsElevated();
            try
            {
                computer.Accept(new UpdateVisitor());
                Thread.Sleep(120);
                computer.Accept(new UpdateVisitor());
                List<Tuple<string,float>> temps=new List<Tuple<string,float>>();
                foreach(IHardware hw in computer.Hardware)
                {
                    if(hw.HardwareType != HardwareType.Cpu) continue;
                    r.CpuName=hw.Name;
                    foreach(ISensor sensor in hw.Sensors)
                    {
                        if(sensor.SensorType != SensorType.Temperature) continue;
                        string valueText=sensor.Value.HasValue ? sensor.Value.Value.ToString("0.0",CultureInfo.InvariantCulture) : "NULL";
                        r.CpuTemperatureSensors.Add(sensor.Name+"="+valueText);
                        if(Valid(sensor.Value)) temps.Add(Tuple.Create(sensor.Name,sensor.Value.Value));
                    }
                    foreach(IHardware sub in hw.SubHardware)
                    {
                        foreach(ISensor sensor in sub.Sensors)
                        {
                            if(sensor.SensorType != SensorType.Temperature) continue;
                            string valueText=sensor.Value.HasValue ? sensor.Value.Value.ToString("0.0",CultureInfo.InvariantCulture) : "NULL";
                            r.CpuTemperatureSensors.Add(sub.Name+"/"+sensor.Name+"="+valueText);
                            if(Valid(sensor.Value)) temps.Add(Tuple.Create(sub.Name+"/"+sensor.Name,sensor.Value.Value));
                        }
                    }
                }
                if(temps.Count==0)
                {
                    r.Available=false;
                    r.Error="No valid CPU temperature values. Sensors="+String.Join(";",r.CpuTemperatureSensors.ToArray());
                    return r;
                }
                Tuple<string,float> chosen=temps.OrderByDescending(x=>Priority(x.Item1)).ThenByDescending(x=>x.Item2).First();
                List<float> core=temps.Where(x=>x.Item1.IndexOf("core",StringComparison.OrdinalIgnoreCase)>=0 && x.Item1.IndexOf("max",StringComparison.OrdinalIgnoreCase)<0 && x.Item1.IndexOf("average",StringComparison.OrdinalIgnoreCase)<0).Select(x=>x.Item2).ToList();
                r.Available=true;
                r.CurrentC=chosen.Item2;
                r.AverageC=core.Count>0 ? core.Average() : temps.Average(x=>x.Item2);
                r.MaximumC=temps.Max(x=>x.Item2);
                r.Sensor=chosen.Item1;
                r.Error="";
                return r;
            }
            catch(Exception ex)
            {
                r.Available=false;
                r.Error=ex.ToString();
                return r;
            }
        }

        private static void AtomicWrite(string path,TempRecord r)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            JavaScriptSerializer js=new JavaScriptSerializer();
            string json=js.Serialize(new Dictionary<string,object> {
                {"TimestampUtc",r.TimestampUtc.ToString("o",CultureInfo.InvariantCulture)},
                {"Available",r.Available},{"CurrentC",r.CurrentC},{"AverageC",r.AverageC},{"MaximumC",r.MaximumC},
                {"Sensor",r.Sensor??""},{"CpuName",r.CpuName??""},{"Error",r.Error??""},{"Is64BitProcess",r.Is64BitProcess},
                {"IsElevated",r.IsElevated},{"CpuTemperatureSensors",r.CpuTemperatureSensors.ToArray()},{"BrokerPid",Process.GetCurrentProcess().Id}
            });
            string tmp=path+"."+Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture)+"."+Environment.TickCount.ToString(CultureInfo.InvariantCulture)+".tmp";
            File.WriteAllText(tmp,json);
            Exception last=null;
            for(int attempt=0;attempt<5;attempt++)
            {
                try
                {
                    if(File.Exists(path))
                    {
                        try
                        {
                            string bak=path+".bak";
                            File.Replace(tmp,path,bak,true);
                            try{File.Delete(bak);}catch{}
                            return;
                        }
                        catch{}
                    }
                    File.Copy(tmp,path,true);
                    try{File.Delete(tmp);}catch{}
                    return;
                }
                catch(Exception ex)
                {
                    last=ex;
                    Thread.Sleep(60*(attempt+1));
                }
            }
            try{File.Delete(tmp);}catch{}
            if(last!=null)throw last;
        }

        private static int Main(string[] args)
        {
            if(args==null || args.Length<2) return 2;
            string mode=args[0];
            string output=args[1];
            Environment.CurrentDirectory=AppDomain.CurrentDomain.BaseDirectory;
            Computer computer=new Computer { IsCpuEnabled=true, IsGpuEnabled=false, IsMemoryEnabled=false, IsMotherboardEnabled=false, IsControllerEnabled=false, IsNetworkEnabled=false, IsStorageEnabled=false };
            try
            {
                computer.Open();
                if(String.Equals(mode,"--once",StringComparison.OrdinalIgnoreCase))
                {
                    TempRecord record=null;
                    for(int i=0;i<8;i++)
                    {
                        record=Read(computer);
                        AtomicWrite(output,record);
                        if(record.Available) return 0;
                        Thread.Sleep(250);
                    }
                    return 5;
                }
                if(String.Equals(mode,"--run",StringComparison.OrdinalIgnoreCase))
                {
                    BrokerLog("BROKER_RUN_START pid="+Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture));
                    int consecutiveFailures=0;
                    while(true)
                    {
                        try
                        {
                            TempRecord record=Read(computer);
                            AtomicWrite(output,record);
                            consecutiveFailures=0;
                        }
                        catch(Exception loopEx)
                        {
                            consecutiveFailures++;
                            BrokerLog("BROKER_LOOP_FAILURE count="+consecutiveFailures.ToString(CultureInfo.InvariantCulture)+" error="+loopEx.ToString());
                            if(consecutiveFailures>=5)
                            {
                                try{computer.Close();}catch{}
                                Thread.Sleep(500);
                                try{computer.Open();BrokerLog("BROKER_COMPUTER_REOPEN_PASS");}
                                catch(Exception reopenEx){BrokerLog("BROKER_COMPUTER_REOPEN_FAIL "+reopenEx.ToString());}
                                consecutiveFailures=0;
                            }
                        }
                        Thread.Sleep(900);
                    }
                }
                return 3;
            }
            catch(Exception ex)
            {
                try
                {
                    TempRecord r=new TempRecord();
                    r.TimestampUtc=DateTime.UtcNow;
                    r.Available=false;
                    r.Error=ex.ToString();
                    r.Is64BitProcess=Environment.Is64BitProcess;
                    r.IsElevated=IsElevated();
                    AtomicWrite(output,r);
                }
                catch{}
                return 6;
            }
            finally
            {
                try{computer.Close();}catch{}
            }
        }
    }
}
