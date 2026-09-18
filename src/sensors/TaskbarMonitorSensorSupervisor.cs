using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Threading;

[assembly: AssemblyTitle("Taskbar Monitor Enhanced Sensor Supervisor")]
[assembly: AssemblyDescription("Failure-contained sensor worker supervisor for Taskbar Monitor Enhanced")]
[assembly: AssemblyProduct("Taskbar Monitor Enhanced")]
[assembly: AssemblyCompany("Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyInformationalVersion("1.1.2-rc1+r20")]
[assembly: AssemblyVersion("1.1.2.0")]
[assembly: AssemblyFileVersion("1.1.2.0")]

internal static class TaskbarMonitorSensorSupervisor
{
    const int FreshnessLimitSeconds=15;
    const int StartupGraceSeconds=30;
    const int StorageIntervalSeconds=60;
    const int StorageTimeoutSeconds=12;

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
        public string LastReason="";
    }

    static string LogPath="";
    static string StatePath="";
    static string BrokerPath="";
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
                "\"Reason\":\""+JsonEscape(reason)+"\","+
                "\"CpuWorkerPid\":"+Pid(Cpu)+","+
                "\"CpuRestartCount\":"+Cpu.RestartCount+","+
                "\"CpuConsecutiveFailures\":"+Cpu.ConsecutiveFailures+","+
                "\"CpuLastReason\":\""+JsonEscape(Cpu.LastReason)+"\","+
                "\"GpuWorkerPid\":"+Pid(Gpu)+","+
                "\"GpuRestartCount\":"+Gpu.RestartCount+","+
                "\"GpuConsecutiveFailures\":"+Gpu.ConsecutiveFailures+","+
                "\"GpuLastReason\":\""+JsonEscape(Gpu.LastReason)+"\","+
                "\"StorageWorkerPid\":"+StoragePid()+","+
                "\"StorageAttemptCount\":"+StorageAttemptCount+","+
                "\"StorageConsecutiveFailures\":"+StorageConsecutiveFailures+","+
                "\"StorageLastReason\":\""+JsonEscape(StorageLastReason)+"\","+
                "\"BrokerVersion\":\"1.1.2-rc1+r20\""+
                "}";
            File.WriteAllText(StatePath,json);
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
        if(failures<=1)return 2;
        if(failures<=3)return 5;
        if(failures<=6)return 15;
        if(failures<=10)return 60;
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
        w.ConsecutiveFailures++;
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
        w.StartedUtc=DateTime.UtcNow;
        w.HealthySinceUtc=DateTime.MinValue;
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

        if(workerAge<=StartupGraceSeconds)
        {
            if(((int)workerAge)%5==0)
                w.LastReason="STARTUP_GRACE";
            return;
        }

        if(!current)
        {
            ScheduleFailure(w,"NO_CURRENT_OUTPUT_AFTER_GRACE");
            return;
        }

        if(age>FreshnessLimitSeconds)
        {
            ScheduleFailure(w,"STALE_OUTPUT_"+age.ToString("0.0",CultureInfo.InvariantCulture)+"S");
            return;
        }

        if(w.HealthySinceUtc==DateTime.MinValue)w.HealthySinceUtc=now;
        if((now-w.HealthySinceUtc).TotalSeconds>=60 && w.ConsecutiveFailures>0)
        {
            Log("WORKER_RECOVERY_STABLE name="+w.Name+" priorFailures="+w.ConsecutiveFailures);
            w.ConsecutiveFailures=0;
        }
        w.LastReason="HEALTHY";
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
        StorageConsecutiveFailures++;
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
                StorageConsecutiveFailures=0;
                StorageLastReason="HEALTHY";
                StorageNextUtc=now.AddSeconds(StorageIntervalSeconds);
                Log("STORAGE_PASS nextSec="+StorageIntervalSeconds);
            }
            else StorageFailure("EXIT_"+exitCode+"_FRESH_"+fresh);
            return;
        }

        if((now-StorageStartedUtc).TotalSeconds>StorageTimeoutSeconds)
        {
            StorageFailure("TIMEOUT");
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
            StatePath=Path.Combine(root,"sensor_supervisor_state.json");

            bool created=false;
            using(Mutex singleton=new Mutex(true,"Local\\TaskbarMonitorEnhancedSensorSupervisor",out created))
            {
                if(!created)
                {
                    Log("SUPERVISOR_SINGLETON_ALREADY_RUNNING");
                    return 0;
                }

                Log("SUPERVISOR_START R20_PROCESS_ISOLATION pid="+Process.GetCurrentProcess().Id+
                    " broker="+BrokerPath+
                    " cpuOutput="+CpuOutput+
                    " gpuOutput="+GpuOutput+
                    " storageOutput="+StorageOutput);

                bool legacyClear=StopExistingBrokers();
                DateTime initialStart=DateTime.UtcNow;
                Cpu.NextStartUtc=legacyClear?initialStart:DateTime.MaxValue;
                Gpu.NextStartUtc=legacyClear?initialStart:DateTime.MaxValue;
                StorageNextUtc=legacyClear?initialStart:DateTime.MaxValue;
                if(!legacyClear)Log("LEGACY_BROKER_DRAIN_PENDING no R20 workers will start until old broker exits");

                int ticks=0;
                while(true)
                {
                    Thread.Sleep(1000);
                    ticks++;
                    if(!legacyClear)
                    {
                        if(!LegacyBrokerProcessesRemain())
                        {
                            legacyClear=true;
                            Cpu.NextStartUtc=DateTime.UtcNow;
                            Gpu.NextStartUtc=DateTime.UtcNow;
                            StorageNextUtc=DateTime.UtcNow;
                            Log("LEGACY_BROKER_DRAIN_PASS starting isolated R20 workers");
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
        }
    }
}
