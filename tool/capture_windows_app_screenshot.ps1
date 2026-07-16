param(
  [string]$OutputDir = ".codex-run/windows-screenshots",
  [int]$Width = 1440,
  [int]$Height = 960,
  [string]$Name = "windows-1440-library"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class PageSageWin32 {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }

  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool BringWindowToTop(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

  [DllImport("user32.dll")]
  public static extern bool SetWindowPos(
    IntPtr hWnd,
    IntPtr hWndInsertAfter,
    int X,
    int Y,
    int cx,
    int cy,
    uint uFlags
  );

  [DllImport("user32.dll")]
  public static extern bool MoveWindow(
    IntPtr hWnd,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    bool bRepaint
  );

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
}
"@

function Get-PageSageWindow {
  $process = Get-Process |
    Where-Object {
      $_.ProcessName -match "pagesage|PageSage" -and
      $_.MainWindowHandle -ne 0
    } |
    Sort-Object StartTime -Descending |
    Select-Object -First 1

  if ($null -eq $process) {
    throw "No running PageSage window was found. Start the Windows app first."
  }
  return $process
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$process = Get-PageSageWindow
$handle = $process.MainWindowHandle

# SW_RESTORE = 9. Use a visible foreground window so the screenshot captures
# the actual rendered app instead of PrintWindow's blank Flutter surface.
[PageSageWin32]::ShowWindow($handle, 9) | Out-Null
[PageSageWin32]::MoveWindow($handle, 40, 40, $Width, $Height, $true) | Out-Null
Start-Sleep -Milliseconds 500
[PageSageWin32]::SetWindowPos($handle, [IntPtr](-1), 40, 40, $Width, $Height, 0x0040) | Out-Null
Start-Sleep -Milliseconds 300
[PageSageWin32]::BringWindowToTop($handle) | Out-Null
[PageSageWin32]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Milliseconds 1000
[PageSageWin32]::SetWindowPos($handle, [IntPtr](-2), 40, 40, $Width, $Height, 0x0040) | Out-Null
Start-Sleep -Milliseconds 300

$rect = New-Object PageSageWin32+RECT
[PageSageWin32]::GetWindowRect($handle, [ref]$rect) | Out-Null
$captureWidth = $rect.Right - $rect.Left
$captureHeight = $rect.Bottom - $rect.Top
if ($captureWidth -le 0 -or $captureHeight -le 0) {
  throw "PageSage window has an invalid capture rectangle."
}

$bitmap = New-Object System.Drawing.Bitmap $captureWidth, $captureHeight
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
  $graphics.CopyFromScreen(
    $rect.Left,
    $rect.Top,
    0,
    0,
    (New-Object System.Drawing.Size $captureWidth, $captureHeight)
  )
  $path = Join-Path $OutputDir "$Name.png"
  $bitmap.Save((Join-Path (Get-Location) $path), [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
  $graphics.Dispose()
  $bitmap.Dispose()
}

$metadata = [ordered]@{
  name = $Name
  path = (Join-Path $OutputDir "$Name.png")
  processId = $process.Id
  title = $process.MainWindowTitle
  requestedWidth = $Width
  requestedHeight = $Height
  left = $rect.Left
  top = $rect.Top
  width = $captureWidth
  height = $captureHeight
  capturedAt = (Get-Date).ToString("o")
}
$metadataPath = Join-Path $OutputDir "$Name.json"
$metadata | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding UTF8

Write-Output "captured $($metadata.path) (${captureWidth}x${captureHeight})"
