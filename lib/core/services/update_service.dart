import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents available app version info
class AppVersion {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String downloadUrl;
  final String releaseNotes;

  AppVersion({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

/// Service for checking app updates against GitHub releases
class UpdateService {
  static const String _owner = 'dboiago';
  static const String _repo = 'Memoix';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Check for available updates
  Future<AppVersion?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g., "1.0.0"

      final response = await http.get(
        Uri.parse(_apiUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (json['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
        final releaseNotes = (json['body'] as String?) ?? 'See release notes on GitHub';
        final releaseUrl = (json['html_url'] as String?) ?? '';

        final hasUpdate = _compareVersions(currentVersion, tagName) < 0;

        return AppVersion(
          currentVersion: currentVersion,
          latestVersion: tagName,
          hasUpdate: hasUpdate,
          downloadUrl: releaseUrl,
          releaseNotes: releaseNotes,
        );
      }
    } catch (e) {
      // Silently fail if update check fails
      print('Update check failed: $e');
    }

    return null;
  }

  /// Compare two semantic versions
  /// Returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    // Pad to same length
    while (parts1.length < parts2.length) parts1.add(0);
    while (parts2.length < parts1.length) parts2.add(0);

    for (int i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0;
  }

  /// Open the release page in browser
  Future<void> openReleaseUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Download and install the app update automatically
  Future<bool> installUpdate(String downloadUrl) async {
    try {
      if (Platform.isAndroid) {
        return await _installAndroidUpdate(downloadUrl);
      } else if (Platform.isIOS) {
        return await _installIOSUpdate(downloadUrl);
      } else if (Platform.isWindows) {
        return await _installWindowsUpdate(downloadUrl);
      } else if (Platform.isMacOS) {
        return await _installMacOSUpdate(downloadUrl);
      } else if (Platform.isLinux) {
        return await _installLinuxUpdate(downloadUrl);
      }
      return false;
    } catch (e) {
      print('Failed to install update: $e');
      return false;
    }
  }

  /// Install update on Android by downloading APK and installing via platform channel
  Future<bool> _installAndroidUpdate(String releaseUrl) async {
    try {
      // Extract the APK download URL from the release page URL
      // GitHub release URLs are typically: https://github.com/owner/repo/releases/tag/v1.0.0
      // We need to download from: https://github.com/owner/repo/releases/download/v1.0.0/app-release.apk
      
      final tagMatch = RegExp(r'/tag/([^/]+)$').firstMatch(releaseUrl);
      if (tagMatch == null) return false;
      
      final tag = tagMatch.group(1)!;
      final apkUrl = 'https://github.com/$_owner/$_repo/releases/download/$tag/app-release.apk';
      
      // Download the APK
      final response = await http.get(Uri.parse(apkUrl)).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        print('Failed to download APK: ${response.statusCode}');
        return false;
      }

      // Save APK to temp directory
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/memoix_update.apk');
      await apkFile.writeAsBytes(response.bodyBytes);

      // Use platform channel to install APK
      const platform = MethodChannel('com.memoix/update');
      final result = await platform.invokeMethod<bool>('installApk', {
        'apkPath': apkFile.path,
      });

      return result ?? false;
    } catch (e) {
      print('Android update failed: $e');
      return false;
    }
  }

  /// Install update on iOS
  Future<bool> _installIOSUpdate(String releaseUrl) async {
    try {
      // For iOS, we can't directly install from GitHub releases like Android
      // Instead, we'll open the App Store or provide instructions
      // In a real app, you'd want to use TestFlight for beta updates
      // or submit to App Store for public updates
      
      // For now, open the GitHub release page
      final uri = Uri.parse(releaseUrl);
      print('iOS update available at: $releaseUrl');
      return false; // Indicate manual installation needed
    } catch (e) {
      print('iOS update failed: $e');
      return false;
    }
  }

  /// Install update on Windows
  Future<bool> _installWindowsUpdate(String releaseUrl) async {
    try {
      final tagMatch = RegExp(r'/tag/([^/]+)$').firstMatch(releaseUrl);
      if (tagMatch == null) return false;

      final tag = tagMatch.group(1)!;
      // Assuming Windows release is available as .exe or .msi
      final installerUrl = 'https://github.com/$_owner/$_repo/releases/download/$tag/MemoixInstaller.exe';
      
      // Download the installer
      final response = await http.get(Uri.parse(installerUrl)).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        print('Failed to download Windows installer: ${response.statusCode}');
        return false;
      }

      // Save installer to temp directory
      final tempDir = await getTemporaryDirectory();
      final installerFile = File('${tempDir.path}/MemoixInstaller.exe');
      await installerFile.writeAsBytes(response.bodyBytes);

      // Execute the installer with /S (silent) and /D (installation directory) flags
      // The installer should handle app restart
      await Process.run(installerFile.path, ['/S'], runInShell: true);
      
      return true;
    } catch (e) {
      print('Windows update failed: $e');
      return false;
    }
  }

  /// Install update on macOS
  Future<bool> _installMacOSUpdate(String releaseUrl) async {
    try {
      final tagMatch = RegExp(r'/tag/([^/]+)$').firstMatch(releaseUrl);
      if (tagMatch == null) return false;

      final tag = tagMatch.group(1)!;
      // Assuming macOS release is available as .dmg
      final dmgUrl = 'https://github.com/$_owner/$_repo/releases/download/$tag/Memoix.dmg';
      
      // Download the DMG
      final response = await http.get(Uri.parse(dmgUrl)).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        print('Failed to download macOS DMG: ${response.statusCode}');
        return false;
      }

      // Save DMG to Downloads folder
      final downloadsDir = Directory('${Platform.environment['HOME']}/Downloads');
      if (!await downloadsDir.exists()) {
        return false;
      }

      final dmgFile = File('${downloadsDir.path}/Memoix-Update.dmg');
      await dmgFile.writeAsBytes(response.bodyBytes);

      // Open the DMG file (system will mount and show it)
      await Process.run('open', [dmgFile.path]);
      
      return true;
    } catch (e) {
      print('macOS update failed: $e');
      return false;
    }
  }

  /// Install update on Linux
  Future<bool> _installLinuxUpdate(String releaseUrl) async {
    try {
      final tagMatch = RegExp(r'/tag/([^/]+)$').firstMatch(releaseUrl);
      if (tagMatch == null) return false;

      final tag = tagMatch.group(1)!;
      
      // Try to detect distro and download appropriate package
      final distroFile = File('/etc/os-release');
      String distro = 'generic';
      
      if (await distroFile.exists()) {
        final content = await distroFile.readAsString();
        if (content.contains('ubuntu') || content.contains('debian')) {
          distro = 'deb';
        } else if (content.contains('fedora') || content.contains('rhel') || content.contains('centos')) {
          distro = 'rpm';
        }
      }

      final packageUrl = distro == 'deb'
          ? 'https://github.com/$_owner/$_repo/releases/download/$tag/memoix.deb'
          : 'https://github.com/$_owner/$_repo/releases/download/$tag/memoix.rpm';

      // Download the package
      final response = await http.get(Uri.parse(packageUrl)).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        print('Failed to download Linux package: ${response.statusCode}');
        return false;
      }

      // Save package to temp directory
      final tempDir = await getTemporaryDirectory();
      final packageFile = File('${tempDir.path}/memoix.${distro == 'deb' ? 'deb' : 'rpm'}');
      await packageFile.writeAsBytes(response.bodyBytes);

      // Install using appropriate package manager with sudo
      if (distro == 'deb') {
        // For DEB: sudo apt install ./memoix.deb
        await Process.run('pkexec', ['apt', 'install', '-y', packageFile.path]);
      } else {
        // For RPM: sudo dnf install ./memoix.rpm or sudo yum install ./memoix.rpm
        await Process.run('pkexec', ['dnf', 'install', '-y', packageFile.path]);
      }

      return true;
    } catch (e) {
      print('Linux update failed: $e');
      return false;
    }
  }
}

/// Riverpod provider for the update service
final updateServiceProvider = Provider((ref) => UpdateService());

/// Provider for checking updates (cached for session)
final appVersionProvider = FutureProvider((ref) async {
  final service = ref.watch(updateServiceProvider);
  return service.checkForUpdate();
});
