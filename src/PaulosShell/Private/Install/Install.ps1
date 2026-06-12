function Install-PaulosWingetPackageIfMissing {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string]$PackageId
  )

  if (Test-PaulosCommand $Command) {
    Write-Host "✓ $Command already installed" -ForegroundColor Green
    return
  }

  if ([string]::IsNullOrWhiteSpace($PackageId)) {
    Write-Host "No winget package configured for command '$Command'." -ForegroundColor DarkYellow
    return
  }

  if (-not (Test-PaulosCommand winget)) {
    Write-Warning "winget not found. Cannot install $PackageId automatically."
    return
  }

  Write-Host "Installing $PackageId..." -ForegroundColor Cyan
  winget install --id $PackageId -e
}

function Install-PaulosPSModuleIfMissing {
  param([Parameter(Mandatory = $true)][string]$Name)

  if (Get-Module -ListAvailable -Name $Name) {
    Write-Host "✓ PowerShell module $Name already installed" -ForegroundColor Green
    return
  }

  Write-Host "Installing PowerShell module $Name..." -ForegroundColor Cyan
  Install-Module $Name -Scope CurrentUser -Force -AllowClobber
}

function Install-PaulosDevShellTools {
  [CmdletBinding()]
  param(
    [switch]$IncludeOptional,
    [switch]$SkipModules
  )

  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

  $tools = Get-PaulosData "tools"
  foreach ($tool in $tools) {
    $essential = if ($tool.PSObject.Properties.Name -contains "Essential") { [bool]$tool.Essential } else { $false }

    if (-not $IncludeOptional -and -not $essential) { continue }
    if (Test-PaulosToolInstalled $tool) {
      Write-Host "✓ $($tool.Tool) already installed" -ForegroundColor Green
      continue
    }

    if ([string]::IsNullOrWhiteSpace($tool.WingetId)) { continue }

    Install-PaulosWingetPackageIfMissing -Command $tool.Command -PackageId $tool.WingetId
  }

  if (-not $SkipModules) {
    $modules = Get-PaulosData "modules"
    foreach ($module in $modules) {
      if (-not $IncludeOptional -and -not $module.Essential) { continue }
      Install-PaulosPSModuleIfMissing -Name $module.Module
    }
  }

  Write-Host "`nDone. Close and reopen your terminal." -ForegroundColor Green
}

function Install-DevShellTools {
  Install-PaulosDevShellTools @args
}
