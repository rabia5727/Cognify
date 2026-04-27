class AppConfig {
  // Change this to your current IP when testing
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000', // your local IP
  );
}
