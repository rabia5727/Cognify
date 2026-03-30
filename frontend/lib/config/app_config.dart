class AppConfig {
  // Change this to your current IP when testing
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.13:8000', // your local IP
  );
}
