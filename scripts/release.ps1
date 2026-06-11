[CmdletBinding()]
param(
  [ValidateSet("patch", "minor", "major")]
  [string]$Bump = "patch",

  [string]$Version,

  [switch]$Push,

  [switch]$CreateGitHubRelease,

  [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Confirm-OrExit {
  param([Parameter(Mandatory = $true)][string]$Message)

  if ($Yes) {
    return
  }

  $answer = Read-Host "$Message [y/N]"
  if ($answer -notmatch "^(y|Y)") {
    Write-Host "Cancelled." -ForegroundColor DarkYellow
    exit 1
  }
}

function Get-NextVersion {
  param(
    [Parameter(Mandatory = $true)][version]$Current,
    [Parameter(Mandatory = $true)][string]$BumpType
  )

  switch ($BumpType) {
    "major" { return [version]::new($Current.Major + 1, 0, 0) }
    "minor" { return [version]::new($Current.Major, $Current.Minor + 1, 0) }
    "patch" { return [version]::new($Current.Major, $Current.Minor, $Current.Build + 1) }
  }
}

$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

$manifestPath = Join-Path $repoRoot "src\PaulosShell\PaulosShell.psd1"

if (-not (Test-Path $manifestPath)) {
  throw "Manifest not found: $manifestPath"
}

$dirty = git status --porcelain
if ($dirty) {
  Write-Host "Working tree is not clean:" -ForegroundColor Red
  git status --short
  Write-Host ""
  throw "Commit or stash your feature changes before running the release script."
}

$manifest = Import-PowerShellDataFile $manifestPath
$currentVersion = [version]$manifest.ModuleVersion

$newVersion = if (-not [string]::IsNullOrWhiteSpace($Version)) {
  [version]($Version -replace "^v", "")
}
else {
  Get-NextVersion -Current $currentVersion -BumpType $Bump
}

$tag = "v$newVersion"

Write-Host ""
Write-Host "PaulosShell release" -ForegroundColor Cyan
Write-Host "  Current: $currentVersion" -ForegroundColor DarkGray
Write-Host "  New:     $newVersion" -ForegroundColor Green
Write-Host "  Tag:     $tag" -ForegroundColor DarkGray
Write-Host ""

$existingTag = git tag --list $tag
if ($existingTag) {
  throw "Tag already exists: $tag"
}

Confirm-OrExit "Create release $tag?"

$content = Get-Content $manifestPath -Raw
$pattern = "(?m)^(\s*ModuleVersion\s*=\s*')[^']*(')"

if ($content -notmatch $pattern) {
  throw "Could not find ModuleVersion in $manifestPath"
}

$updated = [regex]::Replace(
  $content,
  $pattern,
  {
    param($match)
    return $match.Groups[1].Value + $newVersion.ToString() + $match.Groups[2].Value
  },
  1
)

Set-Content -Path $manifestPath -Value $updated -Encoding UTF8

$verify = Import-PowerShellDataFile $manifestPath
if ([version]$verify.ModuleVersion -ne $newVersion) {
  throw "Manifest version verification failed."
}

Write-Host "✓ Manifest bumped to $newVersion" -ForegroundColor Green

git add $manifestPath
git commit -m "Release $tag"
git tag $tag

Write-Host "✓ Commit and tag created." -ForegroundColor Green

if ($Push) {
  git push
  git push origin $tag
  Write-Host "✓ Pushed commit and tag." -ForegroundColor Green
}
else {
  Write-Host ""
  Write-Host "Not pushed yet. To push:" -ForegroundColor DarkGray
  Write-Host "  git push"
  Write-Host "  git push origin $tag"
}

if ($CreateGitHubRelease) {
  if (-not $Push) {
    Write-Host ""
    Write-Host "Skipping GitHub release because -Push was not used." -ForegroundColor DarkYellow
    Write-Host "Run manually after pushing:" -ForegroundColor DarkGray
    Write-Host "  gh release create $tag --title `"$tag`" --notes `"Release $tag`""
  }
  else {
    gh release create $tag --title "$tag" --notes "Release $tag"
    Write-Host "✓ GitHub release created." -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
