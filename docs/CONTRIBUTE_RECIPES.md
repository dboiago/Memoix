# Memoix Contribute Recipes: Data & Privacy

## Overview

Memoix is developing a system to understand recipes semantically - moving beyond 
text search toward a tool that understands cooking as a domain. The long-term goal 
is cross-cuisine discovery: surfacing relevant recipes across languages and culinary 
traditions, with the AI handling translation, unit conversion, and contextual 
adaptation automatically.

To build this, the system needs to learn from real, human-tested recipes rather 
than raw internet scrapes. This feature is strictly opt-in and has no effect unless 
explicitly enabled.

## How It Works

When enabled, Memoix transmits your recipes to a secure backend to build a 
proprietary culinary dataset. Your recipes contribute to a shared understanding of 
ingredient relationships, regional cuisines, dish structure, and recipe evolution 
over time.

Your data helps the system learn things like:

- Which ingredient ratios are characteristic of a dish
- How recipes are naturally categorized and tagged by real cooks
- Which modifications are consistently made to improve a dish
- How dishes relate to and complement one another across cuisines

## What Is Collected

If you opt in, the following is transmitted when you save, update, cook, or 
favourite a recipe:

- Recipe content (ingredients, instructions, and notes)
- Original source text or URL (if the recipe was imported)
- Culinary statistics (cook count, favourite status)
- Recipe pairing relationships (the name and course of any linked recipes)
- A derived lineage identifier and content hash, used to track recipe refinement 
  over time without transmitting any device or user identifier
- Basic metadata (app version and system language)

## What Is NEVER Collected

- No personal identifiers - no name, email, account, or device ID
- No location data
- No behavioural tracking - no screen time, session data, or usage patterns
- No hidden recipes - recipes marked as Hidden are unconditionally excluded from 
  transmission, regardless of your global setting

## A Note on Submitted Data

Because no user or device identifier is attached to any submission, it is not 
possible to associate data in the dataset with a specific person or installation. 
This is intentional. It also means that previously submitted recipes cannot be 
individually withdrawn - there is no link between the dataset and you. Disabling 
this setting stops all future transmissions.

## Control

### Global Setting

Enable or disable this feature at any time in **Settings > Data > Contribute to 
Culinary Intelligence**. Disabling stops all future transmissions immediately.

### Per-Recipe Privacy

If you want to contribute but have specific recipes you want to keep private, open 
the menu on any recipe and set its visibility to **Hidden**. Hidden recipes are 
never transmitted, even when the global setting is enabled.
