# External Storage Design Document

## Overview

**Feature Name:** External Storage (User-Managed Backup & Sync)

**Philosophy:** Users own their data. Memoix provides tools to export recipes to and import recipes from storage providers the user already controls. This is **not cloud sync** — it's explicit, user-controlled backup with optional automatic triggers.

---

## 1. Terminology

| Term | Definition |
|------|------------|
| **External Storage** | A user-owned cloud location (Google Drive folder, GitHub repo, iCloud folder) |
| **Push** | Export local recipes to external storage (overwrites remote) |
| **Pull** | Import recipes from external storage (merges into local) |
| **Automatic Mode** | Push/pull triggered on app lifecycle events (open, save, close) |
| **Manual Mode** | Push/pull only when user explicitly requests |
| **Storage Provider** | OAuth-backed service (Google, GitHub, Apple) |
| **Recipe Bundle** | JSON file(s) containing exported recipes |

**Explicitly NOT:**
- "Cloud Sync" — implies Memoix-managed infrastructure
- "Real-time sync" — no background polling or websockets
- "Account" — user authenticates with provider, not with Memoix

---

## 2. Supported Storage Providers

### 2.1 Provider Matrix

| Provider | Auth Method | Storage Type | iOS | Android | Notes |
|----------|-------------|--------------|-----|---------|-------|
| **Google Drive** | OAuth 2.0 | App-specific folder | ✓ | ✓ | `google_sign_in` + Drive API |
| **GitHub** | OAuth 2.0 | Public/Private repo | ✓ | ✓ | Advanced users only, Manual mode recommended |
| **iCloud Drive** | Native | App container | ✓ | — | CloudKit via `path_provider` |
| **Dropbox** | OAuth 2.0 | App folder | ✓ | ✓ | Future consideration |

### 2.2 Provider Capability Flags

Not all providers are equal. Encode capabilities at the interface level:

```dart
abstract class ExternalStorageProvider {
  String get name;
  bool get supportsAutomaticSync;    // Can handle frequent push/pull
  bool get supportsFastMetaCheck;    // Can check remote meta cheaply
  bool get supportsAtomicWrites;     // Overwrites are atomic
  bool get supportsFolders;          // Can organize in folders
  bool get isAdvanced;               // Requires technical knowledge
}
```

| Provider | Auto Sync | Fast Meta | Atomic | Folders | Advanced |
|----------|-----------|-----------|--------|---------|----------|
| **Google Drive** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **GitHub** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **iCloud** | ✅ | ⚠️ | ⚠️ | ✅ | ❌ |

**Usage:**
- Disable Automatic Mode option for providers where `supportsAutomaticSync = false`
- Skip remote meta check on pull for providers where `supportsFastMetaCheck = false`
- Show "Advanced" badge and warnings for providers where `isAdvanced = true`

### 2.3 GitHub: Advanced Provider Handling

GitHub is powerful but not consumer-friendly. Special handling:

1. **Label as "Advanced / Power Users"** in provider selection UI
2. **Default to Manual Mode only** — disable Automatic Mode toggle
3. **Show warning on connect:**
   > "GitHub stores your recipes as commits. Each save creates a new version. Make sure your repository is private to keep recipes confidential."
4. **Require private repo confirmation** — prompt user to confirm repo visibility

This prevents:
- Support burden from confused users
- Accidental public commits of private recipes
- Unexpected commit history growth

### 2.4 OAuth SDK Requirements

```yaml
# pubspec.yaml additions
dependencies:
  google_sign_in: ^6.2.0
  googleapis: ^13.0.0
  github_signin: ^0.0.8  # Or custom OAuth flow
  # iCloud uses native iOS APIs via method channel
```

---

## 3. Storage Structure

### 3.1 Remote File Layout

```
/Memoix/                          # Root folder (user-visible)
├── memoix_recipes.json           # All recipes (single file mode)
├── recipes/                      # Optional: split by course
│   ├── mains.json
│   ├── desserts.json
│   ├── drinks.json
│   └── ...
├── pizzas.json                   # Domain-specific collections
├── sandwiches.json
├── cheeses.json
├── cellar.json
├── smoking.json
├── modernist.json
└── .memoix_meta.json             # Metadata (last push timestamp, device ID)
```

### 3.2 Meta File Structure

