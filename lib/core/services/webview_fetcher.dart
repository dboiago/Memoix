import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Fetches HTML content using a headless WebView.
/// 
/// This is used as a fallback when normal HTTP requests fail with 403
/// due to bot detection. WebView uses the platform's native browser engine
/// which has a proper TLS fingerprint that sites accept.
class WebViewFetcher {
  /// Check if WebView is supported on the current platform
  static bool get isSupported {
    if (kIsWeb) return false; // Web doesn't support webview_flutter
    try {
      // WebView is only supported on Android and iOS
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Fetch HTML content from a URL using a headless WebView.
  /// 
  /// Returns the page's HTML content, or throws an exception on failure.
  /// The WebView is shown briefly but minimized to be nearly invisible.
  /// 
  /// Throws [UnsupportedError] if WebView is not supported on this platform.
  static Future<String> fetchHtml(BuildContext context, String url, {Duration timeout = const Duration(seconds: 15)}) async {
    if (!isSupported) {
      throw UnsupportedError('WebView is not supported on this platform (only Android/iOS)');
    }
    
    final completer = Completer<String>();
    
    late final WebViewController controller;
    late final OverlayEntry overlayEntry;
    
    // Create the controller
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String finishedUrl) async {
            // Wait a moment for any JS rendering
            await Future.delayed(const Duration(milliseconds: 500));
            
            try {
              // Extract the HTML
              final html = await controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML'
              );
              
              // Remove overlay
              overlayEntry.remove();
              
              if (!completer.isCompleted) {
                // The result comes back as a JSON-encoded string, need to decode it
                String htmlString = html.toString();
                // Remove surrounding quotes if present
                if (htmlString.startsWith('"') && htmlString.endsWith('"')) {
                  htmlString = htmlString.substring(1, htmlString.length - 1);
                }
                // Unescape the string
                htmlString = htmlString
                    .replaceAll(r'\n', '\n')
                    .replaceAll(r'\t', '\t')
                    .replaceAll(r'\"', '"')
                    .replaceAll(r"\'", "'")
                    .replaceAll(r'\\', '\\');
                
                completer.complete(htmlString);
              }
            } catch (e) {
              overlayEntry.remove();
              if (!completer.isCompleted) {
                completer.completeError(Exception('Failed to extract HTML: $e'));
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            overlayEntry.remove();
            if (!completer.isCompleted) {
              completer.completeError(Exception('WebView error: ${error.description}'));
            }
          },
        ),
      )
      ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
    
    // Create a tiny overlay to host the WebView (needed for it to work)
    // Position it off-screen so it's invisible to the user
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,  // Off-screen
        top: -10000,
        width: 1,
        height: 1,
        child: WebViewWidget(controller: controller),
      ),
    );
    
    // Insert the overlay
    Overlay.of(context).insert(overlayEntry);
    
    // Load the URL
    await controller.loadRequest(Uri.parse(url));
    
    // Set up timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        overlayEntry.remove();
        completer.completeError(TimeoutException('WebView fetch timed out after ${timeout.inSeconds}s'));
      }
    });
    
    return completer.future;
  }
}
