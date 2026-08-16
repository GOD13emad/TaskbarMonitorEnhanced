using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Taskbar Monitor Enhanced Setup")]
[assembly: AssemblyDescription("Installer for Taskbar Monitor Enhanced")]
[assembly: AssemblyProduct("Taskbar Monitor Enhanced")]
[assembly: AssemblyCompany("Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyCopyright("Copyright © 2026 Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyVersion("1.0.1.0")]
[assembly: AssemblyFileVersion("1.0.1.0")]

internal static class SetupProgram
{
    const string Product="Taskbar Monitor Enhanced";
    const string Version="1.0.1-rc1";
    const string Publisher="Dr. Ali-Akbar Emadeddin";
    const string AppFolder="TaskbarMonitorEnhanced";
    const string UninstallKey=@"Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced";

    static readonly string[] RequiredResources=new string[] {
      "Payload.TaskbarMonitorEnhanced.exe",
      "Payload.TaskbarMonitorEnhanced.cs",
      "Payload.TaskbarMonitorSensorBroker.exe",
      "Payload.TaskbarMonitorSensorBroker.cs",
      "Payload.TaskbarMonitorSensorSupervisor.exe",
      "Payload.TaskbarMonitorSensorSupervisor.cs",
      "Payload.TaskbarMonitorEnhanced.ico",
      "Payload.LibreHardwareMonitor.zip",
      "Payload.PawnIO_setup.exe",
      "Payload.TBME_Setup_Elevated_Helper.ps1",
      "Payload.LICENSE",
      "Payload.README.md",
      "Payload.AUTHORS.md",
      "Payload.COPYRIGHT_AND_ATTRIBUTION.md",
      "Payload.AI_ASSISTED_DEVELOPMENT.md",
      "Payload.THIRD_PARTY_NOTICES.md",
      "Payload.RELEASE_NOTES_v1.0.1-rc1.md",
      "Payload.UPSTREAM_REFERENCE_GPL_NOTICE.md",
      "Payload.TaskbarMonitorEnhanced_Setup.cs"
    };

    static string AppRoot { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),AppFolder); } }
    static string AppExe { get { return Path.Combine(AppRoot,"TaskbarMonitorEnhanced.exe"); } }
    static string SensorResultPath { get { return Path.Combine(AppRoot,"Logs","sensor_install_result.json"); } }

    sealed class SensorOutcome
    {
        public string Status="UNKNOWN";
        public string Message="Hardware sensor status is unknown.";
        public bool RebootRequired=false;
        public bool IsHealthy=false;
    }

    static Stream Resource(string name)
    {
        return Assembly.GetExecutingAssembly().GetManifestResourceStream(name);
    }

    static void Extract(string resource,string path)
    {
        Stream input=Resource(resource);
        if(input==null)throw new InvalidOperationException("Missing embedded resource: "+resource);
        string parent=Path.GetDirectoryName(path);
        if(!String.IsNullOrEmpty(parent))Directory.CreateDirectory(parent);
        using(input)
        using(FileStream output=File.Create(path))
            input.CopyTo(output);
    }

    static void StopProcess(string name)
    {
        try{
            foreach(Process p in Process.GetProcessesByName(name)){
                try{p.Kill();p.WaitForExit(2500);}catch{}
                try{p.Dispose();}catch{}
            }
        }catch{}
    }

    static int ElevatedHelper(string helper,string args,int timeoutMs)
    {
        ProcessStartInfo psi=new ProcessStartInfo();
        psi.FileName="powershell.exe";
        psi.Arguments="-NoProfile -ExecutionPolicy Bypass -File \""+helper+"\" "+args;
        psi.UseShellExecute=true;
        psi.Verb="runas";
        Process p=Process.Start(psi);
        if(p==null)throw new InvalidOperationException("Could not start protected-sensor helper.");

        DateTime deadline=DateTime.UtcNow.AddMilliseconds(timeoutMs);
        while(!p.HasExited && DateTime.UtcNow<deadline){
            Application.DoEvents();
            Thread.Sleep(100);
        }
        if(!p.HasExited){
            try{p.Kill();}catch{}
            return 124;
        }
        return p.ExitCode;
    }

    static void Shortcut(string path,string target)
    {
        Shortcut(path,target,"","Live system monitor integrated into the Windows taskbar");
    }

    static void Shortcut(string path,string target,string arguments,string description)
    {
        string temp=Path.Combine(Path.GetTempPath(),"tbme_shortcut_"+Guid.NewGuid().ToString("N")+".ps1");
        string text=
          "$ErrorActionPreference='Stop'\r\n"+
          "$w=New-Object -ComObject WScript.Shell\r\n"+
          "$s=$w.CreateShortcut('"+path.Replace("'","''")+"')\r\n"+
          "$s.TargetPath='"+target.Replace("'","''")+"'\r\n"+
          "$s.Arguments='"+arguments.Replace("'","''")+"'\r\n"+
          "$s.WorkingDirectory='"+AppRoot.Replace("'","''")+"'\r\n"+
          "$s.IconLocation='"+AppExe.Replace("'","''")+",0'\r\n"+
          "$s.Description='"+description.Replace("'","''")+"'\r\n"+
          "$s.WindowStyle=1\r\n$s.Save()\r\n";
        File.WriteAllText(temp,text,Encoding.UTF8);
        try{
            ProcessStartInfo psi=new ProcessStartInfo("powershell.exe","-NoProfile -ExecutionPolicy Bypass -File \""+temp+"\"");
            psi.UseShellExecute=false;psi.CreateNoWindow=true;
            Process p=Process.Start(psi);
            if(p==null || !p.WaitForExit(15000) || p.ExitCode!=0)
                throw new InvalidOperationException("Shortcut creation failed.");
        }
        finally{try{File.Delete(temp);}catch{}}
    }

    static void WriteBackendState(string backendRoot)
    {
        string library=Path.Combine(backendRoot,"LibreHardwareMonitorLib.dll");
        string json="{\r\n"+
          "  \"Status\": \"READY\",\r\n"+
          "  \"Backend\": \"LibreHardwareMonitor\",\r\n"+
          "  \"Version\": \"0.9.6\",\r\n"+
          "  \"LibraryPath\": \""+library.Replace("\\","\\\\")+"\"\r\n"+
          "}\r\n";
        File.WriteAllText(Path.Combine(AppRoot,"sensor_backend_state.json"),json,Encoding.UTF8);
    }

    static void WriteInstallState()
    {
        string json="{\r\n"+
          "  \"App\": \"Taskbar Monitor Enhanced\",\r\n"+
          "  \"Version\": \"PUBLIC_1.0.1_RC1\",\r\n"+
          "  \"PublicVersion\": \"1.0.1-rc1\",\r\n"+
          "  \"InternalRuntimeBaseline\": \"R12A2R5R4\",\r\n"+
          "  \"SensorSupervisor\": \"R12A2R5R4S1R3R2_ACCEPTED\",\r\n"+
          "  \"ProductIdentity\": \"LOCKED\",\r\n"+
          "  \"ShortcutName\": \"Taskbar Monitor Enhanced\",\r\n"+
          "  \"Publisher\": \"Dr. Ali-Akbar Emadeddin\",\r\n"+
          "  \"PublisherEmail\": \"aliemad1324@gmail.com\",\r\n"+
          "  \"PublisherGitHub\": \"https://github.com/GOD13emad\",\r\n"+
          "  \"License\": \"GPL-3.0\",\r\n"+
          "  \"AiAssistedDevelopmentDisclosure\": \"DOCUMENTED\",\r\n"+
          "  \"UpstreamAttribution\": \"leandrosa81/taskbar-monitor GPL-3.0\"\r\n"+
          "}\r\n";
        File.WriteAllText(Path.Combine(AppRoot,"install_state.json"),json,Encoding.UTF8);
    }

    static string PrepareSensorPayload()
    {
        string payload=Path.Combine(Path.GetTempPath(),"tbme_setup_"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(payload);
        Extract("Payload.TaskbarMonitorSensorBroker.exe",Path.Combine(payload,"TaskbarMonitorSensorBroker.exe"));
        Extract("Payload.TaskbarMonitorSensorSupervisor.exe",Path.Combine(payload,"TaskbarMonitorSensorSupervisor.exe"));
        Extract("Payload.PawnIO_setup.exe",Path.Combine(payload,"PawnIO_setup.exe"));
        Extract("Payload.TBME_Setup_Elevated_Helper.ps1",Path.Combine(payload,"TBME_Setup_Elevated_Helper.ps1"));
        return payload;
    }

    static SensorOutcome ReadSensorOutcome()
    {
        SensorOutcome outcome=new SensorOutcome();
        try{
            if(!File.Exists(SensorResultPath))return outcome;
            string json=File.ReadAllText(SensorResultPath,Encoding.UTF8);
            outcome.Status=JsonString(json,"Status");
            outcome.Message=JsonString(json,"Message");
            outcome.RebootRequired=JsonBool(json,"RebootRequired");
            outcome.IsHealthy=String.Equals(outcome.Status,"READY",StringComparison.OrdinalIgnoreCase);
            if(String.IsNullOrEmpty(outcome.Status))outcome.Status="UNKNOWN";
            if(String.IsNullOrEmpty(outcome.Message))outcome.Message="Hardware sensor status is unknown.";
        }catch{}
        return outcome;
    }

    static string JsonString(string json,string key)
    {
        string marker="\""+key+"\":";
        int p=json.IndexOf(marker,StringComparison.OrdinalIgnoreCase);
        if(p<0)return "";
        p+=marker.Length;
        while(p<json.Length && Char.IsWhiteSpace(json[p]))p++;
        if(p>=json.Length || json[p]!='\"')return "";
        p++;
        StringBuilder b=new StringBuilder();
        bool esc=false;
        while(p<json.Length){
            char c=json[p++];
            if(esc){
                if(c=='n')b.Append('\n');
                else if(c=='r')b.Append('\r');
                else if(c=='t')b.Append('\t');
                else b.Append(c);
                esc=false;
            }else if(c=='\\'){
                esc=true;
            }else if(c=='\"'){
                break;
            }else b.Append(c);
        }
        return b.ToString();
    }

    static bool JsonBool(string json,string key)
    {
        string marker="\""+key+"\":";
        int p=json.IndexOf(marker,StringComparison.OrdinalIgnoreCase);
        if(p<0)return false;
        p+=marker.Length;
        while(p<json.Length && Char.IsWhiteSpace(json[p]))p++;
        return p+4<=json.Length && String.Equals(json.Substring(p,4),"true",StringComparison.OrdinalIgnoreCase);
    }

    static SensorOutcome InstallSensorLayer()
    {
        SensorOutcome outcome=new SensorOutcome();
        string payload=null;
        try{
            Directory.CreateDirectory(Path.Combine(AppRoot,"Logs"));
            try{File.Delete(SensorResultPath);}catch{}
            payload=PrepareSensorPayload();
            string helper=Path.Combine(payload,"TBME_Setup_Elevated_Helper.ps1");
            string user=WindowsIdentity.GetCurrent().Name;
            int helperExit;
            try{
                helperExit=ElevatedHelper(helper,
                  "-Mode Install -PayloadDir \""+payload+"\" -AppRoot \""+AppRoot+"\" -UserId \""+user+"\"",
                  110000);
            }catch(Exception ex){
                outcome.Status="DEGRADED";
                outcome.Message="The application installed successfully, but Windows did not complete the protected CPU sensor step. "+ex.Message+" CPU temperature will show N/A for now.";
                return outcome;
            }

            outcome=ReadSensorOutcome();
            if(helperExit==124 && String.Equals(outcome.Status,"UNKNOWN",StringComparison.OrdinalIgnoreCase)){
                outcome.Status="DEGRADED";
                outcome.Message="The application installed successfully, but the hardware sensor step exceeded its time limit. CPU temperature will show N/A for now.";
            }else if(helperExit!=0 && String.Equals(outcome.Status,"UNKNOWN",StringComparison.OrdinalIgnoreCase)){
                outcome.Status="DEGRADED";
                outcome.Message="The application installed successfully, but the hardware sensor helper returned exit code "+helperExit+". CPU temperature will show N/A for now.";
            }
            return outcome;
        }finally{
            if(payload!=null)try{Directory.Delete(payload,true);}catch{}
        }
    }

    static SensorOutcome RepairSensors()
    {
        if(!Directory.Exists(AppRoot) || !File.Exists(AppExe))
            throw new InvalidOperationException("Taskbar Monitor Enhanced is not installed.");
        return InstallSensorLayer();
    }

    static SensorOutcome Install(bool desktop,bool startup)
    {
        if(!Environment.Is64BitOperatingSystem)
            throw new InvalidOperationException("Taskbar Monitor Enhanced 1.0.1 RC1 requires 64-bit Windows.");

        StopProcess("TaskbarMonitorEnhanced");

        Directory.CreateDirectory(AppRoot);
        Directory.CreateDirectory(Path.Combine(AppRoot,"Source"));
        Directory.CreateDirectory(Path.Combine(AppRoot,"Docs"));

        Extract("Payload.TaskbarMonitorEnhanced.exe",AppExe);
        Extract("Payload.TaskbarMonitorEnhanced.ico",Path.Combine(AppRoot,"TaskbarMonitorEnhanced.ico"));
        Extract("Payload.TaskbarMonitorEnhanced.cs",Path.Combine(AppRoot,"TaskbarMonitorEnhanced.cs"));
        Extract("Payload.TaskbarMonitorEnhanced.cs",Path.Combine(AppRoot,"Source","TaskbarMonitorEnhanced.cs"));
        Extract("Payload.TaskbarMonitorSensorBroker.cs",Path.Combine(AppRoot,"Source","TaskbarMonitorSensorBroker.cs"));
        Extract("Payload.TaskbarMonitorSensorSupervisor.cs",Path.Combine(AppRoot,"Source","TaskbarMonitorSensorSupervisor.cs"));
        Extract("Payload.TaskbarMonitorEnhanced_Setup.cs",Path.Combine(AppRoot,"Source","TaskbarMonitorEnhanced_Setup.cs"));

        string[] docs=new string[]{
          "LICENSE","README.md","AUTHORS.md","COPYRIGHT_AND_ATTRIBUTION.md",
          "AI_ASSISTED_DEVELOPMENT.md","THIRD_PARTY_NOTICES.md",
          "RELEASE_NOTES_v1.0.1-rc1.md","UPSTREAM_REFERENCE_GPL_NOTICE.md"
        };
        foreach(string doc in docs)
            Extract("Payload."+doc,Path.Combine(AppRoot,"Docs",doc));

        string backendRoot=Path.Combine(AppRoot,"SensorBackend","LibreHardwareMonitor-0.9.6");
        if(Directory.Exists(backendRoot))Directory.Delete(backendRoot,true);
        Directory.CreateDirectory(backendRoot);
        string lhmZip=Path.Combine(Path.GetTempPath(),"tbme_lhm_"+Guid.NewGuid().ToString("N")+".zip");
        Extract("Payload.LibreHardwareMonitor.zip",lhmZip);
        ZipFile.ExtractToDirectory(lhmZip,backendRoot);
        try{File.Delete(lhmZip);}catch{}
        WriteBackendState(backendRoot);

        SensorOutcome sensorOutcome=InstallSensorLayer();

        string uninstaller=Path.Combine(AppRoot,"Uninstall.exe");
        File.Copy(Application.ExecutablePath,uninstaller,true);

        string desktopLink=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),Product+".lnk");
        string startLink=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),Product+".lnk");
        string repairLink=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),Product+" - Repair Hardware Sensors.lnk");
        Shortcut(startLink,AppExe);
        Shortcut(repairLink,uninstaller,"/repair-sensors","Repair or retry Taskbar Monitor Enhanced hardware sensors");
        if(desktop)Shortcut(desktopLink,AppExe);
        else try{File.Delete(desktopLink);}catch{}

        using(RegistryKey run=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")){
            if(startup)run.SetValue("TaskbarMonitorEnhanced","\""+AppExe+"\"");
            else run.DeleteValue("TaskbarMonitorEnhanced",false);
        }

        using(RegistryKey key=Registry.CurrentUser.CreateSubKey(UninstallKey)){
            key.SetValue("DisplayName",Product);
            key.SetValue("DisplayVersion",Version);
            key.SetValue("Publisher",Publisher);
            key.SetValue("DisplayIcon",AppExe);
            key.SetValue("InstallLocation",AppRoot);
            key.SetValue("UninstallString","\""+uninstaller+"\" /uninstall");
            key.SetValue("QuietUninstallString","\""+uninstaller+"\" /uninstall /quiet");
            key.SetValue("NoModify",1,RegistryValueKind.DWord);
            key.SetValue("NoRepair",1,RegistryValueKind.DWord);
        }

        WriteInstallState();
        Process.Start(AppExe);
        return sensorOutcome;
    }

    static void Uninstall(bool quiet)
    {
        if(!quiet){
            DialogResult answer=MessageBox.Show(
              "Remove Taskbar Monitor Enhanced, its shortcuts, settings and logs?\r\n\r\nPawnIO is intentionally left installed because other hardware-monitoring applications may use it.",
              "Uninstall "+Product,MessageBoxButtons.YesNo,MessageBoxIcon.Question);
            if(answer!=DialogResult.Yes)return;
        }

        StopProcess("TaskbarMonitorEnhanced");

        string payload=Path.Combine(Path.GetTempPath(),"tbme_uninstall_"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(payload);
        string helper=Path.Combine(payload,"TBME_Setup_Elevated_Helper.ps1");
        Extract("Payload.TBME_Setup_Elevated_Helper.ps1",helper);
        string user=WindowsIdentity.GetCurrent().Name;

        int helperExit=ElevatedHelper(helper,
          "-Mode Uninstall -PayloadDir \""+payload+"\" -AppRoot \""+AppRoot+"\" -UserId \""+user+"\"",
          90000);
        if(helperExit!=0)
            throw new InvalidOperationException("Protected sensor removal failed. Exit code: "+helperExit);

        try{File.Delete(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),Product+".lnk"));}catch{}
        try{File.Delete(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),Product+".lnk"));}catch{}
        try{File.Delete(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),Product+" - Repair Hardware Sensors.lnk"));}catch{}

        using(RegistryKey run=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
            run.DeleteValue("TaskbarMonitorEnhanced",false);
        Registry.CurrentUser.DeleteSubKeyTree(UninstallKey,false);

        string cleanup=Path.Combine(Path.GetTempPath(),"tbme_cleanup_"+Guid.NewGuid().ToString("N")+".cmd");
        File.WriteAllText(cleanup,
          "@echo off\r\nping 127.0.0.1 -n 4 >nul\r\nrmdir /s /q \""+AppRoot+"\"\r\ndel /q \"%~f0\"\r\n",
          Encoding.ASCII);
        ProcessStartInfo psi=new ProcessStartInfo("cmd.exe","/c \""+cleanup+"\"");
        psi.UseShellExecute=false;psi.CreateNoWindow=true;
        Process.Start(psi);

        if(!quiet)
            MessageBox.Show(Product+" was removed.","Uninstall complete",MessageBoxButtons.OK,MessageBoxIcon.Information);
    }

    static int Verify(string path)
    {
        try{
            foreach(string resourceName in RequiredResources){
                using(Stream s=Resource(resourceName)){
                    if(s==null || s.Length==0)return 20;
                }
            }
            if(!String.IsNullOrEmpty(path)){
                string json="{\"Status\":\"PASS\",\"Resources\":"+RequiredResources.Length+",\"Version\":\"1.0.1-rc1\",\"Publisher\":\"Dr. Ali-Akbar Emadeddin\"}";
                File.WriteAllText(path,json,Encoding.UTF8);
            }
            return 0;
        }catch{return 21;}
    }

    static string Value(string[] args,string prefix)
    {
        foreach(string arg in args)
            if(arg.StartsWith(prefix,StringComparison.OrdinalIgnoreCase))
                return arg.Substring(prefix.Length);
        return "";
    }

    static bool Has(string[] args,string value)
    {
        foreach(string arg in args)
            if(String.Equals(arg,value,StringComparison.OrdinalIgnoreCase))return true;
        return false;
    }

    sealed class SetupForm:Form
    {
        CheckBox desktop,startup;
        Button install;
        ProgressBar progress;
        Label status;

        public SetupForm()
        {
            Text=Product+" Setup";
            Width=610;Height=435;StartPosition=FormStartPosition.CenterScreen;
            FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;
            Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);

            Label title=new Label();
            title.Text=Product+"  1.0.1 RC1";
            title.Font=new Font(Font.FontFamily,18,FontStyle.Bold);
            title.Left=28;title.Top=22;title.AutoSize=true;Controls.Add(title);

            Label author=new Label();
            author.Text="Lead Developer & Maintainer: Dr. Ali-Akbar Emadeddin\r\nGPL-3.0 • AI-assisted development transparently documented";
            author.Left=31;author.Top=67;author.AutoSize=true;Controls.Add(author);

            TextBox info=new TextBox();
            info.Left=30;info.Top=116;info.Width=530;info.Height=140;
            info.Multiline=true;info.ReadOnly=true;info.ScrollBars=ScrollBars.Vertical;
            info.Text="Live CPU, RAM, disk, GPU, VRAM, network and temperature telemetry integrated into the Windows taskbar.\r\n\r\nThe main application runs without elevation. Windows requests administrator approval only for the optional protected hardware-sensor service. If the CPU sensor cannot be activated, installation still completes and CPU temperature shows N/A.\r\n\r\nSource code, GPL license, upstream attribution and third-party notices are installed with the application.";
            Controls.Add(info);

            desktop=new CheckBox();desktop.Text="Create Desktop shortcut";desktop.Checked=true;
            desktop.Left=35;desktop.Top=276;desktop.AutoSize=true;Controls.Add(desktop);

            startup=new CheckBox();startup.Text="Start with Windows";startup.Checked=true;
            startup.Left=35;startup.Top=304;startup.AutoSize=true;Controls.Add(startup);

            progress=new ProgressBar();progress.Left=35;progress.Top=337;progress.Width=370;progress.Height=18;
            progress.Style=ProgressBarStyle.Marquee;progress.Visible=false;Controls.Add(progress);

            status=new Label();status.Left=35;status.Top=362;status.Width=390;status.Text="Ready";Controls.Add(status);

            install=new Button();install.Text="Install";install.Left=460;install.Top=326;install.Width=100;install.Height=38;
            install.Click+=delegate{
                install.Enabled=false;desktop.Enabled=false;startup.Enabled=false;progress.Visible=true;
                status.Text="Installing application and optional CPU sensor support…";
                Application.DoEvents();
                try{
                    SensorOutcome outcome=Install(desktop.Checked,startup.Checked);
                    progress.Visible=false;
                    status.Text="Installation completed.";
                    if(outcome.IsHealthy){
                        MessageBox.Show(Product+" 1.0.1 RC1 was installed successfully.\r\n\r\nCPU temperature monitoring is active.",
                          "Setup complete",MessageBoxButtons.OK,MessageBoxIcon.Information);
                    }else{
                        string extra=outcome.RebootRequired ? "\r\n\r\nRestart Windows, then use Start Menu > Taskbar Monitor Enhanced - Repair Hardware Sensors if needed." :
                          "\r\n\r\nThe application is installed and usable. CPU temperature will show N/A for now. You can retry from Start Menu > Taskbar Monitor Enhanced - Repair Hardware Sensors.";
                        MessageBox.Show(Product+" 1.0.1 RC1 was installed successfully.\r\n\r\n"+outcome.Message+extra,
                          "Setup complete - sensor warning",MessageBoxButtons.OK,MessageBoxIcon.Warning);
                    }
                    Close();
                }catch(Exception ex){
                    progress.Visible=false;install.Enabled=true;desktop.Enabled=true;startup.Enabled=true;
                    status.Text="Installation failed.";
                    MessageBox.Show(ex.Message,"Setup failed",MessageBoxButtons.OK,MessageBoxIcon.Error);
                }
            };
            Controls.Add(install);
        }
    }

    [STAThread]
    static int Main(string[] args)
    {
        if(Has(args,"/verify"))
            return Verify(Value(args,"/verifyfile="));

        bool quiet=Has(args,"/quiet");
        if(Has(args,"/install")){
            try{
                bool desktop=!String.Equals(Value(args,"/desktop="),"0",StringComparison.OrdinalIgnoreCase);
                bool startup=!String.Equals(Value(args,"/startup="),"0",StringComparison.OrdinalIgnoreCase);
                Install(desktop,startup);
                return 0;
            }catch(Exception ex){
                if(!quiet)MessageBox.Show(ex.Message,"Setup failed",MessageBoxButtons.OK,MessageBoxIcon.Error);
                return 30;
            }
        }

        if(Has(args,"/repair-sensors")){
            try{
                SensorOutcome outcome=RepairSensors();
                if(!quiet){
                    MessageBoxIcon icon=outcome.IsHealthy?MessageBoxIcon.Information:MessageBoxIcon.Warning;
                    MessageBox.Show(outcome.Message+"\r\n\r\nDiagnostic log:\r\n"+Path.Combine(AppRoot,"Logs","sensor_install.log"),
                      outcome.IsHealthy?"Sensor repair complete":"Sensor repair warning",MessageBoxButtons.OK,icon);
                }
                return outcome.IsHealthy?0:10;
            }catch(Exception ex){
                if(!quiet)MessageBox.Show(ex.Message,"Sensor repair failed",MessageBoxButtons.OK,MessageBoxIcon.Error);
                return 32;
            }
        }

        if(Has(args,"/uninstall")){
            try{Uninstall(quiet);return 0;}
            catch(Exception ex){
                if(!quiet)MessageBox.Show(ex.Message,"Uninstall failed",MessageBoxButtons.OK,MessageBoxIcon.Error);
                return 31;
            }
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new SetupForm());
        return 0;
    }
}
