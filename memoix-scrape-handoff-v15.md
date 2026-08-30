# Memoix Scrape Handoff v15

## Branch

Continues from v14 (deterministic Dart ingredient parser, review-folder
architecture, file-based site ingestion). This session was entirely about
hardening `03_extract.js` before committing a week-plus of unattended
runtime to the full ~100,000-recipe, 76-site corpus. **Phase 3 has still not
been run at full scale.** All work below was validated through a series of
progressively larger test batches (`--raw-dir`/`--out-dir` overrides), the
largest being 161 files. No batch has yet covered the full site list.

The throughline of this session: nearly every test batch surfaced at least
one new, real, previously-unseen issue. That pattern held up through the
very last batch. Treat that as a standing expectation for the next session,
not a sign that testing has been exhausted.

---

## Files changed this session

`03_extract.js` (extensively — see below). New: `04_cluster_review.js`
(aggregates `manual-review.jsonl` for triage). A third file,
`normalize_metadata.js`, was proposed externally, evaluated, had its useful
ideas absorbed directly into `03_extract.js`, and was then deleted as
redundant — nothing depends on it.

---

## Completed This Session

### 1. Compound-amount detection — rebuilt, not just tuned

The original detector was a raw count of amount+unit regex matches on a
line: 2+ matches meant "flag it." This over-flagged two common,
non-compound shapes, confirmed against real corpus lines:

- A unit conversion in parentheses: `"1/2 cup cashews, soaked (75g)*"`,
  `"8 oz pasta (224g // any shape you like)"`.
- A slash- or comma-joined dual/triple-unit value with no parens at all:
  `"200g/7oz shaved burdock"`, `"240 ml / 1 cup non dairy milk"`,
  `"3/4 cup water, 6 oz/180 ml"`.

Rebuilt `detectCompoundAmount()` in two passes: (1) exclude matches inside
parentheses from the "primary" count, and collapse adjacent primary matches
joined only by `/` or `,` into one; (2) additionally collapse a leading
amount into an already-collapsed multi-unit cluster that follows it after a
comma with no other digits in between (the `3/4 cup water, 6 oz/180 ml`
shape, where real ingredient-name text sits between the first amount and the
comma).

Verified against 12 real lines spanning every false-positive and
true-positive case surfaced this session, including confirming a
comma-separated *genuine two-ingredient* line (`"2 cups flour, 1 cup
sugar"`) still correctly flags — the fix does not over-collapse.

Still correctly flags, unresolved by design (needs human judgment, not a
guess): ambiguous ranges (`"800 g to 1000g fresh pepper"`), genuine
multi-use lines (`"50 g for beans +40g (for fresh peppers) salt"`), and a
recurring sourdough "reserve some water for later" pattern (3 hits on
`theperfectloaf.com` alone in the 161-file batch — common enough that a
dedicated rule might be worth it once real `needs-review` volume confirms
the frequency, but not built yet).

### 2. Checkbox/bullet glyph stripping

WP-Recipe-Maker-style checkbox glyphs (▢ etc.) and other leading bullet/dash
characters were flowing straight from source markdown into the ingredient
`name` field unstripped. `stripIngredientLineNoise()` /
`LEADING_GLYPH_PATTERN` now strip these before any downstream parsing sees
the line.

### 3. `course` and `subcategory` — real enum enforcement, not just a flag

`VALID_COURSES` was previously only ever pasted into the prompt as text,
never checked against what the model actually returned — this is how
`"breakfast"` shipped through instead of `"brunch"` in an earlier test.
Fixed in two layers:

- **Real constrained decoding**: confirmed against current Ollama docs that
  the `format` parameter (v0.3.0+) supports true grammar-based constrained
  decoding via standard JSON Schema, including `enum`. `course` and
  `subcategory` now have `enum: [...VALID_COURSES, '']` /
  `[...VALID_SUBCATEGORIES, '']` in `RECIPE_SCHEMA` — the model is
  *physically incapable* of emitting an out-of-list value. `''` is kept in
  the enum so "couldn't determine one" stays a valid answer instead of
  forcing a wrong guess.
