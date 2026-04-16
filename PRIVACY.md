# Privacy Policy

**App:** Memoix  
**Developer:** dboiago  
**Last updated:** April 2026

## Overview

Memoix is an offline-first application. It does not collect, store, or
transmit any personal data by default. No analytics, diagnostics, or crash
reporting are active.

## Data Storage

All recipe data, notes, and settings are stored locally on your device using
an embedded SQLite database. This data never leaves your device unless you
explicitly configure an optional sync feature.

## Optional Features

All network-connected features are entirely optional and require deliberate
configuration by the user. None are enabled by default.

### Cloud Sync (OneDrive / Google Drive)
If you choose to connect OneDrive or Google Drive, recipe data is transmitted
to and stored in your personal cloud storage account. Sync bundles may
include a device name to identify the source of changes. This data is
governed by Microsoft's or Google's respective privacy policies. The
developer has no access to this data.

### Cloud Sync (Supabase)
The app includes an internal Supabase-backed sync feature. This feature is
not intended for or accessible to end users and requires backend credentials
that are not distributed with the app. If active, recipe data is transmitted
to a Supabase-hosted backend and is governed by Supabase's privacy policy
(supabase.com).

### AI-Assisted Tools
If you choose to use the AI features, you must supply your own API key
from a third-party AI provider. When these features are used, content you submit
(such as recipe images or text) is transmitted to that provider using your
credentials and your subscription. The developer has no access to this data
or your API key. Your use is governed by your AI provider's privacy policy.

### Camera
Camera access is used for two purposes: on-device OCR (optical character
recognition) to assist with recipe text import, and QR code scanning for
recipe link import. No images are stored or transmitted as part of either
process.

## Automatic Network Requests

The following outbound requests occur automatically during normal app use and
do not transmit personal data beyond your IP address:

### App Update Check
On startup, the app makes an unauthenticated request to the GitHub API to
check whether a newer version is available. No personal data is transmitted.

### URL Import Fallback
When importing a recipe from a URL, if the original source is unavailable,
the app may forward that URL to the Wayback Machine (archive.org) as a
fallback. This is triggered only by a deliberate user import action.

### Font Loading
The app uses Google Fonts. Fonts are currently fetched at runtime from
Google's servers (fonts.googleapis.com), which exposes your IP address to
Google. Bundling fonts locally is a planned improvement.

## Donations

The app is free. An optional donation link (Ko-fi) is provided for users who
wish to support development. Tapping this link will open an external browser
session governed by Ko-fi's privacy policy. No payment or personal data is
handled by the app.

## No Data Collection

The developer does not collect user data, usage statistics, or crash reports.
Device identifiers embedded in cloud sync bundles remain within your
configured cloud storage accounts except as described in the Supabase section above.

## Third-Party Services

The app does not integrate any third-party analytics, advertising, or
tracking SDKs.

## Children's Privacy

This app is intended for general audiences and does not knowingly collect
data from anyone.

## Changes

This policy may be updated to reflect changes in the app's functionality.
The last updated date above will reflect any revisions.

## Contact

For questions, open an issue on the GitHub repository.