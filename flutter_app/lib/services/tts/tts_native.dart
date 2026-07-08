/// TTS Native 实现 — Android / Windows / macOS / Linux
///
/// 使用 flutter_tts 包，直接调用平台原生 TTS 引擎:
/// - Android: TextToSpeech 引擎
/// - Windows: SAPI 5
/// - macOS: AVSpeechSynthesizer
library;

import 'package:flutter_tts/flutter_tts.dart';
import 'tts_interface.dart';

class NativeTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();

  NativeTtsService() {
    _tts.setLanguage('zh-CN');
    _tts.setSpeechRate(0.5); // flutter_tts 使用 0.0-1.0 范围
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> setLanguage(String lang) async {
    await _tts.setLanguage(lang);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  @override
  void dispose() {
    _tts.stop();
  }
}

TtsService createTtsImpl() => NativeTtsService();
