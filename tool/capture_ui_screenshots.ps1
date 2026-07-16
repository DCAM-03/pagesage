param(
  [string]$OutputDir = ".codex-run/ui-screenshots",
  [int]$TimeoutSeconds = 90,
  [string[]]$Filters = @(
    "desktop-1440-library",
    "desktop-1024-search",
    "desktop-1024-notes",
    "desktop-768-settings",
    "desktop-768-tasks",
    "desktop-600-library-large-text",
    "mobile-360-library-large-text",
    "mobile-360-notes-large-text",
    "mobile-412-library-large-text",
    "theme-dark-library",
    "theme-high-contrast-search",
    "reader-epub-desktop",
    "reader-pdf-desktop",
    "mobile-360-reader-ai-large-text",
    "reader-theme-paper-epub",
    "reader-theme-green-epub",
    "reader-theme-ink-epub",
    "reader-theme-contrast-epub"
  )
)

$ErrorActionPreference = "Stop"

function Stop-RecentFlutterTestProcesses {
  $cutoff = (Get-Date).AddMinutes(-10)
  Get-Process |
    Where-Object {
      $_.StartTime -gt $cutoff -and
      $_.ProcessName -match "flutter_tester|dartvm|dartaotruntime|dart"
    } |
    Stop-Process -Force -ErrorAction SilentlyContinue
}

function Wait-ForScreenshot {
  param(
    [string]$Path,
    [int]$TimeoutSeconds
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $Path) {
      $item = Get-Item -LiteralPath $Path
      if ($item.Length -gt 0) {
        return $true
      }
    }
    Start-Sleep -Milliseconds 500
  }
  return $false
}

$samplesDir = ".codex-run/samples"
if (-not (Test-Path -LiteralPath (Join-Path $samplesDir "standard.epub")) -or
    -not (Test-Path -LiteralPath (Join-Path $samplesDir "standard-text.pdf"))) {
  dart run tool/generate_manual_samples.dart
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Stop-RecentFlutterTestProcesses

foreach ($filter in $Filters) {
  $target = Join-Path $OutputDir "$filter.png"
  Remove-Item -LiteralPath $target -ErrorAction SilentlyContinue

  $outLog = Join-Path ".codex-run" "ui-screenshot-$filter.out.log"
  $errLog = Join-Path ".codex-run" "ui-screenshot-$filter.err.log"
  Remove-Item -LiteralPath $outLog, $errLog -ErrorAction SilentlyContinue

  $arguments = @(
    "test",
    "test\ui_screenshots_test.dart",
    "--dart-define=UPDATE_PAGESAGE_SCREENSHOTS=true",
    "--dart-define=PAGESAGE_SCREENSHOT_FILTER=$filter"
  )
  $process = Start-Process -FilePath "flutter" `
    -ArgumentList $arguments `
    -WorkingDirectory (Get-Location) `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -WindowStyle Hidden `
    -PassThru

  $created = Wait-ForScreenshot -Path $target -TimeoutSeconds $TimeoutSeconds
  Stop-RecentFlutterTestProcesses

  if (-not $created) {
    throw "Screenshot capture timed out: $filter. Logs: $outLog / $errLog"
  }

  $size = (Get-Item -LiteralPath $target).Length
  Write-Output "captured $target ($size bytes)"
}

& (Join-Path $PSScriptRoot "build_ui_contact_sheet.ps1") `
  -InputDir $OutputDir `
  -OutputPath (Join-Path $OutputDir "contact-sheet.png")

Write-Output "UI screenshots written to $OutputDir"
