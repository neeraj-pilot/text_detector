import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_detector/text_detector.dart';

class IosTextOverlay extends StatefulWidget {
  final File imageFile;
  final List<TextBlock> textBlocks;
  final Function(TextBlock)? onTextSelected;
  final Function(TextBlock)? onTextCopied;

  const IosTextOverlay({
    super.key,
    required this.imageFile,
    required this.textBlocks,
    this.onTextSelected,
    this.onTextCopied,
  });

  @override
  State<IosTextOverlay> createState() => _IosTextOverlayState();
}

class _IosTextOverlayState extends State<IosTextOverlay>
    with SingleTickerProviderStateMixin {
  Size? _imageSize;
  Size? _displaySize;
  Offset? _displayOffset;
  int? _selectedIndex;
  TextBlock? _selectedBlock;
  bool _showSelectionMenu = false;
  Offset _menuPosition = Offset.zero;

  late AnimationController _selectionAnimController;
  late Animation<double> _selectionAnimation;

  // For pinch to zoom
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();

    _selectionAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _selectionAnimation = CurvedAnimation(
      parent: _selectionAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _selectionAnimController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImageDimensions() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    if (mounted) {
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildInteractiveImage(),
        if (_showSelectionMenu && _selectedBlock != null)
          _buildSelectionMenu(),
      ],
    );
  }

  Widget _buildInteractiveImage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 4.0,
          onInteractionUpdate: (details) {
            setState(() {
              _currentScale = details.scale;
              _showSelectionMenu = false;
            });
          },
          child: Stack(
            children: [
              Center(
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (frame != null && _displaySize == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _calculateDisplayMetrics(constraints);
                      });
                    }
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
              if (_displaySize != null && _imageSize != null)
                ..._buildTextOverlays(),
            ],
          ),
        );
      },
    );
  }

  void _calculateDisplayMetrics(BoxConstraints constraints) {
    if (_imageSize == null) return;

    final double imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final double containerAspectRatio = constraints.maxWidth / constraints.maxHeight;

    double displayWidth;
    double displayHeight;

    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container
      displayWidth = constraints.maxWidth;
      displayHeight = constraints.maxWidth / imageAspectRatio;
    } else {
      // Image is taller than container
      displayHeight = constraints.maxHeight;
      displayWidth = constraints.maxHeight * imageAspectRatio;
    }

    final offsetX = (constraints.maxWidth - displayWidth) / 2;
    final offsetY = (constraints.maxHeight - displayHeight) / 2;

    setState(() {
      _displaySize = Size(displayWidth, displayHeight);
      _displayOffset = Offset(offsetX, offsetY);
    });
  }

  List<Widget> _buildTextOverlays() {
    if (_displaySize == null || _imageSize == null || _displayOffset == null) {
      return [];
    }

    // Filter out system UI text and very small blocks
    final filteredBlocks = widget.textBlocks.where((block) {
      // Filter out common system UI text patterns
      final lowerText = block.text.toLowerCase();
      if (lowerText.contains('10:') || // Time
          lowerText.contains('battery') ||
          lowerText.contains('wifi') ||
          block.width < 20 || // Too small
          block.height < 10) {
        return false;
      }
      return block.confidence > 0.5; // Confidence threshold
    }).toList();

    return filteredBlocks.asMap().entries.map((entry) {
      final index = entry.key;
      final block = entry.value;
      final isSelected = _selectedIndex == index;

      // Calculate position with proper scaling
      final scaleX = _displaySize!.width / _imageSize!.width;
      final scaleY = _displaySize!.height / _imageSize!.height;

      final left = _displayOffset!.dx + (block.x * scaleX);
      final top = _displayOffset!.dy + (block.y * scaleY);
      final width = block.width * scaleX;
      final height = block.height * scaleY;

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: GestureDetector(
          onTap: () => _handleTextBlockTap(index, block, Offset(left + width/2, top)),
          onLongPress: () {
            _handleTextBlockLongPress(index, block, Offset(left + width/2, top));
          },
          child: AnimatedBuilder(
            animation: _selectionAnimation,
            builder: (context, child) {
              final scale = isSelected
                  ? 1.0 + (_selectionAnimation.value * 0.05)
                  : 1.0;

              return Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CupertinoColors.activeBlue.withOpacity(0.3)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? CupertinoColors.activeBlue
                          : Colors.white.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: CupertinoColors.activeBlue.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSelectionMenu() {
    return Positioned(
      left: _menuPosition.dx - 100,
      top: _menuPosition.dy - 60,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMenuButton(
                    icon: CupertinoIcons.doc_on_clipboard,
                    label: 'Copy',
                    onTap: _copySelectedText,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white24,
                  ),
                  _buildMenuButton(
                    icon: CupertinoIcons.share,
                    label: 'Share',
                    onTap: _shareSelectedText,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white24,
                  ),
                  _buildMenuButton(
                    icon: CupertinoIcons.speaker_2,
                    label: 'Speak',
                    onTap: _speakSelectedText,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTextBlockTap(int index, TextBlock block, Offset position) {
    setState(() {
      if (_selectedIndex == index) {
        // Toggle menu on second tap
        _showSelectionMenu = !_showSelectionMenu;
        _menuPosition = position;
      } else {
        _selectedIndex = index;
        _selectedBlock = block;
        _showSelectionMenu = true;
        _menuPosition = position;
        _selectionAnimController.forward(from: 0);
      }
    });

    HapticFeedback.lightImpact();
    widget.onTextSelected?.call(block);
  }

  void _handleTextBlockLongPress(int index, TextBlock block, Offset position) {
    setState(() {
      _selectedIndex = index;
      _selectedBlock = block;
      _showSelectionMenu = true;
      _menuPosition = position;
    });

    HapticFeedback.mediumImpact();
    _selectionAnimController.forward(from: 0);

    // Immediately copy on long press
    _copySelectedText();
  }

  void _copySelectedText() {
    if (_selectedBlock != null) {
      Clipboard.setData(ClipboardData(text: _selectedBlock!.text));
      widget.onTextCopied?.call(_selectedBlock!);

      setState(() {
        _showSelectionMenu = false;
      });

      HapticFeedback.mediumImpact();
    }
  }

  void _shareSelectedText() {
    if (_selectedBlock != null) {
      // Share implementation
      setState(() {
        _showSelectionMenu = false;
      });
    }
  }

  void _speakSelectedText() {
    if (_selectedBlock != null) {
      // Text-to-speech implementation
      setState(() {
        _showSelectionMenu = false;
      });
    }
  }
}