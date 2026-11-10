[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AppPath,
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [switch]$HostedGuest
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($PSVersionTable.PSEdition -cne 'Desktop'){throw 'R399_REQUIRES_WINDOWS_POWERSHELL_51'}
if($HostedGuest -and ($env:GITHUB_ACTIONS -cne 'true' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted')){
    throw 'R399_NOT_DISPOSABLE_HOST'
}
$root=(Resolve-Path -LiteralPath $SourceRoot).Path
$app=(Resolve-Path -LiteralPath $AppPath).Path
$expected=Join-Path $root 'build\_out\App\TaskbarMonitorEnhanced.exe'
if(![string]::Equals($app,$expected,[StringComparison]::OrdinalIgnoreCase)){
    throw 'R399_APP_NOT_EXACT_BUILD_OUTPUT'
}
$source=[IO.File]::ReadAllText((Join-Path $root 'src\TaskbarMonitorEnhanced.cs'))
if(([regex]::Matches($source,[regex]::Escape('ExplorerFolderLauncher.Open(AppPaths.Logs);'))).Count -ne 2 -or
   ([regex]::Matches($source,[regex]::Escape('ExplorerFolderLauncher.Open(AppPaths.Root);'))).Count -ne 1 -or
   $source.Contains('Process.Start("explorer.exe",AppPaths.')){
    throw 'R399_EXPECT_THREE_UI_FOLDER_CALLS'
}
$assembly=[Reflection.Assembly]::LoadFrom($app)
$type=$assembly.GetType('TaskbarMonitorEnhanced.ExplorerFolderLauncher',$true)
$method=$type.GetMethod('BuildStartInfo',[Reflection.BindingFlags]'Static,Public,NonPublic')
if(!$method){throw 'R399_BUILDER_ABSENT_FROM_COMPILED_MAIN'}
function Get-BuildResult([string]$Path){
    try{
        $result=$method.Invoke($null,[object[]]@([string]$Path))
        return [pscustomobject]@{Info=$result;Error=''}
    }catch{
        $e=$_.Exception
        while($e.InnerException){$e=$e.InnerException}
        return [pscustomobject]@{Info=$null;Error=$e.GetType().Name}
    }
}
$temp=Join-Path $env:TEMP ('tbme-r399-explorer-args-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temp)|Out-Null
try{
    $folder=Join-Path $temp 'directory with spaces'
    [IO.Directory]::CreateDirectory($folder)|Out-Null
    $built=Get-BuildResult $folder
    if($built.Error -or !$built.Info){throw 'R399_BUILDER_NORMAL_PATH_REJECTED'}
    $info=[Diagnostics.ProcessStartInfo]$built.Info
    $windows=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)) 'explorer.exe'
    if($info.FileName -cne $windows -or $info.UseShellExecute -or
       $info.Arguments -cne ('"'+$folder+'"')){
        throw 'R399_START_INFO_NOT_PINNED_AND_QUOTED'
    }
    'R399_PASS_COMPILED_EXPLORER_ABSOLUTE_AND_QUOTED'

    $exe=Join-Path $temp 'ArgsEcho.exe'
    $code='using System; public static class Echo { public static void Main(string[] args) { Console.WriteLine(args.Length); foreach(string item in args) Console.WriteLine(item); } }'
    Add-Type -TypeDefinition $code -OutputAssembly $exe -OutputType ConsoleApplication -ErrorAction Stop
    $info.FileName=$exe
    $info.RedirectStandardOutput=$true
    $info.CreateNoWindow=$true
    $child=[Diagnostics.Process]::Start($info)
    if(!$child){throw 'R399_ECHO_NOT_STARTED'}
    try{
        $stdout=$child.StandardOutput.ReadToEnd()
        if(!$child.WaitForExit(5000)){throw 'R399_ECHO_TIMEOUT'}
        $rows=@($stdout -split '\r?\n' | Where-Object {$_ -ne ''})
        if($rows.Count -ne 2 -or $rows[0] -cne '1' -or $rows[1] -cne $folder){
            throw 'R399_COMPILED_ARGUMENTS_SPLIT'
        }
    }finally{$child.Dispose()}
    'R399_PASS_NATIVE_DOTNET_ARGUMENT_SINGLE_PATH'

    $relative=Get-BuildResult '.\folder with spaces'
    if($relative.Error -cne 'InvalidDataException'){throw 'R399_RELATIVE_PATH_NOT_REJECTED'}
    'R399_PASS_RELATIVE_FOLDER_REJECTED'
    $quoted=Get-BuildResult ('"'+$folder+'"')
    if($quoted.Error -cne 'InvalidDataException'){throw ('R399_QUOTED_USER_INPUT_NOT_REJECTED_actual_'+$quoted.Error)}
    'R399_PASS_QUOTE_INJECTION_REJECTED'
    $missing=Get-BuildResult (Join-Path $temp 'missing-folder')
    if($missing.Error -cne 'DirectoryNotFoundException'){throw 'R399_MISSING_FOLDER_NOT_REJECTED'}
    'R399_PASS_MISSING_FOLDER_REJECTED'
    'R399_PASS_THREE_UI_FOLDER_CALLS_PINNED'
    'R399_PASS_NO_REAL_EXPLORER_LAUNCHED'
    'R399_RESULT=PASS_SCOPED_EXPLORER_FOLDER_ARG_QUOTING'
}finally{
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
}
