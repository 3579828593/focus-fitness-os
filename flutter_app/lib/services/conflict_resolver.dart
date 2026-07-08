import 'dart:convert';

/// ============================================================
/// ConflictResolver: 冲突解决策略
///
/// 采用 Last-Write-Wins (LWW) + Lamport Clock 混合策略:
///   1. 优先比较 updatedAt 时间戳 — 较新的记录胜出
///   2. 时间戳相同时, 比较 Lamport 逻辑时钟 — 较大值胜出
///   3. Lamport 也相同时, 比较 deviceId 字符串 — 字典序较大的胜出 (保证确定性)
///
/// 这是 CRDT-style 同步的核心组件, 被 SyncEngine 在下行同步时调用。
/// ============================================================

class ConflictResolver {
  /// 判断远程记录是否应该覆盖本地记录
  ///
  /// [remoteUpdatedAt] / [localUpdatedAt]: ISO 8601 时间字符串
  /// [remoteLamport] / [localLamport]: Lamport 逻辑时钟值
  /// [remoteDeviceId] / [localDeviceId]: 设备标识 (用于时间+时钟均相同时的兜底比较)
  ///
  /// 返回 true 表示远程记录胜出 (应覆盖本地), false 表示本地记录胜出 (保留本地)
  static bool shouldRemoteWin({
    required String remoteUpdatedAt,
    required String localUpdatedAt,
    required int remoteLamport,
    required int localLamport,
    String? remoteDeviceId,
    String? localDeviceId,
  }) {
    // 第一级: 比较 updatedAt 时间戳 (Last-Write-Wins)
    final remoteTime = _parseTime(remoteUpdatedAt);
    final localTime = _parseTime(localUpdatedAt);

    if (remoteTime.isAfter(localTime)) return true;
    if (remoteTime.isBefore(localTime)) return false;

    // 第二级: 时间戳相同 → 比较 Lamport 逻辑时钟
    if (remoteLamport > localLamport) return true;
    if (remoteLamport < localLamport) return false;

    // 第三级: 时间+时钟均相同 → 比较 deviceId (保证确定性, 避免活锁)
    // 字典序较大的 deviceId 胜出
    final rDevice = remoteDeviceId ?? '';
    final lDevice = localDeviceId ?? '';
    return rDevice.compareTo(lDevice) > 0;
  }

  /// 合并字段 (字段级冲突解决)
  ///
  /// 当前实现为简化版: 远程记录胜出时全量覆盖本地。
  /// 后续可升级为字段级合并:
  ///   - 对于非冲突字段, 保留各自的最新值
  ///   - 对于冲突字段, 使用 LWW 策略逐字段比较
  ///
  /// [remote] 远程记录 (Map 形式)
  /// [local] 本地记录 (Map 形式)
  /// [remoteWins] 远程记录是否在整体冲突中胜出
  ///
  /// 返回合并后的字段 Map
  static Map<String, dynamic> mergeFields(
    Map<String, dynamic> remote,
    Map<String, dynamic> local, {
    bool remoteWins = true,
  }) {
    // 简化版: 全量覆盖 (后续可升级为字段级合并)
    if (remoteWins) {
      return Map<String, dynamic>.from(remote);
    }
    return Map<String, dynamic>.from(local);
  }

  /// 字段级合并 (预留接口, 供后续升级使用)
  ///
  /// 对每个字段独立比较 updatedAt, 保留最新值。
  /// 需要每条记录携带 fieldTimestamps: { fieldName: ISO8601 } 元数据。
  static Map<String, dynamic> fieldLevelMerge({
    required Map<String, dynamic> remote,
    required Map<String, dynamic> local,
    required Map<String, String> remoteFieldTimestamps,
    required Map<String, String> localFieldTimestamps,
  }) {
    final merged = <String, dynamic>{};

    // 收集所有字段名
    final allFields = <String>{
      ...remote.keys,
      ...local.keys,
    };

    for (final field in allFields) {
      final remoteHas = remote.containsKey(field);
      final localHas = local.containsKey(field);

      if (remoteHas && !localHas) {
        merged[field] = remote[field];
        continue;
      }
      if (!remoteHas && localHas) {
        merged[field] = local[field];
        continue;
      }

      // 两端都有该字段 → 比较 fieldTimestamps
      final rTime = remoteFieldTimestamps[field];
      final lTime = localFieldTimestamps[field];

      if (rTime == null || lTime == null) {
        // 缺少时间戳, 默认取远程值
        merged[field] = remote[field];
        continue;
      }

      final rParsed = _parseTime(rTime);
      final lParsed = _parseTime(lTime);

      merged[field] = rParsed.isAfter(lParsed) || rParsed.isAtSameMomentAs(lParsed)
          ? remote[field]
          : local[field];
    }

    return merged;
  }

  /// 从 OpLog payload 中提取 Lamport 时钟值
  static int extractLamport(Map<String, dynamic> payload) {
    return (payload['lamport_clock'] as num?)?.toInt() ?? 0;
  }

  /// 从 OpLog payload 中提取 deviceId
  static String? extractDeviceId(Map<String, dynamic> payload) {
    return payload['device_id'] as String?;
  }

  /// 解析 ISO 8601 时间字符串, 容错处理
  static DateTime _parseTime(String isoTime) {
    try {
      return DateTime.parse(isoTime);
    } catch (_) {
      // 解析失败时返回 epoch, 等同于"最旧"
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// 将冲突解决结果序列化为 JSON 字符串 (用于日志记录)
  static String serializeResolution({
    required String tableName,
    required int recordId,
    required bool remoteWon,
    required String reason,
  }) {
    return jsonEncode({
      'table': tableName,
      'record_id': recordId,
      'remote_won': remoteWon,
      'reason': reason,
      'resolved_at': DateTime.now().toIso8601String(),
    });
  }
}
