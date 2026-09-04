#!/usr/bin/env node
// 03_extract.js
// Reads Markdown files from raw/, sends each to Ollama for structured extraction,
// and saves JSON to extracted/. Output shape matches rag_telemetry payload.
//
// JSON-LD data from the meta file is used directly for time and yield where
// available, and provided as hints to the model for course, cuisine, and region.
//
// Resumable: skips any file already in extracted/.
// Logs failures to logs/extract-errors.jsonl.
//
// Ollama must be running: ollama serve (or it auto-starts on Windows).
// Model must be pulled: ollama run hf.co/scrapegraphai/sgai-qwen3-1.7b-gguf
//
// Usage:
//   node 03_extract.js [--limit N]
//   node 03_extract.js --model qwen3:14b-q4_k_m --raw-dir raw-test --out-dir extracted-test-14b \
//     --needs-review-dir needs-review-test --cuisine-review-dir cuisine-review-test --log-dir logs-test
//
// --model overrides MODEL for this run only (e.g. for A/B testing a different
// local Ollama model against the same input files without touching the
// pipeline's default). --raw-dir/--out-dir let that comparison run against a
// small hand-picked set of known-hard files without writing into the real
// extracted/ corpus or resuming past files already extracted there.
//
// IMPORTANT: --out-dir alone does NOT isolate a test run. needs-review/,
// cuisine-review/, and logs/ are shared with the real corpus run unless you
// also pass --needs-review-dir/--cuisine-review-dir/--log-dir -- otherwise a
// recipe flagged during a small test will be treated as already handled by
// the real run later and silently skipped.

import { readdirSync, readFileSync, writeFileSync, existsSync, mkdirSync, appendFileSync } from 'fs';
import { createHash } from 'crypto';
import { spawn } from 'child_process';
import { cleanName, normalizeFractions, normalizeUnit, normalizeGarnish, normalizeGlass, COMPOUND_DETECTION_UNIT_WORDS } from './normalizers.js';

// let, not const: --raw-dir/--out-dir/--model can override these in main()
// before anything else runs, for A/B testing against a fixed input set
// without touching the real corpus or the default model.
let RAW_DIR          = 'raw';
let OUT_DIR          = 'extracted';
// Two separate buckets rather than one, since they answer different
// questions: NEEDS_REVIEW_DIR is "did we actually get complete/reliable
// data" (compound-amount lines, missing directions, a failed Dart parse).
// CUISINE_REVIEW_DIR is "does this content belong on this site at all"
// (the model's own cuisine call disagrees with the site's region tag).
// Keeping them apart means a glance at either folder tells you which kind
// of decision it needs without re-diagnosing each file.
// let, not const: --needs-review-dir/--cuisine-review-dir/--log-dir can
// override these. Previously these three were hardcoded regardless of
// --out-dir, which meant a --raw-dir/--out-dir test run still wrote into
// the same needs-review/cuisine-review/logs the real corpus run uses --
// a recipe flagged during a small test would then be silently skipped by
// the real run's resumability check (existsSync sees it as already done)
// and would never make it into extracted/. Fixed: these now default to the
// same shared paths for a normal run, but a test run must pass its own.
let NEEDS_REVIEW_DIR   = 'needs-review';
let CUISINE_REVIEW_DIR = 'cuisine-review';
let LOG_DIR        = 'logs';
let ERROR_LOG      = `${LOG_DIR}/extract-errors.jsonl`;
const OLLAMA_URL     = 'http://localhost:11434/api/chat';
let MODEL            = 'huggingface.co/Qwen/Qwen3-14B-GGUF:Q4_K_M';
const NUM_CTX        = 8192;
const TEMPERATURE    = 0;
const SCHEMA_VERSION = 2;
const MAX_CONTENT_CHARS = 12000;
// Compile once with: dart compile exe memoix_recipe_parser.dart -o memoix_recipe_parser.exe
// (or .out on Mac/Linux). Path is relative to wherever this script is run from.
const DART_PARSER_PATH = './memoix_recipe_parser.exe';
// Separate from the whole-page call's timeout below. Per-line calls run
// sequentially (one recipe can be 18+ calls), and local hardware contention
// under sustained load is a plausible cause of the line-7 timeout seen on
// doubanjiang, not yet distinguished from genuine per-line slowness.
const INGREDIENT_LINE_TIMEOUT_MS = 300_000;

// Valid course values matching Memoix's domain model.
// Pizza, sandwich, and modernist-conceptual content are separate domainTypes
// with their own schemas and are out of scope for this script (deferred:
// per-page domain classification not yet built). 'modernist' here refers
// only to modernist recipes that are structurally standard recipes.
const VALID_COURSES = [
  'apps', 'soups', 'mains', 'sides', 'salads', 'desserts', 'brunch',
  'drinks', 'breads', 'sauces', 'rubs', 'pickles', "veg'n", 'modernist',
];

// Base-spirit categories for drink recipes, confirmed against the app's
// spirit color constants (spiritWhiskey, spiritRum, etc.). Canonical casing
// (Title Case) matches the app's own example data ("subcategory": "Gin"),
// unlike VALID_COURSES which the app stores lowercase -- the two fields use
// different casing conventions in the real schema, not an inconsistency here.
const VALID_SUBCATEGORIES = [
  'Gin', 'Vodka', 'Whiskey', 'Rum', 'Tequila', 'Brandy', 'Wine',
  'Sparkling', 'Liqueur', 'Beer', 'Tea', 'Coffee', 'Mocktail',
];

// Deterministic pre-resolution from PAGE-level structured data (ldCategory,
// ldCuisine) only -- never siteCourseHint/siteRegionHint. Site-level hints
// describe the site in general, not this specific recipe, and locking a
// value from them would reintroduce the exact bias risk the blind cuisine
// check exists to catch (a stray recipe on a JP-tagged site getting hard-
// locked to JP with no review step). ldCategory/ldCuisine are schema.org
// markup the page itself put on this specific recipe, a materially
// different trust level, matching how buildLdHints already treats them as
// stronger than site tags.
//
// Every entry here maps to exactly one confident answer. Deliberately
// excludes broad multi-country groupings ("Mediterranean", "Caribbean") --
// those span several genuinely different national cuisines, and collapsing
// one to a single country (e.g. Mediterranean -> Greece) would ship a
// specific wrong answer that looks confident and never gets reviewed. Those
// fall through to the blind classification call instead of being locked here.
const LD_COURSE_MAP = {
  'dessert': 'desserts', 'desserts': 'desserts', 'sweets': 'desserts', 'sweet': 'desserts',
  'breakfast': 'brunch', 'brunch': 'brunch',
  'appetizer': 'apps', 'appetizers': 'apps', 'starter': 'apps', 'starters': 'apps', 'snack': 'apps', 'snacks': 'apps',
  'main': 'mains', 'mains': 'mains', 'main course': 'mains', 'main dish': 'mains', 'dinner': 'mains', 'entree': 'mains', 'entrees': 'mains',
  'side': 'sides', 'sides': 'sides', 'side dish': 'sides',
  'salad': 'salads', 'salads': 'salads',
  'soup': 'soups', 'soups': 'soups',
  'drink': 'drinks', 'drinks': 'drinks', 'beverage': 'drinks', 'cocktail': 'drinks', 'cocktails': 'drinks',
  'bread': 'breads', 'breads': 'breads',
  'sauce': 'sauces', 'sauces': 'sauces', 'condiment': 'sauces', 'dressing': 'sauces',
  'rub': 'rubs', 'rubs': 'rubs', 'seasoning': 'rubs',
  'pickle': 'pickles', 'pickles': 'pickles', 'preserves': 'pickles', 'ferment': 'pickles',
  'vegan': "veg'n", 'vegetarian': "veg'n", "veg'n": "veg'n", 'plant-based': "veg'n",
};

const LD_CUISINE_MAP = {
  'american': 'US', 'italian': 'IT', 'mexican': 'MX', 'french': 'FR', 'chinese': 'CN',
  'japanese': 'JP', 'indian': 'IN', 'thai': 'TH', 'greek': 'GR', 'spanish': 'ES',
  'german': 'DE', 'korean': 'KR', 'vietnamese': 'VN', 'british': 'GB', 'english': 'GB',
};

function tokenizeLdField(input) {
  if (Array.isArray(input)) return input.flatMap(tokenizeLdField);
  if (typeof input !== 'string') return [];
  return input.toLowerCase().split(/[,/&]+/).map(s => s.trim()).filter(Boolean);
}

// Returns a VALID_COURSES value or null. Only ever called with meta.ldCategory.
function resolveCourseFromLd(ldCategory) {
  for (const token of tokenizeLdField(ldCategory)) {
    if (LD_COURSE_MAP[token]) return LD_COURSE_MAP[token];
  }
  return null;
}

// Returns a two-letter ISO code or null. Only ever called with meta.ldCuisine.
function resolveCuisineFromLd(ldCuisine) {
  for (const token of tokenizeLdField(ldCuisine)) {
    if (LD_CUISINE_MAP[token]) return LD_CUISINE_MAP[token];
    if (/^[a-z]{2}$/.test(token)) return token.toUpperCase();
  }
  return null;
}

