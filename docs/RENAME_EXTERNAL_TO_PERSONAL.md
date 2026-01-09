# Rename External Storage to Personal Storage - Migration Guide

## Overview
Rename `external_storage` to `personal_storage` throughout the codebase for better clarity and maintainability.

## Manual Steps Required

### 1. Rename Feature Folder
```bash
git mv lib/features/external_storage lib/features/personal_storage
```

### 2. Update Folder Structure
The following files/folders will automatically move:
- `lib/features/personal_storage/models/`
- `lib/features/personal_storage/providers/`
- `lib/features/personal_storage/screens/`
- `lib/features/personal_storage/services/`

### 3. Rename Key Files
```bash
cd lib/features/personal_storage/providers
git mv external_storage_provider.dart personal_storage_provider.dart

cd ../services
git mv external_storage_service.dart personal_storage_service.dart

cd ../screens
git mv external_storage_screen.dart personal_storage_screen.dart
```

## Code Changes Required

### Class/Interface Names
- `ExternalStorageProvider` → `PersonalStorageProvider`
- `ExternalStorageService` → `PersonalStorageService`  
- `ExternalStorageScreen` → `PersonalStorageScreen`
- `externalStorageServiceProvider` → `personalStorageServiceProvider`

### Import Paths
All imports must change from:
```dart
import '../features/external_storage/...'
```
to:
```dart
import '../features/personal_storage/...'
```

### Comments & Documentation
- Update all code comments referencing "external storage"
- File docstrings should reference "personal storage"
- Keep references to EXTERNAL_STORAGE.md (documentation file name doesn't need to change)

### DO NOT CHANGE (Backward Compatibility)
Keep these SharedPreferences keys unchanged to avoid breaking existing user data:
- `external_storage_last_sync`
- `external_storage_sync_mode`
- `external_storage_provider_id`
- `external_storage_path`

## Affected Files (59 files)

### Core Files
- `lib/app/app.dart` - imports and method names
- `lib/app/routes/router.dart` - imports and route methods
- `lib/core/services/deep_link_service.dart` - imports

### Repository Files (All features)
- `lib/features/*/repository/*_repository.dart` - imports and comments (7 files)

### Personal Storage Feature (All files in folder)
- All files in `lib/features/external_storage/` → `lib/features/personal_storage/`

### Settings
- `lib/features/settings/screens/settings_screen.dart` - already updated

### Documentation  
- `docs/EXTERNAL_STORAGE.md` - already updated with terminology note

## Testing Checklist
After renaming:
- [ ] App compiles without errors
- [ ] Existing users can still access their cloud connections
- [ ] Settings screen shows "Personal Storage"
- [ ] Repository management works
- [ ] Push/Pull operations function correctly
- [ ] SharedPreferences keys still work (last sync time, etc.)

## Rollback Plan
If issues occur:
```bash
git mv lib/features/personal_storage lib/features/external_storage
# Revert code changes
git checkout HEAD -- lib/
```
