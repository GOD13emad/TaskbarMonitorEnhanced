[CmdletBinding()]
param(
    [string]$VisualSummary='',
    [string]$RuntimeSummary='',
    [string]$CIReceipt='',
    [string]$LivePreviewReceipt='',
    [string]$PositiveWallpaperReceipt='',
    [string]$InstalledRuntimeReceipt='',
    [string]$OutputPath='',
    [switch]$RequireStable
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function Resolve-Evidence([string]$path) {
    if([string]::IsNullOrWhiteSpace($path)){return $null}
    $full=if([IO.Path]::IsPathRooted($path)){[IO.Path]::GetFullPath($path)}else{[IO.Path]::GetFullPath((Join-Path $root $path))}
    if(!(Test-Path -LiteralPath $full -PathType Leaf)){return $null}
    try{return Get-Content -LiteralPath $full -Raw|ConvertFrom-Json}catch{return $null}
}
function Add-Gate([string]$name,[bool]$passed,[string]$evidence,[string]$kind) {
    $script:gates.Add([ordered]@{Gate=$name;Status=$(if($passed){'PASS'}else{'BLOCKED'});Class=$kind;Evidence=$evidence})
}
$sha=(& git -C $root rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0 -or $sha.Length -ne 40){throw 'Git HEAD not available.'}
$dirty=@(& git -C $root status --porcelain)
if($LASTEXITCODE -ne 0){throw 'Git status failed.'}
$manifestPath=Join-Path $root 'artifacts\BUILD_MANIFEST.json'
$detPath=Join-Path $root 'artifacts\DETERMINISM.json'
$verifyPath=Join-Path $root 'build\_out\setup_verify.json'
$gates=[Collections.Generic.List[object]]::new()
Add-Gate 'G01_SOURCE_COMMITTED_CLEAN' ($dirty.Count -eq 0) $sha 'Candidate'
$manifest=Resolve-Evidence $manifestPath
$outputs=@()
$realHashesPass=$false
if($null -ne $manifest) {
    $outputs=@($manifest.Outputs)
    if($outputs.Count -eq 5){
        $files=@{
            'TaskbarMonitorEnhanced.exe'='build\_out\App\TaskbarMonitorEnhanced.exe';
            'TaskbarMonitorEnhanced.exe.config'='build\_out\App\TaskbarMonitorEnhanced.exe.config';
            'TaskbarMonitorSensorBroker.exe'='build\_out\Broker\TaskbarMonitorSensorBroker.exe';
            'TaskbarMonitorSensorSupervisor.exe'='build\_out\Supervisor\TaskbarMonitorSensorSupervisor.exe';
            'TaskbarMonitorEnhanced_Setup_1.7.0.exe'='build\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.0.exe'
        }
        $realHashesPass=$true
        foreach($item in $outputs){
            $name=[string]$item.Name
            if(!$files.ContainsKey($name)){$realHashesPass=$false;break}
            $file=Join-Path $root $files[$name]
            if(!(Test-Path -LiteralPath $file -PathType Leaf) -or
                (Get-FileHash -LiteralPath $file).Hash -ne [string]$item.SHA256){
                $realHashesPass=$false;break
            }
        }
    }
}
Add-Gate 'G02_FIVE_ACTUAL_SHA256_OUTPUTS' $realHashesPass 'artifacts/BUILD_MANIFEST.json' 'Candidate'
$det=Resolve-Evidence $detPath
$detPass=$null -ne $det -and $det.Status -eq 'PASS' -and
    $det.ExactHead -eq $sha -and @($det.Outputs).Count -eq 5
Add-Gate 'G03_CLEAN_CLONE_DETERMINISM' $detPass 'artifacts/DETERMINISM.json' 'Candidate'
$setup=Resolve-Evidence $verifyPath
$setupPass=$null -ne $setup -and $setup.Status -eq 'PASS' -and [int]$setup.Resources -eq 26
Add-Gate 'G04_CANONICAL_SETUP_26_RESOURCES' $setupPass 'build/_out/setup_verify.json' 'Candidate'
$visual=Resolve-Evidence $VisualSummary
$visualPass=$null -ne $visual -and $visual.Status -eq 'PASS' -and $visual.GitHead -eq $sha -and
    @($visual.Results).Count -eq 10 -and @($visual.Results|Where-Object Status -ne 'PASS').Count -eq 0
Add-Gate 'G05_EXACT_SHA_TEN_VISUAL_SUITES' $visualPass $VisualSummary 'Candidate'
$chart=$null;$glass=$null
if($null -ne $visual){
    $visualDir=Split-Path -Parent ([IO.Path]::GetFullPath((Join-Path $root $VisualSummary)))
    $chart=Resolve-Evidence (Join-Path $visualDir 'chartglassproof\CHART_GLASS_PROOF.json')
    $glass=Resolve-Evidence (Join-Path $visualDir 'glassproof\GLASS_PROOF.json')
}
$chartPass=$null -ne $chart -and $chart.Status -eq 'PASS' -and [int]$chart.Themes -eq 49 -and [int]$chart.Pairs -eq 196
$glassPass=$null -ne $glass -and $glass.Status -eq 'PASS' -and [int]$glass.Tests -eq 196
Add-Gate 'G06_FOREGROUND_CHARTS_49_THEMES_196_PAIRS' $chartPass 'paired chart/glass foreground proof' 'Candidate'
Add-Gate 'G07_TEXT_ALPHA_196_PAIRS' $glassPass 'paired glyph/high-contrast proof' 'Candidate'
$runtime=Resolve-Evidence $RuntimeSummary
$runtimePass=$null -ne $runtime -and $runtime.Status -eq 'PASS' -and @($runtime.Results).Count -eq 8 -and
    @($runtime.Results | Where-Object Status -ne 'PASS').Count -eq 0
Add-Gate 'G08_EIGHT_RUNTIME_PROBES' $runtimePass $RuntimeSummary 'Candidate'
$ci=Resolve-Evidence $CIReceipt
$ciPass=$null -ne $ci -and $ci.Status -eq 'PASS' -and $ci.Commit -eq $sha -and
    $ci.Conclusion -eq 'success' -and [int]$ci.LocalToCIOutputsMatched -eq 5 -and
    $ci.ProvenanceAttestations -eq 'PASS'
Add-Gate 'G09_EXACT_SHA_CI_SBOM_PROVENANCE' $ciPass $CIReceipt 'Candidate'
$preview=Resolve-Evidence $LivePreviewReceipt
$previewPass=$null -ne $preview -and $preview.Status -eq 'EXPIRED_CLEAN' -and
    [int]$preview.BackgroundOpacityPercent -eq 0 -and $preview.InstalledMainSHA256Still -eq '05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377' -and
    [int]$preview.VisibleChartInkPixels -ge 100 -and [int]$preview.HistorySamples -ge 12
Add-Gate 'G10_EMAD_VISUAL_ONLY_ZERO_ALPHA_REAL_METRICS' $previewPass $LivePreviewReceipt 'Candidate'
$wallpaper=Resolve-Evidence $PositiveWallpaperReceipt
$wallpaperPass=$null -ne $wallpaper -and $wallpaper.Status -eq 'PASS' -and
    $wallpaper.SourceSHA -eq $sha -and $wallpaper.BackgroundType -eq 0 -and
    $wallpaper.ProductApplyDesktopExecuted -eq $true -and $wallpaper.ProductRestoreExecuted -eq $true -and
    $wallpaper.PreImageSHA256 -eq $wallpaper.RestoredImageSHA256 -and
    $wallpaper.PreImageSHA256 -ne $wallpaper.AppliedImageSHA256 -and
    $wallpaper.RegistryPathAndStyleIdentical -eq $true
Add-Gate 'G11_TRUSTED_STATIC_WALLPAPER_APPLY_RESTORE' $wallpaperPass $PositiveWallpaperReceipt 'Stable'
$installed=Resolve-Evidence $InstalledRuntimeReceipt
$installedPass=$null -ne $installed -and $installed.Status -eq 'PASS' -and
    $installed.SourceSHA -eq $sha -and $installed.InstalledMainSHA256 -eq
        (@($outputs|Where-Object Name -eq 'TaskbarMonitorEnhanced.exe'|Select-Object -First 1 -ExpandProperty SHA256)[0]) -and
    $installed.ActualTaskbarChildReadableCharts -eq $true -and $installed.ExplorerRecoveryPassed -eq $true -and
    $installed.ConfigBackupAndRollbackVerified -eq $true -and $installed.ProtectedSensorsHealthy -eq $true
Add-Gate 'G12_INSTALLED_TASKBAR_EXPLORER_SENSORS_ROLLBACK' $installedPass $InstalledRuntimeReceipt 'Stable'
$setupExe=Join-Path $root 'build\_out\Setup\TaskbarMonitorEnhanced_Setup_1.7.0.exe'
$mainExe=Join-Path $root 'build\_out\App\TaskbarMonitorEnhanced.exe'
$signPass=(Test-Path $setupExe) -and (Test-Path $mainExe) -and
    (Get-AuthenticodeSignature -LiteralPath $setupExe).Status -eq 'Valid' -and
    (Get-AuthenticodeSignature -LiteralPath $mainExe).Status -eq 'Valid'
Add-Gate 'G13_AUTHENTICODE_VALID_ON_SETUP_AND_APP' $signPass 'Get-AuthenticodeSignature (actual local artifacts)' 'Stable'
$mainSHA=(& git -C $root rev-parse main).Trim()
Add-Gate 'G14_MAIN_IS_EXACT_APPROVED_COMMIT' ($mainSHA -eq $sha) ('local main HEAD '+$mainSHA) 'Stable'
$required=@($gates|Where-Object {$_.Class -eq 'Candidate'})
$blocked=@($gates|Where-Object {$_.Status -ne 'PASS'})
$ready=$blocked.Count -eq 0
$report=[ordered]@{Schema=1;Project='TaskbarMonitorEnhanced';SourceSHA=$sha;
    CandidateReady=(@($required|Where-Object Status -ne 'PASS').Count -eq 0);
    StableReady=$ready;Overall=$(if($ready){'PASS'}else{'BLOCKED_EXTERNAL_OR_UNPROVEN'});
    EvaluatedUtc=[DateTime]::UtcNow.ToString('o');
    Security='Read-only assessment; never installs, changes wallpaper, signs or publishes.';
    Gates=$gates}
$raw=$report|ConvertTo-Json -Depth 12
if(![string]::IsNullOrWhiteSpace($OutputPath)){
    $full=[IO.Path]::GetFullPath((Join-Path $root $OutputPath))
    if(Test-Path -LiteralPath $full){throw 'Release gate output already exists; no overwrite.'}
    $parent=Split-Path -Parent $full
    New-Item -ItemType Directory -Path $parent -Force|Out-Null
    [IO.File]::WriteAllText($full,$raw,[Text.UTF8Encoding]::new($false))
}
Write-Output $raw
if($RequireStable -and !$ready){exit 45}
if(!($report.CandidateReady)){exit 46}