```json
{
  "version": 1,
  "schemaVersion": 3,
  "bundleFormat": "single-file",
  "lastModified": "2025-12-22T10:30:00Z",
  "lastModifiedBy": "iPhone 15 Pro",
  "recipeCount": 247,
  "checksum": "sha256:abc123...",
  "domains": {
    "recipes": 180,
    "pizzas": 12,
    "sandwiches": 8,
    "cheeses": 15,
    "cellar": 22,
    "smoking": 5,
    "modernist": 5
  }
}
```

---

## 4. Sync Modes

### 4.1 Manual Mode (Default)

User explicitly taps Push or Pull buttons. No automatic operations.

**Best for:**
- Users who want full control
- Users with multiple devices editing simultaneously
- Users with limited data plans

### 4.2 Automatic Mode

Push/pull operations triggered at specific app lifecycle events.

| Trigger | Operation | Behavior |
|---------|-----------|----------|
| **App Open** | Pull | Smart pull (see below) |
| **Recipe Save** | Push | Upload changes after save (debounced 5s) |
| **Recipe Delete** | Push | Upload changes after delete |

**Smart Pull on App Open:**
1. Check if >5 minutes since last sync
2. If provider `supportsFastMetaCheck`: fetch remote `.memoix_meta.json`
   - If remote `lastModified` ≤ local → skip pull (no changes)
   - If remote `lastModified` > local → proceed with pull
3. If provider doesn't support fast meta check (GitHub): pull if >5 min

This avoids unnecessary downloads and merge churn on providers that support cheap meta checks.
| **Manual Refresh** | Pull | User pulls down to refresh on list screens |
| **App Background** | Push | Upload any pending changes before sleep |

**Best for:**
- Users with one primary device
- Users who want "it just works" behavior
- Users who trust last-write-wins

### 4.3 Conflict Handling (Simple)

Since we're not doing real-time sync, conflicts are rare but possible. Strategy: **Last-Write-Wins with Merge**

**On Pull:**
1. Compare remote `lastModified` with local
2. For each recipe (by UUID):
   - If remote-only: Add to local
   - If local-only: Keep local (push will upload it)
   - If both exist: Keep **newer** based on recipe's `updatedAt` timestamp

**On Push:**
1. Always overwrite remote with local state
2. Update `.memoix_meta.json` timestamp

**No conflict UI** — the app silently applies the above rules. Users can always manually push to force their local state to remote.

**User-Facing Language:**
Add this explanation in the UI (tooltip or info icon on sync settings):
> "When the same recipe is edited on multiple devices, the most recently saved version is kept."

This preempts confusion before it happens.

---

## 5. User Experience

### 5.1 Settings Screen Entry Point

**Location:** Settings → External Storage

```
┌─────────────────────────────────────┐
│ External Storage                    │
│                                     │
│ Store your recipes in a location    │
│ you control. Your data never        │
│ touches Memoix servers.             │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🔗 Google Drive      Connect  → │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ 🐙 GitHub            Connect  → │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ ☁️ iCloud            Connect  → │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ─────────────────────────────────── │
│                                     │
│ Only one storage location can be    │
│ connected at a time.                │
│                                     │
└─────────────────────────────────────┘
```

### 5.2 Connection Flow (Google Drive Example)

```
1. User taps "Connect" on Google Drive
   ↓
2. OAuth consent screen (Google-hosted)
   - Scope: drive.file (app-created files only)
   ↓
3. Success → Folder Selection Dialog
   ┌─────────────────────────────────┐
   │ Choose Storage Location         │
   │                                 │
   │ ○ Create new folder "Memoix"   │
   │ ○ Use existing folder:         │
   │   📁 My Drive                  │
   │     📁 Recipes                 │
   │     📁 Cooking                 │
   │     📁 Memoix  ←── (detected)  │
   │                                 │
   │        [ Cancel ]  [ Select ]  │
   └─────────────────────────────────┘
   ↓
4. Sync Mode Selection
   ┌─────────────────────────────────┐
   │ Choose Sync Behavior            │
   │                                 │
   │ ○ Automatic                    │
   │   Sync when you open the app   │
   │   or save a recipe.            │
   │                                 │
   │ ○ Manual                       │
   │   Only sync when you tap       │
   │   Push or Pull.                │
   │                                 │
   │        [ Cancel ]  [ Done ]    │
   └─────────────────────────────────┘
   ↓
5. Initial Sync Prompt (if folder has data)
   ┌─────────────────────────────────┐
   │ Existing Data Found             │
   │                                 │
   │ Found 312 recipes in this       │
   │ folder. What would you like     │
   │ to do?                          │
   │                                 │
   │ ○ Pull: Import these recipes   │
   │ ○ Push: Overwrite with local   │
   │ ○ Skip: I'll sync later        │
   │                                 │
   │              [ Continue ]       │
   └─────────────────────────────────┘
   ↓
6. Connected state shown in Settings
```

