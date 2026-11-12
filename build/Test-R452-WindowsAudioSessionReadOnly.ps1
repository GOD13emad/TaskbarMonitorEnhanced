#requires -Version 5.1
<#
.SYNOPSIS
  R452 read-only Core Audio routing diagnostic; no audio playback or settings mutation.
.DESCRIPTION
  Reports only matching TaskbarMonitorEnhanced and Windows system-sounds sessions
  on the default eConsole and eMultimedia render endpoints. Absence of a session
  is NOT proof of mute or successful physical playback. No polling, consent prompt,
  installer call, sound emission, or endpoint-volume setter is used.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$expected = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced/TaskbarMonitorEnhanced.exe'))
$ownerProcesses = @(Get-CimInstance Win32_Process -Filter "Name='TaskbarMonitorEnhanced.exe'" |
    Where-Object { $_.ExecutablePath -and
        [string]::Equals([IO.Path]::GetFullPath($_.ExecutablePath), $expected,
                        [StringComparison]::OrdinalIgnoreCase) })
if ($ownerProcesses.Count -ne 1) {
    Write-Output 'R452_OWNER_AUDIO_PROCESS=NOT_SINGLE_RUNNING_OWNER_INSTALL'
    exit 3
}

$cs = @'
using System;
using System.Runtime.InteropServices;
[ComImport,Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface R452DeviceEnumerator {
 void EnumAudioEndpoints(int flow,int mask,out IntPtr collection);
 void GetDefaultAudioEndpoint(int flow,int role,out R452Device device);
 void GetDevice([MarshalAs(UnmanagedType.LPWStr)]string id,out R452Device device);
 void RegisterEndpointNotificationCallback(IntPtr cb);
 void UnregisterEndpointNotificationCallback(IntPtr cb);
}
[ComImport,Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface R452Device {
 void Activate(ref Guid iid,int context,IntPtr parameters,[MarshalAs(UnmanagedType.IUnknown)]out object instance);
}
[ComImport,Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface R452Manager {
 [PreserveSig]int GetAudioSessionControl(IntPtr id,int flags,out IntPtr control);
 [PreserveSig]int GetSimpleAudioVolume(IntPtr id,int flags,out IntPtr volume);
 [PreserveSig]int GetSessionEnumerator(out R452Sessions sessions);
 [PreserveSig]int RegisterSessionNotification(IntPtr callback);
 [PreserveSig]int UnregisterSessionNotification(IntPtr callback);
 [PreserveSig]int RegisterDuckNotification(IntPtr sid,IntPtr callback);
 [PreserveSig]int UnregisterDuckNotification(IntPtr callback);
}
[ComImport,Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface R452Sessions {
 [PreserveSig]int GetCount(out int count);
 [PreserveSig]int GetSession(int index,out R452Control control);
}
[ComImport,Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface R452Control {
 [PreserveSig]int GetState(out int state);
 [PreserveSig]int GetDisplayName(out IntPtr name);
 [PreserveSig]int SetDisplayName(IntPtr name,IntPtr context);
 [PreserveSig]int GetIconPath(out IntPtr path);
 [PreserveSig]int SetIconPath(IntPtr path,IntPtr context);
 [PreserveSig]int GetGroupingParam(out Guid param);
 [PreserveSig]int SetGroupingParam(IntPtr param,IntPtr context);
 [PreserveSig]int RegisterAudioSessionNotification(IntPtr cb);
 [PreserveSig]int UnregisterAudioSessionNotification(IntPtr cb);
 [PreserveSig]int GetSessionIdentifier(out IntPtr identifier);
 [PreserveSig]int GetSessionInstanceIdentifier(out IntPtr identifier);
 [PreserveSig]int GetProcessId(out int pid);
 [PreserveSig]int IsSystemSoundsSession();
 [PreserveSig]int SetDuckingPreference([MarshalAs(UnmanagedType.Bool)]bool optOut);
}
[ComImport,Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface R452Volume {
 [PreserveSig]int SetMasterVolume(float level,IntPtr context);
 [PreserveSig]int GetMasterVolume(out float level);
 [PreserveSig]int SetMute([MarshalAs(UnmanagedType.Bool)]bool muted,IntPtr context);
 [PreserveSig]int GetMute([MarshalAs(UnmanagedType.Bool)]out bool muted);
}
public static class R452WindowsAudioReadOnly {
 public static string Inspect(int ownerProcessId,int role) {
  object enumerator=null,manager=null;
  R452Device device=null;
  R452Sessions sessions=null;
  try {
    enumerator=Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")));
    ((R452DeviceEnumerator)enumerator).GetDefaultAudioEndpoint(0,role,out device);
    Guid iid=new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
    device.Activate(ref iid,23,IntPtr.Zero,out manager);
    int hr=((R452Manager)manager).GetSessionEnumerator(out sessions);
    if(hr<0)return "ROLE="+role+" SESSION_ENUM_HRESULT=0x"+hr.ToString("X8");
    int count=0;hr=sessions.GetCount(out count);
    if(hr<0)return "ROLE="+role+" SESSION_COUNT_HRESULT=0x"+hr.ToString("X8");
    int ownerMatches=0, systemMatches=0;
    string ownerStatus="NOT_PRESENT_AT_SAMPLING_TIME",systemStatus="NOT_PRESENT_AT_SAMPLING_TIME";
    for(int i=0;i<Math.Min(256,count);++i) {
      R452Control session=null;
      try {
        if(sessions.GetSession(i,out session)<0 || session==null)continue;
        int pid=0;
        int pidHr=session.GetProcessId(out pid);
        int sysHr=session.IsSystemSoundsSession();
        bool system=sysHr==0;
        bool owner=pidHr>=0 && pid==ownerProcessId;
        if(!owner && !system)continue;
        int state=-1;
        session.GetState(out state);
        string sessionVolume="UNKNOWN";
        try {
          R452Volume volume=(R452Volume)session;
          float scalar=-1;bool mute=false;
          int volumeHr=volume.GetMasterVolume(out scalar);
          int muteHr=volume.GetMute(out mute);
          if(volumeHr>=0 && muteHr>=0)
            sessionVolume=scalar.ToString("0.000",System.Globalization.CultureInfo.InvariantCulture)+
                          ",MUTED="+mute;
          else sessionVolume="HR_0x"+volumeHr.ToString("X8")+"/0x"+muteHr.ToString("X8");
        }catch(InvalidCastException) {
          sessionVolume="INTERFACE_NOT_AVAILABLE";
        }
        string info="STATE="+state+" VOL="+sessionVolume;
        if(owner){++ownerMatches;ownerStatus=info;}
        if(system){++systemMatches;systemStatus=info;}
      }finally {
        if(session!=null && Marshal.IsComObject(session))Marshal.ReleaseComObject(session);
      }
    }
    return "ROLE="+role+" ENUMERATED="+count+
      " OWNER_MATCHES="+ownerMatches+" OWNER="+ownerStatus+
      " SYSTEM_SOUNDS_MATCHES="+systemMatches+" SYSTEM_SOUNDS="+systemStatus;
  }catch(Exception e) {
    return "ROLE="+role+" NOT_VERIFIED="+e.GetType().Name+
           " HRESULT=0x"+e.HResult.ToString("X8");
  }finally {
    if(sessions!=null && Marshal.IsComObject(sessions))Marshal.ReleaseComObject(sessions);
    if(manager!=null && Marshal.IsComObject(manager))Marshal.ReleaseComObject(manager);
    if(device!=null && Marshal.IsComObject(device))Marshal.ReleaseComObject(device);
    if(enumerator!=null && Marshal.IsComObject(enumerator))Marshal.ReleaseComObject(enumerator);
  }
 }
}
'@
Add-Type -TypeDefinition $cs -Language CSharp -ErrorAction Stop
Write-Output 'R452_AUDIO_DIAGNOSTIC_SCOPE=READ_ONLY_NO_PLAYBACK_NO_GLOBAL_INPUT'
foreach ($role in @(0,1)) {
    [R452WindowsAudioReadOnly]::Inspect([int]$ownerProcesses[0].ProcessId, $role)
}
Write-Output 'R452_AUDIO_DIAGNOSTIC_SNAPSHOT_COMPLETE=PASS_READ_ONLY'
