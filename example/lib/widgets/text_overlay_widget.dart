import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:text_detector/text_detector.dart';

class TextOverlayWidget extends StatefulWidget {
  final File imageFile;
  final List<TextBlock> textBlocks;
  final Function(TextBlock) onTextTapped;

  const TextOverlayWidget({
    super.key,
    required this.imageFile,
    required this.textBlocks,
    required this.onTextTapped,
  });

  @override
  State<TextOverlayWidget> createState() => _TextOverlayWidgetState();
}

class _TextOverlayWidgetState extends State<TextOverlayWidget> {
  ui.Image? _image;
  Size? _imageSize;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(TextOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile != widget.imageFile) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _image = frame.image;
        _imageSize = Size(
          _image!.width.toDouble(),
          _image!.height.toDouble(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null || _imageSize == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _calculateScale(constraints);
        final offset = _calculateOffset(constraints, scale);

        return Stack(
          children: [
            // Custom painter for drawing bounding boxes
            CustomPaint(
              size: constraints.biggest,
              painter: TextBoxPainter(
                textBlocks: widget.textBlocks,
                imageSize: _imageSize!,
                scale: scale,
                offset: offset,
                selectedIndex: _selectedIndex,
              ),
            ),
            // Gesture detectors for each text block
            ...widget.textBlocks.asMap().entries.map((entry) {
              final index = entry.key;
              final block = entry.value;
              final rect = _transformRect(block.boundingBox, scale, offset);

              return Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    widget.onTextTapped(block);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _selectedIndex == index
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedIndex == index
                            ? Colors.blue
                            : Colors.green,
                        width: 2,
                      ),
                    ),
                    child: _selectedIndex == index
                        ? Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.white.withOpacity(0.9),
                            child: SelectableText(
                              block.text,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  double _calculateScale(BoxConstraints constraints) {
    final widthScale = constraints.maxWidth / _imageSize!.width;
    final heightScale = constraints.maxHeight / _imageSize!.height;
    return widthScale < heightScale ? widthScale : heightScale;
  }

  Offset _calculateOffset(BoxConstraints constraints, double scale) {
    final scaledWidth = _imageSize!.width * scale;
    final scaledHeight = _imageSize!.height * scale;
    final dx = (constraints.maxWidth - scaledWidth) / 2;
    final dy = (constraints.maxHeight - scaledHeight) / 2;
    return Offset(dx, dy);
  }

  Rect _transformRect(Rect original, double scale, Offset offset) {
    return Rect.fromLTWH(
      original.left * scale + offset.dx,
      original.top * scale + offset.dy,
      original.width * scale,
      original.height * scale,
    );
  }
}

class TextBoxPainter extends CustomPainter {
  final List<TextBlock> textBlocks;
  final Size imageSize;
  final double scale;
  final Offset offset;
  final int? selectedIndex;

  TextBoxPainter({
    required this.textBlocks,
    required this.imageSize,
    required this.scale,
    required this.offset,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < textBlocks.length; i++) {
      final block = textBlocks[i];
      final rect = Rect.fromLTWH(
        block.x * scale + offset.dx,
        block.y * scale + offset.dy,
        block.width * scale,
        block.height * scale,
      );

      // Draw shadow for better visibility
      paint
        ..color = Colors.black.withOpacity(0.3)
        ..strokeWidth = 4;
      canvas.drawRect(rect.shift(const Offset(1, 1)), paint);

      // Draw main box
      paint
        ..color = selectedIndex == i ? Colors.blue : Colors.green
        ..strokeWidth = 2;
      canvas.drawRect(rect, paint);

      // Draw confidence indicator
      final confidenceColor = _getConfidenceColor(block.confidence);
      paint
        ..color = confidenceColor
        ..style = PaintingStyle.fill;

      final indicatorSize = 8.0;
      final indicatorRect = Rect.fromLTWH(
        rect.right - indicatorSize - 2,
        rect.top + 2,
        indicatorSize,
        indicatorSize,
      );
      canvas.drawCircle(indicatorRect.center, indicatorSize / 2, paint);

      // Reset paint style
      paint.style = PaintingStyle.stroke;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) {
      return Colors.green;
    } else if (confidence >= 0.7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  bool shouldRepaint(TextBoxPainter oldDelegate) {
    return oldDelegate.textBlocks != textBlocks ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset;
  }
}