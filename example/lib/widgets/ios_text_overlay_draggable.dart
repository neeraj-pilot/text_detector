import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_detector/text_detector.dart';

class IosTextOverlayDraggable extends StatefulWidget {
  final File imageFile;
  final List<TextBlock> textBlocks;
  final Function(List<TextBlock>)? onTextBlocksSelected;
  final Function(String)? onTextCopied;

  const IosTextOverlayDraggable({
    super.key,
    required this.imageFile,
    required this.textBlocks,
    this.onTextBlocksSelected,
    this.onTextCopied,
  });

  @override
  State<IosTextOverlayDraggable> createState() => _IosTextOverlayDraggableState();
}

class _IosTextOverlayDraggableState extends State<IosTextOverlayDraggable>
    with TickerProviderStateMixin {
  Size? _imageSize;
  Size? _displaySize;
  Offset? _displayOffset;

  // Selection state
  final Set<int> _selectedIndices = {};
  bool _isDragging = false;
  Offset? _dragStart;
  Offset? _dragEnd;
  Rect? _selectionRect;

  // Toolbar drag state
  Offset _toolbarOffset = Offset.zero;
  bool _isToolbarDragging = false;

  // Animation controllers
  late AnimationController _selectionAnimController;
  late Animation<double> _selectionAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // For pinch to zoom
  final TransformationController _transformController = TransformationController();

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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _selectionAnimController.dispose();
    _pulseController.dispose();
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
        if (_selectedIndices.isNotEmpty)
          _buildSelectionToolbar(),
      ],
    );
  }

  Widget _buildInteractiveImage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) {
            setState(() {
              _isDragging = true;
              _dragStart = details.localPosition;
              _dragEnd = details.localPosition;
              _selectedIndices.clear();
            });
            HapticFeedback.lightImpact();
          },
          onPanUpdate: (details) {
            setState(() {
              _dragEnd = details.localPosition;
              _updateSelectionRect();
              _updateSelectedBlocks();
            });
          },
          onPanEnd: (details) {
            setState(() {
              _isDragging = false;
              if (_selectedIndices.isNotEmpty) {
                _selectionAnimController.forward(from: 0);
                HapticFeedback.mediumImpact();
                _notifySelection();
              }
            });
          },
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 4.0,
            child: Stack(
              children: [
                Center(
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (frame != null && _displaySize == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _calculateDisplayMetrics(constraints);
                        });
                      }
                      return child;
                    },
                  ),
                ),
                if (_displaySize != null && _imageSize != null)
                  ..._buildTextOverlays(),
                if (_isDragging && _selectionRect != null)
                  _buildDragSelectionOverlay(),
              ],
            ),
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
      displayWidth = constraints.maxWidth;
      displayHeight = constraints.maxWidth / imageAspectRatio;
    } else {
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

  void _updateSelectionRect() {
    if (_dragStart == null || _dragEnd == null) return;

    final left = min(_dragStart!.dx, _dragEnd!.dx);
    final top = min(_dragStart!.dy, _dragEnd!.dy);
    final right = max(_dragStart!.dx, _dragEnd!.dx);
    final bottom = max(_dragStart!.dy, _dragEnd!.dy);

    _selectionRect = Rect.fromLTRB(left, top, right, bottom);
  }

  void _updateSelectedBlocks() {
    if (_selectionRect == null || _displaySize == null ||
        _imageSize == null || _displayOffset == null) return;

    _selectedIndices.clear();

    final filteredBlocks = _getFilteredBlocks();

    for (int i = 0; i < filteredBlocks.length; i++) {
      final block = filteredBlocks[i];
      final blockRect = _getBlockRect(block);

      if (_selectionRect!.overlaps(blockRect)) {
        _selectedIndices.add(i);
      }
    }
  }

  Rect _getBlockRect(TextBlock block) {
    final scaleX = _displaySize!.width / _imageSize!.width;
    final scaleY = _displaySize!.height / _imageSize!.height;

    final left = _displayOffset!.dx + (block.x * scaleX);
    final top = _displayOffset!.dy + (block.y * scaleY);
    final width = block.width * scaleX;
    final height = block.height * scaleY;

    return Rect.fromLTWH(left, top, width, height);
  }

  List<TextBlock> _getFilteredBlocks() {
    return widget.textBlocks.where((block) {
      final lowerText = block.text.toLowerCase();
      if (lowerText.contains('12:') ||
          lowerText.contains('battery') ||
          lowerText.contains('wifi') ||
          block.width < 20 ||
          block.height < 10) {
        return false;
      }
      return block.confidence > 0.5;
    }).toList();
  }

  List<Widget> _buildTextOverlays() {
    if (_displaySize == null || _imageSize == null || _displayOffset == null) {
      return [];
    }

    final filteredBlocks = _getFilteredBlocks();

    return filteredBlocks.asMap().entries.map((entry) {
      final index = entry.key;
      final block = entry.value;
      final isSelected = _selectedIndices.contains(index);

      final scaleX = _displaySize!.width / _imageSize!.width;
      final scaleY = _displaySize!.height / _imageSize!.height;

      final left = _displayOffset!.dx + (block.x * scaleX);
      final top = _displayOffset!.dy + (block.y * scaleY);
      final width = block.width * scaleX;
      final height = block.height * scaleY;

      return Positioned(
        left: left - 4,  // Add padding
        top: top - 4,    // Add padding
        width: width + 8,  // Add padding
        height: height + 8,  // Add padding
        child: GestureDetector(
          onTap: () => _handleTextBlockTap(index, block),
          child: AnimatedBuilder(
            animation: isSelected ? _pulseAnimation : _selectionAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? CupertinoColors.activeBlue.withOpacity(
                          _isDragging ? _pulseAnimation.value : 0.25)
                      : Colors.grey.withOpacity(0.08),  // Greyish background for unselected
                  border: Border.all(
                    color: isSelected
                        ? CupertinoColors.activeBlue
                        : Colors.grey.withOpacity(0.25),  // Greyish border for unselected
                    width: isSelected ? 1.5 : 0.8,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: CupertinoColors.activeBlue.withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ] : null,
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDragSelectionOverlay() {
    if (_selectionRect == null) return const SizedBox.shrink();

    return Positioned(
      left: _selectionRect!.left,
      top: _selectionRect!.top,
      width: _selectionRect!.width,
      height: _selectionRect!.height,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.activeBlue.withOpacity(0.1),
          border: Border.all(
            color: CupertinoColors.activeBlue,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSelectionToolbar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned(
      bottom: (MediaQuery.of(context).padding.bottom + 20 - _toolbarOffset.dy)  // Fix: subtract dy instead of add
          .clamp(20.0, screenHeight - 100),
      left: (_toolbarOffset.dx + screenWidth / 2 - 100).clamp(10.0, screenWidth - 210),
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isToolbarDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _toolbarOffset += details.delta;
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isToolbarDragging = false;
          });
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isToolbarDragging
                      ? Colors.black.withOpacity(0.95)
                      : Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: _isToolbarDragging ? 10 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(14),
                      minimumSize: const Size(28, 28),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.doc_on_clipboard,
                               size: 16,
                               color: Colors.white),
                          SizedBox(width: 4),
                          Text('Copy',
                               style: TextStyle(
                                 fontSize: 13,
                                 color: Colors.white,
                                 fontWeight: FontWeight.w600)),
                        ],
                      ),
                      onPressed: _copySelectedText,
                    ),
                    const SizedBox(width: 6),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: CupertinoColors.systemPurple,
                      borderRadius: BorderRadius.circular(14),
                      minimumSize: const Size(28, 28),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.doc_on_doc_fill,
                               size: 16,
                               color: Colors.white),
                          SizedBox(width: 4),
                          Text('Copy All',
                               style: TextStyle(
                                 fontSize: 13,
                                 color: Colors.white,
                                 fontWeight: FontWeight.w600)),
                        ],
                      ),
                      onPressed: _copyAllText,
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(24, 24),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ),
                      onPressed: _clearSelection,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleTextBlockTap(int index, TextBlock block) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });

    if (_selectedIndices.isNotEmpty) {
      _selectionAnimController.forward(from: 0);
    }

    HapticFeedback.lightImpact();
    _notifySelection();
  }

  void _notifySelection() {
    if (widget.onTextBlocksSelected != null) {
      final filteredBlocks = _getFilteredBlocks();
      final selectedBlocks = _selectedIndices
          .map((index) => filteredBlocks[index])
          .toList();

      // Sort blocks by vertical position, then horizontal
      selectedBlocks.sort((a, b) {
        final yDiff = a.y.compareTo(b.y);
        if (yDiff != 0) return yDiff;
        return a.x.compareTo(b.x);
      });

      widget.onTextBlocksSelected!(selectedBlocks);
    }
  }

  void _copySelectedText() {
    if (_selectedIndices.isEmpty) return;

    final filteredBlocks = _getFilteredBlocks();
    final selectedBlocks = _selectedIndices
        .map((index) => filteredBlocks[index])
        .toList();

    // Sort blocks to create coherent paragraph
    selectedBlocks.sort((a, b) {
      final yDiff = a.y.compareTo(b.y);
      if (yDiff != 0) return yDiff;
      return a.x.compareTo(b.x);
    });

    // Group blocks by line (similar y position)
    final List<List<TextBlock>> lines = [];
    List<TextBlock> currentLine = [];
    double? lastY;

    for (final block in selectedBlocks) {
      if (lastY == null || (block.y - lastY).abs() < block.height / 2) {
        currentLine.add(block);
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = [block];
      }
      lastY = block.y;
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    // Join text with appropriate spacing
    final text = lines.map((line) {
      return line.map((block) => block.text).join(' ');
    }).join('\n');

    Clipboard.setData(ClipboardData(text: text));
    widget.onTextCopied?.call(text);

    HapticFeedback.mediumImpact();

    // Auto-hide after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _clearSelection();
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices.clear();
      _selectionRect = null;
      _toolbarOffset = Offset.zero;  // Reset toolbar position
    });
  }

  void _copyAllText() {
    final filteredBlocks = _getFilteredBlocks();

    // Sort all blocks to create coherent paragraph
    final sortedBlocks = List<TextBlock>.from(filteredBlocks);
    sortedBlocks.sort((a, b) {
      final yDiff = a.y.compareTo(b.y);
      if (yDiff != 0) return yDiff;
      return a.x.compareTo(b.x);
    });

    // Group blocks by line (similar y position)
    final List<List<TextBlock>> lines = [];
    List<TextBlock> currentLine = [];
    double? lastY;

    for (final block in sortedBlocks) {
      if (lastY == null || (block.y - lastY).abs() < block.height / 2) {
        currentLine.add(block);
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = [block];
      }
      lastY = block.y;
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    // Join text with appropriate spacing
    final text = lines.map((line) {
      return line.map((block) => block.text).join(' ');
    }).join('\n');

    Clipboard.setData(ClipboardData(text: text));
    widget.onTextCopied?.call(text);

    HapticFeedback.mediumImpact();

    // Auto-hide after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _clearSelection();
      }
    });
  }
}