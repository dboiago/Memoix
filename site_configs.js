// site_configs.js
// Ported from Memoix's lib/core/services/url_importer.dart:
// ExtractionMode enum, SiteConfig class, the _siteConfigs registry,
// _extractWithSiteConfig, _tryAllSiteConfigs, _cleanSectionName, _stripForThePrefix.
//
// This is CSS-selector-based DOM extraction, not free-text parsing, so it's a
// direct 1:1 port rather than a translation with drift risk. jsdom's
// element.textContent is already tag-stripped and entity-decoded, so the
// Dart original's manual _decodeHtml tag-stripping/entity step is unnecessary
// here; only its fraction-to-unicode conversion is worth keeping, and that's
// handled upstream by 03_extract.js already.
//
// Matches Dart's line convention exactly: a section header becomes a line
// like "[Section Name]", and every following line belongs to that section
// until the next bracketed line or the end of the list.

const FOR_THE_PREFIX_RE = /^For\s+(?:the\s+)?(.+)$/i;

function stripForThePrefix(text) {
  const match = text.match(FOR_THE_PREFIX_RE);
  return match ? match[1].trim() : text;
}

function cleanSectionName(text) {
  const cleaned = text.replace(/:$/, '').trim();
  return stripForThePrefix(cleaned);
}

// SiteConfig registry, ported field-for-field from url_importer.dart.
// mode: 'containerWithSections' | 'siblingHeaderList' | 'mixedList'
const SITE_CONFIGS = {
  kingarthur: {
    sectionSelector: '.ingredient-section',
    headerIsDirectChild: true,
    headerChildTag: 'p',
    ingredientSelector: 'ul li',
    mode: 'containerWithSections',
  },
  tasty: {
    // Tasty.co (BuzzFeed) specifically, not the unrelated "Tasty Recipes" WP plugin.
    sectionSelector: '.ingredients__section',
    headerSelector: '.ingredient-section-name',
    ingredientSelector: 'li.ingredient',
    mode: 'containerWithSections',
  },
  seriouseats: {
    headerSelector: '.structured-ingredients__list-heading',
    ingredientSelector: 'li',
    mode: 'siblingHeaderList',
  },
  amazingfood: {
    containerSelector: 'ul.ingredient_list, .ingredient_list',
    headerSelector: 'li.category h3',
    ingredientSelector: 'li.ingredient',
    mode: 'mixedList',
  },
  nyt: {
    headerSelector: '[class*="ingredientgroup_name"]',
    ingredientSelector: 'li',
    mode: 'siblingHeaderList',
  },
  wprm: {
    // Matches any site running the WP Recipe Maker plugin, not a specific domain.
    sectionSelector: '.wprm-recipe-ingredient-group',
    headerSelector: '.wprm-recipe-group-name',
    ingredientSelector: '.wprm-recipe-ingredient',
    mode: 'containerWithSections',
  },
  'generic-headers': {
    containerSelector: '.ingredients',
    headerSelector: 'h3, h4',
    ingredientSelector: 'li',
    mode: 'siblingHeaderList',
  },
  'generic-container': {
    containerSelector: '#recipe-ingredients, ul.ingredients, .ingredients ul, .recipe-ingredients, [data-recipe-ingredients]',
    headerSelector: 'li.category h3',
    ingredientSelector: 'li:not(.category)',
    mode: 'mixedList',
  },
  // Last-resort fallback for pages with zero recipe-plugin markup at all --
  // confirmed 2026-07-10 against an okonomikitchen.com post from 2018 that
  // predates the site's later recipe-plugin adoption: just a bare `<h2>` (or
  // h1/h3/h4) reading "Ingredients", directly followed by a plain <ul>/<ol>,
  // no class or wrapper element anywhere to select against. Every other
  // config in this file requires some CSS hook; this one matches on heading
  // TEXT instead, since that's all a page like this has to offer.
  'generic-text-heading': {
    headingTextPattern: /^ingredients?:?$/i,
    ingredientSelector: 'li',
    mode: 'siblingHeaderList',
  },
};

function textOf(el) {
  return (el && el.textContent ? el.textContent.trim() : '');
}

