[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Executable,[Parameter(Mandatory=$true)][string]$OutputDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Executable=(Resolve-Path -LiteralPath $Executable).Path
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $OutputDirectory){throw 'Runtime evidence directory already exists'}
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$hash=(Get-FileHash -LiteralPath $Executable).Hash
$cases=@(
    @{Name='startup';Switch='--startup-contract-selftest';Target=''},
    @{Name='hover';Switch='--hoverguardproof';Target=''},
    @{Name='hardware';Switch='--hardwareprobe';Target='hardware.json'},
    @{Name='temperature';Switch='--tempprobe';Target='temperature.json'},
    @{Name='health';Switch='--healthprobe';Target='health.json'},
    @{Name='support';Switch='--supportbundleproof';Target='support.zip'},
    @{Name='start';Switch='--startprobe';Target='start'},
    @{Name='shell';Switch='--shellstate';Target='shell.json'}
)
$results=@()
foreach($case in $cases){
    $p=[Diagnostics.Process]::new()
    $p.StartInfo.FileName=$Executable
    $arguments=[string]$case.Switch
    if($case.Target){$arguments+=' "'+(Join-Path $OutputDirectory $case.Target)+'"'}
    $p.StartInfo.Arguments=$arguments
    $p.StartInfo.UseShellExecute=$false
    $p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardOutput=$true
    $p.StartInfo.RedirectStandardError=$true
    $stdout=Join-Path $OutputDirectory ($case.Name+'.out')
    $stderr=Join-Path $OutputDirectory ($case.Name+'.err')
    try{
        if(!$p.Start()){throw 'Process start failed'}
        $readOut=$p.StandardOutput.ReadToEndAsync();$readErr=$p.StandardError.ReadToEndAsync()
        if(!$p.WaitForExit(180000)){try{$p.Kill();$p.WaitForExit()}catch{};throw ('Timeout: '+$case.Name)}
        $p.WaitForExit();[int]$exitCode=$p.ExitCode
        $text=$readOut.GetAwaiter().GetResult();$errorText=$readErr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText($stdout,$text,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($stderr,$errorText,[Text.UTF8Encoding]::new($false))
    }finally{$p.Dispose()}
    $ok=$exitCode -eq 0 -and $text.Contains('=PASS') -and !$errorText.Contains('=FAIL') -and !$text.Contains('=FAIL')
    $results += [ordered]@{Test=$case.Name;Status=$(if($ok){'PASS'}else{'FAIL'});ExitCode=$exitCode;StdoutSHA256=(Get-FileHash $stdout).Hash;StderrSHA256=(Get-FileHash $stderr).Hash}
    $summary=[ordered]@{Status=$(if($ok){'IN_PROGRESS'}else{'FAIL'});Executable=$Executable;ExecutableSHA256=$hash;GeneratedUtc=[DateTime]::UtcNow.ToString('o');Results=$results}
    $summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $OutputDirectory 'SUMMARY.json') -Encoding UTF8
    Write-Output ($case.Name+' exit='+$exitCode+' '+$results[-1].Status)
    if(!$ok){Write-Output $text;Write-Output $errorText;throw ('Runtime test failed: '+$case.Name)}
}
if((Get-FileHash -LiteralPath $Executable).Hash -ne $hash){throw 'Runtime binary changed during verification'}
$summary.Status='PASS';$summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $OutputDirectory 'SUMMARY.json') -Encoding UTF8
Write-Output ('TBME_RUNTIME_SUITE=PASS TESTS='+$results.Count)
