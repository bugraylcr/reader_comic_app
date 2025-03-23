/// comic_provider.dart/// 
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:comicc_readerr_app/api/comic_api_service.dart';
import 'cbz_helper.dart';
import 'package:flutter/material.dart';

class Comic {
  final String filePath;
  final String title;
  String details;
  String? coverImagePath;
  int totalPages;
  int lastReadPage;
  bool isServerComic;
  String? serverUrl;
  String? serverFilename;

  Comic({
    required this.filePath,
    required this.title,
    required this.details,
    this.coverImagePath,
    required this.totalPages,
    required this.lastReadPage,
    this.isServerComic = false,
    this.serverUrl,
    this.serverFilename,
  });

  String get progress {
    if (totalPages == 0) return "New";
    return "$lastReadPage / $totalPages";
  }

  double get progressPercentage => 
    totalPages > 0 ? lastReadPage / totalPages : 0.0;

  bool get isCompleted {
    return lastReadPage > 0 && lastReadPage >= totalPages;
  }

  void updateProgress(int currentPage, int total) {
    lastReadPage = currentPage;
    totalPages = total;
  }
}

class ComicProvider extends ChangeNotifier {
  List<Comic> _importedComics = [];
  Comic? _selectedComic;
  List<File> _importedFiles = [];

  List<Comic> get importedComics => _importedComics;
  Comic? get selectedComic => _selectedComic;
  List<File> get importedFiles => _importedFiles;

  Future<void> addComic(File file) async {
    try {
      final filePath = file.path;
      
      // Clean up the title by removing the extension
      String title = path.basenameWithoutExtension(filePath);
      
      // Check if this comic already exists in the library
      bool exists = _importedComics.any((comic) => comic.filePath == filePath);
      if (exists) return; // Don't add duplicates
      
      // Extract cover image (first page) from CBZ
      String? coverImagePath;
      int totalPages = 0;
      
      if (filePath.toLowerCase().endsWith('.cbz')) {
        // Extract the first image as cover
        final images = await CBZHelper.extractCBZ(filePath, extractFirstOnly: true);
        if (images.isNotEmpty) {
          coverImagePath = images.first.path;
          
          // Count total pages
          final ZipDecoder decoder = ZipDecoder();
          final Archive archive = decoder.decodeBytes(file.readAsBytesSync());
          totalPages = archive.files.where((file) => 
            file.name.toLowerCase().endsWith('.jpg') || 
            file.name.toLowerCase().endsWith('.jpeg') || 
            file.name.toLowerCase().endsWith('.png')
          ).length;
        }
      }
      
      // Create Comic object and add to list
      final comic = Comic(
        filePath: filePath,
        title: title, // Already cleaned up by basenameWithoutExtension
        details: '$totalPages pages', // Show page count instead of "Local Comic"
        coverImagePath: coverImagePath,
        totalPages: totalPages,
        lastReadPage: 0,
      );
      
      _importedComics.add(comic);
      notifyListeners();
    } catch (e) {
      print('Error adding comic: $e');
    }
  }

  Future<void> addServerComic(String filename, String serverUrl) async {
    // Check if comic already exists
    final exists = _importedComics.any(
      (comic) => comic.isServerComic && comic.serverFilename == filename
    );
    
    if (exists) return; // Don't add duplicates
    
    // Get app documents directory for storing references
    final appDir = await getApplicationDocumentsDirectory();
    final serverComicsDir = Directory('${appDir.path}/server_comics');
    if (!await serverComicsDir.exists()) {
      await serverComicsDir.create(recursive: true);
    }
    
    // Create a placeholder file that stores the server reference
    final refFilePath = '${serverComicsDir.path}/${Uri.encodeComponent(filename)}.ref';
    final refFile = File(refFilePath);
    
    // Store server URL and filename in the reference file
    await refFile.writeAsString(json.encode({
      'serverUrl': serverUrl,
      'filename': filename,
    }));
    
    // Clean up the title by removing the .cbz extension
    String cleanTitle = filename;
    if (cleanTitle.toLowerCase().endsWith('.cbz')) {
      cleanTitle = cleanTitle.substring(0, cleanTitle.length - 4);
    }
    
    // Add the comic to the library with server metadata
    final comic = Comic(
      filePath: refFilePath,
      title: cleanTitle, // Use the clean title without extension
      details: '0 pages', // Will be updated when we fetch more info
      coverImagePath: null,
      totalPages: 0, 
      lastReadPage: 0,
      isServerComic: true,
      serverUrl: serverUrl,
      serverFilename: filename,
    );
    
    _importedComics.add(comic);
    notifyListeners();
    
    // Fetch and set cover image and try to get page count
    await fetchAndSetServerComicInfo(filename, serverUrl);
  }

