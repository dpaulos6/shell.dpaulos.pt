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

# ---------- Custom shell commands ----------
function lint { if ($args.Count -gt 0) { pnpx biome lint --write @args } else { pnpx biome lint --write . } }
function format { if ($args.Count -gt 0) { pnpx biome format --write @args } else { pnpx biome format --write . } }
function check { if ($args.Count -gt 0) { pnpx biome check --write @args } else { pnpx biome check --write . } }

function sex { pnpm @args }
function su { Invoke-WebRequest https://get.pnpm.io/install.ps1 -UseBasicParsing | Invoke-Expression }
function run { pnpm run @args }
function dev { pnpm run dev @args }
function debug { pnpm run debug @args }
function build { pnpm run build @args }
function test { pnpm test @args }
function e2e { pnpm test:e2e @args }
function i { pnpm install @args }
function add { pnpm add @args }
function un { pnpm remove @args }
function up { pnpm update @args }
function remove { pnpm remove @args }
function dlx { pnpm dlx @args }
function why { pnpm why @args }
function outdated { pnpm outdated @args }
function approve { pnpm approve-builds @args }

function ishadcn { pnpx shadcn@latest init @args }
function shadcn { pnpx shadcn@latest @args }
function magicui { pnpx magicui-cli @args }

function ll { eza -la --icons @args }
function ls { eza -la --icons @args }
function lt { eza --tree --level=2 --icons @args }

function npp {
  $notepadPlusPlus = "C:\Program Files\Notepad++\notepad++.exe"
  if (Test-Path $notepadPlusPlus) { & $notepadPlusPlus @args }
  else { Write-Warning "Notepad++ not found. Run Install-DevShellTools or install Notepad++ manually." }
}

function icogen {
  param(
    [Parameter(Mandatory = $true)][string]$InputFile,
    [string]$OutputFile = "favicon.ico"
  )

  if (-not (Test-PaulosCommand magick)) { Write-Warning "ImageMagick/magick not found. Run Install-DevShellTools."; return }
  if (-not (Test-Path $InputFile)) { Write-Warning "Input file not found: $InputFile"; return }

  magick $InputFile -define icon:auto-resize=256,128,64,48,32,16 $OutputFile
}

function grep { rg @args }
function todo { rg "TODO|FIXME|HACK|BUG" @args }
function ff { fd @args }

function gst { git status @args }
function gss { git status --short @args }
function gadd { git add @args }
function gcommit { git commit @args }
function gpush { git push @args }
function gpull { git pull @args }
function glog { git log --oneline --graph --decorate --all @args }
function gdiff { git diff @args }
function gbranch { git branch @args }
function gcheckout { git checkout @args }
function lg { lazygit @args }

function prs { gh pr list @args }
function prc { gh pr create @args }
function prv { gh pr view --web @args }

function dn { dotnet @args }
function dnb { dotnet build @args }
function dnr { dotnet run @args }
function dnt { dotnet test @args }
function dnw { dotnet watch @args }
function dnc { dotnet clean @args }
function ef { dotnet ef @args }
function efadd { param([Parameter(Mandatory = $true)][string]$Name) dotnet ef migrations add $Name @args }
function efup { dotnet ef database update @args }

function codehere { code . }
function reload { . $PROFILE }
function profile { if (Test-PaulosCommand npp) { npp $PROFILE } else { notepad $PROFILE } }
function whereis { param([Parameter(Mandatory = $true)][string]$Command) Get-Command $Command -All }

function scripts {
  if (-not (Test-Path package.json)) { Write-Warning "No package.json found in current directory."; return }
  $pkg = Get-Content package.json -Raw | ConvertFrom-Json
  if (-not $pkg.scripts) { Write-Warning "No scripts found in package.json."; return }
  $pkg.scripts.PSObject.Properties | Sort-Object Name | Format-Table Name, Value -AutoSize
}

function ports { netstat -ano | findstr LISTENING }
function port { param([Parameter(Mandatory = $true)][int]$Number) netstat -ano | findstr ":$Number" }
function killport {
  param([Parameter(Mandatory = $true)][int]$Number)
  $lines = netstat -ano | findstr ":$Number"
  if (-not $lines) { Write-Host "No process found on port $Number" -ForegroundColor DarkYellow; return }
  $pids = $lines | ForEach-Object { ($_ -split "\s+")[-1] } | Sort-Object -Unique
  foreach ($targetPid in $pids) {
    Write-Host "Killing PID $targetPid on port $Number" -ForegroundColor Cyan
    Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
  }
}

function mkcd { param([Parameter(Mandatory = $true)][string]$Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null; Set-Location $Path }
function touch {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date }
  else { New-Item -ItemType File -Path $Path | Out-Null }
}
function open { param([string]$Path = ".") Invoke-Item $Path }

# ---------- UI helpers ----------
function Format-PaulosCell {
  param([AllowNull()][object]$Value, [Parameter(Mandatory = $true)][int]$Width)

  $text = if ($null -eq $Value) { "" } else { [string]$Value }
  $text = $text -replace "`r|`n", " "

  if ($text.Length -gt $Width) {
    if ($Width -le 1) { return $text.Substring(0, $Width) }
    $text = $text.Substring(0, $Width - 1) + "…"
  }

  return $text + (" " * ($Width - $text.Length))
}

function Show-PaulosTable {
  param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][object[]]$Rows,
    [Parameter(Mandatory = $true)][string[]]$Columns,
    [hashtable]$MaxWidths = @{}
  )

  $rowsArray = @($Rows)
  Write-Host ""
  Write-Host $Title -ForegroundColor Cyan

  if ($rowsArray.Count -eq 0) { Write-Host "  No entries." -ForegroundColor DarkGray; return }

  $defaultMaxWidths = @{ Status = 8; Category = 14; Command = 34; Tool = 22; Cmd = 14; Module = 42; Item = 24; Detail = 80; Description = 72 }
  $widths = @{}

  foreach ($column in $Columns) {
    $max = $column.Length
    foreach ($row in $rowsArray) {
      $prop = $row.PSObject.Properties[$column]
      $value = if ($prop) { $prop.Value } else { "" }
      $text = if ($null -eq $value) { "" } else { [string]$value }
      $text = $text -replace "`r|`n", " "
      if ($text.Length -gt $max) { $max = $text.Length }
    }

    $cap = if ($MaxWidths.ContainsKey($column)) { $MaxWidths[$column] }
      elseif ($defaultMaxWidths.ContainsKey($column)) { $defaultMaxWidths[$column] }
      else { 30 }

    $widths[$column] = [Math]::Min([Math]::Max($max, 4), $cap)
  }

  $top = "┌" + (($Columns | ForEach-Object { "─" * ($widths[$_] + 2) }) -join "┬") + "┐"
  $sep = "├" + (($Columns | ForEach-Object { "─" * ($widths[$_] + 2) }) -join "┼") + "┤"
  $bottom = "└" + (($Columns | ForEach-Object { "─" * ($widths[$_] + 2) }) -join "┴") + "┘"

  Write-Host $top -ForegroundColor DarkGray
  $headerCells = foreach ($column in $Columns) { Format-PaulosCell $column $widths[$column] }
  Write-Host ("│ " + ($headerCells -join " │ ") + " │") -ForegroundColor DarkGray
  Write-Host $sep -ForegroundColor DarkGray

  foreach ($row in $rowsArray) {
    $cells = foreach ($column in $Columns) {
      $prop = $row.PSObject.Properties[$column]
      $value = if ($prop) { $prop.Value } else { "" }
      Format-PaulosCell $value $widths[$column]
    }
    Write-Host ("│ " + ($cells -join " │ ") + " │")
  }

  Write-Host $bottom -ForegroundColor DarkGray
}

