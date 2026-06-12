function Test-PaulosCommand {
  param([Parameter(Mandatory = $true)][string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-Cmd {
  param([Parameter(Mandatory = $true)][string]$Name)
  return Test-PaulosCommand $Name
}

function Import-PaulosModuleIfAvailable {
  param([Parameter(Mandatory = $true)][string]$Name)

  if (Get-Module -ListAvailable -Name $Name) {
    Import-Module $Name -ErrorAction SilentlyContinue
    return $true
  }

  return $false
}

function Get-PaulosData {
  param([Parameter(Mandatory = $true)][string]$Name)

  $path = Join-Path $script:PaulosModuleRoot "data\$Name.json"
  if (-not (Test-Path $path)) {
    return @()
  }

  return @(Get-Content $path -Raw | ConvertFrom-Json)
}

function Ensure-PaulosStateDirs {
  New-Item -ItemType Directory -Path $script:PaulosStateDir -Force | Out-Null
  New-Item -ItemType Directory -Path $script:PaulosBackupDir -Force | Out-Null
  New-Item -ItemType Directory -Path $script:PaulosModuleBackupDir -Force | Out-Null
  New-Item -ItemType Directory -Path $script:PaulosDownloadsDir -Force | Out-Null
  New-Item -ItemType Directory -Path $script:PaulosStagingDir -Force | Out-Null
}

function Get-PaulosInstalledModuleRoot {
  return Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules\PaulosShell"
}

function Get-PaulosInstalledModuleManifestPath {
  return Join-Path (Get-PaulosInstalledModuleRoot) "PaulosShell.psd1"
}

function Clear-PaulosUpdateCache {
  if (Test-Path $script:PaulosUpdateStatePath) {
    Remove-Item $script:PaulosUpdateStatePath -Force -ErrorAction SilentlyContinue
    return $true
  }

  return $false
}

function Set-PaulosManifestVersion {
  param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$Version
  )

  if (-not (Test-Path $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
  }

  $content = Get-Content -Path $ManifestPath -Raw
  $pattern = "(?m)^(\s*ModuleVersion\s*=\s*')[^']*(')"

  if ($content -notmatch $pattern) {
    throw "Could not find ModuleVersion in manifest: $ManifestPath"
  }

  $updated = [regex]::Replace($content, $pattern, ('$1' + $Version + '$2'), 1)
  Set-Content -Path $ManifestPath -Value $updated -Encoding UTF8
}

function Get-PaulosCurrentVersion {
  $manifestPath = Join-Path $script:PaulosModuleRoot "PaulosShell.psd1"

  if (-not (Test-Path $manifestPath)) {
    return "0.0.0"
  }

  try {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    return $manifest.Version.ToString()
  }
  catch {
    return "0.0.0"
  }
}

function ConvertTo-PaulosVersion {
  param([Parameter(Mandatory = $true)][string]$Version)

  $clean = $Version.Trim()
  $clean = $clean -replace "^v", ""
  $clean = ($clean -split "[-+]")[0]

  try {
    return [version]$clean
  }
  catch {
    return [version]"0.0.0"
  }
}

function Test-PaulosToolInstalled {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Tool
  )

  $hasCommand = $false
  $hasPath = $false

  if ($Tool.PSObject.Properties.Name -contains "Command" -and -not [string]::IsNullOrWhiteSpace($Tool.Command)) {
    $hasCommand = [bool](Get-Command $Tool.Command -ErrorAction SilentlyContinue)
  }

  if ($Tool.PSObject.Properties.Name -contains "Path" -and -not [string]::IsNullOrWhiteSpace($Tool.Path)) {
    $hasPath = Test-Path $Tool.Path
  }

  return $hasCommand -or $hasPath
}

function Get-PaulosGitConfig {
  param([Parameter(Mandatory = $true)][string]$Key)

  if (-not (Test-PaulosCommand git)) {
    return $null
  }

  return git config --global --get $Key 2>$null
}
