/// TTS 抽象接口 — 跨平台兼容
///
/// Android/Windows: 使用 flutter_tts (原生 TTS 引擎)
/// Web: 使用 Web Speech API (window.speechSynthesis)
///
/// 使用条件导入:
///   import 'tts_factory.dart';
///   final tts = createTtsService();

abstract class TtsService {
  /// 播报文本
  Future<void> speak(String text);

  /// 停止播报
  Future<void> stop();

  /// 设置语言 (如 'zh-CN')
  Future<void> setLanguage(String lang);

  /// 设置语速 (0.0 - 1.0)
  Future<void> setSpeechRate(double rate);

  /// 释放资源
  void dispose();
}
