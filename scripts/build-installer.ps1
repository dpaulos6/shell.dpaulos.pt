[CmdletBinding()]
param(
  [string]$Version,
  [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-CleanVersion {
  param([Parameter(Mandatory = $true)][string]$Value)

  $clean = $Value.Trim()
  $clean = $clean -replace "^v", ""
  return ($clean -split "[-+]")[0]
}

function Get-InnoSetupCompiler {
  $cmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  $candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return $candidate
    }
  }

  throw "Could not find iscc.exe. Install Inno Setup 6 or add it to PATH."
}

$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($Version)) {
  $manifest = Import-PowerShellDataFile (Join-Path $repoRoot 'src\PaulosShell\PaulosShell.psd1')
  $Version = [string]$manifest.ModuleVersion
}

$Version = Get-CleanVersion -Value $Version

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
  $OutputDir = Join-Path $repoRoot 'artifacts\installer'
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$compiler = Get-InnoSetupCompiler
$issPath = Join-Path $repoRoot 'packaging\installer\PaulosShell.iss'

if (-not (Test-Path -LiteralPath $issPath)) {
  throw "Installer script not found: $issPath"
}

$arguments = @(
  "/Qp"
  "/DAppVersion=$Version"
  "/DSourceRoot=$repoRoot"
  "/O$OutputDir"
  $issPath
)

& $compiler @arguments

$installerPath = Join-Path $OutputDir "PaulosShell-$Version-Setup.exe"
if (-not (Test-Path -LiteralPath $installerPath)) {
  throw "Installer build did not produce: $installerPath"
}

Write-Output $installerPath
