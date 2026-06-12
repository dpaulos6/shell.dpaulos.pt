function Test-PaulosUpdateAvailable {
  param(
    [Parameter(Mandatory = $true)][string]$CurrentVersion,
    [Parameter(Mandatory = $true)][string]$LatestVersion
  )

  $current = ConvertTo-PaulosVersion $CurrentVersion
  $latest = ConvertTo-PaulosVersion $LatestVersion

  return $latest -gt $current
}

function Get-PaulosUpdateState {
  Ensure-PaulosStateDirs

  if (-not (Test-Path $script:PaulosUpdateStatePath)) {
    return $null
  }

  try {
    return Get-Content $script:PaulosUpdateStatePath -Raw | ConvertFrom-Json
  }
  catch {
    return $null
  }
}

function Save-PaulosUpdateState {
  param(
    [Parameter(Mandatory = $true)][object]$State
  )

  Ensure-PaulosStateDirs

  $State |
    ConvertTo-Json -Depth 6 |
    Set-Content -Path $script:PaulosUpdateStatePath -Encoding UTF8
}

function Test-PaulosShouldCheckForUpdates {
  param([switch]$Force)

  if ($Force) {
    return $true
  }

  if ($env:PAULOS_NO_UPDATE_CHECK -eq "1") {
    return $false
  }

  $state = Get-PaulosUpdateState

  if ($null -eq $state) {
    return $true
  }

  if ($state.PSObject.Properties.Name -notcontains "CheckedAt") {
    return $true
  }

  try {
    $checkedAt = [datetime]$state.CheckedAt
    $nextCheck = $checkedAt.AddHours($script:PaulosUpdateCheckIntervalHours)
    return (Get-Date) -ge $nextCheck
  }
  catch {
    return $true
  }
}

