[CmdletBinding()]
param(
  [switch]$InstallTools,
  [switch]$RunDoctor
)

$ErrorActionPreference = "Stop"
function Write-Step($Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Ensure-Dir($Path) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

$repoRoot = $PSScriptRoot
$moduleSource = Join-Path $repoRoot "src\PaulosShell"
if (-not (Test-Path $moduleSource)) { throw "Module source not found: $moduleSource. Run update.ps1 from the repository root." }

$documents = [Environment]::GetFolderPath("MyDocuments")
$moduleDest = Join-Path $documents "PowerShell\Modules\PaulosShell"
$backupDir = Join-Path $HOME ".paulos-shell\backups"
Ensure-Dir $backupDir
Ensure-Dir (Split-Path $moduleDest -Parent)
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Step "Updating PaulosShell module"
if (Test-Path $moduleDest) {
  $moduleBackup = Join-Path $backupDir "PaulosShell.module.$timestamp"
  Copy-Item $moduleDest $moduleBackup -Recurse -Force
  Remove-Item $moduleDest -Recurse -Force
  Write-Host "✓ Existing module backup: $moduleBackup" -ForegroundColor Green
}
Copy-Item $moduleSource $moduleDest -Recurse -Force
Write-Host "✓ Module updated at $moduleDest" -ForegroundColor Green

Import-Module (Join-Path $moduleDest "PaulosShell.psd1") -Force

if ($InstallTools) { Install-PaulosDevShellTools }
if ($RunDoctor) { paulos doctor }

Write-Host "`n✓ Update complete. Run '. `$PROFILE' or open a new terminal." -ForegroundColor Green
