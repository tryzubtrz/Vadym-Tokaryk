/// Top-20 world languages + Ukrainian for first-launch selection.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.nameNative,
    required this.nameEnglish,
  });

  final String code;
  final String nameNative;
  final String nameEnglish;
}

const List<AppLanguage> supportedLanguages = [
  AppLanguage(code: 'uk', nameNative: 'Українська', nameEnglish: 'Ukrainian'),
  AppLanguage(code: 'en', nameNative: 'English', nameEnglish: 'English'),
  AppLanguage(code: 'zh', nameNative: '中文', nameEnglish: 'Chinese'),
  AppLanguage(code: 'hi', nameNative: 'हिन्दी', nameEnglish: 'Hindi'),
  AppLanguage(code: 'es', nameNative: 'Español', nameEnglish: 'Spanish'),
  AppLanguage(code: 'fr', nameNative: 'Français', nameEnglish: 'French'),
  AppLanguage(code: 'ar', nameNative: 'العربية', nameEnglish: 'Arabic'),
  AppLanguage(code: 'bn', nameNative: 'বাংলা', nameEnglish: 'Bengali'),
  AppLanguage(code: 'pt', nameNative: 'Português', nameEnglish: 'Portuguese'),
  AppLanguage(code: 'ru', nameNative: 'Русский', nameEnglish: 'Russian'),
  AppLanguage(code: 'ur', nameNative: 'اردو', nameEnglish: 'Urdu'),
  AppLanguage(code: 'id', nameNative: 'Bahasa Indonesia', nameEnglish: 'Indonesian'),
  AppLanguage(code: 'de', nameNative: 'Deutsch', nameEnglish: 'German'),
  AppLanguage(code: 'ja', nameNative: '日本語', nameEnglish: 'Japanese'),
  AppLanguage(code: 'sw', nameNative: 'Kiswahili', nameEnglish: 'Swahili'),
  AppLanguage(code: 'mr', nameNative: 'मराठी', nameEnglish: 'Marathi'),
  AppLanguage(code: 'te', nameNative: 'తెలుగు', nameEnglish: 'Telugu'),
  AppLanguage(code: 'tr', nameNative: 'Türkçe', nameEnglish: 'Turkish'),
  AppLanguage(code: 'ko', nameNative: '한국어', nameEnglish: 'Korean'),
  AppLanguage(code: 'vi', nameNative: 'Tiếng Việt', nameEnglish: 'Vietnamese'),
  AppLanguage(code: 'it', nameNative: 'Italiano', nameEnglish: 'Italian'),
];
