#!/usr/bin/env node
// 02_fetch.js
// Reads urls/queue.txt, fetches each page, extracts main content,
// and saves cleaned Markdown + metadata to raw/.
//
// JSON-LD structured data (time, yield, cuisine, category) is extracted
// separately before Readability strips it, and saved into the meta file
// for use by 03_extract.js.
//
// Site tags from urls/site-tags.json (written by 01_discover.js --file) are
// looked up by hostname and saved into each recipe's meta file as
// siteRegionHint/siteCourseHint — soft defaults for 03_extract.js to weigh
// alongside JSON-LD hints, not a filter on what gets fetched here.
//
// Resumable: skips any URL already recorded in an existing raw/*.meta.json.
// Logs failures to logs/fetch-errors.jsonl without stopping the run.
//
// Usage:
//   node 02_fetch.js [--limit N]

import { readFileSync, writeFileSync, existsSync, mkdirSync, appendFileSync, readdirSync } from 'fs';
import { createHash } from 'crypto';
import { Readability } from '@mozilla/readability';
import { JSDOM, VirtualConsole } from 'jsdom';
import TurndownService from 'turndown';
import { tryAllSiteConfigs } from './site_configs.js';

const QUEUE_FILE       = 'urls/queue.txt';
const SITE_TAGS_FILE   = 'urls/site-tags.json';
const RAW_DIR          = 'raw';
const LOG_DIR          = 'logs';
const ERROR_LOG        = `${LOG_DIR}/fetch-errors.jsonl`;
const RATE_LIMIT_MS    = 1500;
const FETCH_TIMEOUT_MS = 20000;
const MIN_CONTENT_CHARS = 400;

// Upgraded User-Agent to mimic standard desktop Chrome
const USER_AGENT       = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

// Filters for non-HTML static assets, API endpoints, and category/archive pages
const IGNORE_PATTERN   = /\.(png|jpg|jpeg|gif|webp|svg|css|js|md|json|pdf|zip|gz)$|xmlrpc\.php|javascript:void\(0\)|#$/i;
const INDEX_PATTERN    = /\/(recipe-archives|category|blog|tag|recipes|pages)\/?$/i;

// Mute JSDOM internal CSS parsing warnings
const virtualConsole = new VirtualConsole();
virtualConsole.on('error', () => {});

const SITE_TAGS = existsSync(SITE_TAGS_FILE)
  ? JSON.parse(readFileSync(SITE_TAGS_FILE, 'utf8'))
  : {};

function siteTagsFor(url) {
  const hostname = new URL(url).hostname.replace(/^www\./, '');
  return SITE_TAGS[hostname] || null;
}

const turndown = new TurndownService({ headingStyle: 'atx', bulletListMarker: '-' });

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

function friendlySlug(url, title) {
  const domain = new URL(url).hostname.replace(/^www\./, '').split('.')[0];
  const titleSlug = (title || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 50) || 'untitled';
  const hash = createHash('sha1').update(url).digest('hex').slice(0, 8);
  return `${titleSlug}_${domain}_${hash}`;
}

function loadFetchedUrls() {
  if (!existsSync(RAW_DIR)) return new Set();
  const fetched = new Set();
  for (const f of readdirSync(RAW_DIR)) {
    if (!f.endsWith('.meta.json')) continue;
    try {
      const meta = JSON.parse(readFileSync(`${RAW_DIR}/${f}`, 'utf8'));
      if (meta.url) fetched.add(meta.url);
    } catch { /* skip unreadable meta file */ }
  }
  return fetched;
}

function logError(url, reason, detail = '') {
  const entry = JSON.stringify({ ts: new Date().toISOString(), url, reason, detail });
  appendFileSync(ERROR_LOG, entry + '\n');
  console.error(`  SKIP [${reason}]: ${url}${detail ? ' — ' + detail : ''}`);
}

// Checks if URL is a likely recipe page vs. homepage, static asset, or index
function isRecipeCandidate(url) {
  try {
    const parsed = new URL(url);
    if (IGNORE_PATTERN.test(url)) return false;
    if (parsed.pathname === '/' || parsed.pathname === '') return false;
    if (INDEX_PATTERN.test(parsed.pathname)) return false;
    return true;
  } catch {
    return false;
  }
}

// Interleaves queue by domain to prevent hammering one site repeatedly
function interleaveByDomain(urls) {
  const buckets = new Map();
  for (const url of urls) {
    try {
      const host = new URL(url).hostname;
      if (!buckets.has(host)) buckets.set(host, []);
      buckets.get(host).push(url);
    } catch {
      if (!buckets.has('unknown')) buckets.set('unknown', []);
      buckets.get('unknown').push(url);
    }
  }

  const interleaved = [];
  while (buckets.size > 0) {
    for (const [host, queue] of buckets.entries()) {
      interleaved.push(queue.shift());
      if (queue.length === 0) buckets.delete(host);
    }
  }
  return interleaved;
}

