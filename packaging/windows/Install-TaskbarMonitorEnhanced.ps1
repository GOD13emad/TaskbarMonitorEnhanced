# R409 Windows 10/11 x64 dependency-first launcher; never updates unrelated software.
[CmdletBinding()]
param([switch]$CheckOnly,[switch]$VerifyOfflineRuntime)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$MinimumRelease=528040
$RuntimeUrl='https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe'
$RuntimeSHA='68C9986A8DCC0214D909AA1F31BEE9FB5461BB839EDCA996A75B08DDFFC1483F'
$RuntimeName='NDP48-x86-x64-AllOS-ENU.exe'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$SetupName='TaskbarMonitorEnhanced_Setup_1.7.10.exe'
$Setup=Join-Path $Root $SetupName
$Manifest=Join-Path $Root 'package-manifest.json'
$script:TempRuntimeDir=$null

function Assert-WindowsDesktop {
  if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
     ![Environment]::Is64BitOperatingSystem -or ![Environment]::Is64BitProcess){
    throw 'R409_REQUIRES_WINDOWS_X64_PROCESS'
  }
  $v=[Environment]::OSVersion.Version
  if($v.Major -ne 10 -or $v.Build -lt 17763){
    throw ('R409_UNSUPPORTED_WINDOWS_BUILD_'+$v.Build)
  }
  $kind=[string](Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ProductOptions' -Name ProductType).ProductType
  if($kind -cne 'WinNT'){throw 'R409_WINDOWS_SERVER_NOT_SUPPORTED'}
  if($v.Build -ge 22000){return 'Windows11-x64'}
  return 'Windows10-x64'
}

function Get-FrameworkRelease {
  $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::Registry64)
  try {
    $key=$base.OpenSubKey('SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full',$false)
    if($null -eq $key){return 0}
    try {
      $value=$key.GetValue('Release',$null)
      if($null -eq $value){return 0}
      return [int]$value
    }finally{$key.Dispose()}
  }finally{$base.Dispose()}
}

function Assert-Package {
  if(!(Test-Path -LiteralPath $Manifest -PathType Leaf) -or
     !(Test-Path -LiteralPath $Setup -PathType Leaf)){
    throw 'R409_PACKAGE_FILES_MISSING'
  }
  $m=Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
  if($m.Schema -ne 1 -or $m.Product -cne 'TaskbarMonitorEnhanced' -or
     $m.SetupFile -cne $SetupName -or $m.SupportedOS -cne 'Windows10/11-x64' -or
     $m.RequiredFrameworkRelease -ne $MinimumRelease -or
     $m.OfficialRuntimeSHA256 -cne $RuntimeSHA -or
     $m.OfficialRuntimeUrl -cne $RuntimeUrl -or
     $m.SetupSHA256 -notmatch '^[A-Fa-f0-9]{64}$' -or
     !($m.OfficialRuntimeBundled -is [bool]) -or
     $m.OfficialRuntimeBundled -ne (Test-Path -LiteralPath (Join-Path $Root $RuntimeName) -PathType Leaf)){
    throw 'R409_PACKAGE_MANIFEST_INVALID'
  }
  $actual=(Get-FileHash -LiteralPath $Setup -Algorithm SHA256).Hash
  if($actual -cne ([string]$m.SetupSHA256).ToUpperInvariant()){
    throw 'R409_SETUP_HASH_MISMATCH'
  }
  return $actual
}

