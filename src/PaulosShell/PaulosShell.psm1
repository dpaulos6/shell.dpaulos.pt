# PaulosShell.psm1
# Safe, updateable PowerShell dev-shell toolkit.
# Keep user-specific customizations in your normal profile or ~/.paulos-shell/local.ps1.

Set-StrictMode -Version Latest

$script:PaulosModuleRoot = $PSScriptRoot
$script:PaulosStateDir = Join-Path $HOME ".paulos-shell"
$script:PaulosBackupDir = Join-Path $script:PaulosStateDir "backups"
$script:PaulosModuleBackupDir = Join-Path $script:PaulosBackupDir "modules"
$script:PaulosDownloadsDir = Join-Path $script:PaulosStateDir "downloads"
$script:PaulosStagingDir = Join-Path $script:PaulosStateDir "staging"
$script:PaulosRepoOwner = "dpaulos6"
$script:PaulosRepoName = "shell.dpaulos.pt"
$script:PaulosUpdateCheckIntervalHours = 12
$script:PaulosUpdateStatePath = Join-Path $script:PaulosStateDir "update-check.json"

$moduleFiles = @(
  "Private\Core\Core.ps1"
  "Private\Git\Git.ps1"
  "Private\Profile\Profile.ps1"
  "Private\Install\Install.ps1"
  "Private\UI\UI.ps1"
  "Private\Update\Update.ps1"
  "Public\Core\Help.ps1"
  "Public\Core\Initialization.ps1"
  "Public\Actions\Actions.ps1"
  "Public\Actions\Repos.ps1"
  "Public\Commands\Commands.ps1"
)

foreach ($moduleFile in $moduleFiles) {
  $path = Join-Path $script:PaulosModuleRoot $moduleFile

  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required PaulosShell module file not found: $path"
  }

  . $path
}
