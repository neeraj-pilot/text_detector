import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../text_detector.dart';

/// A complete text detection widget that displays an image and allows
/// users to select and copy detected text.
class TextDetectorWidget extends StatefulWidget {
  /// The path to the image file to detect text from
  final String imagePath;

  /// Callback when text is copied
  final Function(String)? onTextCopied;

  /// Callback when text blocks are selected
  final Function(List<TextBlock>)? onTextBlocksSelected;

  /// Whether to auto-detect text on load
  final bool autoDetect;

  /// Recognition level for text detection
  final RecognitionLevel recognitionLevel;

  /// Custom loading widget
  final Widget? loadingWidget;

  /// Background color
  final Color backgroundColor;

  /// Whether to show boundaries for unselected text
  final bool showUnselectedBoundaries;

  /// Single-shot mode: Perform only one detection pass with high accuracy
  final bool singleShotMode;

  /// Enable parallel multi-pass detection for better results on challenging images
  final bool enableParallelDetection;

  /// Enable brightness enhancement preprocessing
  final bool enhanceForBrightness;

  /// Preprocessing level: 'auto', 'none', 'light', 'moderate', 'aggressive'
  final String preprocessingLevel;

  const TextDetectorWidget({
    super.key,
    required this.imagePath,
    this.onTextCopied,
    this.onTextBlocksSelected,
    this.autoDetect = true,
    this.recognitionLevel = RecognitionLevel.accurate,
    this.loadingWidget,
    this.backgroundColor = Colors.black,
    this.showUnselectedBoundaries = true,
    this.singleShotMode = false,
    this.enableParallelDetection = true,
    this.enhanceForBrightness = true,
    this.preprocessingLevel = 'auto',
  });

  @override
  State<TextDetectorWidget> createState() => _TextDetectorWidgetState();
}

class _TextDetectorWidgetState extends State<TextDetectorWidget> {
  final TextDetector _textDetector = TextDetector();
  List<TextBlock>? _detectedTextBlocks;
  bool _isProcessing = false;
  File? _imageFile;
  bool _isFileReady = false;

  @override
  void initState() {
    super.initState();
    // Set initial processing state if auto-detecting
    if (widget.autoDetect) {
      _isProcessing = true;
    }
    // Schedule file initialization after first frame to ensure immediate rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFile();
    });
  }

  void _initializeFile() {
    // Create file reference (this is just a reference, not actual loading)
    final file = File(widget.imagePath);

    if (!mounted) return;

    setState(() {
      _imageFile = file;
      _isFileReady = true;
    });

    // Now that file is ready, start detection if needed
    if (widget.autoDetect) {
      _preloadImageAndDetect();
    } else {
      // Preload image even when not auto-detecting
      if (mounted) {
        precacheImage(FileImage(file), context);
      }
    }
  }

  Future<void> _preloadImageAndDetect() async {
    if (_imageFile == null) return;
    // Preload image asynchronously (non-blocking)
    precacheImage(FileImage(_imageFile!), context);
    // Detect text immediately
    _detectText();
  }

  Future<void> _detectText() async {
    // Don't set processing true here if already processing
    if (!_isProcessing) {
      setState(() {
        _isProcessing = true;
        _detectedTextBlocks = null;
      });
    }

    try {
      final blocks = await _textDetector.detectText(
        imagePath: widget.imagePath,
        recognitionLevel: widget.singleShotMode
            ? RecognitionLevel.accurate  // Always use accurate for single-shot
            : widget.recognitionLevel,
        multiPass: widget.singleShotMode
            ? false  // Single-shot mode: only one pass
            : widget.enableParallelDetection,  // Use parallel detection setting
        enhanceForBrightness: widget.singleShotMode
            ? false  // No preprocessing in single-shot mode
            : widget.enhanceForBrightness,
        preprocessingLevel: widget.singleShotMode
            ? 'none'  // No preprocessing in single-shot mode
            : widget.preprocessingLevel,
      );

      if (mounted) {
        setState(() {
          _detectedTextBlocks = blocks;
        });
      }
    } catch (e) {
      debugPrint('Error detecting text: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImageView(),
          // Show processing indicator on top of image when detecting text
          if (_isFileReady && _isProcessing && _detectedTextBlocks == null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(radius: 10, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Detecting text...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
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

  Widget _buildImageView() {
    // Show loading if file is not ready yet
    if (!_isFileReady || _imageFile == null) {
      return _buildLoadingIndicator();
    }

    if (_detectedTextBlocks != null) {
      return TextOverlayWidget(
        imageFile: _imageFile!,
        textBlocks: _detectedTextBlocks!,
        onTextBlocksSelected: widget.onTextBlocksSelected,
        onTextCopied: widget.onTextCopied,
        showUnselectedBoundaries: widget.showUnselectedBoundaries,
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          _imageFile!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (widget.loadingWidget != null) {
      return widget.loadingWidget!;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CupertinoColors.activeBlue.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(
              radius: 14,
              color: CupertinoColors.activeBlue,
            ),
            const SizedBox(width: 12),
            Text(
              'Detecting Text',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Manually trigger text detection
  void detectText() {
    _detectText();
  }

  /// Get the currently detected text blocks
  List<TextBlock>? get detectedTextBlocks => _detectedTextBlocks;

  /// Check if text detection is currently processing
  bool get isProcessing => _isProcessing;
}