### 5.3 Connected State UI

```
┌─────────────────────────────────────┐
│ External Storage                    │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🔗 Google Drive                 │ │
│ │    /My Drive/Memoix             │ │
│ │    Last synced: 2 hours ago     │ │
│ │                                 │ │
│ │  Sync Mode: Automatic      [⚙] │ │
│ │                                 │ │
│ │  ┌────────┐  ┌────────┐        │ │
│ │  │  Push  │  │  Pull  │        │ │
│ │  └────────┘  └────────┘        │ │
│ │                                 │ │
│ │  [ Disconnect ]                 │ │
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### 5.4 Sync Status Indicator

When automatic mode is enabled, show subtle sync status in the app:

**App Bar (during sync):**
```
┌─────────────────────────────────────┐
│ ☰  Recipes              ↻ Syncing  │
└─────────────────────────────────────┘
```

**App Bar (idle):**
```
┌─────────────────────────────────────┐
│ ☰  Recipes                    ☁️✓  │
└─────────────────────────────────────┘
```

**App Bar (error):**
```
┌─────────────────────────────────────┐
│ ☰  Recipes                    ☁️⚠  │
└─────────────────────────────────────┘
```
Tapping the icon opens External Storage settings.

---

## 6. Push/Pull Semantics

### 6.1 Push (Local → Remote)

**Trigger:** 
- Manual: User taps Push button
- Automatic: After recipe save/delete (debounced 5s), app backgrounding

**Behavior:**
1. Serialize all local recipes to JSON
2. Upload to connected storage, **overwriting** existing files
3. Update `.memoix_meta.json` with timestamp and device ID
4. Show subtle confirmation (automatic) or dialog (manual)

**Manual Confirmation Dialog:**
```
┌─────────────────────────────────────┐
│ Push to Google Drive?               │
│                                     │
│ This will upload 247 recipes to:    │
│ /My Drive/Memoix                    │
│                                     │
│ ⚠️ This will overwrite any          │
│ existing recipes in that location.  │
│                                     │
│      [ Cancel ]  [ Push Now ]       │
└─────────────────────────────────────┘
```

### 6.2 Pull (Remote → Local)

**Trigger:**
- Manual: User taps Pull button
- Automatic: App open, pull-to-refresh on list screens

**Behavior:**
1. Download JSON from connected storage
2. Read `.memoix_meta.json` to check for changes
3. Parse and validate recipe data
4. **Merge** into local database:
   - New recipes (by UUID): Add
   - Existing recipes: Keep newer (by `updatedAt`)
   - Local-only recipes: Keep (not deleted)
5. Show summary (manual) or subtle indicator (automatic)

**Manual Confirmation Dialog:**
```
┌─────────────────────────────────────┐
│ Pull from Google Drive?             │
│                                     │
│ Found 312 recipes in:               │
│ /My Drive/Memoix                    │
│                                     │
│ New recipes will be added.          │
│ Conflicts resolved by newest wins.  │
│                                     │
│      [ Cancel ]  [ Pull Now ]       │
└─────────────────────────────────────┘
```

**Post-Pull Summary (Manual):**
```
┌─────────────────────────────────────┐
│ Pull Complete                       │
│                                     │
│ ✓ 65 new recipes added              │
│ ✓ 12 recipes updated                │
│ ○ 170 recipes unchanged             │
│                                     │
│           [ Done ]                  │
└─────────────────────────────────────┘
```

### 6.3 Automatic Sync Behavior

| Event | Action | UI Feedback |
|-------|--------|-------------|
| App launched | Pull (if >5 min since last) | Spinner in app bar |
| Recipe saved | Push (debounced 5s) | Brief "Saved ☁️" snackbar |
| Recipe deleted | Push (debounced 5s) | Brief "Deleted ☁️" snackbar |
| Pull-to-refresh | Pull | Standard refresh indicator |
| App backgrounded | Push if pending | None (silent) |
| Network restored | Retry pending ops | Brief indicator |

**Debouncing:** Multiple saves within 5 seconds are batched into a single push.

**Failure Handling:** 
- Silent retry up to 3 times
- After 3 failures, show persistent indicator
- User can manually retry from Settings

---

## 7. Provider-Specific Implementation

### 7.1 Google Drive

```dart
class GoogleDriveStorage implements ExternalStorageProvider {
  static const scopes = [DriveApi.driveFileScope]; // App-created files only
  
