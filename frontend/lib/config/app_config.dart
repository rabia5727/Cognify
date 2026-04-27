class AppConfig {
  // Default: 127.0.0.1 works for emulator and desktop testing.
  // For physical device testing, run with your LAN IP:
  //   flutter run --dart-define=API_URL=http://192.168.1.x:8000
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
