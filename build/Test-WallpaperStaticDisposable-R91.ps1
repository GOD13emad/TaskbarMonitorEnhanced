# R91 actual *product* WallpaperStudio.ApplyDesktop + private RestoreDesktopPreState on
# explicitly disposable GitHub-hosted interactive Windows only. Never personal desktop.
# Captures synthetic static Picture baseline, applied bytes, restored bytes, original VM
# pre-state and fail-closed native receipt. Not a formally independently signed G13 witness.
[CmdletBinding()]
param(
  [string]$MainExe='',
  [string]$EvidenceDir='',
  [switch]$StaticOnly
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$TestRevision='R91'
$SourceSHA='eeac48c2ff201326c6a59e7ccc21c72c9a676160'
$MainSHA='63A724981E949BA4C91F8BD44F2659F223BDFE0350A2E229CEE7B05535D4BA70'
$WallpaperModePath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
$DesktopRegPath='HKCU:\Control Panel\Desktop'
$ModeRegNative='Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
$DesktopRegNative='Control Panel\Desktop'
if($StaticOnly){
    $tokens=$null;$parseErrors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$parseErrors)
    if($parseErrors.Count -ne 0){throw 'R91 G13 SCRIPT PARSER INVALID'}
    Write-Output 'R91_STATIC_ONLY_NO_WALLPAPER_OR_REGISTRY_MUTATION_PASS'
    exit 0
}
if($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
   $env:RUNNER_OS -cne 'Windows' -or $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT' -or
   [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)){throw 'R91 G13 REFUSE: NOT DISPOSABLE GITHUB HOSTED WINDOWS'}
if([string]::IsNullOrWhiteSpace($EvidenceDir) -or
   [string]::IsNullOrWhiteSpace($MainExe)){throw 'R91 MISSING EXACT INPUT PATHS'}
