# Memoix Scrape Handoff v16

## Branch

Continues from v15. This session covered two things: closing gaps between
`03_extract.js`'s output and the real app schema (confirmed via
`knowledge_payload.dart`, `recipe.dart`, and the normalizer/importer files),
and fixing two confirmed detection bugs surfaced by real test-batch output.
No full corpus run yet. A ~200-recipe test batch is in progress at time of
this handoff; results to be reviewed in the next session before any decision
to commit to the full ~100k run.

---

## Files changed this session

- **`normalizers.js`** (new file) -- JS port of `text_normalizer.dart` and
  `unit_normalizer.dart`, scoped to what the pipeline needs.
- **`03_extract.js`** -- normalizer wiring, nutrition shape fix, source
  value, region/subcategory redesign, pizza scope gate (added, then fixed
  twice), compound-amount detection vocabulary fix.
- **`memoix_recipe_parser.dart`** -- added a branch for bare-unit quantity
  words with no leading number (pinch, dash, handful, drop).
- **`recipe.dart`** -- `scraped` added to the `RecipeSource` enum (done by
  Sine, not by Claude -- no repo write access).

---

## Completed This Session

### 1. Normalizer parity with the app's mandatory contract

`recipe_import_result.dart`'s `fromAi()` factory has a comment: "Apply
normalizers per AGENTS.md: all imports MUST pass through normalizers,"
applied to OCR import and URL import. `03_extract.js` was not doing this at
all. `normalizers.js` ports `cleanName`, `normalizeFractions`,
`normalizeUnit`, `normalizeGarnish` faithfully from the Dart source, plus
`normalizeGlass` (no Dart equivalent -- corpus-pipeline-only, confirmed
against the app's own glassware picker, which shows bare style names like
"Coupe"/"Highball", never "<style> glass").

Wired into `buildPayload`: ingredient `name`/`amount`/`unit` now go through
`cleanName`/`normalizeFractions`/`normalizeUnit`. `garnish` goes through
`normalizeGarnish` (Title Case via `cleanName`, not a bare
capitalize-first-letter pass -- that was an earlier wrong draft, corrected
before landing). `glass` goes through `normalizeGlass`.

**Deliberately NOT applied to the top-level recipe `name`.** Tested against
a real file (`ZZ's Pineapple Cocktail`) and confirmed `cleanName` mangles
legitimate stylized capitalization ("ZZ's" -> "Zz's"), and the mandatory-
normalizer comment in `fromAi()` only covers ingredient-level fields in that
factory, not the top-level name. Reverted after the test caught it.

One upstream bug found and fixed while porting: `text_normalizer.dart`'s
`uppercaseWords` set was missing a comma between `'ev'` and `'diy'`, which
Dart auto-concatenates into the single garbage string `'evdiy'`. Sine fixed
this in the actual repo; the JS port was updated to match the corrected
(separate `'ev'`, `'diy'`) behavior once confirmed fixed upstream.

### 2. Nutrition shape -- was breaking on real-schema import

