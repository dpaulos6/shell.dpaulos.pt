[CmdletBinding()]
param(
  [switch]$RemoveFiles,
  [switch]$Force
)

$ErrorActionPreference = "Stop"
function Write-Step($Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Ensure-Dir($Path) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

$backupDir = Join-Path $HOME ".paulos-shell\backups"
Ensure-Dir $backupDir
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Step "Backing up profile"
if (Test-Path $PROFILE) {
  $backup = Join-Path $backupDir "profile.before-uninstall.$timestamp.ps1.bak"
  Copy-Item $PROFILE $backup -Force
  Write-Host "✓ Backup: $backup" -ForegroundColor Green
}

Write-Step "Removing managed profile blocks"
if (Test-Path $PROFILE) {
  $content = Get-Content $PROFILE -Raw
  $blocks = @(
    @{ Start = "# >>> PaulosShell managed block >>>"; End = "# <<< PaulosShell managed block <<<" },
    @{ Start = "# >>> PaulosShell starship block >>>"; End = "# <<< PaulosShell starship block <<<" }
  )
  foreach ($block in $blocks) {
    $pattern = [regex]::Escape($block.Start) + ".*?" + [regex]::Escape($block.End)
    $content = [regex]::Replace($content, $pattern, "", [System.Text.RegularExpressions.RegexOptions]::Singleline).Trim()
  }
  Set-Content -Path $PROFILE -Value ($content + "`r`n") -Encoding UTF8
  Write-Host "✓ Managed blocks removed from profile." -ForegroundColor Green
}

$documents = [Environment]::GetFolderPath("MyDocuments")
$moduleDest = Join-Path $documents "PowerShell\Modules\PaulosShell"
if ($RemoveFiles) {
  if (-not $Force) {
    $answer = Read-Host "Delete installed module folder '$moduleDest'? [y/N]"
    if ($answer -notmatch "^(y|Y)") {
      Write-Host "Skipped deleting module files." -ForegroundColor DarkYellow
      return
    }
  }

  if (Test-Path $moduleDest) {
    Remove-Item $moduleDest -Recurse -Force
    Write-Host "✓ Deleted $moduleDest" -ForegroundColor Green
  }
}
else {
  Write-Host "Module files kept at $moduleDest" -ForegroundColor DarkGray
  Write-Host "Run .\uninstall.ps1 -RemoveFiles to remove them." -ForegroundColor DarkGray
}

Write-Host "`n✓ Uninstall complete. Open a new terminal." -ForegroundColor Green
