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
  /// The WebView is shown briefly but positioned off-screen so it is invisible.
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
    // Cloudflare and DataDome store a "blocked" session token on the first
    // rejected request. Subsequent requests carry that token and are
    // immediately re-blocked even with a clean User-Agent.
    await WebViewCookieManager().clearCookies();

    final completer = Completer<String>();
    
    late final WebViewController controller;
    late final OverlayEntry overlayEntry;
    
    controller = WebViewController()
      // JavaScript must be unrestricted — Cloudflare Turnstile and DataDome
      // both rely on JS execution to solve challenges and set pass cookies.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Spoof the User-Agent to a standard Android Chrome string.
      // Android WebView normally injects a ' wv' marker (e.g., "Chrome/123 wv Mobile")
      // that Cloudflare and DataDome use as a hard signal to block the request.
      // This UA matches a real Samsung Galaxy Chrome browser with no wv tag.
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-S908U) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/123.0.6312.40 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String finishedUrl) async {
            // Wait for JS challenges (e.g., Cloudflare Turnstile, DataDome) to complete.
            // onPageFinished fires when document.readyState === 'complete', but bot-protection
            // scripts run asynchronously after that. 4 seconds gives the challenge enough
            // time to execute and redirect before we extract the DOM.
            await Future.delayed(const Duration(seconds: 4));
            
            try {
              // Extract the HTML
              final html = await controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML',
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
      );

    // Create a tiny overlay to host the WebView (required for rendering).
    // Positioned off-screen so it is invisible to the user.
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,  // Off-screen
        top: -10000,
        width: 1,
        height: 1,
        child: WebViewWidget(controller: controller),
      ),
    );
    
    Overlay.of(context).insert(overlayEntry);

    // Clear the WebView's on-disk cache after the controller is mounted.
    // This removes any cached responses from previous blocked requests so
    // the site sees a completely fresh client.
    await controller.clearCache();

    await controller.loadRequest(uri);

    // Timeout accounts for: page load + 4 s JS-challenge wait + network latency.
    Timer(timeout, () {
      if (!completer.isCompleted) {
        overlayEntry.remove();
        completer.completeError(TimeoutException('WebView fetch timed out after ${timeout.inSeconds}s'));
      }
    });
    
    return completer.future;
  }
}
