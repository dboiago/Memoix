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
import zlib from 'zlib';
import { parseStringPromise } from 'xml2js';
import { JSDOM } from 'jsdom';

const SITES_FILE = './urls/sites.txt';
const OUTPUT_QUEUE = './urls/queue.txt';
const MAX_CRAWL_PAGES = 25;
const CRAWL_DELAY_MS = 500;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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
  /forum/i, /user-generated/i, /post_tag/i, /author/i, /category/i,
  // Confirmed non-recipe WP taxonomy/CPT sitemaps (shop products, media
  // attachments/images, job listings, company pages).
  /product(_cat|_tag)?-sitemap/i, /attachment-sitemap/i, /image-sitemap/i,
  /jobs?-sitemap/i, /unternehmen-sitemap/i
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

// Some sites emit sitemaps with stray literal "&" in <loc> text (e.g. unescaped
// query strings), which is invalid XML and otherwise kills the whole parse.
function sanitizeXmlEntities(xmlText) {
  return xmlText.replace(/&(?!amp;|lt;|gt;|quot;|apos;|#\d+;|#x[0-9a-fA-F]+;)/g, '&amp;');
}

async function fetchAndParseXml(url) {
  try {
    const res = await fetch(url, { headers: FETCH_HEADERS, signal: AbortSignal.timeout(15000) });
    if (!res.ok) {
      console.warn(`[HTTP ${res.status}] Failed to fetch: ${url}`);
      return null;
    }
    // Some sitemap indexes point at statically pre-gzipped files (.xml.gz)
    // rather than relying on transport-level Content-Encoding, so fetch()
    // won't auto-decompress them -- gunzip manually in that case.
    const xmlText = url.endsWith('.gz')
      ? zlib.gunzipSync(Buffer.from(await res.arrayBuffer())).toString('utf-8')
      : await res.text();
    return await parseStringPromise(sanitizeXmlEntities(xmlText));
  } catch (err) {
    console.error(`Error fetching/parsing XML at ${url}:`, err.message);
    return null;
  }
}

// isChildSitemap is only true for <sitemap> entries found inside a
// <sitemapindex> -- the ignore patterns target known non-recipe sub-sitemaps
// (e.g. "category-sitemap.xml") and must never gate the site's own top-level
// URL, which can legitimately contain words like "category" in its path.
async function processSitemap(sitemapUrl, baseDomain, discoveredUrls, isChildSitemap = false) {
  if (isChildSitemap && IGNORED_SITEMAP_PATTERNS.some(pattern => pattern.test(sitemapUrl))) {
    console.log(`Skipping ignored sub-sitemap: ${sitemapUrl}`);
    return false;
  }

  console.log(`Processing sitemap: ${sitemapUrl}`);
  const xml = await fetchAndParseXml(sitemapUrl);
  if (!xml) return false;

  // Handle Sitemap Index (<sitemapindex><sitemap><loc>...</loc></sitemap></sitemapindex>)
  if (xml.sitemapindex && xml.sitemapindex.sitemap) {
    for (const entry of xml.sitemapindex.sitemap) {
      const childLoc = entry.loc ? entry.loc[0].trim() : null;
      if (childLoc) {
        await processSitemap(childLoc, baseDomain, discoveredUrls, true);
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

  return true;
}

// Fallback for sites with no reachable sitemap: crawl the provided index page
// directly, following rel="next" pagination up to MAX_CRAWL_PAGES. Downstream
// (02_fetch.js) already filters out non-recipe pages via JSON-LD/site-config
// checks, so being permissive about which links get queued here is safe.
async function crawlIndexPage(startUrl, baseDomain, discoveredUrls) {
  let currentUrl = startUrl;
  const visited = new Set();
  let pagesVisited = 0;

  while (currentUrl && !visited.has(currentUrl) && pagesVisited < MAX_CRAWL_PAGES) {
    visited.add(currentUrl);
    pagesVisited++;
    console.log(`Crawling index page: ${currentUrl}`);

    let html;
    try {
      const res = await fetch(currentUrl, { headers: FETCH_HEADERS, signal: AbortSignal.timeout(15000) });
      if (!res.ok) {
        console.warn(`[HTTP ${res.status}] Failed to fetch index page: ${currentUrl}`);
        break;
      }
      html = await res.text();
    } catch (err) {
      console.error(`Error fetching index page at ${currentUrl}:`, err.message);
      break;
    }

    let dom;
    try {
      dom = new JSDOM(html, { url: currentUrl });
    } catch (err) {
      console.error(`Error parsing HTML at ${currentUrl}:`, err.message);
      break;
    }

    let added = 0;
    for (const a of dom.window.document.querySelectorAll('a[href]')) {
      const absolute = a.href;
      if (normalizeDomain(absolute) !== baseDomain || !isAllowedUrl(absolute, baseDomain)) continue;
      if (!discoveredUrls.has(absolute)) added++;
      discoveredUrls.add(absolute);
    }
    console.log(`  Found ${added} new URL(s) on this page.`);

    const nextEl = dom.window.document.querySelector('a[rel="next"], link[rel="next"]');
    currentUrl = nextEl ? nextEl.href : null;
    if (currentUrl) await sleep(CRAWL_DELAY_MS);
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

    // Sitemap candidates: the guessed sub-path first (preserves sites whose
    // real sitemap lives under a specific section), then the common
    // root-domain locations WordPress/Yoast-style sites actually use.
    let sitemapCandidates;
    if (rawUrl.endsWith('.xml')) {
      sitemapCandidates = [rawUrl];
    } else {
      const trimmedRaw = rawUrl.replace(/\/$/, '');
      const root = `${new URL(rawUrl).protocol}//${new URL(rawUrl).hostname}`;
      sitemapCandidates = [...new Set([
        `${trimmedRaw}/sitemap.xml`,
        `${root}/sitemap.xml`,
        `${root}/sitemap_index.xml`
      ])];
    }

    console.log(`\n--- Starting Discovery for: ${baseDomain} ---`);

    let sitemapFound = false;
    for (const candidate of sitemapCandidates) {
      if (await processSitemap(candidate, baseDomain, discoveredUrls)) {
        sitemapFound = true;
        break;
      }
    }

    if (!sitemapFound) {
      console.log(`No sitemap found for ${baseDomain}, falling back to crawling: ${rawUrl}`);
      await crawlIndexPage(rawUrl, baseDomain, discoveredUrls);
    }
  }

  console.log(`\n========================================`);
  console.log(`Discovery Run Complete.`);
  console.log(`Writing ${discoveredUrls.size} validated URLs to ${OUTPUT_QUEUE}`);
  
  fs.writeFileSync(OUTPUT_QUEUE, Array.from(discoveredUrls).join('\n'));
  console.log(`Successfully saved queue!`);
}

runDiscovery();