function extractWithSiteConfig(document, config) {
  const lines = [];

  let container = document;
  if (config.containerSelector) {
    let found = null;
    for (const sel of config.containerSelector.split(',').map(s => s.trim())) {
      found = document.querySelector(sel);
      if (found) break;
    }
    if (!found) return null;
    container = found;
  }

  if (config.mode === 'containerWithSections') {
    if (!config.sectionSelector) return null;
    const sections = container.querySelectorAll(config.sectionSelector);
    if (sections.length === 0) return null;

    for (const section of sections) {
      let headerText = null;
      if (config.headerIsDirectChild && config.headerChildTag) {
        for (const child of section.children) {
          if (child.localName === config.headerChildTag) {
            headerText = textOf(child);
            break;
          }
        }
      } else if (config.headerSelector) {
        const header = section.querySelector(config.headerSelector);
        if (header) headerText = textOf(header);
      }
      if (headerText) lines.push(`[${cleanSectionName(headerText)}]`);

      const items = section.querySelectorAll(config.ingredientSelector);
      for (const item of items) {
        const text = textOf(item);
        if (text) lines.push(text);
      }
    }
  } else if (config.mode === 'siblingHeaderList') {
    let headers;
    if (config.headingTextPattern) {
      // Text-based match: scan every heading tag and filter by content,
      // since a page with no plugin markup has no class to select against.
      const allHeadings = container.querySelectorAll('h1, h2, h3, h4');
      headers = [...allHeadings].filter(h => config.headingTextPattern.test(textOf(h)));
      if (headers.length === 0) return null;
    } else if (config.headerSelector) {
      headers = container.querySelectorAll(config.headerSelector);
      if (headers.length === 0) return null;
    } else {
      return null;
    }

    for (const header of headers) {
      // Skip the section-label line for text-matched headers: this mode
      // exists specifically to find the umbrella "Ingredients" heading on
      // pages with no real subsections, so treating it as a named section
      // would incorrectly tag every ingredient with section: "Ingredients".
      if (!config.headingTextPattern) {
        const headerText = textOf(header);
        if (headerText) lines.push(`[${cleanSectionName(headerText)}]`);
      }

      let sibling = header.nextElementSibling;
      while (sibling) {
        const tag = (sibling.localName || '').toLowerCase();
        if (tag === 'ul' || tag === 'ol') {
          const items = sibling.querySelectorAll(config.ingredientSelector);
          for (const item of items) {
            const text = textOf(item);
            if (text) lines.push(text);
          }
          break;
        } else if (tag === 'h2' || tag === 'h3' || tag === 'h4' || tag === 'p') {
          const headerClass = header.getAttribute('class') || '';
          const siblingClass = sibling.getAttribute('class') || '';
          if (siblingClass && headerClass.includes(siblingClass.split(' ')[0])) break;
          if (tag === 'h2' || tag === 'h3') break;
        }
        sibling = sibling.nextElementSibling;
      }
    }
  } else if (config.mode === 'mixedList') {
    const allItems = container.querySelectorAll('li');
    if (allItems.length === 0) return null;

    for (const item of allItems) {
      const itemClass = item.getAttribute('class') || '';
      if (itemClass.includes('category')) {
        const headerSelTag = config.headerSelector ? config.headerSelector.split(' ').pop() : 'h3';
        const headerEl = item.querySelector(headerSelTag);
        if (headerEl) {
          const headerText = textOf(headerEl);
          if (headerText) lines.push(`[${cleanSectionName(headerText)}]`);
        }
      } else {
        const text = textOf(item);
        if (text) lines.push(text);
      }
    }
  } else {
    return null;
  }

  return lines.length > 0 ? lines : null;
}

function tryAllSiteConfigs(document) {
  for (const key of Object.keys(SITE_CONFIGS)) {
    const result = extractWithSiteConfig(document, SITE_CONFIGS[key]);
    if (result && result.length > 0) {
      return { matchedConfig: key, lines: result };
    }
  }
  return null;
}

export { SITE_CONFIGS, extractWithSiteConfig, tryAllSiteConfigs, cleanSectionName };
