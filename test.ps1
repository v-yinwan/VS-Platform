<#
.SYNOPSIS
    Builds all projects in this repo.
.PARAMETER MSBuildPath
    The path to directory that contains MSBuild.exe that should be used for package restore.
    If not specified, it will be auto-detected with consideration to the workloads that are required to be installed.
.PARAMETER Configuration
    The build configuration.
.PARAMETER Feature
    The individual feature(s) to restore packages for.
    This should be a leaf name of the directory under src.
    If not specified, all features will have their packages restored.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
Param(
    [Parameter()]
    [string]$MSBuildPath,
    [Parameter()]
    [ValidateSet('Debug','Release')]
    [string]$Configuration='Debug',
    [Parameter()]
    [ValidateSet('Editor','Experiments','Identity','ConnectedServices','Shell')]
    [string[]]$Feature
)

$VSTestPath = & "$PSScriptRoot\tools\Get-VSTestPath.ps1"
$VSTestArgs = @()
$VSTestArgs += '/Parallel'
$VSTestArgs += "/TestAdapterPath:$PSScriptRoot\bin"
$VSTestArgs += '/Blame'

$TestAssemblies = @()

Function Get-TestAssembliesUnder($searchRoot) {
    Get-ChildItem $searchRoot -rec |? { $_.Name -like '*tests*.dll' -and $_.Name -notlike '*.RunsVs.*' -and $_.FullName -match "\\$Configuration\\" } |% {
        Write-Output $_.FullName
    }
}

try {
    $HeaderColor = 'Green'

    if (!$Feature) {
        $TestAssemblies += Get-TestAssembliesUnder "$PSScriptRoot\bin"
    } else {
        $Feature |% { $TestAssemblies += Get-TestAssembliesUnder "$PSScriptRoot\bin\$_" }
    }

    if ($TestAssemblies) {
        Write-Host "Test assemblies:" -ForegroundColor $HeaderColor
        $TestAssemblies |% { Write-Host "   $_" }

        if ($PSCmdlet.ShouldProcess('Execute test runner')) {
            & $VSTestPath $VSTestArgs $TestAssemblies
        }
    } else {
        Write-Warning "No test assemblies found."
    }
}
catch {
    Write-Error $error[0]
    exit $lastexitcode
}
finally {
}
