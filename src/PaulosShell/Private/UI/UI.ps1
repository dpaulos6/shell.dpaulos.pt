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

function Show-PaulosActionTable {
  param([Parameter(Mandatory = $true)][object[]]$Rows)

  Show-PaulosTable -Title "Status" -Rows $Rows -Columns @("Status", "Item", "Detail")
}
