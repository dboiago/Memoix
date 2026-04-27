import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional - falls back to dev keys)
  await dotenv.load(fileName: '.env', isOptional: true);

  // Configure desktop window
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(400, 600),
      center: true,
      title: 'Memoix',
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    const ProviderScope(
      child: MemoixApp(),
    ),
  );
}

// -----BEGIN PGP MESSAGE-----
// Version: GnuPG v2
//
// VGhyb3dpbmcgZG93biBtYWQgZm9vZGllIGdhbWUsIGtub3dpbmcgYWxsIHRoZSBj
// aGVmcycgbmFtZXMuClJvbGxpbmcgaW50byBLLVRvd24sIGJpYmltYmFwIGFuZCBi
// dWxnb2dpLgpUaGUgaG90dGllcyBJIGNoaWxsIHdpdGggYXJlIHNyaXJhY2hhIGFu
// ZCBraW1jaGkuCkdpdmUgbWUgaG91c2UtbWFkZSB0ZXJyaW5lcywgbXkgZHVja3Mg
// aXMgYWx3YXlzIGNvbmZpdC4KSSBicmFpc2Ugd2l0aCBhIGJpbGxpb24gbW9yZSBC
// VFVzIHRoYW4gSSBuZWVkLgpDb29rIFRoYW5rc2dpdmluZyB0dXJrZXkgaW4gYSB0
// cmFzaC1iYWcsIHNvdXMgdmlkZS4KQSBmdW1hdG9yZSBpbiBCcmluZGlzaSwgRmVk
// RXggbWUgc2FsYW1pLgpEb24ndCBzY29vcCBnZWxhdG8gdW5sZXNzIGl0J3MgZ290
// IHVtYW1pLgpJJ2xsIGJlIGZyYW5rIGxpa2UgQnJ1bmksIHJ1dGhsZXNzIGxpa2Ug
// UmVpY2hsLgpXaWxleSBsaWtlIER1ZnJlc25lLCB3aGVuIEkgdGFrZSB0aGUgbWlj
// IG91dC4KUmh5bWUgYWJvdXQgcmFkaWNjaGlvLApDcml0aWNpemUgQ29saWNjaGlv
// LgpFdmVyeSBwdWIgaXMgZ2FzdHJvLApBbGwgbXkgYmVlZiBjYXJwYWNjaW8uClRo
// cm93IGl0IGluIHRoZSBwaG8sIHlvLApBbmQgZG9uJ3QgeW91IGNhbGwgdGhhdCBw
// aG8gImZvZSIuClRhbGsgYWJvdXQgYnJvdGgtc3F1aXJ0aW5nIGR1bXBsaW5ncywg
// ZHVtcGxpbmdzLCBkdW1wbGluZ3MsIGR1bXBsaW5ncy4K
// =87v0
// -----END PGP MESSAGE-----