function Get-PaulosToolRows {
  Get-PaulosData "tools" | ForEach-Object {
    $installed = Test-PaulosToolInstalled $_
    $essential = if ($_.PSObject.Properties.Name -contains "Essential") { [bool]$_.Essential } else { $false }

    [PSCustomObject]@{
      Status = if ($installed) { "✓" } elseif ($essential) { "missing" } else { "optional" }
      Category = $_.Category
      Tool = $_.Tool
      Cmd = $_.Command
      Description = $_.Description
    }
  }
}

function Get-PaulosModuleRows {
  Get-PaulosData "modules" | ForEach-Object {
    $installed = [bool](Get-Module -ListAvailable -Name $_.Module)
    $essential = if ($_.PSObject.Properties.Name -contains "Essential") { [bool]$_.Essential } else { $false }

    [PSCustomObject]@{
      Status = if ($installed) { "✓" } elseif ($essential) { "missing" } else { "optional" }
      Category = $_.Category
      Module = $_.Module
      Description = $_.Description
    }
  }
}

function Show-PaulosUsage {
  Write-Host ""
  Write-Host "Paulos Dev Shell" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:" -ForegroundColor DarkGray
  Write-Host "  paulos [command] [action]"
  Write-Host ""
  Write-Host "Commands:" -ForegroundColor DarkGray
  Write-Host "  -h, --help, help       Show help dashboard"
  Write-Host "  -v, --version, version Show PaulosShell version"
  Write-Host "  setup                  Setup dashboard"
  Write-Host "  wizard                 Interactive setup wizard"
  Write-Host "  doctor                 Full diagnostics"
  Write-Host "  commands              Custom commands only"
  Write-Host "  tools [install]        CLI tools status / install essentials"
  Write-Host "  modules               PowerShell modules status"
  Write-Host "  delta [fix|test|side|unified]"
  Write-Host "  font [download|open|list]"
  Write-Host "  starship [fix|config|open]"
  Write-Host "  github [login|setup-git|logout]"
  Write-Host "  update [check|status|self|yes|force|clear-cache|winget|modules|pnpm]"
  Write-Host "  pnpm [approve|store]"
  Write-Host "  backup / restore [latest]"
  Write-Host "  tip"
}