$R91Main=[IO.Path]::GetFullPath($MainExe)
$R91Area=[IO.Path]::GetFullPath($EvidenceDir)
$R91RunnerTemp=[IO.Path]::GetFullPath($env:RUNNER_TEMP)
if(-not $R91Area.StartsWith($R91RunnerTemp.TrimEnd('\')+'\', [StringComparison]::OrdinalIgnoreCase) -or
   $R91Main -cne [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TaskbarMonitorEnhanced\TaskbarMonitorEnhanced.exe'))){
    throw 'R91 INPUTS OUTSIDE OWNED EPHEMERAL HOST'
}
if((Get-FileHash -LiteralPath $R91Main).Hash -cne $MainSHA){throw 'R91 PRODUCT IS NOT EXACT IMMUTABLE PUBLIC MAIN'}
if(Test-Path -LiteralPath $R91Area){throw 'R91 NO UNSAFE CANARY RERUN'}
$R91Session=(Get-Process -Id $PID).SessionId
$R91Explorer=@(Get-Process -Name explorer -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq $R91Session})
if($R91Explorer.Count -lt 1 -or [Environment]::UserInteractive -ne $true){throw 'R91 G13 NEEDS REAL USER INTERACTIVE EXPLORER SESSION'}
$R91StartUtc=(Get-Date).ToUniversalTime().ToString('o')
$R91Dir=Join-Path $R91Area 'raw\wallpaper'
$R91ReceiptPath=Join-Path $R91Area 'R91_G13_CANARY_RECEIPT.json'
$R91EventPath=Join-Path $R91Dir 'product-events.json'
$R91SeedPath=Join-Path $R91Area 'R91_SYNTHETIC_STATIC_BASELINE.bmp'
$R91BeforeCopy=Join-Path $R91Dir 'before.bin'
$R91AfterCopy=Join-Path $R91Dir 'restored.bin'
$R91AppliedCopy=Join-Path $R91Dir 'applied.bin'
$R91BackgroundModeBefore='UNOBSERVED'
$R91BackgroundModeAfter='UNOBSERVED'
$R91AppPositive='NOT_RUN'
$R91Negative='NOT_RUN'
$R91Rollback='NOT_RUN'
$R91OuterRestore='NOT_RUN'
$R91Failure=''
$R91FailureRestore=''
$R91AppliedPath=''
$R91ProductEvents=[ordered]@{
  Schema=1;Revision='R91';SourceSHA=$SourceSHA;ProductClass='WallpaperStudio'
  EventCommit=$env:GITHUB_SHA
  ApplyDesktopInvoked=$false;RestoreDesktopPreStateInvoked=$false
  IndependentAfterStateObserved=$false;ProcessId=$PID
  NegativeSlideshowRefusalObserved=$false;RealUserHostTouched=$false
}
# Original transient runner state: captured before any mutation, restored in finally.
$R91Original=[ordered]@{}
$R91Key=Get-Item -LiteralPath $DesktopRegPath -ErrorAction Stop
$R91ModeKey=Get-Item -LiteralPath $WallpaperModePath -ErrorAction SilentlyContinue
$R91ModeOriginallyExists=$null -ne $R91ModeKey
$R91ModePresent=$R91ModeOriginallyExists -and @($R91ModeKey.GetValueNames()) -contains 'BackgroundType'
$R91OriginalMode=if($R91ModePresent){[int]$R91ModeKey.GetValue('BackgroundType')}else{$null}
if($R91ModePresent -and $R91OriginalMode -ne 0){throw 'R91 REFUSE TO OVERWRITE NONSTATIC SLIDESHOW/SPOTLIGHT EVEN ON EPHEMERAL RUNNER'}
$R91InitialMode=if($R91ModePresent){[string]$R91OriginalMode}else{'ABSENT'}
$R91OriginalValues=@{}
foreach($name in @('WallPaper','WallpaperStyle','TileWallpaper')){
    $present=@($R91Key.GetValueNames()) -contains $name
    $value=if($present){[string]$R91Key.GetValue($name)}else{''}
    $R91OriginalValues[$name]=[pscustomobject]@{Present=$present;Value=$value}
}
$R91OriginalWallpaperFile=$R91OriginalValues['WallPaper'].Value
$R91OriginalHash=if($R91OriginalWallpaperFile -and (Test-Path -LiteralPath $R91OriginalWallpaperFile -PathType Leaf)){
    (Get-FileHash -LiteralPath $R91OriginalWallpaperFile).Hash
}else{''}
if($R91OriginalWallpaperFile -and !$R91OriginalHash){throw 'R91 ORIGINAL HOST WALLPAPER PATH UNREADABLE; NO MUTATION'}
New-Item -ItemType Directory -Path $R91Dir -Force -ErrorAction Stop|Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class R91NativeWallpaper {
  [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool SystemParametersInfo(int action,int parameter,string image,int flags);
}
'@
function Read-R91WallpaperState {
  $k=Get-Item -LiteralPath $DesktopRegPath -ErrorAction Stop
  $mode=Get-Item -LiteralPath $WallpaperModePath -ErrorAction SilentlyContinue
  [ordered]@{
    WallPaper=[string]$k.GetValue('WallPaper','')
    WallpaperStyle=[string]$k.GetValue('WallpaperStyle','')
    TileWallpaper=[string]$k.GetValue('TileWallpaper','')
    BackgroundType=if($mode -and @($mode.GetValueNames()) -contains 'BackgroundType') {[int]$mode.GetValue('BackgroundType')} else {$null}
  }
}
$R91Activated=$false
try{
    # Synthetic 96px BMP is disposable and never an existing user's asset.
    $bitmap=New-Object System.Drawing.Bitmap(96,96)
    try{
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try{$graphics.Clear([Drawing.Color]::FromArgb(255,30,65,110))}
        finally{$graphics.Dispose()}
        $bitmap.Save($R91SeedPath,[Drawing.Imaging.ImageFormat]::Bmp)
    }finally{$bitmap.Dispose()}
    $R91SyntheticSHA=(Get-FileHash $R91SeedPath).Hash
    $modeKey=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($ModeRegNative)
    try{$modeKey.SetValue('BackgroundType',0,[Microsoft.Win32.RegistryValueKind]::DWord)}
    finally{$modeKey.Dispose()}
    $deskKey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($DesktopRegNative,$true)
    if($null -eq $deskKey){throw 'R91 CANNOT OPEN EPHEMERAL DESKTOP REGISTRY FOR SYNTHETIC PICTURE'}
    try{
        $deskKey.SetValue('WallpaperStyle','10',[Microsoft.Win32.RegistryValueKind]::String)
        $deskKey.SetValue('TileWallpaper','0',[Microsoft.Win32.RegistryValueKind]::String)
    }finally{$deskKey.Dispose()}
    if(![R91NativeWallpaper]::SystemParametersInfo(20,0,$R91SeedPath,3)){
        throw 'R91 EPHEMERAL WINDOWS REFUSED SYNTHETIC STATIC WALLPAPER SPI'
    }
    $R91Activated=$true
    $R91Before=Read-R91WallpaperState
    if($R91Before.BackgroundType -ne 0 -or
       $R91Before.WallPaper -cne $R91SeedPath -or
       $R91Before.WallpaperStyle -cne '10' -or
       $R91Before.TileWallpaper -cne '0'){throw 'R91 SYNTHETIC STATIC PICTURE PRESTATE NOT CONFIRMED'}
    $R91BackgroundModeBefore=0
    $R91ProductEvents.BeforeRegistry=$R91Before
    Copy-Item -LiteralPath $R91SeedPath -Destination $R91BeforeCopy -ErrorAction Stop
    if((Get-FileHash $R91BeforeCopy).Hash -cne $R91SyntheticSHA){throw 'R91 BEFORE SYNTHETIC BASELINE HASH'}
    # Invoke actual publicly released Main method (reflection) with CLR 4.0 on hosted
    # interactive Windows; no replacement or recompilation of the application class.
    $assembly=[Reflection.Assembly]::LoadFrom($R91Main)
    $wallpaperType=$assembly.GetType('TaskbarMonitorEnhanced.WallpaperStudio',$true)
    $flags=[Reflection.BindingFlags]'NonPublic,Static'
    $applyMethod=$wallpaperType.GetMethod('ApplyDesktop',$flags)
    $restoreMethod=$wallpaperType.GetMethod('RestoreDesktopPreState',$flags)
    if($null -eq $applyMethod -or $null -eq $restoreMethod){throw 'R91 PRODUCT METHODS NOT FOUND IN EXACT PUBLIC MAIN'}
    $R91ProductEvents.ApplyDesktopInvoked=$true
    $R91AppliedPath=[string]$applyMethod.Invoke($null,@('Art Deco Gold',0))
    $R91AppPositive='PRODUCT_APPLY_RETURNED'
    if(!(Test-Path -LiteralPath $R91AppliedPath -PathType Leaf)){throw 'R91 APPLIED PNG MISSING'}
    $R91AppliedSHA=(Get-FileHash -LiteralPath $R91AppliedPath).Hash
    if($R91AppliedSHA -ceq $R91SyntheticSHA){throw 'R91 REAL APPLIED IMAGE NOT DISTINCT'}
    $R91Current=Read-R91WallpaperState
    if($R91Current.BackgroundType -ne 0 -or
       $R91Current.WallPaper -cne $R91AppliedPath -or
       $R91Current.WallpaperStyle -cne '10' -or
       $R91Current.TileWallpaper -cne '0'){throw 'R91 WINDOWS WALLPAPER NOT SET TO REAL PRODUCT RESULT'}
    Copy-Item -LiteralPath $R91AppliedPath -Destination $R91AppliedCopy -ErrorAction Stop
    if((Get-FileHash $R91AppliedCopy).Hash -cne $R91AppliedSHA){throw 'R91 REAL APPLIED RAW IMAGE SHA'}
    $R91ProductEvents.IndependentAfterStateObserved=$true
    $backupDir=Split-Path -Parent $R91AppliedPath
    $appBackups=@(Get-ChildItem -LiteralPath $backupDir -Filter 'previous-wallpaper-*.json' -File)
    if($appBackups.Count -ne 1){throw ('R91 BACKUP MANIFEST NOT EXACT ONE '+$appBackups.Count)}
    $appBackup=Get-Content -LiteralPath $appBackups[0].FullName -Raw|ConvertFrom-Json
    if($appBackup.OriginalImageSHA256 -cne $R91SyntheticSHA -or
       $appBackup.WallPaper -cne $R91SeedPath -or
       !(Test-Path -LiteralPath ([string]$appBackup.OriginalImageBackup) -PathType Leaf) -or
       (Get-FileHash -LiteralPath ([string]$appBackup.OriginalImageBackup)).Hash -cne $R91SyntheticSHA){
        throw 'R91 PRODUCT PRIOR WALLPAPER BACKUP HASH INVALID'
    }
    $R91ProductEvents.RestoreDesktopPreStateInvoked=$true
    [void]$restoreMethod.Invoke($null,@($R91SeedPath,$R91Before.WallpaperStyle,$R91Before.TileWallpaper,
        [string]$appBackup.OriginalImageBackup,$R91SyntheticSHA))
    $restored=Read-R91WallpaperState
    if($restored.BackgroundType -ne 0 -or $restored.WallPaper -cne $R91SeedPath -or
       $restored.WallpaperStyle -cne $R91Before.WallpaperStyle -or
       $restored.TileWallpaper -cne $R91Before.TileWallpaper -or
       (Get-FileHash -LiteralPath $R91SeedPath).Hash -cne $R91SyntheticSHA){throw 'R91 PRODUCT RESTORE WAS NOT EXACT'}
    Copy-Item -LiteralPath $R91SeedPath -Destination $R91AfterCopy -ErrorAction Stop
    if((Get-FileHash $R91AfterCopy).Hash -cne $R91SyntheticSHA){throw 'R91 RESTORED IMAGE RAW BYTE MISMATCH'}
    $R91ProductEvents.AfterRegistry=$restored
    $R91Rollback='PASS_EXACT_PRODUCT_APPLY_THEN_RESTORE'
    # Real product negative case: transient dynamic mode 2 must be rejected BEFORE
    # generating a new image and changing Wallpaper. Safe only on synthetic host baseline.
    $modeKey=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($ModeRegNative)
    try{$modeKey.SetValue('BackgroundType',2,[Microsoft.Win32.RegistryValueKind]::DWord)}
    finally{$modeKey.Dispose()}
    $R91Rejected=$false
    try{[void]$applyMethod.Invoke($null,@('Art Deco Gold',1))}
    catch{
        if($_.Exception.InnerException -is [NotSupportedException]){$R91Rejected=$true}
    }
    $modeKey=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($ModeRegNative)
    try{$modeKey.SetValue('BackgroundType',0,[Microsoft.Win32.RegistryValueKind]::DWord)}
    finally{$modeKey.Dispose()}
    if(!$R91Rejected -or (Read-R91WallpaperState).WallPaper -cne $R91SeedPath -or
       (Get-FileHash -LiteralPath $R91SeedPath).Hash -cne $R91SyntheticSHA){
        throw 'R91 NEGATIVE DYNAMIC-MODE REFUSAL DID NOT FAIL CLOSED'
    }
    $R91Negative='PASS_REAL_PRODUCT_REJECTED_DYNAMIC_SLIDESHOW'
    $R91ProductEvents.NegativeSlideshowRefusalObserved=$true
    $R91ProductEvents.AppliedSHA256=$R91AppliedSHA
    $R91ProductEvents.BeforeSHA256=$R91SyntheticSHA
    $R91ProductEvents.RestoredSHA256=(Get-FileHash $R91AfterCopy).Hash
    $R91BackgroundModeAfter=0
}catch{
    $R91Failure=$_.Exception.ToString()
}finally{
    # Restore original ephemeral runner state, including mode presence, wallpaper path,
    # style/tile and original file bytes. If restoration cannot be proven, fail closed.
    try{
        $deskKey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($DesktopRegNative,$true)
        if($null -eq $deskKey){throw 'R91 HOST ORIGINAL DESKTOP REGISTRY NOT AVAILABLE'}
        try{
            foreach($name in @('WallpaperStyle','TileWallpaper')){
                $item=$R91OriginalValues[$name]
                if($item.Present){$deskKey.SetValue($name,[string]$item.Value,[Microsoft.Win32.RegistryValueKind]::String)}
                else{$deskKey.DeleteValue($name,$false)}
            }
        }finally{$deskKey.Dispose()}
        if($R91OriginalWallpaperFile -and (Test-Path -LiteralPath $R91OriginalWallpaperFile -PathType Leaf)){
            if(![R91NativeWallpaper]::SystemParametersInfo(20,0,$R91OriginalWallpaperFile,3)){
                throw 'R91 RESTORE ORIGINAL RUNNER HOST VIA SPI FAILED'
            }
        }else{
            # Original runner may have no wallpaper at all. Clearing is valid only on this VM.
            if(![R91NativeWallpaper]::SystemParametersInfo(20,0,'',3)){
                throw 'R91 CLEAR RUNNER ORIGINAL EMPTY WALLPAPER VIA SPI FAILED'
            }
        }
        $deskKey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($DesktopRegNative,$true)
        if($null -eq $deskKey){throw 'R91 CANNOT RESTORE ORIGINAL HOST WALLPAPER REGISTRY'}
        try{
            $item=$R91OriginalValues['WallPaper']
            if($item.Present){$deskKey.SetValue('WallPaper',[string]$item.Value,[Microsoft.Win32.RegistryValueKind]::String)}
            else{$deskKey.DeleteValue('WallPaper',$false)}
        }finally{$deskKey.Dispose()}
        if($R91ModeOriginallyExists){
            $mkey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($ModeRegNative,$true)
            if($null -eq $mkey){throw 'R91 CANNOT OPEN ORIGINAL WALLPAPER MODE KEY'}
            try{
                if($R91ModePresent){$mkey.SetValue('BackgroundType',[int]$R91OriginalMode,[Microsoft.Win32.RegistryValueKind]::DWord)}
                else{$mkey.DeleteValue('BackgroundType',$false)}
            }finally{$mkey.Dispose()}
        }else{
            $mkey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($ModeRegNative,$true)
            if($mkey){try{$mkey.DeleteValue('BackgroundType',$false)}finally{$mkey.Dispose()}}
        }
        $modeFinal=Get-Item -LiteralPath $WallpaperModePath -ErrorAction SilentlyContinue
        $modePresentFinal=$modeFinal -and @($modeFinal.GetValueNames()) -contains 'BackgroundType'
        if($modePresentFinal -ne $R91ModePresent){throw 'R91 ORIGINAL MODE PRESENCE NOT RESTORED'}
        if($R91ModePresent -and [int]$modeFinal.GetValue('BackgroundType') -ne $R91OriginalMode){throw 'R91 ORIGINAL MODE VALUE NOT RESTORED'}
        $desktopFinal=Get-Item -LiteralPath $DesktopRegPath -ErrorAction Stop
        foreach($name in @('WallPaper','WallpaperStyle','TileWallpaper')){
            $original=$R91OriginalValues[$name]
            $presentFinal=@($desktopFinal.GetValueNames()) -contains $name
            if($original.Present -ne $presentFinal -or
                ($presentFinal -and [string]$desktopFinal.GetValue($name) -cne [string]$original.Value)){
                throw ('R91 ORIGINAL HOST REGISTRY NOT RESTORED '+$name)
            }
        }
        if($R91OriginalHash -and (Get-FileHash -LiteralPath $R91OriginalWallpaperFile).Hash -cne $R91OriginalHash){
            throw 'R91 ORIGINAL EPHEMERAL WALLPAPER FILE SHA NOT RESTORED'
        }
        $R91OuterRestore='PASS_ORIGINAL_HOST_REGISTRY_AND_ORIGINAL_FILE_SHA'
    }catch{$R91FailureRestore=$_.Exception.ToString();$R91OuterRestore='FAIL_OR_UNPROVEN'}
    $R91ProductEvents|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $R91EventPath -Encoding utf8
    $result=[ordered]@{
        Schema=1;Revision='R91';EventCommit=$env:GITHUB_SHA
        Status=if(!$R91Failure -and !$R91FailureRestore -and $R91Rollback -like 'PASS*' -and
          $R91Negative -like 'PASS*' -and $R91OuterRestore -like 'PASS*'){
           'PASS_ACTUAL_WALLPAPER_APPLY_RESTORE_DISPOSABLE_INTERACTIVE'
        }else{'FAIL_CLOSED_WALLPAPER_CANARY'}
        SourceSHA=$SourceSHA;InstalledMainSHA256=$MainSHA
        HostRole='GITHUB_HOSTED_DISPOSABLE_INTERACTIVE_WINDOWS'
        HostSessionId=$R91Session;ExplorerInSameSessionCount=$R91Explorer.Count
        OriginalHostedWallpaperMode=$R91InitialMode;SyntheticBaselineMode=0
        ProductApplyStatus=$R91AppPositive;ProductRestoreStatus=$R91Rollback
        NegativeDynamicModeStatus=$R91Negative
        OriginalHostRestorationStatus=$R91OuterRestore
        AppliedImageSHA256=if(Test-Path $R91AppliedCopy){(Get-FileHash $R91AppliedCopy).Hash}else{''}
        BeforeImageSHA256=if(Test-Path $R91BeforeCopy){(Get-FileHash $R91BeforeCopy).Hash}else{''}
        RestoredImageSHA256=if(Test-Path $R91AfterCopy){(Get-FileHash $R91AfterCopy).Hash}else{''}
        ProductClass='WallpaperStudio';RawProductEvents='raw/wallpaper/product-events.json'
        IndependentLabWitnessSignature='MISSING_NOT_FORMAL_G13_ACCEPTANCE'
        FormalG13Accepted=$false
        UserPersonalWallpaperTouched=$false
        StartedUTC=$R91StartUtc;FinishedUTC=(Get-Date).ToUniversalTime().ToString('o')
        Error=$R91Failure;RestorationError=$R91FailureRestore
    }
    $result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $R91ReceiptPath -Encoding utf8
    $rawRecords=@()
    foreach($case in @(@('raw/wallpaper/before.bin',$R91BeforeCopy),@('raw/wallpaper/applied.bin',$R91AppliedCopy),
                       @('raw/wallpaper/restored.bin',$R91AfterCopy),@('raw/wallpaper/product-events.json',$R91EventPath))){
      if(Test-Path -LiteralPath $case[1] -PathType Leaf){
        $obj=Get-Item -LiteralPath $case[1]
        $rawRecords += [ordered]@{Path=[string]$case[0];Bytes=[long]$obj.Length;SHA256=(Get-FileHash -LiteralPath $case[1]).Hash}
      }
    }
    $rawManifest=[ordered]@{Schema=1;Revision='R91';EventCommit=$env:GITHUB_SHA
      Status=$result.Status;FormalG13Accepted=$false;SignedIndependentWitness=$false;Files=$rawRecords}
    $rawManifest|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $R91Area 'R91_G13_RAW_MANIFEST.json') -Encoding utf8
    Write-Output ('R91_G13_RECEIPT='+$R91ReceiptPath+' STATUS='+$result.Status+
      ' PRODUCT='+$R91AppPositive+' ROLLBACK='+$R91Rollback+' HOST_RESTORE='+$R91OuterRestore)
}
if($R91Failure -or $R91FailureRestore){throw ('R91 G13 FAIL_CLOSED PRODUCT='+$R91Failure+' RESTORATION='+$R91FailureRestore)}
Write-Output 'R91_REAL_PRODUCT_G13_APPLY_AND_RESTORE_HOSTED_PASS_FORMAL_WITNESS_STILL_MISSING'
exit 0