  Future<void> connect() async {
    final account = await GoogleSignIn(scopes: scopes).signIn();
    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    _driveApi = DriveApi(client);
  }
  
  Future<void> push(RecipeBundle bundle) async {
    final folder = await _getOrCreateMemoixFolder();
    await _uploadFile(folder, 'memoix_recipes.json', bundle.toJson());
    await _uploadFile(folder, '.memoix_meta.json', _createMeta());
  }
  
  Future<RecipeBundle> pull() async {
    final folder = await _findMemoixFolder();
    final content = await _downloadFile(folder, 'memoix_recipes.json');
    return RecipeBundle.fromJson(content);
  }
  
  Future<StorageMeta?> getMeta() async {
    final folder = await _findMemoixFolder();
    try {
      final content = await _downloadFile(folder, '.memoix_meta.json');
      return StorageMeta.fromJson(content);
    } catch (_) {
      return null;
    }
  }
}
```

### 7.2 GitHub

```dart
class GitHubStorage implements ExternalStorageProvider {
  // OAuth flow returns personal access token with 'repo' scope
  
  Future<void> connect() async {
    final token = await _performOAuthFlow();
    _client = GitHub(auth: Authentication.withToken(token));
    
    // User selects or creates repo
    final repo = await _selectRepository();
    _repoSlug = repo.slug;
  }
  
  Future<void> push(RecipeBundle bundle) async {
    // Get current file SHA if exists (required for update)
    String? sha;
    try {
      final existing = await _client.repositories.getContents(
        _repoSlug, 'memoix_recipes.json'
      );
      sha = existing.sha;
    } catch (_) {}
    
    // Commit to main branch
    await _client.repositories.createFile(
      _repoSlug,
      CreateFile(
        path: 'memoix_recipes.json',
        content: base64Encode(utf8.encode(bundle.toJson())),
        message: 'Memoix: ${DateTime.now().toIso8601String()}',
        sha: sha,
      ),
    );
  }
  
  Future<RecipeBundle> pull() async {
    final content = await _client.repositories.getContents(
      _repoSlug, 'memoix_recipes.json'
    );
    final decoded = utf8.decode(base64Decode(content.content!));
    return RecipeBundle.fromJson(decoded);
  }
}
```

### 7.3 iCloud Drive

```dart
class ICloudStorage implements ExternalStorageProvider {
  // iOS only - uses CloudKit container
  
  Future<void> connect() async {
    // No OAuth needed - uses device's iCloud account
    final available = await _checkICloudAvailable();
    if (!available) throw ICloudNotConfiguredException();
  }
  
  Future<void> push(RecipeBundle bundle) async {
    final container = await _getICloudContainer();
    final file = File('${container.path}/Memoix/memoix_recipes.json');
    await file.create(recursive: true);
    await file.writeAsString(bundle.toJson());
    // iOS automatically syncs to iCloud Drive
  }
  
  Future<RecipeBundle> pull() async {
    final container = await _getICloudContainer();
    final file = File('${container.path}/Memoix/memoix_recipes.json');
    if (!await file.exists()) throw FileNotFoundException();
    final content = await file.readAsString();
    return RecipeBundle.fromJson(content);
  }
}
```

---

## 8. Sync Service Architecture

### 8.1 Core Service

```dart
class ExternalStorageService {
  final ExternalStorageProvider? _provider;
  final Ref _ref;
  
  Timer? _pushDebouncer;
  bool _isPushing = false;
  bool _isPulling = false;
  
  /// Called on app startup
  Future<void> onAppLaunched() async {
    if (!isConnected || !isAutomaticMode) return;
    
    final lastSync = await _getLastSyncTime();
    if (DateTime.now().difference(lastSync) > Duration(minutes: 5)) {
      await pull(silent: true);
    }
  }
  
