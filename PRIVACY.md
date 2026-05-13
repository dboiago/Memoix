# Privacy Policy

**App:** Memoix  
**Developer:** dboiago  
**Last updated:** May 2026

## Overview

Memoix is an offline-first application. It does not collect, store, or
transmit any personal data by default. No analytics, diagnostics, or crash
reporting are active.

## Data Storage

All recipe data, comments, and settings are stored locally on your device using
an embedded SQLite database. This data never leaves your device unless you
explicitly configure an optional sync feature.

## Optional Features

All network-connected features are entirely optional and require deliberate
configuration by the user. None are enabled by default.

### Cloud Sync (OneDrive / Google Drive)
If you choose to connect OneDrive or Google Drive, recipe data is transmitted
to and stored in your personal cloud storage account. Sync bundles may
include a device model to identify the source of changes. This data is
governed by Microsoft's or Google's respective privacy policies. The
developer has no access to this data.

### AI-Assisted Tools
If you choose to use the AI features, you must supply your own API key
from a third-party AI provider. When these features are used, content you
submit (such as recipe images or text) is transmitted to that provider using
your credentials and your subscription. The developer has no access to this
data or your API key. Your use is governed by your AI provider's privacy
policy.

### Contribute Recipes
If you enable this feature in Settings > Data, Memoix transmits selected recipe 
data to a secure backend to build an anonymized culinary dataset. The goal is to 
develop cross-cuisine discovery, ingredient substitutions, semantic scaling and 
understanding of cooking as a domain.

**Data Transmission**
When enabled, the following is transmitted when you save, update, cook, or favourite a recipe:
*   **Content:** Recipe text (ingredients, instructions, comments) and original source URL/text
*   **Context:** Culinary statistics (cook count, favourite status, ratings) and pairing relationships
*   **Metadata:** A derived lineage identifier and content hash (used to track refinement over time), app version, and system language

**Privacy & Anonymization**
*   **No Identifiers:** No personal identifiers are ever collected - this includes name, email, account info, device IDs, or advertising identifiers
*   **No Tracking:** No location data, screen-time metrics, or behavioural analytics are collected
*   **Strict Exclusion:** Recipes marked as "Hidden" are unconditionally excluded from transmission regardless of global settings
*   **User Responsibility:** Do not include sensitive personal information (such as passwords or government IDs) in recipe text or comments, as Memoix cannot guarantee the detection of all manually entered identifiers
*   **Automated Scrubbing:** Memoix performs a best-effort automated scan to redact potential contact information (like emails or phone numbers) before transmission

**Retention & Control**
Submitted data is stored without any user or device linkage. Because the data 
is intentionally detached from your identity, at the point of transmission 
previously submitted data cannot be withdrawn - there is no mechanical link 
between the dataset and you. 
Disabling this setting stops all future transmissions immediately.

**Infrastructure**
Recipe content is never used to train third-party commercial models. Data is processed on Cloudflare’s infrastructure (see: https://www.cloudflare.com/privacypolicy/).

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
credential provisioning and is not accessible to end users. No personal data 
is transmitted through this interface or the associated verification endpoint.

Navigating a valid token link contacts a developer-operated verification endpoint. 
The token encodes only derived metadata and a cryptographic signature - 
no personal or recipe data is included. If verification succeeds, the user is 
optionally presented with a guest book they may choose to sign. Guest book entries 
are voluntarily submitted and retained by the developer.

## Support the Developer

Memoix is free. GitHub Sponsors is available for those who wish to contribute.
No payment or personal data is handled by the app. The GitHub Sponsors option
is not present in the Play Store version of the app.

## No Data Collection
By default, Memoix does not collect user data, usage statistics or crash 
reports. This remains true unless you explicitly enable the optional 
Contribute Recipes feature described above.

Device model embedded in optional cloud sync bundles remain within 
your configured cloud storage accounts and are not transmitted to the 
developer.

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

For questions, open an issue on the [GitHub repository](https://github.com/dboiago/Memoix).
