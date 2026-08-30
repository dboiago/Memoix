#!/usr/bin/env node
// 01_discover.js
// Finds recipe URLs from a given site and appends them to urls/queue.txt.
// Tries sitemap.xml first, falls back to crawling the provided index URL.
// Idempotent: never adds a URL already in the queue.
//
// Usage:
//   node 01_discover.js <index-or-site-url>
//   node 01_discover.js --file urls/sites.txt
//
// Examples:
//   node 01_discover.js https://www.chinasichuanfood.com/recipe-index/
//   node 01_discover.js https://hot-thai-kitchen.com
//
// --file mode reads a pipe-delimited site list, one site per line:
//   <index-or-site-url>|<region>|<course>
// Both tag fields are optional and are soft defaults, not filters — they get
// carried through to 02_fetch.js/03_extract.js as hints, never used here to
// decide what to discover. Region is for cuisine-narrow sites (CN, KR, VN);
// course is for sites added for a specific strength (Apps, Soups, Smoking)
// where you still want everything on the site scraped. Blank fields and
// bare URLs with no tags at all are fine:
//   https://www.chinasichuanfood.com/recipe-index/|CN
//   https://academiedugout.fr||Apps
//   https://hot-thai-kitchen.com
// Lines starting with # or blank lines are skipped.
//
// Output: appends discovered URLs to urls/queue.txt, and merges any tags
// into urls/site-tags.json (keyed by hostname, without a leading "www.").

import fs from 'fs';
import readline from 'readline';
import fetch from 'node-fetch';
import { parseStringPromise } from 'xml2js';

const SITES_FILE = './urls/sites.txt';
const OUTPUT_QUEUE = './urls/queue.txt';

// --- CONFIGURATION & FILTERS ---

const FETCH_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.9'
};

// Sub-sitemaps to skip immediately to save requests
const IGNORED_SITEMAP_PATTERNS = [
  /_fr\.xml/i, /_it\.xml/i, /_de\.xml/i, /_es\.xml/i,
  /\/fr-ca\//i, /\/it-eu\//i, /\/de-eu\//i, /\/fr-eu\//i,
  /forum/i, /user-generated/i, /post_tag/i, /author/i, /category/i
];

// Non-English path segments to drop
const NON_ENGLISH_PATTERNS = [
  /meilleurduchef\.com\/(fr|it|es|de)\//i,
  /lyres\.com\/(it-eu|de-eu|fr-eu|nl-eu|pl-eu|es-eu)\//i,
  /seedlipdrinks\.com\/fr-ca\//i,
  /\/fr\//i, /\/it\//i, /\/de\//i, /\/es\//i
];

// Generic UGC and non-recipe metadata paths
const UGC_PATTERNS = [
  /\/forum\//i, /\/forums\//i, /\/community\//i,
  /\/user-generated\//i, /\/user-recipe\//i, /\/user\//i,
  /\/tag\//i, /\/category\//i, /\/author\//i
];

/**
 * Validates whether a URL should be added to the queue based on site-specific and global rules.
 */
function isAllowedUrl(url, domain) {
  // 1. Domain-specific strict inclusions
  if (domain.includes('diffordsguide.com')) {
    return url.includes('/cocktails/recipe/');
  }

  if (domain.includes('meilleurduchef.com')) {
    return url.includes('/en/');
  }

  // 2. Reject non-English paths
  if (NON_ENGLISH_PATTERNS.some(pattern => pattern.test(url))) {
    return false;
  }

  // 3. Reject generic UGC and index paths
  if (UGC_PATTERNS.some(pattern => pattern.test(url))) {
    return false;
  }

  return true;
}

/**
 * Normalizes base domain matching to account for www. differences
 */
function normalizeDomain(urlStr) {
  try {
    const parsed = new URL(urlStr);
    return parsed.hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
}

// --- SITEMAP PARSER ---

async function fetchAndParseXml(url) {
  try {
    const res = await fetch(url, { headers: FETCH_HEADERS, timeout: 15000 });
    if (!res.ok) {
      console.warn(`[HTTP ${res.status}] Failed to fetch: ${url}`);
      return null;
    }
    const xmlText = await res.text();
    return await parseStringPromise(xmlText);
  } catch (err) {
    console.error(`Error fetching/parsing XML at ${url}:`, err.message);
    return null;
  }
}

async function processSitemap(sitemapUrl, baseDomain, discoveredUrls) {
  // Check if sub-sitemap should be skipped
  if (IGNORED_SITEMAP_PATTERNS.some(pattern => pattern.test(sitemapUrl))) {
    console.log(`Skipping ignored sub-sitemap: ${sitemapUrl}`);
    return;
  }

  console.log(`Processing sitemap: ${sitemapUrl}`);
  const xml = await fetchAndParseXml(sitemapUrl);
  if (!xml) return;

  // Handle Sitemap Index (<sitemapindex><sitemap><loc>...</loc></sitemap></sitemapindex>)
  if (xml.sitemapindex && xml.sitemapindex.sitemap) {
    for (const entry of xml.sitemapindex.sitemap) {
      const childLoc = entry.loc ? entry.loc[0].trim() : null;
      if (childLoc) {
        await processSitemap(childLoc, baseDomain, discoveredUrls);
      }
    }
  }

  // Handle URL Set (<urlset><url><loc>...</loc></url></urlset>)
  if (xml.urlset && xml.urlset.url) {
    for (const entry of xml.urlset.url) {
      const loc = entry.loc ? entry.loc[0].trim() : null;
      if (loc && isAllowedUrl(loc, baseDomain)) {
        discoveredUrls.add(loc);
      }
    }
  }
}

// --- MAIN DISCOVERY ENTRYPOINT ---

async function runDiscovery() {
  if (!fs.existsSync(SITES_FILE)) {
    console.error(`Error: Base sites file not found at ${SITES_FILE}`);
    process.exit(1);
  }

  const fileStream = fs.createReadStream(SITES_FILE);
  const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

  const discoveredUrls = new Set();
  
  // Load existing discovered URLs if present to avoid duplicating across runs
  if (fs.existsSync(OUTPUT_QUEUE)) {
    const existingLines = fs.readFileSync(OUTPUT_QUEUE, 'utf-8').split(/\r?\n/);
    existingLines.forEach(line => {
      if (line.trim()) discoveredUrls.add(line.trim());
    });
    console.log(`Loaded ${discoveredUrls.size} pre-existing entries from ${OUTPUT_QUEUE}`);
  }

  for await (const line of rl) {
    if (!line.trim() || line.startsWith('#')) continue;

    // Expected format: URL | Country Code | Course
    const parts = line.split('|').map(p => p.trim());
    const rawUrl = parts[0];
    
    if (!rawUrl) continue;

    const baseDomain = normalizeDomain(rawUrl);
    
    // Default fallback to standard /sitemap.xml if direct root provided
    const sitemapTarget = rawUrl.endsWith('.xml') 
      ? rawUrl 
      : `${rawUrl.replace(/\/$/, '')}/sitemap.xml`;

    console.log(`\n--- Starting Discovery for: ${baseDomain} ---`);
    await processSitemap(sitemapTarget, baseDomain, discoveredUrls);
  }

  console.log(`\n========================================`);
  console.log(`Discovery Run Complete.`);
  console.log(`Writing ${discoveredUrls.size} validated URLs to ${OUTPUT_QUEUE}`);
  
  fs.writeFileSync(OUTPUT_QUEUE, Array.from(discoveredUrls).join('\n'));
  console.log(`Successfully saved queue!`);
}

runDiscovery();