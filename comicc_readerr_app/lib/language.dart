import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings.dart';
import 'custom_page_route.dart';
import 'theme_provider.dart';
import 'language_provider.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.translate('languages'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              FadePageRoute(child: const SettingsPage()),
            );
          },
        ),
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // English option - always displayed in English
                  ListTile(
                    title: Text(
                      'English',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: languageProvider.currentLanguage == AppLanguage.english
                        ? Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      languageProvider.setLanguage(AppLanguage.english);
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  ),
                  // Turkish option - always displayed in English
                  ListTile(
                    title: Text(
                      'Turkish',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: languageProvider.currentLanguage == AppLanguage.turkish
                        ? Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      languageProvider.setLanguage(AppLanguage.turkish);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
    );
  }
}
