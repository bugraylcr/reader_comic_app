import 'package:flutter/material.dart';

enum AppLanguage { english, turkish }

class LanguageProvider extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;

  void setLanguage(AppLanguage language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
    }
  }

  // Translations
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Main page
      'findInLibrary': 'Find in library',
      
      // Navigation
      'readingNow': 'Reading Now',
      'library': 'Library',
      'downloads': 'Downloads',
      'settings': 'Settings',
      'api': 'API',
      
      // Downloads page
      'recentlyImported': 'Recently Imported',
      'edit': 'Edit',
      'local': 'Local',
      'server': 'Server',
      
      // Settings page
      'account': 'Account',
      'notifications': 'Notifications',
      'changeLanguage': 'Change Language',
      'termsConditions': 'Terms & Conditions',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'about': 'About',
      'readingDirection': 'Reading Direction',
      
      // Language page
      'languages': 'Languages',
      'english': 'English',
      'turkish': 'Turkish',
      'noFilesImported': 'No files imported yet',
    },
    'tr': {
      // Main page
      'findInLibrary': 'Kütüphanede Bul',
      
      // Navigation
      'readingNow': 'Şimdi Oku',
      'library': 'Kütüphane',
      'downloads': 'İndirilenler',
      'settings': 'Ayarlar',
      'api': 'API',
      
      // Downloads page
      'recentlyImported': 'Son İçe Aktarılanlar',
      'edit': 'Düzenle',
      'local': 'Yerel',
      'server': 'Sunucu',
      
      // Settings page
      'account': 'Hesap',
      'notifications': 'Bildirimler',
      'changeLanguage': 'Dil Değiştir',
      'termsConditions': 'Şartlar ve Koşullar',
      'darkMode': 'Karanlık Mod',
      'lightMode': 'Aydınlık Mod',
      'about': 'Hakkında',
      'readingDirection': 'Okuma Yönü',
      
      // Language page
      'languages': 'Diller',
      'english': 'İngilizce',
      'turkish': 'Türkçe',
      'noFilesImported': 'Henüz dosya içe aktarılmadı',
    },
  };

  String translate(String key) {
    final languageCode = _currentLanguage == AppLanguage.english ? 'en' : 'tr';
    return _localizedValues[languageCode]?[key] ?? key;
  }
}