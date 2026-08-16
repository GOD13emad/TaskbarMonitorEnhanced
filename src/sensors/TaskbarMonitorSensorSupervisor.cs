using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Threading;

internal static class TaskbarMonitorSensorSupervisor
{
    const int FreshnessLimitSeconds=15;
    const int StartupGraceSeconds=30;
    static string LogPath="";
    static string StatePath="";
    static string BrokerPath="";
    static string OutputPath="";
    static Process Worker=null;
    static int RestartCount=0;
    static DateTime StartedUtc=DateTime.UtcNow;
    static DateTime WorkerStartedUtc=DateTime.MinValue;

    static void Log(string message)
    {
        try
        {
            File.AppendAllText(LogPath,
                DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)+" "+message+Environment.NewLine);
        }
        catch{}
    }

    static void WriteState(string reason)
    {
        try
        {
            string json="{"+
                "\"TimestampUtc\":\""+DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)+"\","+
                "\"SupervisorPid\":"+Process.GetCurrentProcess().Id+","+
                "\"WorkerPid\":"+((Worker!=null && !Worker.HasExited)?Worker.Id:0)+","+
                "\"RestartCount\":"+RestartCount+","+
                "\"Reason\":\""+reason.Replace("\\","\\\\").Replace("\"","\\\"")+"\""+
                "}";
            File.WriteAllText(StatePath,json);
        }
        catch{}
    }

    static void StopExistingBrokers()
    {
        try
        {
            foreach(Process p in Process.GetProcessesByName("TaskbarMonitorSensorBroker"))
            {
                try{p.Kill();p.WaitForExit(1500);}catch{}
                try{p.Dispose();}catch{}
            }
        }
        catch{}
    }

    static Process StartWorker(string reason)
    {
        StopExistingBrokers();
        ProcessStartInfo psi=new ProcessStartInfo();
        psi.FileName=BrokerPath;
        psi.Arguments="--run \""+OutputPath+"\"";
        psi.UseShellExecute=false;
        psi.CreateNoWindow=true;
        Process p=Process.Start(psi);
        if(p==null)throw new InvalidOperationException("BROKER_START_RETURNED_NULL");
        RestartCount++;
        WorkerStartedUtc=DateTime.UtcNow;
        Log("WORKER_START reason="+reason+" pid="+p.Id+" restartCount="+RestartCount+
            " startupGraceSec="+StartupGraceSeconds);
        Worker=p;
        WriteState(reason);
        return p;
    }

    static double OutputAgeSeconds()
    {
        try
        {
            if(!File.Exists(OutputPath))return Double.MaxValue;
            return (DateTime.UtcNow-File.GetLastWriteTimeUtc(OutputPath)).TotalSeconds;
        }
        catch{return Double.MaxValue;}
    }

    static bool ParseArgs(string[] args)
    {
        for(int i=0;i<args.Length-1;i++)
        {
            if(String.Equals(args[i],"--broker",StringComparison.OrdinalIgnoreCase))BrokerPath=args[++i];
            else if(String.Equals(args[i],"--output",StringComparison.OrdinalIgnoreCase))OutputPath=args[++i];
        }
        return !String.IsNullOrWhiteSpace(BrokerPath) && !String.IsNullOrWhiteSpace(OutputPath);
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

                StartedUtc=DateTime.UtcNow;
                Log("SUPERVISOR_START ANTI_THRASH_WORKER_STARTUP_GRACE=TRUE pid="+Process.GetCurrentProcess().Id+
                    " broker="+BrokerPath+" output="+OutputPath+
                    " freshnessLimitSec="+FreshnessLimitSeconds);

                StartWorker("SUPERVISOR_START");

                int ticks=0;
                while(true)
                {
                    Thread.Sleep(1000);
                    ticks++;

                    bool exited=false;
                    try{exited=Worker==null || Worker.HasExited;}catch{exited=true;}
                    if(exited)
                    {
                        int exitCode=-999;
                        try{if(Worker!=null)exitCode=Worker.ExitCode;}catch{}
                        Log("WORKER_EXIT_DETECTED exitCode="+exitCode);
                        Thread.Sleep(300);
                        StartWorker("WORKER_EXIT");
                        continue;
                    }

                    double age=OutputAgeSeconds();
                    double workerAge=(DateTime.UtcNow-WorkerStartedUtc).TotalSeconds;
                    DateTime outputWriteUtc=DateTime.MinValue;
                    try
                    {
                        if(File.Exists(OutputPath))
                            outputWriteUtc=File.GetLastWriteTimeUtc(OutputPath);
                    }
                    catch{}

                    bool outputFromCurrentWorker=
                        outputWriteUtc!=DateTime.MinValue &&
                        outputWriteUtc>=WorkerStartedUtc.AddSeconds(-1);

                    if(workerAge<=StartupGraceSeconds)
                    {
                        if(ticks%5==0)
                        {
                            Log("WORKER_STARTUP_GRACE workerPid="+Worker.Id+
                                " workerAgeSec="+workerAge.ToString("0.0",CultureInfo.InvariantCulture)+
                                " outputFromCurrentWorker="+outputFromCurrentWorker+
                                " outputAgeSec="+(age==Double.MaxValue?"INF":age.ToString("0.0",CultureInfo.InvariantCulture)));
                            WriteState("STARTUP_GRACE");
                        }
                        continue;
                    }

                    if(!outputFromCurrentWorker)
                    {
                        Log("WORKER_NO_CURRENT_OUTPUT_AFTER_GRACE workerPid="+Worker.Id+
                            " workerAgeSec="+workerAge.ToString("0.0",CultureInfo.InvariantCulture));
                        try{Worker.Kill();Worker.WaitForExit(1500);}catch{}
                        Thread.Sleep(500);
                        StartWorker("NO_CURRENT_OUTPUT_AFTER_GRACE");
                        continue;
                    }

                    if(age>FreshnessLimitSeconds)
                    {
                        Log("WORKER_STALE_DETECTED ageSec="+
                            age.ToString("0.0",CultureInfo.InvariantCulture)+
                            " workerPid="+Worker.Id+
                            " workerAgeSec="+workerAge.ToString("0.0",CultureInfo.InvariantCulture));
                        try{Worker.Kill();Worker.WaitForExit(1500);}catch{}
                        Thread.Sleep(500);
                        StartWorker("STALE_OUTPUT");
                        continue;
                    }

                    if(ticks%5==0)WriteState("HEALTHY");
                }
            }
        }
        catch(Exception ex)
        {
            Log("SUPERVISOR_FATAL "+ex.ToString());
            return 100;
        }
    }
}
