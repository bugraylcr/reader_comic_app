import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class CBZHelper {
  static Future<List<File>> extractCBZ(String cbzFilePath, {bool extractFirstOnly = false}) async {
    try {
      final file = File(cbzFilePath);
      final bytes = await file.readAsBytes();
      
      // Decode the zip file
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Create a temporary directory to extract images
      final tempDir = await getTemporaryDirectory();
      final extractionDir = '${tempDir.path}/cbz_${path.basenameWithoutExtension(cbzFilePath)}';
      
      // Create directory if it doesn't exist
      final directory = Directory(extractionDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create(recursive: true);
      
      // Filter image files from the archive - WebP desteği eklendi
      final imageFiles = archive.files.where((file) => 
        !file.isDirectory && 
        (file.name.toLowerCase().endsWith('.jpg') || 
         file.name.toLowerCase().endsWith('.jpeg') || 
         file.name.toLowerCase().endsWith('.png') ||
         file.name.toLowerCase().endsWith('.webp'))  // WebP desteği eklendi
      ).toList();
      
      // Sort image files by name
      imageFiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      
      List<File> extractedImages = [];
      
      // Extract only the first image if extractFirstOnly is true
      final filesToProcess = extractFirstOnly ? 
          [imageFiles.first] : 
          imageFiles;
      
      // Extract image files
      for (final file in filesToProcess) {
        if (file.isFile) {
          final extractedFilePath = '$extractionDir/${path.basename(file.name)}';
          final outputFile = File(extractedFilePath);
          await outputFile.writeAsBytes(file.content as List<int>);
          extractedImages.add(outputFile);
        }
        
        // If we only need the first image and we've extracted it, we're done
        if (extractFirstOnly && extractedImages.isNotEmpty) {
          break;
        }
      }
      
      return extractedImages;
    } catch (e) {
      print('Error extracting CBZ: $e');
      return [];
    }
  }
}