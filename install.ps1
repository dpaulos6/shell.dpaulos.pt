[CmdletBinding()]
param(
  [switch]$InstallTools,
  [switch]$ConfigureDelta,
  [switch]$ConfigureStarship,
  [switch]$CreateStarshipConfig,
  [switch]$OpenFontDownload,
  [switch]$NoBoot
)

$ErrorActionPreference = "Stop"

function Write-Step($Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Ensure-Dir($Path) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

$repoRoot = $PSScriptRoot
$moduleSource = Join-Path $repoRoot "src\PaulosShell"
if (-not (Test-Path $moduleSource)) {
  throw "Module source not found: $moduleSource. Run install.ps1 from the repository root."
}

$documents = [Environment]::GetFolderPath("MyDocuments")
$moduleDest = Join-Path $documents "PowerShell\Modules\PaulosShell"
$stateDir = Join-Path $HOME ".paulos-shell"
$backupDir = Join-Path $stateDir "backups"
Ensure-Dir $stateDir
Ensure-Dir $backupDir
Ensure-Dir (Split-Path $moduleDest -Parent)
Ensure-Dir (Split-Path $PROFILE -Parent)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Step "Backing up current PowerShell profile"
if (-not (Test-Path $PROFILE)) {
  New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
$profileBackup = Join-Path $backupDir "profile.$timestamp.ps1.bak"
Copy-Item $PROFILE $profileBackup -Force
Write-Host "✓ Profile backup: $profileBackup" -ForegroundColor Green

Write-Step "Installing PaulosShell module"
if (Test-Path $moduleDest) {
  $moduleBackup = Join-Path $backupDir "PaulosShell.module.$timestamp"
  Copy-Item $moduleDest $moduleBackup -Recurse -Force
  Remove-Item $moduleDest -Recurse -Force
  Write-Host "✓ Existing module backup: $moduleBackup" -ForegroundColor Green
}
Copy-Item $moduleSource $moduleDest -Recurse -Force
Write-Host "✓ Module copied to $moduleDest" -ForegroundColor Green

Write-Step "Updating managed profile block"
$start = "# >>> PaulosShell managed block >>>"
$end = "# <<< PaulosShell managed block <<<"
$block = @"
# >>> PaulosShell managed block >>>
`$paulosModulePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules\PaulosShell\PaulosShell.psd1"
if (Test-Path `$paulosModulePath) {
  Import-Module `$paulosModulePath -Force
  Initialize-PaulosShell$(if ($NoBoot) { " -NoBoot" } else { "" })
}
else {
  Write-Host "PaulosShell module not found at `$paulosModulePath" -ForegroundColor DarkYellow
}
# <<< PaulosShell managed block <<<
"@
$content = Get-Content $PROFILE -Raw
$pattern = [regex]::Escape($start) + ".*?" + [regex]::Escape($end)
$content = [regex]::Replace($content, $pattern, "", [System.Text.RegularExpressions.RegexOptions]::Singleline).TrimEnd()
if ($content.Length -gt 0) { $content = $content + "`r`n`r`n" }
$content = $content + $block.Trim() + "`r`n"
Set-Content -Path $PROFILE -Value $content -Encoding UTF8
Write-Host "✓ Managed block installed in $PROFILE" -ForegroundColor Green

Write-Step "Importing module for optional setup"
Import-Module (Join-Path $moduleDest "PaulosShell.psd1") -Force

if ($InstallTools) {
  Write-Step "Installing essential tools/modules"
  Install-PaulosDevShellTools
}

if ($ConfigureDelta) {
  Write-Step "Configuring Git Delta"
  paulos delta fix
}

if ($ConfigureStarship) {
  Write-Step "Installing Starship profile block"
  paulos starship fix
}

if ($CreateStarshipConfig) {
  Write-Step "Creating Starship config"
  paulos starship config
}

if ($OpenFontDownload) {
  Write-Step "Opening Nerd Font download"
  paulos font download
}

Write-Step "Done"
Write-Host "Open a new terminal, or run: . `$PROFILE" -ForegroundColor Green
Write-Host "Then run: paulos setup" -ForegroundColor DarkGray