`builtNutrition` was an array containing one object with keys
`calories`/`carbs`/`fat`/`protein`. `NutritionInfo.fromJson()` expects a
plain `Map`, not a `List` (would throw on cast), with keys
`calories`/`carbohydrateContent`/`fatContent`/`proteinContent` (three of
four didn't match at all). Fixed to a plain object with the correct keys.
Verified against a real file with nutrition data
(`sweet-boondi_cookwithmanali`) post-fix: correct shape confirmed in actual
output.

### 3. `source: 'scraped'`

`RecipeSource` enum had no `scraped` value; `Recipe.fromJson()`'s enum match
falls back to `RecipeSource.personal` on no match, meaning every corpus
recipe would silently mistag as a personal recipe on import. `walkin`
(the enum's other candidate) was confirmed to mean something different:
a peer sharing their own recipe with the user, not this pipeline. Sine
added `scraped` to the enum directly in the repo. `03_extract.js`'s
existing `source: 'scraped'` needed no code change once the enum existed.
Decision confirmed deliberate, not merged with `walkin`, for future
curation/filtering flexibility and because provenance (peer-shared vs.
scraped-and-therefore-copyright/removal-sensitive) is a real, if currently
unused, distinction worth preserving now rather than trying to reconstruct
later.

### 4. Region / subcategory -- redesigned, not just patched

**Original bug, confirmed against two real outputs:** the blind cuisine
classifier's `region` field was keying off place-names embedded in
ingredient *names*, not real dish provenance --
`chinese-chicken-herbal-soup` got `region: "Sichuan"` purely from
"Sichuan Lovage Rhizome" (a generic TCM herb, not evidence the soup itself
is Sichuan regional cuisine), and a starchefs goat birria empanada got
`region: "Chihuahua"` purely from "Chihuahua cheese" as an ingredient.

**Real schema finding:** `Recipe` has no standalone `region` field at all.
`supabase_transmission_client.dart`'s enrichment step sets
`payload.recipe.region = recipe.subcategory` -- same slot, one value.
`subcategory` is region/province for most recipes, base-spirit for drinks,
confirmed as "honestly bad leftover" design but the real, current contract.

**Design discussion outcome (this is the important part for anyone picking
this up):** Sine was explicit that they will not accept a review-required
solution here -- the entire point of the pipeline is a 100k-recipe
unattended run, and "always flag for review" just relocates the manual-
review burden Sine is trying to eliminate, it doesn't remove it. Two
candidate mechanisms (a curated per-site region tag; a tightened blind-
classification prompt with an explicit anti-ingredient-name-inference
guardrail) were both proposed and both explicitly rejected on this basis --
neither clears the bar of "provably correct AND zero review," they only
trade which axis fails.

**Final, current, shipped behavior:** `subcategory` is `null` for every
non-drink recipe, unconditionally, unless a future deterministic
page-level signal exists. Confirmed there is currently no such signal
(`02_fetch.js`'s `extractJsonLd()` doesn't extract anything at a sub-region
grain). Verified in production output across multiple real files including
`chinasichuanfood.com` recipes, which now correctly show `null` rather than
a guessed region, confirmed by Sine as the intended tradeoff, accepted
explicitly, not a gap that needs closing.

**One approved-in-principle, not-yet-built extension:** if a site's own
JSON-LD `recipeCuisine`/`recipeCategory` markup ever states something more
specific than country-level (the page's own words, e.g. literally
`"Sichuan"` rather than `"Chinese"`), that would clear Sine's bar (same
trust tier `resolveCourseFromLd`/`resolveCuisineFromLd` already use
unattended) and could deterministically lock `subcategory`, zero review
needed. `resolveCuisineFromLd()` currently only recognizes country-level
tokens or bare two-letter codes and would silently discard a more specific
value if a site ever provided one. **Not built yet, deliberately** -- Sine
wants to prioritize getting to the full run over closing a low-coverage
edge case first. Backlog item, not a blocker.

**Explicitly out of scope, not rejected, just not now:** a future web-
search/food-etymology verification agent, floated by Sine as a genuine
"nice to have" for later, not a requirement blocking anything today. Not
designed, not discussed in technical detail. If revisited, note food
provenance/etymology is a real, often well-documented field (unlike the
earlier-considered "web search to fact-check cuisine" idea from mid-session,
which was correctly rejected as adding model-judgment risk without fixing
the actual failure mode).

### 5. Pizza scope gate -- added, then fixed twice against real false positives

`VALID_COURSES`' own comment says pizza/sandwich are out of scope
(separate domainTypes, not yet built), but nothing previously enforced it --
a pizza recipe fell through to whatever course the model picked (observed:
`mains`) and shipped as a standard recipe. Added a deterministic gate:
name/title/URL matched against `/\bpizzas?\b/i` routes to `needs-review`
with reason `unsupported-domain-type`.

Two real bugs found via actual test-batch output, both fixed:

- **Logging bug:** the gate hardcoded the logged value as the literal
  string `'pizza'` instead of what actually matched, making false-positive
  triage impossible from the log alone. Fixed to log the actual matched
  field (`title`/`ldName`/`url`) and text.
- **False positive, confirmed via the fixed logging:**
  `starchefs-electric-jellyfish-ipa` (a beer recipe) matched on
  `meta.title` = `"StarChefs - Electric Jellyfish IPA | Brewer Joe Mohrfeld
  of Pinthouse Pizza"` -- the brewer's restaurant affiliation in a byline
  after a `|` separator, not the dish. Fixed by stripping everything from
  the first `|` onward in `meta.title`/`meta.ldName` before checking.
  Confirmed against both the false positive (correctly now excluded) and
  the one true positive seen so far, `khymos.org`'s
  `"Pizza with blue cheese and pineapple – Khymos"` (no `|` in that title,
  so the strip is a no-op and the dish name still matches).

**Sandwich was named in the same original code comment but never added as a
gate** -- Sine wants pizza/sandwich handled properly eventually (scraping
sites like California Pizza Kitchen for topping/base-sauce combinations,
a materially different structure than the current recipe schema), not as
an extension of this quarantine gate. Not started.

### 6. Compound-amount detection -- vocabulary gap, confirmed via real miss

`sweet-boondi`'s `"1/2 cup + 4 tablespoons water, divided"` line was never
flagged and shipped as a "clean" recipe with a garbage ingredient
(`name: "+ 4 Tablespoons Water"`, the Dart parser's bad split on the
unflagged compound line). Root cause: `AMOUNT_UNIT_PATTERN`'s own
hand-typed unit list (`g|kg|ml|l|tsp|tbsp|cup|cups|oz|lb|lbs|pinch|clove|
cloves|piece|pieces`) only recognized abbreviated units, not spelled-out
forms -- "tablespoons" isn't in that list, so the line only ever matched
one amount+unit pattern (`"1/2 cup"`), never reached the two-match
threshold, and the detector never fired.

Fixed by rebuilding the pattern from a single shared vocabulary
(`COMPOUND_DETECTION_UNIT_WORDS`, exported from `normalizers.js`) instead
of a second, independently-maintained list -- the actual root cause of the
class of bug, not just this one instance. That vocabulary is the union of
`UNIT_MAP`'s keys (spelled-out input forms) AND its values (canonical
abbreviations like `g`/`kg`/`oz`/`lb`) -- a first attempt using keys-only
was caught by the regression suite as dropping the bare abbreviations the
original narrow list already had correct, since those only exist as
`UNIT_MAP` values, not keys. Size descriptors (`large`/`medium`/`small`,
also `UNIT_MAP` keys) are explicitly excluded to avoid false-positiving on
lines like "2 large eggs."

