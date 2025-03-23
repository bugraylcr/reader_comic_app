import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import '../api/comic_api_service.dart';
import 'package:file_picker/file_picker.dart';
import '../shared_navigation.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../language_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Make the API URL configurable
  String _serverUrl = 'http://10.90.204.23:5000';
  late ComicApiService apiService;
  TextEditingController _serverUrlController = TextEditingController();
  String? _errorMessage;
  bool _isRetrying = false;
  
  List<String> cbzFiles = [];
  Uint8List? currentPageImage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = _serverUrl;
    apiService = ComicApiService(baseUrl: _serverUrl);
    _fetchCbzList();
  }
  
  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  // Update method to change server URL
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
      isLoading = true;
      _errorMessage = null;
      _isRetrying = false;
    });
    
    try {
      // Timeout set to 30 seconds in the API service class
      final files = await apiService.listCbzFiles();
      
      setState(() {
        cbzFiles = files;
        isLoading = false;
      });
    } catch (e) {
      print('CBZ listesi alınamadı: $e');
      setState(() {
        isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _previewFirstPage(String filename) async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
      _isRetrying = false;
    });
    
    try {
      // Timeout set to 30 seconds in the API service class
      final imageBytes = await apiService.previewCbz(filename);
      
      setState(() {
        currentPageImage = imageBytes;
        isLoading = false;
      });
    } catch (e) {
      print('Önizleme hatası: $e');
      setState(() {
        isLoading = false;
        _errorMessage = 'Preview error: ${e.toString()}';
      });
    }
  }

  Future<void> _getSpecificPage(String filename, int page) async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
      _isRetrying = false;
    });
    
    try {
      final imageBytes = await apiService.getPageCbz(filename, page);
      setState(() {
        currentPageImage = imageBytes;
        isLoading = false;
      });
    } catch (e) {
      print('Sayfa hatası: $e');
      setState(() {
        isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final appBar = AppBar(
      title: Text(
        'Comic API',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      centerTitle: true,
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      elevation: 0,
      scrolledUnderElevation: 0,
    );

    final body = Column(
      children: [
        if (isLoading) 
          LinearProgressIndicator(),
          
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
                    hintText: 'http://10.90.204.23:5000',
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
            'API Comics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
        
        Expanded(
          child: cbzFiles.isEmpty && !isLoading
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
                    trailing: const Icon(Icons.visibility, color: Colors.blue),
                    onTap: () => _previewFirstPage(file),
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
          
        // Button row
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (cbzFiles.isNotEmpty)
                ElevatedButton(
                  onPressed: () => _getSpecificPage(cbzFiles[0], 3),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Page 3'),
                ),
              ElevatedButton(
                onPressed: () => pickAndConvertCbr(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text("Convert CBR"),
              ),
            ],
          ),
        ),
      ],
    );

    return SharedNavigation(
      currentIndex: 4, // API tab is selected
      appBar: appBar,
      body: body,
    );
  }

  // CBR dosyası seçme ve dönüştürme fonksiyonu
  Future<void> pickAndConvertCbr() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cbr'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          setState(() {
            isLoading = true;
            _errorMessage = null;
            _isRetrying = false;
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
        isLoading = false;
        _errorMessage = 'Conversion error: ${e.toString()}';
      });
    }
  }
} 