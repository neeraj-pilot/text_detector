import 'package:flutter/material.dart';
import 'package:text_detector/text_detector.dart';

class TextOverlayPainter extends StatefulWidget {
  final Widget child;
  final List<TextBlock> textBlocks;
  final Function(int, TextBlock)? onBlockTap;
  final int? selectedIndex;
  final Color? highlightColor;
  final bool showConfidence;

  const TextOverlayPainter({
    super.key,
    required this.child,
    required this.textBlocks,
    this.onBlockTap,
    this.selectedIndex,
    this.highlightColor,
    this.showConfidence = false,
  });

  @override
  State<TextOverlayPainter> createState() => _TextOverlayPainterState();
}

class _TextOverlayPainterState extends State<TextOverlayPainter> {
  final GlobalKey _imageKey = GlobalKey();
  Size? _imageSize;
  Size? _widgetSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateImageSize();
    });
  }

  void _calculateImageSize() {
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _widgetSize = renderBox.size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          key: _imageKey,
          children: [
            widget.child,
            if (_widgetSize != null)
              ...widget.textBlocks.asMap().entries.map((entry) {
                final index = entry.key;
                final block = entry.value;
                final isSelected = widget.selectedIndex == index;

                // Calculate the scale factor based on widget size
                // This assumes the text blocks are in the original image coordinates
                // and need to be scaled to fit the displayed image size

                return Positioned(
                  left: block.x * (_widgetSize!.width / 1000), // Assuming normalized coordinates
                  top: block.y * (_widgetSize!.height / 1000),
                  width: block.width * (_widgetSize!.width / 1000),
                  height: block.height * (_widgetSize!.height / 1000),
                  child: GestureDetector(
                    onTap: () => widget.onBlockTap?.call(index, block),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (widget.highlightColor ?? Colors.blue).withOpacity(0.3)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? (widget.highlightColor ?? Colors.blue)
                              : Colors.white.withOpacity(0.6),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: widget.showConfidence && isSelected
                          ? Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _getConfidenceColor(block.confidence),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(block.confidence * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
          ],
        );
      },
    );
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
}