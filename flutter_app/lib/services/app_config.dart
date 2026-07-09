import 'dart:convert';
import 'package:http/http.dart' as http;

class AppConfig {
  final String apiBaseUrl;
  final String apiToken;

  const AppConfig({required this.apiBaseUrl, required this.apiToken});

  static Future<AppConfig> load() async {
    try {
      final response = await http.get(Uri.parse('config.json'));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return AppConfig(
          apiBaseUrl: json['apiBaseUrl'] as String,
          apiToken: json['apiToken'] as String? ?? 'dev-token',
        );
      }
    } catch (_) {}
    return AppConfig(
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://focus-fitness-os-api.pages.dev',
      ),
      apiToken: 'dev-token',
    );
  }
}
