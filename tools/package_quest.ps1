param(
  [string]$Output = "dist/KANTO_FIRST_PERSON-1.60.0-quest.8.zip"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outputPath = [IO.Path]::GetFullPath((Join-Path $root $Output))
$stage = Join-Path $root ".quest-package-stage"

if (Test-Path -LiteralPath $stage) {
  Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Path $stage | Out-Null
$payload = Join-Path $stage "ds_fp_ceiling"
New-Item -ItemType Directory -Path $payload | Out-Null

$runtime = Get-ChildItem -LiteralPath $root -File | Where-Object {
  $_.Name -notmatch '^\.' -and $_.Extension -notin @('.zip', '.modpkg', '.apk')
}
foreach ($file in $runtime) {
  Copy-Item -LiteralPath $file.FullName -Destination $payload -Force
}

$forbidden = Get-ChildItem -LiteralPath $payload -Recurse -File | Where-Object {
  $_.Extension -match '^\.(gb|gbc|gba|sav|srm|apk)$' -or
  $_.FullName -match '[\\/](baseroms|generated|cache)[\\/]'
}
if ($forbidden) {
  throw "Forbidden user/game data entered package: $($forbidden.FullName -join ', ')"
}

$manifest = Get-Content -LiteralPath (Join-Path $payload 'manifest.json') -Raw |
  ConvertFrom-Json
if ($manifest.id -ne 'ds_fp_ceiling' -or
    $manifest.version -ne '1.60.0-quest.8') {
  throw 'Unexpected manifest identity/version'
}

New-Item -ItemType Directory -Path (Split-Path $outputPath) -Force | Out-Null
if (Test-Path -LiteralPath $outputPath) {
  Remove-Item -LiteralPath $outputPath -Force
}
$tar = (Get-Command tar.exe -ErrorAction Stop).Source
$fixedTime = [DateTime]::SpecifyKind([DateTime]'2000-01-01T00:00:00', 'Utc')
foreach ($entry in @(Get-Item -LiteralPath $payload) +
    @(Get-ChildItem -LiteralPath $payload -Recurse -Force)) {
  $entry.CreationTimeUtc = $fixedTime
  $entry.LastAccessTimeUtc = $fixedTime
  $entry.LastWriteTimeUtc = $fixedTime
}
Push-Location $stage
try {
  # bsdtar writes the Unix-origin ZIP headers used by the known-good upstream
  # archive. Both Windows/FAT-origin q2 and q3 packages were rejected by the
  # Quest Android PhysicsFS build even though desktop PhysicsFS accepted them.
  & $tar -a -cf $outputPath 'ds_fp_ceiling/*'
  if ($LASTEXITCODE -ne 0) { throw "bsdtar failed with exit code $LASTEXITCODE" }
} finally {
  Pop-Location
}
Remove-Item -LiteralPath $stage -Recurse -Force

$hash = Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
Write-Host "Quest package: $outputPath"
Write-Host "Size: $((Get-Item -LiteralPath $outputPath).Length) bytes"
Write-Host "SHA-256: $($hash.Hash)"
