import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

const String API_BASE_URL = 'https://reader-comic-app.onrender.com';

class ComicApiService {
  final String baseUrl;
  // Timeout settings
  final Duration timeout = Duration(seconds: 120); // Increased timeout

  ComicApiService({required this.baseUrl});

  // Alternatif constructor - sabit IP adresi ile
  ComicApiService.withDefaultHost() : baseUrl = API_BASE_URL;

  /// /list-cbz endpoint'ine GET isteği
  Future<List<String>> listCbzFiles() async {
    final url = Uri.parse('$baseUrl/list-cbz');
    try {
      final response = await http.get(url).timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // data örneği: {"files": ["INVINCIBLE #23.cbz", "INVINCIBLE #27.cbz"]}
        return List<String>.from(data['files']);
      } else {
        throw Exception('CBZ listesi alınamadı. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } on SocketException {
      throw Exception('Server connection failed. Check if the server is running and the URL is correct.');
    } on FormatException {
      throw Exception('Invalid response format. The server did not return valid JSON.');
    } on TimeoutException {
      throw Exception('Server request timed out after ${timeout.inSeconds} seconds. The server might be processing large files or is overloaded.');
    } catch (e) {
      throw Exception('Failed to list CBZ files: $e');
    }
  }

  /// /convert-cbr endpoint'ine form-data (multipart) ile .cbr dosyası yükler
  Future<void> convertCbrToCbz(String filePath) async {
    final url = Uri.parse('$baseUrl/convert-cbr');
    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Dönüştürme başarılı: ${data["output"]}');
      } else {
        throw Exception('CBR dönüştürme başarısız. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } on SocketException {
      throw Exception('Server connection failed. Check if the server is running and the URL is correct.');
    } on FormatException {
      throw Exception('Invalid response format. The server did not return valid JSON.');
    } on TimeoutException {
      throw Exception('Server request timed out after ${timeout.inSeconds} seconds. The server might be processing large files or is overloaded.');
    } catch (e) {
      throw Exception('Failed to convert CBR: $e');
    }
  }

  /// /preview-cbz endpoint'ine POST isteği (artık doğrudan WebP bytes döndürüyor)
  Future<Uint8List> previewCbz(String filename) async {
    final url = Uri.parse('$baseUrl/preview-cbz');
    try {
      // Add thumbnail request parameter to get smaller image
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "filename": filename,
          "thumbnail": true,  // Ask server for thumbnail instead of full image
          "max_size": 1024    // Limit image size to 1024px
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return response.bodyBytes; // ✅ JSON yok, direkt WebP byte
      } else {
        throw Exception('Önizleme başarısız. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } on SocketException {
      throw Exception('Server connection failed. Check if the server is running and the URL is correct.');
    } on TimeoutException {
      throw Exception('Server request timed out after ${timeout.inSeconds} seconds. The server might be processing large files or is overloaded.');
    } catch (e) {
      throw Exception('Failed to preview CBZ: $e');
    }
  }

  /// /page-cbz endpoint'ine POST isteği atarak belirli bir sayfayı WebP formatında alır
  Future<Uint8List> getPageCbz(String filename, int page) async {
    final url = Uri.parse('$baseUrl/page-cbz');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "filename": filename, 
          "page": page,
          "max_size": 1200  // Limit image size to 1200px
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return response.bodyBytes; // ✅ JSON yok, direkt WebP byte
      } else {
        throw Exception('Sayfa alınamadı. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } on SocketException {
      throw Exception('Server connection failed. Check if the server is running and the URL is correct.');
    } on TimeoutException {
      throw Exception('Server request timed out after ${timeout.inSeconds} seconds. The server might be processing large files or is overloaded.');
    } catch (e) {
      throw Exception('Failed to get page from CBZ: $e');
    }
  }
  
  /// Download a CBZ file from the server to local storage
  Future<File> downloadCbzFile(String filename) async {
    try {
      // Create download URL
      final downloadUrl = Uri.parse('$baseUrl/download-cbz');
      
      // Log the beginning of download
      print('Attempting to download "$filename" from $downloadUrl');
      
      // Send request to download the file
      print('Sending download request...');
      final response = await http.post(
        downloadUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"filename": filename}),
      ).timeout(timeout);
      
      print('Received response with status: ${response.statusCode}, Content-Length: ${response.contentLength}');
      
      if (response.statusCode == 200) {
        // Get the application documents directory for saving the file
        print('Getting application documents directory...');
        final directory = await getApplicationDocumentsDirectory();
        final filePath = path.join(directory.path, 'downloaded_comics', filename);
        
        // Ensure the directory exists
        print('Creating directory if needed...');
        final fileDir = Directory(path.dirname(filePath));
        if (!await fileDir.exists()) {
          await fileDir.create(recursive: true);
        }
        
        // Write the file to storage
        print('Writing ${response.bodyBytes.length} bytes to $filePath...');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        print('File downloaded successfully to: $filePath');
        return file;
      } else {
        // If the server response code is not 200, throw an exception
        final errorMsg = 'Failed to download file. Status: ${response.statusCode}, Body: ${response.body}';
        print(errorMsg);
        throw Exception(errorMsg);
      }
    } on SocketException catch (e) {
      final errorMsg = 'Server connection failed: ${e.message}. Check if the server is running at $baseUrl and the URL is correct.';
      print(errorMsg);
      throw Exception(errorMsg);
    } on TimeoutException catch (e) {
      final errorMsg = 'Download timed out after ${timeout.inSeconds} seconds: ${e.message}. The server might be processing large files or is overloaded.';
      print(errorMsg);
      throw Exception(errorMsg);
    } catch (e) {
      final errorMsg = 'Failed to download CBZ file: ${e.toString()}';
      print(errorMsg);
      throw Exception(errorMsg);
    }
  }

  /// Upload a CBZ file to the server
  Future<bool> uploadCbzFile(String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-cbz'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse = await request.send().timeout(timeout);
      
      return streamedResponse.statusCode == 200;
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  /// Delete a CBZ file from the server
  Future<bool> deleteCbz(String filename) async {
    final url = Uri.parse('$baseUrl/delete-cbz');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"filename": filename}),
      ).timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }
} 