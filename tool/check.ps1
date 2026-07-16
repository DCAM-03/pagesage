# PageSage local quality gate (M4)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

Write-Host '== dart format (check) =='
dart format --output=none --set-exit-if-changed .

Write-Host '== flutter analyze =='
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '== flutter test =='
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'OK: format + analyze + test passed'
