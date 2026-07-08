/// TTS Web 实现 — 使用浏览器 Web Speech API
///
/// 通过 dart:html 调用 window.speechSynthesis
/// 兼容 Chrome / Firefox / Edge / Safari
/// dart:html 在 dart2js 编译时可用 (dart.library.html 条件成立)

import 'dart:html';

import 'tts_interface.dart';

class WebTtsService implements TtsService {
  String _lang = 'zh-CN';
  double _rate = 1.0;

  @override
  Future<void> speak(String text) async {
    final synth = window.speechSynthesis;
    if (synth == null) return;
    final utterance = SpeechSynthesisUtterance(text);
    utterance.lang = _lang;
    utterance.rate = _rate;
    utterance.volume = 1.0;
    utterance.pitch = 1.0;
    synth.speak(utterance);
  }

  @override
  Future<void> stop() async {
    window.speechSynthesis?.cancel();
  }

  @override
  Future<void> setLanguage(String lang) async {
    _lang = lang;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    _rate = rate;
  }

  @override
  void dispose() {
    window.speechSynthesis?.cancel();
  }
}

TtsService createTtsImpl() => WebTtsService();
