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
  Write-Host "  repos [all|nofetch]   Local Git repository status scan"
  Write-Host "  repo-status           Alias for repos"
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