  void selectComic(Comic comic) {
    _selectedComic = comic;
    print('✅ Selected comic: ${comic.title}');
    notifyListeners();
  }

  void clearSelectedComic() {
    _selectedComic = null;
    notifyListeners();
  }

  void updateComicProgress(String filePath, int currentPage, int totalPages) {
    final index = _importedComics.indexWhere((comic) => comic.filePath == filePath);
    if (index >= 0) {
      _importedComics[index].updateProgress(currentPage, totalPages);
      notifyListeners();
    }
  }

  void addImportedFile(File file) {
    bool fileExists = _importedFiles.any((f) => f.path == file.path);
    if (!fileExists) {
      _importedFiles.add(file);
      notifyListeners();
    }
  }

  Future<void> updateComicCoverImage(String filePath, String coverImagePath) async {
    final index = _importedComics.indexWhere((comic) => comic.filePath == filePath);
    if (index >= 0) {
      _importedComics[index].coverImagePath = coverImagePath;
      notifyListeners();
    }
  }

  Future<void> fetchAndSetServerComicInfo(String filename, String serverUrl) async {
    try {
      // Find the comic in our library
      final index = _importedComics.indexWhere(
        (comic) => comic.isServerComic && comic.serverFilename == filename
      );
      
      if (index < 0) return; // Comic not found
      
      // Create the API service with the server URL
      final apiService = ComicApiService(baseUrl: serverUrl);
      
      // Get temporary directory to store covers
      final directory = await getTemporaryDirectory();
      final coverDir = Directory('${directory.path}/comic_covers');
      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }
      
      // Generate a filename for the cover - uzantıyı .webp yap
      final coverPath = '${coverDir.path}/${Uri.encodeComponent(filename)}_cover.webp';
      final coverFile = File(coverPath);
      
      // Fetch the cover image if we don't already have it
      if (!await coverFile.exists()) {
        // Fetch the preview (first page) from the server
        final imageBytes = await apiService.previewCbz(filename);
        // Save it to file
        await coverFile.writeAsBytes(imageBytes);
      }
      
      // Update the comic with the cover path
      _importedComics[index].coverImagePath = coverPath;
      
      // Try to get total pages by estimating with binary search
      try {
        int estimatedPages = await _estimateTotalPages(apiService, filename);
        
        // Update comic with the page count
        _importedComics[index].totalPages = estimatedPages;
        _importedComics[index].details = '$estimatedPages pages';
        
        // Notify listeners of the changes
        notifyListeners();
      } catch (e) {
        print('Error estimating pages: $e');
        // If we can't get the page count, at least update the cover
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching info for $filename: $e');
      notifyListeners();
    }
  }

  Future<int> _estimateTotalPages(ComicApiService apiService, String filename) async {
    // Start with a moderate guess
    int low = 1;
    int high = 30; // Initial guess
    int totalPages = 1; // Minimum is 1 page
    
    try {
      // First, check if high bound exists
      try {
        await apiService.getPageCbz(filename, high);
        // If success, we need to increase our upper bound
        while (true) {
          try {
            await apiService.getPageCbz(filename, high);
            low = high; // Move lower bound up
            high = high * 2; // Double our guess
            if (high > 1000) break; // Safety limit
          } catch (e) {
            break; // Found an upper bound that doesn't exist
          }
        }
      } catch (e) {
        // High doesn't exist, we need to binary search between low and high
      }
      
      // Binary search for the last valid page
      while (low <= high) {
        int mid = (low + high) ~/ 2;
        try {
          await apiService.getPageCbz(filename, mid);
          totalPages = mid; // This page exists
          low = mid + 1; // Look for later pages
        } catch (e) {
          high = mid - 1; // This page doesn't exist, look earlier
        }
      }
      
      return totalPages;
    } catch (e) {
      print('Error estimating total pages: $e');
      return 1; // Default to 1 if we can't estimate
    }
  }
}