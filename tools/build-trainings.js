#!/usr/bin/env node
/*
 * Build step for the trainings data. Two jobs:
 *   1) Re-inline data/trainings.json into the <script id="trainingsData"> block
 *      on index.html AND apply.html, and stamp each page with a freshness hash.
 *   2) Write one detail page per record into events/<id>.html.
 *
 * This is the canonical cross-platform build. It runs on Netlify (which has
 * Node) and anywhere Node is installed. tools/build-trainings.ps1 calls this
 * when Node is present and otherwise mirrors it in pure PowerShell — keep the
 * two in sync if you change the logic here.
 *
 *   Usage:  node tools/build-trainings.js
 */
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.join(__dirname, '..');
const jsonFp = path.join(root, 'data', 'trainings.json');
const offeringsFp = path.join(root, 'data', 'offerings.json');
const venuesFp = path.join(root, 'data', 'venues.json');
const pages = ['index.html', 'apply.html'];

const BLOCK = /(<script type="application\/json" id="trainingsData">)[\s\S]*?(<\/script>)/;
const HASH = /<!--\s*trainings-data-hash:[^>]*?-->/;

// The trainers directory (data/trainers.json) is inlined into our-trainers.html
// the same way: a JSON <script> block plus a freshness-hash comment.
const trainersFp = path.join(root, 'data', 'trainers.json');
const trainersPages = ['our-trainers.html', 'a-living-system.html'];
const TR_BLOCK = /(<script type="application\/json" id="trainersData">)[\s\S]*?(<\/script>)/;
const TR_HASH = /<!--\s*trainers-data-hash:[^>]*?-->/;

// Content hash, line-ending-normalized so Windows (CRLF) and Linux (LF) agree.
function contentHash(text) {
  const norm = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  return crypto.createHash('sha256').update(Buffer.from(norm, 'utf8')).digest('hex').slice(0, 16);
}

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// Map a record's category to an offering id, for the description fallback.
// Guide-training records intentionally have no fallback offering (per owner):
// their description stays blank until one is entered in the editor.
const CATEGORY_TO_OFFERING = {
  'Nature as Medicine': 'nature-as-medicine',
  'Opus Training': 'opus-academy'
};

function propositionFor(rec, offerings) {
  const oid = CATEGORY_TO_OFFERING[rec.category];
  if (!oid) return '';
  const off = (offerings || []).filter(function (o) { return o.id === oid; })[0];
  return (off && off.proposition) ? off.proposition : '';
}

// Which apply pathway (?path=) a record's category preselects on apply.html.
const CATEGORY_TO_PATH = {
  'Forest Therapy Guide Training': 'relational-forest-therapy-academy',
  'Opus Training': 'opus-academy',
  'Nature as Medicine': 'nature-as-medicine'
};
// Where the Register button points: a "book" offering -> its booking page; an
// enroll pathway -> apply.html carrying the pathway and event id; otherwise the
// record's own (external) registration link, opened in a new tab.
function registerLink(rec, offerings) {
  // Call/webinar listings register on Zoom (their own unique link), not via apply.
  if (rec.kind === 'call') {
    return { href: rec.zoomUrl || rec.registrationUrl || rec.url || '', ext: true };
  }
  const oid = CATEGORY_TO_OFFERING[rec.category];
  const off = oid ? (offerings || []).filter(function (o) { return o.id === oid; })[0] : null;
  if (off && off.verb === 'book') {
    return { href: '/' + String(off.slug).split('/').pop() + '.html', ext: false };
  }
  const path = CATEGORY_TO_PATH[rec.category];
  if (path && rec.id) {
    return { href: '/apply.html?path=' + path + '&event=' + encodeURIComponent(rec.id), ext: false };
  }
  return { href: rec.zoomUrl || rec.registrationUrl || rec.url || '', ext: true };
}

// images may be absolute (https://...) or repo-relative ("images/..."); the
// detail pages live in /events/, so relative paths are rooted to "/".
function assetUrl(u) {
  if (!u) return '';
  return /^https?:\/\//i.test(u) ? u : '/' + String(u).replace(/^\/+/, '');
}

