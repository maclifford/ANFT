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

# --- Trainers directory: inline data/trainers.json into our-trainers.html (same mechanism) ---
$tjson = [System.IO.File]::ReadAllText((Join-Path $root 'data\trainers.json'))
try { [void]($tjson | ConvertFrom-Json) } catch { throw "data/trainers.json is not valid JSON: $($_.Exception.Message)" }
$tnorm  = ($tjson -replace "`r`n","`n") -replace "`r","`n"
$thash  = (-join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($tnorm)) | ForEach-Object { $_.ToString('x2') })).Substring(0,16)
$tmarker = "<!-- trainers-data-hash:$thash -->"
$rxTrBlock = [regex]'(?s)(<script type="application/json" id="trainersData">).*?(</script>)'
$rxTrHash  = [regex]'<!--\s*trainers-data-hash:[^>]*?-->'
$tname = 'our-trainers.html'
$tfp   = Join-Path $root $tname
$thtml = [System.IO.File]::ReadAllText($tfp)
if (-not $rxTrBlock.IsMatch($thtml)) { throw "trainersData <script> block not found in $tname" }
if (-not $rxTrHash.IsMatch($thtml))  { throw "trainers-data-hash marker not found in $tname" }
$tout = $rxTrBlock.Replace($thtml, { param($m) $m.Groups[1].Value + $tjson + $m.Groups[2].Value }, 1)
$tout = $rxTrHash.Replace($tout,  { param($m) $tmarker }, 1)
if ($tout -eq $thtml) {
  Write-Host "$tname already matches data/trainers.json (no change)."
} else {
  [System.IO.File]::WriteAllText($tfp, $tout, $utf8)
  Write-Host "Re-inlined data/trainers.json into $tname (hash $thash)."
}

# --- Event detail pages (mirror of writeEventPages/buildEventPage in build-trainings.js) ---
$data = $json | ConvertFrom-Json
$offerings = @()
try { $offerings = (Get-Content (Join-Path $root 'offerings.json') -Raw | ConvertFrom-Json).offerings } catch { $offerings = @() }
$CAT = @{ 'Nature as Medicine' = 'nature-as-medicine'; 'Opus Training' = 'opus-academy' }
$CAT_PATH = @{ 'Forest Therapy Guide Training' = 'relational-forest-therapy-academy'; 'Opus Training' = 'opus-academy'; 'Nature as Medicine' = 'nature-as-medicine' }

