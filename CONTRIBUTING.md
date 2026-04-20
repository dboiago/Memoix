# Contributing to Memoix

Thanks for your interest in contributing to Memoix.

This project is opinionated by design. Contributions are welcome, but they're expected to align with the intent and direction of the app.

If you're looking to add features "because recipe apps usually have them," this may not be the right project.

---

## Project Philosophy

Memoix prioritizes:

- Clarity over cleverness
- Flexibility over rigid structure
- Restraint over feature count
- Real cooking workflows over idealized ones

Some sections are recipes. Others are reference logs, shorthand notes, or memory aids. That distinction is intentional.

Please spend time using the app and reading the code before proposing changes.

---

## Data & Persistence

Memoix uses a relational data model backed by Drift (SQLite).

- Data integrity is critical
- Migrations must be explicit and reversible
- Schema changes require justification and discussion

Do not bypass the data layer or duplicate state.

If you're unsure how a change affects persistence, ask before implementing it.

---

## What Makes a Good Contribution

Good contributions tend to:

- Improve correctness, stability, or performance
- Reduce friction in existing workflows
- Clarify UI or data models without adding surface area
- Respect existing patterns and naming conventions
- Be small, focused, and well-reasoned
- Preserve or improve determinism in parsing and data handling

Refactors are welcome only when they clearly improve readability or maintainability.

---

## What Will Likely Be Rejected

The following are unlikely to be accepted:

- Gamification (streaks, points, achievements, etc.)
- Social features or feeds
- Beginner-only scaffolding or tutorials
- Features that force structure where flexibility is intentional
- Cosmetic changes without functional justification
- Large rewrites without prior discussion
- Features that rely on external services without clear fallback behaviour
- AI-driven features that obscure or replace user intent

The goal is to keep the tool coherent.

---

## Issues

If you're opening an issue:

- Be specific
- Include screenshots when relevant
- Explain the impact, not just the behaviour
- Avoid "wouldn't it be cool if…" suggestions without context

Bug reports are always welcome.

Feature requests should explain why the existing behaviour is insufficient.

---

## Pull Requests

Before submitting a PR:

- Open an issue or discussion if the change affects behaviour or UX
- Do not introduce new architectural patterns without discussion
- Keep changes scoped and readable
- Follow existing formatting and structure
- Avoid drive-by cleanup unrelated to the change
- Test on at least one target platform
- Changes affecting data models or parsing logic must handle edge cases explicitly

PRs that add features without discussion may be closed.

---

## Recipes & Reference Data

If contributing recipes or reference data:

- Follow the existing schema exactly
- Avoid embellishment or editorial tone
- Treat entries as working notes, not content
- Increment versions where required

This repository is not a content farm.

---

## Style & Tone

- Avoid marketing language
- Prefer plain, direct naming
- Comments should explain *why*, not *what*
- UI copy should be concise and literal
- Use Canadian English spelling (e.g. flavour, colour, favour) for UI, comments, and identifiers where applicable
- Do not modify spelling in imported or external content

If something feels overly clever, it probably doesn't belong.

---

## Imports & Parsing

OCR, URL import, and AI import all pass through a normalization layer.

- Parsing should favour correctness over coverage
- Edge cases should be handled explicitly, not heuristically guessed
- Silent failures are not acceptable

If a format cannot be parsed reliably, it should fail visibly.

---

## AI Features

AI functionality in Memoix is:

- Optional and user-configured (API key required)
- Explicitly invoked (no background or automatic behaviour)
- Treated as a tool, not a source of truth

Contributions must not:

- Add hidden or automatic AI behaviour
- Depend on specific providers or models
- Fail cleanly when AI is unavailable or misconfigured

AI should assist, not decide.

---

## License Note

Memoix is licensed under the [PolyForm Noncommercial License](LICENSE).

By contributing, you agree that your contributions fall under the same license.

---

## Final Note

Memoix started as a personal tool.

The goal of contributions is not to make it bigger — it's to make it truer to how serious cooks actually work.

If that resonates with you, you're welcome here.