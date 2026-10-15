[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Receipt,
    [switch]$SelfTest,
    [ValidateRange(1,240)][int]$MaxSeconds=210,
    [ValidateRange(1,30)][int]$IntervalSeconds=8
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(!$SelfTest) {
    if($PSVersionTable.PSEdition -cne 'Desktop' -or $env:GITHUB_ACTIONS -cne 'true' -or
       $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows' -or
       $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
       $env:GITHUB_REF -cne 'refs/heads/audit/r209-original-harness-wct' -or
       $env:COMPUTERNAME -match 'EMAD|ALI|PERSONAL' -or ![Environment]::UserInteractive) {
       throw 'R209_REFUSE_NON_DISPOSABLE_OWNER_OR_UNAPPROVED_BRANCH'
    }
}
if([IntPtr]::Size -ne 8 -or $env:OS -cne 'Windows_NT'){
    throw 'R209_REQUIRES_WINDOWS_X64'
}
if(Test-Path -LiteralPath $Receipt){throw 'R209_NO_OVERWRITE_OLD_DIAGNOSTIC_RECEIPT'}
$parent=Split-Path $Receipt -Parent
if(!(Test-Path $parent -PathType Container)){throw 'R209_OUTPUT_PARENT_MUST_EXIST'}
# The native schema mirrors Microsoft's WAITCHAIN_NODE_INFO:
# 8-byte type/status and 272-byte union; WCT_OBJNAME_LENGTH=128.
# Marshals raw union bytes, avoiding overlapping CLR object references.
$native=@'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
public static class TBME_WCT_R209 {
    [StructLayout(LayoutKind.Sequential)]
    public struct Node {
        public int ObjectType;
        public int ObjectStatus;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=272)]
        public byte[] Data;
    }
    public sealed class Row {
        public int Type { get; set; }
        public int Status { get; set; }
        public uint OwnerPid { get; set; }
        public uint OwnerTid { get; set; }
        public uint WaitTimeMs { get; set; }
        public string ObjectName { get; set; }
    }
    public sealed class Result {
        public bool Successful { get; set; }
        public int NativeError { get; set; }
        public bool Cycle { get; set; }
        public Row[] Nodes { get; set; }
    }
    [DllImport("advapi32.dll",SetLastError=true,ExactSpelling=true)]
    static extern IntPtr OpenThreadWaitChainSession(uint flags, IntPtr callback);
    [DllImport("advapi32.dll",SetLastError=true,ExactSpelling=true)]
    static extern void CloseThreadWaitChainSession(IntPtr h);
    [DllImport("advapi32.dll",SetLastError=true,ExactSpelling=true)]
    [return:MarshalAs(UnmanagedType.Bool)]
    static extern bool GetThreadWaitChain(
        IntPtr h, IntPtr context, uint flags, uint threadId,
        ref uint nodeCount, [Out] Node[] nodeInfo,
        [MarshalAs(UnmanagedType.Bool)] out bool isCycle);
    public static int NativeSize { get { return Marshal.SizeOf(typeof(Node)); } }
    public static Result Query(int threadId) {
        var ret=new Result { Successful=false,NativeError=0,Cycle=false,Nodes=new Row[0] };
        IntPtr h=OpenThreadWaitChainSession(0,IntPtr.Zero);
        if(h==IntPtr.Zero){ret.NativeError=Marshal.GetLastWin32Error();return ret;}
        try {
            var nodes=new Node[16];uint count=16;bool cycle=false;
            bool ok=GetThreadWaitChain(h,IntPtr.Zero,0,(uint)threadId,ref count,nodes,out cycle);
            ret.Successful=ok;
            ret.Cycle=cycle;
            if(!ok){ret.NativeError=Marshal.GetLastWin32Error();return ret;}
            var list=new List<Row>();
            for(int i=0;i<(int)Math.Min(count,(uint)nodes.Length);i++){
                var n=nodes[i];
                var row=new Row{Type=n.ObjectType, Status=n.ObjectStatus,OwnerPid=0,
                                OwnerTid=0,WaitTimeMs=0,ObjectName=""};
                if(n.Data!=null){
                    if(n.ObjectType==8) {
                        row.OwnerPid=BitConverter.ToUInt32(n.Data,0);
                        row.OwnerTid=BitConverter.ToUInt32(n.Data,4);
                        row.WaitTimeMs=BitConverter.ToUInt32(n.Data,8);
                    } else {
                        string name=Encoding.Unicode.GetString(n.Data,0,256);
                        int stop=name.IndexOf('\0');
                        if(stop>=0)name=name.Substring(0,stop);
                        if(name.Length>96)name=name.Substring(0,96);
                        // No private filesystem paths or arbitrary names in transferable output.
                        if(name.StartsWith("Local\\TaskbarMonitorEnhanced",StringComparison.OrdinalIgnoreCase)
                            || name.StartsWith("Global\\TaskbarMonitorEnhanced",StringComparison.OrdinalIgnoreCase)) {
                            row.ObjectName=name;
                        }
                    }
                }
                list.Add(row);
            }
            ret.Nodes=list.ToArray();
            return ret;
        } finally {CloseThreadWaitChainSession(h);}
    }
}
'@
Add-Type -TypeDefinition $native -Language CSharp -ErrorAction Stop
if([TBME_WCT_R209]::NativeSize -ne 280){throw 'R209_WCT_NATIVE_STRUCT_SIZE_DRIFT'}
function ReadThread([Diagnostics.ProcessThread]$thread) {
    $s=[ordered]@{
      ThreadId=[int]$thread.Id
      State='UNKNOWN'
      WaitReason='NOT_APPLICABLE'
      CpuSeconds=$null
      WctResult='NOT_QUERIED'
    }
    try{
        $state=$thread.ThreadState.ToString()
        $s.State=$state
        if($state -eq 'Wait'){$s.WaitReason=$thread.WaitReason.ToString()}
        $s.CpuSeconds=[math]::Round($thread.TotalProcessorTime.TotalSeconds,4)
    }catch{$s.State='PARTIAL_ERROR_'+$_.Exception.GetType().Name}
    try {
        $w=[TBME_WCT_R209]::Query([int]$thread.Id)
        $s.WctResult=[ordered]@{Successful=$w.Successful;NativeError=$w.NativeError;Cycle=$w.Cycle;Nodes=@($w.Nodes)}
    }catch{$s.WctResult='WCT_ERROR_'+$_.Exception.GetType().Name}
    return $s
}
function WriteReceipt($row) {
    $raw=$row|ConvertTo-Json -Depth 14
    [IO.File]::WriteAllText($Receipt,$raw,[Text.UTF8Encoding]::new($false))
}
if($SelfTest){
    if($MaxSeconds -gt 10){throw 'R209_SELFTEST_MUST_BE_AT_MOST_10_SECONDS'}
    $me=[Diagnostics.Process]::GetCurrentProcess()
    $one=@($me.Threads | Select-Object -First 3 | ForEach-Object {ReadThread $_})
    $ok=[ordered]@{
      Revision='R209';Status='PASS_PARSER_NATIVE_STRUCT_AND_OWN_PROCESS_QUERY'
      NativeSize=[TBME_WCT_R209]::NativeSize;SelfTest=$true
      PersonalProductProbed=$false;SystemPoliciesChanged=$false
      Samples=@($one);UTCTime=[DateTime]::UtcNow.ToString('o')
    }
    WriteReceipt $ok
    Write-Output ($ok | ConvertTo-Json -Depth 12 -Compress)
    exit 0
}
$started=[DateTime]::UtcNow
$watch=[Diagnostics.Stopwatch]::StartNew()
$records=New-Object 'System.Collections.Generic.List[object]'
while($watch.Elapsed.TotalSeconds -lt $MaxSeconds){
    $matching=@(Get-Process -Name 'TaskbarMonitorEnhanced_Setup_1.7.1' -ErrorAction SilentlyContinue)
    $snap=[ordered]@{ElapsedMs=[int]$watch.ElapsedMilliseconds
       ObservedProcesses=$matching.Count;PID=$null;TotalCpuSeconds=$null
       Threads=@();AppRootExists=[bool](Test-Path (Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'))
       ErrorClass=''}
    if($matching.Count -gt 1){$snap.ErrorClass='MULTIPLE_SETUP_PROCESSES_UNRESOLVED'}
    if($matching.Count -eq 1){
        $p=$matching[0]
        try {
            $p.Refresh()
            if(!$p.HasExited){
                $snap.PID=[int]$p.Id
                $snap.TotalCpuSeconds=[math]::Round($p.TotalProcessorTime.TotalSeconds,4)
                $snap.Threads=@($p.Threads | Select-Object -First 24 | ForEach-Object { ReadThread $_ })
            }
        }catch{$snap.ErrorClass=$_.Exception.GetType().Name}
    }
    $records.Add($snap)
    $record=[ordered]@{
      Revision='R209';Objective='WCT and thread-state evidence on the identical frozen original CPU harness'
      Status='OBSERVATION_CAPTURED_NOT_CAUSAL_ACCEPTANCE'
      GitCommit=$env:GITHUB_SHA;StartedUTC=$started.ToString('o')
      NativeWctNodeSize=[TBME_WCT_R209]::NativeSize
      SamplingCount=$records.Count;Samples=@($records.ToArray())
      OwnerComputerTouched=$false;ProductOrDriverModified=$false
      WctIsOnlySupportedWaitCategories=$true;UpdatedUTC=[DateTime]::UtcNow.ToString('o')
    }
    WriteReceipt $record
    if($matching.Count -gt 1){throw 'R209_MULTIPLE_INSTALLER_PROCESSES'}
    Start-Sleep -Seconds $IntervalSeconds
}
