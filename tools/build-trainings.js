#!/usr/bin/env node
/*
 * Re-inline data/trainings.json into the <script id="trainingsData"> block on
 * index.html AND apply.html, and stamp each page with a freshness hash of the
 * JSON. Both pages read the inlined copy with NO runtime fetch, so they work
 * even when opened directly from disk.
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
const pages = ['index.html', 'apply.html'];

const BLOCK = /(<script type="application\/json" id="trainingsData">)[\s\S]*?(<\/script>)/;
const HASH = /<!--\s*trainings-data-hash:[^>]*?-->/;

// Content hash, line-ending-normalized so Windows (CRLF) and Linux (LF) agree.
function contentHash(text) {
  const norm = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  return crypto.createHash('sha256').update(Buffer.from(norm, 'utf8')).digest('hex').slice(0, 16);
}

function main() {
  const json = fs.readFileSync(jsonFp, 'utf8');
  try { JSON.parse(json); } catch (e) { throw new Error('data/trainings.json is not valid JSON: ' + e.message); }
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
}

main();
