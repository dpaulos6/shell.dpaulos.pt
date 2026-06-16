[CmdletBinding()]
param(
  [string]$Version,
  [string]$InstallerPath,
  [string]$InstallerUrl,
  [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-CleanVersion {
  param([Parameter(Mandatory = $true)][string]$Value)

  $clean = $Value.Trim()
  $clean = $clean -replace "^v", ""
  return ($clean -split "[-+]")[0]
}

function Write-TextFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )

  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($Version)) {
  $manifest = Import-PowerShellDataFile (Join-Path $repoRoot 'src\PaulosShell\PaulosShell.psd1')
  $Version = [string]$manifest.ModuleVersion
}

$Version = Get-CleanVersion -Value $Version

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $repoRoot 'packaging\winget'
}

if ([string]::IsNullOrWhiteSpace($InstallerPath)) {
  $InstallerPath = Join-Path $repoRoot "artifacts\installer\PaulosShell-$Version-Setup.exe"
}

if ([string]::IsNullOrWhiteSpace($InstallerUrl)) {
  $InstallerUrl = "https://github.com/dpaulos6/shell.dpaulos.pt/releases/download/v$Version/PaulosShell-$Version-Setup.exe"
}

if (-not (Test-Path -LiteralPath $InstallerPath)) {
  throw "Installer not found: $InstallerPath"
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $InstallerPath).Hash
$packageRoot = Join-Path $OutputRoot 'dpaulos6.shell'
$versionRoot = Join-Path $packageRoot $Version

$defaultManifest = @"
PackageIdentifier: dpaulos6.shell
PackageVersion: $Version
DefaultLocale: en-US
ManifestType: version
ManifestVersion: 1.6.0
"@

$localeManifest = @"
PackageIdentifier: dpaulos6.shell
PackageVersion: $Version
PackageLocale: en-US
PackageName: PaulosShell
Publisher: dpaulos6
PackageUrl: https://github.com/dpaulos6/shell.dpaulos.pt
License: MIT
LicenseUrl: https://github.com/dpaulos6/shell.dpaulos.pt/blob/v$Version/LICENSE
Copyright: Copyright (c) Diogo Paulos. All rights reserved.
ShortDescription: A safe, updateable PowerShell dev-shell toolkit with a paulos command center.
ManifestType: defaultLocale
ManifestVersion: 1.6.0
"@

$installerManifest = @"
PackageIdentifier: dpaulos6.shell
PackageVersion: $Version
InstallerType: inno
InstallerLocale: en-US
Scope: user
UpgradeBehavior: install
InstallModes:
  - interactive
  - silent
  - silentWithProgress
Installers:
  - Architecture: x64
    InstallerUrl: $InstallerUrl
    InstallerSha256: $hash
    InstallerSwitches:
      Silent: /VERYSILENT /NORESTART
      SilentWithProgress: /SP- /VERYSILENT /NORESTART
ManifestType: installer
ManifestVersion: 1.6.0
"@

Write-TextFile -Path (Join-Path $versionRoot 'dpaulos6.shell.yaml') -Content $defaultManifest
Write-TextFile -Path (Join-Path $versionRoot 'dpaulos6.shell.defaultLocale.en-US.yaml') -Content $localeManifest
Write-TextFile -Path (Join-Path $versionRoot 'dpaulos6.shell.installer.yaml') -Content $installerManifest

Write-Output (Join-Path $versionRoot 'dpaulos6.shell.installer.yaml')