- **Post-hoc validation retained as a safety net** (`invalid-course`,
  `invalid-subcategory` flags) in case a future model/library swap changes
  how strictly the enum is enforced.

`VALID_SUBCATEGORIES` (drinks' base spirit) is a confirmed 13-value enum
from the app's own spirit color constants: `Gin, Vodka, Whiskey, Rum,
Tequila, Brandy, Wine, Sparkling, Liqueur, Beer, Tea, Coffee, Mocktail`.

### 4. Deterministic pre-resolution from page-level structured data

`LD_COURSE_MAP` / `LD_CUISINE_MAP` + `resolveCourseFromLd()` /
`resolveCuisineFromLd()`: resolve `course`/`cuisine` directly from
`meta.ldCategory`/`meta.ldCuisine` when they map unambiguously, skipping the
model (and, for cuisine, skipping the blind-check call below) entirely.

Absorbed from an externally-proposed `normalize_metadata.js` after finding
and fixing two real bugs in it before merging:

- `'mediterranean': 'GR'` and `'caribbean': 'JM'` were **removed**, not
  adopted — both span several genuinely different national cuisines, and
  collapsing either to one country would inject a confident, specific wrong
  answer rather than an honest gap. These now correctly fall through to
  `null` instead.
- The original proposal used `siteCourseHint`/`siteRegionHint` (site-wide
  tags) as a locking/authoritative fallback source. **This was not
  adopted** — locking from a site-wide tag reintroduces exactly the
  per-recipe bias risk the blind cuisine check (below) exists to prevent.
  Site-level hints remain soft signals only; only page-level
  `ldCategory`/`ldCuisine` can lock a value deterministically.

`course`'s LD-lock runs *before* the `VALID_COURSES` enum check, so a locked
value (guaranteed valid by construction) can never trip its own validator.

### 5. `serves` normalization

Prompt now asks for a bare integer (higher end of any stated range), not
free text like `"serves 6"`. A deterministic `normalizeServes()` regex
fallback doesn't trust model compliance alone: extracts the number
regardless of phrasing; a genuine range (`"3-4"`) resolves to the higher
number *and* gets flagged (`serves-range`) rather than silently guessed;
text with no extractable number at all is flagged (`serves-unparseable`).

### 6. Glassware/garnish/subcategory — corrected against the real app schema

Original implementation guessed field names/shapes (`glassware` as a
string, `garnish` as a string). Corrected against the app's actual exported
recipe JSON:

- `glass` (string), not `glassware`.
- `garnish` is an **array of strings**, not a single string.
- Added `subcategory` (see enum above).

**Still open**: the app's real per-ingredient schema has `preparation` /
`alternative` / `isOptional` / `bakerPercent` / `uuid` as distinct fields.
The pipeline's ingredient objects are still the flatter `{name, amount,
unit, notes, section}`. The Dart parser's own `alternative`/`preparation`
split is currently merged into the single `notes` field, with the
`alternative` portion explicitly labeled `alt: ...` per direct request (see
below) — but this is a labeling fix inside a flattened field, not a
structural schema match. Confirm before the real run whether this
flattening is acceptable for however the corpus gets imported later, or
whether the split needs to be preserved as separate output fields.

### 7. Name field cleanup

Added an explicit prompt rule, anchored on a real corpus example: `"The Ong
Choy With Fermented Bean Curd My Dad's Made 100,000 Times (腐乳炒蕹菜)"`
should become `"Ong Choy With Fermented Bean Curd (腐乳炒蕹菜)"` — strip
narrative/personal/hyperbolic blog-title framing, keep any native-language
parenthetical.

Added a soft heuristic safety net alongside it: any final name over 70
characters gets flagged (`long-name`) for a human glance, since there's no
fixed list to validate a cleaned name against the way there is for course.
**Confirmed via the 161-file batch that this produces a lot of expected,
harmless noise** on real fine-dining/professional multi-component dish
names (`thestaffcanteen.com`, `greatbritishchefs.com`) — not a defect, just
something to skim past quickly during review, not something worth tightening.

**Never independently confirmed**: whether the Ong Choy recipe's actual
final `name` field came out clean in a real output JSON. It only ever
surfaced via a `cuisine-review` flag, which doesn't touch the name field at
all. Check this directly before trusting the fix fully.

### 8. Cuisine classification — the largest area of work this session

**The core structural problem**: the original design fed the same
site-level region hint into the same combined extraction call that also
produced the final `cuisine` value, so a biased model could launder site
identity straight into the output with zero signal. Confirmed on a real
case: `okonomikitchen.com` (site-tagged `"JP"`) initially classified a
Vegan Mushroom Stroganoff recipe as Japanese.

Built, in this order, with real regressions caught and fixed along the way:

1. **Blind cuisine reclassification** (`classifyCuisineBlind`): a separate,
   smaller Ollama call, run only when `meta.siteRegionHint` exists (skips
   the cost when there's no bias risk). Given name/ingredients/directions,
   explicitly *not* the site-level hint or URL. Its result is authoritative
   for `cuisine`/`region`, not a tiebreaker.
   - **Regression, found and fixed**: the first version was too blind — it
     also excluded the page's *own* stated `ldCuisine`/`ldCategory`, a
     different trust level than the site-wide hint (this page's own claim
     vs. the site's general identity). This flipped a genuinely Chinese
     recipe (`madewithlau.com`, `ldCuisine: "Chinese"`) to `"SG"` purely
     because the blind call had nothing to work with. Fixed: `ldCuisine`/
     `ldCategory` are now passed into the blind call as "the page's own
     stated data, prefer it unless content contradicts it," while
     `siteRegionHint`/URL/domain remain excluded.
2. **LD-lock takes priority over the blind call** — see item 4 above; skips
   the blind call entirely when `ldCuisine` maps unambiguously.
3. **Dietary-adaptation rule**: added to both cuisine prompts (main call
   and blind call) — a dietary adaptation of a named classic dish should be
   classified by the traditional dish's origin, not the substituted
   ingredients (a vegan stroganoff is still Russian). Prompt-only, and
   **not reliably followed** — see item 4 below, built specifically because
   this instruction alone didn't hold up.
4. **`adapted-dish-cuisine-unresolved` gate**: catches cases where the
   model still returns an empty cuisine *despite* the adaptation
   instruction — meaning a real origin almost certainly exists but the
   model missed it. Detected deterministically via
   `DIETARY_ADAPTATION_PATTERN` (vegan/vegetarian/gluten-free/dairy-free/
   plant-based/meatless/keto/paleo/low-carb), checked against
   `extracted.name` **and** `meta.title`/`meta.ldName`/`meta.url` — broadened
   twice after two real misses (name-cleanup can strip the modifier from
   the cleaned name; at least one real recipe only had "vegan" in the URL
   slug, nowhere else) — **and** `meta.siteCourseHint === "veg'n"` (a
   whole-site vegan focus catches titles that never restate "vegan" at all
   because it's implied site-wide, e.g. repeatedly observed on
   `okonomikitchen.com`). When this fires, the recipe is quarantined to
   `needs-review` rather than falling through to any fallback, since a
   fallback guess would likely be wrong for exactly this category.
5. **Chef → site cuisine waterfall — built, then removed.** For genuinely
   fusion/technique-driven content not caught by the adaptation gate, a
   `classifyChefCuisine(meta.byline)` call was added, falling back to
   `meta.siteRegionHint` if that failed too, per the person's own stated
   design (chef's origin, then site's origin, for true fusion content).
   **Removed after two real, confirmed-wrong results**: Noma Projects
   (`siteRegionHint: "DK"`) came back `"DE"` from the chef tier — not a
   plausible near-miss. David Lebovitz (American writer, French-pastry
   content, `siteRegionHint: "FR"`) came back `"US"` — a chef's nationality
   and the cuisine they actually cook turned out to be different things,
   and the tier only ever asked for nationality. Site-fallback alone would
   have gotten both right. **`classifyChefCuisine` and its prompt/schema
   were deleted, confirmed via grep to have no remaining references.**
   **Current cuisine waterfall, final state**: content → LD data → blind
   check (with page data) → adaptation gate → site-fallback. No chef-based
   tier exists.
6. **`not-searchable` quarantine**: any recipe whose final payload has a
   null `course` OR null `cuisine` is flagged and routed to `needs-review`
   — previously this shipped completely silently into `extracted/`. This
   was an explicit decision given the app's core purpose is search/
   discovery by these exact fields. Expect this to meaningfully increase
   `needs-review` volume relative to earlier batches — that's the intended
   trade (visible gaps beat invisible ones), not a regression.

**Still open**: no enum/validity check exists for `cuisine` itself (unlike
course/subcategory) — nothing stops a stray non-ISO value from slipping
through unflagged. Never observed in practice, never actively guarded
against either. `subcategory` similarly has no blind-reclassification or
LD-lock equivalent — it relies entirely on the main call's enum-constrained
judgment, and hasn't been stress-tested against any real volume of drink
recipes.

### 9. Timeout fix (separate from all cuisine work)

Main extraction call's timeout was 180s. Confirmed via the actual Ollama
server log (not guessed) that two large multi-section recipes (a Beef
Wellington with 4 sub-components/22 steps, a modernist pie) were killed by
the timeout while genuinely still decoding at ~9 tokens/sec — not hung,
just needed ~320-350s to finish at that measured rate. Raised to 420s with
real margin above the measured worst case. **Confirmed fixed**: both
recipes completed on retest.

A separate, unrelated `fetch failed` (connection-level, not a timeout) was
also observed a handful of times across the 161-file batch (~2.5% rate).
Confirmed **not systemic** — didn't cluster toward the end of a long run,
unrelated files succeeded immediately before and after. Consistent with
ordinary transient network blips against the local Ollama server. The
pipeline's existing resumability (skip anything already in `extracted/`/
`needs-review`/`cuisine-review`) means a plain rerun after the full pass
finishes will retry every such failure automatically — budget one cleanup
pass into the full-run timeline, don't expect zero failures on the first pass.

### 10. Test-run isolation

`--raw-dir`/`--out-dir` alone did **not** isolate a test run —
`needs-review/`, `cuisine-review/`, and `logs/` were hardcoded and shared
with the real corpus run. A recipe flagged during a small test would be
silently treated as already-handled by the real run later (the
resumability `existsSync` check would see it as done and skip it forever).
Fixed: added `--needs-review-dir`, `--cuisine-review-dir`, `--log-dir` CLI
overrides, with a runtime warning if `--out-dir` is passed without them.
**Always use all five override flags together for any future test batch.**

### 11. Ingredient-alternative labeling

The Dart parser already extracts a `preparation`/`alternative` split
(ported from the app's own `url_importer.dart`); this was being joined into
`notes` with a bare comma, giving no indication which part was which. Now
the `alternative` portion is explicitly labeled `alt: ...` in the joined
`notes` string, per direct request — e.g. a line offering sugar OR maple
syrup now produces `notes: "alt: 1-2 tbsp maple syrup (20-40g)"` instead of
an unlabeled fragment.

### 12. `04_cluster_review.js` (new file)

Aggregates `manual-review.jsonl` by `reason`, then groups either by the raw
flagged value (for reasons like `invalid-course` where the same fixable
string recurs across files — seeing "42 files" next to a value is what
makes fixing it once worthwhile) or by domain (for reasons like
`no-directions-found`/`compound-amount-detected`, where the per-recipe
value isn't meaningfully groupable but a site-level pattern might be).

```
node 04_cluster_review.js [--review-log logs/manual-review.jsonl] [--top N]
```

Verified against a synthetic log matching real flag shapes. **Never
actually run against a real `manual-review.jsonl` from an actual test
batch** — do this early next session, it's cheap and has been outstanding
for a while.

---

## Real Findings Deliberately Left As-Is (not bugs, decisions made)

- **`chefsteps.com`**: discovery is pulling landing/tips/cuts-of-meat pages
  rather than recipes for at least some URLs. Deliberately **not**
  tightening discovery criteria — already scraped, can clean up manually,
  and an over-tuned filter risks missing real recipes on future sites more
  than the current noise costs. No action planned.
- **`khymos.org`**: mostly molecular-gastronomy discussion posts, not
  recipes. Confirmed expected, not a bug.
- **Fine-dining `long-name` noise**: see item 7 above — expected, not worth
  tightening the 70-char threshold based on current evidence.

---

## Unconfirmed / Needs Verification Next Session

1. **Run `04_cluster_review.js` against a real `manual-review.jsonl`** from
   an actual batch — never done yet, despite the tool existing for a while.
2. **Pull an actual output JSON for a drinks recipe** post-schema-rename
   and confirm `glass`/`garnish` (array)/`subcategory` all serialize
   correctly end to end. The only drinks JSON ever directly inspected
   (`5th-amendment`) predates the schema correction.
3. **Confirm the Ong Choy recipe's cleaned `name` field directly** — never
   actually seen in output, only inferred from a `cuisine-review` flag.
4. **Site coverage is still thin relative to the full 76-site corpus.**
   Batches so far: a handful of small tests, one 44-file batch, one
   161-file batch. Several sites have likely never appeared in any test at
   all. A larger, deliberately-diverse batch — spread across sites not yet
   seen, not repeats of the same ones — remains the standing
   recommendation before committing to the full run.
5. **Expect the next batch to surface something new.** Every batch this
   session did. Treat this handoff as "everything found so far is fixed,"
   not "this is now bug-free."

---

## Start Next Session

1. Read this handoff in full before making changes. Don't re-litigate
   anything marked resolved above without new evidence — most of these
   fixes were confirmed against real failing examples, not theoretical.
2. Knock out the four cheap, concrete, outstanding checks in "Unconfirmed"
   items 1-3 (and re-read item 5 before assuming a clean batch means done).
3. Run one larger, deliberately site-diverse validation batch (item 4).
4. Only after that batch comes back with nothing but already-known,
   accepted flag types (or a new fix gets made and reverified) — decide
   whether to commit to the full 100k-recipe run.
5. For any further test batch, always pass all five isolation flags:
   `--raw-dir`, `--out-dir`, `--needs-review-dir`, `--cuisine-review-dir`,
   `--log-dir`. Never reuse the real corpus's default directories for testing.

---

## Working Preferences (carried forward, refined this session)

No em dashes, no emojis, Canadian spelling, no bullet points with trailing
periods. Findings-first for exploratory or infrastructure-touching tasks.
Zero hallucination, do not guess — if something can't be confirmed from
real evidence (an actual server log, actual output JSON, an actual test
run), say so and get the missing evidence rather than assert a fix.
Corrections acknowledged and course-corrected without excessive apology.
Pushes back clearly when something is over-engineered or an assumption is
unsupported, and expects the same in return.

Specific to this session's focus:

- **Accuracy is paramount for this pipeline above all else** — Memoix is
  for professional cooks, and the app's core value is search/discovery by
  fields like cuisine and course, so a mislabeled or silently-null
  searchable field is a real defect, not a minor gap.
- **Deterministic resolution is preferred over model judgment** wherever a
  reliable deterministic signal exists (URL patterns, JSON-LD data,
  site-wide tags) — the model is reserved for cases with no deterministic
  answer available.
- **Flag ambiguity for human review rather than silently guess**, even when
  a plausible-looking automated resolution exists. The chef-fallback
  removal, the adapted-dish gate, and `serves-range` flagging all follow
  this same pattern, and it should keep being the default going forward.
