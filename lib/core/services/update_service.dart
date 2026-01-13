import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart'; // REQUIRED: Add to pubspec.yaml

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
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(_apiUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (json['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
        final releaseNotes = (json['body'] as String?) ?? 'See release notes on GitHub';
        
        // DYNAMIC ASSET FINDER (New Logic)
        final assets = (json['assets'] as List?) ?? [];
        String downloadUrl = (json['html_url'] as String?) ?? ''; // Fallback

        // Find correct asset based on Platform
        if (Platform.isAndroid) {
          final apkAsset = assets.firstWhere(
            (a) => (a['name'] as String).toLowerCase().endsWith('.apk'),
            orElse: () => null,
          );
          if (apkAsset != null) downloadUrl = apkAsset['browser_download_url'];
        } else if (Platform.isWindows) {
          final exeAsset = assets.firstWhere(
            (a) => (a['name'] as String).toLowerCase().endsWith('.exe'),
            orElse: () => null,
          );
          if (exeAsset != null) downloadUrl = exeAsset['browser_download_url'];
        } else if (Platform.isLinux) {
           // Basic logic, improved later in install step
           final linuxAsset = assets.firstWhere(
            (a) => (a['name'] as String).toLowerCase().endsWith('.deb') || (a['name'] as String).toLowerCase().endsWith('.rpm'),
            orElse: () => null,
          );
          if (linuxAsset != null) downloadUrl = linuxAsset['browser_download_url'];
        } else if (Platform.isMacOS) {
           final dmgAsset = assets.firstWhere(
            (a) => (a['name'] as String).toLowerCase().endsWith('.dmg'),
            orElse: () => null,
          );
          if (dmgAsset != null) downloadUrl = dmgAsset['browser_download_url'];
        }

        final hasUpdate = _compareVersions(currentVersion, tagName) < 0;

        return AppVersion(
          currentVersion: currentVersion,
          latestVersion: tagName,
          hasUpdate: hasUpdate,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
        );
      }
    } catch (e) {
      print('Update check failed: $e');
    }

    return null;
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

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

  /// Install update on Android using OTA Update package
  Future<bool> _installAndroidUpdate(String apkUrl) async {
    try {
      // Use OTA Update to handle download + install intent automatically
      // This avoids writing custom native code
      OtaUpdate()
          .execute(apkUrl, destinationFilename: 'memoix_update.apk')
          .listen(
        (OtaEvent event) {
          // Optional: Add stream controller here if you want to expose progress
          print('OTA Status: ${event.status}, Value: ${event.value}');
        },
      );
      return true; // OTA Update handles the rest async
    } catch (e) {
      print('Android update failed: $e');
      return false;
    }
  }

  /// Install update on iOS
  Future<bool> _installIOSUpdate(String releaseUrl) async {
    try {
      final uri = Uri.parse(releaseUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return true; 
    } catch (e) {
      print('iOS update failed: $e');
      return false;
    }
  }

  /// Install update on Windows
  Future<bool> _installWindowsUpdate(String installerUrl) async {
    try {
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

      // Execute the installer with /S (silent)
      await Process.run(installerFile.path, ['/S'], runInShell: true);
      
      return true;
    } catch (e) {
      print('Windows update failed: $e');
      return false;
    }
  }

  /// Install update on macOS
  Future<bool> _installMacOSUpdate(String dmgUrl) async {
    try {
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
      // NOTE: For Linux, the "downloadUrl" passed in might be just the release page
      // if checkUpdate() didn't find a specific asset. 
      // Ideally, checkUpdate should be smart enough to pass the .deb/.rpm url.
      
      // If the URL is just the release page (fallback), try to parse the tag again
      String packageUrl = releaseUrl;
      
      // Basic check if it's already a direct download link
      if (!releaseUrl.endsWith('.deb') && !releaseUrl.endsWith('.rpm')) {
         final tagMatch = RegExp(r'/tag/([^/]+)$').firstMatch(releaseUrl);
         if (tagMatch != null) {
            final tag = tagMatch.group(1)!;
            
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
            // Construct likely URL (Caution: This assumes standard naming "memoix.deb")
            // A safer bet is just opening the release page if not direct.
            packageUrl = 'https://github.com/$_owner/$_repo/releases/download/$tag/memoix.${distro == 'deb' ? 'deb' : 'rpm'}';
         }
      }

      // Download the package
      final response = await http.get(Uri.parse(packageUrl)).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        print('Failed to download Linux package: ${response.statusCode}');
        return false;
      }

      // Save package to temp directory
      final tempDir = await getTemporaryDirectory();
      final ext = packageUrl.endsWith('.rpm') ? 'rpm' : 'deb';
      final packageFile = File('${tempDir.path}/memoix_update.$ext');
      await packageFile.writeAsBytes(response.bodyBytes);

      // Install using appropriate package manager with sudo
      if (ext == 'deb') {
        await Process.run('pkexec', ['apt', 'install', '-y', packageFile.path]);
      } else {
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