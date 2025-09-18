# Text Detector

A powerful Flutter plugin for detecting and extracting text from images using native iOS Vision framework. Features an iOS-style UI with advanced selection capabilities and intelligent preprocessing for challenging images.

## Features

✨ **Core Features**
- 📷 Detect text in images using native iOS Vision framework
- 🎯 Drag-to-select multiple text blocks
- 👆 Tap to select/deselect individual text blocks
- 📋 Copy selected text or all detected text
- 🔄 Automatic image rotation correction (EXIF orientation)

🎨 **UI Features**
- iOS-style selection overlay with smooth animations
- Draggable copy toolbar that can be repositioned
- Visual feedback with boundaries for text blocks
- Pinch to zoom and pan support
- Haptic feedback for interactions

🚀 **Advanced Detection**
- Intelligent preprocessing for bright/reflective images
- Multi-pass detection for challenging conditions
- Auto-brightness analysis and correction
- Support for 90+ languages with automatic detection
- Small text detection (down to 1% of image height)

## Installation

Add `text_detector` to your `pubspec.yaml`:

```yaml
dependencies:
  text_detector: ^1.0.0
```

### iOS Setup

Add the following to your `Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to select images for text detection</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to capture images for text detection</string>
```

## Quick Start

### Basic Usage

```dart
import 'package:text_detector/text_detector.dart';

// Create detector instance
final textDetector = TextDetector();

// Detect text in an image
final textBlocks = await textDetector.detectText(
  imagePath: '/path/to/image.jpg',
);

// Process detected text
for (final block in textBlocks) {
  print('Text: ${block.text}');
  print('Confidence: ${block.confidence}');
  print('Position: x=${block.x}, y=${block.y}');
}
```

### Using the Pre-built Widget

The easiest way to add text detection to your app:

```dart
import 'package:text_detector/text_detector.dart';

TextDetectorWidget(
  imagePath: imagePath,
  onTextCopied: (text) {
    print('Copied: $text');
  },
  onTextBlocksSelected: (blocks) {
    print('Selected ${blocks.length} blocks');
  },
)
```

### Advanced Configuration

```dart
// Detect with custom settings
final textBlocks = await textDetector.detectText(
  imagePath: imagePath,
  recognitionLevel: RecognitionLevel.accurate, // or .fast
  languages: ['en-US', 'es-ES'], // Specify languages
  enhanceForBrightness: true, // Auto-enhance bright images
  preprocessingLevel: 'auto', // auto/none/light/moderate/aggressive
  multiPass: true, // Multiple detection passes
);
```

## Widget Customization

```dart
TextDetectorWidget(
  imagePath: imagePath,
  autoDetect: true, // Auto-detect on load
  backgroundColor: Colors.black,
  showUnselectedBoundaries: true, // Show grey boundaries
  loadingWidget: CustomLoadingIndicator(),
  onTextCopied: (text) {
    // Handle copied text
  },
)
```

## Example App

Check the `/example` folder for a complete implementation with:
- Image picker integration
- Camera support
- iOS-style UI
- Selection and copy functionality

### Run the Example

```bash
cd example
flutter run
```

## API Reference

### TextDetector

Main class for text detection:

```dart
Future<List<TextBlock>> detectText({
  required String imagePath,
  RecognitionLevel recognitionLevel = RecognitionLevel.accurate,
  List<String>? languages,
  bool enhanceForBrightness = true,
  String preprocessingLevel = 'auto',
  bool multiPass = true,
})
```

### TextBlock

Detected text information:

```dart
class TextBlock {
  final String text;
  final double confidence;
  final double x, y;
  final double width, height;
}
```

### TextDetectorWidget

Ready-to-use widget with selection UI:

```dart
TextDetectorWidget({
  required String imagePath,
  Function(String)? onTextCopied,
  Function(List<TextBlock>)? onTextBlocksSelected,
  bool autoDetect = true,
  RecognitionLevel recognitionLevel = RecognitionLevel.accurate,
  Widget? loadingWidget,
  Color backgroundColor = Colors.black,
  bool showUnselectedBoundaries = true,
})
```

## Performance Tips

1. **For better accuracy**: Use `RecognitionLevel.accurate` (default)
2. **For faster detection**: Use `RecognitionLevel.fast`
3. **For bright images**: Keep `enhanceForBrightness: true` (default)
4. **For normal images**: Set `multiPass: false` for faster processing

## Handling Challenging Images

The plugin automatically handles:
- 📸 Rotated images (portrait/landscape/upside-down)
- ☀️ Overexposed or bright images
- 🔦 Images with reflections or glare
- 📝 Low-contrast text
- 🔤 Small text

## Platform Support

- ✅ iOS 13.0+ (uses Vision framework with VNRecognizeTextRequest)
- 🚧 Android (coming soon with ML Kit)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Author

Created with ❤️ using Flutter and native iOS Vision framework