const RECIPE_SCHEMA = {
  type: 'object',
  properties: {
    name:       { type: 'string' },
    time:       { type: 'string' },
    serves:     { type: 'string' },
    // enum, not just prose instructions: Ollama's format parameter (v0.3.0+)
    // applies real grammar-based constrained decoding, so this makes it
    // physically impossible for the model to emit a value outside
    // VALID_COURSES/VALID_SUBCATEGORIES -- a stronger guarantee than the
    // post-hoc invalid-course/invalid-subcategory checks below, which still
    // stay in place as a safety net in case a future model/library swap
    // changes how strictly this is enforced. '' stays in the enum so "I
    // couldn't determine one" remains a valid answer rather than forcing a
    // wrong guess into one of the real categories.
    course:     { type: 'string', enum: [...VALID_COURSES, ''] },
    cuisine:    { type: 'string' },
    region:     { type: 'string' },
    glass:      { type: 'string' },
    garnish:    { type: 'array', items: { type: 'string' } },
    subcategory:{ type: 'string', enum: [...VALID_SUBCATEGORIES, ''] },
    ingredients: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name:    { type: 'string' },
          amount:  { type: 'string' },
          unit:    { type: 'string' },
          notes:   { type: 'string' },
          section: { type: 'string' },
        },
        required: ['name', 'amount', 'unit', 'notes', 'section'],
      },
    },
    directions: {
      type: 'array',
      items: { type: 'string' },
    },
    nutrition: {
      type: 'object',
      properties: {
        calories: { type: 'string' },
        carbs:    { type: 'string' },
        fat:      { type: 'string' },
        protein:  { type: 'string' },
      },
    },
  },
  required: ['name', 'time', 'serves', 'course', 'cuisine', 'region', 'glass', 'garnish', 'subcategory', 'ingredients', 'directions'],
};

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

function logError(slug, reason, detail = '') {
  const entry = JSON.stringify({ ts: new Date().toISOString(), slug, reason, detail });
  appendFileSync(ERROR_LOG, entry + '\n');
  console.error(`  SKIP [${reason}]: ${slug}${detail ? ' -- ' + detail : ''}`);
}

let REVIEW_LOG  = `${LOG_DIR}/manual-review.jsonl`;
let TIMING_LOG   = `${LOG_DIR}/line-timings.jsonl`;

// Global counter across the whole run, not per-recipe. The doubanjiang/eggplant/
// yu-xiang-rou-si failures showed no correlation with which line or which recipe
// (identical benign lines failed in different recipes), so the working
// hypothesis is degradation tied to total sequential calls since warmup, not
// content. This logs real timing data to confirm or rule that out on the next run.
let globalLineCallCount = 0;

function logLineTiming(slug, lineIndex, totalLines, elapsedMs, outcome) {
  globalLineCallCount++;
  const entry = JSON.stringify({
    ts: new Date().toISOString(),
    globalCallNumber: globalLineCallCount,
    slug, lineIndex, totalLines, elapsedMs, outcome,
  });
  appendFileSync(TIMING_LOG, entry + '\n');
}

function logForReview(slug, url, reason, line, detail = '') {
  const entry = JSON.stringify({ ts: new Date().toISOString(), slug, url, reason, line, detail });
  appendFileSync(REVIEW_LOG, entry + '\n');
  console.log(`  FLAGGED [${reason}]: ${slug} -- "${line}"`);
}

// A single amount+unit pattern, matched globally against a raw ingredient line.
// Deliberately loose (covers whole/decimal/fraction numbers) since this only
// needs to flag for a human, not classify correctly itself. Unit vocabulary
// is built from the shared COMPOUND_DETECTION_UNIT_WORDS list (same source
// as UnitNormalizer.normalize on the Dart side) rather than a separately
// hand-typed list -- confirmed real gap: the previous hand-typed list only
// had abbreviated units (tbsp, oz, lb), so a line reading "1/2 cup + 4
// tablespoons water, divided" (spelled-out "tablespoons") only ever matched
// one amount+unit pattern ("1/2 cup"), never reached the two-match
// threshold, and silently shipped as clean with the Dart parser's bad split
// ("+ 4 Tablespoons Water" as the ingredient name) never flagged for review.
const UNIT_ALTERNATION = COMPOUND_DETECTION_UNIT_WORDS
  .slice()
  .sort((a, b) => b.length - a.length) // longest-first so e.g. "tablespoons" matches before "t"
  .map(u => u.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
  .join('|');
const AMOUNT_UNIT_PATTERN =
  new RegExp(`\\b\\d+(?:\\.\\d+)?(?:\\/\\d+)?\\s*(${UNIT_ALTERNATION})\\b`, 'gi');

// Deterministic, not model-judged: if a raw ingredient line contains more than
// one standalone amount+unit pattern outside of a parenthetical, it likely
// encodes two separate uses (e.g. "50 g for beans +40g (for fresh peppers)
// salt"), which is exactly the shape of line the model silently dropped data
// on for doubanjiang. Flag it for manual review rather than trusting
// whichever amount the model happens to keep, since a plausible-looking
// wrong result is worse than an honest gap.
//
// A raw count of amount+unit matches over-flags two common single-quantity
// shapes that are NOT compound uses, both confirmed against real corpus
// output:
//   - a unit conversion in parentheses, e.g. "1/2 cup cashews, soaked (75g)*"
//     or "8 oz pasta (224g // any shape you like)" -- the parenthetical
//     amount isn't a second use, just an alternate unit or a note.
//   - a slash- or comma-joined dual/triple-unit value with no parentheses,
//     e.g. "200g/7oz shaved burdock" or "3/4 cup water, 6 oz/180 ml" -- same
//     quantity expressed in multiple units back to back, not two ingredients
//     (confirmed against a real corpus line: 3/4 cup = 6 fl oz = 180ml).
// Matches inside parentheses are excluded before counting, and adjacent
// slash- or comma-joined pairs outside parentheses are collapsed into one,
// so only amounts that represent genuinely separate uses in the line's main
// text still trigger a flag. A bare comma/slash with nothing else between
// two amounts is a safe signal for this -- a real second ingredient on the
// same line always has descriptive text between the amounts, not just a
// separator.
function detectCompoundAmount(line) {
  const matches = [...line.matchAll(AMOUNT_UNIT_PATTERN)];
  if (matches.length < 2) return null;

  const isInsideParens = (index) => {
    let depth = 0;
    for (let i = 0; i < index; i++) {
      if (line[i] === '(') depth++;
      else if (line[i] === ')') depth = Math.max(0, depth - 1);
    }
    return depth > 0;
  };

  const primary = matches.filter(m => !isInsideParens(m.index));
  if (primary.length < 2) return null;

  // Pass 1: collapse bare slash/comma-adjacent pairs (nothing but the
  // separator between them) into one item -- e.g. "6 oz/180 ml". Tracks
  // isCluster so pass 2 can tell a multi-unit conversion apart from a lone
  // amount, which matters for the distinction below.
  let collapsed = [];
  for (let i = 0; i < primary.length; i++) {
    const current = primary[i];
    const next = primary[i + 1];
    if (next) {
      const between = line.slice(current.index + current[0].length, next.index);
      if (/^\s*[,/]\s*$/.test(between)) {
        collapsed.push({
          start: current.index, end: next.index + next[0].length,
          text: current[0] + '/' + next[0], isCluster: true,
        });
        i++; // also skip next: same quantity, already counted once
        continue;
      }
    }
    collapsed.push({ start: current.index, end: current.index + current[0].length, text: current[0], isCluster: false });
  }

  // Pass 2: a leading amount followed by ", <already-collapsed multi-unit
  // cluster>" with no other digits in between is the same shape as
  // "3/4 cup water, 6 oz/180 ml" -- a single quantity restated in further
  // units after a comma, not a second ingredient. Only fires when the
  // following item is a cluster (a real multi-unit conversion signal from
  // pass 1), not a lone amount -- "2 cups flour, 1 cup sugar" must still
  // flag as compound, and nothing here collapses it, since "1 cup" alone
  // isn't a cluster.
  const final = [];
  for (let i = 0; i < collapsed.length; i++) {
    const current = collapsed[i];
    const next = collapsed[i + 1];
    if (next && next.isCluster) {
      const between = line.slice(current.end, next.start);
      if (/^[^\d,]*,\s*$/.test(between)) {
        final.push({ text: current.text + ', ' + next.text });
        i++;
        continue;
      }
    }
    final.push(current);
  }

  return final.length > 1 ? final.map(m => m.text) : null;
}

function sha256(str) {
  return createHash('sha256').update(str, 'utf8').digest('hex');
}

// serves is used for ingredient-scaling in the app, so it must land as a
// bare integer regardless of what the model actually returned -- the prompt
// asks for one, but instruction-following alone isn't trustworthy (the same
// gap that let "breakfast" through past VALID_COURSES). This is a
// deterministic safety net, not a replacement for the prompt instruction.
// A single number extracts cleanly ("6 individual desserts" -> "6"). A range
// ("3-4", "6 to 8 servings") is genuinely ambiguous about which number the
// app should scale from, so it's resolved to the higher number but flagged
// for review rather than silently picked, matching the compound-amount
// philosophy of not guessing invisibly on ambiguous source data.
function normalizeServes(raw) {
  if (!raw || !raw.trim()) return { value: null, ambiguousRange: false };
  const nums = [...raw.matchAll(/\d+/g)].map(m => parseInt(m[0], 10));
  if (nums.length === 0) return { value: null, ambiguousRange: false };
  const uniqueNums = [...new Set(nums)];
  if (uniqueNums.length > 1) {
    return { value: String(Math.max(...uniqueNums)), ambiguousRange: true };
  }
  return { value: String(uniqueNums[0]), ambiguousRange: false };
}

// Ported from url_importer.dart's _parseNutritionValue: strips units from
// strings like "20 g" or "150 kcal", returns the leading numeric value.
function parseNutritionValue(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const match = value.match(/([\d.]+)/);
    if (match) return parseFloat(match[1]);
  }
  return null;
}

// Ported from url_importer.dart's _parseNutrition field mapping (schema.org
// NutritionInformation), narrowed to the four fields Memoix's app schema uses.
function nutritionFromJsonLd(ldNutritionRaw) {
  if (!ldNutritionRaw) return null;
  const calories = parseNutritionValue(ldNutritionRaw.calories);
  const carbs    = parseNutritionValue(ldNutritionRaw.carbohydrateContent);
  const fat      = parseNutritionValue(ldNutritionRaw.fatContent);
  const protein  = parseNutritionValue(ldNutritionRaw.proteinContent);
  if (calories === null && carbs === null && fat === null && protein === null) return null;
  return {
    calories: calories !== null ? String(Math.round(calories)) : '',
    carbs:    carbs    !== null ? String(carbs)    : '',
    fat:      fat      !== null ? String(fat)      : '',
    protein:  protein  !== null ? String(protein)  : '',
  };
}

