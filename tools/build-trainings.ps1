# Re-inline data/trainings.json into the <script id="trainingsData"> block on index.html.
# Run this whenever data/trainings.json changes so the homepage accordion stays in sync
# (the section renders from the inlined copy, with no runtime fetch).
#
#   Usage:  powershell -ExecutionPolicy Bypass -File tools/build-trainings.ps1
#
$ErrorActionPreference = 'Stop'
$root    = Split-Path -Parent $PSScriptRoot
$jsonFp  = Join-Path $root 'data\trainings.json'
$idxFp   = Join-Path $root 'index.html'
$utf8    = New-Object System.Text.UTF8Encoding($false)

$json = [System.IO.File]::ReadAllText($jsonFp)
try { [void]([System.Text.Json.JsonDocument]::Parse($json)) } catch { }   # best-effort validity check
$idx  = [System.IO.File]::ReadAllText($idxFp)

$rx = [regex]'(?s)(<script type="application/json" id="trainingsData">).*?(</script>)'
if (-not $rx.IsMatch($idx)) { throw "trainingsData <script> block not found in index.html" }

$out = $rx.Replace($idx, { param($m) $m.Groups[1].Value + $json + $m.Groups[2].Value }, 1)
if ($out -eq $idx) {
  Write-Host "index.html trainingsData already matches data/trainings.json (no change)."
} else {
  [System.IO.File]::WriteAllText($idxFp, $out, $utf8)
  Write-Host "Re-inlined data/trainings.json into index.html (trainingsData block)."
}
