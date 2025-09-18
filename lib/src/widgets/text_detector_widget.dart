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
  });

  @override
  State<TextDetectorWidget> createState() => _TextDetectorWidgetState();
}

class _TextDetectorWidgetState extends State<TextDetectorWidget> {
  final TextDetector _textDetector = TextDetector();
  List<TextBlock>? _detectedTextBlocks;
  bool _isProcessing = false;
  late File _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
    if (widget.autoDetect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _detectText();
      });
    }
  }

  Future<void> _detectText() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _detectedTextBlocks = null;
    });

    try {
      final blocks = await _textDetector.detectText(
        imagePath: widget.imagePath,
        recognitionLevel: widget.recognitionLevel,
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
          if (_isProcessing) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildImageView() {
    if (_detectedTextBlocks != null) {
      return TextOverlayWidget(
        imageFile: _imageFile,
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
          _imageFile,
          fit: BoxFit.contain,
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