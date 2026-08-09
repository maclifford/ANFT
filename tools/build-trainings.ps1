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
foreach ($tname in @('our-trainers.html','a-living-system.html')) {
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
}

# --- Inline venues.json into index.html (home-page cards show venue/location) ---
try {
  $venuesRaw = [System.IO.File]::ReadAllText((Join-Path $root 'data\venues.json'))
  $rxVenBlock = [regex]'(?s)(<script type="application/json" id="venuesData">).*?(</script>)'
  $idxFp = Join-Path $root 'index.html'
  $idxHtml = [System.IO.File]::ReadAllText($idxFp)
  if ($rxVenBlock.IsMatch($idxHtml)) {
    $idxOut = $rxVenBlock.Replace($idxHtml, { param($m) $m.Groups[1].Value + $venuesRaw + $m.Groups[2].Value }, 1)
    if ($idxOut -ne $idxHtml) { [System.IO.File]::WriteAllText($idxFp, $idxOut, $utf8); Write-Host "Re-inlined data/venues.json into index.html." }
    else { Write-Host "index.html venues block already current." }
  }
} catch { Write-Host "venues inline skipped: $($_.Exception.Message)" }

# --- Event detail pages (mirror of writeEventPages/buildEventPage in build-trainings.js) ---
$data = $json | ConvertFrom-Json
$offerings = @()
try { $offerings = (Get-Content (Join-Path $root 'data\offerings.json') -Raw | ConvertFrom-Json).offerings } catch { $offerings = @() }
$venuesById = @{}
$venuesArr = @()
try { $venuesArr = @((Get-Content (Join-Path $root 'data\venues.json') -Raw | ConvertFrom-Json).venues); $venuesArr | ForEach-Object { $venuesById[[string]$_.id] = $_ } } catch {}
$trainersById = @{}
try { @(([System.IO.File]::ReadAllText((Join-Path $root 'data\trainers.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json).trainers) | ForEach-Object { $trainersById[[string]$_.id] = $_ } } catch {}
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
  nav{display:flex;gap:26px;flex-wrap:wrap;align-items:center}
  nav a{color:var(--navy);text-decoration:none;font-size:14.5px;font-weight:600;letter-spacing:.02em}
  nav a:hover{color:var(--gold-deep);text-decoration:underline;text-underline-offset:4px}
  nav a.nav-cta{background:var(--fir);color:#fff;border-radius:8px;padding:9px 18px;text-decoration:none;transition:background .18s ease}
  nav a.nav-cta:hover{background:#264b33;color:#fff;text-decoration:none}
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
      <a href="/academies.html">The Academies</a>
      <a href="/calendar.html">Find a Training</a>
      <a href="/relational-forest-therapy-academy--global-guide-map.html">Find a Guide</a>
      <a href="/academy-of-place--global-trail-map.html">Find a Trail</a>
      <a href="/about.html">About</a>
      <a class="nav-cta" href="/apply.html">Apply</a>
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
      <a href="/about.html">About</a>
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
  $trainerLinks = ''
  if($rec.trainers -and @($rec.trainers).Count -gt 0){
    $parts = @()
    foreach($tid in @($rec.trainers)){
      $nm = if($trainersById.ContainsKey([string]$tid)){ [string]$trainersById[[string]$tid].name } else { [string]$tid }
      $parts += ('<a href="/trainers/'+(EvEsc ([string]$tid))+'.html">'+(EvEsc $nm)+'</a>')
    }
    $trainerLinks = ($parts -join ', ')
  }
  $trainerRow = if($trainerLinks){ '<li><b>Trainers</b><br>'+$trainerLinks+'</li>' } else { '' }
  $oid = if($CAT.ContainsKey([string]$rec.category)){$CAT[[string]$rec.category]}else{''}
  $off = if($oid){ $offerings | Where-Object { $_.id -eq $oid } | Select-Object -First 1 } else { $null }
  $regExt = $false
  if([string]$rec.kind -eq 'call'){ $regHref = if($rec.zoomUrl){[string]$rec.zoomUrl}elseif($rec.registrationUrl){[string]$rec.registrationUrl}elseif($rec.url){[string]$rec.url}else{''}; $regExt = $true }
  elseif($off -and $off.verb -eq 'book'){ $regHref = '/' + (([string]$off.slug -split '/')[-1]) + '.html' }
  elseif($CAT_PATH.ContainsKey([string]$rec.category) -and $rec.id){ $regHref = '/apply.html?path=' + $CAT_PATH[[string]$rec.category] + '&event=' + [uri]::EscapeDataString([string]$rec.id) }
  else { $regHref = if($rec.zoomUrl){[string]$rec.zoomUrl}elseif($rec.registrationUrl){[string]$rec.registrationUrl}elseif($rec.url){[string]$rec.url}else{''}; $regExt = $true }
  $vv = if($rec.venue_id -and $venuesById.ContainsKey([string]$rec.venue_id)){ $venuesById[[string]$rec.venue_id] } else { $null }
  $vname = if($vv){ [string]$vv.name + $(if($vv.region){', '+[string]$vv.region}else{''}) } else { '' }
  $vcountry = if($vv){ [string]$vv.country } else { '' }
  $lodgingCost = if($null -ne $rec.lodgingCost -and ([string]$rec.lodgingCost).Trim() -ne ''){ '$'+[string]$rec.lodgingCost } else { '' }
  $venueRow = if($vv){ '<li><b>Venue</b><br><a href="/venues/'+(EvEsc ([string]$rec.venue_id))+'.html">'+(EvEsc $vname)+'</a></li>' } else { '' }
  $facts = (EvFact 'Academy' $rec.academy)+(EvFact 'Subcategory' $rec.subcategory)+$venueRow+(EvFact 'Country' $vcountry)+(EvFact 'Dates' $dateStr)+(EvFact 'Enrollment deadline' $rec.enrollmentDeadline)+(EvFact 'Language' $rec.language)+$trainerRow+(EvFact 'Tuition' $rec.tuition)+(EvFact 'Lodging cost' $lodgingCost)
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

# --- Trainer profile pages (mirror of buildTrainerPage/writeTrainerPages in build-trainings.js) ---
$trCSS = '.tr-hero{display:flex;gap:26px;align-items:center;flex-wrap:wrap;margin:6px 0 20px}.tr-photo{width:170px;height:170px;border-radius:16px;overflow:hidden;background:var(--fir-tint);position:relative;flex:none;display:flex;align-items:center;justify-content:center}.tr-photo img{width:100%;height:100%;object-fit:cover;position:absolute;inset:0}.tr-photo span{font-family:"Nunito Sans",system-ui,sans-serif;font-weight:700;font-size:46px;color:var(--fir)}.tr-hero h1{margin:0}.tr-bio{max-width:70ch}.tr-bio p{font-family:"EB Garamond",Georgia,serif;font-size:17px;color:var(--ink);margin:0 0 14px}.tr-back{display:inline-block;margin-bottom:4px}'
function TrInitials($name){
  $w = @(($name -split '\s+') | Where-Object { $_ -and ($_ -notmatch '^(?i)(dr|mr|mrs|ms|prof)\.?$') })
  $i1 = if($w.Count -ge 1 -and $w[0].Length -ge 1){$w[0].Substring(0,1)}else{' '}
  $i2 = if($w.Count -ge 2 -and $w[1].Length -ge 1){$w[1].Substring(0,1)}else{''}
  return ($i1 + $i2).ToUpper()
}
function TrPage($p){
  $name = if([string]$p.name){[string]$p.name}else{'Trainer'}
  $rr = @(); if([string]$p.role){$rr += [string]$p.role}; if([string]$p.region){$rr += [string]$p.region}
  $roleRegion = ($rr -join (' ' + [char]0x00B7 + ' '))
  $bioText = if([string]$p.bio_full -and ([string]$p.bio_full).Trim() -ne ''){[string]$p.bio_full}elseif([string]$p.bio_excerpt){[string]$p.bio_excerpt}else{''}
  if($bioText -ne ''){
    $parts = [regex]::Split($bioText, '\r?\n\s*\r?\n') | Where-Object { $_.Trim() -ne '' }
    $paras = (($parts | ForEach-Object { '  <p>'+(EvEsc ($_.Trim()))+'</p>' }) -join "`n")
  } else { $paras = '  <p></p>' }
  $img = if([string]$p.photo){'<img src="'+(EvEsc (EvAsset $p.photo))+'" alt="'+(EvEsc $name)+'" loading="eager" decoding="async" onerror="this.remove()">'}else{''}
  $eyebrow = if($roleRegion){'    <div class="eyebrow">'+(EvEsc $roleRegion)+"</div>`n"}else{''}
  $descMeta = if($bioText){ $d=([string]$bioText -replace '\s+',' '); if($d.Length -gt 180){$d.Substring(0,180)}else{$d} }else{ 'Profile for '+$name+'.' }
  $q = @()
  $q += '<!DOCTYPE html>'; $q += '<html lang="en">'; $q += '<head>'
  $q += '<meta charset="UTF-8">'
  $q += '<meta name="viewport" content="width=device-width, initial-scale=1">'
  $q += '<meta name="robots" content="noindex, nofollow">'
  $q += '<title>'+(EvEsc $name)+' | ANFT</title>'
  $q += '<meta name="description" content="'+(EvEsc $descMeta)+'">'
  $q += '<link rel="icon" type="image/x-icon" href="/favicon-white.ico?v=2">'
  $q += '<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png?v=2">'
  $q += '<link rel="apple-touch-icon" sizes="180x180" href="/favicon-180x180.png?v=2">'
  $q += '<link rel="preconnect" href="https://fonts.googleapis.com">'
  $q += '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
  $q += '<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;500;600;700&family=Nunito+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">'
  $q += '<style>'; $q += $evCSS; $q += ('  '+$trCSS); $q += '</style>'; $q += '</head>'; $q += '<body>'
  $head = ($q -join "`n") + "`n"
  $mainInner = '  <a class="p-link tr-back" href="/our-trainers.html">&larr; All trainers</a>'+"`n" +
    '  <div class="tr-hero">'+"`n" +
    '    <div class="tr-photo">'+$img+'<span>'+(EvEsc (TrInitials $name))+'</span></div>'+"`n" +
    '    <div>'+"`n" +
    '      <h1>'+(EvEsc $name)+'</h1>'+"`n" +
    $eyebrow +
    '    </div>'+"`n" +
    '  </div>'+"`n" +
    '  <div class="tr-bio">'+"`n"+$paras+"`n  </div>"+"`n"
  return $head + $evHEADER + "<main class=`"section`">`n" + $mainInner + "</main>`n" + $evFOOTER + "</body>`n</html>`n"
}

$tdata = $tjson | ConvertFrom-Json
$trDir = Join-Path $root 'trainers'
if (-not (Test-Path $trDir)) { New-Item -ItemType Directory -Path $trDir | Out-Null }
$trN = 0
foreach ($p in @($tdata.trainers)) {
  if (-not $p.id) { continue }
  $pageHtml = (TrPage $p) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path $trDir ([string]$p.id + '.html')), $pageHtml, $utf8)
  $trN++
}
Write-Host "Wrote $trN trainer page(s) into trainers/."

# --- Public venue pages (mirror of buildVenuePage/writeVenuePages in build-trainings.js). Never renders internalContact. ---
$venCSS = 'h2{font-family:"Nunito Sans",system-ui,sans-serif;font-weight:600;color:var(--navy);font-size:20px;margin:28px 0 8px}.ven-list{margin:6px 0 8px;padding-left:20px}.ven-list li{margin:0 0 6px;font-family:"EB Garamond",Georgia,serif;font-size:16.5px}.ven-gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px;margin:10px 0 6px}.ven-gallery img{width:100%;height:150px;object-fit:cover;border-radius:10px;border:1px solid var(--line)}'
function VnPage($v){
  $name = if([string]$v.name){[string]$v.name}else{'Venue'}
  $loc = (@($v.region,$v.country) | Where-Object { [string]$_ -and ([string]$_).Trim() -ne '' }) -join ', '
  $imgs = @($v.images | Where-Object { [string]$_ -and ([string]$_).Trim() -ne '' })
  $banner = if($imgs.Count){ '<div class="banner"><img src="'+(EvEsc (EvAsset $imgs[0]))+'" alt="'+(EvEsc $name)+'" loading="eager" decoding="async"></div>'+"`n" } else { '' }
  $gallery = if($imgs.Count -gt 1){ '  <div class="ven-gallery">'+ (($imgs[1..($imgs.Count-1)] | ForEach-Object { '<img src="'+(EvEsc (EvAsset $_))+'" alt="'+(EvEsc $name)+'" loading="lazy" decoding="async">' }) -join '') +'</div>'+"`n" } else { '' }
  $acc = $v.accessibility
  $accParts = @()
  if($acc -and [string]$acc.terrain -and ([string]$acc.terrain).Trim() -ne ''){ $accParts += '<b>Terrain.</b> '+(EvEsc $acc.terrain) }
  if($acc -and [string]$acc.mobilityAccess -and ([string]$acc.mobilityAccess).Trim() -ne ''){ $accParts += '<b>Mobility access.</b> '+(EvEsc $acc.mobilityAccess) }
  if($acc -and [string]$acc.facilities -and ([string]$acc.facilities).Trim() -ne ''){ $accParts += '<b>Facilities.</b> '+(EvEsc $acc.facilities) }
  $accSec = if($accParts.Count){ '  <h2>Accessibility</h2>'+"`n"+'  <p>'+($accParts -join '<br>')+'</p>'+"`n" } else { '' }
  $lodg = @($v.lodgingOptions | Where-Object { $_ -and ([string]$_.name -or [string]$_.description) })
  $lodgSec = if($lodg.Count){ '  <h2>Lodging</h2>'+"`n"+'  <ul class="ven-list">'+ (($lodg | ForEach-Object { '<li><b>'+(EvEsc $_.name)+'</b>'+ $(if([string]$_.description){' &mdash; '+(EvEsc $_.description)}else{''}) +'</li>' }) -join '') +'</ul>'+"`n" } else { '' }
  $siteRow = if([string]$v.website -and ([string]$v.website).Trim() -ne ''){ $disp=(([string]$v.website) -replace '^https?://','') -replace '/$',''; '<li><b>Website</b><br><a href="'+(EvEsc $v.website)+'" target="_blank" rel="noopener">'+(EvEsc $disp)+'</a></li>' } else { '' }
  $facts = (EvFact 'Elevation' $v.elevation)+(EvFact 'Operated by' $v.operatedBy)+$siteRow
  $factsBlock = if($facts){ '  <ul class="facts">'+$facts+'</ul>'+"`n" } else { '' }
  $eyebrow = if($loc){ '  <div class="eyebrow">'+(EvEsc $loc)+'</div>'+"`n" } else { '' }
  $desc = if([string]$v.description -and ([string]$v.description).Trim() -ne ''){ '  <p class="lede">'+(EvEsc $v.description)+'</p>'+"`n" } else { '' }
  $gettingSec = if([string]$v.howToGetThere -and ([string]$v.howToGetThere).Trim() -ne ''){ '  <h2>Getting there</h2>'+"`n"+'  <p>'+(EvEsc $v.howToGetThere)+'</p>'+"`n" } else { '' }
  $weatherSec = if([string]$v.seasonalWeather -and ([string]$v.seasonalWeather).Trim() -ne ''){ '  <h2>Seasonal weather</h2>'+"`n"+'  <p>'+(EvEsc $v.seasonalWeather)+'</p>'+"`n" } else { '' }
  $descMeta = if([string]$v.description){ $d=([string]$v.description -replace '\s+',' '); if($d.Length -gt 180){$d.Substring(0,180)}else{$d} } else { 'Venue: '+$name+'.' }
  $q=@()
  $q += '<!DOCTYPE html>'; $q += '<html lang="en">'; $q += '<head>'
  $q += '<meta charset="UTF-8">'
  $q += '<meta name="viewport" content="width=device-width, initial-scale=1">'
  $q += '<meta name="robots" content="noindex, nofollow">'
  $q += '<title>'+(EvEsc $name)+' | ANFT Venue</title>'
  $q += '<meta name="description" content="'+(EvEsc $descMeta)+'">'
  $q += '<link rel="icon" type="image/x-icon" href="/favicon-white.ico?v=2">'
  $q += '<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png?v=2">'
  $q += '<link rel="apple-touch-icon" sizes="180x180" href="/favicon-180x180.png?v=2">'
  $q += '<link rel="preconnect" href="https://fonts.googleapis.com">'
  $q += '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
  $q += '<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;500;600;700&family=Nunito+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">'
  $q += '<style>'; $q += $evCSS; $q += ('  '+$venCSS); $q += '</style>'; $q += '</head>'; $q += '<body>'
  $head = ($q -join "`n") + "`n"
  $mainInner = $eyebrow + '  <h1>'+(EvEsc $name)+'</h1>'+"`n" + $desc + $factsBlock + $gallery + $gettingSec + $lodgSec + $accSec + $weatherSec + '  <div class="cta-row" style="margin-top:26px"><a class="p-link p-go" href="/index.html#trainings">See upcoming trainings</a></div>'+"`n"
  return $head + $evHEADER + $banner + "<main class=`"section`">`n" + $mainInner + "</main>`n" + $evFOOTER + "</body>`n</html>`n"
}

$venDir = Join-Path $root 'venues'
if (-not (Test-Path $venDir)) { New-Item -ItemType Directory -Path $venDir | Out-Null }
$vnN = 0
foreach ($v in $venuesArr) {
  if (-not $v.id) { continue }
  $pageHtml = (VnPage $v) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path $venDir ([string]$v.id + '.html')), $pageHtml, $utf8)
  $vnN++
}
Write-Host "Wrote $vnN venue page(s) into venues/."
