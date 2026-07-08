import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// ============================================================
/// NodeRedApi: Flutter ↔ Node-RED HTTP 客户端
/// 负责训练完成上报、提案获取/确认、日程变更通知
/// ============================================================

class NodeRedApi {
  final String baseUrl;
  final String apiToken;
  final int timeoutSeconds;
  final int maxRetries; // 最大重试次数 (遇到可重试错误时)
  AuthService? authService; // JWT 认证服务 (可选, 注入后使用动态令牌)

  NodeRedApi({
    required this.baseUrl,
    required this.apiToken,
    this.timeoutSeconds = 5,
    this.maxRetries = 3,
    this.authService,
  });

  /// 运行时注入 AuthService (切换为 JWT 认证模式)
  void setAuthService(AuthService auth) {
    authService = auth;
  }

  /// 构建认证请求头
  /// - 若已注入 authService, 使用动态 JWT (自动刷新)
  /// - 否则回退到静态 apiToken (兼容测试/开发环境)
  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authService != null) {
      final token = await authService!.getValidAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        return headers;
      }
    }
    // 回退到静态 token
    headers['Authorization'] = 'Bearer $apiToken';
    return headers;
  }

  /// 上报训练完成 → 触发 Flow2 完成递增
  Future<Map<String, dynamic>> reportSessionComplete({
    required int sessionId,
    required int entryId,
    required double completionRatio,
    required List<Map<String, dynamic>> segments,
  }) async {
    // sessionId 已在 body 中传递, 后端注册的是固定路径 /api/v1/sessions/complete
    return _postWithRetry('/api/v1/sessions/complete', {
      'session_id': sessionId,
      'entry_id': entryId,
      'completion_ratio': completionRatio,
      'segments': segments,
    });
  }

  /// 获取待确认提案 (LOCKED 状态)
  Future<List<Map<String, dynamic>>> getProposals({
    String status = 'LOCKED',
  }) async {
    final result = await _getWithRetry('/api/v1/proposals?status=$status');
    return (result['proposals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 接受提案
  Future<void> acceptProposal(int proposalId) async {
    await _postWithRetry('/api/v1/proposals/$proposalId/accept', {});
  }

  /// 拒绝提案
  Future<void> rejectProposal(int proposalId) async {
    await _postWithRetry('/api/v1/proposals/$proposalId/reject', {});
  }

  /// 日程变更通知 → 触发 Flow4 冲突检测
  Future<Map<String, dynamic>> notifyScheduleChange({
    required int entryId,
    required String date,
    required String startTime,
    required int unitId,
  }) async {
    return _postWithRetry('/api/v1/schedule/change', {
      'entry_id': entryId,
      'date': date,
      'start_time': startTime,
      'unit_id': unitId,
    });
  }

  /// 获取周报数据
  Future<Map<String, dynamic>> getWeeklyStats(String week) async {
    return _getWithRetry('/api/v1/stats/weekly?week=$week');
  }

  /// ====== 内部 HTTP 方法 ======

  /// 带重试的 GET: 对可重试错误 (超时、5xx) 指数退避重试
  /// 不可重试错误 (4xx) 立即抛出
  Future<Map<String, dynamic>> _getWithRetry(String path) async {
    int attempt = 0; // 已重试次数
    while (true) {
      try {
        return await _getSingle(path);
      } catch (e) {
        // 不可重试错误 (4xx) 或已达最大重试次数 → 立即抛出
        if (!_isRetryable(e) || attempt >= maxRetries) {
          rethrow;
        }
        // 指数退避: 1s → 2s → 4s (2^attempt)
        final delaySeconds = 1 << attempt;
        await Future.delayed(Duration(seconds: delaySeconds));
        attempt++;
      }
    }
  }

  /// 带重试的 POST: 对可重试错误 (超时、5xx) 指数退避重试
  /// 不可重试错误 (4xx) 立即抛出
  Future<Map<String, dynamic>> _postWithRetry(
      String path, Map<String, dynamic> body) async {
    int attempt = 0; // 已重试次数
    while (true) {
      try {
        return await _postSingle(path, body);
      } catch (e) {
        // 不可重试错误 (4xx) 或已达最大重试次数 → 立即抛出
        if (!_isRetryable(e) || attempt >= maxRetries) {
          rethrow;
        }
        // 指数退避: 1s → 2s → 4s (2^attempt)
        final delaySeconds = 1 << attempt;
        await Future.delayed(Duration(seconds: delaySeconds));
        attempt++;
      }
    }
  }

  /// 判断错误是否可重试
  /// - 超时 / 网络异常 (TimeoutException 等): 可重试
  /// - 5xx 服务端错误: 可重试
  /// - 4xx 客户端错误: 不可重试
  bool _isRetryable(Object error) {
    if (error is NodeRedApiException) {
      // 4xx 客户端错误不重试, 5xx 服务端错误可重试
      return error.statusCode >= 500;
    }
    // 超时及其它网络层异常默认可重试
    return true;
  }

  /// 单次 GET 请求 (无重试)
  Future<Map<String, dynamic>> _getSingle(String path) async {
    final headers = await _buildHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: headers,
        )
        .timeout(Duration(seconds: timeoutSeconds));

    if (response.statusCode != 200) {
      throw NodeRedApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 单次 POST 请求 (无重试)
  Future<Map<String, dynamic>> _postSingle(
      String path, Map<String, dynamic> body) async {
    final headers = await _buildHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: timeoutSeconds));

    if (response.statusCode != 200) {
      throw NodeRedApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

/// API 异常
class NodeRedApiException implements Exception {
  final int statusCode;
  final String body;

  NodeRedApiException(this.statusCode, this.body);

  @override
  String toString() => 'NodeRedApiException($statusCode): $body';
}

/// ============================================================
/// 降级策略: Node-RED 不可用时用本地简化规则
/// ============================================================

class LocalFallbackRules {
  /// 本地渐进超负荷 (简化版, 不做 RPE 判断)
  static double calculateNewWeight({
    required double currentWeight,
    required double completionRatio,
  }) {
    if (completionRatio >= 1.0) {
      return currentWeight + 2.5; // 全完成 → 递增
    } else if (completionRatio < 0.5) {
      return (currentWeight - 2.5).clamp(0, double.infinity); // 不足半 → 退阶
    }
    return currentWeight; // 维持
  }

  /// 本地冲突检测 (简化版)
  static bool hasTimeConflict({
    required String newStartTime,
    required List<String> existingStartTimes,
  }) {
    return existingStartTimes.contains(newStartTime);
  }
}
