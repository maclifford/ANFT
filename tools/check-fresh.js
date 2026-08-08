#!/usr/bin/env node
/*
 * Staleness guard for the inlined trainings data.
 *
 * Compares the current content hash of data/trainings.json against the
 * freshness hash embedded in each generated page. Prints "FRESH" and exits 0
 * when every page is up to date; prints "STALE — run the build" and exits 1
 * when any page is out of date or unstamped.
 *
 * Include this in the pre-launch audit so stale pages can never ship:
 *   node tools/check-fresh.js
 *
 * PowerShell mirror: tools/check-fresh.ps1 (for machines without Node).
 */
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.join(__dirname, '..');
const jsonFp = path.join(root, 'data', 'trainings.json');
const pages = ['index.html', 'apply.html'];
const HASH = /<!--\s*trainings-data-hash:([^\s>]*)\s*-->/;
const trainersFp = path.join(root, 'data', 'trainers.json');
const trainersPages = ['our-trainers.html', 'a-living-system.html'];
const TR_HASH = /<!--\s*trainers-data-hash:([^\s>]*)\s*-->/;

function contentHash(text) {
  const norm = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  return crypto.createHash('sha256').update(Buffer.from(norm, 'utf8')).digest('hex').slice(0, 16);
}

function main() {
  const current = contentHash(fs.readFileSync(jsonFp, 'utf8'));
  const stale = [];
  pages.forEach(function (name) {
    const html = fs.readFileSync(path.join(root, name), 'utf8');
    const m = html.match(HASH);
    const embedded = m ? m[1] : '(none)';
    if (embedded !== current) stale.push(name + ' (embedded ' + embedded + ', expected ' + current + ')');
  });
  const trCurrent = contentHash(fs.readFileSync(trainersFp, 'utf8'));
  trainersPages.forEach(function (name) {
    const trHtml = fs.readFileSync(path.join(root, name), 'utf8');
    const trm = trHtml.match(TR_HASH);
    const trEmbedded = trm ? trm[1] : '(none)';
    if (trEmbedded !== trCurrent) stale.push(name + ' (embedded ' + trEmbedded + ', expected ' + trCurrent + ')');
  });
  if (stale.length === 0) {
    console.log('FRESH — index.html/apply.html match data/trainings.json (hash ' + current + '); ' + trainersPages.join(', ') + ' match data/trainers.json (hash ' + trCurrent + ').');
    process.exit(0);
  }
  console.log('STALE — run the build (update-trainings, or: node tools/build-trainings.js)');
  stale.forEach(function (s) { console.log('  - ' + s); });
  process.exit(1);
}

main();
