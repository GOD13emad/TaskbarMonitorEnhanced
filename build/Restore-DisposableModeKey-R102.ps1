# R102: ONLY disposable GitHub-hosted Windows. No personal registry or real-world cleanup.
# Invoked when the exact wallpaper mode key did not exist BEFORE the test began.
# Preserve unknown values/children: never use DeleteSubKeyTree, never replace user settings.
function Invoke-R102RestoreOriginallyAbsentModeKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$NativeSubKey,
        [Parameter(Mandatory=$true)][bool]$OriginalKeyExists
    )
    if($OriginalKeyExists) { throw 'R102 REFUSE ORIGINAL EXISTED KEY' }
    if($env:GITHUB_ACTIONS -cne 'true' -or
       $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
       $env:RUNNER_OS -cne 'Windows' -or
       [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
       $env:COMPUTERNAME -ceq 'EMAD-PC-ULTIMAT') {
        throw 'R102 REFUSE NONDISPOSABLE HOST'
    }
    $real='Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
    $allowedFixture=($NativeSubKey -cmatch '^Software\\TaskbarMonitorEnhanced_R102_Canary_(Absent|Empty|Dynamic|ForeignValue|ForeignChild|WrongKind|OriginallyPresent)$')
    if($NativeSubKey -cne $real -and !$allowedFixture) {
        throw 'R102 REFUSE NONALLOWLIST REGISTRY KEY'
    }
    $k=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($NativeSubKey,$true)
    if($null -eq $k){return 'ALREADY_ABSENT'}
    try{
        $names=@($k.GetValueNames())
        $child=@($k.GetSubKeyNames())
        if($child.Count -ne 0 -or $names.Count -gt 1 -or
           @($names|Where-Object {$_ -cne 'BackgroundType'}).Count -gt 0) {
            throw 'R102 REFUSE UNOWNED REGISTRY CONTENT'
        }
        if($names.Count -eq 1){
            if($k.GetValueKind('BackgroundType') -ne [Microsoft.Win32.RegistryValueKind]::DWord){
                throw 'R102 REFUSE FOREIGN VALUE TYPE'
            }
            $mode=[int]$k.GetValue('BackgroundType')
            if($mode -notin @(0,2)){throw 'R102 REFUSE UNKNOWN MODE VALUE'}
            $k.DeleteValue('BackgroundType',$false)
        }
        if($k.ValueCount -ne 0 -or $k.SubKeyCount -ne 0) {
            throw 'R102 REFUSE CONTENT ADDED DURING RESTORE'
        }
    }finally{$k.Dispose()}
    # DeleteSubKey (never Tree) is safe only after checking this exact test-owned empty leaf.
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($NativeSubKey,$false)
    $verify=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($NativeSubKey,$false)
    if($null -ne $verify) {
        $verify.Dispose()
        throw 'R102 ORIGINAL ABSENCE NOT RESTORED'
    }
    return 'REMOVED_EXACT_OWNED_EMPTY_KEY'
}
