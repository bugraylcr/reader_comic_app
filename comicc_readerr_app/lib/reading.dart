/// reading.dart/// 
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:page_flip/page_flip.dart';
import 'cbz_helper.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'comic_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:comicc_readerr_app/api/comic_api_service.dart';
import 'package:path_provider/path_provider.dart';

class ReadingPage extends StatefulWidget {
  final String cbzFilePath;

  const ReadingPage({Key? key, required this.cbzFilePath}) : super(key: key);

  @override
  _ReadingPageState createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> with SingleTickerProviderStateMixin {
  List<File> _images = [];
  bool _isLoading = true;
  int _currentPage = 0;
  late PageController _pageController;
  late ScrollController _thumbnailController;
  String _errorMessage = '';
  bool _showUI = true;
  late AnimationController _animationController;
  bool _isZoomed = false;
  TransformationController _transformationController = TransformationController();
  
  // Page turn effect variables
  double _currentPageValue = 0.0;
  bool _isPageTurning = false;
  final GlobalKey<PageFlipWidgetState> _pageFlipController = GlobalKey<PageFlipWidgetState>();

  // Add this variable to the _ReadingPageState class
  bool _isCtrlPressed = false;

  // Add these variables to the _ReadingPageState class
  bool _showZoomToast = false;
  double _currentZoomLevel = 1.0;
  Timer? _zoomToastTimer;

  // Add this variable to the _ReadingPageState class
  bool _isFullScreen = false;

  // Add this class variable to store the estimated total pages
  int _estimatedTotalPages = 1;

  // Add these variables to store cached pages
  Map<String, List<File>> _cachedComics = {};
  Map<String, int> _cachedTotalPages = {};

  @override
  void initState() {
    super.initState();
    // Set preferred orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Set system UI to immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Get the last read page from the provider
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    final selectedComic = comicProvider.selectedComic;
    
    // Initialize page controller, but note that it will be updated in _loadImages
    final initialPage = selectedComic?.lastReadPage ?? 0;
    _pageController = PageController(initialPage: initialPage);
    _pageController.addListener(_pageControllerListener);
    
    _thumbnailController = ScrollController();
    _currentPage = initialPage;
    
    // Initialize animation controller for UI animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    _loadImages();
    
    // Listen for transformation changes to detect zoom
    _transformationController.addListener(() {
      final scale = _transformationController.value.getMaxScaleOnAxis();
      final newIsZoomed = scale > 1.1;
      if (_isZoomed != newIsZoomed) {
        setState(() {
          _isZoomed = newIsZoomed;
        });
      }
    });
  }

  void _pageControllerListener() {
    setState(() {
      _currentPageValue = _pageController.page ?? 0;
      _isPageTurning = _pageController.position.isScrollingNotifier.value;
    });
  }

  @override
  void dispose() {
    // Manage cache size to prevent memory issues
    _manageCacheSize();
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Save reading progress when leaving the page
    _saveReadingProgress();
    _pageController.removeListener(_pageControllerListener);
    _pageController.dispose();
    _thumbnailController.dispose();
    _animationController.dispose();
    _zoomToastTimer?.cancel();
    super.dispose();
  }

  void _saveReadingProgress() {
    if (_images.isEmpty) return;
    
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    comicProvider.updateComicProgress(
      widget.cbzFilePath,
      _currentPage + 1, // Add 1 to convert from 0-based index to 1-based page number
      _images.length
    );
  }

  Future<void> _loadImages() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      final comicProvider = Provider.of<ComicProvider>(context, listen: false);
      final selectedComic = comicProvider.selectedComic;
      final lastReadPage = selectedComic?.lastReadPage ?? 0;
      
      // Cache kontrolünü daha etkili hale getirelim
      if (_cachedComics.containsKey(widget.cbzFilePath) && 
          _cachedComics[widget.cbzFilePath]!.isNotEmpty) {
        
        // Cache'den yüklenen dosyaların varlığını kontrol et
        final cachedFiles = _cachedComics[widget.cbzFilePath]!;
        final validFiles = cachedFiles.where((file) => file.existsSync()).toList();
        
        // Eğer geçerli dosya sayısı azsa, cache'i temizle ve yeniden yükle
        if (validFiles.length < cachedFiles.length * 0.8) {  // %80 geçerli dosya eşiği
          print('⚠️ Cache bozulmuş, yeniden yükleme yapılıyor');
          _cachedComics.remove(widget.cbzFilePath);
        } else {
          print('📋 Cache kullanılıyor: ${widget.cbzFilePath} - ${validFiles.length} sayfa');
        setState(() {
            _images = validFiles;
          
          if (_cachedTotalPages.containsKey(widget.cbzFilePath)) {
            _estimatedTotalPages = _cachedTotalPages[widget.cbzFilePath]!;
          }
          
          _isLoading = false;
          _currentPage = lastReadPage;
        });
        
          // PageController'ı güncelle
        WidgetsBinding.instance.addPostFrameCallback((_) {
            // Doğru sayfa numarasını belirle
            final safePageIndex = math.min(lastReadPage, _images.length - 1);
            
            if (_pageController.hasClients) {
              _pageController.jumpToPage(safePageIndex);
              print('✅ Cache ile son okunan sayfaya geçildi: $safePageIndex');
            } else {
              _pageController.dispose();
              _pageController = PageController(initialPage: safePageIndex);
              _pageController.addListener(_pageControllerListener);
            }
            
            _scrollToCurrentThumbnail();
        });
        
        return;
        }
      }
      
      // Check if this is a server comic
      if (selectedComic != null && selectedComic.isServerComic) {
        // This is a server comic, load images from the server
        await _loadServerComicImages();
      } else {
        // This is a local comic, load from file
        await _loadLocalComicImages();
      }
      
      // Cache the loaded images for future use
      if (_images.isNotEmpty) {
        _cachedComics[widget.cbzFilePath] = List.from(_images);
        
        // For server comics, also cache the estimated total pages
        if (selectedComic != null && selectedComic.isServerComic) {
          _cachedTotalPages[widget.cbzFilePath] = _estimatedTotalPages;
        }
        
        // Set the current page to the last read page
        _currentPage = lastReadPage;
        
        // Update comic provider with total pages
        comicProvider.updateComicProgress(
          widget.cbzFilePath,
          lastReadPage,
          _images.length
        );
        
        // Add post-frame callback to ensure the controller is updated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Sadece yeterli sayfa yüklenmişse sayfaya git
          if (_images.length > lastReadPage) {
            // Make sure we're going to a valid page within our image list
            final safePageIndex = math.min(lastReadPage, _images.length - 1);
            
            if (_pageController.hasClients) {
              // If controller is attached, simply jump to the page
              _pageController.jumpToPage(safePageIndex);
              print('✅ Jumped to last read page (cached): $safePageIndex');
            } else {
              // In case the controller isn't attached yet, recreate it
              _pageController.dispose();
              _pageController = PageController(initialPage: safePageIndex);
              _pageController.addListener(_pageControllerListener);
            }
            
            // Also scroll the thumbnail to the current page
            _scrollToCurrentThumbnail();
          } else {
            print('⚠️ Not enough pages loaded to jump to page $lastReadPage');
          }
        });
      }
    } catch (e) {
      print('❌ Error loading images: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading comic: $e';
      });
    }
  }

  Future<void> _loadLocalComicImages() async {
      // Verify file exists
      final file = File(widget.cbzFilePath);
      if (!file.existsSync()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'File not found: ${widget.cbzFilePath}';
        });
        return;
      }
      
    print('🔄 Loading local comic: ${widget.cbzFilePath}');
      print('📊 File size: ${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
      
    List<File> images = await CBZHelper.extractCBZ(widget.cbzFilePath);
      
      if (images.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No images found in the comic file';
        });
      } else {
    setState(() {
      _images = images;
      _isLoading = false;
    });
    }
  }

  Future<void> _loadServerComicImages() async {
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    final selectedComic = comicProvider.selectedComic;
    
    if (selectedComic == null || !selectedComic.isServerComic || 
        selectedComic.serverUrl == null || selectedComic.serverFilename == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Geçersiz sunucu çizgi roman verisi';
      });
      return;
    }
    
    final serverUrl = selectedComic.serverUrl!;
    final filename = selectedComic.serverFilename!;
    
    print('🔄 Sunucu çizgi romanı yükleniyor: $filename - URL: $serverUrl');
    
    try {
      final apiService = ComicApiService(baseUrl: serverUrl);
      
      // Geçici dizin yerine kalıcı uygulama dizini kullan
      // Bu sayede uygulama kapansa bile dosyalar kalır
      final directory = await getApplicationDocumentsDirectory();
      final comicDir = '${directory.path}/comics/${Uri.encodeComponent(filename)}';
      
      // Dizin yoksa oluştur
      final dir = Directory(comicDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Toplam sayfa sayısını tahmin et
      _estimatedTotalPages = await _estimateTotalPages(apiService, filename);
      print('📊 Tahmini toplam sayfa: $_estimatedTotalPages');
      
      // İlk sayfayı kontrol et - dosya varsa tekrar indirme
      final firstPageFile = File('$comicDir/page_0.webp'); // .webp uzantısı
      if (!firstPageFile.existsSync()) {
        final firstPageData = await apiService.getPageCbz(filename, 1);
        await firstPageFile.writeAsBytes(firstPageData);
      } else {
        print('📋 İlk sayfa zaten indirilmiş, tekrar indirilmiyor');
      }
      
      setState(() {
        _images = [firstPageFile];
        _isLoading = false;
        _currentPage = 0;
      });
      
      // Arka planda diğer sayfaları paralel olarak yükle
      print('🚀 Arka planda daha fazla sayfa yükleniyor, son okunan: ${selectedComic.lastReadPage}');
      await _loadAllServerPagesParallel();
      
    } catch (e) {
      print('❌ Sunucu çizgi romanı yükleme hatası: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Çizgi roman yüklenemedi: $e';
      });
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
  
  Future<void> _loadAllServerPagesParallel() async {
      final comicProvider = Provider.of<ComicProvider>(context, listen: false);
      final selectedComic = comicProvider.selectedComic;
    
    if (selectedComic == null ||
        !selectedComic.isServerComic ||
        selectedComic.serverUrl == null ||
        selectedComic.serverFilename == null) return;

    final serverUrl = selectedComic.serverUrl!;
    final filename = selectedComic.serverFilename!;
    final apiService = ComicApiService(baseUrl: serverUrl);

    // Geçici dizin yerine kalıcı uygulama dizini kullan
    final directory = await getApplicationDocumentsDirectory();
    final comicDir = '${directory.path}/comics/${Uri.encodeComponent(filename)}';
    
    final dir = Directory(comicDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Önce toplam sayfa sayısını tahmin et
    _estimatedTotalPages = await _estimateTotalPages(apiService, filename);
    print('📘 Tahmini toplam sayfa: $_estimatedTotalPages');
    
    // Önce ilk sayfayı hemen göstermek için yükle (UI için)
    final firstPageFile = File('$comicDir/page_0.webp'); // .webp uzantısı
    if (!firstPageFile.existsSync()) {
      try {
        final firstPageData = await apiService.getPageCbz(filename, 1);
        await firstPageFile.writeAsBytes(firstPageData);
      } catch (e) {
        print('❌ İlk sayfa yükleme hatası: $e');
      }
    }
    
    // İlk sayfa yüklendiyse göster
    if (firstPageFile.existsSync()) {
      setState(() {
        _images = [firstPageFile];
        _isLoading = false;
      });
    }

    // Paralel olarak tüm sayfaları yükle
    List<Future<File?>> futures = [];
    
    // Her sayfa için ayrı bir future oluştur
    for (int i = 0; i < _estimatedTotalPages; i++) {
      // İlk sayfayı zaten yükledik, onu atla
      if (i == 0) continue;
      
      final pageFile = File('$comicDir/page_${i}.webp'); // .webp uzantısı
      
      // Eğer dosya zaten varsa, tekrar yükleme
      if (pageFile.existsSync()) {
        futures.add(Future.value(pageFile));
        continue;
      }
      
      // Yoksa asenkron bir şekilde yükle
      futures.add(_loadPageParallel(apiService, filename, i, pageFile));
    }

    // Tüm sayfaları paralel olarak yükle
    print('🚀 Paralel yükleme başlatıldı - ${futures.length} sayfa için');
    
    // Sayfaları düzenli aralıklarla UI'a ekle (batch processing)
    int batchSize = 5; // Her seferde 5 sayfa ekle
    int completedCount = 0;
    
    while (completedCount < futures.length) {
      int endIndex = math.min(completedCount + batchSize, futures.length);
      List<Future<File?>> currentBatch = futures.sublist(completedCount, endIndex);
      
      // Bu grubu paralel olarak bekle
      List<File?> loadedFiles = await Future.wait(currentBatch);
      
      // Sadece başarılı olanları ekle
      List<File> validFiles = loadedFiles
          .where((file) => file != null && file.existsSync())
          .cast<File>()
          .toList();
      
      // UI'ı güncelle
      if (mounted && validFiles.isNotEmpty) {
        setState(() {
          _images.addAll(validFiles);
          // Eklenen sayfaları index'e göre sırala
          _images.sort((a, b) {
            final indexA = int.tryParse(a.path.split('page_').last.split('.').first) ?? 0;
            final indexB = int.tryParse(b.path.split('page_').last.split('.').first) ?? 0;
        return indexA.compareTo(indexB);
          });
      });
      
        // Cache'i güncelle
          _cachedComics[widget.cbzFilePath] = List.from(_images);
      }
        
      completedCount = endIndex;
    }
    
    // İşlem tamamlandı, tahmini toplam sayfayı da güncelle
        _cachedTotalPages[widget.cbzFilePath] = _estimatedTotalPages;
        
    if (mounted) {
      // ComicProvider'ı güncelle
      comicProvider.updateComicProgress(
        widget.cbzFilePath,
        selectedComic.lastReadPage,
        _estimatedTotalPages
      );
      
      // Son olarak, kaldığın sayfaya git
      final lastRead = selectedComic.lastReadPage;
      final safePageIndex = math.min(lastRead, _images.length - 1);
      
      // Sayfa geçişi
      WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(safePageIndex);
              print('✅ Son okunan sayfaya geçildi: $safePageIndex');
            } else {
              _pageController = PageController(initialPage: safePageIndex);
              _pageController.addListener(_pageControllerListener);
            }
            
        // Thumbnail'i güncelle
            _scrollToCurrentThumbnail();
      });
    }
    
    print('🎉 Paralel sayfa yükleme tamamlandı: ${_images.length} sayfa yüklendi');
  }

  // Tek bir sayfayı paralel olarak yükleyen yardımcı fonksiyon
  Future<File?> _loadPageParallel(
    ComicApiService apiService, 
    String filename, 
    int pageIndex, 
    File pageFile
  ) async {
    try {
      // API 1-tabanlı, uygulamamız 0-tabanlı
      final pageData = await apiService.getPageCbz(filename, pageIndex + 1);
      
      // Dosya uzantısını .webp olarak değiştir
      final webpFile = File('${pageFile.path.replaceAll('.jpg', '.webp')}');
      
      await webpFile.writeAsBytes(pageData);
      print('✅ Sayfa $pageIndex paralel olarak yüklendi');
      return webpFile;
    } catch (e) {
      print('❌ Sayfa $pageIndex yükleme hatası: $e');
      return null; // Hata durumunda null döndür
    }
  }

  // Update this method to check against the estimated total
  Future<void> _loadServerPageOnDemand(int pageIndex) async {
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    final selectedComic = comicProvider.selectedComic;
    
    if (selectedComic == null || !selectedComic.isServerComic || 
        selectedComic.serverUrl == null || selectedComic.serverFilename == null) {
      return;
    }
    
    // Tahmini toplam sayfayı kontrol et
    if (pageIndex >= _estimatedTotalPages) {
      print('⚠️ Sayfa $pageIndex tahmini toplam sayfa $_estimatedTotalPages sınırını aşıyor, yükleme yapılmıyor');
      return;
    }
    
    if (pageIndex < _images.length && _images[pageIndex].path.isNotEmpty && _images[pageIndex].existsSync()) {
      print('📋 Sayfa $pageIndex zaten yüklü, tekrar yüklenmiyor');
      return;
    }
    
    try {
      // Yükleme göstergesi ekle
      if (mounted) {
        setState(() {
          if (pageIndex >= _images.length) {
            _images.add(File(''));
          }
        });
      }
      
      final serverUrl = selectedComic.serverUrl!;
      final filename = selectedComic.serverFilename!;
      
      final apiService = ComicApiService(baseUrl: serverUrl);
      
      // Kalıcı depolama dizini kullan
      final directory = await getApplicationDocumentsDirectory();
      final comicDir = '${directory.path}/comics/${Uri.encodeComponent(filename)}';
      
      // Dizin kontrolü
      final dir = Directory(comicDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Dosya var mı kontrol et
      final pageFile = File('$comicDir/page_$pageIndex.webp'); // .webp uzantısı
      if (!pageFile.existsSync()) {
        // Dosya yoksa indir
        final pageData = await apiService.getPageCbz(filename, pageIndex + 1);
        await pageFile.writeAsBytes(pageData);
      } else {
        print('📋 Sayfa $pageIndex zaten disk üzerinde mevcut, tekrar indirilmiyor');
      }
      
      // UI'ı güncelle
      if (mounted) {
        setState(() {
          if (pageIndex < _images.length) {
            _images[pageIndex] = pageFile;
          } else {
            _images.add(pageFile);
          }
          
          // Cache'i güncelle
          _cachedComics[widget.cbzFilePath] = List.from(_images);
        });
      }
    } catch (e) {
      // Hata yönetimi kısmı aynı kalabilir
      // ... Mevcut kodundan devam et
    }
  }

  // Update the onPageChanged method to check against estimated total
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    
    _saveReadingProgress();
    _scrollToCurrentThumbnail();
    
    final comicProvider = Provider.of<ComicProvider>(context, listen: false);
    final selectedComic = comicProvider.selectedComic;
    
    if (selectedComic != null && selectedComic.isServerComic) {
      // Check if we're near the estimated end
      if (page >= _estimatedTotalPages - 1) {
        print('Near or at the estimated end of comic, not preloading more pages');
        return;
      }
      
      // Preload next 2 pages if they don't exist yet
      for (int i = page + 1; i <= page + 2; i++) {
        if (i < _estimatedTotalPages && i >= _images.length) {
          _loadServerPageOnDemand(i);
        }
      }
    }
  }

  void _scrollToCurrentThumbnail() {
    if (_images.isEmpty) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final thumbnailWidth = 50 + 8; // 50px width + 8px margin (4px on each side)
    
    // Calculate the target scroll position to center the current thumbnail
    final targetPosition = _currentPage * thumbnailWidth - (screenWidth / 2) + (thumbnailWidth / 2);
    
    // Only scroll if the controller is attached and the position is valid
    if (_thumbnailController.hasClients) {
      // Ensure we don't scroll beyond the content bounds
      final maxScroll = _thumbnailController.position.maxScrollExtent;
      final minScroll = _thumbnailController.position.minScrollExtent;
      final boundedPosition = math.min(maxScroll, math.max(minScroll, targetPosition));
      
      _thumbnailController.animateTo(
        boundedPosition,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      // If controller isn't attached yet, schedule the scroll for the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentThumbnail();
      });
    }
  }

  void _enterFullScreenMode() {
    setState(() {
      _showUI = false;
      _isFullScreen = true;
      
      // Hide system UI for true full screen experience
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      
      // Force the screen to use the entire available space
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ));
    });
  }

  void _toggleUI() {
    if (_showUI) {
      _enterFullScreenMode();
      _animationController.reverse();
    } else {
      setState(() {
        _showUI = true;
        _isFullScreen = false;
        // Show system UI when exiting full screen
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        _animationController.forward();
      });
    }
  }

  void _resetZoom() {
    // Animate the zoom reset for a smoother experience
    final Matrix4 identity = Matrix4.identity();
    
    // If we're already at identity, no need to animate
    if (_transformationController.value == identity) return;
    
    // Create animation controller for smooth reset
    final AnimationController animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    // Create animation from current transform to identity
    Animation<Matrix4> animation = Matrix4Tween(
      begin: _transformationController.value,
      end: identity,
    ).animate(CurvedAnimation(
      parent: animController,
      curve: Curves.easeOutCubic,
    ));
    
    // Update transformation on each animation frame
    animController.addListener(() {
      _transformationController.value = animation.value;
    });
    
    // Clean up when done
    animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animController.dispose();
        setState(() {
          _isZoomed = false;
        });
      }
    });
    
    // Start the animation
    animController.forward();
  }

  void _goToNextPage() {
    if (_currentPage < _images.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basenameWithoutExtension(widget.cbzFilePath);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      // Add AppBar for error state
      appBar: _errorMessage.isNotEmpty || _images.isEmpty
        ? AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          )
        : null,
      body: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                      strokeWidth: 3,
                    ),
                      ),
                      SizedBox(height: 24),
                  Text(
                    'Loading comic...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                      ),
                    ],
                  ),
                )
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _images.isEmpty
                  ? _buildEmptyView()
                  : _buildReadingView(fileName, bottomPadding, screenSize),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64),
            SizedBox(height: 24),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadImages,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
                      child: Column(
          mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
            Icon(
              Icons.warning_amber_rounded, 
              color: Colors.amber, 
              size: 64
            ),
            SizedBox(height: 24),
                          Text(
                            'No images found in this comic file',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadImages,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildReadingView(String fileName, double bottomPadding, Size screenSize) {
    return GestureDetector(
      onTap: _isZoomed ? null : _toggleUI,
                      child: Stack(
                        children: [
          // Comic pages with page turn effect
                          PageView.builder(
                            controller: _pageController,
                            itemCount: _images.length,
                            onPageChanged: _onPageChanged,
            physics: _isZoomed 
                ? NeverScrollableScrollPhysics() 
                : const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
              // Calculate page turn effect
              final double pageOffset = (index - _currentPageValue).abs();
              final isRightPage = index > _currentPageValue;
              final double pageTurnEffect = _isPageTurning ? (1 - pageOffset.clamp(0.0, 0.5) * 2) : 1.0;
              
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateY(isRightPage ? -pageOffset * 0.5 : pageOffset * 0.5)
                  ..scale(_isFullScreen ? 1.0 : (0.9 + pageTurnEffect * 0.1)),
                alignment: isRightPage ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                                padding: EdgeInsets.only(
                    left: _isFullScreen ? 0.0 : 8.0,
                    right: _isFullScreen ? 0.0 : 8.0,
                    top: _isFullScreen ? 0.0 : 8.0,
                    bottom: _showUI ? 120.0 + bottomPadding : (_isFullScreen ? 0.0 : 8.0),
                  ),
                  child: ClipRRect(
                    borderRadius: _isFullScreen ? BorderRadius.zero : BorderRadius.circular(8),
                    child: Container(
                      width: _isFullScreen ? MediaQuery.of(context).size.width : null,
                      height: _isFullScreen ? MediaQuery.of(context).size.height : null,
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 1.0,
                        maxScale: 4.0,
                        boundaryMargin: EdgeInsets.all(40.0),
                        clipBehavior: Clip.none,
                        panEnabled: _isZoomed,
                        scaleEnabled: true,
                        onInteractionStart: (details) {
                          if (details.pointerCount > 1) {
                            setState(() {
                              _isZoomed = true;
                            });
                          }
                        },
                        onInteractionEnd: (details) {
                          final scale = _transformationController.value.getMaxScaleOnAxis();
                          setState(() {
                            _isZoomed = scale > 1.1;
                          });
                        },
                        child: Listener(
                          onPointerSignal: _onMouseScroll,
                          child: GestureDetector(
                            onDoubleTap: () {
                              if (_isZoomed) {
                                _resetZoom();
                              } else {
                                // Different zoom levels for mobile vs desktop
                                final zoomLevel = isMobile() ? 2.0 : 2.5;
                                
                                // Use the improved matrix transformation approach
                                final Offset center = Offset(screenSize.width / 2, screenSize.height / 2);
                                
                                final Matrix4 matrix = Matrix4.identity()
                                  ..translate(-center.dx, -center.dy)
                                  ..scale(zoomLevel)
                                  ..translate(center.dx, center.dy);
                                
                                _transformationController.value = matrix;
                                setState(() {
                                  _isZoomed = true;
                                });
                              }
                            },
                            child: Hero(
                              tag: 'comic_page_$index',
                              child: Image.file(
                                _images[index],
                                fit: _isFullScreen ? BoxFit.fill : BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                cacheHeight: 2048,
                                cacheWidth: 1536,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[900],
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, color: Colors.white70, size: 48),
                                        SizedBox(height: 16),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
          ),
          
          // Left/Right tap areas for page navigation (only when not zoomed)
          if (!_isZoomed)
            Row(
              children: [
                // Left side - previous page
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () {
                      if (!_showUI) _goToPreviousPage();
                    },
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Middle area - toggle UI
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _toggleUI,
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Right side - next page
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () {
                      if (!_showUI) _goToNextPage();
                    },
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
                          ),
                          
                          // UI elements with improved animation
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return AnimatedSlide(
                            duration: Duration(milliseconds: 200),
                            offset: _showUI ? Offset.zero : Offset(0, 1),
                            child: AnimatedOpacity(
                              opacity: _showUI ? 1.0 : 0.0,
                              duration: Duration(milliseconds: 200),
                              child: Column(
                                children: [
                                  // Header with blur effect
                                  ClipRect(
                                    child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                                      child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.5,
                                ),
                              ),
                            ),
                                        child: SafeArea(
                                          child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                            child: Row(
                                              children: [
                                                IconButton(
                                      icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                                                  onPressed: () => Navigator.pop(context),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    fileName,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.find_in_page, color: Colors.white),
                                                  onPressed: _showPageNavigationDialog,
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.more_horiz, color: Colors.white),
                                      onPressed: _showMoreOptions,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  Spacer(),
                                  
                                  // Bottom thumbnails with blur effect
                                  ClipRect(
                                    child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                                      child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.5,
                                ),
                              ),
                            ),
                                        child: Column(
                                          children: [
                                // Page indicator with progress bar
                                            Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                                'Page: ${_currentPage + 1} of ${_images.length}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${((_currentPage + 1) / _images.length * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      // Progress bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: (_currentPage + 1) / _images.length,
                                          backgroundColor: Colors.grey[800],
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                            // Thumbnails with improved scrolling
                                Container(
                                  height: 80,
                                              child: ListView.builder(
                                                controller: _thumbnailController,
                                                scrollDirection: Axis.horizontal,
                                                physics: BouncingScrollPhysics(),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                                                  final isCurrentPage = _currentPage == index;
                                                  return GestureDetector(
                                                    onTap: () {
                                                      // When tapping a thumbnail, update the page and ensure thumbnails scroll
                                                      _pageController.animateToPage(
                                                        index,
                                                        duration: Duration(milliseconds: 300),
                                                        curve: Curves.easeOutCubic,
                                                      );
                                                      
                                                      // Force thumbnail scroll after a short delay to ensure UI updates
                                                      Future.delayed(Duration(milliseconds: 50), () {
                                                        setState(() {
                                                          _currentPage = index;
                                                        });
                                                        _scrollToCurrentThumbnail();
                                                      });
                                                    },
                                                    child: Container(
                                          width: 50,
                                          margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                      decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: isCurrentPage ? [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(0.6),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ] : null,
                                            border: Border.all(
                                              color: isCurrentPage ? Colors.blue : Colors.transparent,
                                              width: 2,
                                            ),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(4),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                        child: Image.file(
                                                          _images[index],
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return Container(
                                                              color: Colors.grey[800],
                                                        child: Icon(Icons.broken_image, color: Colors.white60, size: 20),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                // Page number overlay
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(vertical: 2),
                                                    color: Colors.black.withOpacity(0.6),
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                                // Add visual indicator for current page
                                                if (isCurrentPage)
                                                  Positioned(
                                                    top: 2,
                                                    right: 2,
                                                    child: Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 8,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            SizedBox(height: bottomPadding), // Add safe area padding
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
              );
            },
          ),
          
          // Zoom indicator
          if (_isZoomed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      '${(_transformationController.value.getMaxScaleOnAxis() * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Reset zoom button
          if (_isZoomed)
            Positioned(
              bottom: 24,
              right: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: Icon(Icons.zoom_out_map, color: Colors.white),
                  tooltip: 'Reset Zoom',
                  onPressed: () {
                    setState(() {
                      _resetZoom();
                      _isZoomed = false;
                    });
                  },
                ),
              ),
            ),
          
          // More visible zoom indicator
          if (_showZoomToast)
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentZoomLevel > 1.0 ? Icons.zoom_in : Icons.zoom_out,
                        color: Colors.blue,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        '${(_currentZoomLevel * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.find_in_page, color: Colors.blue),
                title: Text('Go to Page', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showPageNavigationDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.skip_previous, color: Colors.blue),
                title: Text('First Page', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pageController.animateToPage(
                    0,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.skip_next, color: Colors.blue),
                title: Text('Last Page', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pageController.animateToPage(
                    _images.length - 1,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: Colors.blue),
                title: Text('Comic Info', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showComicInfo();
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showComicInfo() {
    final fileName = path.basenameWithoutExtension(widget.cbzFilePath);
    final fileSize = File(widget.cbzFilePath).lengthSync() / (1024 * 1024);
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Comic Information',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Title', fileName),
              Divider(color: Colors.grey[700]),
              _infoRow('Pages', '${_images.length}'),
              Divider(color: Colors.grey[700]),
              _infoRow('Current Page', '${_currentPage + 1}'),
              Divider(color: Colors.grey[700]),
              _infoRow('Progress', '${((_currentPage + 1) / _images.length * 100).toStringAsFixed(1)}%'),
              Divider(color: Colors.grey[700]),
              _infoRow('File Size', '${fileSize.toStringAsFixed(2)} MB'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: Colors.blue)),
                          ),
                        ],
                      ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
            ),
    );
  }

  void _showPageNavigationDialog() {
    final TextEditingController pageController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Go to Page',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter page number (1-${_images.length})',
                style: TextStyle(color: Colors.grey[400]),
              ),
              SizedBox(height: 16),
              TextField(
                controller: pageController,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                autofocus: true,
                onSubmitted: (value) {
                  _navigateToPage(value);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () {
                _navigateToPage(pageController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Go'),
            ),
          ],
        ),
      ),
    );
    
    // Focus the text field after dialog is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  void _navigateToPage(String pageText) {
    if (pageText.isEmpty) return;
    
    int pageNumber = int.tryParse(pageText) ?? 0;
    
    // Validate page number
    if (pageNumber < 1) pageNumber = 1;
    if (pageNumber > _images.length) pageNumber = _images.length;
    
    // Convert from 1-based page number to 0-based index
    final pageIndex = pageNumber - 1;
    
    // Animate to the page
    _pageController.animateToPage(
      pageIndex,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    
    // Update state and scroll thumbnails
    setState(() {
      _currentPage = pageIndex;
    });
    
    // Add delay to ensure UI updates before scrolling
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollToCurrentThumbnail();
    });
  }

  bool isDesktop() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  bool isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }

  void _onMouseScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        // Zoom oranını belirle (tekerlek yukarı = büyüt, aşağı = küçült)
        double zoomFactor = event.scrollDelta.dy > 0 ? 0.8 : 1.2;

        // Geçerli ölçek değerini al
        double currentScale = _transformationController.value.getMaxScaleOnAxis();
        double newScale = currentScale * zoomFactor;

        // Zoom sınırlarını belirle
        newScale = newScale.clamp(1.0, 4.0);

        // Eğer ölçek değişmemişse işlem yapma
        if (newScale == currentScale) return;

        // Pencerenin yerel koordinatlarını al
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset localFocalPoint = renderBox.globalToLocal(event.position);

        // Zoom merkezini belirle
        final Offset focalPoint = localFocalPoint;

        // Yeni bir matris oluştur ve ölçekleme uygula
        final Matrix4 matrix = Matrix4.identity()
          ..translate(-focalPoint.dx, -focalPoint.dy)
          ..scale(newScale)
          ..translate(focalPoint.dx, focalPoint.dy);

        // Güncellenmiş dönüşümü uygula
        _transformationController.value = matrix;

        // UI'ı güncelle
        _isZoomed = newScale > 1.1;
        
        // Update zoom toast values
        _showZoomToast = true;
        _currentZoomLevel = newScale;
        
        // Set up a timer to hide the toast
        _zoomToastTimer?.cancel();
        _zoomToastTimer = Timer(Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _showZoomToast = false;
            });
          }
        });
      });
    }
  }

  // Add this method to limit the cache size and prevent memory issues
  void _manageCacheSize() {
    // Maximum number of comics to keep in cache
    const int maxCachedComics = 3;
    
    // If cache exceeds limit, remove oldest entries
    if (_cachedComics.length > maxCachedComics) {
      // Get keys sorted by when they were last accessed (you'd need to track this)
      // For simplicity, we'll just remove random entries
      final keysToRemove = _cachedComics.keys.toList()
        ..sort() // Sort alphabetically as a simple strategy
        ..sublist(0, _cachedComics.length - maxCachedComics);
      
      // Remove oldest entries
      for (final key in keysToRemove) {
        _cachedComics.remove(key);
        _cachedTotalPages.remove(key);
        print('🗑️ Removed from cache: $key');
      }
    }
  }
}