function Show-PaulosCommands { Show-PaulosTable -Title "Custom commands" -Rows (Get-PaulosData "commands" | Sort-Object Category, Command) -Columns @("Category", "Command", "Description") }
function Show-PaulosTools { Show-PaulosTable -Title "CLI tools / binaries" -Rows (Get-PaulosToolRows | Sort-Object Category, Tool) -Columns @("Status", "Category", "Tool", "Cmd", "Description") }
function Show-PaulosModules { Show-PaulosTable -Title "PowerShell modules / plugins" -Rows (Get-PaulosModuleRows | Sort-Object Category, Module) -Columns @("Status", "Category", "Module", "Description") }
function Show-PaulosVersion {
  $version = Get-PaulosCurrentVersion
  $manifestPath = Join-Path $script:PaulosModuleRoot "PaulosShell.psd1"

  Write-Host ""
  Write-Host "PaulosShell" -ForegroundColor Cyan
  Write-Host "  Version: $version" -ForegroundColor DarkGray
  Write-Host "  Module:  $script:PaulosModuleRoot" -ForegroundColor DarkGray
  Write-Host "  Manifest: $manifestPath" -ForegroundColor DarkGray
  Write-Host ""
}
function Show-PaulosTip {
  $tips = @(Get-PaulosData "tips")

  if ($tips.Length -gt 0) {
    Write-Host "💡 $(Get-Random -InputObject $tips)" -ForegroundColor DarkYellow
  }
}
function Show-PaulosHelp { Show-PaulosUsage; Show-PaulosCommands; Show-PaulosTools; Show-PaulosModules; Write-Host ""; Show-PaulosTip; Write-Host "" }
function Show-PaulosFull { Show-PaulosHelp }

# ---------- Setup/action commands ----------
function Show-PaulosActionTable { param([Parameter(Mandatory = $true)][object[]]$Rows) Show-PaulosTable -Title "Status" -Rows $Rows -Columns @("Status", "Item", "Detail") }

function Get-PaulosGitConfig { param([Parameter(Mandatory = $true)][string]$Key) if (-not (Test-PaulosCommand git)) { return $null }; return git config --global --get $Key 2>$null }

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

