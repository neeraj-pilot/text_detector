import 'package:flutter_test/flutter_test.dart';
import 'package:text_detector/text_detector.dart';
import 'package:text_detector/text_detector_platform_interface.dart';
import 'package:text_detector/text_detector_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTextDetectorPlatform
    with MockPlatformInterfaceMixin
    implements TextDetectorPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TextDetectorPlatform initialPlatform = TextDetectorPlatform.instance;

  test('$MethodChannelTextDetector is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTextDetector>());
  });

  test('getPlatformVersion', () async {
    TextDetector textDetectorPlugin = TextDetector();
    MockTextDetectorPlatform fakePlatform = MockTextDetectorPlatform();
    TextDetectorPlatform.instance = fakePlatform;

    expect(await textDetectorPlugin.getPlatformVersion(), '42');
  });
}