function parseIngredientString(raw) {
  // Fallback for when the model returns a flat string instead of the required
  // object shape. Deterministic split, not inference: leading amount and unit
  // parsed off the front, text after a comma or semicolon becomes notes.
  const [main, ...rest] = raw.split(/[,;]/);
  const notes = rest.join(',').trim();
  const m = main.trim().match(/^([\d.\/]+)\s*([a-zA-Z]+\.?)?\s+(.+)$/);
  if (m) {
    return {
      name:   m[3].trim(),
      amount: m[1].trim(),
      unit:   m[2] ? m[2].replace(/\.$/, '').trim() : '',
      notes:  notes,
      section: '',
    };
  }
  return { name: main.trim(), amount: '0', unit: '', notes: notes, section: '' };
}

function buildPayload(extracted, meta) {
  const { name, time, serves, course, cuisine, region, glass, garnish, subcategory, ingredients, directions, nutrition } = extracted;
  const nullIfEmpty = s => (s && s.trim() ? s.trim() : null);

  let n = nutrition;
  const ldNutrition = nutritionFromJsonLd(meta.ldNutritionRaw);
  if (ldNutrition) {
    n = ldNutrition;
  } else if (typeof n === 'string') {
    logError(
      meta.slug,
      'nutrition-schema-violation',
      `nutrition returned as bare string "${n}" instead of object, coerced to calories only: ${meta.url}`
    );
    const digits = n.replace(/[^\d.]/g, '');
    n = { calories: digits, carbs: '', fat: '', protein: '' };
  }
  n = n || {};
  const hasNutrition = [n.calories, n.carbs, n.fat, n.protein].some(v => v && v.trim());
  // Matches NutritionInfo.toJson() exactly: a plain object (never an array)
  // with calories/fatContent/carbohydrateContent/proteinContent keys. The
  // pipeline's own internal vocabulary (n.carbs/n.fat/n.protein, matching
  // the LLM prompt) is kept as-is above; only the keys written into the
  // final payload needed to match the real app schema. Previously this was
  // array-wrapped with carbs/fat/protein keys, which either threw on
  // NutritionInfo.fromJson()'s Map cast or silently dropped three of four
  // fields depending on how it was deserialized.
  const builtNutrition = hasNutrition
    ? {
        calories: nullIfEmpty(n.calories),
        carbohydrateContent: nullIfEmpty(n.carbs),
        fatContent: nullIfEmpty(n.fat),
        proteinContent: nullIfEmpty(n.protein),
      }
    : null;

  const coercedCount = ingredients.filter(i => typeof i === 'string').length;
  if (coercedCount > 0) {
    logError(
      meta.slug,
      'ingredient-schema-violation',
      `${coercedCount} ingredient(s) returned as plain strings, coerced via fallback parser: ${meta.url}`
    );
  }

  const normalizedIngredients = ingredients.map(i =>
    typeof i === 'string' ? parseIngredientString(i) : i
  );

  // Region/subcategory: only ever set from a deterministic, page-provided
  // source -- never from the model's own inference, whether from the main
  // extraction call or the blind cuisine classifier. Confirmed necessary,
  // not theoretical: the blind classifier was observed keying off
  // place-names embedded in ingredient names ("Sichuan Lovage Rhizome" ->
  // "Sichuan" on a soup with no other Sichuan-specific ingredients or
  // technique; "Chihuahua cheese" -> "Chihuahua" on a goat birria empanada,
  // a dish more commonly associated with Jalisco) rather than real evidence
  // about the dish's actual origin. For an app aimed at kitchen
  // professionals, a missing region costs nothing; a wrong one sitting next
  // to real ingredient data looks exactly as authoritative as a correct one
  // and actively misleads. No schema.org property or other deterministic
  // page-level region signal exists yet, so this resolves to null for every
  // non-drink recipe until a real one is added -- not a bug, the correct
  // behavior given no trustworthy source currently exists. `region` is
  // still computed upstream (main call, blind call) and left available on
  // `extracted` for a future deterministic mapping, it's just never written
  // into the payload.
  const isDrink = nullIfEmpty(course) === 'drinks';
  const resolvedSubcategory = isDrink ? nullIfEmpty(subcategory) : null;

  const recipe = {
    name:         name.trim(),
    time:         nullIfEmpty(time),
    course:       nullIfEmpty(course),
    rating:       0,
    serves:       nullIfEmpty(serves),
    source:       'scraped',
    cuisine:      nullIfEmpty(cuisine),
    glass:        nullIfEmpty(normalizeGlass(glass)),
    garnish:      Array.isArray(garnish) ? garnish.filter(g => g && g.trim()).map(g => normalizeGarnish(g.trim())) : [],
    subcategory:  resolvedSubcategory,
    comments:     null,
    cookCount:    0,
    nutrition:    builtNutrition,
    directions:   directions.filter(d => d && d.trim()),
    recipeType:   'standard',
    ingredients:  (() => {
      const built = normalizedIngredients
        .filter(i => i.name && i.name.trim())
        .map(i => ({
          name:       cleanName(i.name.trim()),
          unit:       nullIfEmpty(normalizeUnit(i.unit)),
          notes:      nullIfEmpty(i.notes),
          amount:     i.amount && i.amount.trim() ? normalizeFractions(i.amount.trim()) : '0',
          section:    nullIfEmpty(i.section),
          isOptional: false,
        }));
      // A single distinct section across the whole list is redundant labeling
      // (it's just "the ingredients"), so clear it. Only suppress when there is
      // exactly one, since with multiple sections we don't have a safe, general
      // rule for which one counts as the unlabeled "base".
      const distinctSections = new Set(built.map(i => i.section).filter(s => s !== null));
      if (distinctSections.size === 1) {
        built.forEach(i => { i.section = null; });
      }
      return built;
    })(),
    isFavourite:  false,
  };

  const contentStr  = recipe.name + JSON.stringify(recipe.ingredients) + JSON.stringify(recipe.directions);
  const lineageStr  = meta.url + recipe.name;
  recipe.content_hash = sha256(contentStr);
  recipe.lineage_hash = sha256(lineageStr);

  return {
    recipe,
    metadata: {
      appVersion:  'corpus-pipeline',
      buildNumber: '0',
      sourceUrl:   meta.url,
      fetchedAt:   meta.fetchedAt,
    },
    rawSource:     meta.url,
    domainType:    'recipe',
    schemaVersion: SCHEMA_VERSION,
  };
}

// Build hint block from JSON-LD data saved during fetch.
// Used directly for time/yield where present, as context hints otherwise.
function buildLdHints(meta) {
  const hints = [];
  if (meta.ldTime)     hints.push(`Total time (from page data): ${meta.ldTime}`);
  if (meta.ldPrepTime) hints.push(`Prep time (from page data): ${meta.ldPrepTime}`);
  if (meta.ldCookTime) hints.push(`Cook time (from page data): ${meta.ldCookTime}`);
  if (meta.ldYield)    hints.push(`Yield/serves (from page data): ${meta.ldYield}`);
  if (meta.ldCuisine)  hints.push(`Cuisine hint (from page data): ${meta.ldCuisine}`);
  if (meta.ldCategory) hints.push(`Category hint (from page data): ${meta.ldCategory}`);
  if (meta.ldKeywords) hints.push(`Keywords (from page data): ${meta.ldKeywords}`);
  // Site-level hints from urls/site-tags.json, weaker than the page-level
  // JSON-LD hints above since they describe the site in general, not this
  // specific recipe -- a stray off-topic post on an otherwise CN-focused
  // blog should still follow what's actually on the page, not the site tag.
  if (meta.siteRegionHint) {
    hints.push(`Site's general region/cuisine focus (soft default, not authoritative -- prefer what this specific page actually says): ${meta.siteRegionHint}. ` +
      `A general blog with an overall regional focus still posts recipes that genuinely originate elsewhere ` +
      `(e.g. a Japanese-food-focused site posting a Russian-derived Beef Stroganoff, or a fusion/international dish) ` +
      `-- classify by what this specific dish actually is, not by the site's overall identity.`);
  }
  if (meta.siteCourseHint) {
    hints.push(`Site's general course focus (soft default, not authoritative -- prefer what this specific page actually says): ${meta.siteCourseHint}`);
  }
  return hints.length > 0 ? hints.join('\n') : null;
}

// Recipe-plugin markdown (WP Recipe Maker and similar) commonly renders an
// interactive checkbox glyph in front of every ingredient line. This was
// flowing straight through, unstripped, into the Dart parser and out the
// other side as part of the ingredient name (e.g. "[] 3 to 4 Tablespoons
// Oil"). Stripped here, once, before any downstream parsing sees the line --
// not inside the Dart binary, since this is markdown-source noise, not an
// ingredient-parsing decision.
const LEADING_GLYPH_PATTERN = /^[\s\u2610\u2611\u2612\u25a1\u25a2\u25fb\u25fc\u2022\u25e6\u2043\-\*]+/;

// Detects whether a recipe's own name signals it's a dietary adaptation of
// something else (e.g. "Vegan Mushroom Stroganoff") -- used to tell apart two
// cases that both produce an empty extracted.cuisine and would otherwise
// look identical: genuine fusion content with no real origin to find (where
// falling back to the chef/site is the right call, per design), versus an
// adaptation of a dish that DOES have a real origin, which the model simply
// failed to identify despite the adaptation-aware prompt instruction. The
// first case belongs in the chef/site waterfall; the second does not -- the
// site tag is most likely to be wrong exactly when a recipe like this one
// is hosted on a differently-focused site, which is the same reasoning that
// motivated the blind classifier in the first place. Confirmed necessary,
// not theoretical: "Vegan Mushroom Stroganoff" on okonomikitchen.com (a
// Japan-tagged site) came back with an empty cuisine from the blind
// classifier despite the adaptation instruction, and would otherwise have
// silently locked to "JP" via the site fallback.
const DIETARY_ADAPTATION_PATTERN =
  /\b(vegan|vegetarian|gluten-?free|dairy-?free|plant-?based|meatless|keto|paleo|low-?carb)\b/i;

