class AppConfig {
  static const String appName = 'FocusRoast';

  // Gemini API Key can be passed via --dart-define=GEMINI_API_KEY=your_key or set here securely
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String defaultRoastCsvPath = 'assets/data/roast_memes.csv';
  static const String defaultPraiseDirectory = 'assets/images/praise/';
}
