import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The version this build was made from, filled in by flutter from pubspec.yaml.
const appVersion = String.fromEnvironment('FLUTTER_BUILD_NAME');

/// Checks GitHub for a newer release. The PWA is served fresh from Hosting on
/// every open, so only the Android build asks.
class UpdateService {
  static const _latest =
      'https://api.github.com/repos/Navknight/rituals/releases/latest';

  /// Returns the newer release's tag and page, or null when up to date,
  /// offline, or not on Android.
  Future<({String version, String url})?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final response = await http
          .get(Uri.parse(_latest))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String).replaceFirst('v', '');
      if (!isNewer(tag, appVersion)) return null;
      return (version: tag, url: json['html_url'] as String);
    } catch (e) {
      debugPrint('[UpdateService] check failed: $e');
      return null;
    }
  }
}

/// True when dotted version [a] is ahead of [b]. Unparseable parts count as 0.
bool isNewer(String a, String b) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final l = i < x.length ? x[i] : 0, r = i < y.length ? y[i] : 0;
    if (l != r) return l > r;
  }
  return false;
}
