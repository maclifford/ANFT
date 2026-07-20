# Re-inline data/trainings.json into the <script id="trainingsData"> block on
# BOTH index.html and apply.html, and stamp each page with a freshness hash of
# the JSON. Both pages read the inlined copy with NO runtime fetch, so they work
# even when opened directly from disk.
#
# Canonical build lives in tools/build-trainings.js (cross-platform Node, also
# used by Netlify). This wrapper CALLS that script when Node is installed; when
# Node is absent it runs an equivalent pure-PowerShell build so the command
# keeps working on machines without Node. Keep the two in sync.
#
#   Usage:  powershell -ExecutionPolicy Bypass -File tools/build-trainings.ps1
#
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$jsFp = Join-Path $PSScriptRoot 'build-trainings.js'

# Prefer the canonical Node build (single source of truth) when Node exists.
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  & $node.Source $jsFp
  exit $LASTEXITCODE
}

# --- No Node: equivalent pure-PowerShell build (mirror of build-trainings.js) ---
$jsonFp = Join-Path $root 'data\trainings.json'
$utf8   = New-Object System.Text.UTF8Encoding($false)
$json   = [System.IO.File]::ReadAllText($jsonFp)
try { [void]($json | ConvertFrom-Json) }
catch { throw "data/trainings.json is not valid JSON: $($_.Exception.Message)" }

# Content hash, line-ending-normalized so Windows (CRLF) and Linux (LF) agree.
$norm   = ($json -replace "`r`n","`n") -replace "`r","`n"
$bytes  = [System.Text.Encoding]::UTF8.GetBytes($norm)
$sha    = [System.Security.Cryptography.SHA256]::Create()
$hash   = (-join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })).Substring(0,16)
$marker = "<!-- trainings-data-hash:$hash -->"

$rxBlock = [regex]'(?s)(<script type="application/json" id="trainingsData">).*?(</script>)'
$rxHash  = [regex]'<!--\s*trainings-data-hash:[^>]*?-->'

foreach ($name in @('index.html','apply.html')) {
  $fp   = Join-Path $root $name
  $html = [System.IO.File]::ReadAllText($fp)
  if (-not $rxBlock.IsMatch($html)) { throw "trainingsData <script> block not found in $name" }
  if (-not $rxHash.IsMatch($html))  { throw "trainings-data-hash marker not found in $name" }
  $out = $rxBlock.Replace($html, { param($m) $m.Groups[1].Value + $json + $m.Groups[2].Value }, 1)
  $out = $rxHash.Replace($out,  { param($m) $marker }, 1)
  if ($out -eq $html) {
    Write-Host "$name already matches data/trainings.json (no change)."
  } else {
    [System.IO.File]::WriteAllText($fp, $out, $utf8)
    Write-Host "Re-inlined data/trainings.json into $name (hash $hash)."
  }
}
