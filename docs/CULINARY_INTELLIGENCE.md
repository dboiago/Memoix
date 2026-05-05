# Memoix Culinary Intelligence: Data & Privacy

## Overview
Memoix is actively developing a system to understand recipes semantically. The goal is to move beyond basic text search and build a tool that actually understands cooking - allowing for intelligent ingredient substitutions, precise dietary adaptations, and accurate global scaling. 

To build an engine that understands real-world cooking, it needs to learn from mature, human-tested recipes rather than raw internet scrapes.
This feature is not active by default and has no effect unless explicitly enabled.

## How It Works
If enabled, selected recipes may be securely transmitted to Memoix's backedn for potential use in future development.

This helps us learn things such as:
* Which ingredient ratios yield the best results
* How recipes are naturally categorized and tagged by real users
* Which modifications or notes are consistently added to popular dishes

## What Is Collected
If you opt in, the following recipe-related data may be transmitted when you save or update a recipe:
* Recipe content (ingredients, instructions, notes)
* Original source text or URL (if imported)
* Culinary statistics (cook count, favourite status)
* Basic metadata (app version and system language)

## What Is NEVER Collected
Memoix strictly collects recipe information, not personal behavioural data.
* No personal identifiers (name, email, or account identity)
* No location data
* No behavioural tracking (screen time, usage tracking)
* No hidden recipes (recipes marked Hidden are excluded from sharing, regardless of your global settings)

## Control
You own your data and maintain absolute control over what is shared.

### Global Opt-Out
You can disable this system at any time in **Settings > Data > Improve recipe understaning**

### Per-recipe Control
Each recipe can be excluded from sharing using its visibility controls. Hidden recipes are never transmitted, even if sharing is enabled globally.