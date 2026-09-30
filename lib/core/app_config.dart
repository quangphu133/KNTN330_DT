class AppConfig {
  // Override at build/run time with:
  // --dart-define=API_BASE_URL=http://10.0.2.2:8001
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8001',
  );
}
