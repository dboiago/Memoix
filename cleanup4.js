#!/usr/bin/env node
// cleanup4.js
// Removes already-fetched Difford's Guide "community recipe" pages from
// raw/ and prunes their URLs from urls/queue.txt.
//
// Community and official recipes on diffordsguide.com share the exact same
// URL path (/cocktails/recipe/NNNN/slug), so no URL-pattern rule -- in
// 01_discover.js, cleanup.js, or anywhere else -- can ever tell them apart.
// The only reliable signal is in the page content itself: every community
// recipe carries the same template text, confirmed against a real batch.
// 02_fetch.js now checks for this at fetch time so it never saves a new one
// again; this script is the one-time retroactive pass for anything already
// sitting in raw/ from before that check existed.
//
// Usage:
//   node cleanup4.js [--raw-dir raw] [--queue-file urls/queue.txt]

import fs from 'fs';

const args        = process.argv.slice(2);
const rawDirIdx    = args.indexOf('--raw-dir');
const RAW_DIR      = rawDirIdx !== -1 ? args[rawDirIdx + 1] : 'raw';
const queueFileIdx = args.indexOf('--queue-file');
const QUEUE_FILE   = queueFileIdx !== -1 ? args[queueFileIdx + 1] : 'urls/queue.txt';

const COMMUNITY_RECIPE_MARKER = /Community recipes are not tested or verified by Difford/i;

if (!fs.existsSync(RAW_DIR)) {
  console.error(`Raw dir not found: ${RAW_DIR}`);
  process.exit(1);
}

const removedUrls = new Set();
let removedCount = 0;

for (const file of fs.readdirSync(RAW_DIR)) {
  if (!file.endsWith('.md')) continue;

  const mdPath = `${RAW_DIR}/${file}`;
  const content = fs.readFileSync(mdPath, 'utf8');
  if (!COMMUNITY_RECIPE_MARKER.test(content)) continue;

  const slug = file.slice(0, -3);
  const metaPath = `${RAW_DIR}/${slug}.meta.json`;

  if (fs.existsSync(metaPath)) {
    try {
      const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
      if (meta.url) removedUrls.add(meta.url);
    } catch { /* unreadable meta -- still remove the files below */ }
    fs.unlinkSync(metaPath);
  }
  fs.unlinkSync(mdPath);
  removedCount++;
  console.log(`Removed community recipe: ${slug}`);
}

if (removedUrls.size > 0 && fs.existsSync(QUEUE_FILE)) {
  const lines = fs.readFileSync(QUEUE_FILE, 'utf8').split(/\r?\n/);
  const filtered = lines.filter(line => !removedUrls.has(line.trim()));
  fs.writeFileSync(QUEUE_FILE, filtered.join('\n'));
  console.log(`Pruned ${lines.length - filtered.length} URL(s) from ${QUEUE_FILE}`);
}

console.log(`\nCleanup complete! Removed ${removedCount} community recipe(s) from ${RAW_DIR}.`);
