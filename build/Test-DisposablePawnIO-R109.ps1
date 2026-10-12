# R109: explicitly scoped to a new GitHub-hosted disposable Windows VM.
# Exercise the official, separately licensed, Authenticode-valid PawnIO v2.2.0 driver
# prerequisite with exact SHA-256. Never install a driver on a personal/self-hosted PC.
# No changes to product package, no fake sensor telemetry, no reboot or logoff.
[CmdletBinding()]
param([switch]$StaticOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$Version='2.2.0'
$ExpectedSHA='1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032'
$Official='https://github.com/namazso/PawnIO.Setup/releases/download/2.2.0/PawnIO_setup.exe'
$PawnKeys=@(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO'
)
if($StaticOnly){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw 'R109 PARSER FAIL'}
    if($ExpectedSHA -cnotmatch '^[0-9A-F]{64}$' -or
       $Version -cne '2.2.0' -or $Official -cnotmatch '^https://github\.com/namazso/PawnIO\.Setup/releases/download/2\.2\.0/'){
        throw 'R109 OFFICIAL PINNED DRIVER STATIC IDENTITY FAILED'
    }
    Write-Output 'R109_STATIC_GITHUB_ONLY_OFFICIAL_CODE_SIGNED_SHA_PIN_PASS_NO_INSTALL'
    exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or
   $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or
   $env:GITHUB_SHA -cnotmatch '^[a-f0-9]{40}$' -or
   $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   ![Environment]::Is64BitOperatingSystem -or
   ![Environment]::UserInteractive -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){
    throw 'R109 REFUSE ANY NON-DISPOSABLE HOST'
}
$who=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=[Security.Principal.WindowsPrincipal]::new($who)
if(!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    throw 'R109 HOSTED VM NOT ALREADY ELEVATED; NEVER PROMPT OR BYPASS UAC'
}
function Read-R109DriverVersion {
    $versions=@()
    foreach($key in $PawnKeys){
        if(Test-Path -LiteralPath $key){
            try{
                $text=[string](Get-ItemProperty -LiteralPath $key -ErrorAction Stop).DisplayVersion
                if($text){$versions+= $text}
            }catch{}
        }
    }
    return @($versions)
}
$previous=@(Read-R109DriverVersion)
if($previous.Count){
    throw ('R109 DISPOSABLE VM HAS PREEXISTING PAWNIO: REFUSE DRIVER MUTATION '+($previous -join ','))
}
$dir=[IO.Path]::GetFullPath((Join-Path $env:RUNNER_TEMP 'TBME_R109_PawnIO'))
if(Test-Path -LiteralPath $dir){throw 'R109 NO RERUN OR OVERWRITE'}
New-Item -ItemType Directory -Path $dir -ErrorAction Stop|Out-Null
$installer=Join-Path $dir 'PawnIO_setup.exe'
$receipt=Join-Path $dir 'R109_OFFICIAL_PAWNIO_RECEIPT.json'
$status='NOT_STARTED';$errorText='';$exitCode=-999;$sha='';$signatureState='UNVERIFIED'
$signer='';$installedVersion='';$rebootRequired=$false;$driverInstalled=$false
$start=(Get-Date).ToUniversalTime().ToString('o')
try{
    Invoke-WebRequest -Uri $Official -OutFile $installer -TimeoutSec 100 -ErrorAction Stop
    if(!(Test-Path -LiteralPath $installer -PathType Leaf)){throw 'R109 NO OFFICIAL DRIVER FILE'}
    $sha=(Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
    if($sha -cne $ExpectedSHA){throw ('R109 OFFICIAL DRIVER SHA MISMATCH '+$sha)}
    $sig=Get-AuthenticodeSignature -LiteralPath $installer
    $signatureState=[string]$sig.Status
    $signer=if($null -ne $sig.SignerCertificate){[string]$sig.SignerCertificate.Subject}else{''}
    if($sig.Status -ne 'Valid' -or $signer -cnotmatch 'CN=namazso\.eu' -or
       $signer -cnotmatch 'O=namazso'){
        throw ('R109 UNTRUSTED CODE-SIGNER '+$signatureState+' '+$signer)
    }
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$installer
    $psi.WorkingDirectory=$dir
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    [void]$psi.ArgumentList.Add('-install')
    [void]$psi.ArgumentList.Add('-silent')
    $child=[Diagnostics.Process]::Start($psi)
    if($null -eq $child){throw 'R109 OFFICIAL PAWNIO CHILD NOT STARTED'}
    try{
        if(!$child.WaitForExit(105000)){
            try{$child.Kill();$child.WaitForExit(6000)|Out-Null}catch{}
            throw 'R109 OFFICIAL INSTALLER EXCEEDED TIME BOUND'
        }
        $exitCode=[int]$child.ExitCode
    }finally{$child.Dispose()}
    if($exitCode -eq 3010){
        $rebootRequired=$true
        throw 'R109 OFFICIAL INSTALLER REQUIRED REBOOT; AUTO RESTART FORBIDDEN'
    }
    if($exitCode -ne 0){throw ('R109 OFFICIAL DRIVER INSTALL EXIT '+$exitCode)}
    $deadline=(Get-Date).AddSeconds(14)
    do{
        $installed=@(Read-R109DriverVersion)
        if($installed.Count){break}
        Start-Sleep -Milliseconds 700
    }while((Get-Date) -lt $deadline)
    if($installed.Count -ne 1 -or $installed[0] -cne '2.2.0.0'){
        throw ('R109 PINNED PAWNIO REGISTRY VERSION NOT MATCHED '+($installed -join ','))
    }
    $installedVersion=$installed[0]
    $driverInstalled=$true
    $status='PASS_VALID_SIGNED_OFFICIAL_DRIVER_ON_DISPOSABLE_VM_ONLY'
}catch{$errorText=$_.Exception.ToString();$status='FAIL_CLOSED_OFFICIAL_DRIVER_PREREQUISITE'}
finally{
    $result=[ordered]@{
        Schema=1;Revision='R109';EventCommit=$env:GITHUB_SHA
        HostRole='GITHUB_HOSTED_DISPOSABLE_WINDOWS'
        Status=$status;OfficialUrl=$Official;Version=$Version
        PinnedSHA256=$ExpectedSHA;DownloadedSHA256=$sha
        AuthenticodeStatus=$signatureState;SignerSubject=$signer
        InstallerExit=$exitCode;InstalledRegistryVersion=$installedVersion
        DriverInstalledOnDisposable=$driverInstalled
        OriginalDriverAbsent=($previous.Count -eq 0)
        RebootRequired=$rebootRequired;RebootPerformed=$false
        PersonalMachineTouched=$false
        ProtectedUserSetupChanged=$false
        PublicReleaseModified=$false
        Error=$errorText
        StartedUTC=$start;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o')
    }
    [IO.File]::WriteAllText($receipt,($result|ConvertTo-Json -Depth 7),
        [Text.UTF8Encoding]::new($false))
    Write-Output ('R109_OFFICIAL_PAWNIO_RESULT='+$status+' VERSION='+$installedVersion+
        ' SIGNATURE='+$signatureState+' INSTALL_EXIT='+$exitCode+' REBOOT='+$rebootRequired+
        ' RECEIPT_SHA256='+(Get-FileHash -LiteralPath $receipt -Algorithm SHA256).Hash)
}
if($status -cne 'PASS_VALID_SIGNED_OFFICIAL_DRIVER_ON_DISPOSABLE_VM_ONLY'){
    throw ('R109_DRIVER_PREREQUISITE_REFUSED '+$errorText)
}
exit 0