  /// Called after recipe save/delete
  void onRecipeChanged() {
    if (!isConnected || !isAutomaticMode) return;
    
    _pushDebouncer?.cancel();
    _pushDebouncer = Timer(Duration(seconds: 5), () {
      push(silent: true);
    });
  }
  
  /// Called when app goes to background
  Future<void> onAppBackgrounded() async {
    if (!isConnected || !isAutomaticMode) return;
    
    _pushDebouncer?.cancel();
    if (_hasPendingChanges) {
      await push(silent: true);
    }
  }
  
  Future<void> push({bool silent = false}) async {
    if (_isPushing) return;
    _isPushing = true;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.pushing;
    
    try {
      final bundle = await _createBundle();
      await _provider!.push(bundle);
      await _setLastSyncTime(DateTime.now());
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
      
      if (!silent) {
        MemoixSnackBar.showSuccess('Pushed ${bundle.recipeCount} recipes');
      }
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      if (!silent) {
        MemoixSnackBar.showError('Push failed: $e');
      }
    } finally {
      _isPushing = false;
    }
  }
  
  Future<PullResult> pull({bool silent = false}) async {
    if (_isPulling) return PullResult.skipped();
    _isPulling = true;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.pulling;
    
    try {
      final bundle = await _provider!.pull();
      final result = await _mergeBundle(bundle);
      await _setLastSyncTime(DateTime.now());
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
      
      if (!silent) {
        MemoixSnackBar.show(
          '${result.added} added, ${result.updated} updated'
        );
      }
      return result;
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      if (!silent) {
        MemoixSnackBar.showError('Pull failed: $e');
      }
      return PullResult.failed(e);
    } finally {
      _isPulling = false;
    }
  }
  
  Future<MergeResult> _mergeBundle(RecipeBundle bundle) async {
    final db = _ref.read(databaseProvider);
    int added = 0, updated = 0, unchanged = 0;
    
    for (final recipe in bundle.recipes) {
      final existing = await db.recipes.getByUuid(recipe.uuid);
      
      if (existing == null) {
        await db.recipes.put(recipe);
        added++;
      } else if (recipe.updatedAt.isAfter(existing.updatedAt)) {
        await db.recipes.put(recipe);
        updated++;
      } else {
        unchanged++;
      }
    }
    
    // Repeat for pizzas, sandwiches, etc.
    
    return MergeResult(added: added, updated: updated, unchanged: unchanged);
  }
}
```

### 8.2 App Lifecycle Integration

```dart
// In main.dart or app.dart
class _MemoixAppState extends ConsumerState<MemoixApp> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Trigger pull on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(externalStorageServiceProvider).onAppLaunched();
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(externalStorageServiceProvider).onAppBackgrounded();
    }
  }
}
```

### 8.3 Recipe Save Integration

```dart
// In recipe repository
Future<void> saveRecipe(Recipe recipe) async {
  await _db.recipes.put(recipe);
  
  // Notify external storage service
  _ref.read(externalStorageServiceProvider).onRecipeChanged();
}
```

---

## 9. Data Ownership Language

### 9.1 In-App Copy

**Settings Header:**
> "Your recipes are stored on your device. External Storage lets you back up to a location you own and control."

**Connection Screen:**
> "Memoix will request permission to create and read files in a folder you choose. We cannot access any other files in your [Google Drive/GitHub/iCloud]."

**Automatic Mode Explanation:**
> "When enabled, Memoix will automatically sync your recipes when you open the app or save changes. Your devices will stay up to date without manual action."

**Disconnect Confirmation:**
> "Disconnecting will not delete your recipes from [Google Drive]. You can reconnect anytime."

### 9.2 Privacy Policy Additions

```
External Storage Feature:

When you connect an external storage provider:
- We request only the minimum permissions needed to read/write 
  files in a folder you designate
- Your credentials are stored securely on your device
- Recipe data is transmitted directly between your device and 
  your storage provider
- Memoix servers never see or store your recipes
- You can revoke access anytime through your provider's 
  security settings

