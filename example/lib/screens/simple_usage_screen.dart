import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_detector/text_detector.dart';

/// Example screen showing simple usage of TextDetectorWidget
class SimpleUsageScreen extends StatefulWidget {
  const SimpleUsageScreen({super.key});

  @override
  State<SimpleUsageScreen> createState() => _SimpleUsageScreenState();
}

class _SimpleUsageScreenState extends State<SimpleUsageScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Text Detector Example'),
      ),
      body: _imagePath != null
          ? TextDetectorWidget(
              imagePath: _imagePath!,
              autoDetect: true,
              onTextCopied: (text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: ${text.substring(0, text.length.clamp(0, 50))}...'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              onTextBlocksSelected: (blocks) {
                // Silent callback - ${blocks.length} text blocks selected
              },
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.image_search,
                    size: 100,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select an image to detect text',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick from Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take a Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
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
        _imagePath = image.path;
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }
}