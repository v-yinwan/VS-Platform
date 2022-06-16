# VS-Platform repo guidance

General information on this repo and our patterns/practices can be found on [our wiki](https://devdiv.visualstudio.com/DevDiv/Connected%20Experience/_wiki/wikis/DevDiv.wiki?wikiVersion=GBwikiMaster&pagePath=%2FVS%20IDE%2FVS_Platform%20repo).

Please refer to README.md files in individual feature directories for more information
including team contact information.

## Repo structure and general patterns

This repo defines feature directories directly under src.
Each feature directory contains one or more sln files.

### Windows PowerShell

Automation scripts are often written as .ps1 (Windows PowerShell).
We recommend you use a PowerShell window to run scripts since although some scripts have .cmd counterparts, they invoke the .ps1 scripts in a child process and any environment variables the .ps1 script sets for you will be lost when they exit back to cmd.exe. Also, we have completion lists defined for powershell script parameters so they are easier to invoke when you are already running under PowerShell.

## Building

### Prerequisites

Building and testing this repo requires that Visual Studio 2017 be installed on your machine with several workloads or components selected.
You can install VS or add the required components by using this command:

```ps1
.\tools\Install-VS.ps1
```

If you have not installed VS with all the necessary components, the init or build scripts described below will emit an error and advise you to invoke the above script.

### Restore packages

Before building, restore packages by running the `init` script at the root of this repo:

```cmd
.\init
```

Note this script takes optional switches to prepare to build optional projects
(e.g. setup projects) and/or use MicroBuild plugins in a desktop build.

If you plan to only build a subset of features in the repo, you can use the `-Feature` switch
with the init script so init can run more quickly. For example, to restore packages just for Connected Services:

```cmd
.\init -Feature ConnectedServices
```

### Building solution files

Running msbuild.exe on any individual solution or MSBuild project file is fine.
Project references are defined so that all dependencies should build as required automatically.
To build the whole repo or entire features within it, you may find the `build` script at the root of this repo useful:

```cmd
.\build
```

By default, setup projects are not built but can be with the `-Setup` switch.

To build just one feature area, use the `-Feature` switch. For example, to build just Connected Services:

```ps1
.\build.ps1 -Feature ConnectedServices
```

You may also be interested to learn [more about running MicroBuild plugins on desktop builds][MicroBuildDesktopBuild].

Avoid using `dotnet build` in this repo because we rely on MSBuild tasks that are not available on .NET Core.

### Build artifacts

All build artifacts go to the repo-level `bin` and `obj` folders.
Shipping files go to `bin\Packages\%configuration%` and into any of these folders:

* CoreXT
* NuGet
* VSIX

## Testing

The `test.ps1` script will run any tests previously built.

```cmd
.\test
```

[VSTSCredProvider]: https://devdiv.pkgs.visualstudio.com/_apis/public/nuget/client/CredentialProviderBundle.zip
[NuGetExe]: https://dist.nuget.org/win-x86-commandline/v4.0.0/NuGet.exe
[VSPreview]: https://aka.ms/vs/15/intpreview/vs_enterprise.exe
[MicroBuildDesktopBuild]: https://microsoft.sharepoint.com/teams/DD_CoEng/_layouts/OneNote.aspx?id=%2Fteams%2FDD_CoEng%2FDocuments%2FOneNote%2FMicroBuild%20Documentation&wd=target%28MicroBuild.one%7CA0381102-446A-4329-B353-B97A11F92C8B%2FRun%20a%20Desktop%20Build%7C697D16AE-CAD8-4CE9-97D4-63D05A7E11EB%2F%29
[RequiredWorkloads]: tools\Get-RequiredWorkloads.ps1
