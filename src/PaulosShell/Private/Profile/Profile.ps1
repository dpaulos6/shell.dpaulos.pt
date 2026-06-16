function Backup-PaulosProfile {
  Ensure-PaulosStateDirs

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $safeName = Split-Path $PROFILE -Leaf
  if (-not $safeName) { $safeName = "Microsoft.PowerShell_profile.ps1" }
  $backupPath = Join-Path $script:PaulosBackupDir "$safeName.$timestamp.bak"

  if (Test-Path $PROFILE) {
    Copy-Item $PROFILE $backupPath -Force
    Write-Host "✓ Profile backed up to $backupPath" -ForegroundColor Green
  }
  else {
    New-Item -ItemType Directory -Path (Split-Path $PROFILE -Parent) -Force | Out-Null
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Copy-Item $PROFILE $backupPath -Force
    Write-Host "✓ Empty profile created and backed up to $backupPath" -ForegroundColor Green
  }

  return $backupPath
}

function Restore-PaulosProfile {
  param([string]$Action = "list")

  Ensure-PaulosStateDirs
  $backups = @(Get-ChildItem $script:PaulosBackupDir -Filter "*.bak" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)

  if ($backups.Count -eq 0) {
    Write-Host "No profile backups found in $script:PaulosBackupDir" -ForegroundColor DarkYellow
    return
  }

  if ($Action -eq "latest") {
    $latest = $backups[0]
    Backup-PaulosProfile | Out-Null
    Copy-Item $latest.FullName $PROFILE -Force
    Write-Host "✓ Restored latest backup: $($latest.Name)" -ForegroundColor Green
    Write-Host "Run '. `$PROFILE' or reopen the terminal." -ForegroundColor DarkGray
    return
  }

  Write-Host ""
  Write-Host "Available profile backups" -ForegroundColor Cyan
  $backups | Select-Object LastWriteTime, FullName | Format-Table -AutoSize
  Write-Host "Run 'paulos restore latest' to restore the newest backup." -ForegroundColor DarkGray
}

function Get-PaulosStarshipConfigPath { return Join-Path $HOME ".config\starship.toml" }

function Get-PaulosStarshipBundledConfigPath {
  if ($script:PaulosModuleRoot) {
    return Join-Path $script:PaulosModuleRoot "config\starship.toml"
  }

  return Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path "config\starship.toml"
}

function Get-PaulosStarshipConfigContent {
  $bundledConfigPath = Get-PaulosStarshipBundledConfigPath

  if (-not (Test-Path -LiteralPath $bundledConfigPath)) {
    throw "Bundled Starship config not found: $bundledConfigPath"
  }

  return Get-Content -Path $bundledConfigPath -Raw -Encoding UTF8
}

function Get-PaulosStarshipBlock {
  @'
# >>> PaulosShell starship block >>>
if (Get-Command starship -ErrorAction SilentlyContinue) {
  function Invoke-Starship-TransientFunction {
    & starship module character
  }

  Invoke-Expression (& starship init powershell)

  if (Get-Command Enable-TransientPrompt -ErrorAction SilentlyContinue) {
    Enable-TransientPrompt
  }
}
# <<< PaulosShell starship block <<<
'@
}

function Set-PaulosManagedBlock {
  param(
    [Parameter(Mandatory = $true)][string]$StartMarker,
    [Parameter(Mandatory = $true)][string]$EndMarker,
    [Parameter(Mandatory = $true)][string]$Block
  )
  Backup-PaulosProfile | Out-Null
  $content = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { "" }
  $pattern = [regex]::Escape($StartMarker) + ".*?" + [regex]::Escape($EndMarker)
  $content = [regex]::Replace($content, $pattern, "", [System.Text.RegularExpressions.RegexOptions]::Singleline).TrimEnd()
  if ($content.Length -gt 0) { $content = $content + "`r`n`r`n" }
  $content = $content + $Block.Trim() + "`r`n"
  Set-Content -Path $PROFILE -Value $content -Encoding UTF8
}

function Test-PaulosProfileContains {
  param([string]$Text)

  if (-not (Test-Path $PROFILE)) {
    return $false
  }

  return (Get-Content $PROFILE -Raw).Contains($Text)
}

function Get-PaulosDefaultStarshipConfig {
  return Get-PaulosStarshipConfigContent
}

function Get-PaulosInstalledFontNames {
  $paths = @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts", "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")
  $fontNames = @()
  foreach ($path in $paths) {
    if (Test-Path $path) {
      $props = Get-ItemProperty -Path $path
      $fontNames += $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object { $_.Name }
    }
  }
  return $fontNames
}

function Test-PaulosNerdFontInstalled { return [bool](Get-PaulosInstalledFontNames | Where-Object { $_ -match "CaskaydiaCove.*(Nerd Font Mono|NFM|NF Mono)" }) }
