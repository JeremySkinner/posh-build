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