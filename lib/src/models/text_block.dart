import 'dart:ui';

/// Represents a block of detected text with its position and confidence
class TextBlock {
  /// The detected text content
  final String text;

  /// Confidence score (0.0 to 1.0)
  final double confidence;

  /// X coordinate of the text block (in pixels)
  final double x;

  /// Y coordinate of the text block (in pixels)
  final double y;

  /// Width of the text block (in pixels)
  final double width;

  /// Height of the text block (in pixels)
  final double height;

  TextBlock({
    required this.text,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Creates a TextBlock from a map
  factory TextBlock.fromMap(Map<String, dynamic> map) {
    return TextBlock(
      text: map['text'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
    );
  }

  /// Converts the TextBlock to a map
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'confidence': confidence,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  /// Returns the bounding rectangle for this text block
  Rect get boundingBox => Rect.fromLTWH(x, y, width, height);

  /// Returns the center point of the text block
  Offset get center => Offset(x + width / 2, y + height / 2);

  @override
  String toString() {
    return 'TextBlock(text: "$text", confidence: ${confidence.toStringAsFixed(2)}, '
        'position: ($x, $y), size: ${width}x$height)';
  }
}