# Shared Repository Implementation Status

## Overview
This document tracks the implementation of the Shared Repository feature, which allows multiple users to collaborate on a shared Google Drive folder containing recipes.

## Completed Components

### 1. Data Model
✅ **File:** `lib/features/external_storage/models/drive_repository.dart`
- DriveRepository class with fields:
  - `id` (String) - Unique identifier (UUID)
  - `name` (String) - User-friendly repository name
  - `folderId` (String) - Google Drive folder ID
  - `isActive` (bool) - Whether this is the currently active repository
  - `isPendingVerification` (bool) - True when added offline, needs verification
  - `createdAt` (DateTime) - When the repository was added
  - `lastVerified` (DateTime?) - When access was last confirmed
- JSON serialization support

### 2. Repository Manager
✅ **File:** `lib/features/external_storage/services/repository_manager.dart`
- Methods:
  - `loadRepositories()` - Load all repositories from SharedPreferences
  - `saveRepositories()` - Persist repositories to SharedPreferences
  - `getActiveRepository()` - Get the currently active repository
  - `setActiveRepository()` - Switch which repository is active
  - `addRepository()` - Add a new repository (either verified or pending)
  - `removeRepository()` - Remove a repository from the device
  - `markAsVerified()` - Mark a pending repository as verified
  - `folderIdExists()` - Check if a folder ID is already registered

### 3. Google Drive API Integration
✅ **File:** `lib/features/external_storage/providers/google_drive_storage.dart`
- Added methods:
  - `addPermission(folderId, email)` - Grant Editor (writer) access to a user by email
    - Sends Google Drive invitation email automatically
    - Error handling for 400 (invalid email), 403 (permission denied), 404 (not found)
  - `verifyFolderAccess(folderId)` - Check if the current user can access a folder
    - Returns `true` if accessible
    - Returns `false` if 403 (access denied) or 404 (not found)
    - Throws exception for network errors (used to detect offline state)

### 4. Share Repository Screen
✅ **File:** `lib/features/external_storage/screens/share_repository_screen.dart`
- Features:
  - Repository info card showing name
  - **Invite by Email section:**
    - Email input field with validation
    - "Invite" button that calls `addPermission()`
    - Loading state while inviting
    - Success/error feedback
  - **Share Link section:**
    - "Share Link" button - Opens system share dialog with deep link
    - "Copy Link" button - Copies deep link to clipboard
    - Generates link format: `memoix://share/repo?id={folderId}&name={encodedName}`
  - Info box explaining how sharing works

