#requires -Version 5.1
<#
.SYNOPSIS
  R456 read-only Core Audio routing, endpoint and system-sound scheme diagnostic.
.DESCRIPTION
  Reports only matching TaskbarMonitorEnhanced and Windows system-sounds sessions
  on the default eConsole, eMultimedia and eCommunications render endpoints. Absence of a session
  is NOT proof of mute or successful physical playback. No polling, consent prompt,
  installer call, sound emission, or endpoint-volume setter is used.
#>
[CmdletBinding()]
param([switch]$SchemaSelfTest)

$ErrorActionPreference = 'Stop'
$ownerProcesses = @()
if (!$SchemaSelfTest) {
    $expected = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced/TaskbarMonitorEnhanced.exe'))
    $ownerProcesses = @(Get-CimInstance Win32_Process -Filter "Name='TaskbarMonitorEnhanced.exe'" |
        Where-Object { $_.ExecutablePath -and
            [string]::Equals([IO.Path]::GetFullPath($_.ExecutablePath), $expected,
                            [StringComparison]::OrdinalIgnoreCase) })
}
if (!$SchemaSelfTest -and $ownerProcesses.Count -ne 1) {
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
 [PreserveSig]int OpenPropertyStore(int access,out R456Properties properties);
 [PreserveSig]int GetId(out IntPtr id);
 [PreserveSig]int GetState(out int state);
}
[StructLayout(LayoutKind.Sequential)]
struct R456Key { public Guid fmtid; public uint pid; }
[StructLayout(LayoutKind.Explicit,Size=24)]
struct R456Variant {
 [FieldOffset(0)] public ushort vt;
 [FieldOffset(8)] public IntPtr ptr;
}
[ComImport,Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface R456Properties {
 [PreserveSig]int GetCount(out uint count);
 [PreserveSig]int GetAt(uint index,out R456Key key);
 [PreserveSig]int GetValue(ref R456Key key,out R456Variant value);
}
[ComImport,Guid("5CDF2C82-841E-4546-9722-0CF74078229A"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface R456EndpointVolume {
 [PreserveSig]int RegisterControlChangeNotify(IntPtr callback);
 [PreserveSig]int UnregisterControlChangeNotify(IntPtr callback);
 [PreserveSig]int GetChannelCount(out uint count);
 [PreserveSig]int SetMasterVolumeLevel(float level,IntPtr context);
 [PreserveSig]int SetMasterVolumeLevelScalar(float level,IntPtr context);
 [PreserveSig]int GetMasterVolumeLevel(out float level);
 [PreserveSig]int GetMasterVolumeLevelScalar(out float scalar);
 [PreserveSig]int SetChannelVolumeLevel(uint channel,float level,IntPtr context);
 [PreserveSig]int SetChannelVolumeLevelScalar(uint channel,float level,IntPtr context);
 [PreserveSig]int GetChannelVolumeLevel(uint channel,out float level);
 [PreserveSig]int GetChannelVolumeLevelScalar(uint channel,out float scalar);
 [PreserveSig]int SetMute([MarshalAs(UnmanagedType.Bool)]bool muted,IntPtr context);
 [PreserveSig]int GetMute([MarshalAs(UnmanagedType.Bool)]out bool muted);
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
 [DllImport("ole32.dll")] static extern int PropVariantClear(ref R456Variant value);
 private static string ReadEndpoint(R452Device device) {
   R456Properties store=null;
   object volume=null;
   string friendly="UNKNOWN", master="UNKNOWN";
   try {
     int state=-1;
     int stateHr=device.GetState(out state);
     int hr=device.OpenPropertyStore(0,out store); // STGM_READ: no write access
     if(hr>=0 && store!=null) {
       R456Key key=new R456Key{fmtid=new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"),pid=14};
       R456Variant value;
       hr=store.GetValue(ref key,out value);
       if(hr>=0) {
         try { if(value.vt==31 && value.ptr!=IntPtr.Zero)
                 friendly=Marshal.PtrToStringUni(value.ptr); }
         finally { PropVariantClear(ref value); }
       }
     }
     Guid endpointVolumeIID=new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
     device.Activate(ref endpointVolumeIID,23,IntPtr.Zero,out volume);
     float scalar=-1;bool mute=true;
     int scalarHr=((R456EndpointVolume)volume).GetMasterVolumeLevelScalar(out scalar);
     int muteHr=((R456EndpointVolume)volume).GetMute(out mute);
     master=scalarHr==0&&muteHr==0
        ? scalar.ToString("0.000",System.Globalization.CultureInfo.InvariantCulture)+",MUTED="+mute
        : "VOLUME_HR_0x"+scalarHr.ToString("X8")+"_MUTE_HR_0x"+muteHr.ToString("X8");
     return "ENDPOINT_NAME="+friendly+" ENDPOINT_STATE="+(stateHr==0?state.ToString():"UNAVAILABLE")+" ENDPOINT_MASTER="+master;
   }catch(Exception e) {
     return "ENDPOINT_NAME="+friendly+" ENDPOINT_READ_NOT_VERIFIED="+e.GetType().Name+
            "_0x"+e.HResult.ToString("X8");
   }finally {
     if(volume!=null&&Marshal.IsComObject(volume))Marshal.ReleaseComObject(volume);
     if(store!=null&&Marshal.IsComObject(store))Marshal.ReleaseComObject(store);
   }
 }
 public static string Inspect(int ownerProcessId,int role) {
  object enumerator=null,manager=null;
  R452Device device=null;
  R452Sessions sessions=null;
  try {
    enumerator=Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")));
    ((R452DeviceEnumerator)enumerator).GetDefaultAudioEndpoint(0,role,out device);
    string endpoint=ReadEndpoint(device);
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
    return "ROLE="+role+" "+endpoint+" ENUMERATED="+count+
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
if ($SchemaSelfTest) {
    # Hosted-runner, compile-only ABI regression. Do not inspect a real user
    # process, registry, endpoint or generate audio on this execution path.
    if (![R452WindowsAudioReadOnly].GetMethod('Inspect')) {
        throw 'R456_COM_INTERFACE_INSPECT_METHOD_NOT_COMPILED'
    }
    Write-Output 'R456_WINDOWS_AUDIO_COM_SCHEMA_COMPILE=PASS_NO_OWNER_NO_AUDIO'
    exit 0
}
Write-Output 'R452_AUDIO_DIAGNOSTIC_SCOPE=READ_ONLY_NO_PLAYBACK_NO_GLOBAL_INPUT'
if ([IntPtr]::Size -ne 8) { throw 'R456_REQUIRES_64BIT_WINDOWS_TARGET' }
foreach ($role in @(0,1,2)) {
    [R452WindowsAudioReadOnly]::Inspect([int]$ownerProcesses[0].ProcessId, $role)
}
# Microsoft SystemSounds.Exclamation is the current user's SystemExclamation
# program event. Confirm only configuration and RIFF/WAVE header; do not play.
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
    'AppEvents\Schemes\Apps\.Default\SystemExclamation\.Current', $false)
if ($null -eq $key) {
    Write-Output 'R456_SYSTEM_EXCLAMATION_SCHEME=NOT_CONFIGURED'
} else {
    try {
        $raw = [string]$key.GetValue('', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $wave = [Environment]::ExpandEnvironmentVariables($raw)
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Write-Output 'R456_SYSTEM_EXCLAMATION_SCHEME=UNASSIGNED'
        } elseif (![IO.File]::Exists($wave)) {
            Write-Output 'R456_SYSTEM_EXCLAMATION_SCHEME=FILE_MISSING'
        } else {
            $stream = [IO.File]::Open($wave,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
            try {
                $header = New-Object byte[] 12
                $n = $stream.Read($header,0,$header.Length)
                $riffWave = $n -eq 12 -and
                    [Text.Encoding]::ASCII.GetString($header,0,4) -ceq 'RIFF' -and
                    [Text.Encoding]::ASCII.GetString($header,8,4) -ceq 'WAVE'
                Write-Output ('R456_SYSTEM_EXCLAMATION_SCHEME=FILE_EXISTS RIFF_WAVE='+$riffWave+
                    ' LENGTH='+$stream.Length)
            } finally { $stream.Dispose() }
        }
    } finally { $key.Dispose() }
}
Write-Output 'R452_AUDIO_DIAGNOSTIC_SNAPSHOT_COMPLETE=PASS_READ_ONLY'
Write-Output 'R456_ENDPOINT_AND_SYSTEM_SOUND_SCHEME_INSPECTION=PASS_READ_ONLY'
