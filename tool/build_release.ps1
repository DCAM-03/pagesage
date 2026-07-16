# PageSage release build helpers (M4 draft)
param(
  [ValidateSet('windows', 'android', 'all')]
  [string]$Target = 'windows'
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Build-Windows {
  Write-Host '== flutter build windows --release =='
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host 'Output: build\windows\x64\runner\Release\'
}

function Build-Android {
  Write-Host '== flutter build apk --release =='
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host 'APK: build\app\outputs\flutter-apk\app-release.apk'
  Write-Host '== flutter build appbundle --release =='
  flutter build appbundle --release
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host 'AAB: build\app\outputs\bundle\release\app-release.aab'
}

switch ($Target) {
  'windows' { Build-Windows }
  'android' { Build-Android }
  'all' {
    Build-Windows
    Build-Android
  }
}

Write-Host 'OK: release build finished (configure signing for store upload)'
