import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_detector/text_detector.dart';

import 'package:flutter/foundation.dart';

import '../../widgets/custom_toast.dart';
import '../../widgets/debug_text_blocks_viewer.dart';
import '../../widgets/ios_text_overlay_draggable.dart';

class IosStyleScreenV2 extends StatefulWidget {
  const IosStyleScreenV2({super.key});

  @override
  State<IosStyleScreenV2> createState() => _IosStyleScreenV2State();
}

class _IosStyleScreenV2State extends State<IosStyleScreenV2>
    with TickerProviderStateMixin {
  final TextDetector _textDetector = TextDetector();
  final ImagePicker _imagePicker = ImagePicker();

  File? _imageFile;
  List<TextBlock>? _detectedTextBlocks;
  bool _isProcessing = false;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          if (_imageFile != null)
            _buildImageView()
          else
            _buildEmptyState(),
          _buildTopControls(),
          if (_isProcessing)
            _buildProcessingOverlay(),
          if (kDebugMode && _detectedTextBlocks != null && _detectedTextBlocks!.isNotEmpty)
            _buildDebugButton(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    CupertinoColors.activeBlue.withOpacity(0.2),
                    CupertinoColors.activeBlue.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                CupertinoIcons.text_badge_plus,
                size: 80,
                color: CupertinoColors.activeBlue,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Text Scanner',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Extract text from any image',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: CupertinoIcons.photo,
                  label: 'Library',
                  onTap: _pickImage,
                  isPrimary: true,
                ),
                const SizedBox(width: 20),
                _buildActionButton(
                  icon: CupertinoIcons.camera,
                  label: 'Camera',
                  onTap: _takePhoto,
                  isPrimary: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary
              ? CupertinoColors.activeBlue
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(isPrimary ? 1 : 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return const SizedBox.shrink();  // No custom controls, rely on OS default back gesture
  }

  Widget _buildImageView() {
    if (_detectedTextBlocks != null) {
      return IosTextOverlayDraggable(
        imageFile: _imageFile!,
        textBlocks: _detectedTextBlocks!,
        onTextBlocksSelected: (blocks) {
          // Silent - no toast needed for selection
        },
        onTextCopied: (text) {
          _handleTextCopied(text);
        },
      );
    }

    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              _imageFile!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        if (_isProcessing)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 - 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CupertinoColors.activeBlue.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.activeBlue.withOpacity(0.2),
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
            ),
          ),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        CupertinoColors.activeBlue.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const CupertinoActivityIndicator(
                  radius: 25,
                  color: CupertinoColors.activeBlue,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Analyzing Text...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Powered by AI',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _detectedTextBlocks = null;
      });
      _fadeController.forward();
      // Auto-detect after picking
      Future.delayed(const Duration(milliseconds: 500), _detectText);
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _detectedTextBlocks = null;
      });
      _fadeController.forward();
      // Auto-detect after taking photo
      Future.delayed(const Duration(milliseconds: 500), _detectText);
    }
  }

  Future<void> _detectText() async {
    if (_imageFile == null) return;

    setState(() {
      _isProcessing = true;
      _detectedTextBlocks = null;
    });

    try {
      final blocks = await _textDetector.detectText(
        imagePath: _imageFile!.path,
        recognitionLevel: RecognitionLevel.accurate,
      );

      setState(() {
        _detectedTextBlocks = blocks;
      });

      if (blocks.isEmpty) {
        CustomToast.show(context, 'No text detected', isError: true);
      } else {
        HapticFeedback.mediumImpact();
        // Silent - no need to announce text block count
      }
    } catch (e) {
      CustomToast.show(context, 'Error: $e', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Widget _buildDebugButton() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 100,
      right: 16,
      child: FloatingActionButton.small(
        backgroundColor: Colors.orange.withOpacity(0.9),
        onPressed: _showDebugViewer,
        child: const Icon(
          Icons.bug_report,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  void _showDebugViewer() {
    if (_detectedTextBlocks == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebugTextBlocksViewer(
          textBlocks: _detectedTextBlocks!,
        ),
      ),
    );
  }

  void _handleTextCopied(String text) {
    CustomToast.showCopied(context, text);
  }

}