function Test-PaulosGitRepositoryPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  return (Test-Path -LiteralPath (Join-Path $Path ".git"))
}

function Invoke-PaulosGitCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  if (-not (Test-PaulosCommand git)) {
    return [PSCustomObject]@{
      Ok = $false
      Output = @()
      ExitCode = 127
      Error = "git is not installed."
    }
  }

  $output = & git -C $Path @Arguments 2>$null
  $exitCode = $LASTEXITCODE
  $lines = @($output)

  return [PSCustomObject]@{
    Ok = $exitCode -eq 0
    Output = $lines
    ExitCode = $exitCode
    Error = if ($exitCode -eq 0) { "" } else { "git $($Arguments -join ' ') failed with exit code $exitCode." }
  }
}

function Get-PaulosGitRepositories {
  [CmdletBinding()]
  param(
    [string[]]$Roots = @("C:\coding", "C:\repos")
  )

  $skipNames = @(
    ".git",
    "node_modules",
    "bin",
    "obj",
    ".next",
    "dist",
    "build",
    ".turbo",
    ".venv",
    "vendor",
    "coverage",
    ".cache",
    "target"
  )

  $skipLookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($skipName in $skipNames) {
    [void]$skipLookup.Add($skipName)
  }

  $repoPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $results = New-Object System.Collections.Generic.List[object]
  $queue = New-Object System.Collections.Generic.Queue[string]

  foreach ($root in @($Roots)) {
    if ([string]::IsNullOrWhiteSpace($root)) {
      continue
    }

    if (Test-Path -LiteralPath $root) {
      $queue.Enqueue((Resolve-Path -LiteralPath $root).Path)
    }
  }

  while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()

    if (-not (Test-Path -LiteralPath $current)) {
      continue
    }

    if (Test-PaulosGitRepositoryPath $current) {
      $normalized = (Resolve-Path -LiteralPath $current).Path
      if ($repoPaths.Add($normalized)) {
        $results.Add([PSCustomObject]@{
          Path = $normalized
          Repo = Split-Path $normalized -Leaf
        })
      }

      continue
    }

    foreach ($child in Get-ChildItem -LiteralPath $current -Directory -Force -ErrorAction SilentlyContinue) {
      if ($skipLookup.Contains($child.Name)) {
        continue
      }

      $queue.Enqueue($child.FullName)
    }
  }

  return $results
}

function Get-PaulosRepositoryStatus {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$NoFetch
  )

  $repoName = Split-Path $Path -Leaf
  $base = [ordered]@{
    Repo = $repoName
    Path = $Path
    Branch = ""
    Upstream = ""
    Ahead = 0
    Behind = 0
    Changed = 0
    Untracked = 0
    State = "Error"
    Message = ""
  }

  if (-not (Test-PaulosCommand git)) {
    $base.Message = "git is not installed."
    return [PSCustomObject]$base
  }

  if (-not $NoFetch) {
    $fetch = Invoke-PaulosGitCommand -Path $Path -Arguments @("fetch", "--prune", "--quiet")
    if (-not $fetch.Ok) {
      $base.Message = if ($fetch.Error) { $fetch.Error } else { "git fetch failed." }
      return [PSCustomObject]$base
    }
  }

  $branchResult = Invoke-PaulosGitCommand -Path $Path -Arguments @("branch", "--show-current")
  if (-not $branchResult.Ok) {
    $base.Message = if ($branchResult.Error) { $branchResult.Error } else { "Could not read current branch." }
    return [PSCustomObject]$base
  }

  $branch = ($branchResult.Output | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($branch)) {
    $branch = "DETACHED"
  }

  $base.Branch = $branch

  $statusResult = Invoke-PaulosGitCommand -Path $Path -Arguments @("status", "--porcelain=v1")
  if (-not $statusResult.Ok) {
    $base.Message = if ($statusResult.Error) { $statusResult.Error } else { "Could not read working tree status." }
    return [PSCustomObject]$base
  }

  $statusLines = @($statusResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $base.Changed = @($statusLines | Where-Object { -not $_.StartsWith("??") }).Count
  $base.Untracked = @($statusLines | Where-Object { $_.StartsWith("??") }).Count

  $upstreamResult = Invoke-PaulosGitCommand -Path $Path -Arguments @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
  $hasUpstream = $upstreamResult.Ok -and -not [string]::IsNullOrWhiteSpace(($upstreamResult.Output | Select-Object -First 1))

  if ($hasUpstream) {
    $base.Upstream = ($upstreamResult.Output | Select-Object -First 1)

    $countsResult = Invoke-PaulosGitCommand -Path $Path -Arguments @("rev-list", "--left-right", "--count", "HEAD...@{u}")
    if (-not $countsResult.Ok) {
      $base.Message = if ($countsResult.Error) { $countsResult.Error } else { "Could not compare HEAD to upstream." }
      return [PSCustomObject]$base
    }

    $countsLine = ($countsResult.Output | Select-Object -First 1)
    if ($countsLine -match "^(\d+)\s+(\d+)$") {
      $base.Ahead = [int]$Matches[1]
      $base.Behind = [int]$Matches[2]
    }
    else {
      $base.Message = "Could not parse ahead/behind counts."
      return [PSCustomObject]$base
    }
  }

  if ($base.Changed -gt 0 -or $base.Untracked -gt 0) {
    $base.State = "Dirty"
  }
  elseif (-not $hasUpstream) {
    $base.State = "No upstream"
  }
  elseif ($base.Ahead -gt 0 -and $base.Behind -gt 0) {
    $base.State = "Diverged"
  }
  elseif ($base.Behind -gt 0) {
    $base.State = "Pull"
  }
  elseif ($base.Ahead -gt 0) {
    $base.State = "Push"
  }
  else {
    $base.State = "Clean"
  }

  return [PSCustomObject]$base
}