function factRow(label, value) {
  if (value == null || String(value).trim() === '') return '';
  return '<li><b>' + esc(label) + '</b><br>' + esc(value) + '</li>';
}

const CSS = [
  ':root{--paper:#F2F3EC;--card:#FBFCF8;--ink:#26301F;--ink-soft:#4E5A47;--navy:#1E3A5F;--fir:#2E5B3E;--fir-tint:#E1EBDD;--gold:#A9862C;--gold-deep:#7C6118;--gold-tint:#F3EDD9;--bark:#6B4F3A;--bark-deep:#4E3324;--line:#C9D0BE;--radius:14px}',
  '*{box-sizing:border-box;margin:0;padding:0}',
  'body{background:var(--paper);color:var(--ink);font-family:"Nunito Sans",system-ui,sans-serif;font-size:16px;line-height:1.65;-webkit-font-smoothing:antialiased}',
  'p,.lede{font-family:"EB Garamond",Georgia,serif}',
  '.site-header{background:#fff;border-bottom:1px solid var(--line)}',
  '.hdr-in{max-width:1120px;margin:0 auto;padding:4px 28px;display:flex;align-items:center;justify-content:space-between;gap:20px;flex-wrap:wrap}',
  '.hdr-in img{width:200px;height:auto;display:block}',
  'nav{display:flex;gap:26px;flex-wrap:wrap;align-items:center}',
  'nav a{color:var(--navy);text-decoration:none;font-size:14.5px;font-weight:600;letter-spacing:.02em}',
  'nav a:hover{color:var(--gold-deep);text-decoration:underline;text-underline-offset:4px}',
  'nav a.nav-cta{background:var(--fir);color:#fff;border-radius:8px;padding:9px 18px;text-decoration:none;transition:background .18s ease}',
  'nav a.nav-cta:hover{background:#264b33;color:#fff;text-decoration:none}',
  '.banner{max-width:1120px;margin:0 auto}',
  '.banner img{display:block;width:100%;height:clamp(180px,26vw,320px);object-fit:cover;border-radius:0 0 var(--radius) var(--radius)}',
  '.section{max-width:880px;margin:0 auto;padding:48px 28px 72px}',
  '.eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:var(--gold-deep);font-weight:600;margin-bottom:10px}',
  'h1{font-family:"Nunito Sans",system-ui,sans-serif;font-weight:500;color:var(--navy);font-size:clamp(28px,4vw,40px);line-height:1.15}',
  '.lede{margin-top:14px;color:var(--ink-soft);font-size:17.5px;max-width:64ch}',
  'p{margin:0 0 14px;max-width:70ch}',
  '.facts{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:14px;margin:28px 0 6px;padding:0;list-style:none}',
  '.facts li{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px;font-size:14.5px}',
  '.facts b{color:var(--navy)}',
  '.cta-row{margin-top:30px;display:flex;gap:16px;flex-wrap:wrap;align-items:center}',
  '.btn{display:inline-block;font-size:14.5px;font-weight:600;border-radius:8px;padding:12px 26px;text-decoration:none;cursor:pointer;border:1.5px solid transparent;font-family:inherit;background:var(--fir);color:#fff;transition:background .18s ease,transform .18s ease}',
  '.btn:hover{background:#264b33;transform:translateY(-1px)}',
  '.p-link{font-size:14.5px;font-weight:600;color:var(--fir);text-decoration:underline;text-decoration-color:rgba(46,91,62,.35);text-underline-offset:3px;transition:text-decoration-color .2s ease}',
  '.p-link:hover{text-decoration-color:var(--fir)}',
  '.p-link.p-go::after{content:"\\00a0\\2192";display:inline-block;transition:transform .2s ease}',
  '.p-link.p-go:hover::after{transform:translateX(3px)}',
  'footer{margin-top:72px;background:var(--navy);color:#F4F7FB;border-top:3px solid var(--gold);padding:40px 28px 26px}',
  '.foot-in{max-width:1120px;margin:0 auto}',
  '.foot-brand{font-family:"Nunito Sans",system-ui,sans-serif;font-size:21px;line-height:1.3;color:#fff}',
  '.foot-tagline{font-family:"Nunito Sans",system-ui,sans-serif;font-size:14.5px;color:#E7D9A8;letter-spacing:.06em;margin-top:8px}',
  '.foot-nav{margin-top:18px;display:flex;gap:8px 22px;flex-wrap:wrap}',
  '.foot-nav a{color:#EDF2F8;text-decoration:none;font-size:14px}',
  '.foot-nav a:hover{text-decoration:underline;text-decoration-color:var(--gold);text-underline-offset:3px}',
  '.foot-legal{max-width:1120px;margin:28px auto 0;padding-top:16px;border-top:1px solid rgba(244,247,251,.16);font-size:12.5px;color:#B9C6D9}'
].join('\n  ');

