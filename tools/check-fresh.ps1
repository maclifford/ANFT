# Staleness guard for the inlined trainings data (PowerShell mirror of
# tools/check-fresh.js, for machines without Node).
#
# Compares the current content hash of data/trainings.json against the hash
# embedded in each generated page. Prints "FRESH" and exits 0 when every page
# is up to date; prints "STALE - run the build" and exits 1 otherwise.
#
# Prefers the canonical Node checker when Node is installed.
#
#   Usage:  powershell -ExecutionPolicy Bypass -File tools/check-fresh.ps1
#
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$jsFp = Join-Path $PSScriptRoot 'check-fresh.js'

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  & $node.Source $jsFp
  exit $LASTEXITCODE
}

$jsonFp = Join-Path $root 'data\trainings.json'
$json   = [System.IO.File]::ReadAllText($jsonFp)
$norm   = ($json -replace "`r`n","`n") -replace "`r","`n"
$bytes  = [System.Text.Encoding]::UTF8.GetBytes($norm)
$sha    = [System.Security.Cryptography.SHA256]::Create()
$current = (-join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })).Substring(0,16)

$rxHash = [regex]'<!--\s*trainings-data-hash:([^\s>]*)\s*-->'
$stale  = @()
foreach ($name in @('index.html','apply.html')) {
  $html = [System.IO.File]::ReadAllText((Join-Path $root $name))
  $m = $rxHash.Match($html)
  $embedded = if ($m.Success) { $m.Groups[1].Value } else { '(none)' }
  if ($embedded -ne $current) { $stale += "$name (embedded $embedded, expected $current)" }
}

if ($stale.Count -eq 0) {
  Write-Host "FRESH - index.html and apply.html match data/trainings.json (hash $current)."
  exit 0
} else {
  Write-Host "STALE - run the build (update-trainings, or: powershell -File tools/build-trainings.ps1)"
  $stale | ForEach-Object { Write-Host "  - $_" }
  exit 1
}
