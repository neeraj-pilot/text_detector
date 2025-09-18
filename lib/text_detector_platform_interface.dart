import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'text_detector_method_channel.dart';

abstract class TextDetectorPlatform extends PlatformInterface {
  /// Constructs a TextDetectorPlatform.
  TextDetectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static TextDetectorPlatform _instance = MethodChannelTextDetector();

  /// The default instance of [TextDetectorPlatform] to use.
  ///
  /// Defaults to [MethodChannelTextDetector].
  static TextDetectorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TextDetectorPlatform] when
  /// they register themselves.
  static set instance(TextDetectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Detects text in an image
  Future<List<Map<String, dynamic>>> detectText({
    required String imagePath,
    required String recognitionLevel,
    List<String>? languages,
    bool enhanceForBrightness = true,
    String preprocessingLevel = 'auto',
    bool multiPass = true,
  }) {
    throw UnimplementedError('detectText() has not been implemented.');
  }

  /// Gets the platform version
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}