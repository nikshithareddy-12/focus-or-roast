class GeminiConfig {
  // Supplied at build time only: flutter run/build --dart-define=GEMINI_API_KEY=<key>.
  // Never hardcode a key here — anything compiled into the app is extractable from the APK.
  // When empty, GeminiService skips the API and uses the offline question bank.
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String defaultModel = 'gemini-3.1-flash-lite';
  static const List<String> fallbackModels = ['gemini-3.1-flash-lite', 'gemini-3.5-flash-lite'];
}