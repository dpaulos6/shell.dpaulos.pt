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

function paulos {
  [CmdletBinding()]
  param(
    [Alias("h", "?")]
    [switch]$Help,

    [Alias("v")]
    [switch]$Version,

    [Parameter(ValueFromRemainingArguments = $true, Position = 0)]
    [string[]]$RemainingArgs
  )

  if ($Version) {
    Show-PaulosVersion
    return
  }

  if ($Help) {
    Show-PaulosHelp
    return
  }

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
    "v" { Show-PaulosVersion }

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

    "repos" { Invoke-PaulosRepos -RemainingArgs (@($tokens | Select-Object -Skip 1)) }
    "repo-status" { Invoke-PaulosRepos -RemainingArgs (@($tokens | Select-Object -Skip 1)) }

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