const NAV = [
  '<a href="/academies.html">The Academies</a>',
  '<a href="/specializations.html">Specializations</a>',
  '<a href="/calendar.html">Find a Training</a>',
  '<a href="/the-book.html">The Book</a>',
  '<a href="/science.html">Science</a>',
  '<a href="/about.html">About</a>',
  '<a class="nav-cta" href="/apply.html">Introduce Yourself</a>'
].join('\n      ');

const HEADER =
  '<header class="site-header">\n' +
  '  <div class="hdr-in">\n' +
  '    <a href="/index.html" aria-label="Association of Nature and Forest Therapies &mdash; home"><img src="/images/brand/logo.webp" width="500" height="167" decoding="async" alt="Association of Nature and Forest Therapies"></a>\n' +
  '    <nav aria-label="Primary">\n      ' + NAV + '\n    </nav>\n' +
  '  </div>\n</header>\n';

const FOOTER =
  '<footer>\n' +
  '  <div class="foot-in">\n' +
  '    <div class="foot-brand">Academies of Nature<br>and Forest Therapies</div>\n' +
  '    <div class="foot-tagline">Knowledge &middot; Practice &middot; Transformation</div>\n' +
  '    <div class="foot-nav">\n' +
  '      <a href="/academies.html">The Academies</a>\n' +
  '      <a href="/about.html">About</a>\n' +
  '      <a href="/apply.html">Introduce Yourself</a>\n' +
  '      <a href="/calendar.html">Calendar</a>\n' +
  '      <a href="/index.html#trainings">Upcoming trainings</a>\n' +
  '      <a href="/faq.html">FAQ</a>\n' +
  '      <a href="/contact.html">Contact</a>\n' +
  '    </div>\n' +
  '  </div>\n' +
  '  <div class="foot-legal">&copy; 2026 ANFT.earth LLC, doing business as the Association of Nature and Forest Therapies. All rights reserved. All photos &copy; M. Amos Clifford except people profile photos and where otherwise noted.</div>\n' +
  '</footer>\n';

