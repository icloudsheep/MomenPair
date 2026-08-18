import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({required this.apiBaseUri, required this.enableFakeSocialLogin});

  factory AppConfig.fromEnvironment() {
    const rawBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000/api/v1/',
    );
    final baseUri = Uri.parse(rawBaseUrl);
    if (!baseUri.hasScheme || baseUri.host.isEmpty) {
      throw const FormatException('API_BASE_URL must be an absolute URL.');
    }
    return AppConfig(
      apiBaseUri: baseUri.path.endsWith('/')
          ? baseUri
          : baseUri.replace(path: '${baseUri.path}/'),
      enableFakeSocialLogin: const bool.fromEnvironment(
        'ENABLE_FAKE_SOCIAL_LOGIN',
        defaultValue: kDebugMode,
      ),
    );
  }

  final Uri apiBaseUri;
  final bool enableFakeSocialLogin;
}
