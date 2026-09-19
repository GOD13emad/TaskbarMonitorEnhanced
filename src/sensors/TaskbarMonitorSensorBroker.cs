using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Principal;
using System.Threading;
using System.Web.Script.Serialization;
using LibreHardwareMonitor.Hardware;

[assembly: AssemblyTitle("Taskbar Monitor Enhanced Sensor Broker")]
[assembly: AssemblyDescription("Isolated LibreHardwareMonitor sensor worker for Taskbar Monitor Enhanced")]
[assembly: AssemblyProduct("Taskbar Monitor Enhanced")]
[assembly: AssemblyCompany("Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyInformationalVersion("1.1.2-rc2+r21")]
[assembly: AssemblyVersion("1.1.2.0")]
[assembly: AssemblyFileVersion("1.1.2.0")]

namespace TaskbarMonitorSensorBroker
{
    internal sealed class StorageTempRecord
    {
        public bool Available;
        public string HardwareName="";
        public string HardwareId="";
        public float TemperatureC;
        public string Sensor="";
        public List<string> TemperatureSensors=new List<string>();
    }

    internal sealed class GpuRecord
    {
        public bool Available;
        public bool LoadValid;
        public bool TemperatureValid;
        public bool CoreClockValid;
        public bool MemoryClockValid;
        public bool PowerValid;
        public bool FanRpmValid;
        public bool FanPercentValid;
        public float Load;
        public float Temperature;
        public float VramUsedGb;
        public float VramTotalGb;
        public float CoreClockMHz;
        public float MemoryClockMHz;
        public float PowerW;
        public float FanRpm;
        public float FanPercent;
        public int PcieGeneration;
        public int PcieWidth;
        public string Source="";
        public string HardwareName="";
        public string HardwareId="";
        public int AdapterIndex=-1;
    }

    internal static class Program
    {
        private static long SampleSequence=0;
        private static string LogPath
        {
            get { return Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"sensor_broker.log"); }
        }

        private static void Log(string message)
        {
            try
            {
                File.AppendAllText(
                    LogPath,
                    DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)+" "+message+Environment.NewLine
                );
            }
            catch{}
        }

        private static bool IsElevated()
        {
            try
            {
                using(WindowsIdentity id=WindowsIdentity.GetCurrent())
                {
                    WindowsPrincipal p=new WindowsPrincipal(id);
                    return p.IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
            catch{return false;}
        }

        private static bool ValidTemp(float? v)
        {
            return v.HasValue &&
                   !Single.IsNaN(v.Value) &&
                   !Single.IsInfinity(v.Value) &&
                   v.Value>=5f && v.Value<=130f;
        }

        private static void UpdateTree(IHardware hw)
        {
            if(hw==null)return;
            hw.Update();
            foreach(IHardware sub in hw.SubHardware)UpdateTree(sub);
        }

        private static void AtomicWrite(string path,string json)
        {
            string parent=Path.GetDirectoryName(path);
            if(!String.IsNullOrWhiteSpace(parent))Directory.CreateDirectory(parent);
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

        private static string Json(Dictionary<string,object> m)
        {
            return new JavaScriptSerializer().Serialize(m);
        }

        private static int CpuPriority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n.Contains("cpu package"))return 100;
            if(n=="package"||n.Contains(" package"))return 97;
            if(n.Contains("tctl/tdie"))return 96;
            if(n.Contains("tctl"))return 95;
            if(n.Contains("tdie"))return 94;
            if(n.Contains("core max"))return 92;
            if(n.Contains("cores max"))return 91;
            if(n.Contains("core average"))return 85;
            if(n.Contains("cores average"))return 84;
            if(n.Contains("cpu core"))return 75;
            if(n.Contains("core #"))return 74;
            return 20;
        }

        private static int CpuPowerPriority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n.Contains("cpu package"))return 100;
            if(n=="package"||n.Contains("package power"))return 98;
            if(n.Contains("cpu total"))return 95;
            if(n.Contains("cores"))return 70;
            return 40;
        }

        private static Dictionary<string,object> ReadCpu(Computer computer)
        {
            DateTime ts=DateTime.UtcNow;
            string cpuName="";
            List<Tuple<string,float>> temps=new List<Tuple<string,float>>();
            List<Tuple<string,float>> powers=new List<Tuple<string,float>>();
            List<string> raw=new List<string>();
            try
            {
                foreach(IHardware hw in computer.Hardware)
                {
                    if(hw.HardwareType!=HardwareType.Cpu)continue;
                    UpdateTree(hw);
                    cpuName=hw.Name??"";
                    foreach(ISensor sensor in hw.Sensors)
                    {
                        if(sensor.SensorType==SensorType.Temperature)
                        {
                            string value=sensor.Value.HasValue?sensor.Value.Value.ToString("0.0",CultureInfo.InvariantCulture):"NULL";
                            raw.Add(sensor.Name+"="+value);
                            if(ValidTemp(sensor.Value))temps.Add(Tuple.Create(sensor.Name,sensor.Value.Value));
                        }
                        else if(sensor.SensorType==SensorType.Power && sensor.Value.HasValue)
                        {
                            float v=sensor.Value.Value;
                            if(!Single.IsNaN(v)&&!Single.IsInfinity(v)&&v>0.1f&&v<1000) powers.Add(Tuple.Create(sensor.Name??"",v));
                        }
                    }
                    foreach(IHardware sub in hw.SubHardware)
                    {
                        foreach(ISensor sensor in sub.Sensors)
                        {
                            string name=sub.Name+"/"+sensor.Name;
                            if(sensor.SensorType==SensorType.Temperature)
                            {
                                string value=sensor.Value.HasValue?sensor.Value.Value.ToString("0.0",CultureInfo.InvariantCulture):"NULL";
                                raw.Add(name+"="+value);
                                if(ValidTemp(sensor.Value))temps.Add(Tuple.Create(name,sensor.Value.Value));
                            }
                            else if(sensor.SensorType==SensorType.Power && sensor.Value.HasValue)
                            {
                                float v=sensor.Value.Value;
                                if(!Single.IsNaN(v)&&!Single.IsInfinity(v)&&v>0.1f&&v<1000)powers.Add(Tuple.Create(name,v));
                            }
                        }
                    }
                }

                float current=0,average=0,maximum=0;
                string chosenName="";
                bool available=temps.Count>0;
                if(available)
                {
                    Tuple<string,float> chosen=temps.OrderByDescending(x=>CpuPriority(x.Item1)).ThenByDescending(x=>x.Item2).First();
                    chosenName=chosen.Item1;
                    current=chosen.Item2;
                    List<float> cores=temps
                        .Where(x=>x.Item1.IndexOf("core",StringComparison.OrdinalIgnoreCase)>=0 &&
                                  x.Item1.IndexOf("max",StringComparison.OrdinalIgnoreCase)<0 &&
                                  x.Item1.IndexOf("average",StringComparison.OrdinalIgnoreCase)<0 &&
                                  x.Item1.IndexOf("distance",StringComparison.OrdinalIgnoreCase)<0)
                        .Select(x=>x.Item2).ToList();
                    average=cores.Count>0?cores.Average():temps.Average(x=>x.Item2);
                    maximum=temps.Where(x=>x.Item1.IndexOf("distance",StringComparison.OrdinalIgnoreCase)<0).Select(x=>x.Item2).DefaultIfEmpty(current).Max();
                }

                bool powerAvailable=powers.Count>0;
                float packagePower=0f;
                string powerSensor="";
                if(powerAvailable)
                {
                    Tuple<string,float> pwr=powers.OrderByDescending(x=>CpuPowerPriority(x.Item1)).ThenByDescending(x=>x.Item2).First();
                    packagePower=pwr.Item2;
                    powerSensor=pwr.Item1;
                }

                return new Dictionary<string,object>{
                    {"TimestampUtc",ts.ToString("o",CultureInfo.InvariantCulture)},
                    {"Available",available},
                    {"CurrentC",current},
                    {"AverageC",average},
                    {"MaximumC",maximum},
                    {"Sensor",chosenName},
                    {"CpuName",cpuName},
                    {"PackagePowerAvailable",powerAvailable},
                    {"PackagePowerW",packagePower},
                    {"PackagePowerSensor",powerSensor},
                    {"Error",available?"":"No valid CPU temperature values."},
                    {"Is64BitProcess",Environment.Is64BitProcess},
                    {"IsElevated",IsElevated()},
                    {"CpuTemperatureSensors",raw.ToArray()},
                    {"BrokerPid",Process.GetCurrentProcess().Id},
                    {"BrokerMode","CPU"},
                    {"BrokerVersion","1.1.2-rc2+r21"}
                };
            }
            catch(Exception ex)
            {
                return new Dictionary<string,object>{
                    {"TimestampUtc",ts.ToString("o",CultureInfo.InvariantCulture)},
                    {"Available",false},
                    {"CurrentC",0f},{"AverageC",0f},{"MaximumC",0f},{"Sensor",""},{"CpuName",cpuName},
                    {"PackagePowerAvailable",false},{"PackagePowerW",0f},{"PackagePowerSensor",""},
                    {"Error",ex.ToString()},
                    {"Is64BitProcess",Environment.Is64BitProcess},
                    {"IsElevated",IsElevated()},
                    {"CpuTemperatureSensors",raw.ToArray()},
                    {"BrokerPid",Process.GetCurrentProcess().Id},
                    {"BrokerMode","CPU"},
                    {"BrokerVersion","1.1.2-rc2+r21"}
                };
            }
        }

        private static int StoragePriority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n=="temperature")return 100;
            if(n.Contains("drive")&&n.Contains("temperature"))return 98;
            if(n.Contains("composite"))return 96;
            if(n.Contains("temperature #1")||n.Contains("temperature 1"))return 92;
            if(n.Contains("controller"))return 70;
            if(n.Contains("memory"))return 50;
            return 60;
        }

        private static void CollectStorage(IHardware hw,string prefix,List<Tuple<string,float>> valid,List<string> raw)
        {
            if(hw==null)return;
            foreach(ISensor sensor in hw.Sensors)
            {
                if(sensor.SensorType!=SensorType.Temperature)continue;
                string name=String.IsNullOrWhiteSpace(prefix)?sensor.Name:(prefix+"/"+sensor.Name);
                string value=sensor.Value.HasValue?sensor.Value.Value.ToString("0.0",CultureInfo.InvariantCulture):"NULL";
                raw.Add(name+"="+value);
                if(ValidTemp(sensor.Value))valid.Add(Tuple.Create(name,sensor.Value.Value));
            }
            foreach(IHardware sub in hw.SubHardware)
                CollectStorage(sub,String.IsNullOrWhiteSpace(prefix)?sub.Name:(prefix+"/"+sub.Name),valid,raw);
        }

        private static Dictionary<string,object> ReadStorage(Computer computer)
        {
            DateTime ts=DateTime.UtcNow;
            List<StorageTempRecord> records=new List<StorageTempRecord>();
            string error="";
            try
            {
                foreach(IHardware hw in computer.Hardware)
                {
                    if(hw.HardwareType!=HardwareType.Storage)continue;
                    UpdateTree(hw);
                    StorageTempRecord sr=new StorageTempRecord();
                    sr.HardwareName=hw.Name??"";
                    sr.HardwareId=hw.Identifier.ToString();
                    List<Tuple<string,float>> valid=new List<Tuple<string,float>>();
                    CollectStorage(hw,"",valid,sr.TemperatureSensors);
                    if(valid.Count>0)
                    {
                        Tuple<string,float> chosen=valid.OrderByDescending(x=>StoragePriority(x.Item1)).ThenByDescending(x=>x.Item2).First();
                        sr.Available=true;
                        sr.Sensor=chosen.Item1;
                        sr.TemperatureC=chosen.Item2;
                    }
                    records.Add(sr);
                }
            }
            catch(Exception ex){error=ex.ToString();}

            return new Dictionary<string,object>{
                {"TimestampUtc",ts.ToString("o",CultureInfo.InvariantCulture)},
                {"Available",records.Any(x=>x.Available)},
                {"Error",error},
                {"Is64BitProcess",Environment.Is64BitProcess},
                {"IsElevated",IsElevated()},
                {"StorageTemperatures",records.ToArray()},
                {"BrokerPid",Process.GetCurrentProcess().Id},
                {"BrokerMode","STORAGE_ONESHOT"},
                {"BrokerVersion","1.1.2-rc2+r21"}
            };
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

        private static int GpuTempPriority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n=="gpu core")return 100;
            if(n.Contains("gpu core"))return 98;
            if(n=="core")return 96;
            if(n.Contains("hot spot")||n.Contains("hotspot"))return 80;
            if(n.Contains("memory"))return 40;
            return 60;
        }

        private static int GpuPowerPriority(string name)
        {
            string n=(name??"").ToLowerInvariant();
            if(n.Contains("gpu package"))return 100;
            if(n=="gpu power"||n.Contains("board power"))return 98;
            if(n.Contains("gpu core"))return 90;
            if(n.Contains("power"))return 70;
            return 40;
        }

        private static float ToGb(SensorType type,float value)
        {
            if(type==SensorType.SmallData)return value/1024f;
            if(type==SensorType.Data)return value;
            return 0f;
        }

        private static bool IsGpuType(HardwareType t)
        {
            string s=t.ToString();
            return s.IndexOf("Gpu",StringComparison.OrdinalIgnoreCase)>=0;
        }

        private static Dictionary<string,object> ReadGpu(Computer computer)
        {
            DateTime ts=DateTime.UtcNow;
            List<GpuRecord> records=new List<GpuRecord>();
            string error="";
            try
            {
                int adapterIndex=0;
                foreach(IHardware hw in computer.Hardware)
                {
                    if(!IsGpuType(hw.HardwareType))continue;
                    UpdateTree(hw);
                    List<Tuple<string,float>> loads=new List<Tuple<string,float>>();
                    List<Tuple<string,float>> temps=new List<Tuple<string,float>>();
                    List<Tuple<string,float>> clocks=new List<Tuple<string,float>>();
                    List<Tuple<string,float>> powers=new List<Tuple<string,float>>();
                    List<Tuple<string,float>> fans=new List<Tuple<string,float>>();
                    List<Tuple<string,float>> fanControls=new List<Tuple<string,float>>();
                    float dedicatedUsed=0,dedicatedTotal=0,sharedUsed=0,sharedTotal=0,genericUsed=0,genericTotal=0;
                    bool hasDedicatedUsed=false,hasDedicatedTotal=false,hasSharedUsed=false,hasSharedTotal=false,hasGenericUsed=false,hasGenericTotal=false;

                    foreach(ISensor sensor in hw.Sensors)
                    {
                        if(!sensor.Value.HasValue)continue;
                        float value=sensor.Value.Value;
                        if(Single.IsNaN(value)||Single.IsInfinity(value))continue;
                        string name=sensor.Name??"";
                        if(sensor.SensorType==SensorType.Load && value>=0 && value<=100)loads.Add(Tuple.Create(name,value));
                        else if(sensor.SensorType==SensorType.Temperature && value>=5 && value<=130)temps.Add(Tuple.Create(name,value));
                        else if(sensor.SensorType==SensorType.Clock && value>0 && value<100000)clocks.Add(Tuple.Create(name,value));
                        else if(sensor.SensorType==SensorType.Power && value>0.1f && value<2000)powers.Add(Tuple.Create(name,value));
                        else if(sensor.SensorType==SensorType.Fan && value>=0 && value<100000)fans.Add(Tuple.Create(name,value));
                        else if(sensor.SensorType==SensorType.Control && name.IndexOf("fan",StringComparison.OrdinalIgnoreCase)>=0 && value>=0 && value<=100)fanControls.Add(Tuple.Create(name,value));
                        else if(sensor.SensorType==SensorType.SmallData || sensor.SensorType==SensorType.Data)
                        {
                            float gb=ToGb(sensor.SensorType,value);
                            string lower=name.ToLowerInvariant();
                            if(lower.Contains("gpu memory used")){genericUsed=gb;hasGenericUsed=true;}
                            else if(lower.Contains("gpu memory total")){genericTotal=gb;hasGenericTotal=true;}
                            else if(lower.Contains("dedicated memory used")){dedicatedUsed=gb;hasDedicatedUsed=true;}
                            else if(lower.Contains("dedicated memory total")){dedicatedTotal=gb;hasDedicatedTotal=true;}
                            else if(lower.Contains("shared memory used")){sharedUsed=gb;hasSharedUsed=true;}
                            else if(lower.Contains("shared memory total")){sharedTotal=gb;hasSharedTotal=true;}
                        }
                    }

                    GpuRecord g=new GpuRecord();
                    g.Available=true;
                    g.Source="LHM_ISOLATED_GPU:"+hw.HardwareType+":"+hw.Name;
                    g.HardwareName=hw.Name??"";
                    g.HardwareId=hw.Identifier.ToString();
                    g.AdapterIndex=adapterIndex++;
                    g.PcieGeneration=0;g.PcieWidth=0;
                    if(loads.Count>0)
                    {
                        Tuple<string,float> best=loads.OrderByDescending(x=>LoadPriority(x.Item1)).ThenByDescending(x=>x.Item2).First();
                        g.Load=Math.Max(0,Math.Min(100,best.Item2));g.LoadValid=true;
                    }
                    if(temps.Count>0)
                    {
                        Tuple<string,float> best=temps.OrderByDescending(x=>GpuTempPriority(x.Item1)).ThenByDescending(x=>x.Item2).First();
                        g.Temperature=best.Item2;g.TemperatureValid=true;
                    }
                    Tuple<string,float> coreClock=clocks.Where(x=>x.Item1.IndexOf("core",StringComparison.OrdinalIgnoreCase)>=0).OrderByDescending(x=>x.Item2).FirstOrDefault();
                    if(coreClock!=null&&coreClock.Item2>0){g.CoreClockMHz=coreClock.Item2;g.CoreClockValid=true;}
                    Tuple<string,float> memClock=clocks.Where(x=>x.Item1.IndexOf("memory",StringComparison.OrdinalIgnoreCase)>=0).OrderByDescending(x=>x.Item2).FirstOrDefault();
                    if(memClock!=null&&memClock.Item2>0){g.MemoryClockMHz=memClock.Item2;g.MemoryClockValid=true;}
                    Tuple<string,float> power=powers.OrderByDescending(x=>GpuPowerPriority(x.Item1)).ThenByDescending(x=>x.Item2).FirstOrDefault();
                    if(power!=null){g.PowerW=power.Item2;g.PowerValid=true;}
                    Tuple<string,float> fan=fans.OrderByDescending(x=>x.Item2).FirstOrDefault();
                    if(fan!=null){g.FanRpm=fan.Item2;g.FanRpmValid=true;}
                    Tuple<string,float> fanPct=fanControls.OrderByDescending(x=>x.Item2).FirstOrDefault();
                    if(fanPct!=null){g.FanPercent=fanPct.Item2;g.FanPercentValid=true;}
                    g.VramUsedGb=hasGenericUsed?genericUsed:(hasDedicatedUsed?dedicatedUsed:0)+(hasSharedUsed?sharedUsed:0);
                    g.VramTotalGb=hasGenericTotal?genericTotal:(hasDedicatedTotal?dedicatedTotal:0)+(hasSharedTotal?sharedTotal:0);
                    records.Add(g);
                }
            }
            catch(Exception ex){error=ex.ToString();}

            List<Dictionary<string,object>> gpuJson=new List<Dictionary<string,object>>();
            foreach(GpuRecord g in records)
            {
                gpuJson.Add(new Dictionary<string,object>{
                    {"Available",g.Available},{"LoadValid",g.LoadValid},{"TemperatureValid",g.TemperatureValid},
                    {"CoreClockValid",g.CoreClockValid},{"MemoryClockValid",g.MemoryClockValid},
                    {"PowerValid",g.PowerValid},{"FanRpmValid",g.FanRpmValid},{"FanPercentValid",g.FanPercentValid},
                    {"Load",g.Load},{"Temperature",g.Temperature},{"VramUsedGb",g.VramUsedGb},{"VramTotalGb",g.VramTotalGb},
                    {"CoreClockMHz",g.CoreClockMHz},{"MemoryClockMHz",g.MemoryClockMHz},
                    {"PowerW",g.PowerW},{"FanRpm",g.FanRpm},{"FanPercent",g.FanPercent},
                    {"PcieGeneration",g.PcieGeneration},{"PcieWidth",g.PcieWidth},
                    {"Source",g.Source},{"HardwareName",g.HardwareName},{"HardwareId",g.HardwareId},{"AdapterIndex",g.AdapterIndex}
                });
            }

            return new Dictionary<string,object>{
                {"TimestampUtc",ts.ToString("o",CultureInfo.InvariantCulture)},
                {"Available",records.Count>0},
                {"Error",error},
                {"Is64BitProcess",Environment.Is64BitProcess},
                {"IsElevated",IsElevated()},
                {"Gpus",gpuJson.ToArray()},
                {"BrokerPid",Process.GetCurrentProcess().Id},
                {"BrokerMode","GPU"},
                {"BrokerVersion","1.1.2-rc2+r21"}
            };
        }

        private static Computer CreateComputer(string mode)
        {
            Computer c=new Computer();
            if(mode=="CPU")c.IsCpuEnabled=true;
            else if(mode=="GPU"){c.IsGpuEnabled=true;}
            else if(mode=="STORAGE")c.IsStorageEnabled=true;
            return c;
        }

        private static int RunPersistent(string mode,string output,int sleepMs)
        {
            Log("BROKER_RUN_START mode="+mode+" pid="+Process.GetCurrentProcess().Id);
            Computer computer=CreateComputer(mode);
            try
            {
                computer.Open();
                while(true)
                {
                    Stopwatch sw=Stopwatch.StartNew();
                    Dictionary<string,object> m=mode=="CPU"?ReadCpu(computer):ReadGpu(computer);
                    sw.Stop();
                    m["Sequence"]=Interlocked.Increment(ref SampleSequence);
                    m["ReadDurationMs"]=sw.ElapsedMilliseconds;
                    m["GeneratedBy"]="TBME_R21_ISOLATED_BROKER";
                    AtomicWrite(output,Json(m));
                    Thread.Sleep(sleepMs);
                }
            }
            finally
            {
                try{computer.Close();}catch{}
            }
        }

        private static int RunOnce(string mode,string output)
        {
            Log("BROKER_ONCE_START mode="+mode+" pid="+Process.GetCurrentProcess().Id);
            Computer computer=CreateComputer(mode);
            try
            {
                computer.Open();
                Stopwatch sw=Stopwatch.StartNew();
                Dictionary<string,object> m;
                if(mode=="CPU")m=ReadCpu(computer);
                else if(mode=="GPU")m=ReadGpu(computer);
                else m=ReadStorage(computer);
                sw.Stop();
                m["Sequence"]=Interlocked.Increment(ref SampleSequence);
                m["ReadDurationMs"]=sw.ElapsedMilliseconds;
                m["GeneratedBy"]="TBME_R21_ISOLATED_BROKER";
                AtomicWrite(output,Json(m));
            }
            finally
            {
                try{computer.Close();}catch{}
            }
            Log("BROKER_ONCE_PASS mode="+mode);
            return 0;
        }

        private static void TryWriteFatal(string output,string mode,Exception ex)
        {
            try
            {
                AtomicWrite(output,Json(new Dictionary<string,object>{
                    {"TimestampUtc",DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)},
                    {"Available",false},{"Error",ex.ToString()},
                    {"Is64BitProcess",Environment.Is64BitProcess},{"IsElevated",IsElevated()},
                    {"BrokerPid",Process.GetCurrentProcess().Id},{"BrokerMode",mode},{"BrokerVersion","1.1.2-rc2+r21"}
                }));
            }
            catch{}
        }

        private static int Main(string[] args)
        {
            if(args==null||args.Length<2)return 2;
            string mode=(args[0]??"").Trim().ToLowerInvariant();
            string output=args[1];
            Environment.CurrentDirectory=AppDomain.CurrentDomain.BaseDirectory;
            try
            {
                if(mode=="--run"||mode=="--run-cpu")return RunPersistent("CPU",output,1000);
                if(mode=="--run-gpu")return RunPersistent("GPU",output,2000);
                if(mode=="--once"||mode=="--once-cpu")return RunOnce("CPU",output);
                if(mode=="--once-gpu")return RunOnce("GPU",output);
                if(mode=="--once-storage")return RunOnce("STORAGE",output);
                return 3;
            }
            catch(Exception ex)
            {
                Log("BROKER_FATAL mode="+mode+" "+ex);
                TryWriteFatal(output,mode,ex);
                return 6;
            }
        }
    }
}
