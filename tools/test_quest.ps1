param(
  [string]$Dramaless = "..\Dramaless-Quest",
  [string]$LoveExe = "..\third_party\Gen1Recomp-Content-Editor\love\love.exe"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dramalessPath = [IO.Path]::GetFullPath((Join-Path $root $Dramaless))
$lovePath = [IO.Path]::GetFullPath((Join-Path $root $LoveExe))
$python = (Get-Command python -ErrorAction Stop).Source

& $python (Join-Path $PSScriptRoot "test_dramaless_2_0.py") `
  --dramaless $dramalessPath
if ($LASTEXITCODE -ne 0) { throw "Static Dramaless 2.0 contract failed" }

$env:KANTO_TEST_DRAMALESS = $dramalessPath.Replace('\', '/')
foreach ($test in @("love_syntax", "love_patch_contract")) {
  $app = Join-Path $PSScriptRoot $test
  $result = Join-Path $app "result.txt"
  if (Test-Path -LiteralPath $result) {
    Remove-Item -LiteralPath $result -Force
  }
  $proc = Start-Process -FilePath $lovePath -ArgumentList $app -Wait `
    -WindowStyle Hidden -PassThru
  if ($proc.ExitCode -ne 0) {
    $detail = if (Test-Path -LiteralPath $result) {
      Get-Content -LiteralPath $result -Raw
    } else { "no test report" }
    throw "$test failed: $detail"
  }
  $detail = Get-Content -LiteralPath $result -Raw
  if ($detail -notmatch '^PASS:') { throw "$test did not report PASS: $detail" }
  Write-Host $detail.Trim()
}

& (Join-Path $PSScriptRoot "package_quest.ps1")
$archive = Join-Path $root "dist\KANTO_FIRST_PERSON-1.60.0-quest.6.zip"
$first = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
& (Join-Path $PSScriptRoot "package_quest.ps1")
$second = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
if ($first -ne $second) { throw "Quest archive builds are not deterministic" }

Write-Host "PASS: deterministic Quest package $first"

$env:KANTO_TEST_ARCHIVE = $archive
$mountApp = Join-Path $PSScriptRoot "love_archive_mount"
$mountResult = Join-Path $mountApp "result.txt"
if (Test-Path -LiteralPath $mountResult) {
  Remove-Item -LiteralPath $mountResult -Force
}
$mountProc = Start-Process -FilePath $lovePath -ArgumentList $mountApp -Wait `
  -WindowStyle Hidden -PassThru
$mountDetail = if (Test-Path -LiteralPath $mountResult) {
  Get-Content -LiteralPath $mountResult -Raw
} else { "no test report" }
if ($mountProc.ExitCode -ne 0 -or $mountDetail -notmatch '^PASS:') {
  throw "Quest archive mount failed: $mountDetail"
}
Write-Host $mountDetail.Trim()
