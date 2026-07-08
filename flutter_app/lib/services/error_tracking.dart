import 'dart:async';

/// ============================================================
/// ErrorTrackingService: 错误追踪服务 (Sentry 集成骨架)
/// 实际使用时需在 pubspec.yaml 添加 sentry_flutter 依赖:
///   sentry_flutter: ^8.0.0
/// 当前提供接口定义和轻量级实现, 便于在依赖未安装时先接入调用点。
/// ============================================================
class ErrorTrackingService {
  static ErrorTrackingService? _instance;
  static ErrorTrackingService get instance =>
      _instance ??= ErrorTrackingService._();
  ErrorTrackingService._();

  bool _initialized = false;
  String? _dsn;
  String? _userId;
  final List<ErrorEvent> _buffer = []; // 环形缓冲区 (未初始化时暂存)
  final List<Map<String, dynamic>> _breadcrumbs = []; // 面包屑暂存
  static const int _maxBreadcrumbs = 100;

  /// 初始化 (在 main() 中调用)
  Future<void> init({String? dsn}) async {
    _dsn = dsn;
    _initialized = true;
    // 实际集成:
    // await SentryFlutter.init(
    //   (options) {
    //     options.dsn = dsn;
    //     options.tracesSampleRate = 1.0;
    //   },
    //   appRunner: () => runApp(MyApp()),
    // );
    // 当前: 刷新缓冲区, 重新上报暂存的事件
    for (final event in _buffer) {
      _printEvent(event);
    }
    _buffer.clear();
  }

  /// 捕获异常
  void captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final event = ErrorEvent(exception, stackTrace, context);
    if (!_initialized) {
      _buffer.add(event);
      return;
    }
    // 实际集成: Sentry.captureException(exception, stackTrace: stackTrace)
    _printEvent(event);
  }

  /// 捕获消息
  void captureMessage(String message, {ErrorLevel level = ErrorLevel.info}) {
    // 实际集成: Sentry.captureMessage(message, level: _mapLevel(level))
    // ignore: avoid_print
    print('[ErrorTracking][$level] $message');
  }

  /// 设置用户上下文
  void setUserContext(String userId, {Map<String, dynamic>? extras}) {
    _userId = userId;
    // 实际集成:
    // Sentry.configureScope((scope) {
    //   scope.setUser(SentryUser(id: userId, extras: extras));
    // });
    // ignore: avoid_print
    print('[ErrorTracking] setUserContext: $userId, extras=$extras');
  }

  /// 添加面包屑 (breadcrumb)
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    final crumb = <String, dynamic>{
      'message': message,
      'category': category,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _breadcrumbs.add(crumb);
    // 限制面包屑数量 (环形淘汰)
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeRange(0, _breadcrumbs.length - _maxBreadcrumbs);
    }
    // 实际集成:
    // Sentry.addBreadcrumb(Breadcrumb(
    //   message: message,
    //   category: category,
    //   data: data?.cast<String, dynamic>(),
    // ));
  }

  /// 清除用户上下文 (登出时调用)
  void clearUserContext() {
    _userId = null;
    // 实际集成: Sentry.configureScope((scope) => scope.setUser(null));
  }

  /// 获取当前已暂存的面包屑 (调试用)
  List<Map<String, dynamic>> get breadcrumbs =>
      List.unmodifiable(_breadcrumbs);

  /// 打印事件 (骨架实现)
  void _printEvent(ErrorEvent event) {
    // ignore: avoid_print
    print('[ErrorTracking] ${event.exception}');
    if (event.stackTrace != null) {
      // ignore: avoid_print
      print(event.stackTrace);
    }
    if (event.context != null && event.context!.isNotEmpty) {
      // ignore: avoid_print
      print('  context: ${event.context}');
    }
  }
}

/// 错误级别 (对应 Sentry SentryLevel)
enum ErrorLevel { debug, info, warning, error, fatal }

/// 错误事件
class ErrorEvent {
  final dynamic exception;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  ErrorEvent(this.exception, this.stackTrace, this.context)
      : timestamp = DateTime.now();
}

/// 全局错误处理 (Zone.errorHandler)
void Function(Object error, StackTrace stack) get globalErrorHandler =>
    (error, stack) =>
        ErrorTrackingService.instance.captureException(error, stackTrace: stack);
