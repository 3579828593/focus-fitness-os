/// TTS Web 实现 — 使用浏览器 Web Speech API
///
/// 通过 dart:js_interop 调用 window.speechSynthesis
/// 兼容 Chrome / Firefox / Edge / Safari
library;

import 'dart:js_interop';

import 'tts_interface.dart';

@JS('speechSynthesis')
external _JSSpeechSynthesis get _speechSynthesis;

@JS()
@staticInterop
class _JSSpeechSynthesis {}

extension _JSSpeechSynthesisExt on _JSSpeechSynthesis {
  external void speak(_JSUtterance utterance);
  external void cancel();
  external bool get speaking;
}

@JS('SpeechSynthesisUtterance')
@staticInterop
class _JSUtterance {
  external factory _JSUtterance(String text);
}

extension _JSUtteranceExt on _JSUtterance {
  external set rate(double value);
  external set pitch(double value);
  external set volume(double value);
  external set lang(String value);
}

class WebTtsService implements TtsService {
  String _lang = 'zh-CN';
  double _rate = 1.0;

  @override
  Future<void> speak(String text) async {
    final utterance = _JSUtterance(text);
    utterance.lang = _lang;
    utterance.rate = _rate;
    utterance.volume = 1.0;
    utterance.pitch = 1.0;
    _speechSynthesis.speak(utterance);
  }

  @override
  Future<void> stop() async {
    _speechSynthesis.cancel();
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
    _speechSynthesis.cancel();
  }
}

TtsService _createTts() => WebTtsService();