Verified against a 10-case regression suite covering the actual bug, every
documented true-positive shape from the function's original header comment,
every documented false-positive guard, and the size-descriptor exclusion.
All 10 pass.

**Still not addressed, and flagged as a real open design question, not a
bug:** how the Dart parser should actually *split* a divided/compound line
like `"1/2 cup + 4 tablespoons water, divided"` once flagged. It'll now
correctly route to `needs-review` instead of shipping silently, but nothing
parses it into two sane ingredient entries or handles the "divided" timing
information. Needs real volume data before designing a fix, per Sine.

---

## Real Findings Left As-Is (deliberate, not oversights)

- **`region` internally still computed, never output.** `extracted.region`
  is still populated by both the main extraction call and the blind
  classifier, just never written into the final payload for non-drink
  recipes. Left in place in case a future deterministic LD-based signal
  needs it, or for future debugging visibility. Not currently logged
  anywhere either.
- **Drink `region` (sub-region within a drink's cuisine) is fully
  discarded, not just for non-drinks.** Confirmed acceptable by Sine --
  they've never seen this matter for drinks the way it does for food
  (Sichuan/Cantonese-type distinctions), and `subcategory` is already
  spoken for by the base spirit on drink recipes.
- **`+4 tablespoons` compound-quantity Dart-side splitting** -- see above,
  intentionally deferred pending real volume.
- **Sandwich scope gate** -- intentionally not built, per the note above.

---

## Unconfirmed / Needs Verification Next Session

In priority order, per the explicit "what am I checking for before a
week-long unattended run" discussion at the end of this session:

1. **Random-sample the CLEAN bucket, not just the flagged one.** 15-20
   recipes, spread across course and site, checked by eye against the
   actual source page. This is the only real check against something wrong
   that never trips a flag at all -- everything else on this list checks
   review queues Sine would glance at anyway.
2. **`04_cluster_review.js` output has no unrecognized reason string.**
   Known closed set as of this session: `cuisine-from-site-fallback`,
   `no-directions-found`, `compound-amount-detected`, `not-searchable`,
   `long-name`, `unsupported-domain-type`, `serves-range`,
   `adapted-dish-cuisine-unresolved`, `cuisine-blind-check-failed`, plus
   error-log reasons `dart-parse-error`, `ingredient-structuring-failed`,
   `nutrition-schema-violation`. A new reason means something unseen --
   stop and look, don't assume it's fine by analogy to the others.
3. **`extract-errors.jsonl` failure rate is in line with the ~2.5%
   transient `fetch failed` baseline noted in v15**, not climbing on a
   bigger batch (would suggest something structural: rate limiting, a site
   blocking the scraper, Ollama degrading under longer sustained load).
4. **A drinks recipe actually imports cleanly through the real walk-in
   schema path**, not just "looks right in the JSON file." Given how much
   shifted this session (nutrition shape, source value, subcategory
   routing), this needs confirming for real before scale, not assumed
   because the individual pieces were each tested in isolation.
5. **Interrupt-and-resume actually works**: kill mid-batch, restart with
   identical flags, confirm clean resumption with no duplicated or
   silently-skipped files. Never explicitly tested. A multi-day run on a
   home PC will get interrupted at some point.
6. **Site diversity is real, not just a bigger sample of already-tested
   sites.** Check whether the ~200-recipe batch (results pending review in
   the next session) actually reached previously-untested sites, per the
   v15 handoff's own standing recommendation, still not confirmed as of
   this session.

The ~200-recipe batch mentioned by Sine at the end of this session is meant
to be reviewed against this exact checklist in the next session, in order,
starting with item 1.

---

## Start Next Session

1. Read this handoff in full. Don't re-litigate the region/subcategory
   design decision without new evidence -- it was a deliberate, explicit
   tradeoff Sine chose after two rejected alternatives, not an oversight.
2. Review the ~200-recipe batch results against the six-item checklist
   above, in order.
3. Only after that batch comes back clean (or a fix gets made and
   reverified) -- decide whether to commit to the full 100k-recipe run.
4. If item 1 (clean-bucket spot check) or item 2 (unrecognized reason
   string) surfaces anything, that takes priority over everything else on
   the list, per the reasoning in this session: those are the two checks
   against silent failure, everything else is either already-visible
   (review queues) or infrastructure (resumability, error rate).

---

## Working Preferences (carried forward, unchanged)

No em dashes, no emojis, Canadian spelling, no bullet points with trailing
periods. Zero hallucination, do not guess -- confirm against real evidence
(actual output files, actual source code, actual test results) before
asserting a fix, and say so explicitly when something can't be confirmed
from what's available. IT professional background: skip foundational
explanations. Culinary background: Red Seal certified, professional
fine-dining -- operate at that level when food/technique is relevant, not
home-cook-blog level.

Specific to this session, reconfirmed and sharpened:

- **Accuracy over coverage, always, even at the cost of leaving a field
  empty.** Stated explicitly and repeatedly this session: a missing value
  costs nothing long-term; a wrong one sitting next to real data looks
  exactly as authoritative as a correct one and actively misleads,
  especially for an app aimed at kitchen professionals who will trust the
  data at face value.
- **"Flag for review" is not a free action.** This was the key
  correction of this session: a review-required solution at 100k-recipe
  scale is not a lightweight safety net, it's a standing manual-review
  burden that directly undermines the stated goal of an unattended run.
  Weigh proposed fixes against review-volume cost explicitly, not just
  correctness.
- **Deterministic, page-provided signals (JSON-LD) are trusted completely,
  zero review required.** Model inference, however well-prompted or
  cross-checked, is not, and no amount of prompt tightening changes that
  category. This is a hard line, confirmed explicitly this session, not
  a spectrum to negotiate case by case.
- **Test claims against real output before presenting them as fixed.**
  Multiple fixes this session were caught wrong or incomplete by actually
  running them against real files/regression cases before shipping
  (the `cleanName`-on-recipe-name revert, the keys-only vs. keys+values
  unit vocabulary bug) -- this pattern held up and should continue.
