[CmdletBinding()]
param(
    [string]$Executable='',
    [string]$OutputDirectory='',
    [switch]$Visual
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($PSScriptRoot)){throw 'Script root not available; invoke this saved script with -File.'}
if([string]::IsNullOrWhiteSpace($Executable)){$Executable=Join-Path $PSScriptRoot '_out\App\TaskbarMonitorEnhanced.exe'}
if([string]::IsNullOrWhiteSpace($OutputDirectory)){$OutputDirectory=Join-Path $PSScriptRoot '..\artifacts\workspace-tests'}
$Executable=(Resolve-Path -LiteralPath $Executable).Path
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $OutputDirectory){throw "Evidence directory already exists; choose a new exact directory: $OutputDirectory"}
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$binaryHash=(Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash
$head=(& git -C (Join-Path $PSScriptRoot '..') rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Git revision read failed'}
$results=@()
$tests=@('selftest','feature-contract-selftest','workspace-selftest')
if($Visual){$tests+=@('workspace-proof','themeproof','compactproof','settingsproof')}
foreach($test in $tests){
    $stdout=Join-Path $OutputDirectory ($test+'.stdout.txt')
    $stderr=Join-Path $OutputDirectory ($test+'.stderr.txt')
    $arguments=@('--'+$test)
    if($test -in @('workspace-proof','themeproof','compactproof','settingsproof')){
        $destination=Join-Path $OutputDirectory $test
        $arguments+=('"'+$destination+'"')
    }
    $p=[Diagnostics.Process]::new()
    $p.StartInfo.FileName=$Executable
    $p.StartInfo.Arguments=[string]::Join(' ',[string[]]$arguments)
    $p.StartInfo.UseShellExecute=$false
    $p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardOutput=$true
    $p.StartInfo.RedirectStandardError=$true
    try{
        if(!$p.Start()){throw 'Could not start test child'}
        $readOut=$p.StandardOutput.ReadToEndAsync()
        $readErr=$p.StandardError.ReadToEndAsync()
        if(!$p.WaitForExit(180000)){
            try{$p.Kill();$p.WaitForExit()}catch{}
            throw "Timeout in $test; proof output is unaccepted."
        }
        $p.WaitForExit()
        [int]$exitCode=$p.ExitCode
        $text=$readOut.GetAwaiter().GetResult()
        $errorText=$readErr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText($stdout,$text,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($stderr,$errorText,[Text.UTF8Encoding]::new($false))
    }finally{$p.Dispose()}
    $ok=$exitCode -eq 0 -and $text.Contains('=PASS') -and !$text.Contains('=FAIL') -and !$errorText.Contains('=FAIL')
    $results += [ordered]@{Test=$test;ExitCode=$exitCode;Status=$(if($ok){'PASS'}else{'FAIL'});StdoutSHA256=(Get-FileHash $stdout).Hash;StderrSHA256=(Get-FileHash $stderr).Hash}
    $summary=[ordered]@{Status=$(if($ok){'IN_PROGRESS'}else{'FAIL'});GitHead=$head;Executable=$Executable;ExecutableSHA256=$binaryHash;GeneratedUtc=[DateTime]::UtcNow.ToString('o');Results=$results}
    $summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $OutputDirectory 'SUMMARY.json') -Encoding UTF8
    Write-Output "$test exit=$exitCode status=$($results[-1].Status)"
    if(!$ok){Write-Output $text;Write-Output $errorText;throw "Test failed: $test"}
}
if((Get-FileHash -LiteralPath $Executable).Hash -ne $binaryHash){throw 'Binary changed during verification'}
if($Visual){
    $proof=Get-Content -LiteralPath (Join-Path $OutputDirectory 'workspace-proof\WORKSPACE_PROOF_MANIFEST.json') -Raw|ConvertFrom-Json
    if(!$proof.NoSyntheticMetricData -or $proof.Pages.Count -ne 8 -or $proof.ThemeCount -ne 48 -or $proof.GeometryUniqueSamePalette -ne 20 -or $proof.UIActions.Status -ne 'PASS' -or $proof.UIActions.AccessibilityNameGaps -ne 0){throw 'Workspace semantic acceptance contract failed'}
}
$summary.Status='PASS'
$summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $OutputDirectory 'SUMMARY.json') -Encoding UTF8
Write-Output ('TBME_WORKSPACE_SUITE=PASS TESTS='+$results.Count)
