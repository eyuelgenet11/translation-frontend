import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';

// ── Fallback App Version if runtime reading fails ────────────────────────────
const String kFallbackCurrentVersion = '1.2.3';

// ── Store URLs ───────────────────────────────────────────────────────────────
const String kAndroidPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.geez.script';
const String kAndroidMarketUrl = 'market://details?id=com.geez.script';
const String kIosAppStoreUrl =
    'https://apps.apple.com/app/com.geez.script';

// ── Update Type ──────────────────────────────────────────────────────────────
enum UpdateType { none, soft, force }

// ── SemVer Comparison ────────────────────────────────────────────────────────
bool isBelowVersion(String current, String target) {
  try {
    // Strip build numbers (+30) and leading 'v'
    final cClean = current.replaceAll('v', '').split('+').first.trim();
    final tClean = target.replaceAll('v', '').split('+').first.trim();

    final cParts = cClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final tParts = tClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final cv = i < cParts.length ? cParts[i] : 0;
      final tv = i < tParts.length ? tParts[i] : 0;
      if (tv > cv) return true;
      if (tv < cv) return false;
    }
  } catch (e) {
    debugPrint('[ForceUpdateService] Version compare error: $e');
  }
  return false;
}

// ── Force Update Service ─────────────────────────────────────────────────────
class ForceUpdateService {
  /// Opens the relevant store for the current platform
  static Future<void> openStore({String? customUrl}) async {
    try {
      if (customUrl != null && customUrl.isNotEmpty) {
        final uri = Uri.parse(customUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      if (!kIsWeb && Platform.isAndroid) {
        // Try opening directly inside the Google Play App
        final marketUri = Uri.parse(kAndroidMarketUrl);
        try {
          if (await canLaunchUrl(marketUri)) {
            await launchUrl(marketUri, mode: LaunchMode.externalApplication);
            return;
          }
        } catch (_) {}

        final webUri = Uri.parse(kAndroidPlayStoreUrl);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (!kIsWeb && Platform.isIOS) {
        final iosUri = Uri.parse(kIosAppStoreUrl);
        if (await canLaunchUrl(iosUri)) {
          await launchUrl(iosUri, mode: LaunchMode.externalApplication);
          return;
        }
      } else {
        final fallbackUri = Uri.parse(kAndroidPlayStoreUrl);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('[ForceUpdateService] Error opening store: $e');
    }
  }

  /// Checks if a newer version is available.
  /// Queries backend /api/config/public first, with Supabase app_config fallback.
  static Future<({UpdateType type, String version, String notes, String storeUrl})> checkForUpdate() async {
    try {
      // 1. Get current installed version dynamically from device
      String currentVersion = kFallbackCurrentVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        if (info.version.isNotEmpty) {
          currentVersion = info.version;
        }
      } catch (e) {
        debugPrint('[ForceUpdateService] Failed reading PackageInfo: $e');
      }

      String latestVer = '';
      String minVer = '';
      bool forceFlag = false;
      String releaseNotes = '';
      String storeUrl = '';

      // 2. Fetch update metadata dynamically from Render Backend
      try {
        final res = await http
            .get(Uri.parse('${ApiConfig.baseUrl}/api/config/public'))
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          latestVer = (data['latestVersion'] ?? '').toString().trim();
          minVer = (data['minRequiredVersion'] ?? '').toString().trim();
          forceFlag = data['forceUpdate'] == true;
          releaseNotes = (data['releaseNotes'] ?? '').toString().trim();
          if (!kIsWeb && Platform.isIOS) {
            storeUrl = (data['storeUrlIos'] ?? '').toString().trim();
          } else {
            storeUrl = (data['storeUrlAndroid'] ?? '').toString().trim();
          }
        }
      } catch (e) {
        debugPrint('[ForceUpdateService] Backend check notice (trying Supabase): $e');
      }

      // 3. Fallback to Supabase app_config if backend values are empty
      if (latestVer.isEmpty && minVer.isEmpty) {
        try {
          final rows = await Supabase.instance.client
              .from('app_config')
              .select('key, value')
              .or('key.eq.force_update_min_version,key.eq.soft_update_min_version,key.eq.latest_version');

          for (final row in rows as List) {
            final key = row['key'];
            final val = (row['value'] ?? '').toString().trim();
            if (key == 'force_update_min_version') minVer = val;
            if (key == 'soft_update_min_version' || key == 'latest_version') {
              latestVer = val;
            }
          }
        } catch (e) {
          debugPrint('[ForceUpdateService] Supabase fallback check notice: $e');
        }
      }

      debugPrint(
        '[ForceUpdateService] Current: $currentVersion, Latest: $latestVer, Min: $minVer, Force: $forceFlag',
      );

      // 4. Force Update evaluation
      final bool belowMin = minVer.isNotEmpty && isBelowVersion(currentVersion, minVer);
      final bool belowLatestWithForce = forceFlag && latestVer.isNotEmpty && isBelowVersion(currentVersion, latestVer);

      if (belowMin || belowLatestWithForce) {
        return (
          type: UpdateType.force,
          version: latestVer.isNotEmpty ? latestVer : minVer,
          notes: releaseNotes,
          storeUrl: storeUrl,
        );
      }

      // 5. Soft Update evaluation (Notify user, but allow "Maybe Later")
      if (latestVer.isNotEmpty && isBelowVersion(currentVersion, latestVer)) {
        return (
          type: UpdateType.soft,
          version: latestVer,
          notes: releaseNotes,
          storeUrl: storeUrl,
        );
      }

      return (type: UpdateType.none, version: '', notes: '', storeUrl: '');
    } catch (e) {
      debugPrint('[ForceUpdateService] Update check failed: $e');
      return (type: UpdateType.none, version: '', notes: '', storeUrl: '');
    }
  }
}

// ── Hard-block Dialog (Force Update) ─────────────────────────────────────────
class ForceUpdateDialog extends StatelessWidget {
  final String requiredVersion;
  final String? releaseNotes;
  final String? storeUrl;

  const ForceUpdateDialog({
    super.key,
    required this.requiredVersion,
    this.releaseNotes,
    this.storeUrl,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(Icons.system_update_alt_rounded, const Color(0xFFDC2626), 0.1),
            const SizedBox(height: 20),
            const Text(
              'Update Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A critical update (version $requiredVersion) is required to continue using the app securely.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            if (releaseNotes != null && releaseNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  releaseNotes!.trim(),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
              ),
            ],
            const SizedBox(height: 26),
            _storeButton('Update Now', storeUrl),
          ],
        ),
      ),
    );
  }
}

// ── Soft-update Dialog (Dismissible) ─────────────────────────────────────────
class SoftUpdateDialog extends StatelessWidget {
  final String newVersion;
  final String? releaseNotes;
  final String? storeUrl;

  const SoftUpdateDialog({
    super.key,
    required this.newVersion,
    this.releaseNotes,
    this.storeUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(Icons.new_releases_rounded, const Color(0xFF8D5C3C), 0.12),
          const SizedBox(height: 20),
          const Text(
            'New Update Available',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Version $newVersion is available with new features and improvements.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          if (releaseNotes != null && releaseNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF8F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8D5C3C).withValues(alpha: 0.2)),
              ),
              child: Text(
                releaseNotes!.trim(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
            ),
          ],
          const SizedBox(height: 26),
          _storeButton('Update Now', storeUrl),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Maybe Later',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared UI Helpers ────────────────────────────────────────────────────────
Widget _icon(IconData icon, Color color, double opacity) => Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 34),
    );

Widget _storeButton(String label, String? storeUrl) => SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8D5C3C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.open_in_new, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        onPressed: () => ForceUpdateService.openStore(customUrl: storeUrl),
      ),
    );
