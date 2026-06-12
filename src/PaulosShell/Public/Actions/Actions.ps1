function Invoke-PaulosDelta {
  param([string]$Action = "status")

  if ($Action -in @("fix", "config", "configure", "setup")) {
    if (-not (Test-PaulosCommand git)) { Write-Warning "Git is not installed. Run 'paulos tools install' first."; return }
    if (-not (Test-PaulosCommand delta)) { Write-Warning "Delta is not installed. Run 'paulos tools install' first."; return }
    git config --global core.pager "delta"
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global merge.conflictstyle zdiff3
    Write-Host "✓ Git Delta configured globally." -ForegroundColor Green
    Write-Host "Try: git diff, git show, git log -p, or gdiff" -ForegroundColor DarkGray
    return
  }

  if ($Action -eq "unified") { git config --global delta.side-by-side false; Write-Host "✓ Delta side-by-side disabled." -ForegroundColor Green; return }
  if ($Action -in @("side", "side-by-side")) { git config --global delta.side-by-side true; Write-Host "✓ Delta side-by-side enabled." -ForegroundColor Green; return }
  if ($Action -eq "test") {
    Write-Host ""
    Write-Host "Delta test commands" -ForegroundColor Cyan
    Write-Host "  git diff" -ForegroundColor DarkGray
    Write-Host "  git diff --staged" -ForegroundColor DarkGray
    Write-Host "  git show HEAD" -ForegroundColor DarkGray
    Write-Host "  git log -p" -ForegroundColor DarkGray
    Write-Host "  git diff main...HEAD" -ForegroundColor DarkGray
    Write-Host ""
    return
  }

  $rows = @(
    [PSCustomObject]@{ Status = if (Test-PaulosCommand git) { "✓" } else { "missing" }; Item = "Git installed"; Detail = if (Test-PaulosCommand git) { git --version } else { "Run 'paulos tools install'" } },
    [PSCustomObject]@{ Status = if (Test-PaulosCommand delta) { "✓" } else { "missing" }; Item = "Delta installed"; Detail = if (Test-PaulosCommand delta) { delta --version } else { "Run 'paulos tools install'" } }
  )

  $expected = @(
    @{ Key = "core.pager"; Expected = "delta" },
    @{ Key = "interactive.diffFilter"; Expected = "delta --color-only" },
    @{ Key = "delta.navigate"; Expected = "true" },
    @{ Key = "delta.side-by-side"; Expected = "true" },
    @{ Key = "merge.conflictstyle"; Expected = "zdiff3" }
  )

  foreach ($cfg in $expected) {
    $current = Get-PaulosGitConfig $cfg.Key
    $ok = $current -eq $cfg.Expected
    $rows += [PSCustomObject]@{ Status = if ($ok) { "✓" } else { "setup" }; Item = $cfg.Key; Detail = if ($current) { "current: $current | expected: $($cfg.Expected)" } else { "not set | expected: $($cfg.Expected)" } }
  }

  Write-Host ""
  Write-Host "Git Delta" -ForegroundColor Cyan
  Show-PaulosActionTable -Rows $rows
  Write-Host "Commands: paulos delta fix | paulos delta test | paulos delta unified | paulos delta side" -ForegroundColor DarkGray
}

function Invoke-PaulosFont {
  param([string]$Action = "status")
  $fontName = "CaskaydiaCove Nerd Font Mono"
  $downloadPage = "https://www.nerdfonts.com/font-downloads"
  $directZip = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CaskaydiaCove.zip"

  if ($Action -in @("open", "page", "link")) { Start-Process $downloadPage; Write-Host "Opened Nerd Fonts download page." -ForegroundColor Green; return }
  if ($Action -in @("download", "zip")) { Start-Process $directZip; Write-Host "Opened direct CaskaydiaCove.zip download." -ForegroundColor Green; return }
  if ($Action -in @("list", "fonts")) { Get-PaulosInstalledFontNames | Where-Object { $_ -match "Caskaydia|Cascadia|Nerd|Mono" } | Sort-Object; return }

  $installed = Test-PaulosNerdFontInstalled
  Write-Host ""
  Write-Host "Terminal font" -ForegroundColor Cyan
  Show-PaulosActionTable -Rows @(
    [PSCustomObject]@{ Status = if ($installed) { "✓" } else { "manual" }; Item = "Installed font"; Detail = if ($installed) { "$fontName appears to be installed" } else { "$fontName not detected" } },
    [PSCustomObject]@{ Status = "manual"; Item = "Windows Terminal"; Detail = "Set font face to: $fontName" },
    [PSCustomObject]@{ Status = "manual"; Item = "Install/update"; Detail = "Download zip, extract .ttf files, right-click, Install for all users" }
  )
  Write-Host "Commands: paulos font download | paulos font open | paulos font list" -ForegroundColor DarkGray
}

