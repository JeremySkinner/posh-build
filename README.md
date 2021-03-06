# Posh-Build

Posh-build is a small set of scripts for building .net applications from Powershell. This is not intended to be a replacement for [psake](https://github.com/psake/psake/), but offers a simpler one-file alternative for working with the `dotnet` CLI tools.

# Requirements

Windows Powershell 5 or Powershell Core 6.x

# Getting Started

Download the build script template by running the following from a powershell prompt:

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/JeremySkinner/posh-build/master/Bootstrap/Build.ps1 -OutFile Build.ps1
```

This will create a file called `Build.ps1` in the current directory with a sample build script that you can modify.
Inside this file, you can define build targets by calling the `target` function, passing it a name and a scriptblock to execute.
At the end of the script, you should call `Start-Build`

Here is a copy of the sample build script that's created:

```powershell
param(
  [string]$version = '1.0.0',
  [string]$configuration = 'Release',
  [string]$path = $PSScriptRoot
)

# Boostrap posh-build
$build_dir = Join-Path $path ".build"
if (! (Test-Path (Join-Path $build_dir "Posh-Build.ps1"))) { Write-Host "Installing posh-build..."; New-Item -Type Directory $build_dir -ErrorAction Ignore | Out-Null; Save-Script "Posh-Build" -Path $build_dir }
. (Join-Path $build_dir "Posh-Build.ps1")

# Set these variables as desired
$packages_dir = Join-Path $build_dir "packages"
$solution_file = Join-Path $path "MySolution.sln";

target default -depends compile, test, deploy

target compile {
  Invoke-Dotnet build $solution_file -c $configuration --no-incremental `
    /p:Version=$version
}

target test {
  # Set the path to the projects you want to test.
  $test_projects = @(
    "$path\src\MyProject.Tests\MyProject.Tests.csproj"
  )

  # This runs "dotnet test". Change to Invoke-Xunit to invoke "dotnet xunit"
  Invoke-Tests $test_projects -c $configuration --no-build
}

target deploy {
  # Run dotnet pack to generate the nuget packages
  Remove-Item $packages_dir -Force -Recurse 2> $null
  Invoke-Dotnet pack $solution_file -c $configuration /p:PackageOutputPath=$packages_dir /p:Version=$version

  # Find all the packages and display them for confirmation
  $packages = dir $packages_dir -Filter "*.nupkg"

  Write-Host "Packages to upload:"
  $packages | ForEach-Object { Write-Host $_.Name }

  # Ensure we haven't run this by accident.
  $result = New-Prompt "Upload Packages" "Do you want to publish the NuGet packages?" @(
    @("&No", "Does not upload the packages."),
    @("&Yes", "Uploads the packages.")
  )

  # Cancelled
  if ($result -eq 0) {
    "Upload aborted"
  }
  # upload
  elseif ($result -eq 1) {
    $packages | ForEach-Object {
      $package = $_.FullName
      Write-Host "Uploading $package"
      Invoke-Dotnet nuget push $package
      Write-Host
    }
  }
}

Start-Build $args
```

This script defines a single target called `default`. Run the script and the target will be executed.

# Built-in functions

Any powershell function can be used inside a target, this includes calling .net framework types. In addition, posh-build defined several functions that make working with the `dotnet` CLI tools easier:

| Function             | Description | Example |
| -------------------- | ----------- | ------- |
| `Invoke-Dotnet`      | Runs the specified `dotnet` CLI tool. All parameters are passed to the tool. If the tool fails (with a non-zero exit code), then the build will fail. | `Invoke-Dotnet build MySolution.sln -c Release --no-incremental` |
| `Invoke-Tests`       | Runs `dotnet test` against the specified test projects | `$projects = @("tests\NetFx\NetFxTests.csproj", "tests\NetCore\NetCore.csproj"); Invoke-Tests $projects -c release` |
| `Invoke-Xunit`       | Runs `dotnet xunit` against the specified test projects. | `$projects = @("tests\NetFx\NetFxTests.csproj", "tests\NetCore\NetCore.csproj"); Invoke-Xunit $projects -c release` |
| `New-Prompt`         | Creates a command line confirmation prompt. Useful for confirming deployments. | `$result = New-Prompt "Upload Packages" "Do you want to upload the NuGet packages to Nuget?" @{ "&No" = "Cancel upload."; "&Yes" = "Upload the packages." }` |
