import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';

class AppSettings {
  final String appName;
  final String logoUrl;
  final Color brandColor;
  final Color brandDarkColor;
  final Color brandLightColor;
  final String fontFamily;
  final String currencyCode;
  final String currencySymbol;
  final String currencyName;
  final bool maintenanceMode;

  const AppSettings({
    this.appName = 'MarketGO Rider',
    this.logoUrl = '',
    this.brandColor = const Color(0xFF16A34A),
    this.brandDarkColor = const Color(0xFF15803D),
    this.brandLightColor = const Color(0xFFDEF7E5),
    this.fontFamily = '',
    this.currencyCode = 'NGN',
    this.currencySymbol = '₦',
    this.currencyName = 'Nigerian Naira',
    this.maintenanceMode = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      appName: (json['app_name'] as String?) ?? 'MarketGO Rider',
      logoUrl: (json['logo_url'] as String?) ?? '',
      brandColor: _parseHex(json['brand_color'] as String?, const Color(0xFF16A34A)),
      brandDarkColor: _parseHex(json['brand_dark_color'] as String?, const Color(0xFF15803D)),
      brandLightColor: _parseHex(json['brand_light_color'] as String?, const Color(0xFFDEF7E5)),
      fontFamily: (json['font_family'] as String?) ?? '',
      currencyCode: (json['currency_code'] as String?) ?? 'NGN',
      currencySymbol: (json['currency_symbol'] as String?) ?? '₦',
      currencyName: (json['currency_name'] as String?) ?? 'Nigerian Naira',
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
    );
  }

  static Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }
}

class SettingsService {
  /// Fetch public app settings (no auth required).
  static Future<AppSettings> fetchSettings() async {
    final url = Uri.parse('${defaultApiBaseUrl()}/api/v1/settings');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return AppSettings.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Fall back to defaults when offline or the server is unreachable.
    }
    return const AppSettings();
  }
}