function Invoke-PaulosStarship {
  param([string]$Action = "status")
  $configPath = Get-PaulosStarshipConfigPath

  if ($Action -in @("fix", "setup", "install")) {
    Set-PaulosManagedBlock -StartMarker "# >>> PaulosShell starship block >>>" -EndMarker "# <<< PaulosShell starship block <<<" -Block (Get-PaulosStarshipBlock)
    Write-Host "✓ Starship profile block installed/updated." -ForegroundColor Green
    Write-Host "Reopen the terminal or run '. `$PROFILE'." -ForegroundColor DarkGray
    return
  }

  if ($Action -eq "config") {
    $configDir = Split-Path $configPath -Parent
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    if (Test-Path $configPath) {
      $backup = "$configPath.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
      Copy-Item $configPath $backup -Force
      Write-Host "✓ Existing starship.toml backed up to $backup" -ForegroundColor Green
    }
    Set-Content -Path $configPath -Value (Get-PaulosDefaultStarshipConfig) -Encoding UTF8
    Write-Host "✓ Default starship.toml written to $configPath" -ForegroundColor Green
    return
  }

  if ($Action -eq "open") {
    if (-not (Test-Path $configPath)) { Invoke-PaulosStarship config }
    if (Test-PaulosCommand npp) { npp $configPath } else { notepad $configPath }
    return
  }

  Write-Host ""
  Write-Host "Starship" -ForegroundColor Cyan
  Show-PaulosActionTable -Rows @(
    [PSCustomObject]@{ Status = if (Test-PaulosCommand starship) { "✓" } else { "missing" }; Item = "Starship installed"; Detail = if (Test-PaulosCommand starship) { starship --version | Select-Object -First 1 } else { "Run 'paulos tools install'" } },
    [PSCustomObject]@{ Status = if (Test-PaulosProfileContains "# >>> PaulosShell starship block >>>") { "✓" } else { "setup" }; Item = "Profile init block"; Detail = "Run: paulos starship fix" },
    [PSCustomObject]@{ Status = if (Test-Path $configPath) { "✓" } else { "setup" }; Item = "starship.toml"; Detail = if (Test-Path $configPath) { $configPath } else { "Run: paulos starship config" } }
  )
  Write-Host "Commands: paulos starship fix | paulos starship config | paulos starship open" -ForegroundColor DarkGray
}

function Invoke-PaulosGithub {
  param([string]$Action = "status")

  if (-not (Test-PaulosCommand gh)) {
    Write-Warning "GitHub CLI is not installed. Run 'paulos tools install' first."
    return
  }

  if ($Action -eq "login") {
    gh auth login
    return
  }

  if ($Action -in @("setup-git", "git")) {
    gh auth setup-git
    return
  }

  if ($Action -eq "logout") {
    gh auth logout
    return
  }

  Write-Host ""
  Write-Host "GitHub CLI" -ForegroundColor Cyan

  $authOutput = gh auth status 2>&1
  $ok = $LASTEXITCODE -eq 0

  Show-PaulosActionTable -Rows @(
    [PSCustomObject]@{
      Status = if ($ok) { "✓" } else { "setup" }
      Item   = "Authentication"
      Detail = if ($ok) { "Authenticated. Useful commands: prs, prc, prv" } else { "Run: paulos github login" }
    }
  )

  if ($Action -eq "verbose") {
    $authOutput
  }

  Write-Host "Commands: paulos github login | paulos github setup-git | paulos github verbose" -ForegroundColor DarkGray
}

