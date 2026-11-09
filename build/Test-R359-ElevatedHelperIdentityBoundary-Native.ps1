[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$HostLabel,
    [Parameter(Mandatory=$true)][string]$SourceRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
if($PSVersionTable.PSEdition -cne 'Desktop' -or
   $env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/security/r347-r349-helper-hardening-v1710' -or
   $env:COMPUTERNAME -match '(?i)EMAD-PC|ALIEMAD|SAEID|LAPTOP' -or
   $env:GITHUB_RUN_ID -cnotmatch '^[0-9]{5,20}$' -or
   $env:GITHUB_SHA -cnotmatch '^[0-9a-f]{40}$' -or
   (git -C $SourceRoot rev-parse HEAD).Trim() -cne $env:GITHUB_SHA){
    throw 'R359_REFUSE_NONDISPOSABLE_OR_WRONG_GIT_SOURCE'
}
$setup=Join-Path $SourceRoot 'build\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$manifestPath=Join-Path $SourceRoot 'artifacts\BUILD_MANIFEST.json'
$helperSource=Join-Path $SourceRoot 'installer\TBME_Setup_Elevated_Helper.ps1'
$native=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
if(-not [IO.File]::Exists($setup) -or -not [IO.File]::Exists($manifestPath) -or
   -not [IO.File]::Exists($helperSource) -or -not [IO.File]::Exists($native)){
    throw 'R359_EXACT_SETUP_MANIFEST_HELPER_OR_NATIVE_POWERSHELL_MISSING'
}
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$manifestSetup=@($manifest.Outputs|Where-Object{$_.Name -ceq [IO.Path]::GetFileName($setup)})
if($manifestSetup.Count -ne 1){throw 'R359_SETUP_MANIFEST_ENTRY_MISSING_OR_DUPLICATE'}
$setupHash=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToUpperInvariant()
if(([string]$manifestSetup[0].SHA256).ToUpperInvariant() -cne $setupHash -or
   [long]$manifestSetup[0].Bytes -ne (Get-Item -LiteralPath $setup).Length){
    throw 'R359_SETUP_BYTES_DO_NOT_MATCH_BUILD_MANIFEST'
}
$sourceHash=(Get-FileHash -LiteralPath $helperSource -Algorithm SHA256).Hash.ToUpperInvariant()
$runId=$env:GITHUB_RUN_ID
$fixtureId=[guid]::NewGuid().ToString('N')
$tempRoot=[IO.Path]::GetFullPath($env:RUNNER_TEMP)
$root=Join-Path $tempRoot ('R359_'+$HostLabel+'_'+$runId+'_'+$fixtureId)
$receipt=Join-Path $tempRoot ('R359_'+$HostLabel+'_'+$runId+'.json')
if([IO.Directory]::Exists($root) -or [IO.File]::Exists($receipt)){
    throw 'R359_FIXTURE_OR_RECEIPT_COLLISION'
}
$checks=[Collections.Generic.List[string]]::new()
$failure=''
$launch=$null
$createdRoot=$false
$pipeName=''
$pipeHash=''
$currentSid=''
$targetSid=''
$effectiveFailure=''
$daclRules=@()
$before=@{}
$after=@{}
function Check([string]$name){
    $script:checks.Add($name)
    Write-Output ('PASS '+$name)
}
function Has-AllowedFullControl([object[]]$Rules,[string]$Sid){
    $matches=@($Rules|Where-Object{
        $_.IdentityReference.Value -ceq $Sid -and
        $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
        (($_.PipeAccessRights -band [IO.Pipes.PipeAccessRights]::FullControl) -eq [IO.Pipes.PipeAccessRights]::FullControl) -and
        -not $_.IsInherited
    })
    return ($matches.Count -eq 1)
}
try{
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    if($null -eq $identity -or $null -eq $identity.User){throw 'R359_RUNNER_IDENTITY_UNAVAILABLE'}
    $currentSid=[string]$identity.User.Value
    $principal=[Security.Principal.WindowsPrincipal]::new($identity)
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        throw 'R359_HOSTED_RUNNER_REQUIRES_EXISTING_ADMIN_TOKEN'
    }
    $lastDash=$currentSid.LastIndexOf('-')
    if($lastDash -lt 1){throw 'R359_CURRENT_SID_FORMAT_INVALID'}
    $sidPrefix=$currentSid.Substring(0,$lastDash+1)
    $profileKey=''
    do{
        $rid=[string]([uint32]([BitConverter]::ToUInt32([guid]::NewGuid().ToByteArray(),0)))
        $targetSid=$sidPrefix+$rid
        $profileKey='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\'+$targetSid
    }while($targetSid -ceq $currentSid -or (Test-Path -LiteralPath $profileKey))
    if($targetSid -cnotmatch '^S-1-5-21-(?:\d+-){3}\d+$'){
        throw 'R359_TARGET_SID_NOT_A_WELL_FORMED_LOCAL_USER_SID'
    }
    Check 'HOSTED_RUNNER_ADMIN_IDENTITY_AND_DISTINCT_TARGET_SID_ESTABLISHED'

    [void][IO.Directory]::CreateDirectory($root);$createdRoot=$true
    $programRoot=Join-Path $env:ProgramFiles 'TaskbarMonitorEnhanced'
    $appRoot=Join-Path $root 'target-profile\AppData\Local\TaskbarMonitorEnhanced'
    $payload=Join-Path (Join-Path $root 'target-profile\AppData\Local\Temp') ('tbme_setup_'+$fixtureId)
    $taskName='TaskbarMonitorEnhanced Sensor Broker'
    Import-Module ScheduledTasks -ErrorAction Stop
    $taskBefore=@(Get-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction SilentlyContinue|Where-Object{$null -ne $_})
    $processBefore=@(Get-Process -Name TaskbarMonitorSensorBroker,TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue)
    if([IO.Directory]::Exists($programRoot) -or [IO.Directory]::Exists($appRoot) -or
       [IO.Directory]::Exists($payload) -or $taskBefore.Count -ne 0 -or $processBefore.Count -ne 0){
        throw 'R359_FRESH_GUEST_HAS_EXISTING_PRODUCT_STATE'
    }
    $before=[ordered]@{
        ProgramFilesProductRoot=[IO.Directory]::Exists($programRoot)
        TargetAppRoot=[IO.Directory]::Exists($appRoot)
        TargetPayload=[IO.Directory]::Exists($payload)
        BrokerTask=($taskBefore.Count -gt 0)
        SensorProcesses=@($processBefore).Count
    }

    $asm=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $setup).Path)
    $resource=$asm.GetManifestResourceStream('Payload.TBME_Setup_Elevated_Helper.ps1')
    if($null -eq $resource){throw 'R359_SETUP_EMBEDDED_HELPER_RESOURCE_MISSING'}
    $reader=[IO.StreamReader]::new($resource,[Text.Encoding]::UTF8)
    try{$embedded=$reader.ReadToEnd()}finally{$reader.Dispose()}
    $normalize={param([string]$v) $v.Replace(([string][char]13+[string][char]10),[string][char]10).TrimStart([char]0xFEFF).TrimEnd()}
    $source=[IO.File]::ReadAllText($helperSource)
    if((& $normalize $embedded) -cne (& $normalize $source)){
        throw 'R359_SETUP_EMBEDDED_HELPER_NOT_SOURCE_EXACT'
    }
    if(-not $embedded.Contains('SENSOR_BOUNDARY_ELEVATED_TOKEN_ACCOUNT_MISMATCH') -or
       -not $embedded.Contains('R305: runas with a credential prompt can launch as a different admin.')){
        throw 'R359_SAME_ACCOUNT_FAIL_CLOSED_GUARD_MISSING'
    }
    Check 'EXACT_SETUP_PE_EMBEDS_CURRENT_HELPER_AND_R305_IDENTITY_GUARD'

    $setupType=$asm.GetType('SetupProgram',$true)
    $flags=[Reflection.BindingFlags]'Static,NonPublic'
    $buildMethod=$setupType.GetMethod('BuildElevatedSensorLaunch',$flags)
    if(!$buildMethod){throw 'R359_REAL_SETUP_PIPE_METHOD_MISSING'}
    $buildArgs=New-Object 'object[]' 4
    $buildArgs[0]=[string]'Install'
    $buildArgs[1]=[string]$payload
    $buildArgs[2]=[string]$appRoot
    $buildArgs[3]=[string]$currentSid
    $launch=$buildMethod.Invoke($null,$buildArgs)
    if($null -eq $launch){throw 'R359_REAL_SETUP_LAUNCH_OBJECT_NULL'}
    $pipeName=[string]$launch.PipeName
    $pipeHash=[string]$launch.HelperSHA256
    if($pipeName -cnotmatch '^TBME_SensorHelper_[0-9a-f]{32}$' -or $pipeHash -cnotmatch '^[0-9A-F]{64}$'){
        throw 'R359_PIPE_IDENTITY_OR_HASH_INVALID'
    }
    $serverField=$launch.GetType().GetField('server',[Reflection.BindingFlags]'Instance,NonPublic')
    if($null -eq $serverField){throw 'R359_REAL_SETUP_PIPE_SERVER_FIELD_MISSING'}
    $server=$serverField.GetValue($launch)
    if($null -eq $server){throw 'R359_REAL_SETUP_PIPE_SERVER_NULL'}
    $security=[IO.Pipes.PipesAclExtensions]::GetAccessControl($server)
    if(-not $security.AreAccessRulesProtected -or -not $security.AreAccessRulesCanonical){
        throw 'R359_PIPE_DACL_NOT_PROTECTED_AND_CANONICAL'
    }
    $rules=@($security.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
    $systemSid=[Security.Principal.SecurityIdentifier]::new([Security.Principal.WellKnownSidType]::LocalSystemSid,$null).Value
    $adminSid=[Security.Principal.SecurityIdentifier]::new([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid,$null).Value
    $usersSid=[Security.Principal.SecurityIdentifier]::new([Security.Principal.WellKnownSidType]::BuiltinUsersSid,$null).Value
    $authSid=[Security.Principal.SecurityIdentifier]::new([Security.Principal.WellKnownSidType]::AuthenticatedUserSid,$null).Value
    $everyoneSid=[Security.Principal.SecurityIdentifier]::new([Security.Principal.WellKnownSidType]::WorldSid,$null).Value
    if($rules.Count -ne 2 -or
       -not (Has-AllowedFullControl $rules $currentSid) -or
       -not (Has-AllowedFullControl $rules $systemSid) -or
       @($rules|Where-Object{$_.IdentityReference.Value -cin @($adminSid,$usersSid,$authSid,$everyoneSid)}).Count -ne 0){
        throw 'R359_PIPE_DACL_NOT_EXACT_OWNER_AND_SYSTEM_ONLY'
    }
    $daclRules=@($rules|ForEach-Object{[ordered]@{
        Sid=$_.IdentityReference.Value
        Rights=[string]$_.PipeAccessRights
        Type=[string]$_.AccessControlType
        Inherited=[bool]$_.IsInherited
    }})
    Check 'SETUP_PIPE_DACL_IS_PROTECTED_AND_RESTRICTED_TO_OWNER_AND_SYSTEM'

    $tokens=$null;$parseErrors=$null
    [System.Management.Automation.Language.Parser]::ParseInput($embedded,[ref]$tokens,[ref]$parseErrors)|Out-Null
    if($parseErrors.Count){throw ('R359_EMBEDDED_HELPER_PARSE_FAILED_'+$parseErrors[0].Message)}
    $zeroHash=('0'*64)
    $effectiveFailure=''
    try{
        & ([ScriptBlock]::Create($embedded)) -Mode 'Install' -PayloadDir $payload -AppRoot $appRoot -UserId $targetSid -ExpectedBrokerSHA256 $zeroHash -ExpectedSupervisorSHA256 $zeroHash -ExpectedBackendZipSHA256 $zeroHash
        throw 'R359_HELPER_DID_NOT_REFUSE_DIFFERENT_ELEVATED_SID'
    }catch{
        $effectiveFailure=[string]$_.Exception.Message
        if($effectiveFailure -cne 'SENSOR_BOUNDARY_ELEVATED_TOKEN_ACCOUNT_MISMATCH'){
            throw
        }
    }
    Check 'EMBEDDED_HELPER_REJECTS_DIFFERENT_EFFECTIVE_USER_SID_BEFORE_PROFILE_OR_INSTALL_MUTATION'

    $taskAfter=@(Get-ScheduledTask -TaskPath '\' -TaskName $taskName -ErrorAction SilentlyContinue|Where-Object{$null -ne $_})
    $processAfter=@(Get-Process -Name TaskbarMonitorSensorBroker,TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue)
    $after=[ordered]@{
        ProgramFilesProductRoot=[IO.Directory]::Exists($programRoot)
        TargetAppRoot=[IO.Directory]::Exists($appRoot)
        TargetPayload=[IO.Directory]::Exists($payload)
        BrokerTask=($taskAfter.Count -gt 0)
        SensorProcesses=@($processAfter).Count
    }
    if($after.ProgramFilesProductRoot -or $after.TargetAppRoot -or $after.TargetPayload -or
       $after.BrokerTask -or $after.SensorProcesses -ne 0){
        throw 'R359_CROSS_ACCOUNT_REFUSAL_MUTATED_PRODUCT_OR_TASK_STATE'
    }
    Check 'CROSS_ACCOUNT_REFUSAL_LEAVES_PROGRAMFILES_LOGS_PAYLOAD_TASK_AND_SENSOR_PROCESSES_UNCHANGED'
    Check 'NO_UAC_OR_PRODUCT_MUTATION_PERFORMED'
}catch{
    $failure=$_.Exception.ToString()
    Write-Output ('FAIL R359 '+$failure)
}finally{
    if($launch){try{$launch.Dispose()}catch{$failure=($failure+";R359_PIPE_DISPOSE_FAILED "+$_.Exception.Message).Trim()}}
    if($createdRoot){
        try{
            if([IO.Directory]::Exists($root)){[IO.Directory]::Delete($root,$true)}
            if([IO.Directory]::Exists($root)){throw 'R359_FIXTURE_CLEANUP_RESIDUE'}
        }catch{$failure=($failure+";R359_FIXTURE_CLEANUP_FAILED "+$_.Exception.Message).Trim()}
    }
    $receiptObject=[ordered]@{
        Schema=1
        Revision='R359'
        Host=$HostLabel
        RunId=$runId
        GitHubSHA=$env:GITHUB_SHA
        SetupSHA256=$setupHash
        HelperSourceSHA256=$sourceHash
        PipeName=$pipeName
        PackedHelperSHA256=$pipeHash
        CurrentRunnerSID=$currentSid
        DifferentTargetSID=$targetSid
        PipeDacl=$daclRules
        ExpectedBoundaryFailure=$effectiveFailure
        Before=$before
        After=$after
        Checks=@($checks)
        Passed=($failure -eq '' -and $checks.Count -eq 6)
        UACActuallyInvoked=$false
        ProductInstallOrMutationPerformed=$false
        Failure=$failure
    }
    try{[IO.File]::WriteAllText($receipt,($receiptObject|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))}
    catch{Write-Output ('FAIL R359_RECEIPT_WRITE '+$_.Exception.Message);if($failure -eq ''){$failure=$_.Exception.Message}}
}
if($failure){Write-Output ('FAIL R359 '+$failure);exit 1}
Write-Output ('R359_NATIVE_STATUS=PASS CHECKS='+$checks.Count+' SETUP_SHA256='+$setupHash)
