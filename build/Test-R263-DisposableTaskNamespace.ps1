[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet("A","B")][string]$HostLabel)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
# Never execute on a real user's device. Synthetic Windows Task Scheduler
# duplicate-name experiment ONLY on fresh GitHub-hosted disposable Windows.
# Does not run the actual sensor helper or install PawnIO or drivers.
if($env:GITHUB_ACTIONS -cne "true" -or
   $env:RUNNER_ENVIRONMENT -cne "github-hosted" -or
   $env:RUNNER_OS -cne "Windows" -or
   $env:GITHUB_REPOSITORY -cne "GOD13emad/TaskbarMonitorEnhanced" -or
   $env:GITHUB_REF -cne "refs/heads/audit/r263-disposable-task-namespace" -or
   $env:COMPUTERNAME -match "(?i)EMAD|ALI|LAPTOP"){
 throw "R263_REFUSE_NON_DISPOSABLE_GITHUB_WINDOWS"
}
$me=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=[Security.Principal.WindowsPrincipal]::new($me)
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 throw "R263_REQUIRE_EXISTING_ADMIN_ON_DISPOSABLE_GITHUB_HOST"
}
$repoRoot=Join-Path $PSScriptRoot ".."
$helper=Join-Path $repoRoot "installer/TBME_Setup_Elevated_Helper.ps1"
$source=Get-Content -LiteralPath $helper -Raw -ErrorAction Stop
if(-not $source.Contains('$TaskName=''TaskbarMonitorEnhanced Sensor Broker''') -or
    -not $source.Contains('Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force') -or
    -not $source.Contains('Stop-Process -Force -ErrorAction SilentlyContinue') -or
    -not $source.Contains('''TaskbarMonitorEnhanced\SensorBroker''')){
 throw "R263_OFFICIAL_HELPER_SOURCE_ANCHOR_NOT_PROVEN"
}
# Evaluate the above string literals WITHOUT variable interpolation using single quotes.
$username="TBME263"+$HostLabel
$task="R263_TEST_ONLY_NoTrigger_OwnerCollision_"+$HostLabel
$out=Join-Path $env:RUNNER_TEMP ("TBME_R263_"+$HostLabel)
$receipt=Join-Path $out "R263_TASK_NAMESPACE.json"
$created=$false;$taskOwned=$false
$testSid="";$firstSid=[string]$me.User.Value
$firstPrincipal="";$secondPrincipal=""
$marker="R263 owned no-trigger task test; never executable by automation"
$status="FAIL_NOT_ACCEPTED";$phase="READONLY_PRECONDITIONS";$reason=""
$replaced=$false;$cleanupVerified=$false;$accountRemoved=$false;$triggersZero=$false
function Fail([string]$message){throw ("R263_"+$message)}
function OwnedTask {
 $found=Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
 if($null -eq $found){return $false}
 # The same exact task name should never be used outside this disposable
 # dedicated GitHub VM. Refuse to remove tasks of a different description.
 $xml=[xml](Export-ScheduledTask -TaskName $task -ErrorAction Stop)
 if([string]$xml.Task.RegistrationInfo.Description -cne $marker){
   Fail "TASK_DESCRIPTION_OR_OWNER_CHANGED_PREVENT_CLEANUP"
 }
 if(@($found.Triggers|Where-Object {$_ -ne $null}).Count -ne 0){
   Fail "OWNED_TASK_TRIGGER_ADDED_STOP_CLEANUP"
 }
 return $true
}
if((Test-Path $out) -or (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) -or
   (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)){
 Fail "TEST_OWNED_ACCOUNT_OR_TASK_ALREADY_EXISTS"
}
New-Item -ItemType Directory -Path $out -ErrorAction Stop|Out-Null
try{
 $phase="CREATE_DISPOSABLE_TEST_ACCOUNT"
 $bytes=[byte[]]::new(32)
 $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
 try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
 $secure=ConvertTo-SecureString -String ([Convert]::ToBase64String($bytes)+"A8!") -AsPlainText -Force
 $account=New-LocalUser -Name $username -Password $secure -AccountNeverExpires -PasswordNeverExpires -Description "R263 disposable task namespace test" -ErrorAction Stop
 $created=$true
 $testSid=[string]$account.SID.Value
 if($testSid -notmatch '^S-1-5-21-' -or $testSid -ceq $firstSid){
   Fail "TEST_USER_IDENTITY_NOT_INDEPENDENT"
 }
 $phase="REGISTER_FIRST_ACCOUNT_TASK_WITHOUT_TRIGGER"
 $exe=Join-Path $env:SystemRoot 'System32\whoami.exe'
 $action=New-ScheduledTaskAction -Execute $exe
 $settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::FromMinutes(1))
 $whoA=[Security.Principal.NTAccount]::new($me.Name)
 $whoB=[Security.Principal.SecurityIdentifier]::new($testSid)
 $identityA=[string]$whoA.Value
 $identityB=[string]$whoB.Translate([Security.Principal.NTAccount]).Value
 $a=New-ScheduledTaskPrincipal -UserId $identityA -LogonType Interactive -RunLevel Limited
 Register-ScheduledTask -TaskName $task -Action $action -Principal $a -Settings $settings -Description $marker -ErrorAction Stop|Out-Null
 $taskOwned=$true
 if(-not (OwnedTask)){Fail "FIRST_TASK_NOT_REGISTERED"}
 $current=Get-ScheduledTask -TaskName $task
 $firstPrincipal=[string]$current.Principal.UserId
 if($firstPrincipal -notmatch [regex]::Escape($env:USERNAME)+'$'){Fail "FIRST_TASK_PRINCIPAL_WRONG"}
 $phase="REGISTER_DIFFERENT_LOCAL_USER_SAME_TASK_NAME_WITH_FORCE"
 $b=New-ScheduledTaskPrincipal -UserId $identityB -LogonType Interactive -RunLevel Limited
 Register-ScheduledTask -TaskName $task -Action $action -Principal $b -Settings $settings -Description $marker -Force -ErrorAction Stop|Out-Null
 if(-not (OwnedTask)){Fail "SECOND_TASK_NOT_REGISTERED"}
 $current=Get-ScheduledTask -TaskName $task
 $secondPrincipal=[string]$current.Principal.UserId
 if($secondPrincipal -notmatch [regex]::Escape($username)+'$' -or $secondPrincipal -ceq $firstPrincipal){
  Fail "SECOND_TASK_PRINCIPAL_NOT_REPLACED"
 }
 $xml=[xml](Export-ScheduledTask -TaskName $task)
 if(@($current.Triggers|Where-Object {$_ -ne $null}).Count){Fail "NO_TRIGGER_POLICY_VIOLATED"}
 $triggersZero=$true
 $replaced=$true
 $phase="DELETE_ONLY_OWNED_SYNTHETIC_NO_TRIGGER_TASK_AND_ACCOUNT"
 if(-not (OwnedTask)){Fail "TASK_MISSING_BEFORE_CLEANUP"}
 Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction Stop
 $taskOwned=$false
 $cleanupVerified=($null -eq (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue))
 if(-not $cleanupVerified){Fail "TASK_NOT_REMOVED"}
 $actual=Get-LocalUser -Name $username -ErrorAction Stop
 if([string]$actual.SID.Value -cne $testSid){Fail "TEST_USER_SID_CHANGED"}
 Disable-LocalUser -Name $username -ErrorAction Stop
 Remove-LocalUser -Name $username -ErrorAction Stop
 $created=$false
 $accountRemoved=($null -eq (Get-LocalUser -Name $username -ErrorAction SilentlyContinue))
 if(-not $accountRemoved){Fail "TEST_ACCOUNT_NOT_REMOVED"}
 $status="PASS_SYNTHETIC_MACHINEWIDE_SAME_TASK_NAME_FORCE_REPLACES_DIFFERENT_USER_PRINCIPAL"
}catch{
 $reason=$_.Exception.GetType().Name+": "+$_.Exception.Message
}finally{
 # Do not destroy task or account if an unknown actor has modified its identity.
 try{
  if($taskOwned -and (OwnedTask)){
   Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction Stop
   $taskOwned=$false
   $cleanupVerified=($null -eq (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue))
  }
 }catch{
  $status="FAIL_UNCERTAIN_TASK_CLEANUP"
  $reason+=" | TaskCleanup: "+$_.Exception.Message
 }
 try{
  if($created){
   $known=Get-LocalUser -Name $username -ErrorAction SilentlyContinue
   if($known -and [string]$known.SID.Value -ceq $testSid){
    Disable-LocalUser -Name $username -ErrorAction Stop
    Remove-LocalUser -Name $username -ErrorAction Stop
    $accountRemoved=($null -eq (Get-LocalUser -Name $username -ErrorAction SilentlyContinue))
   }
  }
 }catch{
  $status="FAIL_UNCERTAIN_ACCOUNT_CLEANUP"
  $reason+=" | AccountCleanup: "+$_.Exception.Message
 }
 $record=[ordered]@{
  Revision="R263";Status=$status;Phase=$phase;Failure=$reason
  Guest=$HostLabel;FirstAccountSid=$firstSid;SecondAccountSid=$testSid
  FirstTaskPrincipal=$firstPrincipal;SecondTaskPrincipal=$secondPrincipal
  DistinctAccounts=($firstSid -cne $testSid)
  SameTaskName=$task
  SameNameForceReplacedFirstPrincipal=$replaced
  NoTaskTriggersOrStarts=$triggersZero
  SyntheticTaskRemoved=$cleanupVerified
  SyntheticSecondAccountRemoved=$accountRemoved
  ExactProductHelperUsesSameTaskNameAndForce=$true
  ProductElevatedHelperActuallyExecuted=$false
  CrossUserRealSensorProcessInterrupted=$false
  SharedProgramFilesSensorPayloadObservedFromSource=$true
  NoDriverOrSensorInstall=$true;NoPublisherReleaseChanged=$true
  OwnerPCUntouched=$true;Utc=[DateTime]::UtcNow.ToString("o")
 }
 [IO.File]::WriteAllText($receipt,($record|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
 Write-Output ($record|ConvertTo-Json -Depth 6 -Compress)
}
if($status -notlike "PASS_*" -or !$cleanupVerified -or !$accountRemoved){
 throw ("R263_GUEST_TASK_NAMESPACE_NOT_ACCEPTED_"+$phase+"_"+$reason)
}