function stripIngredientLineNoise(text) {
  return text.replace(LEADING_GLYPH_PATTERN, '').trim();
}

// Parses the "[Section Name]" bracket convention from site_configs.js output
// (matches url_importer.dart's own line convention) into section-tagged lines.
function expandSectionedLines(lines) {
  const result = [];
  let currentSection = null;
  for (const line of lines) {
    const m = line.match(/^\[(.+)\]$/);
    if (m) {
      currentSection = m[1];
      continue;
    }
    result.push({ section: currentSection, text: line });
  }
  return result;
}

// Given already-isolated, already-correctly-bounded ingredient lines (from a
// site config match or JSON-LD recipeIngredient), ask the model only to split
// each into name/amount/unit/notes. No page context, no narrative text, no
// section-finding task, so the two confirmed failure modes (fabrication from
// prose, dropped sections) have no path to occur here. Schema enforces the
// output array length equals the input length.
const INGREDIENT_LINE_SCHEMA = {
  type: 'object',
  properties: {
    name:   { type: 'string' },
    amount: { type: 'string' },
    unit:   { type: 'string' },
    notes:  { type: 'string' },
  },
  required: ['name', 'amount', 'unit', 'notes'],
};

const INGREDIENT_LINE_SYSTEM_PROMPT =
  'Split this single ingredient line into its parts.\n\n' +
  'name: the ingredient name only.\n' +
  'amount: the number or fraction alone (e.g. "2"), never the unit repeated into it.\n' +
  'unit: a measurement unit only (g, tbsp, cup, piece, clove, etc), never a cut-size or preparation ' +
    'descriptor. Phrases like "cut into 5cm pieces" describe preparation, not a unit, and belong in notes.\n' +
  'notes: any preparation detail, alternative, or qualifier not part of the core name/amount/unit. ' +
    'If there is nothing beyond the name/amount/unit, leave notes as an empty string. ' +
    'Never repeat the name, amount, or unit back into notes.\n' +
  'If the line has no clear amount or unit (e.g. "oyster mushrooms"), leave those fields as empty strings.\n\n' +
  'Example: "1/4 cucumber cut into 5cm pieces" becomes ' +
  '{"name": "cucumber", "amount": "1/4", "unit": "", "notes": "cut into 5cm pieces"}.';

// Deliberately excludes SITE-level context (siteRegionHint, siteCourseHint,
// URL, domain) since those describe the site in general, not this specific
// recipe, and are exactly what biased the model toward "JP" on a Stroganoff
// recipe. PAGE-level structured data (meta.ldCuisine, meta.ldCategory) is
// different: it's the page's own stated claim about this specific recipe,
// not a site-wide generalization, and omitting it was a real regression --
// caught when it flipped a real Chinese recipe (madewithlau, ldCuisine:
// "Chinese") to "SG" purely because the blind call had nothing to work with
// beyond ingredients/directions. Confirmed via the recipe's own .meta.json,
// not assumed. Fixed: ldCuisine/ldCategory are now passed through as the
// page's own claim, explicit about the fact they're unverified and can be
// overridden by clearer evidence in the actual ingredients/directions.
const CUISINE_SCHEMA = {
  type: 'object',
  properties: {
    cuisine: { type: 'string' },
    region:  { type: 'string' },
  },
  required: ['cuisine', 'region'],
};

const CUISINE_SYSTEM_PROMPT =
  'You are classifying the national cuisine of a single recipe from its name, ingredients, directions, and (if ' +
  'given) the page\'s own stated cuisine/category. You are given no information about which website this recipe ' +
  'came from or that site\'s general focus -- classify from this specific recipe\'s own data only.\n\n' +
  '- cuisine: the two-letter ISO 3166-1 alpha-2 country code for the national cuisine this recipe belongs to ' +
    '(e.g. "CN" for Chinese, "FR" for French, "DE" for German, "KR" for Korean, "RU" for Russian). ' +
    'Always a two-letter code, never a full name. If a page-stated cuisine/category is given below, treat it as ' +
    'a real signal from the page itself (not a site-wide generalization) and prefer it unless the recipe\'s own ' +
    'ingredients/directions clearly contradict it. ' +
    'If this recipe is a dietary adaptation of a traditionally-named dish (vegan, vegetarian, gluten-free, dairy-' +
    'free, etc. -- e.g. "Vegan Mushroom Stroganoff", "Gluten-Free Beef Bulgogi"), classify by the origin of the ' +
    'traditional dish being adapted, not by the substituted ingredients actually used. A vegan stroganoff is ' +
    'still Russian in origin even though the beef and sour cream have been replaced. ' +
    'If the recipe is a genuine fusion with no single traditional dish it is adapting, or has no clear national ' +
    'origin and no page-stated cuisine is given, return an empty string rather than guessing.\n' +
  '- region: the specific province, state, city, or sub-regional origin, if identifiable ' +
    '(e.g. "Sichuan", "Tuscany", "Oaxaca"). Give only the place name itself. Leave empty if no sub-regional ' +
    'origin is identifiable.\n\n' +
  'Return only the requested JSON fields.';

async function classifyCuisineBlind(name, ingredients, directions, ldCuisine, ldCategory) {
  const ingredientLines = ingredients
    .map(i => [i.amount, i.unit, i.name].filter(Boolean).join(' '))
    .filter(Boolean)
    .join('\n');
  const pageDataLines = [
    ldCuisine  ? `Page's own stated cuisine: ${ldCuisine}`   : null,
    ldCategory ? `Page's own stated category: ${ldCategory}` : null,
  ].filter(Boolean);
  const pageDataBlock = pageDataLines.length > 0 ? `\n\n${pageDataLines.join('\n')}` : '';
  const userContent =
    `Recipe name: ${name}\n\nIngredients:\n${ingredientLines}\n\nDirections:\n${directions.join('\n')}${pageDataBlock}`;

  const body = {
    model:    MODEL,
    messages: [
      { role: 'system', content: CUISINE_SYSTEM_PROMPT },
      { role: 'user',   content: userContent },
    ],
    format:  CUISINE_SCHEMA,
    stream:  false,
    think:   false,
    options: { num_ctx: NUM_CTX, temperature: TEMPERATURE, num_predict: 150 },
  };

  const res = await fetch(OLLAMA_URL, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify(body),
    signal:  AbortSignal.timeout(INGREDIENT_LINE_TIMEOUT_MS),
  });

  if (!res.ok) throw new Error(`Ollama HTTP ${res.status} (blind cuisine classification)`);

  const json    = await res.json();
  const content = json?.message?.content;
  if (!content) throw new Error('Empty response from Ollama (blind cuisine classification)');

  const parsed = JSON.parse(content);
  return {
    cuisine: (parsed.cuisine ?? '').trim(),
    region:  (parsed.region  ?? '').trim(),
  };
}

async function attemptStructureIngredientLine(line) {
  const body = {
    model:    MODEL,
    messages: [
      { role: 'system', content: INGREDIENT_LINE_SYSTEM_PROMPT },
      { role: 'user',   content: line },
    ],
    format:   INGREDIENT_LINE_SCHEMA,
    stream:   false,
    // Root cause confirmed via logs/empty-content-debug.jsonl (2026-07-10): this
    // model (Qwen3-based) has a reasoning/"thinking" mode, and on this task it
    // was spending its entire token budget on chain-of-thought (visible in the
    // response's "thinking" field, done_reason: "length") and never reaching
    // the actual answer. This explains every failure mode seen across this
    // debugging arc: the original timeouts, the 65k-token "runaway generation"
    // (task 25442, 2026-07-09 server log), and this run's empty-content
    // failures, all the same mechanism, just landing at different points.
    // think: false skips reasoning entirely for a task this trivial. num_predict
    // dropped back down since a real answer is a handful of tokens once
    // reasoning isn't consuming the budget; kept as a safety net, not the fix.
    think:    false,
    options: { num_ctx: NUM_CTX, temperature: TEMPERATURE, num_predict: 150 },
  };

  let res;
  try {
    res = await fetch(OLLAMA_URL, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(body),
      signal:  AbortSignal.timeout(INGREDIENT_LINE_TIMEOUT_MS),
    });
  } catch (e) {
    const err = new Error(`Network/timeout error calling Ollama (ingredient line: "${line}"): ${e.message}`);
    // Timeouts are not retried: server-log evidence from a real hang showed
    // llama-server received no task at all for the full duration, and retrying
    // the identical request reproduced the identical hang three times in a row
    // (doubanjiang, 2026-07-09). Retrying just triples the wall-clock cost for
    // no benefit. Other network errors (e.g. connection refused) may still be
    // transient, so those remain retryable.
    err.retryable = e.name !== 'TimeoutError';
    throw err;
  }

  if (!res.ok) {
    const err = new Error(`Ollama HTTP ${res.status} (ingredient line: "${line}")`);
    err.retryable = true;
    throw err;
  }

  const json    = await res.json();
  const content = json?.message?.content;
  if (!content) {
    // Log the full response, not just the fact that it was empty. done_reason
    // ("length" vs "stop") tells us whether num_predict cut generation off
    // before content was produced, versus some other cause (e.g. a reasoning/
    // thinking field populated instead of content, which some fine-tuned
    // models do). Guessing at a new num_predict value without this would just
    // repeat the same mistake that caused this regression.
    appendFileSync(`${LOG_DIR}/empty-content-debug.jsonl`, JSON.stringify({
      ts: new Date().toISOString(), line, response: json,
    }) + '\n');
    const err = new Error(`Ollama returned empty message content (ingredient line: "${line}")`);
    err.retryable = true;
    throw err;
  }

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (e) {
    mkdirSync('logs/raw-responses', { recursive: true });
    writeFileSync(
      `logs/raw-responses/structuring-failed-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.json`,
      JSON.stringify({ inputLine: line, rawContent: content }, null, 2),
      'utf8'
    );
    // Not retryable: at TEMPERATURE 0 the same malformed output would recur.
    throw new Error(`Ollama returned unparseable JSON for line "${line}": ${e.message}`);
  }

  if (!('name' in parsed) || !('amount' in parsed) || !('unit' in parsed) || !('notes' in parsed)) {
    mkdirSync('logs/raw-responses', { recursive: true });
    writeFileSync(
      `logs/raw-responses/structuring-failed-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.json`,
      JSON.stringify({ inputLine: line, rawContent: content }, null, 2),
      'utf8'
    );
    throw new Error(`Ollama response missing required fields for line "${line}"`);
  }

  return {
    name:   parsed.name   ?? '',
    amount: parsed.amount ?? '',
    unit:   parsed.unit   ?? '',
    notes:  parsed.notes  ?? '',
  };
}

