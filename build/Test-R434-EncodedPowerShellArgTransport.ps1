[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SetupPath,
    [Parameter(Mandatory=$true)][string]$SourceRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -cne 'Desktop'){
    throw 'R434_REQUIRES_NATIVE_WINPS51_NETFRAMEWORK'
}
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
$SetupPath=[IO.Path]::GetFullPath($SetupPath)
if(!(Test-Path -LiteralPath $SetupPath -PathType Leaf) -or
   !(Test-Path -LiteralPath (Join-Path $SourceRoot 'installer/TaskbarMonitorEnhanced_Setup.cs'))){
    throw 'R434_COMPILED_SETUP_OR_SOURCE_MISSING'
}
$hashBefore=(Get-FileHash -LiteralPath $SetupPath -Algorithm SHA256).Hash
$asm=[Reflection.Assembly]::LoadFrom($SetupPath)
$setupType=$asm.GetType('SetupProgram',$true)
$method=$setupType.GetMethod('BuildElevatedSensorLaunch',
    [Reflection.BindingFlags]'Static,NonPublic')
if(!$method){throw 'R434_COMPILED_BUILDER_MISSING'}
$fields=@(
    @{
        Mode='Install'
        Payload="C:\Test\test' ; Write-Output R434_SENTINEL_PAYLOAD ; #"
        Root='C:\Users\Example & (Fake)\AppData\Local\TaskbarMonitorEnhanced\'
        User='S-1-5-21-1234-$($R434_SENTINEL_USER)-"'
    },
    @{
        Mode='Uninstall'
        Payload='C:\Temp\Carets ^ & pipes | redirection > sentinel;'
        Root='C:\Users\O''Brien ! %test%\AppData\Local\TaskbarMonitorEnhanced'
        User='S-1-5-21-12345-67890-24680-1001''; Write-Output R434_SENTINEL_USER; #'
    }
)
foreach($case in $fields){
    $call=New-Object 'object[]' 4
    $call[0]=[string]$case.Mode
    $call[1]=[string]$case.Payload
    $call[2]=[string]$case.Root
    $call[3]=[string]$case.User
    $launch=$null
    try{
        $launch=$method.Invoke($null,$call)
        if($null -eq $launch){throw 'R434_LAUNCH_OBJECT_MISSING'}
        $psi=[Diagnostics.ProcessStartInfo]$launch.ProcessInfo
        if(!$psi.UseShellExecute -or $psi.Verb -cne 'runas' -or
           ![IO.Path]::IsPathRooted($psi.FileName) -or
           (Split-Path $psi.FileName -Leaf) -cne 'powershell.exe'){
            throw 'R434_UNEXPECTED_EXECUTABLE_OR_ELEVATION_METADATA'
        }
        if($psi.Arguments -cnotmatch '\A-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ([A-Za-z0-9+/=]+)\z'){
            throw 'R434_COMMAND_LINE_CONTAINS_UNTRUSTED_LITERAL_OR_SWITCHES'
        }
        $payload=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1]))
        if($payload.Contains('R434_SENTINEL_') -or $payload.Contains([string]$case.Payload) -or
           $payload.Contains([string]$case.Root) -or $payload.Contains([string]$case.User)){
            throw 'R434_UNTRUSTED_INPUT_INTERPOLATED_IN_POWERSHELL_SOURCE'
        }
        $tokens=$null;$parseErrors=$null
        [void][Management.Automation.Language.Parser]::ParseInput($payload,[ref]$tokens,[ref]$parseErrors)
        if(@($parseErrors).Count -ne 0){throw 'R434_ENCODED_BOOTSTRAP_PARSE_ERRORS'}
        $re=[regex]::new("\[Convert\]::FromBase64String\('(?<value>[A-Za-z0-9+/=]+)'\)")
        $found=$re.Matches($payload)
        if($found.Count -ne 3){throw ('R434_EXPECTED_EXACT_THREE_DATA_ONLY_BASE64_TRANSPORTS_'+$found.Count)}
        $decoded=@(foreach($x in $found){
            [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$x.Groups['value'].Value))
        })
        for($i=0;$i -lt 3;$i++){
            $want=@([string]$case.Payload,[string]$case.Root,[string]$case.User)[$i]
            if($decoded[$i] -cne $want){throw ('R434_UNTRUSTED_VALUE_TRANSPORT_CORRUPTED_'+$i)}
        }
        if($payload -cnotmatch ("-Mode '"+[regex]::Escape([string]$case.Mode)+"'")){
            throw 'R434_ALLOWED_MODE_NOT_BOUND'
        }
        'R434_PASS_COMPILED_'+$case.Mode.ToUpperInvariant()+'_THREE_UNTRUSTED_STRINGS_BASE64_ONLY'
    }finally{
        if($null -ne $launch){$launch.Dispose()}
    }
}
foreach($badMode in @("Install';Write-Output R434_SENTINEL;#", 'install', '', 'Repair')){
    $args=New-Object 'object[]' 4
    $args[0]=$badMode;$args[1]='C:\Temp\fixture';$args[2]='C:\Users\Fake\AppData\Local\TaskbarMonitorEnhanced';$args[3]='S-1-5-21-1'
    $rejected=$false
    $unused=$null
    try{$unused=$method.Invoke($null,$args)}
    catch {
        $err=$_.Exception
        while($null -ne $err){
            if($err -is [IO.InvalidDataException]){
                $rejected=$true
                break
            }
            $err=$err.InnerException
        }
        if(!$rejected){throw}
    }
    if($unused -is [IDisposable]){$unused.Dispose()}
    if(!$rejected){throw ('R434_MODE_INJECTION_NOT_REJECTED_'+$badMode)}
}
'R434_PASS_FOUR_NON_ALLOWLISTED_MODE_ATTEMPTS_REJECTED_BEFORE_PIPE_CREATION'
$cleanupMethod=$setupType.GetMethod('BuildDeferredUninstallCleanupProcessInfo',
    [Reflection.BindingFlags]'Static,NonPublic')
