# Text Detector Widget Documentation

The Text Detector plugin now includes ready-to-use widgets for easily integrating text detection into your Flutter apps.

## Quick Start

### Basic Usage

```dart
import 'package:text_detector/text_detector.dart';

// Simple usage with just an image path
TextDetectorWidget(
  imagePath: '/path/to/image.jpg',
  onTextCopied: (text) {
    print('Copied text: $text');
  },
)
```

## Available Widgets

### TextDetectorWidget

A complete text detection widget that handles the entire flow from image display to text selection and copying.

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `imagePath` | `String` | required | Path to the image file |
| `onTextCopied` | `Function(String)?` | null | Callback when text is copied |
| `onTextBlocksSelected` | `Function(List<TextBlock>)?` | null | Callback when text blocks are selected |
| `autoDetect` | `bool` | true | Auto-detect text on load |
| `recognitionLevel` | `RecognitionLevel` | accurate | Recognition accuracy level |
| `loadingWidget` | `Widget?` | null | Custom loading indicator |
| `backgroundColor` | `Color` | Colors.black | Background color |
| `showUnselectedBoundaries` | `bool` | true | Show boundaries for unselected text |

### TextOverlayWidget

A lower-level widget for overlaying detected text blocks on an image with selection capabilities.

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `imageFile` | `File` | required | Image file to display |
| `textBlocks` | `List<TextBlock>` | required | Detected text blocks |
| `onTextBlocksSelected` | `Function(List<TextBlock>)?` | null | Selection callback |
| `onTextCopied` | `Function(String)?` | null | Copy callback |
| `showUnselectedBoundaries` | `bool` | true | Show unselected boundaries |

## Features

### Selection Methods
- **Drag to Select**: Draw a rectangle to select multiple text blocks
- **Tap to Select**: Tap individual text blocks to select/deselect them

### Copy Options
- **Copy**: Copy only the selected text blocks
- **Copy All**: Copy all detected text from the image

### Draggable Toolbar
The selection toolbar can be dragged around the screen to reveal any text that might be hidden behind it.

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_detector/text_detector.dart';

class MyTextDetectorScreen extends StatefulWidget {
  @override
  _MyTextDetectorScreenState createState() => _MyTextDetectorScreenState();
}

class _MyTextDetectorScreenState extends State<MyTextDetectorScreen> {
  String? _imagePath;

  @override
  Widget build(BuildContext context) {
    if (_imagePath == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _pickImage,
          child: Text('Select Image'),
        ),
      );
    }

    return TextDetectorWidget(
      imagePath: _imagePath!,
      autoDetect: true,
      recognitionLevel: RecognitionLevel.accurate,
      onTextCopied: (text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Text copied!')),
        );
      },
      onTextBlocksSelected: (blocks) {
        print('Selected ${blocks.length} blocks');
      },
      loadingWidget: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }
}
```

## Programmatic Control

You can also control the widget programmatically:

```dart
// Create a GlobalKey to access the widget's state
final GlobalKey<TextDetectorWidgetState> _detectorKey =
    GlobalKey<TextDetectorWidgetState>();

// Use the key with the widget
TextDetectorWidget(
  key: _detectorKey,
  imagePath: imagePath,
  autoDetect: false, // Don't auto-detect
)

// Manually trigger detection
_detectorKey.currentState?.detectText();

// Access detected text blocks
final blocks = _detectorKey.currentState?.detectedTextBlocks;

// Check if processing
final isProcessing = _detectorKey.currentState?.isProcessing;
```

## Customization

### Custom Loading Indicator

```dart
TextDetectorWidget(
  imagePath: imagePath,
  loadingWidget: Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 10),
        Text('Processing...', style: TextStyle(color: Colors.white)),
      ],
    ),
  ),
)
```

### Custom Styling

```dart
TextDetectorWidget(
  imagePath: imagePath,
  backgroundColor: Colors.grey[900]!,
  showUnselectedBoundaries: false, // Hide unselected text boundaries
)
```

## UI/UX Features

1. **Visual Feedback**
   - Selected text blocks are highlighted in blue
   - Unselected blocks show subtle grey boundaries (optional)
   - Smooth animations for selections

2. **Gestures**
   - Pinch to zoom the image
   - Pan to move around when zoomed
   - Drag to select multiple text blocks
   - Tap to select individual blocks

3. **Toolbar**
   - Draggable toolbar that can be repositioned
   - Copy selected text or all text
   - Clear selection button

4. **Haptic Feedback**
   - Light haptic on selection start
   - Medium haptic on successful copy

## Performance Tips

1. Use `RecognitionLevel.fast` for quicker detection with slightly lower accuracy
2. Consider image size - very large images may take longer to process
3. The widget automatically handles image dimensions and scaling

## Platform Support

The widgets work on both iOS and Android, with platform-specific styling for iOS (CupertinoActivityIndicator, CupertinoColors, etc.).