Automatic Sync:
- When enabled, sync occurs on app open, recipe save, and app close
- No background polling or always-on connections
- You can disable automatic sync at any time
```

---

## 10. Error Handling

### 10.1 Error States

| Error | User Message | Recovery |
|-------|--------------|----------|
| OAuth cancelled | "Connection cancelled" | Retry button |
| Token expired | "Please reconnect to [Provider]" | Re-auth flow |
| Network failure | "Couldn't reach [Provider]" | Retry button / auto-retry |
| File not found (pull) | "No Memoix data found in [folder]" | Suggest push first |
| Parse error | "Couldn't read recipe data" | Contact support |
| Quota exceeded | "[Provider] storage is full" | Link to provider |
| Rate limited | "Too many requests, retrying..." | Auto-retry with backoff |

### 10.2 Offline Behavior

**Manual Mode:**
- Push/Pull buttons disabled when offline
- Show "No internet connection" inline

**Automatic Mode:**
- Queue operations for when connectivity returns
- Show persistent "Pending sync" indicator
- Sync automatically when network available

---

## 11. File Structure

### 11.1 New Files

```
lib/features/external_storage/
├── external_storage.dart              # Feature barrel
├── models/
│   ├── recipe_bundle.dart             # Serialization model
│   ├── storage_meta.dart              # Meta file model
│   ├── sync_mode.dart                 # Manual/Automatic enum
│   ├── sync_status.dart               # Idle/Pushing/Pulling/Error
│   └── merge_result.dart              # Pull result stats
├── providers/
│   ├── external_storage_provider.dart # Abstract interface
│   ├── google_drive_storage.dart
│   ├── github_storage.dart
│   ├── icloud_storage.dart
│   └── external_storage_providers.dart # Riverpod providers
├── repository/
│   └── external_storage_repository.dart
├── screens/
│   ├── external_storage_screen.dart   # Settings entry
│   ├── provider_selector_screen.dart  # Choose provider
│   ├── folder_picker_screen.dart      # Select location
│   └── sync_mode_screen.dart          # Choose auto/manual
├── services/
│   ├── external_storage_service.dart  # Core sync logic
│   └── bundle_service.dart            # Export/import logic
└── widgets/
    ├── connected_provider_card.dart
    ├── push_pull_buttons.dart
    ├── sync_status_indicator.dart
    └── sync_mode_toggle.dart
```

### 11.2 Settings Integration

```dart
// In settings screen
ListTile(
  leading: Icon(Icons.cloud_outlined),
  title: Text('External Storage'),
  subtitle: _connectedProvider != null 
      ? Text('Connected to ${_connectedProvider.name}')
      : Text('Back up to your own cloud storage'),
  trailing: Icon(Icons.chevron_right),
  onTap: () => AppRoutes.toExternalStorage(context),
)
```

---

## 12. Future Considerations

**Not in v1, but possible later:**

1. **Multiple providers** — Allow backup to both Google Drive AND GitHub
2. **Scheduled sync** — Daily sync at a specific time
3. **Selective sync** — Sync only certain courses or domains
4. **Recipe versioning** — GitHub commits as version history
5. **Dropbox/OneDrive** — Additional providers based on demand
6. **Export formats** — JSON + PDF + Markdown bundles
7. **Deletion sync via tombstones** — Track deletions locally to prevent "zombie recipes":
   - Store `"deletedUuids": ["uuid1", "uuid2"]` in meta
   - On pull, ignore remote recipes older than their deletion timestamp
   - Auto-expire tombstones after 30 days
   - This prevents deleted recipes from reappearing without full deletion sync

---

## 13. Success Metrics

- % of users who connect external storage
- % who enable automatic mode vs manual
- Sync frequency per connected user
- Multi-device detection (same provider, different device IDs)
- Error rates by provider
- Disconnect rate (churn indicator)

---

## 14. Open Questions

1. **Single file vs. split files?** — One `memoix_recipes.json` or separate files per course/domain?
2. **Image handling?** — Store images in cloud or just recipe data? (Suggest: data only for v1)
3. **GitHub repo visibility?** — Require private repos or allow public (recipe sharing)?
4. **Deletion propagation?** — Should deleting on one device delete everywhere? (Suggest: no for v1)
5. **Large libraries?** — Performance with 1000+ recipes? **Use chunked parsing, not chunked files:**
   - Stream JSON parsing (don't load entire file into memory)
   - Batch DB writes (insert 50 recipes at a time)
   - Show progress indicator during large imports
   - Do NOT split into multiple files for performance — that's UX debt

---

*This document describes user-controlled backup with optional automatic triggers. It is not real-time sync. Users can enable automatic mode for convenience or stay manual for full control. Their data stays in storage they own.*