### 5. Repository Management Screen
✅ **File:** `lib/features/external_storage/screens/repository_management_screen.dart`
- Features:
  - List of all repositories
  - Repository cards showing:
    - Name with "ACTIVE" badge for current repository
    - Verification status (verified or pending)
    - Last verified date
  - Actions:
    - **Switch** - Make a repository active
    - **Share** - Navigate to ShareRepositoryScreen
    - **Verify** - Manually check access for pending repositories
    - **Remove** - Delete repository from device (doesn't delete Drive folder)
  - Empty state when no repositories exist
  - "Create Repository" button in app bar (UI only - needs backend implementation)

### 6. Deep Link Handling
✅ **File:** `lib/core/services/deep_link_service.dart`
- Updated to handle `memoix://share/repo?id=X&name=Y` links
- Three scenarios:
  - **Scenario A (200 OK - Verified Access):**
    - Calls `verifyFolderAccess()` successfully
    - Adds repository with `isPendingVerification=false`
    - Shows dialog: "Joined {Name}! Switch to this repository now?"
    - Option to switch immediately or keep current active
  - **Scenario B (403 Forbidden - Access Denied):**
    - Shows dialog: "You don't have access. Ask owner to invite your email."
    - Repository NOT added to device
  - **Scenario C (Network Error - Offline):**
    - Adds repository with `isPendingVerification=true`
    - Shows dialog: "Repository saved but could not be verified. Will check when online."
    - User can manually verify later via Repository Management screen

### 7. Navigation & Routing
✅ **File:** `lib/app/routes/router.dart`
- Added routes:
  - `toRepositoryManagement(context)` - Opens repository list
  - `toShareRepository(context, repository)` - Opens share screen for a specific repository

✅ **File:** `lib/features/settings/screens/settings_screen.dart`
- Added "Repositories" tile in Backup section
- Located below "External Storage" tile
- Icon: `folder_shared_outlined`
- Navigates to Repository Management screen

## Pending Implementation

### 1. Google Drive Folder Creation
⏳ **File:** `lib/features/external_storage/providers/google_drive_storage.dart`
- Need to add `createFolder(String name)` method
- Should create a new folder in Google Drive root (or specific location)
- Return the folder ID
- Used by "Create Repository" button in Repository Management screen

### 2. Multi-Repository Support in GoogleDriveStorage
⏳ **File:** `lib/features/external_storage/providers/google_drive_storage.dart`
- Currently uses a single `_folderId` field
- Need to refactor to use active repository from RepositoryManager
- Update `_ensureFolderId()` to:
  ```dart
  Future<String> _ensureFolderId() async {
    final manager = RepositoryManager();
    final activeRepo = await manager.getActiveRepository();
    
    if (activeRepo != null) {
      return activeRepo.folderId;
    }
    
    // Fallback to existing behavior (create/find default folder)
    // ...existing code...
  }
  ```
- This allows switching between repositories without disconnect/reconnect

### 3. Repository Verification on App Start
⏳ **Location:** TBD (possibly in app initialization or settings screen)
- On app startup, check for repositories with `isPendingVerification=true`
- Attempt to verify access if online
- Mark as verified if successful, or show notification if access denied

### 4. Background Access Verification
⏳ **Optional Enhancement**
- Periodically verify access to all repositories (e.g., daily)
- Update `lastVerified` timestamp
- Notify user if access is lost (owner revoked permission)

### 5. Repository Deletion Workflow
⏳ **Enhancement**
- Consider adding option to delete the Google Drive folder when removing repository
- Would require calling Drive API to delete folder
- Should prompt user: "Remove from device only" vs "Remove and delete from Google Drive"

## Testing Checklist

### Host Side (Sharing a Repository)
- [ ] Create a new repository
- [ ] Invite a user by email
  - [ ] Verify Google sends invitation email
  - [ ] Test with invalid email format
  - [ ] Test with email that doesn't exist
- [ ] Generate and copy deep link
- [ ] Share deep link via system share dialog
- [ ] Verify link format is correct

### Guest Side (Joining a Repository)
- [ ] Receive deep link while online
  - [ ] Verify access check succeeds
  - [ ] Confirm join dialog appears
  - [ ] Test switching to new repository
- [ ] Receive deep link while offline
  - [ ] Verify repository added with pending status
  - [ ] Confirm verification message shown
  - [ ] Test manual verification later
- [ ] Receive link without permission
  - [ ] Verify access denied message
  - [ ] Confirm repository NOT added

### Repository Management
- [ ] View list of repositories
- [ ] Switch active repository
  - [ ] Verify recipes load from new folder
- [ ] Share a repository
  - [ ] Navigate to share screen
  - [ ] Invite user
  - [ ] Copy/share link
- [ ] Verify pending repository
  - [ ] Test success case
  - [ ] Test failure case (no access)
- [ ] Remove a repository
  - [ ] Verify confirmation dialog
  - [ ] Confirm repository removed from list
  - [ ] Verify Google Drive folder still exists

### Deep Link Handling
- [ ] Test link while app is closed (cold start)
- [ ] Test link while app is running (warm)
- [ ] Test link with special characters in repository name
- [ ] Test link with very long repository name
- [ ] Test malformed links (missing parameters)

## Known Limitations

1. **Repository Creation:** Currently shows a placeholder message - needs backend implementation
2. **Single Active Repository:** Only one repository can be active at a time (by design)
3. **No Permission Revocation:** Must revoke access via Google Drive web interface
4. **No Offline Invites:** Cannot invite users while offline (Drive API required)
5. **No Repository Renaming:** Folder name on Drive is used as-is

## Security Considerations

✅ **Implemented:**
- Email validation before adding permission
- Folder access verification before joining
- Offline-safe repository adds (pending verification)
- User confirmation before joining repository
- Error messages don't expose sensitive folder IDs

⏳ **Future Considerations:**
- Rate limiting on permission requests (prevent spam invites)
- Audit log of permission changes
- Warning when repository owner changes
- Encrypted repository metadata storage

## Architecture Notes

### Repository Storage
- Repositories stored in SharedPreferences as JSON array
- Key: `drive_repositories`
- Active repository marked with `isActive: true` (only one per device)

### Folder ID vs Repository ID
- **Folder ID:** Google Drive folder identifier (provided by Drive API)
- **Repository ID:** Local UUID for the repository record (allows multiple devices to have different IDs for same folder)

### Permission Model
- Uses Google Drive native permissions (role: 'writer' = Editor)
- Permissions managed through Drive API, not custom system
- Owner can revoke via Drive web interface

### Offline Behavior
- Repository joins work offline (provisional add)
- Verification deferred until online
- User can manually retry verification
- No false "access denied" if truly offline

## Migration Path

If existing users have data in the single-folder setup:
1. On first launch with multi-repository support, detect existing `_folderId` in SharedPreferences
2. Create a default repository: `DriveRepository(name: 'My Recipes', folderId: existingId, isActive: true)`
3. Save to repository list
4. Clear old `_folderId` preference key
5. User seamlessly continues with their data in the new system

## Future Enhancements

- **Repository Templates:** Pre-configured repositories (e.g., "Family Recipes", "Meal Prep")
- **Permission Levels:** Read-only access (viewer role) in addition to editor
- **Folder Organization:** Nested folders for different recipe types
- **Conflict Resolution:** Handle simultaneous edits by multiple users
- **Change Notifications:** Notify when repository contents updated by others
- **Batch Operations:** Invite multiple users at once
- **QR Code Sharing:** Generate QR codes for repository links (for in-person sharing)
