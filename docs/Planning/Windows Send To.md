## Audit Findings

### 1. Windows Runner — Command-Line Argument Handling

**main.cpp** — completely stock Flutter template:
- `GetCommandLineArguments()` in utils.cpp calls `CommandLineToArgvW` + `GetCommandLineW`, skips argv[0] (binary name), converts remaining args to UTF-8
- The resulting `std::vector<std::string>` is passed to `project.set_dart_entrypoint_arguments()` — meaning they land in `PlatformDispatcher.instance.defaultRouteName` / `dart:io`'s `Platform.executableArguments`, **not** on a MethodChannel
- **No MethodChannel plugin or channel code** exists in the Windows runner whatsoever
- **No IPC / single-instance mechanism** (no named mutex, no named pipe, no WM_COPYDATA)

### 2. Windows Registry — Protocol/File Associations

**None registered anywhere** in the runner or CMakeLists:
- No registry writes in any `.cpp` file
- No `.reg` file, no installer script, no `Runner.rc` association
- No `AppUserModelID` or `ProgId` registration

### 3. Import Entry Points (confirmed from Android audit)

| Import type | Entry point | Navigation |
|---|---|---|
| **URL import** | `URLImportScreen` | `AppRoutes.toURLImport()` → `AppShellNavigator.navigatorKey` push |
| **Text import** | `AiImportScreen` | `AppRoutes.toAiImport()` → same navigator |
| **Image/AI import** | `AiImportScreen` | `AppRoutes.toAiImport()` |
| **OCR import** | `OCRScannerScreen` | `AppRoutes.toOCRScanner()` |
| **QR/deep link** | `DeepLinkService` | `AppRoutes.toQRScanner()` / deep-link routing |

All four are navigated using `AppShellNavigator.navigatorKey` (inner shell navigator), not `rootNavigatorKey`. However, **`ShareHandlerService` already uses `rootNavigatorKey`** and pushes `MaterialPageRoute` directly — bypassing the shell navigator — which is exactly what the Android handler does.

### 4. ShareHandlerService — Current Platform Coverage

- **Channel name:** `memoix/share` (MethodChannel)
- **Method called by native side:** `onShareReceived` with `{type, content/path}`
- **Type routing:** `"url"` → URL import logic, `"text"` → AI text, `"image"` → AI or OCR
- **Pending event buffer:** queued if navigator not ready, drained in `initialize()`
- **Platform guard:** **none** — the service sets up the MethodChannel unconditionally on all platforms. On Windows it simply has no C++ side sending anything, so it's a no-op
- **Initialized at:** `_DeepLinkWrapperState.initState` post-frame callback in app.dart

---

## Planned Changes

### Windows C++ (new files + edits)

**New file: `windows/runner/registry_handler.h` / `registry_handler.cpp`**
- `RegisterFileAssociations()` — writes to `HKCU\Software\Classes\` for `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`; no-ops if already registered
- No URL scheme registration (avoids touching default browser)

**New file: `windows/runner/single_instance.h` / `single_instance.cpp`**
- Named mutex (`Local\MemoixSingleInstance`) to detect if already running
- Named pipe (`\\.\pipe\MemoixIPC`) for the second instance to send its argv to the first
- First instance pumps the pipe in `OnCreate` and handles incoming file paths

**Edit: flutter_window.h / flutter_window.cpp**
- Add `flutter::MethodChannel<flutter::EncodableValue>* share_channel_` member
- In `OnCreate()`: instantiate the MethodChannel on `flutter_controller_->engine()->messenger()`, store it
- Add `SendShareEvent(type, content/path)` helper that invokes `"onShareReceived"`

**Edit: main.cpp**
- After `GetCommandLineArguments()`: inspect args for a file path (extension check) or URL
- If already running (mutex exists): send via named pipe and exit
- If first instance: register associations, set up pipe server in a background thread

### Registry keys written (HKCU only, no admin required)

```
HKCU\Software\Classes\.jpg\OpenWithProgids\MemoixImage  = ""
HKCU\Software\Classes\.jpeg\OpenWithProgids\MemoixImage = ""
HKCU\Software\Classes\.png\OpenWithProgids\MemoixImage  = ""
HKCU\Software\Classes\.gif\OpenWithProgids\MemoixImage  = ""
HKCU\Software\Classes\.webp\OpenWithProgids\MemoixImage = ""
HKCU\Software\Classes\MemoixImage\shell\open\command    = "<exe path> \"%1\""
HKCU\Software\Classes\MemoixImage\DefaultIcon           = "<exe path>,0"
HKCU\Software\Classes\MemoixImage (default)             = "Memoix Recipe Image"
```

No `HKLM` writes. No URL/protocol registration (http/https left to the browser).

### Dart side (share_handler_service.dart)

Single change: wrap the `_channel.setMethodCallHandler` call with `if (Platform.isAndroid || Platform.isWindows)` to make the intent explicit (currently it's unconditional, which is harmless but not intentional for Windows).

---

**Confirm to proceed with implementation.**