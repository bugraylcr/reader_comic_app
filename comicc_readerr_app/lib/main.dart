import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared_navigation.dart';
import 'theme_provider.dart';
import 'language_provider.dart';
import 'comic_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'download.dart';
import 'reading.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => ComicProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Comic Reader',
          theme: themeProvider.themeData,
          home: const ComicReadingPage(),
        );
      },
    );
  }
}

class ComicReadingPage extends StatefulWidget {
  const ComicReadingPage({super.key});

  @override
  State<ComicReadingPage> createState() => _ComicReadingPageState();
}

class _ComicReadingPageState extends State<ComicReadingPage> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  List<Comic> filteredImportedComics = [];
  Comic? recentlyDeletedComic;
  int? recentlyDeletedIndex;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    // Add sample comics to emulator when app starts
    _addSampleComics();
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    
    setState(() {
      searchQuery = searchController.text.toLowerCase();
      
      if (searchQuery.isEmpty) {
        // If search is empty, show all comics
        filteredImportedComics = comicProvider.importedComics;
      } else {
        // Filter imported comics
        filteredImportedComics = comicProvider.importedComics.where((comic) {
          return comic.title.toLowerCase().contains(searchQuery) ||
                 comic.details.toLowerCase().contains(searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _addSampleComics() async {
    try {
      // Get application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final sampleDir = Directory('${directory.path}/sample_comics');
      
      // Create directory if it doesn't exist
      if (!await sampleDir.exists()) {
        await sampleDir.create(recursive: true);
      }
      
      // Create a sample CBZ file from an asset
      final sampleComicPath = '${sampleDir.path}/sample_comic.cbz';
      final sampleFile = File(sampleComicPath);
      
      if (!await sampleFile.exists()) {
        // Create a simple ZIP archive with an image
        final archive = Archive();
        
        // Add a text file to the archive
        final infoBytes = utf8.encode('This is a sample comic file for testing');
        archive.addFile(ArchiveFile('info.txt', infoBytes.length, infoBytes));
        
        // Try to get an image from assets
        try {
          final ByteData data = await rootBundle.load('lib/assets/images/empty.png');
          final List<int> imageBytes = data.buffer.asUint8List();
          
          // Add the image to the archive
          archive.addFile(ArchiveFile('page1.png', imageBytes.length, imageBytes));
        } catch (e) {
          print("Could not load asset image: $e");
          // Add a simple text file as a fallback
          final pageBytes = utf8.encode('This is a sample page');
          archive.addFile(ArchiveFile('page1.txt', pageBytes.length, pageBytes));
        }
        
        // Write the archive to a file
        final zipData = ZipEncoder().encode(archive);
        if (zipData != null) {
          await sampleFile.writeAsBytes(zipData);
          print("Sample comic created at: $sampleComicPath");
          
          // Add to imported comics
          final comicProvider = Provider.of<ComicProvider>(context, listen: false);
          comicProvider.addComic(sampleFile);
        }
      }
      
      // Log available files for debugging
      print("Available files in app documents:");
      await for (var entity in Directory(directory.path).list(recursive: true)) {
        print(entity.path);
      }
      
    } catch (e) {
      print("Error creating sample comic: $e");
    }
  }

  void _navigateToReadingPage(Comic comic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingPage(cbzFilePath: comic.filePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final comicProvider = Provider.of<ComicProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    // Update filtered comics list when the component rebuilds
    if (searchQuery.isEmpty) {
      filteredImportedComics = comicProvider.importedComics;
    } else {
      filteredImportedComics = comicProvider.importedComics.where((comic) {
        return comic.title.toLowerCase().contains(searchQuery) ||
               comic.details.toLowerCase().contains(searchQuery);
      }).toList();
    }
    
    final appBar = AppBar(
      automaticallyImplyLeading: false, // Remove the back button
      title: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: languageProvider.translate('findInLibrary'),
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.grey : Colors.grey[600],
            ),
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      searchController.clear();
                    },
                  )
                : null,
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    );

    // Create a list to hold all comics
    List<Widget> comicItems = [];
    
    // Add imported comics
    for (var i = 0; i < filteredImportedComics.length; i++) {
      final comic = filteredImportedComics[i];
      // Only show selected state if not searching
      final isSelected = searchQuery.isEmpty && comicProvider.selectedComic?.filePath == comic.filePath;
      
      comicItems.add(
        InkWell(
          onTap: () {
            // Only select the comic, don't navigate
            comicProvider.selectComic(comic);
            
            // If searching, clear the search after selection
            if (searchQuery.isNotEmpty) {
              searchController.clear();
            }
          },
          child: Column(
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover image or placeholder with conditional border
                    Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        border: isSelected ? Border.all(
                          color: Colors.blue,
                          width: 2,
                        ) : null,
                      ),
                      child: comic.coverImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(comic.coverImagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.book,
                                      size: 40,
                                      color: isDarkMode ? Colors.white : Colors.black54,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.book,
                                size: 40,
                                color: isDarkMode ? Colors.white : Colors.black54,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Content column - takes fixed width to ensure consistent progress bar size
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          searchQuery.isEmpty
                              ? Text(
                                  comic.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                )
                              : _highlightText(comic.title, searchQuery, isDarkMode, isTitle: true),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: searchQuery.isEmpty
                                    ? Text(
                                        comic.details,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      )
                                    : _highlightText(comic.details, searchQuery, isDarkMode, isTitle: false),
                              ),
                              // Show reading progress with more spacing
                              if (comic.totalPages > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                                  child: Text(
                                    "${comic.lastReadPage} / ${comic.totalPages}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Add progress indicator if reading has started
                          if (comic.lastReadPage > 0 && comic.totalPages > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: LinearProgressIndicator(
                                value: comic.progressPercentage,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                minHeight: 4,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Container for checkmark and delete button
                    SizedBox(
                      width: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Checkmark for selected comic
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.check_circle, color: Colors.blue, size: 24),
                            ),
                          // Spacer to push delete button to bottom
                          SizedBox(height: 70),
                          // Delete button
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color:Colors.blue,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: () => _deleteComic(comic, i),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      );
    }

    // Show empty state if no comics
    if (comicItems.isEmpty) {
      comicItems.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              
                  SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset('lib/assets/images/empty.png'),
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? languageProvider.translate('No Comics In Library')
                      : languageProvider.translate('No Search Results'),
                  style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  searchQuery.isEmpty
                      ? languageProvider.translate('')
                      : languageProvider.translate(''),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final body = ListView(
      children: comicItems,
    );

    return SharedNavigation(
      currentIndex: 1, // Library is selected
      appBar: appBar,
      body: body,
    );
  }

  // Helper method to highlight matching text
  Widget _highlightText(String text, String query, bool isDarkMode, {bool isTitle = false}) {
    final List<TextSpan> spans = [];
    final String lowercaseText = text.toLowerCase();
    final String lowercaseQuery = query.toLowerCase();
    
    int start = 0;
    int indexOfMatch;
    
    while (true) {
      indexOfMatch = lowercaseText.indexOf(lowercaseQuery, start);
      if (indexOfMatch < 0) {
        // No more matches
        if (start < text.length) {
          spans.add(TextSpan(
            text: text.substring(start),
            style: TextStyle(
              fontSize: isTitle ? 18 : 14,
              fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
              color: isTitle 
                  ? (isDarkMode ? Colors.white : Colors.black) 
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            ),
          ));
        }
        break;
      }
      
      // Add non-matching text
      if (indexOfMatch > start) {
        spans.add(TextSpan(
          text: text.substring(start, indexOfMatch),
          style: TextStyle(
            fontSize: isTitle ? 18 : 14,
            fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
            color: isTitle 
                ? (isDarkMode ? Colors.white : Colors.black) 
                : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
          ),
        ));
      }
      
      // Add matching text with highlight
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: TextStyle(
          fontSize: isTitle ? 18 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
          backgroundColor: Colors.blue.withOpacity(0.1),
        ),
      ));
      
      start = indexOfMatch + query.length;
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  void _deleteComic(Comic comic, int index) {
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    
    // Store the comic and its index for potential undo
    recentlyDeletedComic = comic;
    recentlyDeletedIndex = index;
    
    // If the deleted comic is currently selected, clear the selection
    if (comicProvider.selectedComic?.filePath == comic.filePath) {
      comicProvider.clearSelectedComic();
    }
    
    // Remove the comic from the provider
    final comicIndex = comicProvider.importedComics.indexWhere((c) => c.filePath == comic.filePath);
    if (comicIndex >= 0) {
      comicProvider.importedComics.removeAt(comicIndex);
      comicProvider.notifyListeners();
    }
    
    // Show snackbar with undo option
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Comic deleted'),
        duration: Duration(milliseconds: 1500),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: _undoDelete,
        ),
      ),
    );
  }

  void _undoDelete() {
    if (recentlyDeletedComic != null && recentlyDeletedIndex != null) {
      final comicProvider = Provider.of<ComicProvider>(context, listen: false);
      
      // Ensure we're restoring the comic with all its properties intact
      final Comic comicToRestore = Comic(
        filePath: recentlyDeletedComic!.filePath,
        title: recentlyDeletedComic!.title,
        details: recentlyDeletedComic!.details,
        coverImagePath: recentlyDeletedComic!.coverImagePath,
        totalPages: recentlyDeletedComic!.totalPages,
        lastReadPage: recentlyDeletedComic!.lastReadPage, // Preserve last read position
      );
      
      // Try to insert at the original index if possible
      if (recentlyDeletedIndex! < comicProvider.importedComics.length) {
        comicProvider.importedComics.insert(recentlyDeletedIndex!, comicToRestore);
      } else {
        // Otherwise add to the end
        comicProvider.importedComics.add(comicToRestore);
      }
      
      // If this was the previously selected comic, reselect it
      if (comicProvider.selectedComic == null) {
        comicProvider.selectComic(comicToRestore);
      }
      
      // Notify listeners to update the UI
      comicProvider.notifyListeners();
      
      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comic restored with reading progress'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Clear the stored comic and index
      recentlyDeletedComic = null;
      recentlyDeletedIndex = null;
    }
  }
}
