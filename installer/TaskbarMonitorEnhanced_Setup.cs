using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Taskbar Monitor Enhanced Setup")]
[assembly: AssemblyDescription("Installer for Taskbar Monitor Enhanced")]
[assembly: AssemblyProduct("Taskbar Monitor Enhanced")]
[assembly: AssemblyCompany("Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyCopyright("Copyright © 2026 Dr. Ali-Akbar Emadeddin")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class SetupProgram
{
    const string Product="Taskbar Monitor Enhanced";
    const string Version="1.0.0";
    const string Publisher="Dr. Ali-Akbar Emadeddin";
    const string AppFolder="TaskbarMonitorEnhanced";
    const string UninstallKey=@"Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced";

    static readonly string[] RequiredResources=new string[] {
      "Payload.TaskbarMonitorEnhanced.exe","Payload.TaskbarMonitorEnhanced.cs","Payload.TaskbarMonitorSensorBroker.exe","Payload.TaskbarMonitorSensorBroker.cs","Payload.TaskbarMonitorSensorSupervisor.exe","Payload.TaskbarMonitorSensorSupervisor.cs","Payload.TaskbarMonitorEnhanced.ico","Payload.LibreHardwareMonitor.zip","Payload.PawnIO_setup.exe","Payload.TBME_Setup_Elevated_Helper.ps1","Payload.LICENSE","Payload.README.md","Payload.AUTHORS.md","Payload.COPYRIGHT_AND_ATTRIBUTION.md","Payload.AI_ASSISTED_DEVELOPMENT.md","Payload.THIRD_PARTY_NOTICES.md","Payload.RELEASE_NOTES_v1.0.0.md","Payload.UPSTREAM_REFERENCE_GPL_NOTICE.md","Payload.TaskbarMonitorEnhanced_Setup.cs"
    };

    static string AppRoot { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),AppFolder); } }
    static string AppExe { get { return Path.Combine(AppRoot,"TaskbarMonitorEnhanced.exe"); } }
    static Stream Resource(string name) { return Assembly.GetExecutingAssembly().GetManifestResourceStream(name); }
    static void Extract(string resource,string path)
    {
        Stream input=Resource(resource);
        if(input==null)throw new InvalidOperationException("Missing embedded resource: "+resource);
        string parent=Path.GetDirectoryName(path);
        if(!String.IsNullOrEmpty(parent))Directory.CreateDirectory(parent);
        using(input) using(FileStream output=File.Create(path)) input.CopyTo(output);
    }
    static void StopProcess(string name)
    {
        try{foreach(Process p in Process.GetProcessesByName(name)){try{p.Kill();p.WaitForExit(2500);}catch{} try{p.Dispose();}catch{}}}catch{}
    }
    static int ElevatedHelper(string helper,string args,int timeoutMs)
    {
        ProcessStartInfo psi=new ProcessStartInfo();
        psi.FileName="powershell.exe";psi.Arguments="-NoProfile -ExecutionPolicy Bypass -File \""+helper+"\" "+args;psi.UseShellExecute=true;psi.Verb="runas";
        Process p=Process.Start(psi);if(p==null)throw new InvalidOperationException("Could not start protected-sensor helper.");
        if(!p.WaitForExit(timeoutMs)){try{p.Kill();}catch{} throw new TimeoutException("Protected-sensor helper timed out.");}
        return p.ExitCode;
    }
    static void Shortcut(string path,string target)
    {
        string temp=Path.Combine(Path.GetTempPath(),"tbme_shortcut_"+Guid.NewGuid().ToString("N")+".ps1");
        string text="$ErrorActionPreference='Stop'\r\n"+"$w=New-Object -ComObject WScript.Shell\r\n"+"$s=$w.CreateShortcut('"+path.Replace("'","''")+"')\r\n"+"$s.TargetPath='"+target.Replace("'","''")+"'\r\n"+"$s.WorkingDirectory='"+AppRoot.Replace("'","''")+"'\r\n"+"$s.IconLocation='"+target.Replace("'","''")+",0'\r\n"+"$s.Description='Live system monitor integrated into the Windows taskbar'\r\n"+"$s.WindowStyle=1\r\n$s.Save()\r\n";
        File.WriteAllText(temp,text,Encoding.UTF8);
        try{ProcessStartInfo psi=new ProcessStartInfo("powershell.exe","-NoProfile -ExecutionPolicy Bypass -File \""+temp+"\"");psi.UseShellExecute=false;psi.CreateNoWindow=true;Process p=Process.Start(psi);if(p==null || !p.WaitForExit(15000) || p.ExitCode!=0)throw new InvalidOperationException("Shortcut creation failed.");}
        finally{try{File.Delete(temp);}catch{}}
    }
    static void WriteBackendState(string backendRoot)
    {
        string library=Path.Combine(backendRoot,"LibreHardwareMonitorLib.dll");
        string json="{\r\n  \"Status\": \"READY\",\r\n  \"Backend\": \"LibreHardwareMonitor\",\r\n  \"Version\": \"0.9.6\",\r\n  \"LibraryPath\": \""+library.Replace("\\","\\\\")+"\"\r\n}\r\n";
        File.WriteAllText(Path.Combine(AppRoot,"sensor_backend_state.json"),json,Encoding.UTF8);
    }
    static void WriteInstallState()
    {
        string json="{\r\n  \"App\": \"Taskbar Monitor Enhanced\",\r\n  \"Version\": \"PUBLIC_1.0.0\",\r\n  \"PublicVersion\": \"1.0.0\",\r\n  \"InternalRuntimeBaseline\": \"R12A2R5R4\",\r\n  \"SensorSupervisor\": \"R12A2R5R4S1R3R2_ACCEPTED\",\r\n  \"ProductIdentity\": \"LOCKED\",\r\n  \"ShortcutName\": \"Taskbar Monitor Enhanced\",\r\n  \"Publisher\": \"Dr. Ali-Akbar Emadeddin\",\r\n  \"PublisherEmail\": \"aliemad1324@gmail.com\",\r\n  \"PublisherGitHub\": \"https://github.com/GOD13emad\",\r\n  \"License\": \"GPL-3.0\",\r\n  \"AiAssistedDevelopmentDisclosure\": \"DOCUMENTED\",\r\n  \"UpstreamAttribution\": \"leandrosa81/taskbar-monitor GPL-3.0\"\r\n}\r\n";
        File.WriteAllText(Path.Combine(AppRoot,"install_state.json"),json,Encoding.UTF8);
    }
    static void Install(bool desktop,bool startup)
    {
        if(!Environment.Is64BitOperatingSystem)throw new InvalidOperationException("Taskbar Monitor Enhanced 1.0.0 requires 64-bit Windows.");
        StopProcess("TaskbarMonitorEnhanced");Directory.CreateDirectory(AppRoot);Directory.CreateDirectory(Path.Combine(AppRoot,"Source"));Directory.CreateDirectory(Path.Combine(AppRoot,"Docs"));
        Extract("Payload.TaskbarMonitorEnhanced.exe",AppExe);Extract("Payload.TaskbarMonitorEnhanced.ico",Path.Combine(AppRoot,"TaskbarMonitorEnhanced.ico"));Extract("Payload.TaskbarMonitorEnhanced.cs",Path.Combine(AppRoot,"TaskbarMonitorEnhanced.cs"));Extract("Payload.TaskbarMonitorEnhanced.cs",Path.Combine(AppRoot,"Source","TaskbarMonitorEnhanced.cs"));Extract("Payload.TaskbarMonitorSensorBroker.cs",Path.Combine(AppRoot,"Source","TaskbarMonitorSensorBroker.cs"));Extract("Payload.TaskbarMonitorSensorSupervisor.cs",Path.Combine(AppRoot,"Source","TaskbarMonitorSensorSupervisor.cs"));Extract("Payload.TaskbarMonitorEnhanced_Setup.cs",Path.Combine(AppRoot,"Source","TaskbarMonitorEnhanced_Setup.cs"));
        string[] docs=new string[]{"LICENSE","README.md","AUTHORS.md","COPYRIGHT_AND_ATTRIBUTION.md","AI_ASSISTED_DEVELOPMENT.md","THIRD_PARTY_NOTICES.md","RELEASE_NOTES_v1.0.0.md","UPSTREAM_REFERENCE_GPL_NOTICE.md"};
        foreach(string doc in docs)Extract("Payload."+doc,Path.Combine(AppRoot,"Docs",doc));
        string backendRoot=Path.Combine(AppRoot,"SensorBackend","LibreHardwareMonitor-0.9.6");if(Directory.Exists(backendRoot))Directory.Delete(backendRoot,true);Directory.CreateDirectory(backendRoot);
        string lhmZip=Path.Combine(Path.GetTempPath(),"tbme_lhm_"+Guid.NewGuid().ToString("N")+".zip");Extract("Payload.LibreHardwareMonitor.zip",lhmZip);ZipFile.ExtractToDirectory(lhmZip,backendRoot);try{File.Delete(lhmZip);}catch{}WriteBackendState(backendRoot);
        string payload=Path.Combine(Path.GetTempPath(),"tbme_setup_"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(payload);Extract("Payload.TaskbarMonitorSensorBroker.exe",Path.Combine(payload,"TaskbarMonitorSensorBroker.exe"));Extract("Payload.TaskbarMonitorSensorSupervisor.exe",Path.Combine(payload,"TaskbarMonitorSensorSupervisor.exe"));Extract("Payload.PawnIO_setup.exe",Path.Combine(payload,"PawnIO_setup.exe"));string helper=Path.Combine(payload,"TBME_Setup_Elevated_Helper.ps1");Extract("Payload.TBME_Setup_Elevated_Helper.ps1",helper);
        string user=WindowsIdentity.GetCurrent().Name;int helperExit=ElevatedHelper(helper,"-Mode Install -PayloadDir \""+payload+"\" -AppRoot \""+AppRoot+"\" -UserId \""+user+"\"",180000);if(helperExit!=0)throw new InvalidOperationException("Protected sensor installation failed. Exit code: "+helperExit);
        string desktopLink=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),Product+".lnk");string startLink=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),Product+".lnk");Shortcut(startLink,AppExe);if(desktop)Shortcut(desktopLink,AppExe);else try{File.Delete(desktopLink);}catch{}
        using(RegistryKey run=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")){if(startup)run.SetValue("TaskbarMonitorEnhanced","\""+AppExe+"\"");else run.DeleteValue("TaskbarMonitorEnhanced",false);}
        string uninstaller=Path.Combine(AppRoot,"Uninstall.exe");File.Copy(Application.ExecutablePath,uninstaller,true);using(RegistryKey key=Registry.CurrentUser.CreateSubKey(UninstallKey)){key.SetValue("DisplayName",Product);key.SetValue("DisplayVersion",Version);key.SetValue("Publisher",Publisher);key.SetValue("DisplayIcon",AppExe);key.SetValue("InstallLocation",AppRoot);key.SetValue("UninstallString","\""+uninstaller+"\" /uninstall");key.SetValue("QuietUninstallString","\""+uninstaller+"\" /uninstall /quiet");key.SetValue("NoModify",1,RegistryValueKind.DWord);key.SetValue("NoRepair",1,RegistryValueKind.DWord);}
        WriteInstallState();try{Directory.Delete(payload,true);}catch{}Process.Start(AppExe);
    }
    static void Uninstall(bool quiet)
    {
        if(!quiet){DialogResult answer=MessageBox.Show("Remove Taskbar Monitor Enhanced, its shortcuts, settings and logs?\r\n\r\nPawnIO is intentionally left installed because other hardware-monitoring applications may use it.","Uninstall "+Product,MessageBoxButtons.YesNo,MessageBoxIcon.Question);if(answer!=DialogResult.Yes)return;}
        StopProcess("TaskbarMonitorEnhanced");string payload=Path.Combine(Path.GetTempPath(),"tbme_uninstall_"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(payload);string helper=Path.Combine(payload,"TBME_Setup_Elevated_Helper.ps1");Extract("Payload.TBME_Setup_Elevated_Helper.ps1",helper);string user=WindowsIdentity.GetCurrent().Name;int helperExit=ElevatedHelper(helper,"-Mode Uninstall -PayloadDir \""+payload+"\" -AppRoot \""+AppRoot+"\" -UserId \""+user+"\"",90000);if(helperExit!=0)throw new InvalidOperationException("Protected sensor removal failed. Exit code: "+helperExit);
        try{File.Delete(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),Product+".lnk"));}catch{}try{File.Delete(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),Product+".lnk"));}catch{}
        using(RegistryKey run=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))run.DeleteValue("TaskbarMonitorEnhanced",false);Registry.CurrentUser.DeleteSubKeyTree(UninstallKey,false);
        string cleanup=Path.Combine(Path.GetTempPath(),"tbme_cleanup_"+Guid.NewGuid().ToString("N")+".cmd");File.WriteAllText(cleanup,"@echo off\r\nping 127.0.0.1 -n 4 >nul\r\nrmdir /s /q \""+AppRoot+"\"\r\ndel /q \"%~f0\"\r\n",Encoding.ASCII);ProcessStartInfo psi=new ProcessStartInfo("cmd.exe","/c \""+cleanup+"\"");psi.UseShellExecute=false;psi.CreateNoWindow=true;Process.Start(psi);if(!quiet)MessageBox.Show(Product+" was removed.","Uninstall complete",MessageBoxButtons.OK,MessageBoxIcon.Information);
    }
    static int Verify(string path)
    {
        try{foreach(string resourceName in RequiredResources){using(Stream s=Resource(resourceName)){if(s==null || s.Length==0)return 20;}}if(!String.IsNullOrEmpty(path)){string json="{\"Status\":\"PASS\",\"Resources\":"+RequiredResources.Length+",\"Version\":\"1.0.0\",\"Publisher\":\"Dr. Ali-Akbar Emadeddin\"}";File.WriteAllText(path,json,Encoding.UTF8);}return 0;}catch{return 21;}
    }
    static string Value(string[] args,string prefix){foreach(string arg in args)if(arg.StartsWith(prefix,StringComparison.OrdinalIgnoreCase))return arg.Substring(prefix.Length);return "";}
    static bool Has(string[] args,string value){foreach(string arg in args)if(String.Equals(arg,value,StringComparison.OrdinalIgnoreCase))return true;return false;}
    sealed class SetupForm:Form
    {
        CheckBox desktop,startup;Button install;ProgressBar progress;Label status;
        public SetupForm()
        {
            Text=Product+" Setup";Width=610;Height=435;StartPosition=FormStartPosition.CenterScreen;FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            Label title=new Label();title.Text=Product+"  1.0.0";title.Font=new Font(Font.FontFamily,18,FontStyle.Bold);title.Left=28;title.Top=22;title.AutoSize=true;Controls.Add(title);
            Label author=new Label();author.Text="Lead Developer & Maintainer: Dr. Ali-Akbar Emadeddin\r\nGPL-3.0 • AI-assisted development transparently documented";author.Left=31;author.Top=67;author.AutoSize=true;Controls.Add(author);
            TextBox info=new TextBox();info.Left=30;info.Top=116;info.Width=530;info.Height=140;info.Multiline=true;info.ReadOnly=true;info.ScrollBars=ScrollBars.Vertical;info.Text="Live CPU, RAM, disk, GPU, VRAM, network and temperature telemetry integrated into the Windows taskbar.\r\n\r\nThe main application runs without elevation. Windows requests administrator approval only for the protected hardware-sensor service.\r\n\r\nSource code, GPL license, upstream attribution and third-party notices are installed with the application.";Controls.Add(info);
            desktop=new CheckBox();desktop.Text="Create Desktop shortcut";desktop.Checked=true;desktop.Left=35;desktop.Top=276;desktop.AutoSize=true;Controls.Add(desktop);startup=new CheckBox();startup.Text="Start with Windows";startup.Checked=true;startup.Left=35;startup.Top=304;startup.AutoSize=true;Controls.Add(startup);progress=new ProgressBar();progress.Left=35;progress.Top=337;progress.Width=370;progress.Height=18;progress.Style=ProgressBarStyle.Marquee;progress.Visible=false;Controls.Add(progress);status=new Label();status.Left=35;status.Top=362;status.Width=390;status.Text="Ready";Controls.Add(status);
            install=new Button();install.Text="Install";install.Left=460;install.Top=326;install.Width=100;install.Height=38;install.Click+=delegate{install.Enabled=false;desktop.Enabled=false;startup.Enabled=false;progress.Visible=true;status.Text="Installing… Windows may request administrator approval for CPU sensors.";Application.DoEvents();try{Install(desktop.Checked,startup.Checked);status.Text="Installation completed.";MessageBox.Show(Product+" 1.0.0 was installed successfully.","Setup complete",MessageBoxButtons.OK,MessageBoxIcon.Information);Close();}catch(Exception ex){progress.Visible=false;install.Enabled=true;desktop.Enabled=true;startup.Enabled=true;status.Text="Installation failed.";MessageBox.Show(ex.Message,"Setup failed",MessageBoxButtons.OK,MessageBoxIcon.Error);}};Controls.Add(install);
        }
    }
    [STAThread] static int Main(string[] args)
    {
        if(Has(args,"/verify"))return Verify(Value(args,"/verifyfile="));bool quiet=Has(args,"/quiet");if(Has(args,"/install")){try{bool desktop=!String.Equals(Value(args,"/desktop="),"0",StringComparison.OrdinalIgnoreCase);bool startup=!String.Equals(Value(args,"/startup="),"0",StringComparison.OrdinalIgnoreCase);Install(desktop,startup);return 0;}catch(Exception ex){if(!quiet)MessageBox.Show(ex.Message,"Setup failed",MessageBoxButtons.OK,MessageBoxIcon.Error);return 30;}}if(Has(args,"/uninstall")){try{Uninstall(quiet);return 0;}catch(Exception ex){if(!quiet)MessageBox.Show(ex.Message,"Uninstall failed",MessageBoxButtons.OK,MessageBoxIcon.Error);return 31;}}Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new SetupForm());return 0;
    }
}
