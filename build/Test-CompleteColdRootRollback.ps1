[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$Machine)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Disposable GitHub-hosted Windows ONLY. Never call from any owner workstation.
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:GITHUB_REPOSITORY -cne 'GOD13emad/TaskbarMonitorEnhanced' -or
   $env:GITHUB_REF -cne 'refs/heads/audit/r232-ownerlike-cold-rollback' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
   $env:COMPUTERNAME -match '(?i)EMAD|ALI|LAPTOP'){
   throw 'R232_REFUSE_NON_FRESH_DISPOSABLE_GITHUB_WINDOWS'
}
$repo='GOD13emad/TaskbarMonitorEnhanced'
$app=Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced'
$main=Join-Path $app 'TaskbarMonitorEnhanced.exe'
$reg='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TaskbarMonitorEnhanced'
$expectedOfficial='84D5DBF6F2E6D1D2E2B3E6D9C9DA523E564A7F5240C08D34A456D934026B829F'
$expectedSetup='225BCC259C392DA04F3E0157CAF22F96C4052282AAF02555E6F6E777F4CB8AF4'
$work=Join-Path $env:RUNNER_TEMP ('TBME_R232_COLD_'+$Machine)
$receipt=Join-Path $work 'R232_REAL_INSTALLED_COLD_ROLLBACK.json'
$archive=Join-Path $work 'COLD_INSTALL_ROOT.zip'
$isolated=Join-Path $work 'isolated-restore'
$before=Join-Path $work 'mutated-installed-root'
$status='FAIL';$stage='PRESTATE';$failure=''
$quiescent=$false;$archiveSHA='';$sourceCount=0;$sandboxRestored=$false
$replacementExercised=$false;$actualRootRestored=$false
$extraNeeded=0;$existing=@{};$rejected=$false;$installed=$false
$originalMap=@{};$registryBefore=$null
function Fail([string]$why){throw ('R232_'+$why)}
function SHA([string]$file){
    if(!(Test-Path -LiteralPath $file -PathType Leaf)){return 'MISSING'}
    return (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
}
function Count-AppProcesses {
    return @((Get-Process -ErrorAction SilentlyContinue|Where-Object {
        $_.ProcessName -in @('TaskbarMonitorEnhanced','TaskbarMonitorSensorBroker',
                            'TaskbarMonitorSensorSupervisor')
    })).Count
}
function RegistrySnapshot {
    if(!(Test-Path -LiteralPath $reg)){Fail 'UNINSTALL_REGISTRATION_MISSING'}
    $v=Get-ItemProperty -LiteralPath $reg -ErrorAction Stop
    if($v.DisplayVersion -cne '1.7.2' -or $v.InstallLocation -cne $app){
        Fail 'OFFICIAL_INSTALLED_VERSION_OR_ROOT_WRONG'
    }
    $run=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
    $entry=if($null -ne $run -and $null -ne $run.PSObject.Properties['TaskbarMonitorEnhanced']){
       [string]$run.TaskbarMonitorEnhanced
    }else{'ABSENT'}
    return [ordered]@{DisplayName=[string]$v.DisplayName;Version=[string]$v.DisplayVersion
        InstallLocation=[string]$v.InstallLocation;UninstallString=[string]$v.UninstallString
        Startup=$entry}
}
function FileMap([string]$root){
    $records=@{}
    $files=@(Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction Stop)
    if($files.Count -lt 40 -or $files.Count -gt 5000){Fail 'FILE_COUNT_OUT_OF_BOUND'}
    $dirs=@(Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -ErrorAction Stop)
    if(@($dirs|Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count -gt 0){
        Fail 'REPARSE_DIRECTORY_NOT_SUPPORTED'
    }
    $total=0
    foreach($f in $files){
        if($f.Attributes -band [IO.FileAttributes]::ReparsePoint){Fail 'SYMLINK_IN_GUEST_APP'}
        $rel=$f.FullName.Substring($root.Length).TrimStart('\').Replace('\','/')
        if(!$rel -or $rel.Contains('..') -or $records.ContainsKey($rel)){Fail 'INVALID_ZIP_FILE_NAME'}
        $total+=$f.Length
        if($total -gt 536870912){Fail 'APP_ROOT_OVER_512MIB'}
        $records[$rel]=[ordered]@{Bytes=[long]$f.Length;SHA256=(SHA $f.FullName)}
    }
    return $records
}
function EqualMaps($first,$second){
    if($first.Count -ne $second.Count){Fail ('ROOT_FILE_COUNT_CHANGED_'+$first.Count+'_'+$second.Count)}
    foreach($k in $first.Keys){
        if(!$second.ContainsKey($k) -or
           $first[$k].SHA256 -cne $second[$k].SHA256 -or
           [long]$first[$k].Bytes -ne [long]$second[$k].Bytes){
            Fail ('ROOT_BACKUP_MAP_NOT_IDENTICAL_'+$k)
        }
    }
}
function CheckArchive([string]$zip,$snapshot){
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    $z=[IO.Compression.ZipFile]::OpenRead($zip)
    try{
        $seen=@{}
        foreach($e in $z.Entries){
            if(!$e.Name){continue}
            $rel=[string]$e.FullName
            if(!$snapshot.ContainsKey($rel) -or $seen.ContainsKey($rel) -or
               $rel.Contains('..') -or $rel.StartsWith('/')){Fail 'ARCHIVE_MEMBER_SET_WRONG'}
            $s=$e.Open()
            $hasher=[Security.Cryptography.SHA256]::Create()
            try{
                $checksum=[Convert]::ToHexString($hasher.ComputeHash($s))
            }finally{$hasher.Dispose();$s.Dispose()}
            if($checksum -cne $snapshot[$rel].SHA256 -or $e.Length -ne $snapshot[$rel].Bytes){
                Fail ('ARCHIVE_MEMBER_SHA_MISMATCH_'+$rel)
            }
            $seen[$rel]=$true
        }
        if($seen.Count -ne $snapshot.Count){Fail 'ARCHIVE_MISSING_MEMBERS'}
    }finally{$z.Dispose()}
}
function Run-Installer([string]$path,[string]$arg,[int]$timeout){
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$path;$psi.Arguments=$arg;$psi.UseShellExecute=$false
    $psi.WorkingDirectory=(Split-Path $path -Parent)
    $p=[Diagnostics.Process]::Start($psi)
    if(!$p){Fail 'INSTALLER_PROCESS_NOT_CREATED'}
    try{
        if(!$p.WaitForExit($timeout)){Fail 'INSTALLER_TIMED_OUT'}
        if($p.ExitCode -ne 0){Fail ('INSTALLER_EXIT_'+$p.ExitCode)}
    }finally{$p.Dispose()}
}
try {
    if((Test-Path $app) -or (Test-Path $reg) -or (Count-AppProcesses) -ne 0){
        Fail 'GUEST_NOT_FRESH_OR_USER_STATE_PRESENT'
    }
    if(Test-Path $work){Fail 'R232_WORK_PREEXISTS_NO_BLIND_RERUN'}
    New-Item -ItemType Directory -Path $work -ErrorAction Stop|Out-Null
    $stage='DOWNLOAD_OFFICIAL_SETUP'
    & gh release download v1.7.2 --repo $repo --pattern TaskbarMonitorEnhanced_Setup_1.7.2.exe --dir $work
    if($LASTEXITCODE -ne 0){Fail 'OFFICIAL_SETUP_DOWNLOAD_FAILED'}
    $setup=Join-Path $work 'TaskbarMonitorEnhanced_Setup_1.7.2.exe'
    if((SHA $setup) -cne $expectedSetup){Fail 'SETUP_IMMUTABLE_SHA_DRIFT'}
    $stage='REAL_GUEST_INSTALL'
    Run-Installer $setup '/install /quiet /desktop=0 /startup=0' 190000
    if((SHA $main) -cne $expectedOfficial){Fail 'FRESH_INSTALLED_MAIN_SHA'}
    $installed=$true
    $registryBefore=RegistrySnapshot
    if((Count-AppProcesses) -ne 0){Fail 'APP_OR_SENSORS_NOT_QUIESCENT_AFTER_INSTALL'}
    $stage='SEED_DISPOSABLE_USER_DATA'
    foreach($entry in @(
        @{Rel='R232OwnerData/user-preserve.txt';Text='R232 exact user protected sentinel'},
        @{Rel='R232OwnerData/unknown.bin';Text='opaque synthetic contents'},
        @{Rel='Logs/R232-historical.log';Text='R232 historical custom log preserved'},
        @{Rel='Updates/R232-owner-state.json';Text='{"owner":"synthetic"}'},
        @{Rel='Release/R232-custom.txt';Text='R232 synthetic historical release'}
    )){
        $path=Join-Path $app $entry.Rel
        if(Test-Path $path){Fail 'SEED_FILE_PREEXISTS'}
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force|Out-Null
        [IO.File]::WriteAllText($path,$entry.Text,[Text.UTF8Encoding]::new($false))
    }
    $cfg=Join-Path $app 'config.json'
    $bak=Join-Path $app 'config.json.bak'
    if(!(Test-Path $cfg)){[IO.File]::WriteAllText($cfg,'{"GlassMode":false,"Opacity":0.1,"Theme":"Retro Terminal"}',[Text.UTF8Encoding]::new($false))}
    if(!(Test-Path $bak)){Copy-Item -LiteralPath $cfg -Destination $bak}

    # Grow a real installed official guest root with unknown but fully synthetic data.
    # The owner's private filenames and contents never leave their PC.
    $existing=FileMap $app
    $extraNeeded=442-$existing.Count
    if($extraNeeded -lt 250 -or $extraNeeded -gt 410){Fail ('FIXTURE_UNEXPECTED_OFFICIAL_ROOT_COUNT_'+$existing.Count)}
    for($i=0;$i -lt $extraNeeded;$i++){
        $category=if($i -lt 245){'historical-temp'}elseif($i % 2 -eq 0){'unknown-user'}else{'historical-files'}
        $rel=('R232Opaque/'+$category+'/payload_'+$i.ToString('D4')+'.dat')
        $path=Join-Path $app $rel
        if(Test-Path -LiteralPath $path){Fail 'OPAQUE_SEED_PREEXISTS'}
        [void](New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force -ErrorAction Stop)
        if($i -eq 0){$data=[byte[]]::new(50*1024*1024)}
        else{
            $data=[byte[]]::new(73+($i%443))
            for($j=0;$j -lt $data.Length;$j++){$data[$j]=[byte](($i+$j)%251)}
        }
        [IO.File]::WriteAllBytes($path,$data)
        if($i -eq 1){[IO.File]::SetAttributes($path,[IO.FileAttributes]::Hidden)}
        if($i -eq 2){[IO.File]::SetAttributes($path,[IO.FileAttributes]::ReadOnly)}
    }
    $empty=Join-Path $app 'R232Opaque/empty-user-folder'
    if(Test-Path $empty){Fail 'OPAQUE_EMPTY_FOLDER_ALREADY_EXISTS'}
    [void](New-Item -ItemType Directory -Path $empty -ErrorAction Stop)
    if((FileMap $app).Count -ne 442){Fail 'GUEST_OWNERLIKE_EXACT_442_FILES_NOT_PROVEN'}
    $stage='TAKE_QUIESCENT_COLD_SNAPSHOT'
    if((Count-AppProcesses) -ne 0){Fail 'APP_NOT_QUIESCENT_BEFORE_SNAPSHOT'}
    $quiescent=$true
    $originalMap=FileMap $app
    $sourceCount=$originalMap.Count
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($app,$archive,[IO.Compression.CompressionLevel]::Optimal,$false)
    if(!(Test-Path $archive)){Fail 'COLD_ARCHIVE_MISSING'}
    CheckArchive $archive $originalMap
    EqualMaps $originalMap (FileMap $app)
    $archiveSHA=SHA $archive
    $stage='ISOLATED_ACTUAL_INSTALL_ROOT_RESTORE'
    [IO.Compression.ZipFile]::ExtractToDirectory($archive,$isolated)
    EqualMaps $originalMap (FileMap $isolated)
    $sandboxRestored=$true

    if(!(Test-Path -LiteralPath (Join-Path $isolated 'R232Opaque/empty-user-folder') -PathType Container)){
        Fail 'ISOLATED_EMPTY_USER_FOLDER_MISSING'
    }
    # Hostile path traversal archive must be rejected *before* any extraction.
    $hostile=Join-Path $work 'R232_HOSTILE_TRAVERSAL.zip'
    $attackZip=[IO.Compression.ZipFile]::Open($hostile,[IO.Compression.ZipArchiveMode]::Create)
    try{
        $attackEntry=$attackZip.CreateEntry('../escape.txt')
        $attackStream=$attackEntry.Open()
        try{$attackStream.WriteByte([byte]1)}finally{$attackStream.Dispose()}
    }finally{$attackZip.Dispose()}
    $rejected=$false
    try{ CheckArchive $hostile $originalMap }
    catch{if($_.Exception.Message -match 'R232_ARCHIVE_MEMBER_SET_WRONG'){$rejected=$true}else{throw}}
    if(!$rejected){Fail 'HOSTILE_TRAVERSAL_NOT_REJECTED'}
    $stage='INJECT_DISPOSABLE_GUEST_BINARY_CORRUPTION'
    # Sacrificial guest executable: deliberately corrupt one byte before restoring the
    # complete original official root. No candidate binary is distributed or installed
    # on an owner's machine in this test.
    $binary=[IO.File]::ReadAllBytes($main)
    if($binary.Length -lt 8193){Fail 'OFFICIAL_GUEST_BINARY_UNEXPECTEDLY_SHORT'}
    $binary[8192]=[byte]($binary[8192] -bxor 1)
    [IO.File]::WriteAllBytes($main,$binary)
    if((SHA $main) -ceq $expectedOfficial){Fail 'GUEST_MUTATION_NOT_OBSERVED'}
    $replacementExercised=$true
    if((Count-AppProcesses) -ne 0){Fail 'APP_NOT_QUIESCENT_BEFORE_RESTORE'}
    $stage='REPLACE_EXACT_GUEST_ROOT_FROM_COLD_ARCHIVE'
    if(Test-Path $before){Fail 'GUEST_REPLACED_DIRECTORY_ALREADY_EXISTS'}
    Move-Item -LiteralPath $app -Destination $before -ErrorAction Stop
    [IO.Compression.ZipFile]::ExtractToDirectory($archive,$app)
    EqualMaps $originalMap (FileMap $app)
    if((SHA $main) -cne $expectedOfficial){Fail 'RESTORED_ORIGINAL_OFFICIAL_SHA_DIFFERENT'}
    if(!(Test-Path -LiteralPath (Join-Path $app 'R232Opaque/empty-user-folder') -PathType Container)){Fail 'GUEST_EMPTY_FOLDER_NOT_RESTORED'}
    $afterReg=RegistrySnapshot
    if(($afterReg|ConvertTo-Json -Compress) -cne ($registryBefore|ConvertTo-Json -Compress)){
        Fail 'GUEST_INSTALL_REGISTRY_CHANGED'
    }
    if((SHA (Join-Path $app 'R232OwnerData/user-preserve.txt')) -cne
       (SHA (Join-Path $isolated 'R232OwnerData/user-preserve.txt'))){
        Fail 'GUEST_CUSTOM_USER_DATA_NOT_RESTORED'
    }
    $actualRootRestored=$true
    $status='PASS_R232_DISPOSABLE_REAL_442_FILE_COLD_ARCHIVE_AND_ISOLATED_RESTORE'
    $stage='ACCEPTED'
}catch {
    $failure=$_.Exception.GetType().Name+': '+$_.Exception.Message
}finally{
    if(Test-Path $work){
        $result=[ordered]@{
           Revision='R232';Host=$Machine;Status=$status;Phase=$stage;Failure=$failure
           GitHubTestCommit=$env:GITHUB_SHA;OfficialSetupSHA256=$expectedSetup
           OfficialInstalledBaselineMainSHA256=$expectedOfficial
           MutatedGuestMain='ONE_BYTE_FLIP_ONLY_DISPOSABLE'
           UserPersonalComputerTouched=$false
           ActualOfficial172FreshInstall=$installed
           OriginalAppRootPath=$app;GuestQuiescentBeforeBackup=$quiescent
           ExactSourceFilesBackedUp=$sourceCount
           SyntheticUnknownExtraFiles=$extraNeeded
           SyntheticOriginalInstalledFiles=$existing.Count
           OwnerlikeExact442Files=($sourceCount -eq 442)
           HostilePathTraversalRejected=$rejected
           EmptyUserFolderRestored=$actualRootRestored
           CompleteArchiveSHA256=$archiveSHA
           AllArchiveMembersSHA256Checked=$sandboxRestored
           IsolatedRestoreAllFileBytesExact=$sandboxRestored
           GuestInstalledMainActuallyReplacedWithTrial=$replacementExercised
           ActualGuestInstalledRootRestoredFromArchive=$actualRootRestored
           OwnerProtectedCanaryPreserved=$actualRootRestored
           InstallerHKCURegistrationPreserved=$actualRootRestored
           OfficialUninstallRegistrationStillOneRoot=$actualRootRestored
           PersonalOwnerFullColdBackupAccepted=$false
           NoPublicReleaseMutation=$true
           TimestampUTC=[DateTime]::UtcNow.ToString('o')
        }
        [IO.File]::WriteAllText($receipt,($result|ConvertTo-Json -Depth 7),
                               [Text.UTF8Encoding]::new($false))
        Write-Output ($result|ConvertTo-Json -Depth 7 -Compress)
    }
}
if($status -cne 'PASS_R232_DISPOSABLE_REAL_442_FILE_COLD_ARCHIVE_AND_ISOLATED_RESTORE'){
    throw ('R232_FAIL_CLOSED_'+$stage+' '+$failure)
}
