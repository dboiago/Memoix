// normalizers.js
//
// Faithful JS port of lib/core/utils/text_normalizer.dart and
// lib/core/utils/unit_normalizer.dart, scoped to only what 03_extract.js
// needs (cleanName, normalizeFractions, normalizeUnit, normalizeGarnish).
//
// Per recipe_import_result.dart's fromAi() comment: "Apply normalizers per
// AGENTS.md: all imports MUST pass through normalizers" — OCR import and
// URL import both do this; 03_extract.js currently does not. This module
// closes that gap so corpus-pipeline output matches every other import path.
//
// Ported, not reimplemented: logic mirrors the Dart source line-for-line
// where possible so behavior stays identical, not just "close enough."

// ---------------------------------------------------------------------------
// TextNormalizer.cleanName
// ---------------------------------------------------------------------------

const LOWERCASE_WORDS = new Set([
  'a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on', 'at', 'by', 'with',
]);

// Missing-comma bug ('ev' 'diy' -> 'evdiy') fixed upstream in the repo as of
// this session, so ported here as the two separate entries that were always
// intended.
const UPPERCASE_WORDS = new Set([
  'bbq', 'xo', 'msg', 'aoc', 'dop', 'igp', 'pdo', 'pgi', 'abv', 'ibu', 's&p', 'tt', 'ap', 'gf', 'df', 'vg', 'gmo', 'hp', 'a1',
  'usa', 'uk', 'eu', 'nyc', 'la', 'sf', 'doc', 'docg', 'aop',
  'ipa', 'blt', 'pb', 'pbj',
  'evoo', 'evo', 'ev', 'diy', 'usda', 'fda',
  'ai', 'ml', 'tv', 'dvd', 'cd',
]);

/**
 * Port of TextNormalizer.cleanName. Collapses whitespace, strips trailing
 * punctuation, applies Title Case with lowercase connectors and preserved
 * acronyms (BBQ, XO, MSG, etc.) exactly as the app does for every other
 * import path.
 */
export function cleanName(name) {
  let cleaned = (name ?? '').trim().replace(/\s+/g, ' ');
  cleaned = cleaned.replace(/[,;:.]+$/, '').trim();
  if (!cleaned) return cleaned;

  const words = cleaned.split(' ');
  const titleCased = words.map((word, i) => {
    if (!word) return word;

    const wordLower = word.toLowerCase().replace(/[^a-z&0-9]/g, '');
    if (UPPERCASE_WORDS.has(wordLower)) {
      return word.replace(/[a-zA-Z]+/g, (m) => m.toUpperCase());
    }

    if (i === 0) {
      return word[0].toUpperCase() + word.slice(1).toLowerCase();
    }

    if (LOWERCASE_WORDS.has(word.toLowerCase())) {
      return word.toLowerCase();
    }

    return word[0].toUpperCase() + word.slice(1).toLowerCase();
  });

  return titleCased.join(' ');
}

/** Port of TextNormalizer.toTitleCase. */
export function toTitleCase(text) {
  if (!text) return text;
  return text[0].toUpperCase() + text.slice(1).toLowerCase();
}

// ---------------------------------------------------------------------------
// TextNormalizer.normalizeFractions
// ---------------------------------------------------------------------------

const TEXT_TO_FRACTION = {
  '1/2': '½', '1/4': '¼', '3/4': '¾',
  '1/3': '⅓', '2/3': '⅔',
  '1/8': '⅛', '3/8': '⅜', '5/8': '⅝', '7/8': '⅞',
  '1/5': '⅕', '2/5': '⅖', '3/5': '⅗', '4/5': '⅘',
  '1/6': '⅙', '5/6': '⅚',
};

const DECIMAL_TO_FRACTION = {
  '0.5': '½', '0.25': '¼', '0.75': '¾',
  '0.33': '⅓', '0.333': '⅓', '0.67': '⅔', '0.666': '⅔', '0.667': '⅔',
  '0.125': '⅛', '0.375': '⅜', '0.625': '⅝', '0.875': '⅞',
  '0.2': '⅕', '0.4': '⅖', '0.6': '⅗', '0.8': '⅘',
};

/**
 * Port of TextNormalizer.normalizeFractions. Converts text fractions
 * ("1/2") and decimal fractions ("0.5", including repeating decimals like
 * "0.333...") to unicode glyphs ("½"), matching every other import path's
 * stored amount format.
 */
export function normalizeFractions(text) {
  if (text === null || text === undefined || text === '') return text ?? '';
  let result = text;

  for (const [textFrac, glyph] of Object.entries(TEXT_TO_FRACTION)) {
    result = result.split(textFrac).join(glyph);
  }

  result = result.replace(/\b0\.3{3,}\d*\b/g, '⅓');
  result = result.replace(/\b0\.6{3,}\d*\b/g, '⅔');
  result = result.replace(/\b0\.16{2,}\d*\b/g, '⅙');
  result = result.replace(/\b0\.83{2,}\d*\b/g, '⅚');

  for (const [decimal, glyph] of Object.entries(DECIMAL_TO_FRACTION)) {
    const escaped = decimal.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    result = result.replace(new RegExp(`(?<![\\d])${escaped}(?![\\d])`, 'g'), glyph);
  }

  return result;
}

// ---------------------------------------------------------------------------
// UnitNormalizer.normalize
// ---------------------------------------------------------------------------

