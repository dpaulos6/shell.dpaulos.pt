function Show-PaulosReposStatus {
  [CmdletBinding()]
  param(
    [string[]]$Roots,
    [switch]$All,
    [switch]$NoFetch,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
  )

  $effectiveRoots = @()
  if ($Roots) {
    $effectiveRoots += $Roots
  }

  foreach ($arg in @($RemainingArgs)) {
    if ([string]::IsNullOrWhiteSpace($arg)) {
      continue
    }

    switch -Regex ($arg) {
      '^(?i)(all)$' { $All = $true; continue }
      '^(?i)(nofetch)$' { $NoFetch = $true; continue }
      '^-.*$' { throw "Unknown repos option: $arg" }
      default { $effectiveRoots += $arg }
    }
  }

  if ($effectiveRoots.Count -eq 0) {
    $effectiveRoots = @("C:\coding", "C:\repos")
  }

  if (-not (Test-PaulosCommand git)) {
    Write-Warning "Git is not installed. Run 'paulos tools install' first."
    return
  }

  $repos = @(Get-PaulosGitRepositories -Roots $effectiveRoots)
  $statuses = foreach ($repo in $repos) {
    Get-PaulosRepositoryStatus -Path $repo.Path -NoFetch:$NoFetch
  }

  $total = $statuses.Count
  $attention = @($statuses | Where-Object { $_.State -ne "Clean" }).Count
  $displayRows = if ($All) { $statuses } else { @($statuses | Where-Object { $_.State -ne "Clean" }) }

  Write-Host ""
  Write-Host "Local Git repositories" -ForegroundColor Cyan
  Write-Host "Scanned $total repos · $attention need attention" -ForegroundColor DarkGray

  if ($displayRows.Count -eq 0) {
    Write-Host "All scanned repos look clean and up to date." -ForegroundColor Green
    Write-Host ""
    return
  }

  Show-PaulosTable -Title "Repository status" -Rows $displayRows -Columns @("State", "Repo", "Branch", "Ahead", "Behind", "Changed", "Untracked", "Path") -MaxWidths @{
    State = 14
    Repo = 28
    Branch = 24
    Path = 72
  }

  $errors = @($displayRows | Where-Object { $_.State -eq "Error" -and -not [string]::IsNullOrWhiteSpace($_.Message) })
  if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors" -ForegroundColor DarkYellow
    foreach ($errorRow in $errors) {
      Write-Host ("  {0} - {1}" -f $errorRow.Repo, $errorRow.Message) -ForegroundColor DarkYellow
    }
  }

  Write-Host ""
}

function Invoke-PaulosRepos {
  [CmdletBinding()]
  param(
    [string[]]$Roots,
    [switch]$All,
    [switch]$NoFetch,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
  )

  Show-PaulosReposStatus -Roots $Roots -All:$All -NoFetch:$NoFetch -RemainingArgs $RemainingArgs
}

function repos { Show-PaulosReposStatus @args }
function repo-status { Show-PaulosReposStatus @args }
