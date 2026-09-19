[CmdletBinding()]
param(
    [string]$ManifestPath=(Join-Path $PSScriptRoot '..\artifacts\R21_BUILD_MANIFEST.json'),
    [string]$DependencyLockPath=(Join-Path $PSScriptRoot 'dependencies.lock.json'),
    [string]$OutputPath=(Join-Path $PSScriptRoot '..\artifacts\R21_SBOM.spdx.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$manifest=Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json
$lock=Get-Content -LiteralPath $DependencyLockPath -Raw|ConvertFrom-Json
$gitHead=(& git -C (Join-Path $PSScriptRoot '..') rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitHead)){throw 'Could not resolve Git HEAD for SBOM.'}

$packages=@()
$packages += [ordered]@{
    name='Taskbar Monitor Enhanced'
    SPDXID='SPDXRef-Package-TBME'
    versionInfo=[string]$manifest.Version
    downloadLocation='NOASSERTION'
    filesAnalyzed=$false
    licenseConcluded='GPL-3.0-only'
    licenseDeclared='GPL-3.0-only'
    copyrightText='Copyright 2026 Dr. Ali-Akbar Emadeddin'
    supplier='Person: Dr. Ali-Akbar Emadeddin'
}

$relationships=@(
    [ordered]@{spdxElementId='SPDXRef-DOCUMENT';relationshipType='DESCRIBES';relatedSpdxElement='SPDXRef-Package-TBME'}
)

foreach($prop in $lock.dependencies.PSObject.Properties){
    $name=[string]$prop.Name
    $d=$prop.Value
    $id='SPDXRef-Package-'+($name -replace '[^A-Za-z0-9.-]','-')
    $packages += [ordered]@{
        name=$name
        SPDXID=$id
        versionInfo=[string]$d.version
        downloadLocation=[string]$d.url
        filesAnalyzed=$false
        licenseConcluded='NOASSERTION'
        licenseDeclared='NOASSERTION'
        copyrightText='NOASSERTION'
        checksums=@([ordered]@{algorithm='SHA256';checksumValue=([string]$d.sha256).ToLowerInvariant()})
    }
    $relationships += [ordered]@{spdxElementId='SPDXRef-Package-TBME';relationshipType='DEPENDS_ON';relatedSpdxElement=$id}
}

$files=@()
foreach($o in $manifest.Outputs){
    $id='SPDXRef-File-'+(([string]$o.Name) -replace '[^A-Za-z0-9.-]','-')
    $files += [ordered]@{
        fileName=[string]$o.Name
        SPDXID=$id
        checksums=@([ordered]@{algorithm='SHA256';checksumValue=([string]$o.SHA256).ToLowerInvariant()})
        licenseConcluded='NOASSERTION'
        copyrightText='NOASSERTION'
    }
    $relationships += [ordered]@{spdxElementId='SPDXRef-Package-TBME';relationshipType='CONTAINS';relatedSpdxElement=$id}
}

$created=[datetime]::Parse([string]$manifest.GeneratedUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$doc=[ordered]@{
    spdxVersion='SPDX-2.3'
    dataLicense='CC0-1.0'
    SPDXID='SPDXRef-DOCUMENT'
    name=('Taskbar-Monitor-Enhanced-'+[string]$manifest.Version)
    documentNamespace=('https://github.com/GOD13emad/TaskbarMonitorEnhanced/spdx/'+[string]$manifest.Version+'/'+$gitHead)
    creationInfo=[ordered]@{
        created=$created
        creators=@('Tool: TBME-Generate-Sbom.ps1','Organization: Taskbar Monitor Enhanced')
    }
    documentDescribes=@('SPDXRef-Package-TBME')
    packages=$packages
    files=$files
    relationships=$relationships
}

$parent=Split-Path -Parent $OutputPath
if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
$doc|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ('R21_SBOM=PASS path='+$OutputPath+' packages='+$packages.Count+' files='+$files.Count)
