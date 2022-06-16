<#
.SYNOPSIS
    Builds all projects in this repo.
.PARAMETER MSBuildPath
    The path to directory that contains MSBuild.exe that should be used for package restore.
    If not specified, it will be auto-detected with consideration to the workloads that are required to be installed.
.PARAMETER Configuration
    The build configuration.
.PARAMETER TreatWarningsAsErrors
    Elevates some build warnings to errors, leading ultimately to a build failure.
.PARAMETER ContinueOnError
    WarnAndContinue: When a task fails, subsequent tasks in the Target element and the build continue to execute, and all errors from the task are treated as warnings.
    ErrorAndContinue: When a task fails, subsequent tasks in the Target element and the build continue to execute, and all errors from the task are treated as errors.
    ErrorAndStop (default): When a task fails, the remaining tasks in the Target element and the build aren't executed, and the entire Target element and the build is considered to have failed.
.PARAMETER Feature
    The individual feature(s) to restore packages for.
    This should be a leaf name of the directory under src.
    If not specified, all features will have their packages restored.
.PARAMETER Verbosity
    The MSBuild verbosity to emit to the console.
.PARAMETER Setup
    Build setup as well as standard VS .sln solutions.
.PARAMETER Init
    Run init.ps1 first.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
Param(
    [Parameter()]
    [string]$MSBuildPath,
    [Parameter()]
    [ValidateSet('Debug','Release')]
    [string]$Configuration='Debug',
    [Parameter()]
    [switch]$TreatWarningsAsErrors,
    [Parameter()]
    [ValidateSet('WarnAndContinue','ErrorAndContinue','ErrorAndStop')]
    [string]$ContinueOnError='ErrorAndStop',
    [Parameter()]
    [ValidateSet('Editor','Experiments','Identity','ConnectedServices','Shell')]
    [string[]]$Feature,
    [Parameter()]
    [ValidateSet('quiet','minimal','normal','detailed','diagnostic')]
    [string]$Verbosity='minimal',
    [Parameter()]
    [switch]$Setup,
    [Parameter()]
    [switch]$Init
)

$MSBuildPath = & "$PSScriptRoot\tools\Get-MSBuildPath.ps1"
$MSBuildArgs = @()
$MSBuildArgs += '/nologo'
$MSBuildArgs += "/v:$Verbosity"
$MSBuildArgs += '/nr:false'
$MSBuildArgs += "/bl:$PSScriptRoot\bin\build_logs\$Configuration\msbuild.binlog"
$MSBuildArgs += "/flp:verbosity=normal;logfile=$PSScriptRoot\bin\build_logs\$Configuration\msbuild.normal.log"
#$MSBuildArgs += "/flp1:verbosity=detailed;logfile=$PSScriptRoot\bin\build_logs\$Configuration\msbuild.detailed.log" # the /bl we use is far more efficient
$MSBuildArgs += "/flp2:warningsonly;verbosity=minimal;nosummary;logfile=$PSScriptRoot\bin\build_logs\$Configuration\msbuild.wrn.log"
$MSBuildArgs += "/flp3:errorsonly;verbosity=minimal;nosummary;logfile=$PSScriptRoot\bin\build_logs\$Configuration\msbuild.err.log"
if ($TreatWarningsAsErrors) { $MSBuildArgs += "/p:TreatWarningsAsErrors=true" }
if ($ContinueOnError) { $MSBuildArgs += "/p:ContinueOnError=`"$ContinueOnError`"" }

Function Build() {
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]$project,
        [hashtable]$globalProperties=@{}
    )

    $visibleMSBuildArgs = @()
    if ($globalProperties) {
        $visibleMSBuildArgs += $globalProperties.GetEnumerator() |% {
            Write-Output "/p:`"$($_.key)`"=`"$($_.value)`""
        }
    }

    Write-Host "Building $project $visibleMSBuildArgs" -ForegroundColor $HeaderColor
    if ($PSCmdlet.ShouldProcess($project, "msbuild.exe $visibleMSBuildArgs")) {
        & "$MSBuildPath\msbuild.exe" ($MSBuildArgs + $project + $visibleMSBuildArgs)
        if ($LASTEXITCODE -ne 0) {
            throw "Build failure"
        }
    }
}

try {
    $HeaderColor = 'Green'

    if ($Init) {
        if (!$Feature) { $Feature = @() }
        & "$PSScriptRoot\init.ps1" -Feature $Feature -Setup:$Setup -MSBuildPath $MSBuildPath
    }

    $globalProperties = @{
        'Configuration' = $Configuration;
    }
    if ($Setup) {
        $globalProperties['BuildSetup'] = 'true'
    }

    if (!$Feature) {
        Build "$PSScriptRoot\src\dirs.proj" -GlobalProperties $globalProperties
    } else {
        $Feature |% { Build "$PSScriptRoot\src\dirs.proj" -GlobalProperties ($globalProperties + @{ 'Feature' = $_ }) }
    }
    Write-Host "Successfully built" -ForegroundColor Yellow
}
catch {
    Write-Error $error[0]
    exit $lastexitcode
}
finally {
}
