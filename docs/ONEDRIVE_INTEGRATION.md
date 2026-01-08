# OneDrive Integration Implementation

## Overview
This document describes the OneDrive integration for Memoix, enabling users to sync recipes to their OneDrive account.

---

## Architecture

### Components Created

#### 1. GraphHttpClient (`lib/core/services/graph_http_client.dart`)
**Purpose:** HTTP client wrapper for Microsoft Graph API with automatic throttling handling.

**Features:**
- Automatic retry on 429 (Too Many Requests) responses
- Reads `Retry-After` header and waits specified duration
- Maximum 3 retry attempts with exponential backoff
- Auto-injects `Authorization: Bearer <token>` header
- Supports GET, POST, PUT, PATCH, DELETE methods

**Usage:**
```dart
final client = GraphHttpClient(accessToken);
final response = await client.get(Uri.parse('https://graph.microsoft.com/v1.0/me'));
```

---

#### 2. OneDriveStorage (`lib/features/external_storage/providers/one_drive_storage.dart`)
**Purpose:** Implementation of `CloudStorageProvider` interface for OneDrive.

**Features:**
- OAuth2 authentication via `flutter_appauth`
- Secure token storage via `flutter_secure_storage`
- Automatic token refresh when expired
- Folder creation and management
- File upload/download operations

**Implemented Methods:**
- `init()` - Restore previous session from secure storage
- `signIn()` - OAuth2 sign-in flow
- `signOut()` - Clear tokens and session
- `isConnected` - Check connection status (with auto-refresh)
- `createFolder(name)` - Create folder in OneDrive root
- `switchRepository(folderId, name)` - Switch active folder
- `uploadFile(fileName, content)` - Upload file to active folder
- `downloadFile(fileName)` - Download file from active folder

**Microsoft Graph API Endpoints Used:**
- `/me/drive/root/children` - Create folder
- `/me/drive/items/{folderId}` - Verify folder access
- `/me/drive/items/{folderId}:/{fileName}:/content` - Upload/download files

---

#### 3. AppConfig (`lib/config/app_config.dart`)
**Purpose:** Configuration provider for OneDrive OAuth credentials.

**Configuration:**
Add to `.env` file:
```env
ONEDRIVE_CLIENT_ID=your-azure-app-client-id
ONEDRIVE_REDIRECT_URI=memoix://oauth/callback  # Optional, has default
```

**Default Redirect URI:** `memoix://oauth/callback`

---

## Setup Instructions

### 1. Azure App Registration
Register the app in Azure Portal to get the Client ID:

1. Go to [Azure Portal > App Registrations](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps)
2. Click "New registration"
3. **Name:** Memoix
4. **Supported account types:** Personal Microsoft accounts only
5. **Redirect URI:** 
   - Platform: Mobile and desktop applications
   - URI: `memoix://oauth/callback`
6. Click "Register"
7. Copy the **Application (client) ID**

### 2. Configure API Permissions
1. Go to "API permissions"
2. Click "Add a permission" > "Microsoft Graph" > "Delegated permissions"
3. Add:
   - `Files.ReadWrite` - Read and write user files
   - `Files.ReadWrite.All` - Full access to user files
   - `User.Read` - Sign in and read user profile
   - `offline_access` - Maintain access to data
4. Click "Grant admin consent" (if required)

### 3. Update .env File
Add the Client ID to your `.env` file:
```env
ONEDRIVE_CLIENT_ID=your-client-id-from-azure
```

### 4. Configure Platform-Specific Settings

#### Android (`android/app/src/main/AndroidManifest.xml`)
Add inside `<application>` tag:
```xml
<activity android:name="net.openid.appauth.RedirectUriReceiverActivity">
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="memoix" android:host="oauth" android:path="/callback"/>
    </intent-filter>
</activity>
```

#### iOS (`ios/Runner/Info.plist`)
Add before `</dict>`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>memoix</string>
        </array>
    </dict>
