function Show-PaulosBoot {
  $tools = @(
    [PSCustomObject]@{ Icon = "📦"; Name = "pnpm"; Cmd = "pnpm"; Use = "dev/build/test/i/add" },
    [PSCustomObject]@{ Icon = "🔎"; Name = "ripgrep"; Cmd = "rg"; Use = "grep, todo" },
    [PSCustomObject]@{ Icon = "📁"; Name = "fd"; Cmd = "fd"; Use = "ff <file>" },
    [PSCustomObject]@{ Icon = "🌳"; Name = "eza"; Cmd = "eza"; Use = "ls, ll, lt" },
    [PSCustomObject]@{ Icon = "📖"; Name = "bat"; Cmd = "bat"; Use = "cat <file>" },
    [PSCustomObject]@{ Icon = "🌿"; Name = "lazygit"; Cmd = "lazygit"; Use = "lg" },
    [PSCustomObject]@{ Icon = "🧬"; Name = "delta"; Cmd = "delta"; Use = "gdiff, git diff" },
    [PSCustomObject]@{ Icon = "🟣"; Name = ".NET"; Cmd = "dotnet"; Use = "dn/dnb/dnt/dnw" },
    [PSCustomObject]@{ Icon = "🐙"; Name = "GitHub"; Cmd = "gh"; Use = "prs/prc/prv" },
    [PSCustomObject]@{ Icon = "🧭"; Name = "zoxide"; Cmd = "zoxide"; Use = "smart cd" }
  )

  Write-Host ""
  Write-Host "╭──────────────────────────────────────────────╮" -ForegroundColor DarkGray
  Write-Host "│ ⚡ Paulos Dev Shell loaded                    │" -ForegroundColor Cyan
  Write-Host "╰──────────────────────────────────────────────╯" -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "Useful commands" -ForegroundColor Cyan
  Write-Host "  paulos -h        Commands/tools/modules" -ForegroundColor DarkGray
  Write-Host "  paulos setup     Setup dashboard" -ForegroundColor DarkGray
  Write-Host "  paulos wizard    Guided configuration" -ForegroundColor DarkGray
  Write-Host "  scripts          List package.json scripts" -ForegroundColor DarkGray
  Write-Host "  lt               Project tree with icons" -ForegroundColor DarkGray
  Write-Host "  grep <text>      Search code fast" -ForegroundColor DarkGray
  Write-Host "  todo             Find TODO/FIXME/HACK/BUG" -ForegroundColor DarkGray
  Write-Host "  lg               Open lazygit" -ForegroundColor DarkGray
  Write-Host "  port 3000        Check who is using a port" -ForegroundColor DarkGray
  Write-Host "  killport 3000    Kill process using a port" -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "Tool status" -ForegroundColor Cyan
  foreach ($tool in $tools) {
    $status = if (Test-PaulosCommand $tool.Cmd) { "✓" } else { "×" }
    $color = if ($status -eq "✓") { "Green" } else { "DarkRed" }
    $line = "  {0} {1,-2} {2,-9} → {3}" -f $tool.Icon, $status, $tool.Name, $tool.Use
    Write-Host $line -ForegroundColor $color
  }
  Write-Host ""

  Invoke-PaulosUpdateCheck -Quiet | Out-Null

  $updateState = Get-PaulosUpdateState
  if (
    $null -ne $updateState -and
    $updateState.PSObject.Properties.Name -contains "UpdateAvailable" -and
    [bool]$updateState.UpdateAvailable
  ) {
    Write-Host "⬆ PaulosShell update available: $($updateState.LatestVersion)" -ForegroundColor Yellow
    Write-Host "  Current: $($updateState.CurrentVersion) · Run: paulos update self" -ForegroundColor DarkGray
    Write-Host ""
  }

  Show-PaulosTip
  Write-Host ""
}

function Initialize-PaulosShell {
  [CmdletBinding()]
  param(
    [switch]$NoBoot
  )

  $env:NI_DEFAULT_AGENT = "pnpm"
  $env:NI_GLOBAL_AGENT = "npm"

  if (Import-PaulosModuleIfAvailable PSReadLine) {
    Set-PSReadLineOption -EditMode Windows

    if ((Get-Command Set-PSReadLineOption).Parameters.ContainsKey("PredictionSource")) {
      Set-PSReadLineOption -PredictionSource History
    }

    if ((Get-Command Set-PSReadLineOption).Parameters.ContainsKey("PredictionViewStyle")) {
      Set-PSReadLineOption -PredictionViewStyle ListView
    }
  }

  if (Import-PaulosModuleIfAvailable CompletionPredictor) {
    try {
      Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    }
    catch {
      Set-PSReadLineOption -PredictionSource History
    }
  }

  Import-PaulosModuleIfAvailable Terminal-Icons | Out-Null

  if ((Test-PaulosCommand fzf) -and (Import-PaulosModuleIfAvailable PSFzf)) {
    Set-PsFzfOption `
      -PSReadlineChordProvider 'Ctrl+f' `
      -PSReadlineChordReverseHistory 'Ctrl+r'
  }

  Import-PaulosModuleIfAvailable posh-git | Out-Null

  if (Test-PaulosCommand zoxide) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
  }

  if (Test-PaulosCommand fnm) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
  }

  if (Test-PaulosCommand eza) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    Remove-Item Alias:ll -Force -ErrorAction SilentlyContinue
  }

  if (Test-PaulosCommand bat) {
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    Set-Alias -Name cat -Value bat -Scope Global
  }

  $localFile = Join-Path $script:PaulosStateDir "local.ps1"
  if (Test-Path $localFile) {
    . $localFile
  }

  $bootShownVar = Get-Variable -Name PaulosBootShown -Scope Script -ErrorAction SilentlyContinue
  $bootAlreadyShown = $null -ne $bootShownVar -and [bool]$bootShownVar.Value

  if (-not $NoBoot -and $env:PAULOS_NO_BOOT -ne "1" -and -not $bootAlreadyShown) {
    $script:PaulosBootShown = $true
    Show-PaulosBoot
  }
}
