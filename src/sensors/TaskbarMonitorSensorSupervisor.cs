using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;

[assembly: AssemblyTitle("Taskbar Monitor Enhanced Sensor Supervisor")]
[assembly: AssemblyDescription("Failure-contained sensor worker supervisor for Taskbar Monitor Enhanced")]
[assembly: AssemblyProduct("Taskbar Monitor Enhanced")]
[assembly: AssemblyCompany("Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyInformationalVersion("1.1.2-rc7+r21")]
[assembly: AssemblyVersion("1.1.2.0")]
[assembly: AssemblyFileVersion("1.1.2.0")]

internal static class TaskbarMonitorSensorSupervisor
{
    static class ChildJobContainment
    {
        const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE=0x00002000;
        const int JobObjectExtendedLimitInformation=9;
        static IntPtr Handle=IntPtr.Zero;
        public static bool Active;
        public static int LastError;

        [StructLayout(LayoutKind.Sequential)]
        struct JOBOBJECT_BASIC_LIMIT_INFORMATION
        {
            public long PerProcessUserTimeLimit;
            public long PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize;
            public UIntPtr MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass;
            public uint SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct IO_COUNTERS
        {
            public ulong ReadOperationCount;
            public ulong WriteOperationCount;
            public ulong OtherOperationCount;
            public ulong ReadTransferCount;
            public ulong WriteTransferCount;
            public ulong OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
        {
            public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
            public IO_COUNTERS IoInfo;
            public UIntPtr ProcessMemoryLimit;
            public UIntPtr JobMemoryLimit;
            public UIntPtr PeakProcessMemoryUsed;
            public UIntPtr PeakJobMemoryUsed;
        }

        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
        static extern IntPtr CreateJobObject(IntPtr lpJobAttributes,string lpName);
        [DllImport("kernel32.dll",SetLastError=true)]
        static extern bool SetInformationJobObject(IntPtr hJob,int infoClass,ref JOBOBJECT_EXTENDED_LIMIT_INFORMATION info,uint length);
        [DllImport("kernel32.dll",SetLastError=true)]
        static extern bool AssignProcessToJobObject(IntPtr hJob,IntPtr hProcess);
        [DllImport("kernel32.dll",SetLastError=true)]
        static extern bool CloseHandle(IntPtr hObject);

        public static bool Initialize()
        {
            if(Handle!=IntPtr.Zero)return Active;
            Handle=CreateJobObject(IntPtr.Zero,null);
            if(Handle==IntPtr.Zero){LastError=Marshal.GetLastWin32Error();return false;}
            JOBOBJECT_EXTENDED_LIMIT_INFORMATION info=new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
            info.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            if(!SetInformationJobObject(Handle,JobObjectExtendedLimitInformation,ref info,(uint)Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION))))
            {
                LastError=Marshal.GetLastWin32Error();
                CloseHandle(Handle);Handle=IntPtr.Zero;return false;
            }
            Active=true;LastError=0;return true;
        }

        public static bool Attach(Process process)
        {
            if(!Active||Handle==IntPtr.Zero||process==null)return false;
            try
            {
                if(process.HasExited)return false;
                bool ok=AssignProcessToJobObject(Handle,process.Handle);
                if(!ok)LastError=Marshal.GetLastWin32Error();
                return ok;
            }
            catch{LastError=Marshal.GetLastWin32Error();return false;}
        }

        public static void Dispose()
        {
            IntPtr h=Handle;Handle=IntPtr.Zero;Active=false;
            if(h!=IntPtr.Zero)try{CloseHandle(h);}catch{}
        }
    }

    const int FreshnessLimitSeconds=15;
    const int StartupGraceSeconds=30;
    const int StorageIntervalSeconds=60;
    const int StorageTimeoutSeconds=12;
    const long MaxSensorLogBytes=4L*1024L*1024L;
    const int SensorLogBackups=3;

    sealed class Worker
    {
        public string Name="";
        public string Mode="";
        public string Output="";
        public Process Process;
        public int RestartCount;
        public int ConsecutiveFailures;
        public DateTime StartedUtc=DateTime.MinValue;
        public DateTime NextStartUtc=DateTime.MinValue;
        public DateTime HealthySinceUtc=DateTime.MinValue;
        public DateTime LastOutputUtc=DateTime.MinValue;
        public bool TransportHealthy;
        public bool DataAvailable;
        public string OutputError="";
        public string LastReason="";
        public DateTime LastFailureUtc=DateTime.MinValue;
        public DateTime LastRecoveryUtc=DateTime.MinValue;
        public string LastFailureReason="";
        public bool JobContained;
    }

    static string LogPath="";
    static string BrokerLogPath="";
    static string StatePath="";
    static string BrokerPath="";
    static DateTime SupervisorStartedUtc=DateTime.UtcNow;
    static string CpuOutput="";
    static string GpuOutput="";
    static string StorageOutput="";
    static readonly Worker Cpu=new Worker{Name="CPU",Mode="--run-cpu"};
    static readonly Worker Gpu=new Worker{Name="GPU",Mode="--run-gpu"};
    static Process StorageProcess;
    static DateTime StorageStartedUtc=DateTime.MinValue;
    static DateTime StorageNextUtc=DateTime.MinValue;
    static int StorageAttemptCount;
    static int StorageConsecutiveFailures;
    static string StorageLastReason="NOT_STARTED";
    static DateTime StorageLastOutputUtc=DateTime.MinValue;
    static bool StorageTransportHealthy;
    static bool StorageDataAvailable;
    static string StorageOutputError="";
    static DateTime StorageLastFailureUtc=DateTime.MinValue;
    static DateTime StorageLastRecoveryUtc=DateTime.MinValue;
    static string StorageLastFailureReason="";
    static bool StorageJobContained;

    static void Log(string message)
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

    static void RotateLogFile(string path)
    {
        try
        {
            if(String.IsNullOrWhiteSpace(path)||!File.Exists(path)||new FileInfo(path).Length<MaxSensorLogBytes)return;
            for(int i=SensorLogBackups;i>=1;i--)
            {
                string dst=path+"."+i.ToString(CultureInfo.InvariantCulture);
                if(i==SensorLogBackups)
                {
                    try{if(File.Exists(dst))File.Delete(dst);}catch{}
                }
                string src=i==1?path:path+"."+(i-1).ToString(CultureInfo.InvariantCulture);
                if(File.Exists(src))
                {
                    try{File.Move(src,dst);}catch{}
                }
            }
        }
        catch{}
    }

    static void MaintainLogs()
    {
        RotateLogFile(LogPath);
        RotateLogFile(BrokerLogPath);
    }

    static string JsonEscape(string s)
    {
        return (s??"").Replace("\\","\\\\").Replace("\"","\\\"");
    }

    static int Pid(Worker w)
    {
        try{return w.Process!=null&&!w.Process.HasExited?w.Process.Id:0;}catch{return 0;}
    }

    static int StoragePid()
    {
        try{return StorageProcess!=null&&!StorageProcess.HasExited?StorageProcess.Id:0;}catch{return 0;}
    }

    static void WriteState(string reason)
    {
        try
        {
            string json="{"+
                "\"TimestampUtc\":\""+DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)+"\","+
                "\"SupervisorPid\":"+Process.GetCurrentProcess().Id+","+
                "\"SupervisorStartedUtc\":\""+SupervisorStartedUtc.ToString("o",CultureInfo.InvariantCulture)+"\","+
                "\"SupervisorUptimeSeconds\":"+Math.Max(0,(DateTime.UtcNow-SupervisorStartedUtc).TotalSeconds).ToString("0.0",CultureInfo.InvariantCulture)+","+
                "\"Reason\":\""+JsonEscape(reason)+"\","+
                "\"ChildJobKillOnClose\":"+(ChildJobContainment.Active?"true":"false")+","+
                "\"ChildJobLastError\":"+ChildJobContainment.LastError+","+
                "\"CpuJobContained\":"+(Cpu.JobContained?"true":"false")+","+
                "\"GpuJobContained\":"+(Gpu.JobContained?"true":"false")+","+
                "\"StorageJobContained\":"+(StorageJobContained?"true":"false")+","+
                "\"CpuWorkerPid\":"+Pid(Cpu)+","+
                "\"CpuWorkerStartedUtc\":\""+(Cpu.StartedUtc==DateTime.MinValue?"":Cpu.StartedUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"CpuWorkerAgeSeconds\":"+(Cpu.StartedUtc==DateTime.MinValue?"0":Math.Max(0,(DateTime.UtcNow-Cpu.StartedUtc).TotalSeconds).ToString("0.0",CultureInfo.InvariantCulture))+","+
                "\"CpuRestartCount\":"+Cpu.RestartCount+","+
                "\"CpuConsecutiveFailures\":"+Cpu.ConsecutiveFailures+","+
                "\"CpuLastReason\":\""+JsonEscape(Cpu.LastReason)+"\","+
                "\"CpuTransportHealthy\":"+(Cpu.TransportHealthy?"true":"false")+","+
                "\"CpuDataAvailable\":"+(Cpu.DataAvailable?"true":"false")+","+
                "\"CpuLastOutputUtc\":\""+(Cpu.LastOutputUtc==DateTime.MinValue?"":Cpu.LastOutputUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"CpuOutputError\":\""+JsonEscape(Cpu.OutputError)+"\","+
                "\"CpuLastFailureUtc\":\""+(Cpu.LastFailureUtc==DateTime.MinValue?"":Cpu.LastFailureUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"CpuLastFailureReason\":\""+JsonEscape(Cpu.LastFailureReason)+"\","+
                "\"CpuLastRecoveryUtc\":\""+(Cpu.LastRecoveryUtc==DateTime.MinValue?"":Cpu.LastRecoveryUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"GpuWorkerPid\":"+Pid(Gpu)+","+
                "\"GpuWorkerStartedUtc\":\""+(Gpu.StartedUtc==DateTime.MinValue?"":Gpu.StartedUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"GpuWorkerAgeSeconds\":"+(Gpu.StartedUtc==DateTime.MinValue?"0":Math.Max(0,(DateTime.UtcNow-Gpu.StartedUtc).TotalSeconds).ToString("0.0",CultureInfo.InvariantCulture))+","+
                "\"GpuRestartCount\":"+Gpu.RestartCount+","+
                "\"GpuConsecutiveFailures\":"+Gpu.ConsecutiveFailures+","+
                "\"GpuLastReason\":\""+JsonEscape(Gpu.LastReason)+"\","+
                "\"GpuTransportHealthy\":"+(Gpu.TransportHealthy?"true":"false")+","+
                "\"GpuDataAvailable\":"+(Gpu.DataAvailable?"true":"false")+","+
                "\"GpuLastOutputUtc\":\""+(Gpu.LastOutputUtc==DateTime.MinValue?"":Gpu.LastOutputUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"GpuOutputError\":\""+JsonEscape(Gpu.OutputError)+"\","+
                "\"GpuLastFailureUtc\":\""+(Gpu.LastFailureUtc==DateTime.MinValue?"":Gpu.LastFailureUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"GpuLastFailureReason\":\""+JsonEscape(Gpu.LastFailureReason)+"\","+
                "\"GpuLastRecoveryUtc\":\""+(Gpu.LastRecoveryUtc==DateTime.MinValue?"":Gpu.LastRecoveryUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"StorageWorkerPid\":"+StoragePid()+","+
                "\"StorageWorkerStartedUtc\":\""+(StorageStartedUtc==DateTime.MinValue?"":StorageStartedUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"StorageWorkerAgeSeconds\":"+(StorageProcess==null||StorageStartedUtc==DateTime.MinValue?"0":Math.Max(0,(DateTime.UtcNow-StorageStartedUtc).TotalSeconds).ToString("0.0",CultureInfo.InvariantCulture))+","+
                "\"StorageAttemptCount\":"+StorageAttemptCount+","+
                "\"StorageConsecutiveFailures\":"+StorageConsecutiveFailures+","+
                "\"StorageLastReason\":\""+JsonEscape(StorageLastReason)+"\","+
                "\"StorageTransportHealthy\":"+(StorageTransportHealthy?"true":"false")+","+
                "\"StorageDataAvailable\":"+(StorageDataAvailable?"true":"false")+","+
                "\"StorageLastOutputUtc\":\""+(StorageLastOutputUtc==DateTime.MinValue?"":StorageLastOutputUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"StorageOutputError\":\""+JsonEscape(StorageOutputError)+"\","+
                "\"StorageLastFailureUtc\":\""+(StorageLastFailureUtc==DateTime.MinValue?"":StorageLastFailureUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"StorageLastFailureReason\":\""+JsonEscape(StorageLastFailureReason)+"\","+
                "\"StorageLastRecoveryUtc\":\""+(StorageLastRecoveryUtc==DateTime.MinValue?"":StorageLastRecoveryUtc.ToString("o",CultureInfo.InvariantCulture))+"\","+
                "\"BrokerVersion\":\"1.1.2-rc7+r21\""+
                "}";
            string tmp=StatePath+".tmp";
            File.WriteAllText(tmp,json);
            if(File.Exists(StatePath))File.Replace(tmp,StatePath,null,true);
            else File.Move(tmp,StatePath);
        }
        catch{}
    }

    static bool ParseArgs(string[] args)
    {
        string legacyOutput="";
        for(int i=0;i<args.Length-1;i++)
        {
            if(String.Equals(args[i],"--broker",StringComparison.OrdinalIgnoreCase))BrokerPath=args[++i];
            else if(String.Equals(args[i],"--output",StringComparison.OrdinalIgnoreCase))legacyOutput=args[++i];
        }
        if(String.IsNullOrWhiteSpace(BrokerPath)||String.IsNullOrWhiteSpace(legacyOutput))return false;
        string dir=Path.GetDirectoryName(legacyOutput);
        if(String.IsNullOrWhiteSpace(dir))return false;
        CpuOutput=legacyOutput;
        GpuOutput=Path.Combine(dir,"gpu_temp_broker.json");
        StorageOutput=Path.Combine(dir,"storage_temp_broker.json");
        Cpu.Output=CpuOutput;
        Gpu.Output=GpuOutput;
        return true;
    }

    static bool StopExistingBrokers()
    {
        bool clear=true;
        try
        {
            foreach(Process p in Process.GetProcessesByName("TaskbarMonitorSensorBroker"))
            {
                bool exited=false;
                try
                {
                    if(p.HasExited)exited=true;
                    else
                    {
                        p.Kill();
                        exited=p.WaitForExit(1500);
                        if(!exited)try{exited=p.HasExited;}catch{}
                    }
                }
                catch{}
                if(!exited)
                {
                    clear=false;
                    Log("LEGACY_BROKER_TERMINATION_PENDING pid="+p.Id);
                }
                try{p.Dispose();}catch{}
            }
        }
        catch(Exception ex){clear=false;Log("LEGACY_BROKER_DRAIN_ERROR "+ex.Message);}
        return clear;
    }

    static bool LegacyBrokerProcessesRemain()
    {
        try
        {
            Process[] ps=Process.GetProcessesByName("TaskbarMonitorSensorBroker");
            bool any=ps.Length>0;
            foreach(Process p in ps)try{p.Dispose();}catch{}
            return any;
        }
        catch{return true;}
    }

    static int BackoffSeconds(int failures)
    {
        if(failures<=1)return 5;
        if(failures==2)return 15;
        if(failures==3)return 30;
        if(failures<=5)return 60;
        if(failures<=8)return 120;
        return 300;
    }

    static bool TryTerminateWorker(Worker w)
    {
        if(w.Process==null)return true;
        bool exited=false;
        try
        {
            if(w.Process.HasExited)exited=true;
            else
            {
                w.Process.Kill();
                exited=w.Process.WaitForExit(1500);
                if(!exited)try{exited=w.Process.HasExited;}catch{}
            }
        }
        catch{}
        if(exited)
        {
            try{w.Process.Dispose();}catch{}
            w.Process=null;
            return true;
        }
        return false;
    }

    static void ScheduleFailure(Worker w,string reason)
    {
        w.TransportHealthy=false;w.DataAvailable=false;
        w.ConsecutiveFailures++;
        w.LastFailureUtc=DateTime.UtcNow;
        w.LastFailureReason=reason;
        if(!TryTerminateWorker(w))
        {
            w.NextStartUtc=DateTime.MaxValue;
            w.LastReason=reason+"_TERMINATION_PENDING";
            Log("WORKER_TERMINATION_PENDING name="+w.Name+" reason="+reason+
                " failures="+w.ConsecutiveFailures+" pid="+Pid(w));
            return;
        }
        int delay=BackoffSeconds(w.ConsecutiveFailures);
        w.NextStartUtc=DateTime.UtcNow.AddSeconds(delay);
        w.LastReason=reason+"_BACKOFF_"+delay+"S";
        Log("WORKER_FAILURE name="+w.Name+" reason="+reason+
            " failures="+w.ConsecutiveFailures+" nextStartSec="+delay);
    }

    static void StartWorker(Worker w,string reason)
    {
        ProcessStartInfo psi=new ProcessStartInfo();
        psi.FileName=BrokerPath;
        psi.Arguments=w.Mode+" \""+w.Output+"\"";
        psi.UseShellExecute=false;
        psi.CreateNoWindow=true;
        Process p=Process.Start(psi);
        if(p==null)throw new InvalidOperationException(w.Name+"_BROKER_START_RETURNED_NULL");
        w.Process=p;
        w.JobContained=ChildJobContainment.Attach(p);
        if(!w.JobContained)Log("WORKER_JOB_ATTACH_FAIL name="+w.Name+" pid="+p.Id+" win32="+ChildJobContainment.LastError);
        w.StartedUtc=DateTime.UtcNow;
        w.HealthySinceUtc=DateTime.MinValue;
        w.TransportHealthy=false;w.DataAvailable=false;w.OutputError="";w.LastOutputUtc=DateTime.MinValue;
        w.RestartCount++;
        w.LastReason=reason;
        Log("WORKER_START name="+w.Name+" reason="+reason+" pid="+p.Id+
            " restartCount="+w.RestartCount+" startupGraceSec="+StartupGraceSeconds);
    }

    static DateTime OutputWriteUtc(string path)
    {
        try{return File.Exists(path)?File.GetLastWriteTimeUtc(path):DateTime.MinValue;}
        catch{return DateTime.MinValue;}
    }

    static string ReadSharedText(string path)
    {
        try
        {
            using(FileStream fs=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
            using(StreamReader sr=new StreamReader(fs))
                return sr.ReadToEnd();
        }
        catch{return "";}
    }

    static bool OutputDataAvailable(string path,out string error)
    {
        error="";
        string json=ReadSharedText(path);
        if(String.IsNullOrWhiteSpace(json)){error="OUTPUT_EMPTY";return false;}
        int ai=json.IndexOf("\"Available\"",StringComparison.OrdinalIgnoreCase);
        if(ai<0){error="AVAILABLE_FIELD_MISSING";return false;}
        int colon=json.IndexOf(':',ai);
        if(colon<0){error="AVAILABLE_FIELD_INVALID";return false;}
        string tail=json.Substring(colon+1).TrimStart();
        bool available=tail.StartsWith("true",StringComparison.OrdinalIgnoreCase);
        if(!available)
        {
            int ei=json.IndexOf("\"Error\"",StringComparison.OrdinalIgnoreCase);
            if(ei>=0)
            {
                int ec=json.IndexOf(':',ei);
                if(ec>=0)
                {
                    int q1=json.IndexOf('"',ec+1);
                    int q2=q1>=0?json.IndexOf('"',q1+1):-1;
                    if(q1>=0&&q2>q1)error=json.Substring(q1+1,q2-q1-1);
                }
            }
            if(String.IsNullOrWhiteSpace(error))error="DATA_UNAVAILABLE";
        }
        return available;
    }

    static void MarkFreshOutput(Worker w,DateTime writeUtc,DateTime now)
    {
        string dataError="";
        bool data=OutputDataAvailable(w.Output,out dataError);
        w.TransportHealthy=true;
        w.DataAvailable=data;
        w.OutputError=data?"":dataError;
        w.LastOutputUtc=writeUtc;
        if(w.HealthySinceUtc==DateTime.MinValue)w.HealthySinceUtc=now;
        if((now-w.HealthySinceUtc).TotalSeconds>=60 && w.ConsecutiveFailures>0)
        {
            Log("WORKER_RECOVERY_STABLE name="+w.Name+" priorFailures="+w.ConsecutiveFailures);
            w.LastRecoveryUtc=now;
            w.ConsecutiveFailures=0;
        }
        w.LastReason=data?"HEALTHY_DATA":"HEALTHY_NO_DATA";
    }

    static void CheckWorker(Worker w)
    {
        DateTime now=DateTime.UtcNow;
        if(w.Process!=null && w.LastReason.EndsWith("_TERMINATION_PENDING",StringComparison.Ordinal))
        {
            bool pendingExited=false;try{pendingExited=w.Process.HasExited;}catch{pendingExited=true;}
            if(!pendingExited)return;
            try{w.Process.Dispose();}catch{}
            w.Process=null;
            int terminatedDelay=BackoffSeconds(w.ConsecutiveFailures);
            w.NextStartUtc=now.AddSeconds(terminatedDelay);
            w.LastReason="TERMINATED_BACKOFF_"+terminatedDelay+"S";
            Log("WORKER_TERMINATED_AFTER_PENDING name="+w.Name+" nextStartSec="+terminatedDelay);
            return;
        }
        if(w.Process==null)
        {
            if(now<w.NextStartUtc)return;
            try{StartWorker(w,w.RestartCount==0?"SUPERVISOR_START":"RETRY");}
            catch(Exception ex)
            {
                w.ConsecutiveFailures++;
                w.LastFailureUtc=DateTime.UtcNow;
                w.LastFailureReason="START_EXCEPTION";
                int delay=BackoffSeconds(w.ConsecutiveFailures);
                w.NextStartUtc=now.AddSeconds(delay);
                w.LastReason="START_EXCEPTION_BACKOFF_"+delay+"S";
                Log("WORKER_START_EXCEPTION name="+w.Name+" "+ex);
            }
            return;
        }

        bool exited=false;
        int exitCode=-999;
        try
        {
            exited=w.Process.HasExited;
            if(exited)exitCode=w.Process.ExitCode;
        }
        catch{exited=true;}
        if(exited)
        {
            Log("WORKER_EXIT_DETECTED name="+w.Name+" exitCode="+exitCode);
            ScheduleFailure(w,"WORKER_EXIT_"+exitCode);
            return;
        }

        double workerAge=(now-w.StartedUtc).TotalSeconds;
        DateTime writeUtc=OutputWriteUtc(w.Output);
        bool current=writeUtc!=DateTime.MinValue&&writeUtc>=w.StartedUtc.AddSeconds(-1);
        double age=writeUtc==DateTime.MinValue?Double.MaxValue:(now-writeUtc).TotalSeconds;

        if(current && age<=FreshnessLimitSeconds)
        {
            MarkFreshOutput(w,writeUtc,now);
            return;
        }

        if(!current && w.LastOutputUtc!=DateTime.MinValue)
        {
            double lastGoodAge=(now-w.LastOutputUtc).TotalSeconds;
            if(lastGoodAge<=FreshnessLimitSeconds)
            {
                w.LastReason="OUTPUT_OBSERVATION_GAP_LAST_GOOD_"+lastGoodAge.ToString("0.0",CultureInfo.InvariantCulture)+"S";
                return;
            }
        }

        w.TransportHealthy=false;
        w.DataAvailable=false;
        if(workerAge<=StartupGraceSeconds && w.LastOutputUtc==DateTime.MinValue)
        {
            w.LastReason="STARTUP_GRACE";
            return;
        }

        if(!current)
        {
            if(w.LastOutputUtc!=DateTime.MinValue)
            {
                double lastGoodAge=(now-w.LastOutputUtc).TotalSeconds;
                ScheduleFailure(w,"OUTPUT_OBSERVATION_GAP_"+lastGoodAge.ToString("0.0",CultureInfo.InvariantCulture)+"S");
            }
            else ScheduleFailure(w,"NO_CURRENT_OUTPUT_AFTER_GRACE");
            return;
        }

        ScheduleFailure(w,"STALE_OUTPUT_"+age.ToString("0.0",CultureInfo.InvariantCulture)+"S");
    }

    static bool TryTerminateStorage()
    {
        if(StorageProcess==null)return true;
        bool exited=false;
        try
        {
            if(StorageProcess.HasExited)exited=true;
            else
            {
                StorageProcess.Kill();
                exited=StorageProcess.WaitForExit(1500);
                if(!exited)try{exited=StorageProcess.HasExited;}catch{}
            }
        }
        catch{}
        if(exited)
        {
            try{StorageProcess.Dispose();}catch{}
            StorageProcess=null;
            return true;
        }
        return false;
    }

    static int StorageBackoffSeconds(int failures)
    {
        if(failures<=1)return StorageIntervalSeconds;
        if(failures<=3)return 180;
        return 300;
    }

    static void StorageFailure(string reason)
    {
        StorageTransportHealthy=false;StorageDataAvailable=false;
        StorageConsecutiveFailures++;
        StorageLastFailureUtc=DateTime.UtcNow;
        StorageLastFailureReason=reason;
        if(!TryTerminateStorage())
        {
            StorageNextUtc=DateTime.MaxValue;
            StorageLastReason=reason+"_TERMINATION_PENDING";
            Log("STORAGE_TERMINATION_PENDING reason="+reason+" failures="+StorageConsecutiveFailures+
                " pid="+StoragePid());
            return;
        }
        int delay=StorageBackoffSeconds(StorageConsecutiveFailures);
        StorageNextUtc=DateTime.UtcNow.AddSeconds(delay);
        StorageLastReason=reason+"_BACKOFF_"+delay+"S";
        Log("STORAGE_FAILURE reason="+reason+" failures="+StorageConsecutiveFailures+" nextSec="+delay);
    }

    static void StartStorage()
    {
        ProcessStartInfo psi=new ProcessStartInfo();
        psi.FileName=BrokerPath;
        psi.Arguments="--once-storage \""+StorageOutput+"\"";
        psi.UseShellExecute=false;
        psi.CreateNoWindow=true;
        Process p=Process.Start(psi);
        if(p==null)throw new InvalidOperationException("STORAGE_BROKER_START_RETURNED_NULL");
        StorageProcess=p;
        StorageJobContained=ChildJobContainment.Attach(p);
        if(!StorageJobContained)Log("STORAGE_JOB_ATTACH_FAIL pid="+p.Id+" win32="+ChildJobContainment.LastError);
        StorageStartedUtc=DateTime.UtcNow;
        StorageAttemptCount++;
        StorageLastReason="RUNNING";
        Log("STORAGE_START pid="+p.Id+" attempt="+StorageAttemptCount+" timeoutSec="+StorageTimeoutSeconds);
    }

    static void CheckStorage()
    {
        DateTime now=DateTime.UtcNow;
        if(StorageProcess!=null && StorageLastReason.EndsWith("_TERMINATION_PENDING",StringComparison.Ordinal))
        {
            bool pendingExited=false;try{pendingExited=StorageProcess.HasExited;}catch{pendingExited=true;}
            if(!pendingExited)return;
            try{StorageProcess.Dispose();}catch{}
            StorageProcess=null;
            int pendingDelay=StorageBackoffSeconds(StorageConsecutiveFailures);
            StorageNextUtc=now.AddSeconds(pendingDelay);
            StorageLastReason="TERMINATED_BACKOFF_"+pendingDelay+"S";
            Log("STORAGE_TERMINATED_AFTER_PENDING nextStartSec="+pendingDelay);
            return;
        }
        if(StorageProcess==null)
        {
            if(now<StorageNextUtc)return;
            try{StartStorage();}
            catch(Exception ex)
            {
                StorageConsecutiveFailures++;
                StorageLastFailureUtc=DateTime.UtcNow;
                StorageLastFailureReason="START_EXCEPTION";
                int delay=StorageBackoffSeconds(StorageConsecutiveFailures);
                StorageNextUtc=now.AddSeconds(delay);
                StorageLastReason="START_EXCEPTION_BACKOFF_"+delay+"S";
                Log("STORAGE_START_EXCEPTION "+ex);
            }
            return;
        }

        bool exited=false;
        int exitCode=-999;
        try
        {
            exited=StorageProcess.HasExited;
            if(exited)exitCode=StorageProcess.ExitCode;
        }
        catch{exited=true;}

        if(exited)
        {
            DateTime writeUtc=OutputWriteUtc(StorageOutput);
            bool fresh=writeUtc!=DateTime.MinValue && writeUtc>=StorageStartedUtc.AddSeconds(-1);
            try{StorageProcess.Dispose();}catch{}
            StorageProcess=null;
            if(exitCode==0&&fresh)
            {
                string storageError="";
                StorageDataAvailable=OutputDataAvailable(StorageOutput,out storageError);
                StorageOutputError=StorageDataAvailable?"":storageError;
                StorageTransportHealthy=true;
                StorageLastOutputUtc=writeUtc;
                if(StorageConsecutiveFailures>0)
                {
                    StorageLastRecoveryUtc=now;
                    Log("STORAGE_RECOVERY priorFailures="+StorageConsecutiveFailures);
                }
                StorageConsecutiveFailures=0;
                StorageLastReason=StorageDataAvailable?"HEALTHY_DATA":"HEALTHY_NO_DATA";
                StorageNextUtc=now.AddSeconds(StorageIntervalSeconds);
                Log("STORAGE_PASS dataAvailable="+StorageDataAvailable+" nextSec="+StorageIntervalSeconds);
            }
            else StorageFailure("EXIT_"+exitCode+"_FRESH_"+fresh);
            return;
        }

        if((now-StorageStartedUtc).TotalSeconds>StorageTimeoutSeconds)
        {
            StorageFailure("TIMEOUT");
        }
    }

    static void RecycleWorkerAfterResume(Worker w,int staggerSeconds)
    {
        if(w.Process==null){w.NextStartUtc=DateTime.UtcNow.AddSeconds(staggerSeconds);return;}
        if(TryTerminateWorker(w))
        {
            w.TransportHealthy=false;w.DataAvailable=false;w.HealthySinceUtc=DateTime.MinValue;
            w.NextStartUtc=DateTime.UtcNow.AddSeconds(staggerSeconds);
            w.LastReason="POWER_RESUME_RECYCLE_BACKOFF_"+staggerSeconds+"S";
            Log("WORKER_POWER_RESUME_RECYCLE name="+w.Name+" nextStartSec="+staggerSeconds);
        }
        else
        {
            w.NextStartUtc=DateTime.MaxValue;
            w.LastReason="POWER_RESUME_RECYCLE_TERMINATION_PENDING";
            Log("WORKER_POWER_RESUME_TERMINATION_PENDING name="+w.Name+" pid="+Pid(w));
        }
    }

    static void RecycleStorageAfterResume(int staggerSeconds)
    {
        if(StorageProcess==null){StorageNextUtc=DateTime.UtcNow.AddSeconds(staggerSeconds);return;}
        if(TryTerminateStorage())
        {
            StorageTransportHealthy=false;StorageDataAvailable=false;
            StorageNextUtc=DateTime.UtcNow.AddSeconds(staggerSeconds);
            StorageLastReason="POWER_RESUME_RECYCLE_BACKOFF_"+staggerSeconds+"S";
            Log("STORAGE_POWER_RESUME_RECYCLE nextStartSec="+staggerSeconds);
        }
        else
        {
            StorageNextUtc=DateTime.MaxValue;
            StorageLastReason="POWER_RESUME_RECYCLE_TERMINATION_PENDING";
            Log("STORAGE_POWER_RESUME_TERMINATION_PENDING pid="+StoragePid());
        }
    }

    static int Main(string[] args)
    {
        try
        {
            if(!ParseArgs(args))return 2;
            if(!File.Exists(BrokerPath))return 3;

            string root=AppDomain.CurrentDomain.BaseDirectory;
            LogPath=Path.Combine(root,"sensor_supervisor.log");
            BrokerLogPath=Path.Combine(root,"sensor_broker.log");
            SupervisorStartedUtc=DateTime.UtcNow;
            MaintainLogs();
            string outputRoot=Path.GetDirectoryName(CpuOutput);
            StatePath=Path.Combine(outputRoot,"sensor_supervisor_state.json");

            bool created=false;
            using(Mutex singleton=new Mutex(true,"Local\\TaskbarMonitorEnhancedSensorSupervisor",out created))
            {
                if(!created)
                {
                    Log("SUPERVISOR_SINGLETON_ALREADY_RUNNING");
                    return 0;
                }

                bool jobReady=ChildJobContainment.Initialize();
                Log("CHILD_JOB_KILL_ON_CLOSE active="+jobReady+" win32="+ChildJobContainment.LastError);
                if(!jobReady)return 4;

                Log("SUPERVISOR_START R21_PRODUCTION_HARDENING pid="+Process.GetCurrentProcess().Id+
                    " broker="+BrokerPath+
                    " cpuOutput="+CpuOutput+
                    " gpuOutput="+GpuOutput+
                    " storageOutput="+StorageOutput);

                bool legacyClear=StopExistingBrokers();
                DateTime initialStart=DateTime.UtcNow;
                Cpu.NextStartUtc=legacyClear?initialStart:DateTime.MaxValue;
                Gpu.NextStartUtc=legacyClear?initialStart.AddSeconds(3):DateTime.MaxValue;
                StorageNextUtc=legacyClear?initialStart.AddSeconds(6):DateTime.MaxValue;
                if(!legacyClear)Log("LEGACY_BROKER_DRAIN_PENDING no R21 workers will start until old broker exits");

                int ticks=0;
                DateTime lastLoopUtc=DateTime.UtcNow;
                while(true)
                {
                    Thread.Sleep(1000);
                    DateTime loopNow=DateTime.UtcNow;
                    double loopGap=(loopNow-lastLoopUtc).TotalSeconds;
                    lastLoopUtc=loopNow;
                    ticks++;
                    if(ticks%60==0)MaintainLogs();

                    if(loopGap>15)
                    {
                        Log("POWER_RESUME_OR_LONG_GAP_DETECTED seconds="+loopGap.ToString("0.0",CultureInfo.InvariantCulture));
                        RecycleWorkerAfterResume(Cpu,0);
                        RecycleWorkerAfterResume(Gpu,3);
                        RecycleStorageAfterResume(6);
                        WriteState("POWER_RESUME_RECYCLE");
                    }

                    if(!legacyClear)
                    {
                        if(!LegacyBrokerProcessesRemain())
                        {
                            legacyClear=true;
                            DateTime ready=DateTime.UtcNow;
                            Cpu.NextStartUtc=ready;
                            Gpu.NextStartUtc=ready.AddSeconds(3);
                            StorageNextUtc=ready.AddSeconds(6);
                            Log("LEGACY_BROKER_DRAIN_PASS starting staggered isolated R21 workers");
                        }
                        else
                        {
                            if(ticks%5==0)WriteState("LEGACY_DRAIN_PENDING");
                            continue;
                        }
                    }
                    CheckWorker(Cpu);
                    CheckWorker(Gpu);
                    CheckStorage();
                    if(ticks%5==0)WriteState("HEALTH_LOOP");
                }
            }
        }
        catch(Exception ex)
        {
            try{Log("SUPERVISOR_FATAL "+ex);}catch{}
            return 100;
        }
        finally
        {
            try{TryTerminateWorker(Cpu);}catch{}
            try{TryTerminateWorker(Gpu);}catch{}
            try{TryTerminateStorage();}catch{}
            try{ChildJobContainment.Dispose();}catch{}
        }
    }
}
