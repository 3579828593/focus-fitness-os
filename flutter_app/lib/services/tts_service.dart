import 'dart:async';
import 'dart:collection';

/// ============================================================
/// TTS 串行化播报队列
/// 基于 StreamController + await speak() 避免播报重叠
/// 优先级: 组完成 > 休息倒计时 > 动作切换 > 其他
/// ============================================================

enum TtsPriority {
  low,    // 普通提示
  medium, // 动作切换
  high,   // 休息倒计时
  urgent, // 组完成/紧急
}

class _TtsItem {
  final String text;
  final TtsPriority priority;
  _TtsItem(this.text, this.priority);
}

/// TTS 队列管理器
///
/// 使用方法:
/// 1. 初始化时传入 speakFunction (flutter_tts 的 speak 方法)
/// 2. 调用 enqueue() 入队播报
/// 3. 队列自动按优先级出队, 串行播报, 不会重叠
class TtsQueue {
  final Future<void> Function(String text) _speakFunction;
  final Queue<_TtsItem> _queue = Queue();
  bool _isSpeaking = false;
  StreamController<_TtsItem>? _controller;

  TtsQueue(this._speakFunction) {
    _controller = StreamController<_TtsItem>.broadcast();
    _controller!.stream.listen(_processQueue);
  }

  /// 入队播报 (按优先级插入)
  void enqueue(String text, {TtsPriority priority = TtsPriority.low}) {
    final item = _TtsItem(text, priority);

    // 按优先级插入 (高优先级插队到低优先级前面)
    if (_queue.isEmpty || priority.index <= _queue.last.priority.index) {
      _queue.addLast(item);
    } else {
      // 找到插入位置
      bool inserted = false;
      for (int i = 0; i < _queue.length; i++) {
        if (priority.index > _queue.elementAt(i).priority.index) {
          _queue.add(item);
          // 将元素移动到正确位置 (Queue 不支持 insert, 用toList+rebuild)
          final list = _queue.toList();
          list.insert(i, item);
          list.removeLast(); // 移除末尾重复
          _queue.clear();
          _queue.addAll(list);
          inserted = true;
          break;
        }
      }
      if (!inserted) {
        _queue.addLast(item);
      }
    }

    _controller?.add(item);
  }

  /// 处理队列 (串行播报)
  Future<void> _processQueue(_TtsItem _) async {
    if (_isSpeaking || _queue.isEmpty) return;

    _isSpeaking = true;
    final item = _queue.removeFirst();

    try {
      await _speakFunction(item.text);
    } catch (e) {
      // TTS 错误不影响流程, 静默丢弃
    } finally {
      _isSpeaking = false;
      // 检查队列中是否还有待播报
      if (_queue.isNotEmpty) {
        _controller?.add(_queue.first);
      }
    }
  }

  /// 清空队列 (如: 用户放弃训练)
  void clear() {
    _queue.clear();
  }

  /// 当前队列长度
  int get pendingCount => _queue.length;

  /// 是否正在播报
  bool get isSpeaking => _isSpeaking;

  /// 释放资源
  void dispose() {
    _queue.clear();
    _controller?.close();
  }
}

/// ============================================================
/// TTS 播报内容构建器 (健身场景专用)
/// ============================================================

class WorkoutTtsBuilder {
  /// 组完成播报
  static String setComplete({
    required int setNumber,
    required int restSeconds,
  }) {
    return '第$setNumber组完成，休息$restSeconds秒';
  }

  /// 休息倒计时播报
  static String restCountdown(int remainingSeconds) {
    if (remainingSeconds <= 0) return '休息结束，开始下一组';
    if (remainingSeconds <= 10 && remainingSeconds % 5 == 0) {
      return '还有$remainingSeconds秒';
    }
    if (remainingSeconds == 3) return '3';
    if (remainingSeconds == 2) return '2';
    if (remainingSeconds == 1) return '1';
    return '';
  }

  /// 动作切换播报
  static String exerciseChange({
    required String name,
    required int sets,
    required int reps,
  }) {
    return '下一个动作：$name，$sets组×$reps次';
  }

  /// 全部完成播报
  static String allComplete({required int totalSets, required double volume}) {
    return '训练完成！共完成$totalSets组，总训练量${volume.toStringAsFixed(1)}公斤。干得漂亮！';
  }

  /// PR (个人记录) 播报
  static String personalRecord(String exerciseName, double weight) {
    return '恭喜！$exerciseName 创造新纪录，$weight公斤！';
  }
}
