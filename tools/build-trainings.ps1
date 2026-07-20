# Re-inline data/trainings.json into the <script id="trainingsData"> block on
# BOTH index.html and apply.html. Run this whenever data/trainings.json changes
# so the homepage accordion and the apply page's selected-training card stay in
# sync. Both pages read the inlined copy with NO runtime fetch — this is what lets
# them work even when the files are opened directly from disk (where the browser
# blocks fetch of local files).
#
#   Usage:  powershell -ExecutionPolicy Bypass -File tools/build-trainings.ps1
#
$ErrorActionPreference = 'Stop'
$root    = Split-Path -Parent $PSScriptRoot
$jsonFp  = Join-Path $root 'data\trainings.json'
$utf8    = New-Object System.Text.UTF8Encoding($false)

$json = [System.IO.File]::ReadAllText($jsonFp)
try { [void]([System.Text.Json.JsonDocument]::Parse($json)) } catch { }   # best-effort validity check

$rx = [regex]'(?s)(<script type="application/json" id="trainingsData">).*?(</script>)'
foreach ($name in @('index.html','apply.html')) {
  $fp   = Join-Path $root $name
  $html = [System.IO.File]::ReadAllText($fp)
  if (-not $rx.IsMatch($html)) { throw "trainingsData <script> block not found in $name" }
  $out = $rx.Replace($html, { param($m) $m.Groups[1].Value + $json + $m.Groups[2].Value }, 1)
  if ($out -eq $html) {
    Write-Host "$name trainingsData already matches data/trainings.json (no change)."
  } else {
    [System.IO.File]::WriteAllText($fp, $out, $utf8)
    Write-Host "Re-inlined data/trainings.json into $name (trainingsData block)."
  }
}
