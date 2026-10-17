param(
    [Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$Mode,
    [Parameter(Mandatory=$true)][string]$PayloadDir,
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$UserId,
    [string]$ExpectedBrokerSHA256='',
    [string]$ExpectedSupervisorSHA256='',
    [string]$ExpectedBackendZipSHA256=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

# R291: privileged sensor preflight runs before ANY result/log creation.
# Ordinary per-user Setup stays unelevated; only optional sensors use UAC.
function Assert-SensorBoundaryNoReparse([string]$Path){
    if([string]::IsNullOrWhiteSpace($Path)){throw 'SENSOR_BOUNDARY_EMPTY_PATH'}
    $cursor=[IO.Path]::GetFullPath($Path)
    while(-not [string]::IsNullOrEmpty($cursor)){
        try{
            if(([IO.File]::GetAttributes($cursor) -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw [IO.IOException]::new('SENSOR_BOUNDARY_REPARSE_REFUSED: '+$cursor)
            }
        }catch [IO.FileNotFoundException]{
            # Absent output may be created later; other I/O errors fail closed.
        }catch [IO.DirectoryNotFoundException]{
        }
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if([string]::IsNullOrEmpty($parent) -or $parent -ceq $cursor){break}
        $cursor=$parent
    }
}
function Assert-SensorPrivilegedBoundary(
    [string]$RequestedMode,[string]$RequestedPayload,[string]$RequestedAppRoot,[string]$RequestedUser
){
    if($RequestedMode -cne 'Install' -and $RequestedMode -cne 'Uninstall'){
        throw 'SENSOR_BOUNDARY_INVALID_MODE'
    }
    if([string]::IsNullOrWhiteSpace($RequestedUser)){throw 'SENSOR_BOUNDARY_EMPTY_USER'}
    $sid=if($RequestedUser -match '^S-1-5-21-(?:\d+-){3}\d+$'){
        $RequestedUser
    }else{
        try{
            [string]([Security.Principal.NTAccount]::new($RequestedUser)).Translate(
                [Security.Principal.SecurityIdentifier]
            ).Value
        }catch{
            throw 'SENSOR_BOUNDARY_USER_ID_UNRESOLVABLE'
        }
    }
    if($sid -cnotmatch '^S-1-5-21-(?:\d+-){3}\d+$'){
        throw 'SENSOR_BOUNDARY_USER_PROFILE_NOT_INTERACTIVE'
    }
    # R305: runas with a credential prompt can launch as a different admin.
    # Fail BEFORE any sensor log/result/ProgramFiles/task mutation if the
    # actual elevated process identity is not the intended user's SID.
    $effective=[Security.Principal.WindowsIdentity]::GetCurrent()
    if($null -eq $effective -or $null -eq $effective.User -or
       -not [string]::Equals([string]$effective.User.Value,$sid,[StringComparison]::OrdinalIgnoreCase)){
        throw 'SENSOR_BOUNDARY_ELEVATED_TOKEN_ACCOUNT_MISMATCH'
    }
    $profileKey='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\'+$sid
    $entry=Get-ItemProperty -LiteralPath $profileKey -ErrorAction Stop
    if([string]::IsNullOrWhiteSpace([string]$entry.ProfileImagePath)){
        throw 'SENSOR_BOUNDARY_PROFILE_MISSING'
    }
    $profile=[IO.Path]::GetFullPath(
        [Environment]::ExpandEnvironmentVariables([string]$entry.ProfileImagePath)
    ).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if($profile.StartsWith('\\') -or [IO.Path]::GetPathRoot($profile) -ceq $profile){
        throw 'SENSOR_BOUNDARY_PROFILE_NOT_LOCAL'
    }
    $expectedRoot=[IO.Path]::GetFullPath((Join-Path $profile 'AppData\Local\TaskbarMonitorEnhanced'))
    if(-not [IO.Path]::IsPathRooted($RequestedAppRoot) -or
       -not [string]::Equals([IO.Path]::GetFullPath($RequestedAppRoot),
               $expectedRoot,[StringComparison]::OrdinalIgnoreCase)){
        throw 'SENSOR_BOUNDARY_APP_ROOT_OUTSIDE_USER_PROFILE'
    }
    if(-not [IO.Path]::IsPathRooted($RequestedPayload)){
        throw 'SENSOR_BOUNDARY_PAYLOAD_NOT_ABSOLUTE'
    }
    $payload=[IO.Path]::GetFullPath($RequestedPayload)
    $name=[IO.Path]::GetFileName($payload.TrimEnd([IO.Path]::DirectorySeparatorChar))
    $prefix=if($RequestedMode -ceq 'Install'){'tbme_setup_'}else{'tbme_uninstall_'}
    # Only direct children of this user's default Temp root are trusted. A
    # profile-wide prefix would also accept Downloads or arbitrary subfolders.
    # Nonstandard redirected TEMP locations fail closed (optional sensors degrade).
    $expectedTempParent=[IO.Path]::GetFullPath(
        (Join-Path $profile 'AppData\Local\Temp')
    ).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if(-not [string]::Equals([IO.Path]::GetDirectoryName($payload),
                             $expectedTempParent,[StringComparison]::OrdinalIgnoreCase) -or
       $name -cnotmatch ('^'+$prefix+'[0-9a-f]{32}$')){
        throw 'SENSOR_BOUNDARY_PAYLOAD_OUTSIDE_USER_TEMP'
    }
    $trustedProgramFiles=[Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
    if(-not [string]::Equals([IO.Path]::GetFullPath($trustedProgramFiles),
              [IO.Path]::GetFullPath($env:ProgramFiles),[StringComparison]::OrdinalIgnoreCase)){
        throw 'SENSOR_BOUNDARY_PROGRAMFILES_REDIRECT'
    }
    $brokerRoot=Join-Path $trustedProgramFiles 'TaskbarMonitorEnhanced\SensorBroker'
    $candidates=@(
       $profile,$expectedRoot,$payload,$brokerRoot,
       (Join-Path $expectedRoot 'Logs'),
       (Join-Path $expectedRoot 'Logs\sensor_install.log'),
       (Join-Path $expectedRoot 'Logs\sensor_install_result.json'),
       (Join-Path $expectedRoot 'SensorBackend\LibreHardwareMonitor-0.9.6\LibreHardwareMonitorLib.dll'),
       (Join-Path $expectedRoot 'cpu_temp_broker.json'),
       (Join-Path $expectedRoot 'gpu_temp_broker.json'),
       (Join-Path $expectedRoot 'storage_temp_broker.json'),
       (Join-Path $expectedRoot 'sensor_supervisor_state.json'),
       (Join-Path $payload 'TBME_Setup_Elevated_Helper.ps1'),
       (Join-Path $payload 'TaskbarMonitorSensorBroker.exe'),
       (Join-Path $payload 'TaskbarMonitorSensorSupervisor.exe'),
       (Join-Path $brokerRoot 'TaskbarMonitorSensorBroker.exe'),
       (Join-Path $brokerRoot 'TaskbarMonitorSensorSupervisor.exe')
    )
    foreach($path in $candidates){Assert-SensorBoundaryNoReparse $path}
    return $sid
}
$validatedSensorSid=Assert-SensorPrivilegedBoundary $Mode $PayloadDir $AppRoot $UserId

$TaskName='TaskbarMonitorEnhanced Sensor Broker'
$BrokerRoot=Join-Path $env:ProgramFiles 'TaskbarMonitorEnhanced\SensorBroker'
$SensorOwnerMarker=Join-Path $BrokerRoot '.tbme-owner.sid'
$script:SensorJournalRoot=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'TaskbarMonitorEnhanced\.tbme-sensor-rollback'
$LogsRoot=Join-Path $AppRoot 'Logs'
$ResultPath=Join-Path $LogsRoot 'sensor_install_result.json'
$LogPath=Join-Path $LogsRoot 'sensor_install.log'
New-Item -ItemType Directory -Force -Path $LogsRoot | Out-Null

# R21 health channels are initialized before any early-return/uninstall branch so
# Write-Result can always emit a stable schema under StrictMode.
$SupervisorHealthy=$false
$CpuTransportHealthy=$false
$GpuTransportHealthy=$false
$StorageTransportHealthy=$false
$CpuDataAvailable=$false
$RollbackPerformed=$false
$RollbackSucceeded=$false
$PreviousSensorLayerPresent=$false
$ActiveArchitecture='R21_PROCESS_ISOLATED'
$RollbackFiles=@()
$RollbackTaskXmlText=$null
$RollbackCaptured=$false

function Write-Log([string]$Message){
    $line=(Get-Date).ToString('o')+' '+$Message
    $line | Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Write-Result(
    [string]$Status,
    [string]$Message,
    [string]$PawnStatus,
    [Nullable[int]]$PawnExitCode,
    [bool]$RebootRequired,
    [bool]$TaskInstalled,
    [bool]$SensorHealthy
){
    [ordered]@{
        Status=$Status
        Message=$Message
        PawnIOStatus=$PawnStatus
        PawnIOExitCode=$(if($null -eq $PawnExitCode){$null}else{[int]$PawnExitCode})
        RebootRequired=$RebootRequired
        TaskInstalled=$TaskInstalled
        SensorHealthy=$SensorHealthy
        SupervisorHealthy=$SupervisorHealthy
        CpuTransportHealthy=$CpuTransportHealthy
        GpuTransportHealthy=$GpuTransportHealthy
        StorageTransportHealthy=$StorageTransportHealthy
        CpuDataAvailable=$CpuDataAvailable
        Architecture=$ActiveArchitecture
        RollbackPerformed=$RollbackPerformed
        RollbackSucceeded=$RollbackSucceeded
        PreviousSensorLayerPresent=$PreviousSensorLayerPresent
        Time=(Get-Date).ToString('o')
        LogPath=$LogPath
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
}
function Get-PawnIOVersion {
    foreach($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO'
    )){
        try{
            if(Test-Path -LiteralPath $key){
                $value=(Get-ItemProperty -LiteralPath $key -ErrorAction Stop).DisplayVersion
                if($value){return [string]$value}
            }
        }catch{}
    }
    return ''
}

# R296: no privileged rollback snapshot is staged to user-writable Temp.
function Get-SensorRollbackFiles([string]$Folder){
    Assert-SensorBoundaryNoReparse $Folder
    $root=[IO.Path]::GetFullPath($Folder).TrimEnd('\')
    $prefix=$root+'\'
    $items=@(Get-ChildItem -LiteralPath $root -Force -Recurse -ErrorAction Stop)
    foreach($item in $items){Assert-SensorBoundaryNoReparse $item.FullName}
    $files=@($items|Where-Object {-not $_.PSIsContainer})
    if($files.Count -gt 128){throw 'ROLLBACK_FILE_COUNT'}
    $saved=[Collections.Generic.List[object]]::new()
    [long]$total=0
    foreach($file in $files){
        $path=[IO.Path]::GetFullPath($file.FullName)
        if(-not $path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'ROLLBACK_PATH_ESCAPE'}
        Assert-SensorBoundaryNoReparse $path
        $rel=$path.Substring($prefix.Length)
        foreach($part in $rel.Split('\')){
            if($part -ceq '.' -or $part -ceq '..' -or $part -cnotmatch '^[A-Za-z0-9_.-]+$'){
                throw 'ROLLBACK_BAD_NAME'
            }
        }
        $fs=[IO.FileStream]::new($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
        try{
            if($fs.Length -gt 16777216){throw 'ROLLBACK_FILE_TOO_LARGE'}
            $total+=$fs.Length
            if($total -gt 67108864){throw 'ROLLBACK_TOTAL_TOO_LARGE'}
            $bytes=[byte[]]::new([int]$fs.Length)
            $n=0
            while($n -lt $bytes.Length){
                $k=$fs.Read($bytes,$n,$bytes.Length-$n)
                if($k -lt 1){throw 'ROLLBACK_SHORT_READ'}
                $n+=$k
            }
            $saved.Add([pscustomobject]@{Rel=$rel;Data=$bytes})
        }finally{$fs.Dispose()}
    }
    return ,$saved.ToArray()
}
function Restore-SensorRollbackFiles([string]$Folder,[object[]]$Saved){
    Assert-SensorBoundaryNoReparse $Folder
    New-Item -ItemType Directory -Force -Path $Folder|Out-Null
    foreach($entry in $Saved){
        foreach($part in ([string]$entry.Rel).Split('\')){
            if($part -ceq '.' -or $part -ceq '..' -or $part -cnotmatch '^[A-Za-z0-9_.-]+$'){
                throw 'ROLLBACK_RESTORE_BAD_NAME'
            }
        }
        $path=Join-Path $Folder $entry.Rel
        Assert-SensorBoundaryNoReparse $path
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path)|Out-Null
        Assert-SensorBoundaryNoReparse $path
        [IO.File]::WriteAllBytes($path,[byte[]]$entry.Data)
    }
}
function Clear-SensorRollbackBuffer {
    $script:RollbackFiles=@()
    $script:RollbackTaskXmlText=$null
    $script:RollbackCaptured=$false
}

# R308 experimental protected write-ahead snapshot. The current review stage
# deliberately refuses preexisting/stale journals rather than consuming them.
# Crash recovery and terminal cleanup need separate native acceptance.
function Get-SensorJournalHash([byte[]]$Value){
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return [BitConverter]::ToString($sha.ComputeHash($Value)).Replace('-','')}
    finally{$sha.Dispose()}
}
function Assert-SensorJournalRelative([string]$Rel){
    if([string]::IsNullOrWhiteSpace($Rel) -or $Rel.Length -gt 240 -or
       [IO.Path]::IsPathRooted($Rel) -or $Rel.Contains('/') -or
       $Rel.Contains(':') -or $Rel.StartsWith('\') -or $Rel.EndsWith('\')){
        throw 'SENSOR_JOURNAL_UNSAFE_RELATIVE_NAME'
    }
    foreach($part in $Rel.Split('\')){
        if($part -ceq '.' -or $part -ceq '..' -or $part.EndsWith('.') -or
           $part -cnotmatch '^[A-Za-z0-9_.-]+$'){
            throw 'SENSOR_JOURNAL_UNSAFE_RELATIVE_NAME'
        }
    }
}
function Assert-SensorJournalTrustedAcl([string]$Path,[bool]$RequireProtected){
    Assert-SensorBoundaryNoReparse $Path
    $acl=Get-Acl -LiteralPath $Path -ErrorAction Stop
    $owner=([Security.Principal.NTAccount]::new([string]$acl.Owner)).Translate(
        [Security.Principal.SecurityIdentifier]).Value
    $trusted=@('S-1-5-18','S-1-5-32-544',
        'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
    if($trusted -cnotcontains $owner){throw 'SENSOR_JOURNAL_UNTRUSTED_OWNER'}
    if($RequireProtected -and -not $acl.AreAccessRulesProtected){
        throw 'SENSOR_JOURNAL_UNPROTECTED_DACL'
    }
    $write=[Security.AccessControl.FileSystemRights]::Write -bor
        [Security.AccessControl.FileSystemRights]::Modify -bor
        [Security.AccessControl.FileSystemRights]::Delete -bor
        [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [Security.AccessControl.FileSystemRights]::TakeOwnership
    foreach($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])){
        if($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow){continue}
        if($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly){continue}
        if(($trusted -cnotcontains [string]$rule.IdentityReference.Value) -and
           ($rule.FileSystemRights -band $write)){
            throw 'SENSOR_JOURNAL_UNTRUSTED_WRITE_ACE'
        }
    }
}
function Write-SensorJournalUnique([string]$Root,[string]$Relative,[byte[]]$Bytes){
    Assert-SensorJournalRelative $Relative
    $file=Join-Path $Root $Relative
    $parent=[IO.Path]::GetDirectoryName($file)
    Assert-SensorBoundaryNoReparse $parent
    [void][IO.Directory]::CreateDirectory($parent)
    Assert-SensorJournalTrustedAcl $parent $false
    Assert-SensorBoundaryNoReparse $file
    $fs=[IO.FileStream]::new($file,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$fs.Write($Bytes,0,$Bytes.Length);$fs.Flush($true)}
    finally{$fs.Dispose()}
    Assert-SensorJournalTrustedAcl $file $false
}
function Assert-SensorDurableJournal([string]$Root,[string]$ExpectedSid){
    Assert-SensorJournalTrustedAcl $Root $true
    $ready=Join-Path $Root 'READY'
    Assert-SensorBoundaryNoReparse $ready
    if(-not [IO.File]::Exists($ready) -or
       [IO.File]::ReadAllText($ready,[Text.Encoding]::ASCII) -cne 'TBME_SENSOR_READY_V1'){
        throw 'SENSOR_JOURNAL_INCOMPLETE_OR_UNREADY'
    }
    foreach($name in @('READY','manifest.json','task.xml')){
        Assert-SensorJournalTrustedAcl (Join-Path $Root $name) $false
    }
    $file=Join-Path $Root 'manifest.json'
    if(([IO.FileInfo]::new($file)).Length -gt 65536){throw 'SENSOR_JOURNAL_MANIFEST_OVERSIZE'}
    $manifest=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)|ConvertFrom-Json
    if($manifest.Schema -ne 1 -or $manifest.Phase -cne 'PREPARED' -or
       $manifest.Sid -cne $ExpectedSid){throw 'SENSOR_JOURNAL_OWNER_OR_PHASE_MISMATCH'}
    $bytes=[IO.File]::ReadAllBytes((Join-Path $Root 'task.xml'))
    if($bytes.Length -gt 262144 -or
       (Get-SensorJournalHash $bytes) -cne [string]$manifest.TaskHash){
        throw 'SENSOR_JOURNAL_TASK_XML_HASH_MISMATCH'
    }
    $allowed=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($n in @('READY','manifest.json','task.xml')){[void]$allowed.Add((Join-Path $Root $n))}
    [void]$allowed.Add((Join-Path $Root 'files'))
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if(@($manifest.Files).Count -gt 128){throw 'SENSOR_JOURNAL_SNAPSHOT_COUNT_INVALID'}
    [long]$total=0
    foreach($row in @($manifest.Files)){
        $rel=[string]$row.Rel
        Assert-SensorJournalRelative $rel
        if(-not $seen.Add($rel)){throw 'SENSOR_JOURNAL_DUPLICATE_SNAPSHOT'}
        $path=Join-Path (Join-Path $Root 'files') $rel
        Assert-SensorJournalTrustedAcl $path $false
        $blob=[IO.File]::ReadAllBytes($path)
        $total+=$blob.Length
        if($blob.Length -gt 16777216 -or $total -gt 67108864 -or
           $blob.Length -ne [long]$row.Length -or
           (Get-SensorJournalHash $blob) -cne [string]$row.Hash){
            throw 'SENSOR_JOURNAL_SNAPSHOT_HASH_MISMATCH'
        }
        [void]$allowed.Add($path)
        $parent=[IO.Path]::GetDirectoryName($path)
        while($parent.StartsWith((Join-Path $Root 'files')+'\',[StringComparison]::OrdinalIgnoreCase)){
            [void]$allowed.Add($parent)
            $parent=[IO.Path]::GetDirectoryName($parent)
        }
    }
    if(-not [IO.Directory]::Exists((Join-Path $Root 'files'))){
        throw 'SENSOR_JOURNAL_FILES_DIRECTORY_MISSING'
    }
    # Check each child before recursing; never follow a junction while merely
    # enumerating the rollback journal (PowerShell provider behavior varies).
    $pending=[Collections.Generic.List[string]]::new()
    $pending.Add($Root)
    while($pending.Count -gt 0){
        $directory=$pending[$pending.Count-1]
        $pending.RemoveAt($pending.Count-1)
        Assert-SensorBoundaryNoReparse $directory
        foreach($member in [IO.Directory]::GetFileSystemEntries($directory)){
            $full=[IO.Path]::GetFullPath($member)
            $attrs=[IO.File]::GetAttributes($full)
            if(($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw 'SENSOR_JOURNAL_REPARSE_MEMBER'
            }
            if(-not $allowed.Contains($full)){
                throw 'SENSOR_JOURNAL_UNKNOWN_MEMBER'
            }
            if(($attrs -band [IO.FileAttributes]::Directory) -ne 0){
                $pending.Add($full)
            }
        }
    }
    return $manifest
}
function New-SensorDurableJournal(
    [string]$Root,[string]$Sid,[object[]]$Rows,[string]$TaskXml,
    [string[]]$NewNames,[bool]$OldRootPresent
){
    $token=[Security.Principal.WindowsIdentity]::GetCurrent().User
    if($null -eq $token -or $token.Value -cne $Sid){
        throw 'SENSOR_JOURNAL_TOKEN_MISMATCH'
    }
    Assert-SensorBoundaryNoReparse $Root
    if(Test-Path -LiteralPath $Root){throw 'SENSOR_JOURNAL_ALREADY_EXISTS'}
    $parent=[IO.Path]::GetDirectoryName($Root)
    Assert-SensorJournalTrustedAcl $parent $false
    $all=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if(@($Rows).Count -gt 128 -or @($NewNames).Count -gt 64){
        throw 'SENSOR_JOURNAL_INVENTORY_TOO_LARGE'
    }
    $index=[Collections.Generic.List[object]]::new()
    [long]$sum=0
    foreach($r in @($Rows)){
        $rel=[string]$r.Rel
        Assert-SensorJournalRelative $rel
        if(-not $all.Add($rel)){throw 'SENSOR_JOURNAL_DUPLICATE_ORIGINAL'}
        $payload=[byte[]]$r.Data
        $sum+=$payload.Length
        if($payload.Length -gt 16777216 -or $sum -gt 67108864){
            throw 'SENSOR_JOURNAL_TOO_LARGE'
        }
        $index.Add([pscustomobject]@{Rel=$rel;Length=$payload.Length;Hash=(Get-SensorJournalHash $payload)})
    }
    $newList=[Collections.Generic.List[string]]::new()
    $newSeen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($name in $NewNames){
        Assert-SensorJournalRelative $name
        if(-not $newSeen.Add($name)){throw 'SENSOR_JOURNAL_DUPLICATE_NEXT_FILE'}
        $newList.Add($name)
    }
    $xml=[Text.Encoding]::UTF8.GetBytes([string]$TaskXml)
    if($xml.Length -gt 262144){throw 'SENSOR_JOURNAL_XML_TOO_LARGE'}
    $admins=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $system=[Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $acl=[Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($admins)
    $acl.SetAccessRuleProtection($true,$false)
    foreach($principal in @($admins,$system)){
        $ace=[Security.AccessControl.FileSystemAccessRule]::new(
            $principal,[Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow)
        [void]$acl.AddAccessRule($ace)
    }
    [void][IO.Directory]::CreateDirectory($Root,$acl)
    Assert-SensorJournalTrustedAcl $Root $true
    [void][IO.Directory]::CreateDirectory((Join-Path $Root 'files'))
    Assert-SensorJournalTrustedAcl (Join-Path $Root 'files') $false
    foreach($r in @($Rows)){
        Write-SensorJournalUnique $Root ('files\'+[string]$r.Rel) ([byte[]]$r.Data)
    }
    Write-SensorJournalUnique $Root 'task.xml' $xml
    $manifest=[ordered]@{
        Schema=1;Phase='PREPARED';Sid=$Sid;OldRootPresent=$OldRootPresent
        TaskPresent=($xml.Length -gt 0);TaskHash=(Get-SensorJournalHash $xml)
        Files=@($index);ExpectedNewFiles=@($newList)
    }
    $json=[Text.Encoding]::UTF8.GetBytes(($manifest|ConvertTo-Json -Depth 6 -Compress))
    if($json.Length -gt 65536){throw 'SENSOR_JOURNAL_MANIFEST_TOO_LARGE'}
    Write-SensorJournalUnique $Root 'manifest.json' $json
    # READY is written and flushed LAST, before any service/task mutation.
    Write-SensorJournalUnique $Root 'READY' ([Text.Encoding]::ASCII.GetBytes('TBME_SENSOR_READY_V1'))
    $verified=Assert-SensorDurableJournal $Root $Sid
    if($verified.Phase -cne 'PREPARED'){throw 'SENSOR_JOURNAL_READY_READBACK_FAILED'}
}

function Capture-PreviousSensorLayer {
    try{
        Clear-SensorRollbackBuffer
        if(Test-Path -LiteralPath $BrokerRoot){
            $script:RollbackFiles=Get-SensorRollbackFiles $BrokerRoot
            $script:PreviousSensorLayerPresent=$true
        }
        Import-Module ScheduledTasks
        $task=Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if($task){
            $script:RollbackTaskXmlText=[string](Export-ScheduledTask -TaskName $TaskName)
            if($RollbackTaskXmlText.Length -gt 262144){throw 'ROLLBACK_XML_TOO_LARGE'}
            $script:PreviousSensorLayerPresent=$true
        }
        $script:RollbackCaptured=$true
        Write-Log ("ROLLBACK_CAPTURE_PASS previous="+$PreviousSensorLayerPresent)
        return $true
    }catch{
        Clear-SensorRollbackBuffer
        Write-Log ('ROLLBACK_CAPTURE_FAIL '+$_.Exception.ToString())
        return $false
    }
}

function Restore-PreviousSensorLayer([string]$Reason){
    $script:RollbackPerformed=$true
    $script:RollbackSucceeded=$false
    try{
        Write-Log ("ROLLBACK_BEGIN reason="+$Reason+" previous="+$PreviousSensorLayerPresent)
        if(-not $RollbackCaptured){throw 'ROLLBACK_NOT_CAPTURED'}
        Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        Remove-Item -LiteralPath $BrokerRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $LiveJson,$GpuJson,$StorageJson,$SupervisorState -Force -ErrorAction SilentlyContinue

        if(@($RollbackFiles).Count -gt 0){
            Restore-SensorRollbackFiles $BrokerRoot $RollbackFiles
        }
        if(-not [string]::IsNullOrEmpty($RollbackTaskXmlText)){
            Register-ScheduledTask -TaskName $TaskName -Xml $RollbackTaskXmlText -Force|Out-Null
            Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        }

        $script:ActiveArchitecture=$(if($PreviousSensorLayerPresent){'PREVIOUS_SENSOR_LAYER_RESTORED'}else{'NO_PROTECTED_SENSOR_LAYER'})
        $script:RollbackSucceeded=$true
        Write-Log ("ROLLBACK_PASS architecture="+$ActiveArchitecture)
        return $true
    }catch{
        $script:ActiveArchitecture='ROLLBACK_FAILED'
        Write-Log ('ROLLBACK_FAIL '+$_.Exception.ToString())
        return $false
    }
}

Write-Log "BEGIN mode=$Mode user=$UserId"

# R264-SENSOR-GUARD-BOUNDARY-BEGIN
# Before any shared task/process/file mutation, fail closed if a different
# Windows account owns the fixed legacy machinewide sensor task or processes.
# This is defensive per-account isolation, NOT a machinewide singleton policy.
function Resolve-SensorPrincipalSid([string]$AccountName){
    if([string]::IsNullOrWhiteSpace($AccountName)){throw 'EMPTY_SENSOR_PRINCIPAL'}
    if($AccountName -match '^S-1-5-(?:\d+-)+\d+$'){return $AccountName}
    $account=[Security.Principal.NTAccount]::new($AccountName)
    return [string]$account.Translate([Security.Principal.SecurityIdentifier]).Value
}
function Preserve-OtherUserSensorLayer([string]$Why){
    $script:ActiveArchitecture='SHARED_PROTECTED_SENSOR_LAYER_LEFT_UNTOUCHED'
    Write-Log ('CROSS_USER_SENSOR_SAFETY_REFUSAL reason='+$Why+' mode='+$Mode)
    Write-Result 'DEGRADED_OTHER_USER_SENSOR_LAYER_PRESERVED' ('Protected sensors were not changed: '+$Why+'. The per-user main app remains available with unavailable protected metrics as N/A.') 'NOT_STARTED' $null $false $false $false
    exit 0
}
try{
    $expectedUserSid=Resolve-SensorPrincipalSid $UserId
    Import-Module ScheduledTasks -ErrorAction Stop
    $lookupErrors=@()
    $existing=@(Get-ScheduledTask -TaskPath '\' -TaskName $TaskName -ErrorAction SilentlyContinue -ErrorVariable +lookupErrors |
        Where-Object {$null -ne $_})
    if(@($lookupErrors|Where-Object {$_.CategoryInfo.Category -ne [Management.Automation.ErrorCategory]::ObjectNotFound}).Count){
        throw 'TASK_SCHEDULER_LOOKUP_NOT_TRUSTED'
    }
    if($existing.Count -gt 1){throw 'MULTIPLE_GLOBAL_TASK_MATCHES'}
    if($existing.Count -eq 1){
        $oldSid=Resolve-SensorPrincipalSid ([string]$existing[0].Principal.UserId)
        if($oldSid -cne $expectedUserSid){
            Preserve-OtherUserSensorLayer 'ANOTHER_ACCOUNT_OWNS_GLOBAL_SCHEDULED_TASK'
        }
    }elseif(Test-Path -LiteralPath $BrokerRoot){
        # R303: an aborted same-user install may leave an existing protected
        # BrokerRoot after task removal. Refuse absent/other-user ownership.
        Assert-SensorBoundaryNoReparse $SensorOwnerMarker
        if(-not (Test-Path -LiteralPath $SensorOwnerMarker -PathType Leaf)){
            Preserve-OtherUserSensorLayer 'UNOWNED_SHARED_PROGRAMFILES_BROKER_WITHOUT_TASK'
        }
        if([IO.File]::ReadAllText($SensorOwnerMarker,[Text.Encoding]::ASCII).Trim() -cne $expectedUserSid){
            Preserve-OtherUserSensorLayer 'PROTECTED_SENSOR_OWNER_MARKER_MISMATCH'
        }
        Write-Log 'PARTIAL_PROTECTED_SENSOR_BROKER_SAME_OWNER_ACCEPTED'
    }
    $sensorProcesses=@(Get-CimInstance Win32_Process -Filter "Name='TaskbarMonitorSensorBroker.exe' OR Name='TaskbarMonitorSensorSupervisor.exe'" -ErrorAction Stop |
       Where-Object {$null -ne $_})
    foreach($proc in $sensorProcesses){
        $owner=Invoke-CimMethod -InputObject $proc -MethodName GetOwnerSid -ErrorAction Stop
        if([int]$owner.ReturnValue -ne 0 -or
            [String]::IsNullOrWhiteSpace([string]$owner.Sid) -or
            [string]$owner.Sid -cne $expectedUserSid){
            Preserve-OtherUserSensorLayer 'SENSOR_PROCESS_OWNER_IS_UNKNOWN_OR_OTHER_ACCOUNT'
        }
    }
}catch{
    Preserve-OtherUserSensorLayer ('UNVERIFIED_MACHINEWIDE_SENSOR_OWNERSHIP_'+$_.Exception.GetType().Name)
}
# R264-SENSOR-GUARD-BOUNDARY-END

# R308: no automatic recovery/cleanup until an independently validated
# terminal protocol exists. Existing or partial journal blocks further
# protected writes; the per-user main application remains usable.
Assert-SensorBoundaryNoReparse $SensorJournalRoot
if(Test-Path -LiteralPath $SensorJournalRoot){
    $script:ActiveArchitecture='PROTECTED_JOURNAL_RECOVERY_REQUIRED'
    Write-Log 'R308_PENDING_PROTECTED_JOURNAL_NO_NEW_PROTECTED_MUTATION'
    Write-Result 'DEGRADED_ROLLBACK_RECOVERY_REQUIRED' 'A protected sensor update journal is pending validation. Protected sensors were not modified; a verified recovery procedure is required.' 'NOT_STARTED' $null $false $false $false
    exit 0
}

if($Mode -eq 'Uninstall'){
    try{
        Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $BrokerRoot -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log 'UNINSTALL protected sensor layer removed'
        Write-Result 'UNINSTALLED' 'Protected sensor layer removed.' 'NOT_APPLICABLE' $null $false $false $false
        exit 0
    }catch{
        Write-Log ('UNINSTALL_ERROR '+$_.Exception.ToString())
        Write-Result 'UNINSTALL_WARNING' $_.Exception.Message 'NOT_APPLICABLE' $null $false $false $false
        exit 0
    }
}

# R294: one exclusive read; installed bytes are the same verified buffer.
function Get-VerifiedSensorPayloadBytes([string]$File,[string]$Expected,[long]$MaxBytes){
    if($Expected -cnotmatch '^[A-F0-9]{64}$'){throw 'SENSOR_PAYLOAD_SHA_NOT_PINNED'}
    Assert-SensorBoundaryNoReparse $File
    $stream=[IO.FileStream]::new($File,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    try{
        if($stream.Length -lt 1 -or $stream.Length -gt $MaxBytes){throw 'SENSOR_PAYLOAD_SIZE_INVALID'}
        $buffer=[byte[]]::new([int]$stream.Length)
        $offset=0
        while($offset -lt $buffer.Length){
            $count=$stream.Read($buffer,$offset,$buffer.Length-$offset)
            if($count -le 0){throw 'SENSOR_PAYLOAD_SHORT_READ'}
            $offset+=$count
        }
        $sha=[Security.Cryptography.SHA256]::Create()
        try{$actual=[BitConverter]::ToString($sha.ComputeHash($buffer)).Replace('-','')}
        finally{$sha.Dispose()}
        if($actual -cne $Expected){throw 'SENSOR_PAYLOAD_EMBEDDED_SHA_MISMATCH'}
        return ,$buffer
    }finally{$stream.Dispose()}
}

# R295: only the PE-pinned, single-read ZIP buffer supplies protected dependency bytes.
function Get-VerifiedSensorBackendEntries([string]$ZipFile,[string]$ExpectedZipSHA256){
    $bytes=Get-VerifiedSensorPayloadBytes $ZipFile $ExpectedZipSHA256 16777216
    Add-Type -AssemblyName System.IO.Compression
    $mem=[IO.MemoryStream]::new([byte[]]$bytes)
    $archive=[IO.Compression.ZipArchive]::new($mem,[IO.Compression.ZipArchiveMode]::Read,$false)
    $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $result=[Collections.Generic.List[object]]::new()
    [long]$sum=0
    try{
        if($archive.Entries.Count -ne 43){throw 'SENSOR_BACKEND_ZIP_ENTRY_COUNT'}
        foreach($entry in $archive.Entries){
            $name=[string]$entry.FullName
            if([string]::IsNullOrWhiteSpace($name) -or $name.Contains('\') -or
               $name.Contains(':') -or $name.StartsWith('/') -or
               [IO.Path]::IsPathRooted($name)){throw 'SENSOR_BACKEND_ZIP_UNSAFE_ENTRY'}
            $parts=@($name.Split('/'))
            foreach($part in $parts){
                if($part -ceq '.' -or $part -ceq '..' -or
                   $part.EndsWith('.') -or $part.EndsWith(' ') -or
                   $part -cnotmatch '^[A-Za-z0-9_.-]+$'){
                    throw 'SENSOR_BACKEND_ZIP_UNSAFE_ENTRY'
                }
            }
            if(-not $names.Add($name)){throw 'SENSOR_BACKEND_ZIP_DUPLICATE_ENTRY'}
            $fileType=($entry.ExternalAttributes -shr 16) -band 0xF000
            if($fileType -eq 0xA000){throw 'SENSOR_BACKEND_ZIP_LINK_REFUSED'}
            if($entry.Length -le 0 -or $entry.Length -gt 8388608){
                throw 'SENSOR_BACKEND_ZIP_FILE_SIZE'
            }
            $sum+=$entry.Length
            if($sum -gt 33554432){throw 'SENSOR_BACKEND_ZIP_TOTAL_SIZE'}
            $buffer=[byte[]]::new([int]$entry.Length)
            $input=$entry.Open()
            try{
                $offset=0
                while($offset -lt $buffer.Length){
                    $read=$input.Read($buffer,$offset,$buffer.Length-$offset)
                    if($read -le 0){throw 'SENSOR_BACKEND_ZIP_TRUNCATED_ENTRY'}
                    $offset+=$read
                }
                if($input.ReadByte() -ne -1){throw 'SENSOR_BACKEND_ZIP_UNDECLARED_EXTRA_DATA'}
            }finally{$input.Dispose()}
            $result.Add([pscustomobject]@{Rel=$name;Bytes=$buffer})
        }
        if(-not $names.Contains('LibreHardwareMonitorLib.dll')){
            throw 'SENSOR_BACKEND_ZIP_MISSING_LIBRARY'
        }
        return ,$result.ToArray()
    }finally{$archive.Dispose();$mem.Dispose()}
}

$BrokerPayload=Join-Path $PayloadDir 'TaskbarMonitorSensorBroker.exe'
$SupervisorPayload=Join-Path $PayloadDir 'TaskbarMonitorSensorSupervisor.exe'
$BackendRoot=Join-Path $AppRoot 'SensorBackend\LibreHardwareMonitor-0.9.6'
$LiveJson=Join-Path $AppRoot 'cpu_temp_broker.json'
$GpuJson=Join-Path $AppRoot 'gpu_temp_broker.json'
$StorageJson=Join-Path $AppRoot 'storage_temp_broker.json'
$SupervisorState=Join-Path $AppRoot 'sensor_supervisor_state.json'

$requiredOk=$true
foreach($required in @(
    $BrokerPayload,$SupervisorPayload,
    (Join-Path $BackendRoot 'LibreHardwareMonitorLib.dll')
)){
    if(-not(Test-Path -LiteralPath $required)){
        Write-Log "MISSING_PAYLOAD $required"
        $requiredOk=$false
    }
}
if(-not$requiredOk){
    Write-Result 'DEGRADED' 'Hardware sensor payload is incomplete. The main application can still run; protected temperature fields will show N/A.' 'NOT_STARTED' $null $false $false $false
    exit 0
}

# R297: NEVER execute a user-writable PawnIO installer from Temp under UAC.
# A forged PawnIO_setup.exe can be created after payload extraction, even if
# the official open-source PE carries no proprietary PawnIO resource.
# Only an already installed compatible PawnIO is reused; otherwise fail closed
# and request a separate, explicit upstream installer with user consent.
$existingPawn=Get-PawnIOVersion
$pawnAlreadyCompatible=$false
if($existingPawn){
    try{if([version]$existingPawn -ge [version]'2.2.0'){$pawnAlreadyCompatible=$true}}catch{}
}
if(-not $pawnAlreadyCompatible){
    $ActiveArchitecture='PAWNIO_EXTERNAL_INSTALL_REQUIRED'
    Write-Log 'PAWNIO_UPSTREAM_EXTERNAL_INSTALL_REQUIRED never executing mutable Temp PawnIO binary under UAC'
    Write-Result 'DEGRADED' ('Optional protected hardware sensors require the official PawnIO 2.2.0 driver, installed separately with user consent from https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0 . The main application works without it and unavailable temperatures show N/A. No driver or protected sensor service was modified.') 'EXTERNAL_INSTALL_REQUIRED' $null $false $false $false
    exit 0
}

# R294: Verify pinned embedded identity before touching protected services.
try{
    $VerifiedBrokerBytes=Get-VerifiedSensorPayloadBytes $BrokerPayload $ExpectedBrokerSHA256 16777216
    $VerifiedSupervisorBytes=Get-VerifiedSensorPayloadBytes $SupervisorPayload $ExpectedSupervisorSHA256 16777216
    $VerifiedBackendEntries=Get-VerifiedSensorBackendEntries (Join-Path $PayloadDir 'LibreHardwareMonitor.zip') $ExpectedBackendZipSHA256
}catch{
    Write-Log ('SENSOR_PAYLOAD_PROVENANCE_REFUSED '+$_.Exception.Message)
    Write-Result 'DEGRADED' 'Protected sensor payload provenance not verified; prior service preserved.' 'NOT_STARTED' $null $false $false $false
    exit 0
}
if(-not(Capture-PreviousSensorLayer)){
    $ActiveArchitecture='PREVIOUS_SENSOR_LAYER_UNCHANGED'
    Write-Result 'DEGRADED' 'Setup could not capture a rollback snapshot of the existing protected sensor layer, so it did not modify that layer.' 'NOT_STARTED' $null $false $false $false
    exit 0
}
# R308: preserve old protected bytes and task XML BEFORE writing ownership
# markers, stopping tasks or replacing protected files.
try{
    $parent=[IO.Path]::GetDirectoryName($SensorJournalRoot)
    Assert-SensorBoundaryNoReparse $parent
    if(-not [IO.Directory]::Exists($parent)){
        [void][IO.Directory]::CreateDirectory($parent)
    }
    Assert-SensorJournalTrustedAcl $parent $false
    $expectedNew=[Collections.Generic.List[string]]::new()
    foreach($name in @('TaskbarMonitorSensorBroker.exe','TaskbarMonitorSensorSupervisor.exe','.tbme-owner.sid')){
        $expectedNew.Add($name)
    }
    foreach($verified in $VerifiedBackendEntries){
        $expectedNew.Add(([string]$verified.Rel).Replace('/','\'))
    }
    New-SensorDurableJournal $SensorJournalRoot $validatedSensorSid $RollbackFiles $RollbackTaskXmlText $expectedNew.ToArray() ([IO.Directory]::Exists($BrokerRoot))
    Write-Log 'R308_DURABLE_READY_VERIFIED_BEFORE_PROTECTED_MUTATION'
}catch{
    Clear-SensorRollbackBuffer
    Write-Log ('R308_PROTECTED_JOURNAL_PREWRITE_REFUSED '+$_.Exception.Message)
    Write-Result 'DEGRADED' 'Protected sensor snapshot could not be durably verified before mutation; prior protected services were preserved.' 'NOT_STARTED' $null $false $false $false
    exit 0
}

$pawnStatus='ALREADY_PRESENT'
$pawnExit=$null
$rebootRequired=$false
Write-Log "PAWNIO_ALREADY_PRESENT version=$existingPawn"

# R303: publish protected SID ownership BEFORE unregistering the old task.
# The marker is never accepted from writable Temp/AppData and is exclusive.
function Assert-OrRecordSensorOwner {
    Assert-SensorBoundaryNoReparse $BrokerRoot
    Assert-SensorBoundaryNoReparse $SensorOwnerMarker
    if(Test-Path -LiteralPath $SensorOwnerMarker){
        if([IO.File]::ReadAllText($SensorOwnerMarker,[Text.Encoding]::ASCII).Trim() -cne $validatedSensorSid){
            throw 'PROTECTED_SENSOR_OWNER_MARKER_MISMATCH'
        }
        return
    }
    [void][IO.Directory]::CreateDirectory($BrokerRoot)
    Assert-SensorBoundaryNoReparse $SensorOwnerMarker
    $bytes=[Text.Encoding]::ASCII.GetBytes($validatedSensorSid)
    $stream=[IO.FileStream]::new($SensorOwnerMarker,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}
    finally{$stream.Dispose()}
}
try{
    Assert-OrRecordSensorOwner
}catch{
    Write-Log ('PROTECTED_SENSOR_OWNER_MARKER_SETUP_REFUSED '+$_.Exception.Message)
    Write-Result 'DEGRADED' 'Protected sensor ownership could not be persisted before modification; existing services were preserved.' 'NOT_STARTED' $null $false $false $false
    exit 0
}
$taskInstalled=$false
try{
    Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    $drainDeadline=(Get-Date).AddSeconds(5)
    do{
        Start-Sleep -Milliseconds 250
        $remaining=@(Get-Process TaskbarMonitorSensorSupervisor,TaskbarMonitorSensorBroker -ErrorAction SilentlyContinue)
    }while($remaining.Count -gt 0 -and (Get-Date) -lt $drainDeadline)
    if($remaining.Count -gt 0){
        throw ('SENSOR_PROCESS_DRAIN_FAILED pids='+($remaining.Id -join ','))
    }
    Remove-Item -LiteralPath $LiveJson,$GpuJson,$StorageJson,$SupervisorState -Force -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Force -Path $BrokerRoot|Out-Null
    [IO.File]::WriteAllBytes((Join-Path $BrokerRoot 'TaskbarMonitorSensorBroker.exe'),$VerifiedBrokerBytes)
    [IO.File]::WriteAllBytes((Join-Path $BrokerRoot 'TaskbarMonitorSensorSupervisor.exe'),$VerifiedSupervisorBytes)

    foreach($verified in $VerifiedBackendEntries){
        $destination=Join-Path $BrokerRoot ($verified.Rel.Replace('/','\'))
        Assert-SensorBoundaryNoReparse $destination
        $parent=Split-Path -Parent $destination
        if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
        Assert-SensorBoundaryNoReparse $destination
        [IO.File]::WriteAllBytes($destination,[byte[]]$verified.Bytes)
    }

    Import-Module ScheduledTasks
    $SupervisorExe=Join-Path $BrokerRoot 'TaskbarMonitorSensorSupervisor.exe'
    $BrokerExe=Join-Path $BrokerRoot 'TaskbarMonitorSensorBroker.exe'
    $Action=New-ScheduledTaskAction -Execute $SupervisorExe -Argument ('--broker "'+$BrokerExe+'" --output "'+$LiveJson+'"')
    $Trigger=New-ScheduledTaskTrigger -AtLogOn -User $UserId
    $Principal=New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Highest
    $Settings=New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force|Out-Null
    Start-ScheduledTask -TaskName $TaskName
    $taskInstalled=$true
    Write-Log 'SUPERVISOR_TASK_INSTALLED_AND_STARTED restartCount=3 restartInterval=PT1M multipleInstances=IgnoreNew'
}catch{
    Write-Log ('SUPERVISOR_TASK_SETUP_WARNING '+$_.Exception.ToString())
    Restore-PreviousSensorLayer 'TASK_SETUP_EXCEPTION'|Out-Null
    $taskInstalled=$false
}

$healthy=$false
$currentC=$null
if($taskInstalled -and -not$rebootRequired){
    for($i=0;$i -lt 90;$i++){
        Start-Sleep -Milliseconds 500
        $task=Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        $supervisor=@(Get-Process TaskbarMonitorSensorSupervisor -ErrorAction SilentlyContinue)

        if($task -and [string]$task.State -eq 'Running' -and $supervisor.Count -eq 1){
            try{
                if(Test-Path -LiteralPath $SupervisorState){
                    $state=Get-Content -LiteralPath $SupervisorState -Raw|ConvertFrom-Json
                    $stateTs=[datetime]::Parse([string]$state.TimestampUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
                    $stateAge=([datetime]::UtcNow-$stateTs).TotalSeconds
                    $version=[string]$state.BrokerVersion
                    $supervisorVersion=[string]$state.SupervisorVersion
                    $CpuTransportHealthy=[bool]$state.CpuTransportHealthy
                    $GpuTransportHealthy=[bool]$state.GpuTransportHealthy
                    $StorageTransportHealthy=[bool]$state.StorageTransportHealthy
                    $JobContainmentHealthy=(
                        [bool]$state.ChildJobKillOnClose -and
                        [bool]$state.CpuJobContained -and
                        [bool]$state.GpuJobContained -and
                        [bool]$state.StorageJobContained
                    )
                    $SupervisorHealthy=(
                        $stateAge -ge 0 -and $stateAge -lt 15 -and
                        $version -eq '1.1.2+r21' -and
                        $supervisorVersion -eq '1.3.0+r33' -and
                        $JobContainmentHealthy -and
                        $CpuTransportHealthy -and $GpuTransportHealthy -and $StorageTransportHealthy
                    )
                }
            }catch{
                $SupervisorHealthy=$false
            }

            try{
                if(Test-Path -LiteralPath $LiveJson){
                    $j=Get-Content -LiteralPath $LiveJson -Raw|ConvertFrom-Json
                    $ts=[datetime]::Parse([string]$j.TimestampUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
                    $age=([datetime]::UtcNow-$ts).TotalSeconds
                    $sensorName=[string]$j.Sensor
                    $current=[double]$j.CurrentC
                    if([bool]$j.Available -eq $true -and
                       [bool]$j.Is64BitProcess -eq $true -and
                       [bool]$j.IsElevated -eq $true -and
                       -not[String]::IsNullOrWhiteSpace($sensorName) -and
                       $current -gt 0 -and $current -lt 130 -and
                       $age -lt 15){
                        $healthy=$true
                        $CpuDataAvailable=$true
                        $currentC=$current
                    }
                }
            }catch{}

            if($SupervisorHealthy -and $healthy){
                Write-Log ("R33_READY_MATCH supervisor="+$supervisorVersion+" brokerProtocol="+$version+" cpu="+$currentC+" jobContainment="+$JobContainmentHealthy+" cpuTransport="+$CpuTransportHealthy+" gpuTransport="+$GpuTransportHealthy+" storageTransport="+$StorageTransportHealthy)
                break
            }
        }
    }
}

if($taskInstalled -and -not$SupervisorHealthy -and -not$rebootRequired){
    Restore-PreviousSensorLayer 'R21_HEALTH_GATE_FAILED'|Out-Null
    $taskInstalled=$false
}

if($RollbackPerformed){
    if($RollbackSucceeded){
        Clear-SensorRollbackBuffer
        Write-Log 'R21_INSTALL_DEGRADED_ROLLED_BACK'
        Write-Result 'DEGRADED_ROLLED_BACK' 'R21 protected sensor validation did not pass, so the previous protected sensor layer was restored automatically. The main application remains usable; use Repair protected sensors to retry R21 later.' $pawnStatus $pawnExit $false $false $false
    }else{
        Write-Log 'R21_INSTALL_DEGRADED_ROLLBACK_FAILED'
        Write-Result 'DEGRADED_ROLLBACK_FAILED' 'R21 protected sensor validation did not pass and automatic rollback also failed. The main application remains usable, but protected telemetry requires repair.' $pawnStatus $pawnExit $false $false $false
    }
    exit 0
}

# Retire the in-memory snapshot after a successful terminal path.
Clear-SensorRollbackBuffer
if($SupervisorHealthy -and $healthy){
    Write-Log "R21_SENSOR_READY cpu=$currentC"
    Write-Result 'READY' 'R21 protected sensor supervisor is healthy across CPU, GPU and storage lanes; CPU temperature data is active.' $pawnStatus $pawnExit $false $taskInstalled $true
}elseif($SupervisorHealthy){
    Write-Log 'R21_SENSOR_TRANSPORT_READY_DATA_DEGRADED'
    Write-Result 'DEGRADED_DATA' 'The R21 protected sensor supervisor is healthy across CPU, GPU and storage lanes, but CPU temperature data is not currently available on this machine.' $pawnStatus $pawnExit $false $taskInstalled $false
}elseif($rebootRequired){
    Write-Log 'SENSOR_REBOOT_REQUIRED'
    Write-Result 'REBOOT_REQUIRED' 'The application installed successfully. Restart Windows to finish activating CPU temperature monitoring.' $pawnStatus $pawnExit $true $taskInstalled $false
}elseif($pawnStatus -eq 'TIMEOUT'){
    Write-Log 'SENSOR_DEGRADED pawnio-timeout'
    Write-Result 'DEGRADED' 'The application installed successfully, but the PawnIO driver installer timed out. CPU temperature will show N/A until the sensor layer is repaired.' $pawnStatus $pawnExit $false $taskInstalled $false
}elseif($pawnStatus -eq 'FAILED' -or $pawnStatus -eq 'EXCEPTION'){
    Write-Log "SENSOR_DEGRADED pawnio=$pawnStatus"
    Write-Result 'DEGRADED' 'The application installed successfully, but CPU temperature could not be activated on this machine. Other monitoring features remain available.' $pawnStatus $pawnExit $false $taskInstalled $false
}elseif(-not$taskInstalled){
    Write-Log 'SENSOR_DEGRADED task-not-installed'
    Write-Result 'DEGRADED' 'The application installed successfully, but the protected sensor task could not be created. CPU temperature will show N/A.' $pawnStatus $pawnExit $false $false $false
}else{
    Write-Log ("R21_SUPERVISOR_UNAVAILABLE_AFTER_STARTUP_WINDOW cpuTransport="+$CpuTransportHealthy+" gpuTransport="+$GpuTransportHealthy+" storageTransport="+$StorageTransportHealthy)
    Write-Result 'UNAVAILABLE' 'The application installed successfully, but the R21 protected sensor supervisor did not reach a fresh healthy state across all worker lanes in time. Use Diagnostics > Repair protected sensors.' $pawnStatus $pawnExit $false $taskInstalled $false
}
exit 0
