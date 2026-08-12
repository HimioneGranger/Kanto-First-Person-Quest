param(
  [string]$Output = "dist/KANTO_FIRST_PERSON-1.60.0-quest.1.zip"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outputPath = [IO.Path]::GetFullPath((Join-Path $root $Output))
$stage = Join-Path $root ".quest-package-stage"

if (Test-Path -LiteralPath $stage) {
  Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Path $stage | Out-Null

$runtime = Get-ChildItem -LiteralPath $root -File | Where-Object {
  $_.Name -notmatch '^\.' -and $_.Extension -notin @('.zip', '.modpkg', '.apk')
}
foreach ($file in $runtime) {
  Copy-Item -LiteralPath $file.FullName -Destination $stage -Force
}

$forbidden = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object {
  $_.Extension -match '^\.(gb|gbc|gba|sav|srm|apk)$' -or
  $_.FullName -match '[\\/](baseroms|generated|cache)[\\/]'
}
if ($forbidden) {
  throw "Forbidden user/game data entered package: $($forbidden.FullName -join ', ')"
}

$manifest = Get-Content -LiteralPath (Join-Path $stage 'manifest.json') -Raw |
  ConvertFrom-Json
if ($manifest.id -ne 'ds_fp_ceiling' -or
    $manifest.version -ne '1.60.0-quest.1') {
  throw 'Unexpected manifest identity/version'
}

New-Item -ItemType Directory -Path (Split-Path $outputPath) -Force | Out-Null
if (Test-Path -LiteralPath $outputPath) {
  Remove-Item -LiteralPath $outputPath -Force
}
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $outputPath
Remove-Item -LiteralPath $stage -Recurse -Force

$hash = Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
Write-Host "Quest package: $outputPath"
Write-Host "Size: $((Get-Item -LiteralPath $outputPath).Length) bytes"
Write-Host "SHA-256: $($hash.Hash)"