async function fetchHtml(url) {
  const res = await fetch(url, {
    headers: {
      'User-Agent': USER_AGENT,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cache-Control': 'no-cache',
    },
    redirect: 'follow',
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const contentType = res.headers.get('content-type') || '';
  if (!contentType.includes('html')) throw new Error(`Non-HTML content-type: ${contentType}`);
  return res.text();
}

function extractRawInstructions(value) {
  if (value == null) return [];
  if (typeof value === 'string') return [value.trim()].filter(Boolean);
  if (Array.isArray(value)) {
    return value
      .map(item => {
        if (typeof item === 'string') return item.trim();
        if (item && typeof item === 'object') return (item.text || item.name || '').trim();
        return String(item).trim();
      })
      .filter(Boolean);
  }
  return [];
}

function extractRawIngredients(value) {
  if (value == null) return [];
  if (typeof value === 'string') return [value.trim()].filter(Boolean);
  if (Array.isArray(value)) {
    return value.map(item => String(item).trim()).filter(Boolean);
  }
  return [];
}

function extractJsonLd(dom) {
  const scripts = dom.window.document.querySelectorAll('script[type="application/ld+json"]');
  for (const script of scripts) {
    try {
      const raw = JSON.parse(script.textContent);
      const items = raw['@graph'] ? raw['@graph'] : [raw];
      for (const item of items) {
        const type = item['@type'];
        if (type === 'Recipe' || (Array.isArray(type) && type.includes('Recipe'))) {
          let rawIngredients = extractRawIngredients(item.recipeIngredient);
          if (rawIngredients.length === 0) {
            rawIngredients = extractRawIngredients(item.ingredients);
          }
          let rawInstructions = extractRawInstructions(item.recipeInstructions);
          if (rawInstructions.length === 0) {
            rawInstructions = extractRawInstructions(item.instructions);
          }
          return {
            ldName:      item.name                          || null,
            ldTime:      item.totalTime || item.cookTime    || null,
            ldPrepTime:  item.prepTime                      || null,
            ldCookTime:  item.cookTime                      || null,
            ldYield:     item.recipeYield                   || null,
            ldCuisine:   Array.isArray(item.recipeCuisine)
                           ? item.recipeCuisine.join(', ')
                           : (item.recipeCuisine || null),
            ldCategory:  Array.isArray(item.recipeCategory)
                           ? item.recipeCategory.join(', ')
                           : (item.recipeCategory || null),
            ldKeywords:  item.keywords                      || null,
            ldIngredientsRaw:  rawIngredients.length  > 0 ? rawIngredients  : null,
            ldInstructionsRaw: rawInstructions.length > 0 ? rawInstructions : null,
            ldNutritionRaw:    (item.nutrition && typeof item.nutrition === 'object') ? item.nutrition : null,
          };
        }
      }
    } catch { /* malformed JSON-LD, skip */ }
  }
  return {};
}

function extractContent(html, url) {
  const dom    = new JSDOM(html, { url, virtualConsole });
  const ldData = extractJsonLd(dom);

  const siteConfigResult = tryAllSiteConfigs(dom.window.document);

  const reader  = new Readability(dom.window.document);
  const article = reader.parse();

  // Readability failing doesn't mean there's nothing usable. ldData and
  // siteConfigResult are both extracted from the raw document above,
  // independent of Readability's own scoring heuristic, and can succeed
  // even when it fails — confirmed on madewithlau.com, which turned out to
  // be fully server-rendered (no JS execution needed) but has enough
  // competing video/upsell/testimonial content that Readability picks the
  // wrong region. Discarding a good siteConfigResult/ldData just because
  // Readability separately failed was silently losing real data on any
  // site with this pattern, not just that one. Only bail out entirely if
  // there's truly nothing to work with.
  if (!article || !article.content) {
    const hasLdRecipeData    = Boolean(ldData.ldIngredientsRaw || ldData.ldInstructionsRaw);
    const hasSiteConfigMatch = Boolean(siteConfigResult && siteConfigResult.lines && siteConfigResult.lines.length > 0);
    if (!hasLdRecipeData && !hasSiteConfigMatch) return null;

    // Best-effort fallback so the whole-page model call still has
    // *something* for name/time/cuisine — rough, unclean text, not meant to
    // be pretty. The deterministic ldData/siteConfigResult data (used
    // directly downstream) is what actually matters here and doesn't
    // depend on how clean this fallback text is.
    const bodyText = (dom.window.document.body?.textContent || '').replace(/\s+/g, ' ').trim();
    return {
      title:             dom.window.document.title || '',
      markdown:          bodyText.slice(0, 8000),
      byline:            '',
      ldData,
      siteConfigResult,
      readabilityFailed: true,
    };
  }

  const markdown = turndown.turndown(article.content);
  return {
    title:    article.title || '',
    markdown: markdown.trim(),
    byline:   article.byline || '',
    ldData,
    siteConfigResult,
  };
}

async function main() {
  const args      = process.argv.slice(2);
  const limitIdx  = args.indexOf('--limit');
  const limit     = limitIdx !== -1 ? parseInt(args[limitIdx + 1], 10) : Infinity;
  const domainIdx = args.indexOf('--domain');
  const domain    = domainIdx !== -1 ? args[domainIdx + 1] : null;

  if (!existsSync(QUEUE_FILE)) {
    console.error(`Queue file not found: ${QUEUE_FILE}. Run 01_discover.js first.`);
    process.exit(1);
  }

  mkdirSync(RAW_DIR, { recursive: true });
  mkdirSync(LOG_DIR, { recursive: true });

  const allUrls        = readFileSync(QUEUE_FILE, 'utf8').split('\n').filter(Boolean);
  const filteredUrls   = domain ? allUrls.filter(u => u.includes(domain)) : allUrls;
  const urls           = domain ? filteredUrls : interleaveByDomain(filteredUrls);
  const alreadyFetched = loadFetchedUrls();

  console.log(`Queue: ${allUrls.length} URL(s) total${domain ? ` (${urls.length} matching --domain ${domain})` : ''}`);

  let processed = 0, skipped = 0, failed = 0;

  for (const url of urls) {
    if (processed >= limit) break;

    if (alreadyFetched.has(url)) {
      skipped++;
      continue;
    }

    if (!isRecipeCandidate(url)) {
      logError(url, 'filtered-asset-or-index', 'Skipped static asset, homepage, or category index page');
      failed++;
      continue;
    }

    console.log(`Fetching [${processed + 1}]: ${url}`);

    try {
      const html      = await fetchHtml(url);
      await sleep(RATE_LIMIT_MS);

      const extracted = extractContent(html, url);

      if (extracted?.readabilityFailed) {
        console.log(`  (Readability found no main content — kept JSON-LD/site-config data, using rough fallback text)`);
      }

      if (!extracted) {
        logError(url, 'readability-failed', 'No usable content: Readability found no article, and no JSON-LD or site-config data either');
        failed++;
        continue;
      }

      if (extracted.markdown.length < MIN_CONTENT_CHARS) {
        logError(url, 'content-too-short', `${extracted.markdown.length} chars`);
        failed++;
        continue;
      }

      const slug     = friendlySlug(url, extracted.title);
      const mdPath   = `${RAW_DIR}/${slug}.md`;
      const metaPath = `${RAW_DIR}/${slug}.meta.json`;
      const siteTags = siteTagsFor(url);

      writeFileSync(mdPath, extracted.markdown, 'utf8');
      writeFileSync(metaPath, JSON.stringify({
        url,
        slug,
        title:     extracted.title,
        byline:    extracted.byline,
        fetchedAt: new Date().toISOString(),
        ...extracted.ldData,
        htmlIngredientLines:  extracted.siteConfigResult ? extracted.siteConfigResult.lines : null,
        htmlIngredientConfig: extracted.siteConfigResult ? extracted.siteConfigResult.matchedConfig : null,
        siteRegionHint: siteTags?.region ?? null,
        siteCourseHint: siteTags?.course ?? null,
      }, null, 2), 'utf8');

      const ldFound = Object.keys(extracted.ldData).length > 0;
      if (!ldFound) console.log(`  (no JSON-LD found on this page)`);
      if (extracted.siteConfigResult) {
        console.log(`  (matched site config: ${extracted.siteConfigResult.matchedConfig})`);
      }

      processed++;
    } catch (e) {
      logError(url, 'fetch-error', e.message);
      failed++;
      await sleep(RATE_LIMIT_MS);
    }
  }

  console.log(`\nDone. Fetched: ${processed}, already had: ${skipped}, failed: ${failed}`);
  if (failed > 0) console.log(`Failures logged to ${ERROR_LOG}`);
  console.log(`\nNOTE: 'readability-failed' now only fires when there's truly nothing usable (no article content, no JSON-LD, no site-config match). If a site still shows up there a lot, it's more likely genuinely JS-rendered than before — those need Playwright for a second pass.`);
}

main().catch(e => { console.error(e.message); process.exit(1); });