function buildEventPage(rec, offerings, venuesById, trainersById) {
  const title = rec.title || 'Event';
  const description = (rec.description && String(rec.description).trim())
    ? String(rec.description).trim()
    : propositionFor(rec, offerings);

  let dateStr = '';
  if (rec.date) dateStr = rec.date + (rec.time ? (' · ' + rec.time) : '');
  else dateStr = rec.startDate || rec.firstCall || rec.start || '';

  const trainerLinks = (Array.isArray(rec.trainers) ? rec.trainers : []).map(function (tid) {
    const t = (trainersById && trainersById[tid]) ? trainersById[tid] : null;
    const nm = t ? t.name : tid;
    return '<a href="/trainers/' + esc(tid) + '.html">' + esc(nm) + '</a>';
  }).join(', ');
  const reg = registerLink(rec, offerings);

  const v = (venuesById && rec.venue_id) ? venuesById[rec.venue_id] : null;
  const venueName = v ? (v.name + (v.region ? ', ' + v.region : '')) : '';
  const venueCountry = v ? (v.country || '') : '';
  const lodgingCost = (rec.lodgingCost != null && String(rec.lodgingCost).trim() !== '') ? ('$' + rec.lodgingCost) : '';
  const facts = [
    factRow('Academy', rec.academy),
    factRow('Subcategory', rec.subcategory),
    (v ? ('<li><b>Venue</b><br><a href="/venues/' + esc(rec.venue_id) + '.html">' + esc(venueName) + '</a></li>') : ''),
    factRow('Country', venueCountry),
    factRow('Dates', dateStr),
    factRow('Enrollment deadline', rec.enrollmentDeadline),
    factRow('Language', rec.language),
    (trainerLinks ? ('<li><b>Trainers</b><br>' + trainerLinks + '</li>') : ''),
    factRow('Tuition', rec.tuition),
    factRow('Lodging cost', lodgingCost)
  ].join('');

  const eyebrow = rec.category ? '  <div class="eyebrow">' + esc(rec.category) + '</div>\n' : '';
  const desc = description ? '  <p class="lede">' + esc(description) + '</p>\n' : '';
  const factsBlock = facts ? '  <ul class="facts">' + facts + '</ul>\n' : '';
  const banner = rec.image
    ? '<div class="banner"><img src="' + esc(assetUrl(rec.image)) + '" alt="' + esc(title) + '" loading="eager" decoding="async"></div>\n'
    : '';
  const registerBtn = reg.href
    ? '  <div class="cta-row"><a class="btn" href="' + esc(reg.href) + '"' + (reg.ext ? ' target="_blank" rel="noopener"' : '') + '>Register</a></div>\n'
    : '';

  const descMeta = description ? String(description).replace(/\s+/g, ' ').slice(0, 180) : ('Details for ' + title + '.');

  return '<!DOCTYPE html>\n<html lang="en">\n<head>\n' +
    '<meta charset="UTF-8">\n' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n' +
    '<meta name="robots" content="noindex, nofollow">\n' +
    '<title>' + esc(title) + ' | ANFT</title>\n' +
    '<meta name="description" content="' + esc(descMeta) + '">\n' +
    '<link rel="icon" type="image/x-icon" href="/favicon-white.ico?v=2">\n' +
    '<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png?v=2">\n' +
    '<link rel="apple-touch-icon" sizes="180x180" href="/favicon-180x180.png?v=2">\n' +
    '<link rel="preconnect" href="https://fonts.googleapis.com">\n' +
    '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n' +
    '<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;500;600;700&family=Nunito+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">\n' +
    '<style>\n  ' + CSS + '\n</style>\n</head>\n<body>\n' +
    HEADER +
    banner +
    '<main class="section">\n' +
    eyebrow +
    '  <h1>' + esc(title) + '</h1>\n' +
    desc +
    factsBlock +
    registerBtn +
    '  <div class="cta-row" style="margin-top:26px"><a class="p-link p-go" href="/calendar.html">See the full calendar</a></div>\n' +
    '</main>\n' +
    FOOTER +
    '</body>\n</html>\n';
}

function writeEventPages(data, offerings, venuesById, trainersById) {
  const records = (data.trainings || []).concat(data.events || []);
  const dir = path.join(root, 'events');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir);
  let n = 0;
  records.forEach(function (rec) {
    if (!rec.id) return;
    const fp = path.join(dir, rec.id + '.html');
    fs.writeFileSync(fp, buildEventPage(rec, offerings, venuesById, trainersById)); // utf8, no BOM
    n++;
  });
  console.log('Wrote ' + n + ' event detail page(s) into events/.');
}

// One profile page per trainer, built from data/trainers.json (mirrors the
// event-page approach). Reuses the shared CSS/HEADER/FOOTER plus a little
// trainer-specific layout CSS.
const TR_CSS = '.tr-hero{display:flex;gap:26px;align-items:center;flex-wrap:wrap;margin:6px 0 20px}.tr-photo{width:170px;height:170px;border-radius:16px;overflow:hidden;background:var(--fir-tint);position:relative;flex:none;display:flex;align-items:center;justify-content:center}.tr-photo img{width:100%;height:100%;object-fit:cover;position:absolute;inset:0}.tr-photo span{font-family:"Nunito Sans",system-ui,sans-serif;font-weight:700;font-size:46px;color:var(--fir)}.tr-hero h1{margin:0}.tr-bio{max-width:70ch}.tr-bio p{font-family:"EB Garamond",Georgia,serif;font-size:17px;color:var(--ink);margin:0 0 14px}.tr-back{display:inline-block;margin-bottom:4px}';

