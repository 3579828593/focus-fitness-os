/// TTS Stub — 不支持的平台占位
///
/// 当既没有 dart:io 也没有 dart:html 时使用 (不应发生)
import 'tts_interface.dart';

class _StubTtsService implements TtsService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setLanguage(String lang) async {}
  @override
  Future<void> setSpeechRate(double rate) async {}
  @override
  void dispose() {}
}

TtsService createTtsImpl() => _StubTtsService();
