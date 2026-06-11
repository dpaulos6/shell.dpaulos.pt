# PaulosShell managed profile template
# Your installer will add this block to your real PowerShell profile.

# >>> PaulosShell managed block >>>
$paulosModulePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules\PaulosShell\PaulosShell.psd1"
if (Test-Path $paulosModulePath) {
  Import-Module $paulosModulePath -Force
  Initialize-PaulosShell
}
else {
  Write-Host "PaulosShell module not found at $paulosModulePath" -ForegroundColor DarkYellow
}
# <<< PaulosShell managed block <<<