function EvEsc($s){ if($null -eq $s){return ''}; return ([string]$s).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;') }
function EvAsset($u){ if([string]::IsNullOrEmpty([string]$u)){return ''}; if([string]$u -match '^(?i)https?://'){return [string]$u}; return '/' + ([string]$u -replace '^/+','') }
function EvFact($label,$value){ if($null -eq $value -or ([string]$value).Trim() -eq ''){return ''}; return '<li><b>'+(EvEsc $label)+'</b><br>'+(EvEsc $value)+'</li>' }
function EvProp($rec){ if(-not $CAT.ContainsKey([string]$rec.category)){return ''}; $oid=$CAT[[string]$rec.category]; $o=$offerings | Where-Object { $_.id -eq $oid } | Select-Object -First 1; if($o -and $o.proposition){return [string]$o.proposition}; return '' }

$evCSS = @'
  :root{--paper:#F2F3EC;--card:#FBFCF8;--ink:#26301F;--ink-soft:#4E5A47;--navy:#1E3A5F;--fir:#2E5B3E;--fir-tint:#E1EBDD;--gold:#A9862C;--gold-deep:#7C6118;--gold-tint:#F3EDD9;--bark:#6B4F3A;--bark-deep:#4E3324;--line:#C9D0BE;--radius:14px}
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:var(--paper);color:var(--ink);font-family:"Nunito Sans",system-ui,sans-serif;font-size:16px;line-height:1.65;-webkit-font-smoothing:antialiased}
  p,.lede{font-family:"EB Garamond",Georgia,serif}
  .site-header{background:#fff;border-bottom:1px solid var(--line)}
  .hdr-in{max-width:1120px;margin:0 auto;padding:4px 28px;display:flex;align-items:center;justify-content:space-between;gap:20px;flex-wrap:wrap}
  .hdr-in img{width:200px;height:auto;display:block}
  nav{display:flex;gap:26px;flex-wrap:wrap}
  nav a{color:var(--navy);text-decoration:none;font-size:14.5px;font-weight:600;letter-spacing:.02em}
  nav a:hover{color:var(--gold-deep);text-decoration:underline;text-underline-offset:4px}
  .banner{max-width:1120px;margin:0 auto}
  .banner img{display:block;width:100%;height:clamp(180px,26vw,320px);object-fit:cover;border-radius:0 0 var(--radius) var(--radius)}
  .section{max-width:880px;margin:0 auto;padding:48px 28px 72px}
  .eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:var(--gold-deep);font-weight:600;margin-bottom:10px}
  h1{font-family:"Nunito Sans",system-ui,sans-serif;font-weight:500;color:var(--navy);font-size:clamp(28px,4vw,40px);line-height:1.15}
  .lede{margin-top:14px;color:var(--ink-soft);font-size:17.5px;max-width:64ch}
  p{margin:0 0 14px;max-width:70ch}
  .facts{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:14px;margin:28px 0 6px;padding:0;list-style:none}
  .facts li{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px;font-size:14.5px}
  .facts b{color:var(--navy)}
  .cta-row{margin-top:30px;display:flex;gap:16px;flex-wrap:wrap;align-items:center}
  .btn{display:inline-block;font-size:14.5px;font-weight:600;border-radius:8px;padding:12px 26px;text-decoration:none;cursor:pointer;border:1.5px solid transparent;font-family:inherit;background:var(--fir);color:#fff;transition:background .18s ease,transform .18s ease}
  .btn:hover{background:#264b33;transform:translateY(-1px)}
  .p-link{font-size:14.5px;font-weight:600;color:var(--fir);text-decoration:underline;text-decoration-color:rgba(46,91,62,.35);text-underline-offset:3px;transition:text-decoration-color .2s ease}
  .p-link:hover{text-decoration-color:var(--fir)}
  .p-link.p-go::after{content:"\00a0\2192";display:inline-block;transition:transform .2s ease}
  .p-link.p-go:hover::after{transform:translateX(3px)}
  footer{margin-top:72px;background:var(--navy);color:#F4F7FB;border-top:3px solid var(--gold);padding:40px 28px 26px}
  .foot-in{max-width:1120px;margin:0 auto}
  .foot-brand{font-family:"Nunito Sans",system-ui,sans-serif;font-size:21px;line-height:1.3;color:#fff}
  .foot-tagline{font-family:"Nunito Sans",system-ui,sans-serif;font-size:14.5px;color:#E7D9A8;letter-spacing:.06em;margin-top:8px}
  .foot-nav{margin-top:18px;display:flex;gap:8px 22px;flex-wrap:wrap}
  .foot-nav a{color:#EDF2F8;text-decoration:none;font-size:14px}
  .foot-nav a:hover{text-decoration:underline;text-decoration-color:var(--gold);text-underline-offset:3px}
  .foot-legal{max-width:1120px;margin:28px auto 0;padding-top:16px;border-top:1px solid rgba(244,247,251,.16);font-size:12.5px;color:#B9C6D9}
'@ -replace "`r`n","`n"
$evCSS = $evCSS.TrimEnd("`n")

$evHEADER = @'
<header class="site-header">
  <div class="hdr-in">
    <a href="/index.html" aria-label="Association of Nature and Forest Therapies &mdash; home"><img src="/images/brand/logo.webp" width="500" height="167" decoding="async" alt="Association of Nature and Forest Therapies"></a>
    <nav aria-label="Primary">
      <a href="/forest-threshold.html">The Forest Threshold</a>
      <a href="/a-living-system.html">About &mdash; A Living System</a>
      <a href="/academies.html">The Academies</a>
      <a href="/the-book.html">The Book</a>
      <a href="/science.html">Science</a>
      <a href="/apply.html">Apply</a>
      <a href="/contact.html">Contact</a>
    </nav>
  </div>
</header>
'@ -replace "`r`n","`n"

$evFOOTER = @'
<footer>
  <div class="foot-in">
    <div class="foot-brand">Academies of Nature<br>and Forest Therapies</div>
    <div class="foot-tagline">Knowledge &middot; Practice &middot; Transformation</div>
    <div class="foot-nav">
      <a href="/academies.html">The Academies</a>
      <a href="/apply.html">Apply</a>
      <a href="/calendar.html">Calendar</a>
      <a href="/index.html#trainings">Upcoming trainings</a>
      <a href="/faq.html">FAQ</a>
      <a href="/contact.html">Contact</a>
    </div>
  </div>
  <div class="foot-legal">&copy; 2026 ANFT.earth LLC, doing business as the Association of Nature and Forest Therapies. All rights reserved.</div>
</footer>
'@ -replace "`r`n","`n"

function EvPage($rec){
  $title = if([string]$rec.title){[string]$rec.title}else{'Event'}
  $description = if($rec.description -and ([string]$rec.description).Trim() -ne ''){([string]$rec.description).Trim()}else{EvProp $rec}
  if($rec.date){ $dateStr = [string]$rec.date + $(if($rec.time){' '+[char]0x00B7+' '+[string]$rec.time}else{''}) }
  elseif($rec.startDate){ $dateStr=[string]$rec.startDate } elseif($rec.firstCall){ $dateStr=[string]$rec.firstCall } elseif($rec.start){ $dateStr=[string]$rec.start } else { $dateStr='' }
  $trainers = ''
  if($rec.trainers -and @($rec.trainers).Count -gt 0){ $trainers = (@($rec.trainers) -join ', ') }
  $oid = if($CAT.ContainsKey([string]$rec.category)){$CAT[[string]$rec.category]}else{''}
  $off = if($oid){ $offerings | Where-Object { $_.id -eq $oid } | Select-Object -First 1 } else { $null }
  $regExt = $false
  if([string]$rec.kind -eq 'call'){ $regHref = if($rec.zoomUrl){[string]$rec.zoomUrl}elseif($rec.registrationUrl){[string]$rec.registrationUrl}elseif($rec.url){[string]$rec.url}else{''}; $regExt = $true }
  elseif($off -and $off.verb -eq 'book'){ $regHref = '/' + (([string]$off.slug -split '/')[-1]) + '.html' }
  elseif($CAT_PATH.ContainsKey([string]$rec.category) -and $rec.id){ $regHref = '/apply.html?path=' + $CAT_PATH[[string]$rec.category] + '&event=' + [uri]::EscapeDataString([string]$rec.id) }
  else { $regHref = if($rec.zoomUrl){[string]$rec.zoomUrl}elseif($rec.registrationUrl){[string]$rec.registrationUrl}elseif($rec.url){[string]$rec.url}else{''}; $regExt = $true }
  $facts = (EvFact 'Academy' $rec.academy)+(EvFact 'Subcategory' $rec.subcategory)+(EvFact 'Venue' $rec.venue)+(EvFact 'Country' $rec.country)+(EvFact 'Dates' $dateStr)+(EvFact 'Enrollment deadline' $rec.enrollmentDeadline)+(EvFact 'Language' $rec.language)+(EvFact 'Trainers' $trainers)+(EvFact 'Tuition' $rec.tuition)+(EvFact 'Lodging' $rec.lodging)
  $eyebrow = if([string]$rec.category){'  <div class="eyebrow">'+(EvEsc $rec.category)+"</div>`n"}else{''}
  $desc = if($description){'  <p class="lede">'+(EvEsc $description)+"</p>`n"}else{''}
  $factsBlock = if($facts){'  <ul class="facts">'+$facts+"</ul>`n"}else{''}
  $banner = if($rec.image){'<div class="banner"><img src="'+(EvEsc (EvAsset $rec.image))+'" alt="'+(EvEsc $title)+'" loading="eager" decoding="async"></div>'+"`n"}else{''}
  $registerBtn = if($regHref){'  <div class="cta-row"><a class="btn" href="'+(EvEsc $regHref)+'"'+$(if($regExt){' target="_blank" rel="noopener"'}else{''})+'>Register</a></div>'+"`n"}else{''}
  $descMeta = if($description){ $d=([string]$description -replace '\s+',' '); if($d.Length -gt 180){$d.Substring(0,180)}else{$d} }else{ 'Details for '+$title+'.' }
  $p = @()
  $p += '<!DOCTYPE html>'; $p += '<html lang="en">'; $p += '<head>'
  $p += '<meta charset="UTF-8">'
  $p += '<meta name="viewport" content="width=device-width, initial-scale=1">'
  $p += '<meta name="robots" content="noindex, nofollow">'
  $p += '<title>'+(EvEsc $title)+' | ANFT</title>'
  $p += '<meta name="description" content="'+(EvEsc $descMeta)+'">'
  $p += '<link rel="icon" type="image/x-icon" href="/favicon-white.ico?v=2">'
  $p += '<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png?v=2">'
  $p += '<link rel="apple-touch-icon" sizes="180x180" href="/favicon-180x180.png?v=2">'
  $p += '<link rel="preconnect" href="https://fonts.googleapis.com">'
  $p += '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
  $p += '<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;500;600;700&family=Nunito+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">'
  $p += '<style>'
  $p += $evCSS
  $p += '</style>'; $p += '</head>'; $p += '<body>'
  $head = ($p -join "`n") + "`n"
  $mainInner = $eyebrow + '  <h1>'+(EvEsc $title)+"</h1>`n" + $desc + $factsBlock + $registerBtn + '  <div class="cta-row" style="margin-top:26px"><a class="p-link p-go" href="/calendar.html">See the full calendar</a></div>' + "`n"
  return $head + $evHEADER + $banner + "<main class=`"section`">`n" + $mainInner + "</main>`n" + $evFOOTER + "</body>`n</html>`n"
}

$evDir = Join-Path $root 'events'
if (-not (Test-Path $evDir)) { New-Item -ItemType Directory -Path $evDir | Out-Null }
$records = @(); if($data.trainings){$records += $data.trainings}; if($data.events){$records += $data.events}
$evN = 0
foreach ($rec in $records) {
  if (-not $rec.id) { continue }
  $pageHtml = (EvPage $rec) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path $evDir ([string]$rec.id + '.html')), $pageHtml, $utf8)
  $evN++
}
Write-Host "Wrote $evN event detail page(s) into events/."
