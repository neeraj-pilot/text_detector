import 'dart:io';

import 'src/models/text_block.dart';
import 'text_detector_platform_interface.dart';

export 'src/models/text_block.dart';
export 'src/widgets/text_detector_widget.dart';
export 'src/widgets/text_overlay_widget.dart';

/// Main class for text detection functionality
class TextDetector {
  /// Detects text in an image at the given file path
  ///
  /// [imagePath] - Path to the image file
  /// [recognitionLevel] - Recognition accuracy level: 'fast' or 'accurate' (default: 'accurate')
  /// [languages] - List of language codes to recognize (optional, uses automatic detection if not specified)
  ///
  /// Returns a list of [TextBlock] objects containing detected text and their positions
  Future<List<TextBlock>> detectText({
    required String imagePath,
    RecognitionLevel recognitionLevel = RecognitionLevel.accurate,
    List<String>? languages,
  }) async {
    if (!File(imagePath).existsSync()) {
      throw ArgumentError('Image file does not exist at path: $imagePath');
    }

    final results = await TextDetectorPlatform.instance.detectText(
      imagePath: imagePath,
      recognitionLevel: recognitionLevel.name,
      languages: languages,
    );

    return results.map((data) => TextBlock.fromMap(data)).toList();
  }

  /// Gets the platform version (for testing purposes)
  Future<String?> getPlatformVersion() {
    return TextDetectorPlatform.instance.getPlatformVersion();
  }
}

/// Recognition accuracy levels
enum RecognitionLevel {
  /// Fast recognition with lower accuracy
  fast,

  /// Accurate recognition with higher processing time
  accurate,
}