const UNIT_MAP = {
  cup: 'C', cups: 'C', c: 'C',
  tablespoon: 'Tbsp', tablespoons: 'Tbsp', tbsp: 'Tbsp', tbs: 'Tbsp', tb: 'Tbsp', t: 'Tbsp',
  teaspoon: 'tsp', teaspoons: 'tsp', tsp: 'tsp', ts: 'tsp',
  'fluid ounce': 'fl oz', 'fluid ounces': 'fl oz', 'fl. oz': 'fl oz', 'fl.oz': 'fl oz', floz: 'fl oz',
  liter: 'L', liters: 'L', litre: 'L', litres: 'L', l: 'L',
  milliliter: 'ml', milliliters: 'ml', millilitre: 'ml', millilitres: 'ml', mls: 'ml',
  gram: 'g', grams: 'g', gr: 'g', gm: 'g', gms: 'g',
  kilogram: 'kg', kilograms: 'kg', kilo: 'kg', kilos: 'kg', kgs: 'kg',
  milligram: 'mg', milligrams: 'mg', mgs: 'mg',
  ounce: 'oz', ounces: 'oz',
  pound: 'lb', pounds: 'lb', lbs: 'lb',
  can: 'can', cans: 'cans',
  bunch: 'bunch', bunches: 'bunches',
  clove: 'clove', cloves: 'clove',
  pinch: 'pinch', pinches: 'pinches',
  dash: 'dash', dashes: 'dashes',
  slice: 'slice', slices: 'slices',
  piece: 'pc', pieces: 'pcs', pcs: 'pcs', pc: 'pc',
  sprig: 'sprig', sprigs: 'sprigs',
  stalk: 'stalk', stalks: 'stalks',
  head: 'head', heads: 'heads',
  package: 'pkg', packages: 'pkgs', pkg: 'pkg', pkgs: 'pkgs',
  stick: 'stick', sticks: 'sticks',
  drop: 'drop', drops: 'drops',
  handful: 'handful', handfuls: 'handfuls',
  pint: 'pt', pints: 'pt', pt: 'pt',
  quart: 'qt', quarts: 'qt', qt: 'qt',
  gallon: 'gal', gallons: 'gal', gal: 'gal',
  large: 'large', medium: 'medium', small: 'small',
};

const NORMALIZED_UNIT_VALUES = new Set(Object.values(UNIT_MAP));

// Words worth recognizing as a standalone amount+unit signal for compound-
// amount detection specifically. Union of UNIT_MAP's keys (spelled-out
// input forms: "grams", "tablespoons") AND its values (canonical
// abbreviations: "g", "Tbsp") -- keys alone miss common bare abbreviations
// like "g"/"kg"/"oz"/"lb" that only exist as map values, not keys, which
// the original narrower hand-typed list happened to include directly and
// a keys-only refactor would have silently dropped. Deliberately excludes
// size descriptors ('large', 'medium', 'small') that are also UNIT_MAP
// keys -- "2 large eggs" isn't a compound-amount candidate, and including
// those would cause false positives.
const SIZE_DESCRIPTOR_KEYS = new Set(['large', 'medium', 'small']);
const COMPOUND_DETECTION_UNIT_WORDS = [...new Set([
  ...Object.keys(UNIT_MAP).filter((k) => !SIZE_DESCRIPTOR_KEYS.has(k)),
  ...Object.values(UNIT_MAP),
])];

/**
 * Port of UnitNormalizer.normalize. Strips a trailing period, maps to the
 * app's canonical abbreviation ("ounce" -> "oz"), and preserves case for
 * values already in abbreviated form.
 */
export function normalizeUnit(unit) {
  if (!unit) return '';
  let trimmed = unit.trim();
  if (trimmed.endsWith('.')) trimmed = trimmed.slice(0, -1);

  const lower = trimmed.toLowerCase();
  if (UNIT_MAP[lower]) return UNIT_MAP[lower];
  if (NORMALIZED_UNIT_VALUES.has(trimmed)) return trimmed;
  return trimmed;
}

// ---------------------------------------------------------------------------
// normalizeGarnish (top-level function in text_normalizer.dart)
// ---------------------------------------------------------------------------

/**
 * Port of normalizeGarnish: strips trailing punctuation, drops a leading
 * article (a/an/the), then applies the same cleanName Title Case as every
 * other name field. NOT the same as a bare capitalize-first-letter pass —
 * "chamomile powder" -> "Chamomile Powder", not "Chamomile powder".
 */
export function normalizeGarnish(text) {
  let cleaned = (text ?? '').trim();
  cleaned = cleaned.replace(/[.,;:!?]+$/, '');
  cleaned = cleaned.replace(/^(a|an|the)\s+/i, '');
  return cleanName(cleaned);
}

// ---------------------------------------------------------------------------
// normalizeGlass — corpus-pipeline-only, no Dart-side equivalent exists.
// Confirmed against the app's own glassware suggestion list: entries are
// bare style names ("Coupe", "Highball"), never "<style> glass".
// ---------------------------------------------------------------------------

/**
 * Strips a redundant trailing "glass"/"glasses" and applies the same
 * Title Case as every other name-like field, matching what the app's own
 * glassware picker actually shows.
 */
export function normalizeGlass(raw) {
  const trimmed = (raw ?? '').trim();
  if (!trimmed) return '';
  const stripped = trimmed.replace(/\s*glass(es)?\s*$/i, '').trim();
  return cleanName(stripped || trimmed);
}

export { COMPOUND_DETECTION_UNIT_WORDS };
