# Memoix Recipe Ingestion Pipeline

Ingestion and structured data extraction tool for seeding the Memoix recipe database. Scrapes, normalizes, and parses high-value recipe sources using deterministic rule sets alongside Ollama schema-constrained extraction.

## Pipeline Architecture

- `01_discover.js`: Discovers and compiles target recipe URLs.
- `02_fetch.js`: Downloads raw source content to disk.
- `03_extract.js`: Main LLM/deterministic extraction engine. Handles ingredient parsing, course/cuisine resolution, schema enforcement, and quarantine routing.
- `04_cluster_review.js`: Triage tool that aggregates `manual-review.jsonl` by failure reason and domain.
- `memoix_recipe_parser.dart`: Dart ingredient and amount parsing logic.
- `site_configs.js`: Domain-specific selector and metadata rules.

## Extraction Execution & Test Isolation

To prevent test runs from polluting production directories or falsely marking unreviewed recipes as processed, **pass all five path override flags together** during test batches:

```bash
node 03_extract.js \
  --raw-dir raw-test \
  --out-dir extracted-test \
  --needs-review-dir needs-review-test \
  --cuisine-review-dir cuisine-review-test \
  --log-dir logs-test
```

## Review Clustering

To aggregate flagged outputs for batch triage:

```Bash
node 04_cluster_review.js --review-log logs-test/manual-review.jsonl --top 20
```
