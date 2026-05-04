import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// REQUIRED for accessing Android-specific WebViewController methods
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Fetches HTML content using a headless WebView.
/// 
/// This is used as a fallback when normal HTTP requests fail with 403, 503, or 429
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
  /// The WebView is rendered full-screen to bypass DataDome sizing checks, 
  /// but covered by an opaque loading overlay.
  /// 
  /// Throws [UnsupportedError] if WebView is not supported on this platform.
  static Future<String> fetchHtml(BuildContext context, String url, {Duration timeout = const Duration(seconds: 30)}) async {
    if (!isSupported) {
      throw UnsupportedError('WebView is not supported on this platform (only Android/iOS)');
    }

    // SECURITY: Validate URL scheme before creating any resources.
    // Only allow http:// and https:// to prevent local file access or XSS.
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw ArgumentError('Invalid URL format: unable to parse URL');
    }
    if (!uri.isScheme('http') && !uri.isScheme('https')) {
      throw ArgumentError(
        'Invalid URL scheme: "${uri.scheme}". Only HTTP and HTTPS URLs are allowed in WebView.',
      );
    }

    // Clear stale cookies from any previous (failed) session.
    await WebViewCookieManager().clearCookies();

    final completer = Completer<String>();
    
    late final WebViewController controller;
    late final OverlayEntry overlayEntry;
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-S908U) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/123.0.6312.40 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String finishedUrl) async {
            // Wait for JS challenges (e.g., Cloudflare Turnstile, DataDome) to complete.
            await Future.delayed(const Duration(seconds: 4));
            
            try {
              // Extract the HTML
              final html = await controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML',
              );
              
              overlayEntry.remove();
              
              if (!completer.isCompleted) {
                String htmlString = html.toString();
                if (htmlString.startsWith('"') && htmlString.endsWith('"')) {
                  htmlString = htmlString.substring(1, htmlString.length - 1);
                }
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
      );

    // DATADOME BYPASS: Safely apply Android-specific media playback rules.
    // Cloudflare/DataDome embed invisible audio nodes for fingerprinting.
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    // Get screen size so we can give DataDome a realistic viewport
    final screenSize = MediaQuery.of(context).size;

    // Create a full-screen overlay to host the WebView.
    // DataDome checks window.innerWidth/innerHeight. If it's 1x1, it blocks us.
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0, 
        top: 0,
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          children: [
            // Bottom layer: The actual WebView doing the work
            WebViewWidget(controller: controller),
            
            // Top layer: An opaque cover matching your app's background
            // so the user just sees a loading state, not the recipe site.
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
    
    Overlay.of(context).insert(overlayEntry);

    // Clear cache after mounting, before loading
    await controller.clearCache();

    await controller.loadRequest(uri);

    Timer(timeout, () {
      if (!completer.isCompleted) {
        overlayEntry.remove();
        completer.completeError(TimeoutException('WebView fetch timed out after ${timeout.inSeconds}s'));
      }
    });
    
    return completer.future;
  }
}