import 'dart:async';
import 'package:http/http.dart' as http;

/// ============================================================
/// MetricsCollector: 应用指标采集器
/// 采集本地指标 (计数器/直方图) 并定期上报到 Node-RED /metrics 端点。
/// 骨架实现: 不依赖外部采集库, 自维护内存指标, 输出 Prometheus 文本格式。
/// ============================================================
class MetricsCollector {
  static MetricsCollector? _instance;
  static MetricsCollector get instance =>
      _instance ??= MetricsCollector._();
  MetricsCollector._();

  final Map<String, _CounterEntry> _counters = {};
  final Map<String, _HistogramEntry> _histograms = {};
  Timer? _reportTimer;
  String? _reportEndpoint; // Node-RED 上报地址
  final http.Client _httpClient = http.Client();

  // 直方图默认桶边界 (同时覆盖 API 延迟 <1s 与会话时长 >1h 场景)
  static const List<double> _defaultBuckets = [
    0.005, 0.01, 0.05, 0.1, 0.5, 1, 5, 10, 60, 300, 600, 1800, 3600,
  ];

  /// 增加计数器
  void increment(String name, {Map<String, String>? labels, int value = 1}) {
    final key = _key(name, labels);
    final entry =
        _counters.putIfAbsent(key, () => _CounterEntry(name, labels ?? {}));
    entry.value += value;
  }

  /// 记录直方图值
  void observe(String name, double value, {Map<String, String>? labels}) {
    final key = _key(name, labels);
    final entry =
        _histograms.putIfAbsent(key, () => _HistogramEntry(name, labels ?? {}));
    entry.values.add(value);
  }

  /// 记录会话指标
  void recordSession({
    required String type,
    required String status,
    required Duration duration,
  }) {
    increment('sessions_total', labels: {'type': type, 'status': status});
    observe('session_duration_seconds', duration.inSeconds.toDouble(),
        labels: {'type': type});
  }

  /// 记录 API 请求指标
  void recordApiRequest({
    required String endpoint,
    required int statusCode,
    required Duration duration,
  }) {
    increment('api_requests_total',
        labels: {'endpoint': endpoint, 'status': statusCode.toString()});
    observe('api_request_duration_seconds', duration.inMilliseconds / 1000,
        labels: {'endpoint': endpoint});
  }

  /// 获取所有指标 (Prometheus 格式字符串)
  String toPrometheusFormat() {
    final buf = StringBuffer();

    // ---- 计数器 ----
    final counterNames = <String>{};
    for (final e in _counters.values) {
      counterNames.add(e.name);
    }
    for (final name in counterNames) {
      buf.writeln('# HELP focus_fitness_$name 计数器 (客户端采集)');
      buf.writeln('# TYPE focus_fitness_$name counter');
      for (final e in _counters.values.where((e) => e.name == name)) {
        buf.writeln('focus_fitness_$name${_labelsStr(e.labels)} ${e.value}');
      }
    }

    // ---- 直方图 ----
    final histNames = <String>{};
    for (final e in _histograms.values) {
      histNames.add(e.name);
    }
    for (final name in histNames) {
      buf.writeln('# HELP focus_fitness_$name 直方图 (客户端采集)');
      buf.writeln('# TYPE focus_fitness_$name histogram');
      for (final e in _histograms.values.where((e) => e.name == name)) {
        final sorted = List<double>.from(e.values)..sort();
        final count = sorted.length;
        final sum = sorted.fold<double>(0, (a, b) => a + b);
        for (final le in _defaultBuckets) {
          final c = sorted.where((v) => v <= le).length;
          buf.writeln(
              'focus_fitness_${name}_bucket${_labelsStrWithExtra(e.labels, 'le="$le"')} $c');
        }
        buf.writeln(
            'focus_fitness_${name}_bucket${_labelsStrWithExtra(e.labels, 'le="+Inf"')} $count');
        buf.writeln('focus_fitness_${name}_count${_labelsStr(e.labels)} $count');
        buf.writeln('focus_fitness_${name}_sum${_labelsStr(e.labels)} $sum');
      }
    }

    return buf.toString();
  }

  /// 设置上报端点 (例如 http://nodered:1880/metrics/record/batch)
  void setReportEndpoint(String url) {
    _reportEndpoint = url;
  }

  /// 启动定期上报
  void startReporting({Duration interval = const Duration(minutes: 5)}) {
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(interval, (_) => _report());
  }

  /// 立即执行一次上报
  Future<void> _report() async {
    final body = toPrometheusFormat();
    final url = _reportEndpoint;
    if (url == null) {
      // 未配置上报地址, 仅打印摘要
      // ignore: avoid_print
      print('[MetricsCollector] 上报地址未配置, 跳过上报 (${body.length} bytes)');
      return;
    }
    try {
      final resp = await _httpClient
          .post(Uri.parse(url),
              body: body,
              headers: {'Content-Type': 'text/plain; charset=utf-8'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        // ignore: avoid_print
        print('[MetricsCollector] 上报返回非 2xx: ${resp.statusCode}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[MetricsCollector] 上报失败: $e');
    }
  }

  /// 停止上报
  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
  }

  /// 清空所有指标
  void reset() {
    _counters.clear();
    _histograms.clear();
  }

  /// 释放资源
  void dispose() {
    stopReporting();
    _httpClient.close();
  }

  // ---- 内部工具方法 ----

  String _key(String name, Map<String, String>? labels) {
    return name + _labelsKey(labels);
  }

  String _labelsKey(Map<String, String>? labels) {
    if (labels == null || labels.isEmpty) return '';
    final keys = labels.keys.toList()..sort();
    return '|' + keys.map((k) => '$k=${labels[k]}').join('|');
  }

  String _labelsStr(Map<String, String> labels) {
    if (labels.isEmpty) return '';
    final keys = labels.keys.toList()..sort();
    return '{' + keys.map((k) => '$k="${labels[k]}"').join(',') + '}';
  }

  String _labelsStrWithExtra(Map<String, String> labels, String extra) {
    if (labels.isEmpty) return '{$extra}';
    final keys = labels.keys.toList()..sort();
    final base = keys.map((k) => '$k="${labels[k]}"').join(',');
    return '{$base,$extra}';
  }
}

/// 计数器条目
class _CounterEntry {
  final String name;
  final Map<String, String> labels;
  int value;
  _CounterEntry(this.name, this.labels) : value = 0;
}

/// 直方图条目
class _HistogramEntry {
  final String name;
  final Map<String, String> labels;
  final List<double> values;
  _HistogramEntry(this.name, this.labels) : values = [];
}
