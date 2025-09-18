import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'text_detector_platform_interface.dart';

/// An implementation of [TextDetectorPlatform] that uses method channels.
class MethodChannelTextDetector extends TextDetectorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('text_detector');

  @override
  Future<List<Map<String, dynamic>>> detectText({
    required String imagePath,
    required String recognitionLevel,
    List<String>? languages,
    bool enhanceForBrightness = true,
    String preprocessingLevel = 'auto',
    bool multiPass = true,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<List>('detectText', {
        'imagePath': imagePath,
        'recognitionLevel': recognitionLevel,
        'languages': languages,
        'enhanceForBrightness': enhanceForBrightness,
        'preprocessingLevel': preprocessingLevel,
        'multiPass': multiPass,
      });

      if (result == null) {
        return [];
      }

      return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to detect text: ${e.message}');
    }
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}