function Assert-OfficialRuntime([string]$Path){
  if(!(Test-Path -LiteralPath $Path -PathType Leaf)){throw 'R409_RUNTIME_FILE_MISSING'}
  if((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -cne $RuntimeSHA){
    throw 'R409_RUNTIME_HASH_MISMATCH'
  }
  $sig=Get-AuthenticodeSignature -LiteralPath $Path
  if([string]$sig.Status -cne 'Valid' -or !$sig.SignerCertificate -or
     $sig.SignerCertificate.Subject -notmatch '(^|,\s*)CN=Microsoft Corporation(,|$)'){
    throw 'R409_RUNTIME_MICROSOFT_SIGNATURE_NOT_VALID'
  }
}

function Acquire-Runtime {
  $offline=Join-Path $Root $RuntimeName
  if(Test-Path -LiteralPath $offline -PathType Leaf){
    Assert-OfficialRuntime $offline
    return $offline
  }
  $script:TempRuntimeDir=Join-Path $env:TEMP ('tbme-r409-runtime-'+[guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($script:TempRuntimeDir)
  $dest=Join-Path $script:TempRuntimeDir $RuntimeName
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  # No URL redirects; the official redistributable is strictly SHA-256 pinned.
  Invoke-WebRequest -Uri $RuntimeUrl -UseBasicParsing -MaximumRedirection 0 -OutFile $dest -ErrorAction Stop
  Assert-OfficialRuntime $dest
  return $dest
}

function Install-Runtime {
  $installer=Acquire-Runtime
  # Pin the read-only signed runtime denying write/delete sharing during UAC.
  $pin=[IO.FileStream]::new($installer,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  try {
    $digest=[Security.Cryptography.SHA256]::Create()
    try{$hash=([BitConverter]::ToString($digest.ComputeHash($pin))).Replace('-','')}finally{$digest.Dispose()}
    if($hash -cne $RuntimeSHA){throw 'R410_PINNED_FRAMEWORK_SHA256_CHANGED'}
    Assert-OfficialRuntime $installer
    Write-Host 'The verified Microsoft .NET Framework 4.8 installer requests native UAC approval.'
    $p=Start-Process -FilePath $installer -ArgumentList @('/q','/norestart','/ChainingPackage','TaskbarMonitorEnhanced') -Verb RunAs -Wait -PassThru
    if(!$p){throw 'R409_RUNTIME_INSTALL_START_FAILED'}
    $code=[int]$p.ExitCode
  }finally{$pin.Dispose()}
  if($code -in @(1641,3010)){
    throw 'R409_RESTART_REQUIRED_REBOOT_WINDOWS_AND_RETRY'
  }
  if($code -ne 0){throw ('R409_RUNTIME_INSTALL_FAILED_EXIT_'+$code)}
  if((Get-FrameworkRelease) -lt $MinimumRelease){
    throw 'R409_RUNTIME_NOT_REGISTERED_REBOOT_WINDOWS_AND_RETRY'
  }
}

try {
  if($VerifyOfflineRuntime){
    $setupSHA=Assert-Package
    $runtime=Join-Path $Root $RuntimeName
    if(!(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'R410_OFFLINE_RUNTIME_REQUIRED_FOR_VERIFICATION'}
    Assert-OfficialRuntime $runtime
    [pscustomobject][ordered]@{Status='OFFLINE_RUNTIME_VERIFIED_NO_EXECUTION';SHA256=$RuntimeSHA;SetupSHA256=$setupSHA;ProductInstalled=$false;RuntimeExecuted=$false} |ConvertTo-Json -Compress
    exit 0
  }
  $platform=Assert-WindowsDesktop
  $setupSHA=Assert-Package
  $bundled=Test-Path -LiteralPath (Join-Path $Root $RuntimeName) -PathType Leaf
  if($bundled){Assert-OfficialRuntime (Join-Path $Root $RuntimeName)}
  $release=Get-FrameworkRelease
  if($CheckOnly){
    [pscustomobject][ordered]@{
      Status='CHECK_ONLY'
      Platform=$platform
      FrameworkRelease=$release
      Framework48OrNewer=($release -ge $MinimumRelease)
      WillInstallFramework=($release -lt $MinimumRelease)
      OfficialRuntimeBundled=$bundled
      OfficialRuntimeIntegrityChecked=$bundled
      SetupSHA256=$setupSHA
      ExecutedSetup=$false
      ModifiedOwnerSettings=$false
    } | ConvertTo-Json -Compress
    exit 0
  }
  if($release -lt $MinimumRelease){Install-Runtime}
  if((Get-FrameworkRelease) -lt $MinimumRelease){throw 'R409_FRAMEWORK_PREREQUISITE_MISSING'}
  # Runtime installation can take minutes; rehash the exact Setup and its
  # companion manifest immediately before launch, not only during preflight.
  if((Assert-Package) -cne $setupSHA){throw 'R409_SETUP_CHANGED_AFTER_PREREQUISITE_PHASE'}
  # Never elevate the whole product installer: it must retain R385 medium-token
  # per-user update ownership; its protected sensor helper requests UAC itself.
  $p=Start-Process -FilePath $Setup -ArgumentList @('/install','/quiet') -PassThru -Wait
  if(!$p -or $p.ExitCode -ne 0){
    throw ('R409_PRODUCT_SETUP_FAILED_EXIT_'+$(if(!$p){'NULL'}else{$p.ExitCode}))
  }
  $installed=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe'
  if(!(Test-Path -LiteralPath $installed -PathType Leaf)){
    throw 'R409_PRODUCT_SETUP_SUCCEEDED_BUT_MAIN_MISSING'
  }
  $running=@(Get-Process -Name 'TaskbarMonitorEnhanced' -ErrorAction SilentlyContinue |
    Where-Object {$_.Path -and [string]::Equals($_.Path,$installed,[StringComparison]::OrdinalIgnoreCase)})
  if($running.Count -eq 0){
    Start-Process -FilePath $installed -WorkingDirectory (Split-Path -Parent $installed) | Out-Null
  }
  Write-Host 'R409_BOOTSTRAP_SUCCESS_FRAMEWORK_SETUP_AND_MAIN'
  exit 0
}catch{
  Write-Host ('R409_BOOTSTRAP_FAILED: '+$_.Exception.Message)
  exit 1
}finally{
  if($script:TempRuntimeDir -and (Test-Path -LiteralPath $script:TempRuntimeDir)){
    Remove-Item -LiteralPath $script:TempRuntimeDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
