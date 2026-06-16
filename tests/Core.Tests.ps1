. (Join-Path $PSScriptRoot '..\src\PaulosShell\Private\Core\Core.ps1')
. (Join-Path $PSScriptRoot '..\src\PaulosShell\Private\Profile\Profile.ps1')
$SourceManifestPath = (Resolve-Path (Join-Path $PSScriptRoot '..\src\PaulosShell\PaulosShell.psd1')).Path
$BundledStarshipConfigPath = (Resolve-Path (Join-Path $PSScriptRoot '..\config\starship.toml')).Path

Describe 'Set-PaulosManifestVersion' {
  foreach ($version in @('0.3.1', '1.0.0', '10.0.0')) {
    It "updates the manifest safely for version $version" {
      $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
      New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

      try {
        $moduleRoot = Join-Path $tempDir 'PaulosShell'
        Copy-Item -Path (Join-Path $PSScriptRoot '..\src\PaulosShell') -Destination $moduleRoot -Recurse -Force

        $manifestPath = Join-Path $moduleRoot 'PaulosShell.psd1'

        Set-PaulosManifestVersion -ManifestPath $manifestPath -Version $version

        $content = Get-Content -Path $manifestPath -Raw
        if ($content -notmatch "ModuleVersion\s*=\s*'$version'") {
          throw "Manifest version line was not updated to $version."
        }

        $validated = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        if ($validated.Version.ToString() -ne $version) {
          throw "Manifest version validated as $($validated.Version) instead of $version."
        }
      }
      finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }
}

Describe 'Get-PaulosStarshipConfigContent' {
  It 'returns the exact bundled starship.toml content' {
    $expected = Get-Content -Path $BundledStarshipConfigPath -Raw -Encoding UTF8
    $actual = Get-PaulosStarshipConfigContent

    if ($actual -ne $expected) {
      throw 'Bundled Starship config content does not match config/starship.toml.'
    }
  }
}