function trainerInitials(name) {
  const w = String(name || '').split(/\s+/).filter(function (x) { return x && !/^(dr|mr|mrs|ms|prof)\.?$/i.test(x); });
  return (((w[0] || ' ').charAt(0)) + ((w[1] || '').charAt(0))).toUpperCase();
}

function buildTrainerPage(p) {
  const name = p.name || 'Trainer';
  const roleRegion = [p.role, p.region].filter(function (x) { return x && String(x).trim(); }).join(' · ');
  const bioText = (p.bio_full && String(p.bio_full).trim()) ? p.bio_full : (p.bio_excerpt || '');
  const paras = bioText
    ? String(bioText).split(/\r?\n\s*\r?\n/).map(function (t) { return '  <p>' + esc(t.trim()) + '</p>'; }).join('\n')
    : '  <p></p>';
  const img = p.photo ? '<img src="' + esc(assetUrl(p.photo)) + '" alt="' + esc(name) + '" loading="eager" decoding="async" onerror="this.remove()">' : '';
  const eyebrow = roleRegion ? '    <div class="eyebrow">' + esc(roleRegion) + '</div>\n' : '';
  const descMeta = bioText ? String(bioText).replace(/\s+/g, ' ').slice(0, 180) : ('Profile for ' + name + '.');

  return '<!DOCTYPE html>\n<html lang="en">\n<head>\n' +
    '<meta charset="UTF-8">\n' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n' +
    '<meta name="robots" content="noindex, nofollow">\n' +
    '<title>' + esc(name) + ' | ANFT</title>\n' +
    '<meta name="description" content="' + esc(descMeta) + '">\n' +
    '<link rel="icon" type="image/x-icon" href="/favicon-white.ico?v=2">\n' +
    '<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png?v=2">\n' +
    '<link rel="apple-touch-icon" sizes="180x180" href="/favicon-180x180.png?v=2">\n' +
    '<link rel="preconnect" href="https://fonts.googleapis.com">\n' +
    '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n' +
    '<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;500;600;700&family=Nunito+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">\n' +
    '<style>\n  ' + CSS + '\n  ' + TR_CSS + '\n</style>\n</head>\n<body>\n' +
    HEADER +
    '<main class="section">\n' +
    '  <a class="p-link tr-back" href="/our-trainers.html">&larr; All trainers</a>\n' +
    '  <div class="tr-hero">\n' +
    '    <div class="tr-photo">' + img + '<span>' + esc(trainerInitials(name)) + '</span></div>\n' +
    '    <div>\n' +
    '      <h1>' + esc(name) + '</h1>\n' +
    eyebrow +
    '    </div>\n' +
    '  </div>\n' +
    '  <div class="tr-bio">\n' + paras + '\n  </div>\n' +
    '</main>\n' +
    FOOTER +
    '</body>\n</html>\n';
}

function writeTrainerPages(tdata) {
  const list = (tdata && tdata.trainers) || [];
  const dir = path.join(root, 'trainers');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir);
  let n = 0;
  list.forEach(function (p) {
    if (!p.id) return;
    fs.writeFileSync(path.join(dir, p.id + '.html'), buildTrainerPage(p)); // utf8, no BOM
    n++;
  });
  console.log('Wrote ' + n + ' trainer page(s) into trainers/.');
}

// One public page per venue, from data/venues.json. Never renders internalContact.
const VEN_CSS = 'h2{font-family:"Nunito Sans",system-ui,sans-serif;font-weight:600;color:var(--navy);font-size:20px;margin:28px 0 8px}.ven-list{margin:6px 0 8px;padding-left:20px}.ven-list li{margin:0 0 6px;font-family:"EB Garamond",Georgia,serif;font-size:16.5px}.ven-gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px;margin:10px 0 6px}.ven-gallery img{width:100%;height:150px;object-fit:cover;border-radius:10px;border:1px solid var(--line)}';

