import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'settings.dart';
import 'download.dart';
import 'custom_page_route.dart';
import 'language_provider.dart';
import 'comic_provider.dart';
import 'reading.dart';
// import 'screens/home_screen.dart'; // No longer needed as API is integrated into Downloads

class SharedNavigation extends StatefulWidget {
  final int currentIndex;
  final Widget body;
  final PreferredSizeWidget? appBar;

  const SharedNavigation({
    super.key,
    required this.currentIndex,
    required this.body,
    this.appBar,
  });

  @override
  State<SharedNavigation> createState() => _SharedNavigationState();
}

class _SharedNavigationState extends State<SharedNavigation> {
  void _onItemTapped(int index) {
    if (index == widget.currentIndex) return;
    
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    
    Widget page;
    switch (index) {
      case 0:
        // Reading Now page - navigate to the selected comic or show a message
        if (comicProvider.selectedComic != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReadingPage(
                cbzFilePath: comicProvider.selectedComic!.filePath,
              ),
            ),
          );
          return;
        } else {
          // Show a message that no comic is selected
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please select a comic from the library first'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      case 1:
        // Library page (main page)
        page = const ComicReadingPage();
        break;
      case 2:
        // Downloads page
        page = const DownloadPage();
        break;
      case 3:
        // Settings page
        page = const SettingsPage();
        break;
      default:
        page = const ComicReadingPage();
    }

    Navigator.pushReplacement(
      context,
      FadePageRoute(child: page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      appBar: widget.appBar,
      body: widget.body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'lib/assets/images/book3.png',
                color: widget.currentIndex == 0 ? Colors.blue : Colors.grey,
              ),
            ),
            label: languageProvider.translate('readingNow'),
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'lib/assets/images/library3.png',
                color: widget.currentIndex == 1 ? Colors.blue : Colors.grey,
              ),
            ),
            label: languageProvider.translate('library'),
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'lib/assets/images/dowload.png',
                color: widget.currentIndex == 2 ? Colors.blue : Colors.grey,
              ),
            ),
            label: languageProvider.translate('downloads'),
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'lib/assets/images/settings2.png',
                color: widget.currentIndex == 3 ? Colors.blue : Colors.grey,
              ),
            ),
            label: languageProvider.translate('settings'),
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}