function Get-PaulosStarshipConfigPath { return Join-Path $HOME ".config\starship.toml" }
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
function Test-PaulosProfileContains { param([string]$Text) if (-not (Test-Path $PROFILE)) { return $false }; return (Get-Content $PROFILE -Raw).Contains($Text) }
function Get-PaulosDefaultStarshipConfig {
@'
# PaulosShell default Starship config
# Edit freely. This file is backed up before PaulosShell overwrites it.

add_newline = true
command_timeout = 1000

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
vimcmd_symbol = "[❮](bold green)"

[directory]
truncation_length = 3
truncate_to_repo = false
read_only = " 󰌾"

[git_branch]
symbol = " "

[git_status]
disabled = false

[nodejs]
symbol = " "

[package]
symbol = "󰏗 "

[dotnet]
symbol = " "

[cmd_duration]
min_time = 1000
format = "took [$duration]($style) "
'@
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

function shellcheck {
  $rows = foreach ($row in Get-PaulosToolRows) {
    $version = "missing"

    if ($row.Status -eq "✓") {
      try {
        $cmd = $row.Cmd
        $version = (& $cmd --version 2>$null | Select-Object -First 1)
        if (-not $version) { $version = "installed" }
      }
      catch {
        $version = "installed"
      }
    }

    [PSCustomObject]@{
      Tool = $row.Tool
      Cmd = $row.Cmd
      Status = $row.Status
      Version = $version
    }
  }

  $rows | Format-Table -AutoSize
}

function Get-PaulosCurrentVersion {
  $manifestPath = Get-PaulosInstalledModuleManifestPath

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
    Copy-Item -Path $releaseRoot.FullName -Destination $installedRoot -Recurse -Force -ErrorAction Stop
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
  Write-Host "Reload with:" -ForegroundColor DarkGray
  Write-Host "  Remove-Module PaulosShell -Force -ErrorAction SilentlyContinue" -ForegroundColor DarkGray
  Write-Host "  . `$PROFILE" -ForegroundColor DarkGray
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

function paulos {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
  )

  $tokens = @($RemainingArgs)

  $first = if ($tokens.Length -gt 0 -and -not [string]::IsNullOrWhiteSpace($tokens[0])) {
    $tokens[0]
  }
  else {
    "-h"
  }

  $action = if ($tokens.Length -gt 1 -and -not [string]::IsNullOrWhiteSpace($tokens[1])) {
    $tokens[1]
  }
  else {
    "status"
  }

  switch ($first) {
    "-h" { Show-PaulosHelp }
    "--help" { Show-PaulosHelp }
    "help" { Show-PaulosHelp }

    "-v" { Show-PaulosVersion }
    "--version" { Show-PaulosVersion }
    "version" { Show-PaulosVersion }

    "commands" { Show-PaulosCommands }
    "cmds" { Show-PaulosCommands }

    "tools" {
      if ($action -eq "install") {
        Install-PaulosDevShellTools
      }
      else {
        Show-PaulosTools
      }
    }

    "binaries" { Show-PaulosTools }

    "modules" { Show-PaulosModules }
    "plugins" { Show-PaulosModules }

    "full" { Show-PaulosFull }
    "tip" { Show-PaulosTip }

    "setup" { Invoke-PaulosSetup }
    "doctor" { Invoke-PaulosDoctor }
    "wizard" { Invoke-PaulosWizard }

    "delta" { Invoke-PaulosDelta $action }
    "font" { Invoke-PaulosFont $action }
    "starship" { Invoke-PaulosStarship $action }
    "github" { Invoke-PaulosGithub $action }
    "gh" { Invoke-PaulosGithub $action }
    "update" { Invoke-PaulosUpdate $action }
    "pnpm" { Invoke-PaulosPnpm $action }

    "backup" { Backup-PaulosProfile | Out-Null }
    "restore" { Restore-PaulosProfile $action }

    default {
      Write-Host "Unknown option: $first" -ForegroundColor Red
      Write-Host "Run 'paulos -h' for help." -ForegroundColor DarkGray
    }
  }
}
