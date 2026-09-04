// 04_cluster_review.js
//
// Aggregates logs/manual-review.jsonl (one JSON line per flag, written by
// 03_extract.js's logForReview) into a grouped summary, so a recurring raw
// value — an unmapped ldCategory string, the same site hitting
// compound-amount repeatedly, one domain accounting for most timeouts — gets
// fixed once in LD_COURSE_MAP/LD_CUISINE_MAP or the relevant detector,
// instead of being discovered one needs-review file at a time.
//
// Usage:
//   node 04_cluster_review.js [--review-log logs/manual-review.jsonl] [--top N]
//
// --review-log points at the flag log to read (defaults to the same path
// 03_extract.js uses by default — pass the same --log-dir value you used for
// that run if you isolated it).
// --top limits how many distinct values are shown per reason (default 15) —
// the log itself is the full record, this is a triage view, not a report.

import { readFileSync, existsSync } from 'fs';

function parseArgs() {
  const args = process.argv.slice(2);
  const reviewLogIdx = args.indexOf('--review-log');
  const topIdx = args.indexOf('--top');
  return {
    reviewLog: reviewLogIdx !== -1 ? args[reviewLogIdx + 1] : 'logs/manual-review.jsonl',
    top: topIdx !== -1 ? parseInt(args[topIdx + 1], 10) : 15,
  };
}

function domainOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return '(unknown domain)';
  }
}

// Groups on the raw flagged value itself (`line`) where that's the
// meaningful signal — e.g. every recipe flagged invalid-course: "breakfast"
// is the exact same fixable case, and seeing "42 files" next to it is what
// makes fixing it once worth doing instead of clicking through 42 files.
// Reasons where the raw value is unique per-recipe by nature (a specific
// compound-amount ingredient line, a specific long name) are grouped by
// domain instead, since that's where a real pattern would show up.
const GROUP_BY_VALUE_REASONS = new Set([
  'invalid-course', 'invalid-subcategory', 'serves-unparseable', 'cuisine-blind-check-failed',
]);

function main() {
  const { reviewLog, top } = parseArgs();

  if (!existsSync(reviewLog)) {
    console.error(`No review log found at ${reviewLog}. Nothing to aggregate — check --review-log if you used ` +
      `a --log-dir override for the run you're reviewing.`);
    process.exitCode = 1;
    return;
  }

  const lines = readFileSync(reviewLog, 'utf8').split('\n').filter(l => l.trim());
  const entries = [];
  for (const line of lines) {
    try {
      entries.push(JSON.parse(line));
    } catch {
      console.warn(`Skipping unparseable line in ${reviewLog}: ${line.slice(0, 100)}`);
    }
  }

  if (entries.length === 0) {
    console.log(`${reviewLog} has no entries. Nothing to aggregate.`);
    return;
  }

  const byReason = new Map();
  for (const entry of entries) {
    if (!byReason.has(entry.reason)) byReason.set(entry.reason, []);
    byReason.get(entry.reason).push(entry);
  }

  console.log(`${entries.length} flagged entries across ${byReason.size} reasons, from ${reviewLog}\n`);

  const sortedReasons = [...byReason.entries()].sort((a, b) => b[1].length - a[1].length);

  for (const [reason, reasonEntries] of sortedReasons) {
    console.log(`## ${reason} (${reasonEntries.length})`);

    const groupByValue = GROUP_BY_VALUE_REASONS.has(reason);
    const counts = new Map();
    for (const entry of reasonEntries) {
      const key = groupByValue ? (entry.line ?? '(empty)') : domainOf(entry.url);
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }

    const sortedCounts = [...counts.entries()].sort((a, b) => b[1] - a[1]);
    const shown = sortedCounts.slice(0, top);
    for (const [key, count] of shown) {
      console.log(`  ${count.toString().padStart(4)}  ${key}`);
    }
    if (sortedCounts.length > top) {
      console.log(`  ... and ${sortedCounts.length - top} more distinct ${groupByValue ? 'values' : 'domains'}`);
    }
    console.log('');
  }
}

main();
