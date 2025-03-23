import 'package:comicc_readerr_app/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared_navigation.dart';
import 'custom_page_route.dart';
import 'language.dart';
import 'theme_provider.dart';
import 'language_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // List of settings items
    final List<Map<String, dynamic>> settingsItems = [
      // Aşağıdaki ayarlar yorum satırına alındı
      /*
      {
        'icon': Icons.person_outline,
        'title': languageProvider.translate('account'),
      },
      {
        'icon': Icons.notifications_none,
        'title': languageProvider.translate('notifications'),
      },
      */
      
      // Language ayarı aktif kalacak
      {
        'icon': Icons.language,
        'title': languageProvider.translate('changeLanguage'),
        'subtitle': languageProvider.currentLanguage == AppLanguage.english 
            ? languageProvider.translate('english') 
            : languageProvider.translate('turkish'),
        'onTap': () {
          Navigator.push(
            context,
            FadePageRoute(child: const LanguagePage()),
          );
        },
      },
      
      // Aşağıdaki ayar yorum satırına alındı
      /*
      {
        'icon': Icons.description_outlined,
        'title': languageProvider.translate('termsConditions'),
      },
      */
      
      // Dark Mode ayarı aktif kalacak
      {
        'icon': isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        'title': isDarkMode 
            ? languageProvider.translate('lightMode') 
            : languageProvider.translate('darkMode'),
        'onTap': () {
          themeProvider.toggleTheme();
        },
      },
      
      // Aşağıdaki ayarlar yorum satırına alındı
      /*
      {
        'icon': Icons.info_outline,
        'title': languageProvider.translate('about'),
      },
      {
        'icon': Icons.swap_horiz,
        'title': languageProvider.translate('readingDirection'),
      },
      */
    ];

    final appBar = AppBar(
      title: Text(
        languageProvider.translate('settings'),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            FadePageRoute(child: const ComicReadingPage()),
          );
        },
      ),
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      elevation: 0,
      scrolledUnderElevation: 0,
    );

    final body = ListView.separated(
      itemCount: settingsItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = settingsItems[index];
        return ListTile(
          leading: Icon(item['icon'], color: Colors.grey),
          title: Text(
            item['title'],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          subtitle: item.containsKey('subtitle') ? Text(
            item['subtitle'],
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ) : null,
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: item['onTap'] ?? () {
            // Default onTap handler if none is provided
          },
        );
      },
    );

    return SharedNavigation(
      currentIndex: 3, // Settings is selected
      appBar: appBar,
      body: body,
    );
  }
}

