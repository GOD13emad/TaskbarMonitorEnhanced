[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('baseline','candidate')][string]$Variant,
 [Parameter(Mandatory=$true)][string]$SourceRoot,
 [ValidateSet('LOCAL','A','B')][string]$HostLabel='LOCAL',
 [switch]$HostedGuest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R370_NEEDS_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
 $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows')){
 throw 'R370_REFUSE_UNTRUSTED_HOSTED_IDENTITY'
}
$source=(Resolve-Path -LiteralPath $SourceRoot).Path
$path=Join-Path $source 'installer\TaskbarMonitorEnhanced_Setup.cs'
if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw 'R370_SETUP_SOURCE_MISSING'}
$base='a8fadee40ade2fb871c5d4d1adce7776576270de'
if($Variant -eq 'baseline'){
 $lines=@(git -C $source show ($base+':installer/TaskbarMonitorEnhanced_Setup.cs') 2>&1)
 if($LASTEXITCODE -ne 0){throw 'R370_PINNED_BASELINE_GIT_SHOW_FAILED'}
 $src=($lines -join [Environment]::NewLine)
 if(!$src.Contains('File.WriteAllText(tmp,UpgradeStageMarker+"|"+phase,Encoding.ASCII)')){
  throw 'R370_EXACT_VULNERABLE_SOURCE_MISSING'
 }
 $sourceCommit=$base
}else{
 $src=[IO.File]::ReadAllText($path)
 if(!$src.Contains('new FileStream(tmp,FileMode.CreateNew,FileAccess.Write,FileShare.None)') -or
    !$src.Contains('new StreamWriter(stream,Encoding.ASCII)')){
  throw 'R370_CANDIDATE_EXCLUSIVE_TEMP_GUARD_MISSING'
 }
 $sourceCommit=(git -C $source rev-parse HEAD).Trim()
}
$match=[regex]::Match($src,'(?s)    static void WritePhase\(string phase\)\r?\n    \{.*?\r?\n    \}\r?\n\s*static string GetPhase\(\)')
if(!$match.Success -or ([regex]::Matches($src,'static void WritePhase\(string phase\)')).Count -ne 1){
 throw 'R370_SOURCE_EXTRACT_NOT_UNIQUE'
}
$method=$match.Value.Substring(0,$match.Value.IndexOf('    static string GetPhase()'))
# This fixture compiles the exact extracted production method, substituting only its
# root accessor. Never load/call SetupProgram.WritePhase against an owner installation.
$fixture=@'
using System;
using System.IO;
using System.Text;
public static class R370Fixture {
 public static string Root;
 const string UpgradeStageMarker="TBME_UPGRADE_R92_OWNED_STAGE_V1";
 static string UpgradeRoot {get{return Root;}}
 public static void Run(string phase){WritePhase(phase);}
'@+[Environment]::NewLine+$method+[Environment]::NewLine+'}'
Add-Type -TypeDefinition $fixture -ErrorAction Stop
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class R370Hardlink {
 [DllImport("kernel32.dll",EntryPoint="CreateHardLinkW",CharSet=CharSet.Unicode,SetLastError=true)]
 [return:MarshalAs(UnmanagedType.Bool)]
 public static extern bool Link(string name,string existing,IntPtr data);
}
'@ -ErrorAction Stop
function Link([string]$name,[string]$target){
 if(![R370Hardlink]::Link($name,$target,[IntPtr]::Zero)){
  throw ('R370_HARDLINK_CREATE_FAILED_'+[Runtime.InteropServices.Marshal]::GetLastWin32Error())
 }
}
function Sha([string]$f){(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash}
$checks=[Collections.Generic.List[string]]::new()
function Pass([string]$name){$checks.Add($name);Write-Output ('R370_PASS '+$name)}
$root=Join-Path $env:TEMP ('tbme-r370-phase-'+[Guid]::NewGuid().ToString('N'))
if(Test-Path -LiteralPath $root){throw 'R370_FIXTURE_ALREADY_EXISTS'}
[void][IO.Directory]::CreateDirectory($root)
$canary=Join-Path $root 'outside-canary.txt'
$stage=Join-Path $root 'stage'
[void][IO.Directory]::CreateDirectory($stage)
[IO.File]::WriteAllText($canary,'R370_OUTSIDE_CANARY_UNCHANGED')
$original=Sha $canary
$expected='TBME_UPGRADE_R92_OWNED_STAGE_V1|'
$alias=Join-Path $stage 'phase.tmp'
$state=Join-Path $stage 'phase.txt'
try{
 Link $alias $canary
 [R370Fixture]::Root=$stage
 $refused=$false
 try{[R370Fixture]::Run('PREPARED')}catch [System.IO.IOException]{$refused=$true}
 $after=Sha $canary
 if($Variant -eq 'baseline'){
  if($refused -or $after -ceq $original -or
     [IO.File]::ReadAllText($state,[Text.Encoding]::ASCII) -cne ($expected+'PREPARED')){
    throw 'R370_BASELINE_HARDLINK_ATTACK_NOT_REPRODUCED'
  }
  Pass 'BASELINE_FIXED_TEMP_HARDLINK_WRITE_THROUGH_REPRODUCED'
 }else{
  if(!$refused -or $after -cne $original -or
     !(Test-Path -LiteralPath $alias) -or (Test-Path -LiteralPath $state)){
    throw 'R370_CANDIDATE_PRECREATED_TEMP_ALIAS_NOT_REFUSED'
  }
  Pass 'CANDIDATE_PRECREATED_TEMP_ALIAS_FAILS_CLOSED_WITH_CANARY_UNCHANGED'
  Remove-Item -LiteralPath $alias -Force
  [R370Fixture]::Run('PREPARED')
  if([IO.File]::ReadAllText($state,[Text.Encoding]::ASCII) -cne ($expected+'PREPARED') -or
     (Test-Path -LiteralPath $alias)){throw 'R370_PREPARED_PHASE_COMMIT_FAILED'}
  [R370Fixture]::Run('COMMITTING')
  if([IO.File]::ReadAllText($state,[Text.Encoding]::ASCII) -cne ($expected+'COMMITTING') -or
     (Test-Path -LiteralPath $alias)){throw 'R370_COMMITTING_PHASE_REPLACE_FAILED'}
  [R370Fixture]::Run('COMMITTED')
  if([IO.File]::ReadAllText($state,[Text.Encoding]::ASCII) -cne ($expected+'COMMITTED') -or
     (Test-Path -LiteralPath $alias)){throw 'R370_COMMITTED_PHASE_REPLACE_FAILED'}
  Pass 'CANDIDATE_ALL_THREE_CRASH_JOURNAL_PHASES_REMAIN_ATOMIC_AND_CLEAN'
  $stage2=Join-Path $root 'stage2'
  [void][IO.Directory]::CreateDirectory($stage2)
  $destinationCanary=Join-Path $root 'destination-canary.txt'
  [IO.File]::WriteAllText($destinationCanary,'R370_DESTINATION_CANARY_UNCHANGED')
  $targetHash=Sha $destinationCanary
  Link (Join-Path $stage2 'phase.txt') $destinationCanary
  [R370Fixture]::Root=$stage2
  [R370Fixture]::Run('COMMITTED')
  if((Sha $destinationCanary) -cne $targetHash -or
     [IO.File]::ReadAllText((Join-Path $stage2 'phase.txt'),[Text.Encoding]::ASCII) -cne ($expected+'COMMITTED')){
   throw 'R370_DESTINATION_ALIAS_WRITE_THROUGH'
  }
  Pass 'CANDIDATE_DESTINATION_HARDLINK_REPLACED_CANARY_UNCHANGED'
 }
 $receiptRoot=if($HostedGuest){$env:RUNNER_TEMP}else{$env:TEMP}
 $dir=Join-Path $receiptRoot ('R370_'+$Variant+'_'+$HostLabel+'_'+[Guid]::NewGuid().ToString('N'))
 [void][IO.Directory]::CreateDirectory($dir)
 $result=[ordered]@{
  Revision='R370';Variant=$Variant;Host=$HostLabel;Method='Exact production WritePhase source extracted, compiled with substituted isolated root accessor'
  SourceCommit=$sourceCommit
  SourceSHA256=if($Variant -eq 'candidate'){Sha $path}else{'BASELINE_COMMIT_SOURCE_EXTRACT'}
  CanaryBeforeSHA256=$original;CanaryAfterSHA256=$after
  AliasWriteThrough=($after -cne $original)
  Checks=@($checks)
  Status=if($Variant -eq 'baseline'){'PASS_VULNERABLE_REPRODUCED'}else{'PASS_ALIAS_BLOCKED_AND_RECOVERY_PHASES'}
  ChangedOwnerInstall=$false;InvokedActualSetup=$false
  ClaimLimit='Same-user NTFS hardlinks against a fixed upgrade phase temporary path. Extracted exact source method, not a native installed Setup execution; no simultaneous directory-rename adversary.'
 }
 $receipt=Join-Path $dir 'R370_PHASE_HARDLINK.json'
 [IO.File]::WriteAllText($receipt,($result|ConvertTo-Json -Depth 9),[Text.UTF8Encoding]::new($false))
 $check=Get-Content $receipt -Raw|ConvertFrom-Json -ErrorAction Stop
 if($check.Revision -cne 'R370' -or $check.Checks.Count -lt 1){throw 'R370_TYPED_RECEIPT_INVALID'}
 Write-Output ('R370_RECEIPT='+$receipt)
 Write-Output ('R370_RESULT='+$result.Status+' CHECKS='+$checks.Count)
}finally{
 Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
