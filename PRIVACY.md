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

### AI-Assisted Tools
If you choose to use the AI features, you must supply your own API key
from a third-party AI provider. When these features are used, content you
submit (such as recipe images or text) is transmitted to that provider using
your credentials and your subscription. The developer has no access to this
data or your API key. Your use is governed by your AI provider's privacy
policy.

## Permissions

### Camera
Camera access is used for two purposes: on-device OCR (optical character
recognition) to assist with recipe text import, and QR code scanning for
recipe link import. No images are stored or transmitted as part of either
process.

## Credential Storage

API keys and authentication tokens are encrypted and stored in your device's
native hardware keystore (Android Keystore / iOS Keychain). They are never
backed up to the database or transmitted anywhere except directly to the
provider you configured.

## Network Requests

The following outbound requests only occur if triggered by user action or
explicitly enabled in settings. They do not transmit personal data beyond
your IP address.

### App Update Check
If enabled in settings, or when manually triggered, the app makes an
unauthenticated request to the GitHub API to check whether a newer version
is available. No personal data is transmitted. This feature is disabled by
default and is only available in the GitHub APK version.

### URL Import Fallback
When importing a recipe from a URL, if the original source is unavailable,
the app may forward that URL to the Wayback Machine (archive.org) as a
fallback. This is triggered only by a deliberate user import action.

## Developer Diagnostic Interface

The app contains a developer diagnostic interface that requires manual
credential provisioning and is not accessible to end users. No user data
is transmitted through this interface.

## Support the Developer

Memoix is free. GitHub Sponsors is available for those who wish to contribute.
No payment or personal data is handled by the app. The GitHub Sponsors option
is not present in the Play Store version of the app.

## No Data Collection

The developer does not collect user data, usage statistics, or crash reports.
Device identifiers embedded in cloud sync bundles remain within your
configured cloud storage accounts.

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