# Memoix corpus-pipeline: agent guidelines

Scraping/extraction pipeline that turns recipe pages into structured JSON to seed
the Memoix app's database. Solo project, no budget, run locally.

## Architecture

Pipeline: `01_discover.js` (finds recipe URLs, writes `urls/queue.txt`) →
`02_fetch.js` (fetches + converts to markdown, writes `raw/*.md` + `.meta.json`) →
`03_extract.js` (sends markdown to a local Ollama model + deterministic
overrides, writes structured JSON). `memoix_recipe_parser.dart` is the
compiled CLI ingredient parser `03_extract.js` shells out to;
`normalizers.js` is its JS-side port used for pre-parse checks;
`lib/core/utils/unit_normalizer.dart` is the Flutter app's own copy, kept in
sync by hand. `site_configs.js` holds per-site CSS-selector configs for
ingredient extraction (ported from the app's own `url_importer.dart`).

**Output buckets and what they actually mean:** `extracted/` (clean),
`needs-review/`, `cuisine-review/`, `unrecoverable/`. The operator does not
plan to manually work through `needs-review`/`cuisine-review` at scale — in
practice, flagging a recipe is equivalent to excluding it from the usable
corpus, not "held for later." This means: don't flag defensively or
speculatively; only flag when something is genuinely uncertain enough that
shipping it clean would be worse than losing it. A recipe with ingredients
but zero directions can never reach `extracted` — `no-directions-found` sets
`flaggedForReview`, and that check runs before the clean-bucket assignment.

**Sites are a curated, bounded list** (see `memoix-source-list-v2.md`), not
an open-ended scrape target. New sites get their own test-batch run (same
process as below) before being trusted, not added blind at full scale. Given
that, targeted per-site parsing fixes (regexes tuned to one site's markup)
are an acceptable, ongoing strategy here — this is a fundamentally different
risk profile than "handle arbitrary internet content."

## Environment constraints

- Local model only: `Qwen3-14B-GGUF:Q4_K_M` via Ollama, on a personal PC
  (RTX 3080, 32GB RAM) — not a server, no budget for frontier models. Other
  models were tried; this is the practical ceiling. Do not suggest "just use
  a better model" as a fix.
- No dart/flutter toolchain available in this sandbox. Any edit to
  `memoix_recipe_parser.dart` or `lib/core/utils/unit_normalizer.dart` is
  verified by careful manual review only (brace-balance, line-by-line
  comparison) — say so explicitly, never claim it compiles or was analyzed.
- This workspace is a GitHub VFS mount — no real local terminal tied to the
  actual repo checkout. If you need fresh files not already in context, the
  GitHub web UI blocks direct fetching and `api.github.com` rate-limits
  fast; pulling a tarball via `https://codeload.github.com/<owner>/<repo>/tar.gz/refs/heads/<branch>` works reliably.

## Testing workflow

Test batches run against `raw-test/` → `extracted-test/` /
`needs-review-test/` / `cuisine-review-test/` / `unrecoverable-test/` /
`logs-test/`, mirroring the real directory names via CLI flags:

```
node 03_extract.js --raw-dir raw-test --out-dir extracted-test \
  --needs-review-dir needs-review-test --cuisine-review-dir cuisine-review-test \
  --log-dir logs-test --unrecoverable-dir unrecoverable-test
```

Clear all four output dirs before every re-run, not just the first —
stale files from a prior run's bucket assignment (a recipe that moved
buckets between runs) otherwise sit alongside fresh output. Test batches are
genuinely random samples across the full site list, not hand-picked or
adversarial — don't assume a batch failure is a curated edge case.

## Core conventions

- **Deterministic over model judgment, everywhere it's feasible.** The
  operator has repeatedly found the local model unreliable at mechanical
  tasks (amount/unit splitting, cuisine/region guessing) and does not trust
  it for semantic judgment calls. Prefer regex/lookup/structured-data
  grounding (`ldCuisine`, `siteRegionHint`, JSON-LD, Dart parser) over
  asking the model to decide, and prefer nulling/flagging an unknown over
  guessing.
- **Only add a pattern/override after confirming a real corpus case**, not
  speculatively or in a batch. This applies especially to course/cuisine
  keyword overrides (e.g. `/\bsoups?\b/i` → `'soups'`) — check for
  savory/alternate-meaning counter-examples first (`"pie"` → desserts is
  wrong because meat pie exists; same logic for `"cake"`, `"bread"`).
- **Never use an LLM call for ingredient-name → region/cuisine inference.**
  Tried before, produced confident wrong guesses. Cheese/dairy names
  specifically are unreliable cuisine signals (naming reflects the cheese's
  own origin, not the dish's cuisine).
- **A review flag should verify against the actual final parsed output**
  before firing, not just pattern-match on a risky-looking shape — a check
  that never looks at what actually shipped is just noise.
- Comments: one short line stating what the code can't show on its own
  (a confirmed real-world case, a non-obvious constraint) — not a restatement
  of what the next line does.
