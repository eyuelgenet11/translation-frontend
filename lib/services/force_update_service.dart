import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ── The current app version (keep in sync with pubspec.yaml) ──────────────────
const String kCurrentVersion = '1.0.0';

// ── Play Store / App Store URL ────────────────────────────────────────────────
const String kStoreUrl =
    'https://play.google.com/store/apps/details?id=com.geezscript.translation';

// ── Update type ───────────────────────────────────────────────────────────────
enum UpdateType { none, soft, force }

// ── Version comparator ────────────────────────────────────────────────────────
bool _isBelow(String current, String required) {
  final c = current.split('.').map(int.parse).toList();
  final r = required.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final cv = i < c.length ? c[i] : 0;
    final rv = i < r.length ? r[i] : 0;
    if (rv > cv) return true;
    if (rv < cv) return false;
  }
  return false;
}

// ── Service ───────────────────────────────────────────────────────────────────
class ForceUpdateService {
  static final _supabase = Supabase.instance.client;

  /// Returns the update type and required version string.
  static Future<({UpdateType type, String version})> checkForUpdate() async {
    try {
      final rows = await _supabase
          .from('app_config')
          .select('key, value')
          .or('key.eq.force_update_min_version,key.eq.soft_update_min_version');

      String? forceMin, softMin;
      for (final row in rows as List) {
        if (row['key'] == 'force_update_min_version') forceMin = row['value'];
        if (row['key'] == 'soft_update_min_version')  softMin  = row['value'];
      }

      // Hard block takes priority
      if (forceMin != null && _isBelow(kCurrentVersion, forceMin)) {
        return (type: UpdateType.force, version: forceMin);
      }
      if (softMin != null && _isBelow(kCurrentVersion, softMin)) {
        return (type: UpdateType.soft, version: softMin);
      }
      return (type: UpdateType.none, version: '');
    } catch (e) {
      debugPrint('ForceUpdateService: $e');
      return (type: UpdateType.none, version: ''); // fail open
    }
  }
}

// ── Shared store launcher ─────────────────────────────────────────────────────
Future<void> _openStore() async {
  final uri = Uri.parse(kStoreUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ── Hard-block dialog (force update) ─────────────────────────────────────────
class ForceUpdateDialog extends StatelessWidget {
  final String requiredVersion;
  const ForceUpdateDialog({super.key, required this.requiredVersion});

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
            _icon(Icons.system_update_alt_rounded, const Color(0xFFdc2626), 0.1),
            const SizedBox(height: 20),
            const Text('Update Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 10),
            Text(
              'Version $requiredVersion is required to continue. '
              'Please update from the store.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 28),
            _storeButton('Update Now'),
          ],
        ),
      ),
    );
  }
}

// ── Soft-update dialog (dismissible) ─────────────────────────────────────────
class SoftUpdateDialog extends StatelessWidget {
  final String newVersion;
  const SoftUpdateDialog({super.key, required this.newVersion});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(Icons.new_releases_rounded, const Color(0xFF895129), 0.1),
          const SizedBox(height: 20),
          const Text('New Update Available',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          Text(
            'Version $newVersion is available with improvements and fixes. '
            'Update for the best experience.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 28),
          _storeButton('Update Now'),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Maybe Later',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
Widget _icon(IconData icon, Color color, double opacity) => Container(
  width: 72, height: 72,
  decoration: BoxDecoration(
    color: color.withOpacity(opacity),
    shape: BoxShape.circle,
  ),
  child: Icon(icon, color: color, size: 36),
);

Widget _storeButton(String label) => SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF895129),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: const Icon(Icons.open_in_new, size: 18),
    label: Text(label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    onPressed: _openStore,
  ),
);
