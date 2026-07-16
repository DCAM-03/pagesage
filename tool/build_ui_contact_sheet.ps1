param(
  [string]$InputDir = ".codex-run/ui-screenshots",
  [string]$OutputPath = ".codex-run/ui-screenshots/contact-sheet.png",
  [int]$Columns = 2,
  [int]$ThumbWidth = 520,
  [int]$LabelHeight = 34,
  [int]$Gap = 18,
  [int]$Margin = 24
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function Get-ImageFiles {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Input directory does not exist: $Path"
  }

  $files = Get-ChildItem -LiteralPath $Path -Filter "*.png" |
    Where-Object { $_.Name -ne "contact-sheet.png" } |
    Sort-Object Name

  if ($files.Count -eq 0) {
    throw "No PNG screenshots found in $Path"
  }

  return $files
}

function New-ThumbnailInfo {
  param(
    [System.IO.FileInfo]$File,
    [int]$ThumbWidth,
    [int]$LabelHeight
  )

  $image = [System.Drawing.Image]::FromFile($File.FullName)
  try {
    $scale = $ThumbWidth / [double]$image.Width
    $thumbHeight = [int][Math]::Round($image.Height * $scale)
    return [pscustomobject]@{
      File = $File
      Width = $ThumbWidth
      Height = $thumbHeight
      CellHeight = $thumbHeight + $LabelHeight
    }
  }
  finally {
    $image.Dispose()
  }
}

$files = Get-ImageFiles -Path $InputDir
$columns = [Math]::Max(1, $Columns)
$thumbs = @(
  foreach ($file in $files) {
    New-ThumbnailInfo -File $file -ThumbWidth $ThumbWidth -LabelHeight $LabelHeight
  }
)

$rows = [int][Math]::Ceiling($thumbs.Count / [double]$columns)
$rowHeights = New-Object int[] $rows
for ($i = 0; $i -lt $thumbs.Count; $i += 1) {
  $row = [int][Math]::Floor($i / $columns)
  $rowHeights[$row] = [Math]::Max($rowHeights[$row], $thumbs[$i].CellHeight)
}

$sheetWidth = $Margin * 2 + $columns * $ThumbWidth + ($columns - 1) * $Gap
$sheetHeight = $Margin * 2 + ($rows - 1) * $Gap
foreach ($height in $rowHeights) {
  $sheetHeight += $height
}

$bitmap = New-Object System.Drawing.Bitmap $sheetWidth, $sheetHeight
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$font = New-Object System.Drawing.Font "Segoe UI", 11, ([System.Drawing.FontStyle]::Regular)
$brushText = [System.Drawing.Brushes]::Black
$brushBackground = [System.Drawing.Brushes]::White
$penBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(210, 210, 210)), 1

try {
  $graphics.Clear([System.Drawing.Color]::White)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  $y = $Margin
  for ($row = 0; $row -lt $rows; $row += 1) {
    for ($column = 0; $column -lt $columns; $column += 1) {
      $index = $row * $columns + $column
      if ($index -ge $thumbs.Count) {
        continue
      }

      $thumb = $thumbs[$index]
      $x = $Margin + $column * ($ThumbWidth + $Gap)
      $labelRect = New-Object System.Drawing.RectangleF $x, $y, $ThumbWidth, $LabelHeight
      $graphics.FillRectangle($brushBackground, $labelRect)
      $graphics.DrawString($thumb.File.Name, $font, $brushText, $labelRect)

      $image = [System.Drawing.Image]::FromFile($thumb.File.FullName)
      try {
        $imageRect = New-Object System.Drawing.Rectangle $x, ($y + $LabelHeight), $thumb.Width, $thumb.Height
        $graphics.DrawImage($image, $imageRect)
        $graphics.DrawRectangle($penBorder, $imageRect)
      }
      finally {
        $image.Dispose()
      }
    }
    $y += $rowHeights[$row] + $Gap
  }

  $outputDir = Split-Path -Parent $OutputPath
  if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
  }
  $bitmap.Save((Join-Path (Get-Location) $OutputPath), [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Output "contact sheet written to $OutputPath ($($thumbs.Count) screenshots)"
}
finally {
  $graphics.Dispose()
  $bitmap.Dispose()
  $font.Dispose()
  $penBorder.Dispose()
}
