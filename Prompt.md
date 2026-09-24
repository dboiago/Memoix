Continuing work on the Memoix corpus-pipeline (see AGENTS.md for architecture/conventions — should auto-load).

Status:

Confirmed already-working, no change needed: recipes with zero directions already get routed to needs-review, never extracted (flaggedForReview from no-directions-found is checked before the clean-bucket assignment in 03_extract.js, ~line 2562).
Pending: a diagnosed-but-not-yet-applied fix for baking-sense.com's "## Process Photos" heading convention in extractMarkdownDirections/METHOD_HEADING_PATTERN (03_extract.js) — needs a third fallback trying plain bullets (/^[-*]\s+(.+)$/) with terminal punctuation, confirmed against sourdough-babka and triple-guinness-bundt-cake in raw-test. No new review flag should be added alongside it.
Let's pick up with applying that fix