function buildVenuePage(v) {
  const name = v.name || 'Venue';
  const loc = [v.region, v.country].filter(function (x) { return x && String(x).trim(); }).join(', ');
  const imgs = (v.images || []).filter(function (x) { return x && String(x).trim(); });
  const banner = imgs.length ? '<div class="banner"><img src="' + esc(assetUrl(imgs[0])) + '" alt="' + esc(name) + '" loading="eager" decoding="async"></div>\n' : '';
  const gallery = imgs.length > 1 ? ('  <div class="ven-gallery">' + imgs.slice(1).map(function (im) { return '<img src="' + esc(assetUrl(im)) + '" alt="' + esc(name) + '" loading="lazy" decoding="async">'; }).join('') + '</div>\n') : '';
  function sec(title, body) { return (body && String(body).trim()) ? ('  <h2>' + esc(title) + '</h2>\n  <p>' + esc(body) + '</p>\n') : ''; }
  const acc = v.accessibility || {};
  const accParts = [];
  if (acc.terrain && String(acc.terrain).trim()) accParts.push('<b>Terrain.</b> ' + esc(acc.terrain));
  if (acc.mobilityAccess && String(acc.mobilityAccess).trim()) accParts.push('<b>Mobility access.</b> ' + esc(acc.mobilityAccess));
  if (acc.facilities && String(acc.facilities).trim()) accParts.push('<b>Facilities.</b> ' + esc(acc.facilities));
  const accSec = accParts.length ? ('  <h2>Accessibility</h2>\n  <p>' + accParts.join('<br>') + '</p>\n') : '';
  const lodg = (v.lodgingOptions || []).filter(function (o) { return o && (o.name || o.description); });
  const lodgSec = lodg.length ? ('  <h2>Lodging</h2>\n  <ul class="ven-list">' + lodg.map(function (o) { return '<li><b>' + esc(o.name || '') + '</b>' + (o.description ? (' &mdash; ' + esc(o.description)) : '') + '</li>'; }).join('') + '</ul>\n') : '';
  const siteRow = (v.website && String(v.website).trim()) ? ('<li><b>Website</b><br><a href="' + esc(v.website) + '" target="_blank" rel="noopener">' + esc(String(v.website).replace(/^https?:\/\//, '').replace(/\/$/, '')) + '</a></li>') : '';
  const facts = factRow('Elevation', v.elevation) + factRow('Operated by', v.operatedBy) + siteRow;
  const factsBlock = facts ? '  <ul class="facts">' + facts + '</ul>\n' : '';
  const eyebrow = loc ? '  <div class="eyebrow">' + esc(loc) + '</div>\n' : '';
  const desc = (v.description && String(v.description).trim()) ? '  <p class="lede">' + esc(v.description) + '</p>\n' : '';
  const descMeta = v.description ? String(v.description).replace(/\s+/g, ' ').slice(0, 180) : ('Venue: ' + name + '.');
  return '<!DOCTYPE html>\n<html lang="en">\n<head>\n' +
    '<meta charset="UTF-8">\n' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n' +
    '<meta name="robots" content="noindex, nofollow">\n' +
    '<title>' + esc(name) + ' | ANFT Venue</title>\n' +
    '<meta name="description" content="' + esc(descMeta) + '">\n' +
    '<link rel="icon" type="image/x-icon" href="/favicon-white.ico?v=2">\n' +
    '<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png?v=2">\n' +
    '<link rel="apple-touch-icon" sizes="180x180" href="/favicon-180x180.png?v=2">\n' +
    '<link rel="preconnect" href="https://fonts.googleapis.com">\n' +
    '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n' +
    '<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;500;600;700&family=Nunito+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">\n' +
    '<style>\n  ' + CSS + '\n  ' + VEN_CSS + '\n</style>\n</head>\n<body>\n' +
    HEADER +
    banner +
    '<main class="section">\n' +
    eyebrow +
    '  <h1>' + esc(name) + '</h1>\n' +
    desc +
    factsBlock +
    gallery +
    sec('Getting there', v.howToGetThere) +
    lodgSec +
    accSec +
    sec('Seasonal weather', v.seasonalWeather) +
    '  <div class="cta-row" style="margin-top:26px"><a class="p-link p-go" href="/index.html#trainings">See upcoming trainings</a></div>\n' +
    '</main>\n' +
    FOOTER +
    '</body>\n</html>\n';
}

function writeVenuePages(venues) {
  const list = venues || [];
  const dir = path.join(root, 'venues');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir);
  let n = 0;
  list.forEach(function (v) {
    if (!v.id) return;
    fs.writeFileSync(path.join(dir, v.id + '.html'), buildVenuePage(v)); // utf8, no BOM
    n++;
  });
  console.log('Wrote ' + n + ' venue page(s) into venues/.');
}

// Build the hero "upcoming events" chyron from live trainings + venues data.
// Shows open-enrollment events that have a real venue location, soonest first,
// dropping any whose date has passed. Emits the set twice for a seamless loop.
const CHY_BLOCK = /(<!--\s*chyron:start\s*-->)[\s\S]*?(<!--\s*chyron:end\s*-->)/;
function buildChyron(data, venuesById) {
  const M = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  function fmt(s) { var p = String(s).split('-'); if (p.length < 3) return s; return M[(+p[1]) - 1] + ' ' + (+p[2]) + ', ' + p[0]; }
  function rawDate(r) { return r.date || r.startDate || r.firstCall || r.start || r.enrollmentDeadline || ''; }
  function loc(r) { var v = venuesById[r.venue_id]; if (v) { var s = [v.region, v.country].filter(Boolean).join(', '); if (s) return s; } var t = r.title || ''; var i = t.search(/[—–]/); return i > -1 ? t.slice(0, i).trim() : t.trim(); }
  function nm(r) { var v = venuesById[r.venue_id]; if (v && v.name) return v.name; var t = r.title || ''; var parts = t.split(/[—–]/); return parts.length > 1 ? parts[parts.length - 1].trim() : t.trim(); }
  function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  var today = new Date().toISOString().slice(0, 10);
  var recs = (data.trainings || []).concat(data.events || []);
  var items = recs
    .filter(function (r) { return r.venue_id && /open/i.test(r.status || '') && (!rawDate(r) || rawDate(r) >= today); })
    .sort(function (a, b) { return rawDate(a) < rawDate(b) ? -1 : 1; });
  function itemHtml(r) {
    var dr = rawDate(r); var date = dr ? ('<span class="cy-date">' + fmt(dr) + '</span>') : '';
    return '<a class="cy-item" href="/events/' + r.id + '.html"><span class="cy-dot" aria-hidden="true"></span>' +
      '<span class="cy-name">' + esc(nm(r)) + '</span><span class="cy-loc">' + esc(loc(r)) + '</span>' + date + '</a>';
  }
  var set = items.map(itemHtml).join('\n      ');
  return { count: items.length, html: '\n      ' + set + '\n      ' + set + '\n      ' };
}

function main() {
  const json = fs.readFileSync(jsonFp, 'utf8');
  let data;
  try { data = JSON.parse(json); } catch (e) { throw new Error('data/trainings.json is not valid JSON: ' + e.message); }

  let offerings = [];
  try { offerings = (JSON.parse(fs.readFileSync(offeringsFp, 'utf8')).offerings) || []; }
  catch (e) { console.log('data/offerings.json unavailable (' + e.message + '); descriptions will fall back to blank.'); }

  const venuesById = {};
  let venuesArr = [];
  try { venuesArr = JSON.parse(fs.readFileSync(venuesFp, 'utf8')).venues || []; venuesArr.forEach(function (vv) { venuesById[vv.id] = vv; }); }
  catch (e) { console.log('venues.json unavailable (' + e.message + '); venue facts will be blank.'); }

  const hash = contentHash(json);
  const marker = '<!-- trainings-data-hash:' + hash + ' -->';

  pages.forEach(function (name) {
    const fp = path.join(root, name);
    let html = fs.readFileSync(fp, 'utf8');
    if (!BLOCK.test(html)) throw new Error('trainingsData <script> block not found in ' + name);
    if (!HASH.test(html)) throw new Error('trainings-data-hash marker not found in ' + name);
    const out = html
      .replace(BLOCK, function (m, open, close) { return open + json + close; })
      .replace(HASH, function () { return marker; });
    if (out === html) {
      console.log(name + ' already matches data/trainings.json (no change).');
    } else {
      fs.writeFileSync(fp, out); // utf8, no BOM
      console.log('Re-inlined data/trainings.json into ' + name + ' (hash ' + hash + ').');
    }
  });

  // Inline venues.json into index.html so the home-page cards can show venue/location.
  try {
    const venuesRaw = fs.readFileSync(venuesFp, 'utf8');
    const VEN_BLOCK = /(<script type="application\/json" id="venuesData">)[\s\S]*?(<\/script>)/;
    const idxFp = path.join(root, 'index.html');
    const idxHtml = fs.readFileSync(idxFp, 'utf8');
    if (VEN_BLOCK.test(idxHtml)) {
      const idxOut = idxHtml.replace(VEN_BLOCK, function (m, open, close) { return open + venuesRaw + close; });
      if (idxOut !== idxHtml) { fs.writeFileSync(idxFp, idxOut); console.log('Re-inlined data/venues.json into index.html.'); }
      else { console.log('index.html venues block already current.'); }
    }
  } catch (e) { console.log('venues inline skipped: ' + e.message); }

  // Regenerate the upcoming-events chyron in the hero from live data.
  try {
    const idxFp = path.join(root, 'index.html');
    const idxHtml = fs.readFileSync(idxFp, 'utf8');
    if (CHY_BLOCK.test(idxHtml)) {
      const chy = buildChyron(data, venuesById);
      const idxOut = idxHtml.replace(CHY_BLOCK, function (m, open, close) { return open + chy.html + close; });
      if (idxOut !== idxHtml) { fs.writeFileSync(idxFp, idxOut); console.log('Rebuilt hero chyron in index.html (' + chy.count + ' events).'); }
      else { console.log('index.html chyron already current (' + chy.count + ' events).'); }
    } else { console.log('chyron markers not found in index.html; skipped.'); }
  } catch (e) { console.log('chyron build skipped: ' + e.message); }

  const trainersById = {};
  try { (JSON.parse(fs.readFileSync(trainersFp, 'utf8')).trainers || []).forEach(function (t) { trainersById[t.id] = t; }); }
  catch (e) { console.log('trainers.json unavailable (' + e.message + '); trainer names will fall back to ids.'); }

  writeEventPages(data, offerings, venuesById, trainersById);

  // Inline the trainers directory into every page that embeds it (same mechanism).
  const tjson = fs.readFileSync(trainersFp, 'utf8');
  let tdata;
  try { tdata = JSON.parse(tjson); } catch (e) { throw new Error('data/trainers.json is not valid JSON: ' + e.message); }
  const thash = contentHash(tjson);
  const tmarker = '<!-- trainers-data-hash:' + thash + ' -->';
  trainersPages.forEach(function (name) {
    const tfp = path.join(root, name);
    const thtml = fs.readFileSync(tfp, 'utf8');
    if (!TR_BLOCK.test(thtml)) throw new Error('trainersData <script> block not found in ' + name);
    if (!TR_HASH.test(thtml)) throw new Error('trainers-data-hash marker not found in ' + name);
    const tout = thtml
      .replace(TR_BLOCK, function (m, open, close) { return open + tjson + close; })
      .replace(TR_HASH, function () { return tmarker; });
    if (tout === thtml) {
      console.log(name + ' already matches data/trainers.json (no change).');
    } else {
      fs.writeFileSync(tfp, tout); // utf8, no BOM
      console.log('Re-inlined data/trainers.json into ' + name + ' (hash ' + thash + ').');
    }
  });

  writeTrainerPages(tdata);

  writeVenuePages(venuesArr);
}

main();
