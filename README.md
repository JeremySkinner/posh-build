# Posh-Build

Posh-build is a small set of scripts for building .net applications from Powershell. This is not intended to be a replacement for [psake](https://github.com/psake/psake/), but offers a simpler one-file alternative for working with the `dotnet` CLI tools.

# Requirements

Windows Powershell 5 or Powershell Core 6.x

# Getting Started

Download the `posh-build.ps1` file and reference it from your build script. Inside your build script, define build targets using the `target` function. These should specify a name and a script block. At the end of the script, you should call `Start-Build`

```powershell
. $PSScriptRoot/posh-build.ps1

target default {
  write-host "Hello from posh-build"
}

Start-Build
```

This script defines a single target called `default`. Run the script and the target will be executed.

# Built-in functions

Any powershell function can be used inside a target, this includes calling .net framework types. In addition, posh-build defined several functions that make working with the `dotnet` CLI tools easier:

| Function             | Description | Example |
| -------------------- | ----------- | ------- |
| `Invoke-Dotnet`      | Runs the specified `dotnet` CLI tool. All parameters are passed to the tool. If the tool fails (with a non-zero exit code), then the build will fail. | `Invoke-Dotnet build MySolution.sln -c Release --no-incremental` |
| `Invoke-Tests`       | Runs `dotnet test` against the specified test projects | `$projects = @("tests\NetFx\NetFxTests.csproj", "tests\NetCore\NetCore.csproj"); Invoke-Tests $projects -c release` |
| `New-Prompt`         | Creates a command line confirmation prompt. Useful for confirming deployments. | `$result = New-Prompt "Upload Packages" "Do you want to upload the NuGet packages to Nuget?" @{ "&No" = "Cancel upload."; "&Yes" = "Upload the packages." }` |

# Complete example

This is the build script, saved as `build.ps1`. It'd be invoked from powershell just by dotsourcing the file:

```
.\build.ps1 -version 2.0.0
```

Complete source:

```powershell
param(
  [string]$version = '1.0.0-dev',
  [string]$configuration = 'Release'
)

. $PSScriptRoot/posh-build.ps1

$base = $PSScriptRoot;
$build_dir = "$base\build";
$packages_dir = "$build_dir\packages"
$output_dir = "$build_dir\$configuration";
$solution_file = "$base\MySolution.sln";

target default -depends compile, test, deploy

target compile {
  Invoke-Dotnet build $solution_file -c $configuration --no-incremental `
    /p:Version=$version
}

target test {
  $test_projects = @(
    "$base\tests\Tests.netcoreapp1\Tests.netcoreapp1.csproj",
    "$base\tests\Tests.netcoreapp2\Tests.netcoreapp2.csproj"
  )

  Invoke-Tests $test_projects -c $configuration --no-build
}

target deploy {
  Remove-Item $build_dir -Force -Recurse 2> $null
  Invoke-Dotnet pack $solution_file -c $configuration /p:PackageOutputPath=$build_dir\Packages /p:Version=$version

  # Copy to output dir
  Copy-Item "$base\src\MyProject\bin\$configuration\netstandard2.0" -Destination "$output_dir\MyProject-netstandard2.0" -Recurse
  Copy-Item "$base\src\MyProject\bin\$configuration\netstandard1.0" -Destination "$output_dir\MyProject-netstandard1.0" -Recurse
}

target publish {
  # Find all the packages and display them for confirmation
  $packages = dir $packages_dir -Filter "*.nupkg"
  write-host "Packages to upload:"
  $packages | ForEach-Object { write-host $_.Name }

  # Ensure we haven't run this by accident.
  $result = New-Prompt "Upload Packages" "Do you want to upload the NuGet packages?" @{
    "&No" = "Cancel upload"
    "&Yes" = "Upload the packages."
  }

  # Cancelled
  if ($result -eq 0) {
    "Upload aborted"
  }
  # upload
  elseif ($result -eq 1) {
    $packages | foreach {
      $package = $_.FullName
      write-host "Uploading $package"
      Invoke-Dotnet nuget push $package --source "https://www.nuget.org/api/v2/package"
      write-host
    }
  }
}

Start-Build $args
```