function Get-PaulosLatestRelease {
  $url = "https://api.github.com/repos/$script:PaulosRepoOwner/$script:PaulosRepoName/releases/latest"

  $headers = @{
    "Accept" = "application/vnd.github+json"
    "User-Agent" = "PaulosShell"
  }

  try {
    $release = Invoke-RestMethod `
      -Uri $url `
      -Headers $headers `
      -Method Get `
      -TimeoutSec 3 `
      -ErrorAction Stop

    return [PSCustomObject]@{
      Ok = $true
      Version = [string]$release.tag_name
      TagName = [string]$release.tag_name
      Name = [string]$release.name
      Url = [string]$release.html_url
      ZipballUrl = [string]$release.zipball_url
      PublishedAt = [string]$release.published_at
      Error = ""
    }
  }
  catch {
    return [PSCustomObject]@{
      Ok = $false
      Version = ""
      TagName = ""
      Name = ""
      Url = ""
      ZipballUrl = ""
      PublishedAt = ""
      Error = $_.Exception.Message
    }
  }
}

function Confirm-PaulosSelfUpdate {
  param(
    [Parameter(Mandatory = $true)][string]$CurrentVersion,
    [Parameter(Mandatory = $true)][string]$LatestVersion,
    [Parameter(Mandatory = $true)][string]$Action
  )

  if ($Action -in @("yes", "force")) {
    return $true
  }

  $answer = Read-Host "Install PaulosShell $LatestVersion over $CurrentVersion now? [y/N]"
  return $answer -match "^(y|Y)"
}

function Invoke-PaulosSelfUpdate {
  param(
    [Parameter(Mandatory = $true)][string]$Action,
    [Parameter(Mandatory = $true)][object]$LatestRelease
  )

  Ensure-PaulosStateDirs

  if (-not $LatestRelease.Ok) {
    Write-Warning "Unable to fetch the latest release: $($LatestRelease.Error)"
    return
  }

  $installedRoot = Get-PaulosInstalledModuleRoot
  $installedManifest = Get-PaulosInstalledModuleManifestPath
  $currentVersion = Get-PaulosCurrentVersion
  $latestVersion = [string]$LatestRelease.Version
  $reinstallLatest = $Action -eq "force"

  if (-not $reinstallLatest -and -not (Test-PaulosUpdateAvailable -CurrentVersion $currentVersion -LatestVersion $latestVersion)) {
    Write-Host ""
    Write-Host "PaulosShell is up to date." -ForegroundColor Green
    Write-Host "  Current: $currentVersion" -ForegroundColor DarkGray
    Write-Host "  Latest:  $latestVersion" -ForegroundColor DarkGray
    return
  }

  if (-not (Confirm-PaulosSelfUpdate -CurrentVersion $currentVersion -LatestVersion $latestVersion -Action $Action)) {
    Write-Host ""
    Write-Host "Update cancelled." -ForegroundColor DarkGray
    return
  }

  if (-not (Test-Path $installedManifest)) {
    Write-Warning "Installed module manifest not found at $installedManifest"
    return
  }

  if ([string]::IsNullOrWhiteSpace($LatestRelease.ZipballUrl)) {
    throw "Latest release did not include a zipball_url."
  }

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $cleanVersion = ($latestVersion -replace "^v", "") -replace "[^0-9A-Za-z._-]", "_"
  $downloadPath = Join-Path $script:PaulosDownloadsDir ("PaulosShell.{0}.{1}.zip" -f $cleanVersion, $timestamp)
  $stagingPath = Join-Path $script:PaulosStagingDir ("PaulosShell.{0}" -f $timestamp)
  $moduleBackupPath = Join-Path $script:PaulosModuleBackupDir ("PaulosShell.{0}" -f $timestamp)
  $releaseRoot = $null
  $backupCreated = $false

  if (Test-Path $stagingPath) {
    Remove-Item $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
  }

  Write-Host ""
  Write-Host "Downloading PaulosShell $latestVersion..." -ForegroundColor Cyan
  Invoke-WebRequest `
    -Uri $LatestRelease.ZipballUrl `
    -OutFile $downloadPath `
    -Headers @{
      "Accept" = "application/vnd.github+json"
      "User-Agent" = "PaulosShell"
    } `
    -TimeoutSec 60 `
    -ErrorAction Stop | Out-Null

  Write-Host "Expanding release archive..." -ForegroundColor Cyan
  Expand-Archive -LiteralPath $downloadPath -DestinationPath $stagingPath -Force

  $releaseRoot = Get-ChildItem -Path $stagingPath -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
      (Test-Path (Join-Path $_.FullName "PaulosShell.psm1")) -and
      (Test-Path (Join-Path $_.FullName "PaulosShell.psd1"))
    } |
    Sort-Object { $_.FullName.Length } |
    Select-Object -First 1

  if ($null -eq $releaseRoot) {
    throw "Could not locate an extracted PaulosShell module in $stagingPath."
  }

  Write-Host "Backing up installed module..." -ForegroundColor Cyan
  Copy-Item -Path $installedRoot -Destination $moduleBackupPath -Recurse -Force
  $backupCreated = $true

  try {
    Remove-Item -Path $installedRoot -Recurse -Force -ErrorAction Stop
    New-Item -ItemType Directory -Path $installedRoot -Force | Out-Null
    Copy-Item -Path (Join-Path $releaseRoot.FullName "*") -Destination $installedRoot -Recurse -Force -ErrorAction Stop
    Set-PaulosManifestVersion -ManifestPath $installedManifest -Version ($latestVersion -replace "^v", "")
    Clear-PaulosUpdateCache | Out-Null
  }
  catch {
    if ($backupCreated -and (Test-Path $moduleBackupPath)) {
      Remove-Item -Path $installedRoot -Recurse -Force -ErrorAction SilentlyContinue
      Copy-Item -Path $moduleBackupPath -Destination $installedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    throw
  }

  Write-Host ""
  Write-Host "PaulosShell updated to $latestVersion." -ForegroundColor Green
  Write-Host "Backup: $moduleBackupPath" -ForegroundColor DarkGray
  Write-Host ""

  Reset-PaulosShellModule -NoBoot
}

function Invoke-PaulosUpdateCheck {
  param(
    [switch]$Force,
    [switch]$Quiet,
    [switch]$SaveOnly
  )

  if (-not (Test-PaulosShouldCheckForUpdates -Force:$Force)) {
    $state = Get-PaulosUpdateState

    if ($Quiet -or $null -eq $state) {
      return $state
    }

    if (
      $state.PSObject.Properties.Name -contains "UpdateAvailable" -and
      [bool]$state.UpdateAvailable
    ) {
      Write-Host ""
      Write-Host "⬆ PaulosShell update available: $($state.LatestVersion)" -ForegroundColor Yellow
      Write-Host "  Current: $($state.CurrentVersion)" -ForegroundColor DarkGray
      Write-Host "  Run: paulos update self" -ForegroundColor DarkGray
    }

    return $state
  }

  $currentVersion = Get-PaulosCurrentVersion
  $latest = Get-PaulosLatestRelease

  $state = [PSCustomObject]@{
    CheckedAt = (Get-Date).ToString("o")
    CurrentVersion = $currentVersion
    LatestVersion = if ($latest.Ok) { $latest.Version } else { "" }
    UpdateAvailable = if ($latest.Ok) { Test-PaulosUpdateAvailable -CurrentVersion $currentVersion -LatestVersion $latest.Version } else { $false }
    ReleaseUrl = if ($latest.Ok) { $latest.Url } else { "" }
    Error = if ($latest.Ok) { "" } else { $latest.Error }
  }

  Save-PaulosUpdateState -State $state

  if ($SaveOnly -or $Quiet) {
    return $state
  }

  if ($state.UpdateAvailable) {
    Write-Host ""
    Write-Host "⬆ PaulosShell update available: $($state.LatestVersion)" -ForegroundColor Yellow
    Write-Host "  Current: $($state.CurrentVersion)" -ForegroundColor DarkGray
    Write-Host "  Run: paulos update self" -ForegroundColor DarkGray
  }
  elseif ($Force) {
    Write-Host ""
    Write-Host "✓ PaulosShell is up to date." -ForegroundColor Green
    Write-Host "  Current: $($state.CurrentVersion)" -ForegroundColor DarkGray
  }

  return $state
}

function Reset-PaulosShellModule {
  param(
    [switch]$NoBoot
  )

  $manifestPath = Join-Path $script:PaulosModuleRoot "PaulosShell.psd1"

  if (-not (Test-Path $manifestPath)) {
    Write-Warning "Could not reset PaulosShell because manifest was not found: $manifestPath"
    return
  }

  try {
    Import-Module $manifestPath -Force -Global -ErrorAction Stop

    if (Get-Command Initialize-PaulosShell -ErrorAction SilentlyContinue) {
      Initialize-PaulosShell -NoBoot:$NoBoot
    }

    Write-Host "✓ PaulosShell reset." -ForegroundColor Green

    if (Get-Command Show-PaulosVersion -ErrorAction SilentlyContinue) {
      Show-PaulosVersion
    }
  }
  catch {
    Write-Warning "Update installed, but automatic reset failed: $($_.Exception.Message)"
    Write-Host "Reset manually with:" -ForegroundColor DarkGray
    Write-Host "  Remove-Module PaulosShell -Force -ErrorAction SilentlyContinue" -ForegroundColor DarkGray
    Write-Host "  . `$PROFILE" -ForegroundColor DarkGray
  }
}

function Show-PaulosUpdateStatus {
  $state = Invoke-PaulosUpdateCheck -Force

  Write-Host ""
  Write-Host "PaulosShell update status" -ForegroundColor Cyan

  Show-PaulosActionTable -Rows @(
    [PSCustomObject]@{
      Status = if ($state.UpdateAvailable) { "setup" } else { "✓" }
      Item   = "Current version"
      Detail = $state.CurrentVersion
    },
    [PSCustomObject]@{
      Status = if ($state.LatestVersion) { "info" } else { "missing" }
      Item   = "Latest release"
      Detail = if ($state.LatestVersion) { $state.LatestVersion } else { "Could not fetch latest release" }
    },
    [PSCustomObject]@{
      Status = if ($state.UpdateAvailable) { "setup" } else { "✓" }
      Item   = "Update"
      Detail = if ($state.UpdateAvailable) { "Run: paulos update self" } else { "No update available" }
    }
  )

  if ($state.Error) {
    Write-Host ""
    Write-Host "Update check error: $($state.Error)" -ForegroundColor DarkYellow
  }
}