if(!$cleanupMethod){throw 'R434_CLEANUP_BUILDER_MISSING'}
$canonical=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'TaskbarMonitorEnhanced'
$good=New-Object 'object[]' 3
$good[0]=[string]$canonical;$good[1]=[int]([Diagnostics.Process]::GetCurrentProcess().Id)
$good[2]=[long][DateTime]::UtcNow.Ticks
$cleanup=[Diagnostics.ProcessStartInfo]$cleanupMethod.Invoke($null,$good)
if($cleanup.UseShellExecute -or
   $cleanup.Verb -eq 'runas' -or
   (Split-Path $cleanup.FileName -Leaf) -cne 'powershell.exe'){
    throw 'R434_DEFERRED_CLEANUP_PROCESS_BOUNDARY_CHANGED'
}
if($cleanup.Arguments -cnotmatch '\A-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ([A-Za-z0-9+/=]+)\z'){
    throw 'R434_DEFERRED_CLEANUP_UNTRUSTED_ARGUMENT_OR_BAD_SWITCH'
}
$decodedCleanup=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1]))
$rootBase64=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($canonical))
if(!$decodedCleanup.Contains("'"+$rootBase64+"'") -or
   $decodedCleanup.Contains($canonical) -or $decodedCleanup.Contains('__ROOT_B64__')){
    throw 'R434_DEFERRED_CLEANUP_ROOT_NOT_ONLY_BASE64_LITERAL'
}
$cleanupTok=$null;$cleanupErr=$null
[void][Management.Automation.Language.Parser]::ParseInput($decodedCleanup,[ref]$cleanupTok,[ref]$cleanupErr)
if(@($cleanupErr).Count){throw 'R434_DEFERRED_CLEANUP_SCRIPT_PARSE_FAILED'}
'R434_PASS_COMPILED_DEFERRED_UNINSTALL_ROOT_ONLY_AS_BASE64_DATA'
foreach($badRoot in @('C:\Windows',($canonical+'-nonowner'),($canonical+"';Write-Output R434_SENTINEL;#"))){
    $negative=New-Object 'object[]' 3
    $negative[0]=[string]$badRoot;$negative[1]=[int]$good[1];$negative[2]=[long]$good[2]
    $refused=$false
    try{$notLaunched=$cleanupMethod.Invoke($null,$negative)}
    catch{
        $ex=$_.Exception
        while($null -ne $ex){
            if($ex -is [IO.InvalidDataException]){$refused=$true;break}
            $ex=$ex.InnerException
        }
        if(!$refused){throw}
    }
    if(!$refused){throw 'R434_DEFERRED_CLEANUP_UNTRUSTED_ROOT_ACCEPTED'}
}
'R434_PASS_THREE_UNTRUSTED_DEFERRED_UNINSTALL_ROOTS_REJECTED'
$hashAfter=(Get-FileHash -LiteralPath $SetupPath -Algorithm SHA256).Hash
if($hashAfter -cne $hashBefore){throw 'R434_SETUP_BINARY_CHANGED'}
'R434_PASS_COMPILED_SETUP_SHA256_UNCHANGED'
'R434_PASS_NO_PROCESS_START_NO_UAC_NO_HELPER_EXECUTION'
'R434_RESULT=PASS_COMPILED_ELEVATED_HELPER_ARG_TRANSPORT_SCOPED'