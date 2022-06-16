<#
.SYNOPSIS
    Restores/installs NuGet packages required to build projects in this repo.
.PARAMETER MSBuildPath
    The path to directory that contains MSBuild.exe that should be used for package restore.
    If not specified, it will be auto-detected with consideration to the workloads that are required to be installed.
.PARAMETER Feature
    The individual feature(s) to restore packages for.
    This should be a leaf name of the directory under src.
    If not specified, all features will have their packages restored.
.PARAMETER Signing
    Install the MicroBuild signing plugin for building test-signed builds on desktop machines.
.PARAMETER Localization
    Install the MicroBuild localization plugin for building loc builds on desktop machines.
    The environment is configured to build pseudo-loc for JPN only, but may be used to build
    all languages with shipping-style loc by using the `/p:loctype=full,loclanguages=vs`
    when building.
.PARAMETER Setup
    Install the MicroBuild setup plugin for building VSIXv3 packages.
.PARAMETER IBCMerge
    Install the MicroBuild IBCMerge plugin for building optimized assemblies on desktop machines.
.PARAMETER FxCop
    Install the MicroBuild FxCop plugin.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
Param(
    [Parameter()]
    [string]$MSBuildPath,
    [Parameter()]
    [ValidateSet('Editor','Experiments','Identity','ConnectedServices','Shell')]
    [string[]]$Feature,
    [Parameter()]
    [switch]$Signing,
    [Parameter()]
    [switch]$Localization,
    [Parameter()]
    [switch]$Setup,
    [Parameter()]
    [switch]$IBCMerge,
    [Parameter()]
    [switch]$FxCop
)

Function Restore-PackagesUnder($searchRoot) {
    # Restore swixproj and vsmanproj packages since these projects are not part of the solution file
    Get-ChildItem $searchRoot -rec |? { $_.FullName -imatch 'swixproj|vsmanproj' } |% {
        Write-Host "Restoring packages for $_..." -ForegroundColor $HeaderColor
        $setupProj = $_.FullName
        $projDir = split-path -Parent $setupProj
        $projectJson = "$projDir\project.json"
        if (Test-Path $projectJson -PathType Leaf) {
            & "$toolsPath\Restore-NuGetPackages.ps1" -Path $projectJson -NuGetVersion 3.5.0
        }
        else {
            Write-Verbose "Setup project '$setupProj' does not have adjacent '$projectJson'"
        }
    }

    # Restore VS solution dependencies
    Get-ChildItem $searchRoot -rec |? { $_.FullName.EndsWith('.sln') } |% {
        Write-Host "Restoring packages for $($_.FullName)..." -ForegroundColor $HeaderColor
        & "$toolsPath\Restore-NuGetPackages.ps1" -Path $_.FullName -Verbosity $nugetVerbosity -Twice
    }
}

Push-Location $PSScriptRoot
try {
    $EnvVarsSet = $false
    $HeaderColor = 'Green'
    $toolsPath = "$PSScriptRoot\tools"
    $nugetVerbosity = 'quiet'
    if ($Verbose) { $nugetVerbosity = 'normal' }

    & "$PSScriptRoot\tools\Get-NuGetTool.ps1" | Out-Null
    if (!$Feature) {
        Restore-PackagesUnder "$PSScriptRoot\src"
    } else {
        $Feature |% { Restore-PackagesUnder "$PSScriptRoot\src\$_" }
    }

    $MicroBuildPackageSource = 'https://devdiv.pkgs.visualstudio.com/DefaultCollection/_packaging/MicroBuildToolset/nuget/v3/index.json'
    if ($Signing) {
        Write-Host "Installing MicroBuild signing plugin" -ForegroundColor $HeaderColor
        & "$toolsPath\Install-NuGetPackage.ps1" MicroBuild.Plugins.Signing -source $MicroBuildPackageSource -Verbosity $nugetVerbosity
        $env:SignType = "Test"
        $EnvVarsSet = $true
    }

    if ($Setup) {
        Write-Host "Installing MicroBuild SwixBuild plugin..." -ForegroundColor $HeaderColor
        & "$toolsPath\Install-NuGetPackage.ps1" MicroBuild.Plugins.SwixBuild -source $MicroBuildPackageSource -Verbosity $nugetVerbosity
    }

    if ($IBCMerge) {
        Write-Host "Installing MicroBuild IBCMerge plugin" -ForegroundColor $HeaderColor
        & "$toolsPath\Install-NuGetPackage.ps1" MicroBuild.Plugins.IBCMerge -source $MicroBuildPackageSource -Verbosity $nugetVerbosity
        $env:IBCMergeBranch = & "$PSScriptRoot\src\_release\variables\InsertTargetBranch.ps1"
        $EnvVarsSet = $true
    }

    if ($Localization) {
        Write-Host "Installing MicroBuild localization plugin" -ForegroundColor $HeaderColor
        & "$toolsPath\Install-NuGetPackage.ps1" MicroBuild.Plugins.Localization -source $MicroBuildPackageSource -Verbosity $nugetVerbosity
        $env:LocType = "Pseudo"
        $env:LocLanguages = "JPN"
        $EnvVarsSet = $true
    }

    if ($EnvVarsSet -and $env:PS1UnderCmd -eq '1') {
        Write-Warning "Environment variables have been set to support MicroBuild plugins that will be lost because you're running under cmd.exe"
    }

    if ($FxCop) {
        Write-Host "Installing MicroBuild FxCop plugin" -ForegroundColor $HeaderColor
        & "$toolsPath\Install-NuGetPackage.ps1" MicroBuild.Plugins.FxCop -source $MicroBuildPackageSource -Verbosity $nugetVerbosity
        $env:MicroBuild_FXCop = "true"
    }

    Write-Host "Successfully restored all dependencies" -ForegroundColor Yellow
}
catch {
    Write-Error $error[0]
    exit $lastexitcode
}
finally {
    Pop-Location
}
