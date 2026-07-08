/// TTS 工厂 — 条件导入自动选择平台实现
///
/// 使用方式:
///   import 'services/tts/tts_factory.dart';
///   final tts = createTtsService();
///   await tts.speak('训练开始');

export 'tts_interface.dart';

import 'tts_interface.dart';
import 'tts_native_stub.dart'
    if (dart.library.io) 'tts_native.dart'
    if (dart.library.html) 'tts_web.dart';

/// 创建当前平台的 TTS 服务实例
TtsService createTtsService() {
  return _createTts();
}