</array>
```

---

## Dependencies Added

```yaml
dependencies:
  flutter_appauth: ^6.0.2          # OAuth2 authentication
  flutter_secure_storage: ^9.0.0   # Secure token storage
  http: ^1.2.0                      # Already present
```

---

## Usage Example

```dart
// Initialize provider
final oneDrive = OneDriveStorage();
await oneDrive.init();

// Sign in
if (!await oneDrive.isConnected) {
  await oneDrive.signIn();
}

// Create repository folder
final folderId = await oneDrive.createFolder('My Recipes');

// Switch to folder
await oneDrive.switchRepository(folderId, 'My Recipes');

// Upload file
await oneDrive.uploadFile('recipes.json', jsonContent);

// Download file
final content = await oneDrive.downloadFile('recipes.json');

// Sign out
await oneDrive.signOut();
```

---

## Integration with Existing System

### 1. Update RepositoryManager
When creating a repository with OneDrive:
```dart
await repositoryManager.addRepository(
  name: 'My OneDrive Recipes',
  folderId: folderId,
  provider: StorageProvider.oneDrive,  // Use enum
);
```

### 2. Provider Selection Logic
In `setActiveRepository`, implement provider switching:
```dart
final activeRepo = await manager.getActiveRepository();

switch (activeRepo.provider) {
  case StorageProvider.googleDrive:
    // Use GoogleDriveStorage (existing)
    break;
  case StorageProvider.oneDrive:
    final oneDrive = OneDriveStorage();
    await oneDrive.init();
    await oneDrive.switchRepository(
      activeRepo.folderId,
      activeRepo.name,
    );
    break;
}
```

---

## Security Considerations

### Token Storage
- Access tokens stored in `FlutterSecureStorage` (encrypted)
- On Android: Uses Keystore
- On iOS: Uses Keychain
- Tokens never logged or exposed

### Permissions
- Uses least-privilege principle
- Only requests `Files.ReadWrite` scope
- No admin consent required for personal accounts

### Throttling
- Respects Microsoft's rate limits (429 responses)
- Automatic retry with `Retry-After` header
- Maximum 3 attempts to prevent infinite loops

---

## Error Handling

Common errors and solutions:

### "OneDrive Client ID not configured"
**Cause:** Missing `ONEDRIVE_CLIENT_ID` in .env  
**Solution:** Add Client ID from Azure Portal to .env

### "Sign in was cancelled by user"
**Cause:** User closed OAuth window  
**Solution:** Retry sign-in or show user-friendly message

### "Token refresh failed"
**Cause:** Refresh token expired (90 days)  
**Solution:** Prompt user to sign in again

### "429 Too Many Requests"
**Cause:** Rate limit exceeded  
**Solution:** GraphHttpClient handles automatically with retry

---

## Testing Checklist

- [ ] Sign in flow completes successfully
- [ ] Access token stored securely
- [ ] Token auto-refreshes when expired
- [ ] Folder creation works
- [ ] File upload/download works
- [ ] Throttling retry works (simulate 429)
- [ ] Sign out clears all tokens
- [ ] Reconnect after app restart works
- [ ] Works on Android
- [ ] Works on iOS
- [ ] Works on Windows/macOS/Linux (desktop)

---

## Next Steps

1. **Integrate with ExternalStorageProvider:**
   - Implement `push()` and `pull()` methods using RecipeBundle
   - Add support for metadata files
   - Implement smart sync with meta checks

2. **UI Updates:**
   - Add OneDrive option to storage provider selection
   - Show OneDrive icon/branding
   - Handle provider-specific error messages

3. **Migration Support:**
   - Allow users to copy data between Google Drive and OneDrive
   - Implement provider switching wizard

4. **Advanced Features:**
   - Conflict resolution for multi-device sync
   - Selective sync (choose which recipe types to sync)
   - Share repository with other OneDrive users

---

## References

- [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/overview)
- [OneDrive API Reference](https://learn.microsoft.com/en-us/graph/api/resources/onedrive)
- [flutter_appauth Documentation](https://pub.dev/packages/flutter_appauth)
- [Azure App Registration Guide](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
