import 'package:comicc_readerr_app/main.dart';
import 'reading.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'shared_navigation.dart';
import 'custom_page_route.dart';
import 'theme_provider.dart';
import 'language_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:archive/archive.dart'; // Use archive package instead of flutter_archive
import 'comic_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart'; // Add this import
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:async';
import 'api/comic_api_service.dart'; // Add import for API service
// import 'package:process_run/process_run.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _mounted = true; // Track if widget is mounted
  final String comicConverterFolder = "C:\\Users\\W11\\Desktop\\ComicConverter";
  
  // API related variables
  String _serverUrl = 'https://reader-comic-app.onrender.com';
  late ComicApiService apiService;
  TextEditingController _serverUrlController = TextEditingController();
  String? _errorMessage;
  bool _isRetrying = false;
  List<String> cbzFiles = [];
  Uint8List? currentPageImage;
  String _loadingMessage = '';
  
  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _serverUrlController.text = _serverUrl;
    apiService = ComicApiService(baseUrl: _serverUrl);
    _fetchCbzList();
  }

  @override
  void dispose() {
    _mounted = false; // Set to false when widget is disposed
    _serverUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // API related methods
  void _updateServerUrl() {
    setState(() {
      _serverUrl = _serverUrlController.text.trim();
      apiService = ComicApiService(baseUrl: _serverUrl);
      _errorMessage = null;
      _fetchCbzList();
    });
  }

  Future<void> _fetchCbzList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isRetrying = false;
      _loadingMessage = 'Fetching comics from server...';
    });
    
    try {
      final files = await apiService.listCbzFiles();
      
      setState(() {
        cbzFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      print('CBZ listesi alınamadı: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _previewFirstPage(String filename) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isRetrying = false;
      _loadingMessage = 'Loading preview...';
    });
    
    try {
      final imageBytes = await apiService.previewCbz(filename);
      
      setState(() {
        currentPageImage = imageBytes;
        _isLoading = false;
      });
    } catch (e) {
      print('Önizleme hatası: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Preview error: ${e.toString()}';
      });
    }
  }

  Future<void> _getSpecificPage(String filename, int page) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isRetrying = false;
    });
    
    try {
      final imageBytes = await apiService.getPageCbz(filename, page);
      setState(() {
        currentPageImage = imageBytes;
        _isLoading = false;
      });
    } catch (e) {
      print('Sayfa hatası: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Page error: ${e.toString()}';
      });
    }
  }

  // Add retry functionality
  void _retryOperation() {
    setState(() {
      _isRetrying = true;
    });
    
    if (currentPageImage == null) {
      // We were probably trying to fetch the list
      _fetchCbzList();
    } else {
      // We were probably trying to preview a file
      if (cbzFiles.isNotEmpty) {
        _previewFirstPage(cbzFiles[0]);
      }
    }
  }

  // API method for CBR conversion
  Future<void> _apiConvertCbrToCbz() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cbr'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
            _isRetrying = false;
            _loadingMessage = 'Converting CBR to CBZ...';
          });
          
          // API'ye gönder
          await apiService.convertCbrToCbz(filePath);
          
          // Dönüşüm tamamlandıktan sonra listeyi yenile
          await _fetchCbzList();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CBR başarıyla dönüştürüldü')),
          );
        }
      }
    } catch (e) {
      print('Dönüştürme hatası: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Conversion error: ${e.toString()}';
      });
    }
  }

  // Original methods
  Future<void> _pickAndConvertFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cbr', 'cbz'],
    );

    if (result != null && result.files.isNotEmpty && _mounted) {
      final filePath = result.files.single.path;
      if (filePath != null) {
        setState(() {
          _isLoading = true;
          _loadingMessage = filePath.toLowerCase().endsWith('.cbr') 
            ? 'Converting CBR to CBZ...' 
            : 'Uploading file to server...';
        });
        
        try {
          bool success = false;
          
          // CBR dosyası ise sunucuya dönüştürme için gönder
          if (filePath.toLowerCase().endsWith('.cbr')) {
            await apiService.convertCbrToCbz(filePath);
            success = true;
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('CBR başarıyla dönüştürüldü'))
            );
          } else if (filePath.toLowerCase().endsWith('.cbz')) {
            // CBZ dosyasını doğrudan yükle
            success = await apiService.uploadCbzFile(filePath);
            
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Dosya başarıyla yüklendi"))
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Yükleme başarısız!"),
                  backgroundColor: Colors.red,
                )
              );
            }
          }
          
          // Dosya işlemi başarılıysa sunucu listesini yenile
          if (success) {
            await _fetchCbzList();
          }
          
          setState(() {
            _isLoading = false;
          });
        } catch (e) {
          print('İşlem hatası: $e');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error: ${e.toString()}';
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: Colors.red,
            )
          );
        }
      }
    }
  }

  Future<String> _convertCbrToCbz(String cbrPath) async {
    try {
      final String fileName = path.basenameWithoutExtension(cbrPath);
      final String outputCbzPath = path.join(comicConverterFolder, "$fileName.cbz");

      if (File(outputCbzPath).existsSync()) {
        File(outputCbzPath).deleteSync();
      }

      // Try to use Python script first with ASCII-safe output
      try {
        // Modify the Python command to avoid Unicode issues
        ProcessResult result = await Process.run(
          'python', 
          ['-c', 'import sys; sys.stdout = open(sys.stdout.fileno(), mode="w", encoding="utf8", buffering=1); import subprocess; subprocess.run(["python", "convert.py", r"' + cbrPath + '"], check=True)'],
          workingDirectory: comicConverterFolder,
        );

        if (result.exitCode == 0 && File(outputCbzPath).existsSync()) {
          print("CBR successfully converted to CBZ: $outputCbzPath");
          return outputCbzPath;
        } else {
          print("Python script failed, falling back to built-in conversion");
          // Fall back to the built-in conversion method
        }
      } catch (e) {
        print("Python script error, falling back to built-in conversion: $e");
        // Fall back to the built-in conversion method
      }

      // Built-in conversion method using archive package
      final tempDir = await getTemporaryDirectory();
      final String extractDir = '${tempDir.path}/$fileName';
      
      // Create extraction directory
      final directory = Directory(extractDir);
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
      directory.createSync(recursive: true);
      
      // Use unrar command to extract CBR
      ProcessResult result = await Process.run(
        'unrar', ['x', cbrPath, extractDir],
      );
      
      if (result.exitCode != 0) {
        print("CBR extraction failed: ${result.stderr}");
        return "";
      }
      
      // Create a ZIP file from the extracted contents using archive package
      final zipFile = File(outputCbzPath);
      if (zipFile.existsSync()) {
        zipFile.deleteSync();
      }
      
      // Create archive
      final archive = Archive();
      
      // Add all files from the extraction directory
      final dir = Directory(extractDir);
      await for (final file in dir.list(recursive: true)) {
        if (file is File) {
          final relativePath = path.relative(file.path, from: extractDir);
          final data = await file.readAsBytes();
          final archiveFile = ArchiveFile(relativePath, data.length, data);
          archive.addFile(archiveFile);
        }
      }
      
      // Write the archive to a zip file
      final zipData = ZipEncoder().encode(archive);
      if (zipData != null) {
        await zipFile.writeAsBytes(zipData);
      }
      
      // Clean up the temporary directory
      await dir.delete(recursive: true);
      
      print("CBR successfully converted to CBZ: $outputCbzPath");
      return outputCbzPath;
    } catch (e) {
      print("Conversion error: $e");
      return "";
    }
  }

  void _showErrorSnackBar(String message) {
    // Only show snackbar if widget is still mounted
    if (!_mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _addToImportedFiles(File file) {
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    bool fileExists = comicProvider.importedFiles.any((f) => f.path == file.path);
    if (!fileExists) {
      comicProvider.addImportedFile(file);
    }
  }

  Future<void> pickComicFile() async {
    try {
      print("Starting file picker...");
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null) {
        print("File selected: ${result.files.single.path}");
        
        if (result.files.single.path != null) {
          final path = result.files.single.path!;
          
          // Show a snackbar with the selected file path
          if (_mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected file: $path'))
            );
          }
          
          // Try to open the file
          final openResult = await OpenFile.open(path);
          print("Open file result: ${openResult.type}, ${openResult.message}");
          
          // Add to imported files
          final file = File(path);
          _addToImportedFiles(file);
        }
      } else {
        print("No file selected");
      }
    } catch (e) {
      print("Error picking file: $e");
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'))
        );
      }
    }
  }

  Future<void> _createSampleComics() async {
    try {
      // Get the external storage directory (accessible by SAF)
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print("External storage directory is null");
        return;
      }
      
      final sampleDir = Directory('${directory.path}/sample_comics');
      
      // Create directory if it doesn't exist
      if (!await sampleDir.exists()) {
        await sampleDir.create(recursive: true);
      }
      
      // Create a sample CBZ file
      final sampleComicPath = '${sampleDir.path}/sample_comic.cbz';
      final sampleFile = File(sampleComicPath);
      
      if (!await sampleFile.exists()) {
        // Create a simple ZIP archive
        final archive = Archive();
        
        // Add a text file to the archive
        final infoBytes = utf8.encode('This is a sample comic file for testing');
        archive.addFile(ArchiveFile('info.txt', infoBytes.length, infoBytes));
        
        // Add a simple text file as a page
        final pageBytes = utf8.encode('This is a sample page');
        archive.addFile(ArchiveFile('page1.txt', pageBytes.length, pageBytes));
        
        // Write the archive to a file
        final zipData = ZipEncoder().encode(archive);
        if (zipData != null) {
          await sampleFile.writeAsBytes(zipData);
          print("Sample comic created at: $sampleComicPath");
          
          // Add to imported files
          _addToImportedFiles(sampleFile);
          
          // Show a snackbar to confirm file creation
          if (_mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sample comic created at: $sampleComicPath'))
            );
          }
        }
      }
      
      // Log all available directories for debugging
      _printAvailableDirectories();
      
    } catch (e) {
      print("Error creating sample comic: $e");
    }
  }

  void _printAvailableDirectories() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      print("App Documents Directory: ${appDocDir.path}");
      
      final downloadDir = await getExternalStorageDirectory();
      print("External Storage Directory: ${downloadDir?.path}");
      
      final tempDir = await getTemporaryDirectory();
      print("Temporary Directory: ${tempDir.path}");
      
      // List all directories
      List<Directory?> allDirs = [
        appDocDir,
        downloadDir,
        tempDir,
      ];
      
      for (var dir in allDirs) {
        if (dir != null && await dir.exists()) {
          print("Files in ${dir.path}:");
          try {
            await for (var entity in dir.list(recursive: false)) {
              print("- ${entity.path}");
            }
          } catch (e) {
            print("Error listing files in ${dir.path}: $e");
          }
        }
      }
    } catch (e) {
      print("Error printing directories: $e");
    }
  }

  void _addComicToLibrary(String filename) async {
    // First fetch the preview to show the user
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Loading preview...';
    });
    
    try {
      // WebP formatını direkt olarak kullanmak için değişiklik yapıldı
      final imageBytes = await apiService.previewCbz(filename);
      
      // Try to estimate the total pages
      int estimatedPages = 0;
      try {
        estimatedPages = await _estimateTotalPages(filename);
      } catch (e) {
        print('Error estimating pages: $e');
      }
      
      setState(() {
        currentPageImage = imageBytes;
        _isLoading = false;
      });
      
      // Clean up title for display
      String displayTitle = filename;
      if (displayTitle.toLowerCase().endsWith('.cbz')) {
        displayTitle = displayTitle.substring(0, displayTitle.length - 4);
      }
      
      // Show confirmation dialog with preview
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Add to Library'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 200,
                  width: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(displayTitle),
                if (estimatedPages > 0)
                  Text('$estimatedPages pages', 
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                SizedBox(height: 8),
                Text('Add to your library?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close dialog
                  
                  // Get the comic provider
                  final comicProvider = Provider.of<ComicProvider>(context, listen: false);
                  
                  // Add comic to library and immediately fetch the cover and info
                  await comicProvider.addServerComic(filename, _serverUrl);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added "$displayTitle" to library'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text('Add'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading preview: $e';
      });
    }
  }

  Future<int> _estimateTotalPages(String filename) async {
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
      return 0; // Return 0 to indicate we couldn't estimate
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final comicProvider = Provider.of<ComicProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    // Get imported files from the provider
    final importedFiles = comicProvider.importedFiles;
    
    final appBar = AppBar(
      title: Text(
        languageProvider.translate('downloads'),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            FadePageRoute(child: const ComicReadingPage()),
          );
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
          child: Center(
            child: TextButton(
              onPressed: _pickAndConvertFile,
              child: Text(
                languageProvider.translate('edit'),
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: languageProvider.translate('server')),
        ],
        labelColor: Colors.blue,
        unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.black54,
        indicatorColor: Colors.blue,
      ),
    );

    // Server Tab (API)
    final serverTab = Column(
      children: [
        if (_isLoading) 
          Column(
            children: [
              LinearProgressIndicator(),
              if (_loadingMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(_loadingMessage),
                ),
            ],
          ),
          
        // Server URL configuration
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverUrlController,
                  decoration: InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://reader-comic-app.onrender.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: _updateServerUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text("Connect"),
              ),
            ],
          ),
        ),
        
        // Error message with retry button
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: EdgeInsets.all(8),
              color: Colors.red.withOpacity(0.1),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isRetrying ? null : _retryOperation,
                        child: Text(_isRetrying ? 'Retrying...' : 'Retry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Server Comics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
        
        Expanded(
          child: cbzFiles.isEmpty && !_isLoading
            ? Center(
                child: Text(
                  'No comics found on the server',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              )
            : ListView.separated(
                itemCount: cbzFiles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = cbzFiles[index];
                  return ListTile(
                    title: Text(
                      file,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.visibility, color: Colors.blue),
                          onPressed: () => _previewFirstPage(file),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            // Silme onayı al
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete Comic'),
                                content: Text('Are you sure you want to delete "$file"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ) ?? false;
                            
                            // Onaylanırsa sil
                            if (confirmed) {
                              setState(() {
                                _isLoading = true;
                                _loadingMessage = 'Deleting comic...';
                              });
                              
                              final success = await apiService.deleteCbz(file);
                              
                              setState(() {
                                _isLoading = false;
                              });
                              
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Comic deleted successfully"))
                                );
                                // Listeyi yenile
                                _fetchCbzList();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Failed to delete comic"),
                                    backgroundColor: Colors.red,
                                  )
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: SizedBox(
                            width: 40,
                            height: 40,
                            child: Image.asset('lib/assets/images/addbuton2.png', color: Colors.blue),
                          ),
                          onPressed: () {
                            _addComicToLibrary(file);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
        
        // Seçili sayfa resmi
        if (currentPageImage != null)
          Container(
            height: 300,
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.memory(
                currentPageImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
      ],
    );

    final body = TabBarView(
      controller: _tabController,
      children: [
        serverTab,
      ],
    );

    return SharedNavigation(
      currentIndex: 2, // Downloads is selected
      appBar: appBar,
      body: body,
    );
  }
}