async function structureIngredientLine(line, maxRetries = 2) {
  let lastError;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await attemptStructureIngredientLine(line);
    } catch (e) {
      lastError = e;
      if (!e.retryable || attempt === maxRetries) throw e;
      await sleep(2000 * (attempt + 1));
    }
  }
  throw lastError;
}

async function structureIngredientLines(lines, slug) {
  const results = [];
  for (let i = 0; i < lines.length; i++) {
    const start = Date.now();
    try {
      const result = await structureIngredientLine(lines[i]);
      logLineTiming(slug, i + 1, lines.length, Date.now() - start, 'success');
      results.push(result);
    } catch (e) {
      logLineTiming(slug, i + 1, lines.length, Date.now() - start, 'failed');
      throw new Error(`Line ${i + 1} of ${lines.length} failed: ${e.message}`);
    }
  }
  return results;
}

// Replaces structureIngredientLines above for actual pipeline use (2026-07-10).
// The Ollama per-line path is left in place, unused, as a fallback only if the
// compiled binary itself can't be found or run at all (e.g. not yet compiled
// on a fresh machine) -- not as a fallback for individual line failures, since
// this is deterministic parsing, not model inference; a line either parses or
// it doesn't, retrying identical input against the LLM instead wouldn't be
// more correct, just slower.
//
// One process call per recipe, not per line: batches every ingredient line
// into a single spawn, since Dart's process-startup cost paid 15-20 times per
// recipe would be far more overhead than the deterministic parsing itself.
async function structureIngredientsWithDart(lines) {
  return new Promise((resolve, reject) => {
    const proc = spawn(DART_PARSER_PATH, [], { stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', d => { stdout += d; });
    proc.stderr.on('data', d => { stderr += d; });

    proc.on('error', (e) => {
      // Binary not found / not executable -- this is the one case that falls
      // back to the whole-page ingredients, same as any other structuring failure.
      reject(new Error(`Could not run Dart parser at ${DART_PARSER_PATH}: ${e.message}`));
    });

    proc.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Dart parser exited ${code}: ${stderr.trim()}`));
        return;
      }
      try {
        const parsed = JSON.parse(stdout);
        resolve(parsed.ingredients || []);
      } catch (e) {
        reject(new Error(`Dart parser returned invalid JSON: ${e.message}`));
      }
    });

    proc.stdin.write(JSON.stringify({ ingredientLines: lines }));
    proc.stdin.end();
  });
}

async function extractWithOllama(markdown, meta) {
  // Image markdown lines carry no extraction signal but consume significant
  // character budget (long CDN URLs), and on narrative-heavy posts the actual
  // recipe card sits after most of the images, past the truncation point.
  // Stripping them first recovers real headroom before truncating.
  const withoutImages = markdown.replace(/!\[.*?\]\(.*?\)\n?/g, '');

  // Author-bio boxes ("About {Name}" heading + a paragraph of site/author
  // mission statement) are a common WordPress theme element, not part of the
  // recipe. Confirmed 2026-07-22: this exact pattern on okonomikitchen.com
  // contains site-mission text ("...Japanese cuisine and culture...") that
  // was very likely biasing cuisine/region classification toward "JP" on
  // recipes with nothing Japanese about them (e.g. a vegan mac and cheese).
  // Stripped generally, not just for this one site, since the pattern isn't
  // specific to it.
  // "About Name" may render as a real markdown heading or as plain text --
  // confirmed 2026-07-22 against real fetched content: okonomikitchen.com's
  // author box is a styled <p>, not a semantic heading tag, so it converts to
  // plain text with no # marker at all. Stops at whichever comes first: a
  // horizontal rule (already present in this markdown as a section break), a
  // real heading, or end of content.
  const withoutAuthorBio = withoutImages.replace(
    /^#{0,3}\s*About\s+\w+\s*$[\s\S]*?(?=^\*\s*\*\s*\*\s*$|^#{1,3}\s|(?![\s\S]))/mi,
    ''
  );

  const truncated = withoutAuthorBio.length > MAX_CONTENT_CHARS
    ? withoutAuthorBio.slice(0, MAX_CONTENT_CHARS) + '\n[content truncated]'
    : withoutAuthorBio;

  const ldHints = buildLdHints(meta);

  const systemPrompt =
    'You are a structured data extraction assistant. ' +
    'Extract recipe information from the provided web page content. ' +
    'Return only the requested JSON fields. ' +
    'If a field is not present in the source, return an empty string for string fields or an empty array for array fields. ' +
    'Do not invent information not present in the source.\n\n' +

    'Field rules:\n' +
    '- name: the recipe name. Use the page title if no clearer name is in the content. ' +
      'Many blog titles are written as a narrative sentence or a personal story rather than a dish name -- ' +
      'strip that framing down to the plain dish name. Remove first-person narrative asides, possessive ' +
      'personal references, and hyperbolic claims that are not part of the dish\'s actual name (e.g. ' +
      '"My Dad\'s Made 100,000 Times", "The Best Ever", "You Won\'t Believe How Easy"), while keeping any ' +
      'native-language name in parentheses. For example, "The Ong Choy With Fermented Bean Curd My Dad\'s ' +
      'Made 100,000 Times" should become "Ong Choy With Fermented Bean Curd". ' +
      'If the name contains an alternate or native-language name separated by a dash or colon ' +
      '(e.g. "Mala Dry Hot Pot - Mala Xiang Guo"), reformat it as "Primary Name (Alternate Name)" instead. ' +
      'But if a trailing segment after a dash or pipe is just the site\'s own branding rather than an ' +
      'alternate recipe name (e.g. it matches or resembles the domain in the Source URL below, such as ' +
      '"Herb Crusted Cauliflower Steaks - Okonomi Kitchen" where "Okonomi Kitchen" is the site itself, not ' +
      'another name for the dish), drop that segment entirely rather than reformatting it into parentheses.\n' +
    '- time: total time as a human-readable duration only (e.g. "45 min", "1 hr 30 min"). ' +
      'Strip descriptive words like "total", "approx", or "roughly" even if the source page includes them. ' +
      'Prefer the structured page data hint if provided. If only prep and cook times are available, sum them.\n' +
    '- serves: a single whole number as a string, with no other text (e.g. "4", "6", "12"). ' +
      'The app uses this to scale ingredient amounts, so it must be a bare integer, never a range, a unit, ' +
      'or descriptive words. Convert "serves 6" to "6", "makes 12 pieces" to "12", "6 individual desserts" ' +
      'to "6". For a stated range like "serves 3-4" or "6 to 8 servings", return the higher number ("4", "8"). ' +
      'Prefer the structured page data hint if provided. ' +
      'Do not confuse this with a nutrition "Serving" or "Serving Size" value (e.g. "Serving: 100g"), which ' +
      'states the portion basis for a nutrition breakdown, not the recipe\'s yield. ' +
      'If the only "serving" language on the page is a nutrition serving-size qualifier and no actual yield or ' +
      'serving count is stated for the recipe itself, return an empty string. ' +
      'If no yield or serving count is stated on the page and cannot be clearly derived from the ' +
      'ingredient quantities, return an empty string. Do not default to "1" or any other placeholder value.\n' +
    `- course: classify into exactly one of: ${VALID_COURSES.join(', ')}. ` +
      'If the category hint maps clearly to one of these options, use it, even if the recipe content also ' +
      'suggests a different classification. Only use your own judgment when the hint is absent or ambiguous.\n' +
    '- cuisine: the two-letter ISO 3166-1 alpha-2 country code for the national cuisine this recipe belongs to ' +
      '(e.g. "CN" for Chinese, "FR" for French, "DE" for German, "KR" for Korean). Always a two-letter code, never a full name. ' +
      'If this recipe is a dietary adaptation of a traditionally-named dish (vegan, vegetarian, gluten-free, ' +
      'dairy-free, etc.), classify by the origin of the traditional dish being adapted, not by the substituted ' +
      'ingredients actually used -- a vegan stroganoff is still Russian in origin.\n' +
    '- region: the specific province, state, city, or sub-regional origin, if identifiable ' +
      '(e.g. "Sichuan", "Tuscany", "Oaxaca"). Give only the place name itself, without words like ' +
      '"cuisine", "province", or "style". Leave empty if no sub-regional origin is identifiable.\n' +
    '- glass: for a cocktail or drink recipe only, the specific glass style called for on the page, as the ' +
      'bare style name only -- never include the word "glass" or "glassware" itself (e.g. "Coupe", "Collins", ' +
      '"Rocks", "Nick and Nora", "Highball"). Leave empty for any non-drink recipe, or if the source page does ' +
      'not specify a glass.\n' +
    '- garnish: for a cocktail or drink recipe only, a list of the garnish(es) described on the page, each as ' +
      'a short phrase (e.g. ["Lemon twist"], ["Mint sprig", "Angostura bitters"]). Return an empty array for ' +
      'any non-drink recipe, or if the source page does not specify a garnish.\n' +
    '- subcategory: for a cocktail or drink recipe only, classify into exactly one of: ' +
      `${VALID_SUBCATEGORIES.join(', ')}. ` +
      'Base it on the ingredient present in the largest quantity among the spirits/base liquids listed. ' +
      'Leave empty for any non-drink recipe, or if no single option from that list clearly applies ' +
      '(e.g. an even split between two spirits).\n' +
    '- ingredients: list every ingredient as a separate object with name, amount, unit, notes, and section. ' +
      'Only extract ingredients from an explicit ingredient list on the page (a bulleted or numbered list of ' +
      'quantities, usually near the top of the recipe or under a heading like "Ingredients"). Do not extract ' +
      'ingredients from the directions or narrative text, even if an item is mentioned there. If an item appears ' +
      'only in narrative text and not in an ingredient list, do not add it as an ingredient. Never invent or ' +
      'estimate a quantity for an ingredient; only use amounts stated in the ingredient list itself. ' +
      'Split each ingredient line into its parts rather than leaving the full line as the name. ' +
      'Example: the line "2 tbsp. soy sauce, low sodium preferred" becomes ' +
      '{"name": "soy sauce", "amount": "2", "unit": "tbsp", "notes": "low sodium preferred", "section": ""}. ' +
      'The amount field must be the number or fraction alone (e.g. "2"), never the unit repeated into it (not "2 tbsp"). ' +
      'The unit field is a measurement unit only (g, tbsp, cup, piece, clove, etc), never a cut-size or preparation ' +
      'descriptor. Phrases like "cut into 5cm pieces" or "sliced into rounds" describe preparation, not a unit, ' +
      'and belong in notes, not unit. Example: "1/4 cucumber cut into 5cm pieces" becomes ' +
      '{"name": "cucumber", "amount": "1/4", "unit": "", "notes": "cut into 5cm pieces", "section": ""}. ' +
      'For section: if the ingredient list has subheadings (e.g. "Seasoning:", "Main ingredients", "For the glaze"), ' +
      'use that exact heading text as it appears on the page for section. Do not paraphrase, invent, or generalize ' +
      'a section name that is not literally present as a heading. If there are no subheadings, leave section empty. ' +
      'Never return an ingredient as a plain string. ' +
      'The notes field is for genuinely additional detail (preparation, substitution, qualifier) only. ' +
      'If there is nothing beyond the name/amount/unit to add, leave notes as an empty string. ' +
      'Never repeat the ingredient name, amount, or unit back into notes.\n' +
    '- directions: each step as a separate string in the array, drawn only from step-by-step instruction ' +
      'text that actually appears in the page content below. Exclude photo captions, image labels, and ' +
      'standalone descriptive text that does not describe an action to perform. A caption like "Homemade ' +
      'red oil doubanjiang" describes a photo, not a step, and must not be included even if it appears ' +
      'positioned among the steps. ' +
      'CRITICAL: if the page content contains no actual step-by-step instructions (only an ingredient list, ' +
      'narrative/intro text, or ingredient descriptions with no method), return an empty array. Do NOT generate, ' +
      'infer, or reconstruct plausible-sounding steps from general knowledge of how a similar dish is usually ' +
      'made. Confirmed as a real failure mode: run this exact page twice with no method text present and the ' +
      'model produced two different invented sequences neither one grounded in the source. An empty array is ' +
      'the correct output when there is nothing to extract; inventing steps is never acceptable, regardless ' +
      'of how plausible they would be.\n' +
    '- nutrition: if the page states per-serving nutrition values, return an object with calories, carbs, fat, ' +
      'and protein, each as a plain number string with units stripped (e.g. "181" not "181kcal", "10" not "10g"). ' +
      'The carbs field corresponds to any label reading "Carbohydrate" or "Carbohydrates" on the page, not just "Carbs". ' +
      'Example: {"calories": "181", "carbs": "10", "fat": "14", "protein": "3"}. ' +
      'Never return nutrition as a single number or string. If a specific value is not stated, use an empty ' +
      'string for that value but still return the full object. If no nutrition breakdown is present at all, omit the field.\n\n' +

    'Worked example for cuisine/region: if a page is about Bordeaux wine pairing, cuisine is "FR" and ' +
    'region is "Bordeaux". If a page is about Sichuan peppercorn technique, cuisine is "CN" and ' +
    'region is "Sichuan". The cuisine field is always the national category; the region field holds the ' +
    'specific place name alone, with no descriptive words attached.';

  const ldBlock = ldHints ? `\nStructured page data (use these values directly where applicable):\n${ldHints}\n` : '';

  const userPrompt =
    `Page title: ${meta.title || ''}\n` +
    `Source URL: ${meta.url}\n` +
    ldBlock +
    `\n--- BEGIN CONTENT ---\n${truncated}\n--- END CONTENT ---`;

  const body = {
    model:    MODEL,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user',   content: userPrompt },
    ],
    format:   RECIPE_SCHEMA,
    stream:   false,
    // Same model as the per-line call, which was confirmed burning its token
    // budget on chain-of-thought reasoning instead of answering. This call
    // hasn't shown that symptom directly, but it's the same underlying
    // mechanism, so disabling reasoning here too is preventive, not yet
    // evidence-backed for this specific path.
    think:    false,
    options: {
      num_ctx:     NUM_CTX,
      temperature: TEMPERATURE,
      // Generous cap for a full recipe JSON object, still bounds a runaway
      // generation loop rather than letting it run the full timeout duration.
      num_predict: 3000,
    },
  };

  const res = await fetch(OLLAMA_URL, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify(body),
    // Confirmed against server.log for two real complex-recipe timeouts
    // (beef-wellington: 1699/3000 tokens decoded at ~9.4 t/s average when
    // killed at 180s; a modernist multi-component pie: 1538/3000 at ~8.5
    // t/s) -- both were genuinely still generating, not hung, and needed
    // roughly 320-350s to finish the num_predict budget at this hardware's
    // observed decode speed. 420s gives real margin above that measured
    // worst case rather than a guessed round number.
    signal:  AbortSignal.timeout(420_000),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Ollama HTTP ${res.status}: ${text.slice(0, 200)}`);
  }

  const json    = await res.json();
  const content = json?.message?.content;
  if (!content) throw new Error('Ollama returned empty message content');

  const parsed = JSON.parse(content);

  const rawIngredients = Array.isArray(parsed.ingredients) ? parsed.ingredients : [];
  const nutritionMissing = !parsed.nutrition || typeof parsed.nutrition !== 'object';

  // Diagnostic: if the model returned no ingredients, or returned objects that
  // buildPayload's later filter would drop (blank name), dump the raw response
  // so the failure can be told apart from a genuine source-side absence without
  // needing to re-instrument and re-run. Not a fix, just makes the next run
  // self-diagnosing. Gated on that actual failure condition rather than
  // writing for every recipe -- at 100k-recipe scale, an unconditional dump
  // here was writing 100k+ small files for runs that had nothing wrong.
  const hasBlankNamedIngredient = rawIngredients.some(i => !i || typeof i !== 'object' || !i.name);
  const shouldDumpRaw = rawIngredients.length === 0 || hasBlankNamedIngredient;
  if (shouldDumpRaw) {
    mkdirSync('logs/raw-responses', { recursive: true });
    const debugSlug = meta.slug;
    writeFileSync(
      `logs/raw-responses/${debugSlug}.json`,
      JSON.stringify({ url: meta.url, rawModelOutput: parsed }, null, 2),
      'utf8'
    );
  }
  if (nutritionMissing) {
    mkdirSync('logs/raw-responses', { recursive: true });
    writeFileSync(
      `logs/raw-responses/${meta.slug}-nutrition.json`,
      JSON.stringify({ url: meta.url, rawModelOutput: parsed }, null, 2),
      'utf8'
    );
  }

  return {
    name:        parsed.name        ?? '',
    time:        parsed.time        ?? '',
    serves:      parsed.serves      ?? '',
    course:      parsed.course      ?? '',
    cuisine:     parsed.cuisine     ?? '',
    region:      parsed.region      ?? '',
    glass:       parsed.glass       ?? '',
    garnish:     Array.isArray(parsed.garnish) ? parsed.garnish : [],
    subcategory: parsed.subcategory ?? '',
    ingredients: rawIngredients,
    directions:  Array.isArray(parsed.directions)  ? parsed.directions  : [],
    nutrition:   parsed.nutrition   ?? null,
  };
}

async function warmupOllama() {
  console.log('Warming up Ollama model...');
  try {
    const res = await fetch(OLLAMA_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model:    MODEL,
        messages: [{ role: 'user', content: 'ping' }],
        format:   { type: 'object', properties: { ok: { type: 'string' } }, required: ['ok'] },
        stream:   false,
        options:  { num_ctx: NUM_CTX, temperature: 0 },
        think:    false,
      }),
      // 60s was fine for the 1.1GB sgai model but too short for a cold load
      // of a larger model like the 14B (9GB), which may partially offload to
      // system RAM if it doesn't fit cleanly in VRAM alongside everything
      // else running. This only runs once per script invocation, so the
      // longer ceiling costs nothing on the common case.
      signal: AbortSignal.timeout(300_000),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    console.log('Model ready.');
  } catch (e) {
    console.error(`Ollama warmup failed: ${e.message}`);
    console.error('Make sure Ollama is running and the model is pulled.');
    process.exit(1);
  }
}

async function main() {
  const args     = process.argv.slice(2);
  const limitIdx = args.indexOf('--limit');
  const limit    = limitIdx !== -1 ? parseInt(args[limitIdx + 1], 10) : Infinity;

  // Overrides parsed before warmup, so a --model swap is reflected in the
  // warmup call too, not just the extraction calls that follow it.
  const modelIdx  = args.indexOf('--model');
  if (modelIdx !== -1) MODEL = args[modelIdx + 1];
  const rawDirIdx = args.indexOf('--raw-dir');
  if (rawDirIdx !== -1) RAW_DIR = args[rawDirIdx + 1];
  const outDirIdx = args.indexOf('--out-dir');
  if (outDirIdx !== -1) OUT_DIR = args[outDirIdx + 1];
  const needsReviewDirIdx = args.indexOf('--needs-review-dir');
  if (needsReviewDirIdx !== -1) NEEDS_REVIEW_DIR = args[needsReviewDirIdx + 1];
  const cuisineReviewDirIdx = args.indexOf('--cuisine-review-dir');
  if (cuisineReviewDirIdx !== -1) CUISINE_REVIEW_DIR = args[cuisineReviewDirIdx + 1];
  const logDirIdx = args.indexOf('--log-dir');
  if (logDirIdx !== -1) LOG_DIR = args[logDirIdx + 1];
  // Recompute paths derived from LOG_DIR now that a --log-dir override (if
  // any) has been applied -- these were computed once at module load using
  // the default, so they must be redone here or a --log-dir override would
  // be silently ignored.
  ERROR_LOG  = `${LOG_DIR}/extract-errors.jsonl`;
  REVIEW_LOG = `${LOG_DIR}/manual-review.jsonl`;
  TIMING_LOG = `${LOG_DIR}/line-timings.jsonl`;

  console.log(`Model: ${MODEL}`);
  console.log(`Raw dir: ${RAW_DIR} | Out dir: ${OUT_DIR}`);
  console.log(`Needs-review dir: ${NEEDS_REVIEW_DIR} | Cuisine-review dir: ${CUISINE_REVIEW_DIR} | Log dir: ${LOG_DIR}`);
  if (NEEDS_REVIEW_DIR === 'needs-review' && OUT_DIR !== 'extracted') {
    console.warn('WARNING: --out-dir is overridden but needs-review/cuisine-review/logs are not. ' +
      'Any recipe flagged in this run will be treated as already processed by a later real-corpus run. ' +
      'Pass --needs-review-dir/--cuisine-review-dir/--log-dir for an isolated test run.');
  }

  await warmupOllama();

  mkdirSync(OUT_DIR, { recursive: true });
  mkdirSync(NEEDS_REVIEW_DIR, { recursive: true });
  mkdirSync(CUISINE_REVIEW_DIR, { recursive: true });
  mkdirSync(LOG_DIR, { recursive: true });

  const mdFiles = readdirSync(RAW_DIR)
    .filter(f => f.endsWith('.md'))
    .sort();

  console.log(`Markdown files in raw/: ${mdFiles.length}`);

  let processed = 0, skipped = 0, failed = 0;
  let cleanCount = 0, needsReviewCount = 0, cuisineReviewCount = 0;

  for (const mdFile of mdFiles) {
    if (processed >= limit) break;

    const slug              = mdFile.replace('.md', '');
    const outPath            = `${OUT_DIR}/${slug}.json`;
    const needsReviewPath    = `${NEEDS_REVIEW_DIR}/${slug}.json`;
    const cuisineReviewPath  = `${CUISINE_REVIEW_DIR}/${slug}.json`;
    const metaPath           = `${RAW_DIR}/${slug}.meta.json`;

    // Output can land in any of the three folders now, so resumability has
    // to check all of them -- otherwise a recipe already sitting in
    // needs-review/ or cuisine-review/ would get silently reprocessed and
    // duplicated into a different folder on the next run.
    if (existsSync(outPath) || existsSync(needsReviewPath) || existsSync(cuisineReviewPath)) {
      skipped++;
      continue;
    }

    if (!existsSync(metaPath)) {
      logError(slug, 'missing-meta', 'No .meta.json found alongside .md file');
      failed++;
      continue;
    }

    const markdown = readFileSync(`${RAW_DIR}/${mdFile}`, 'utf8');
    const meta     = JSON.parse(readFileSync(metaPath, 'utf8'));

    console.log(`Extracting [${processed + 1}]: ${meta.url}`);

    // Set at each logForReview() call below -- anything flagged this way is
    // an extraction-completeness concern, so the whole recipe routes to
    // NEEDS_REVIEW_DIR rather than shipping partially-trusted data into the
    // clean corpus.
    let flaggedForReview = false;

    // Deterministic, name/content-based scope gate: pizza and sandwich
    // content are explicitly out of scope per VALID_COURSES' own comment
    // (separate domainTypes with their own schemas, not yet built here).
    // Nothing previously enforced that -- a pizza recipe would silently
    // fall through to whatever course the model picked (observed: "mains")
    // and ship as a standard recipe. Routed to needs-review instead of
    // guessed at, same as every other domain-fit question in this pipeline.
    //
    // Checked as separate fields, not one joined blob: a false positive
    // (starchefs-electric-jellyfish-ipa, a beer recipe, tripped this on
    // its first run) is undebuggable if the log entry can't say which
    // field matched or what text actually triggered it -- the original
    // version logged the literal string 'pizza' regardless of cause.
    //
    // meta.title commonly appends a byline/attribution after a "|"
    // separator, and the byline can name an unrelated business -- confirmed
    // real: "StarChefs - Electric Jellyfish IPA | Brewer Joe Mohrfeld of
    // Pinthouse Pizza" matched on the brewer's restaurant affiliation, not
    // the dish, which is an IPA. Stripping everything from the first "|"
    // onward before checking removes that false positive. Confirmed this
    // doesn't lose the one real positive seen so far either: "Pizza with
    // blue cheese and pineapple – Khymos" has no "|" at all, so the strip
    // is a no-op there and the dish name still matches.
    const PIZZA_PATTERN = /\bpizzas?\b/i;
    const stripByline = (s) => (s ? s.split('|')[0] : s);
    const scopeCheckFields = [
      ['title', stripByline(meta.title)],
      ['ldName', stripByline(meta.ldName)],
      ['url', meta.url],
    ];
    const pizzaMatch = scopeCheckFields.find(([, value]) => value && PIZZA_PATTERN.test(value));
    if (pizzaMatch) {
      const [matchedField, matchedValue] = pizzaMatch;
      logForReview(slug, meta.url, 'unsupported-domain-type', matchedValue,
        `Matched "pizza" in meta.${matchedField}. Pizza is a separate domainType with its own ` +
        'schema, not yet built in this pipeline -- quarantined rather than shipped as a standard recipe.');
      flaggedForReview = true;
    }

    try {
      const extracted = await extractWithOllama(markdown, meta);

      if (!extracted.name || extracted.name.trim() === '') {
        if (meta.title && meta.title.trim()) {
          extracted.name = meta.title.trim();
        } else {
          logError(slug, 'no-name', 'Extracted recipe has no name and page has no title');
          failed++;
          continue;
        }
      }

      // Unlike course, there's no fixed list to validate a cleaned-up name
      // against -- whether the model actually stripped narrative blog-title
      // framing is a judgment call, not a lookup. This is a soft heuristic,
      // not a hard rule: a long name is a plausible signal the model kept
      // narrative framing instead of a plain dish name, worth a human
      // glance, but length alone doesn't prove it (some real dish names are
      // legitimately long, especially with a native-language parenthetical).
      const NAME_LENGTH_REVIEW_THRESHOLD = 70;
      if (extracted.name.trim().length > NAME_LENGTH_REVIEW_THRESHOLD) {
        logForReview(slug, meta.url, 'long-name', extracted.name,
          `Name is ${extracted.name.trim().length} chars -- check it isn't still a narrative blog title rather than a plain dish name.`);
        flaggedForReview = true;
      }

      // Deterministic override: if the page itself states a category that
      // maps unambiguously, that beats whatever the model guessed -- no
      // instruction-following risk, and it's guaranteed to already be a
      // valid VALID_COURSES value by construction, so the check below
      // can't fire a false invalid-course flag on it.
      const ldCourse = resolveCourseFromLd(meta.ldCategory);
      if (ldCourse) {
        extracted.course = ldCourse;
      }

      // course is a hard-set enum in the app's domain model, not a free-text
      // field -- VALID_COURSES was previously only ever interpolated into the
      // prompt, never checked against what the model actually returned, so
      // an instruction-following miss (e.g. "breakfast" instead of "brunch")
      // shipped straight into the corpus with no signal. Enforced here: an
      // empty course is fine (means the model couldn't determine one), but
      // a non-empty value outside VALID_COURSES is never silently coerced or
      // dropped -- it's flagged so a human decides the right mapping.
      if (extracted.course && extracted.course.trim()
          && !VALID_COURSES.includes(extracted.course.trim().toLowerCase())) {
        logForReview(slug, meta.url, 'invalid-course', extracted.course,
          `Model returned "${extracted.course}", which is not in VALID_COURSES.`);
        flaggedForReview = true;
      }

      // Same enforcement as course, one level down: subcategory is only
      // meaningful for drinks, but when the model does return one it must
      // match VALID_SUBCATEGORIES. A case-insensitive match is canonicalized
      // to the app's Title Case convention rather than trusting whatever
      // casing the model produced; a genuine non-match is flagged, not
      // coerced or dropped.
      if (extracted.subcategory && extracted.subcategory.trim()) {
        const subcategoryMatch = VALID_SUBCATEGORIES.find(
          v => v.toLowerCase() === extracted.subcategory.trim().toLowerCase()
        );
        if (subcategoryMatch) {
          extracted.subcategory = subcategoryMatch;
        } else {
          logForReview(slug, meta.url, 'invalid-subcategory', extracted.subcategory,
            `Model returned "${extracted.subcategory}", which is not in VALID_SUBCATEGORIES.`);
          flaggedForReview = true;
        }
      }

      const servesRaw = extracted.serves;
      const { value: servesNormalized, ambiguousRange } = normalizeServes(servesRaw);
      extracted.serves = servesNormalized ?? '';
      if (ambiguousRange) {
        logForReview(slug, meta.url, 'serves-range', servesRaw,
          `Resolved to "${servesNormalized}" (higher end of the range) -- confirm this is the intended yield.`);
        flaggedForReview = true;
      } else if (servesRaw && servesRaw.trim() && !servesNormalized) {
        // Model returned non-empty text with no extractable number at all
        // (e.g. "a crowd") -- can't normalize this deterministically.
        logForReview(slug, meta.url, 'serves-unparseable', servesRaw,
          'Could not extract a whole number from the model\'s serves value.');
        flaggedForReview = true;
      }

      // Prefer a deterministic ingredient source over whatever the whole-page
      // call produced. Site-config HTML extraction (with real section headers)
      // takes priority over flat JSON-LD recipeIngredient (no sections), which
      // takes priority over the model's own whole-page ingredient guess.
      const detSectionedRaw = meta.htmlIngredientLines && meta.htmlIngredientLines.length > 0
        ? expandSectionedLines(meta.htmlIngredientLines)
        : (meta.ldIngredientsRaw && meta.ldIngredientsRaw.length > 0
            ? meta.ldIngredientsRaw.map(text => ({ section: null, text }))
            : null);
      const detSectioned = detSectionedRaw
        ? detSectionedRaw.map(l => ({ ...l, text: stripIngredientLineNoise(l.text) }))
        : null;

      if (detSectioned && detSectioned.length > 0) {
        for (const { text } of detSectioned) {
          const matches = detectCompoundAmount(text);
          if (matches) {
            logForReview(slug, meta.url, 'compound-amount-detected', text,
              `Multiple amount+unit patterns found (${matches.join(', ')}); model may drop one silently.`);
            flaggedForReview = true;
          }
        }

        try {
          const structured = await structureIngredientsWithDart(detSectioned.map(l => l.text));
          extracted.ingredients = structured.map((item, i) => {
            if (item.error) {
              logForReview(slug, meta.url, 'dart-parse-error', detSectioned[i].text, item.error);
              flaggedForReview = true;
              return { name: '', amount: '', unit: '', notes: '', section: detSectioned[i].section };
            }
            // Corpus schema uses a single 'notes' field; the app's own Ingredient
            // model splits this into 'preparation' (e.g. "minced") and
            // 'alternative' (e.g. "OR maple syrup" substitutions). Neither
            // alone is a clean fit for lines that are really just a free-form
            // note ("adjust spice level to taste"), so both are joined here
            // rather than picking one -- alternative gets an explicit "alt:"
            // label so it reads as a substitution, not another prep note.
            const notes = [item.preparation, item.alternative ? `alt: ${item.alternative}` : null]
              .filter(Boolean).join('; ');
            return {
              name:    item.name   ?? '',
              amount:  item.amount ?? '',
              unit:    item.unit   ?? '',
              notes,
              section: detSectioned[i].section,
            };
          });
        } catch (e) {
          logError(slug, 'ingredient-structuring-failed',
            `Falling back to whole-page ingredients: ${e.message}`);
          // extracted.ingredients keeps whatever the whole-page call produced.
          flaggedForReview = true;
        }
      }

      if (extracted.ingredients.length === 0 && extracted.directions.length === 0) {
        logError(slug, 'empty-content', 'No ingredients or directions extracted');
        failed++;
        continue;
      }

      if (extracted.ingredients.length > 0 && extracted.directions.length === 0) {
        // Not a hard failure: real recipe content exists, the source page
        // just has no actual step-by-step method text (confirmed on the mac
        // and cheese recipe, 2026-07-22, where directions were previously
        // fabricated rather than left empty). Flagged so it surfaces for
        // manual attention instead of silently shipping with no directions.
        logForReview(slug, meta.url, 'no-directions-found',
          '(whole recipe)', 'Ingredients present but no method/directions text found in source content.');
        flaggedForReview = true;
      }

      // Deterministic override first: if the page itself states an
      // unambiguous cuisine, that's a stronger, free, per-recipe signal --
      // lock it and skip the blind Ollama call entirely for this recipe.
      // Falls through to the blind check below when ldCuisine is absent or
      // too broad to map confidently (e.g. "Mediterranean").
      const ldCuisine = resolveCuisineFromLd(meta.ldCuisine);
      if (ldCuisine) {
        extracted.cuisine = ldCuisine;
      } else if (meta.siteRegionHint) {
        // Only worth the extra call when there's a hint that could have
        // biased the main call's cuisine field in the first place -- an
        // unhinted site has nothing for the model to lean on, so there's no
        // bias risk to check.
        try {
          const blind = await classifyCuisineBlind(
            extracted.name, extracted.ingredients, extracted.directions,
            meta.ldCuisine, meta.ldCategory
          );
          // The blind result becomes authoritative -- it was never shown the
          // SITE-level hint, so it can't be biased by that. It was shown the
          // page's own ldCuisine/ldCategory, which is a real per-recipe
          // signal, not the same failure mode.
          extracted.cuisine = blind.cuisine;
          extracted.region  = blind.region;
        } catch (e) {
          // Don't fail the whole recipe over this -- fall back to the
          // hint-informed cuisine/region already in extracted, but flag it
          // so a silent fallback to the potentially-biased value isn't
          // invisible.
          logForReview(slug, meta.url, 'cuisine-blind-check-failed', extracted.cuisine,
            `Blind cuisine re-classification failed (${e.message}); kept the hint-informed value.`);
          flaggedForReview = true;
        }
      }

      // Site fallback only, no chef tier -- classifyChefCuisine was removed
      // after two confirmed-wrong results (Noma Projects, David Lebovitz).
      // Checked against the cleaned extracted.name, the raw meta.title/
      // meta.ldName, AND meta.url -- the name-cleanup step earlier in the
      // pipeline is allowed to rewrite extracted.name and nothing
      // guarantees a dietary modifier survives that rewrite, and confirmed
      // against a real case (okonomikitchen's vegan cereal) that the word
      // can be missing from title/ldName too and only survive in the URL
      // slug itself ("diy-3-ingredient-healthy-vegan-cereal"). ALSO treats
      // a site tagged siteCourseHint "veg'n" as an adaptation signal on its
      // own, regardless of what any single recipe's title says -- a
      // dedicated vegan blog's own posts don't always restate "vegan" in
      // every title since it's implied by the site itself, and this site
      // has repeatedly shown that exact pattern across this corpus.
      const looksLikeUnresolvedAdaptation =
        !extracted.cuisine && (
          DIETARY_ADAPTATION_PATTERN.test(
            [extracted.name, meta.title, meta.ldName, meta.url].filter(Boolean).join(' ')
          )
          || (meta.siteCourseHint && meta.siteCourseHint.trim().toLowerCase() === "veg'n")
        );

      if (!extracted.cuisine && !looksLikeUnresolvedAdaptation) {
        if (meta.siteRegionHint) {
          extracted.cuisine = meta.siteRegionHint;
          logForReview(slug, meta.url, 'cuisine-from-site-fallback', meta.siteRegionHint,
            'No cuisine from recipe content; resolved from the site\'s general region tag.');
        }
      } else if (looksLikeUnresolvedAdaptation) {
        logForReview(slug, meta.url, 'adapted-dish-cuisine-unresolved', extracted.name,
          'Name suggests a dietary adaptation of a traditionally-named dish, but no origin could be determined ' +
          'from the recipe content -- needs a human (or a targeted lookup) rather than a chef/site guess, since ' +
          'a real origin likely exists.');
        flaggedForReview = true;
      }

      const payload = buildPayload(extracted, meta);

      // course and cuisine are the two fields the app's search/discovery
      // depends on -- a recipe with either null isn't just incomplete, it's
      // invisible to a user browsing by cuisine or course. Previously an
      // empty value here shipped silently into extracted/ with no signal at
      // all; now it's quarantined into needs-review like any other
      // completeness failure, so nothing un-searchable reaches the clean
      // corpus without a human decision.
      if (!payload.recipe.course || !payload.recipe.cuisine) {
        const missing = [!payload.recipe.course && 'course', !payload.recipe.cuisine && 'cuisine']
          .filter(Boolean).join(' and ');
        logForReview(slug, meta.url, 'not-searchable', missing,
          `Recipe has no ${missing} -- would not be discoverable by that field in the app.`);
        flaggedForReview = true;
      }

      // Cuisine-review is a separate question from extraction completeness:
      // "does this content belong on this site at all," not "did we get it
      // correctly." Only fires when both the site tag and the model's own
      // cuisine call are present and disagree -- a site with no region tag,
      // or a recipe where cuisine came back empty, has nothing to compare.
      const cuisineMismatch = meta.siteRegionHint
        && payload.recipe.cuisine
        && meta.siteRegionHint.trim().toLowerCase() !== payload.recipe.cuisine.trim().toLowerCase();

      let destPath;
      if (flaggedForReview) {
        destPath = needsReviewPath;
        needsReviewCount++;
      } else if (cuisineMismatch) {
        destPath = cuisineReviewPath;
        cuisineReviewCount++;
        console.log(`  CUISINE-REVIEW: ${slug} -- site tagged "${meta.siteRegionHint}", recipe classified "${payload.recipe.cuisine}"`);
      } else {
        destPath = outPath;
        cleanCount++;
      }

      writeFileSync(destPath, JSON.stringify(payload, null, 2), 'utf8');
      processed++;

      await sleep(200);
    } catch (e) {
      logError(slug, 'extract-error', e.message);
      failed++;
      await sleep(500);
    }
  }

  console.log(`\nDone. Extracted: ${processed} (clean: ${cleanCount}, needs-review: ${needsReviewCount}, cuisine-review: ${cuisineReviewCount}), already had: ${skipped}, failed: ${failed}`);
  if (failed > 0) console.log(`Failures logged to ${ERROR_LOG}`);
}

main().catch(e => { console.error(e.message); process.exit(1); });