function Invoke-PaulosUpdate {
  param([string]$Action = "status")

  if ($Action -eq "winget") {
    winget upgrade --all
    return
  }

  if ($Action -in @("modules", "psmodules")) {
    Update-Module
    return
  }

  if ($Action -eq "pnpm") {
    pnpm update
    return
  }

  if ($Action -in @("check", "status")) {
    Show-PaulosUpdateStatus
    return
  }

  if ($Action -eq "clear-cache") {
    Clear-PaulosUpdateCache | Out-Null
    Write-Host "PaulosShell update-check cache cleared." -ForegroundColor Green
    return
  }

  if ($Action -in @("self", "yes", "force")) {
    $latest = Get-PaulosLatestRelease
    Invoke-PaulosSelfUpdate -Action $Action -LatestRelease $latest
    return
  }

  Write-Host ""
  Write-Host "Update helpers" -ForegroundColor Cyan
  Show-PaulosActionTable -Rows @(
    [PSCustomObject]@{ Status = if (Test-PaulosCommand winget) { "✓" } else { "missing" }; Item = "winget tools"; Detail = "paulos update winget" },
    [PSCustomObject]@{ Status = "ok"; Item = "PS modules"; Detail = "paulos update modules" },
    [PSCustomObject]@{ Status = if (Test-PaulosCommand pnpm) { "✓" } else { "missing" }; Item = "project deps"; Detail = "paulos update pnpm" },
    [PSCustomObject]@{ Status = "manual"; Item = "Nerd Font"; Detail = "paulos font download" },
    [PSCustomObject]@{ Status = "info"; Item = "Check PaulosShell"; Detail = "paulos update check" },
    [PSCustomObject]@{ Status = "manual"; Item = "Update PaulosShell"; Detail = "paulos update self / yes / force" }
  )
}

function Invoke-PaulosPnpm {
  param([string]$Action = "status")
  if (-not (Test-PaulosCommand pnpm)) { Write-Warning "pnpm is not installed. Run 'paulos tools install' first."; return }
  if ($Action -eq "approve") { pnpm approve-builds; return }
  if ($Action -eq "store") { pnpm store path; return }
  Write-Host ""
  Write-Host "pnpm" -ForegroundColor Cyan
  Show-PaulosActionTable -Rows @(
    [PSCustomObject]@{ Status = "✓"; Item = "pnpm version"; Detail = pnpm -v },
    [PSCustomObject]@{ Status = "info"; Item = "default agent"; Detail = "NI_DEFAULT_AGENT=$env:NI_DEFAULT_AGENT" },
    [PSCustomObject]@{ Status = "info"; Item = "global agent"; Detail = "NI_GLOBAL_AGENT=$env:NI_GLOBAL_AGENT" },
    [PSCustomObject]@{ Status = "info"; Item = "approve builds"; Detail = "Run: paulos pnpm approve" }
  )
}

function Invoke-PaulosDoctor { Show-PaulosTools; Show-PaulosModules; Invoke-PaulosDelta status; Invoke-PaulosFont status; Invoke-PaulosStarship status; Invoke-PaulosPnpm status; Invoke-PaulosGithub status }
function Invoke-PaulosSetup { Write-Host ""; Write-Host "Paulos setup dashboard" -ForegroundColor Cyan; Invoke-PaulosFont status; Invoke-PaulosDelta status; Invoke-PaulosStarship status; Invoke-PaulosGithub status; Invoke-PaulosPnpm status; Invoke-PaulosUpdate status }

function Invoke-PaulosWizard {
  Write-Host ""
  Write-Host "Paulos Shell Setup Wizard" -ForegroundColor Cyan
  Write-Host "This wizard asks before making changes." -ForegroundColor DarkGray
  Write-Host ""

  $answer = Read-Host "Backup current PowerShell profile? [Y/n]"
  if ($answer -notmatch "^(n|N)") { Backup-PaulosProfile | Out-Null }

  $answer = Read-Host "Install missing essential tools/modules with winget/PowerShellGet? [y/N]"
  if ($answer -match "^(y|Y)") { Install-PaulosDevShellTools }

  $answer = Read-Host "Configure Git Delta now? [y/N]"
  if ($answer -match "^(y|Y)") { Invoke-PaulosDelta fix }

  $answer = Read-Host "Install Starship profile init block? [y/N]"
  if ($answer -match "^(y|Y)") { Invoke-PaulosStarship fix }

  $answer = Read-Host "Create/update default starship.toml? [y/N]"
  if ($answer -match "^(y|Y)") { Invoke-PaulosStarship config }

  $answer = Read-Host "Open CaskaydiaCove Nerd Font download? [y/N]"
  if ($answer -match "^(y|Y)") { Invoke-PaulosFont download }

  $answer = Read-Host "Run GitHub CLI login? [y/N]"
  if ($answer -match "^(y|Y)") { Invoke-PaulosGithub login }

  Write-Host ""
  Write-Host "Final diagnostics:" -ForegroundColor Cyan
  Invoke-PaulosSetup
}
