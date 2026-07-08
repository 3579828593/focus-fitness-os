/// ============================================================
/// SyncConfig: PowerSync 同步配置
///
/// 定义 PowerSync 服务连接参数、设备标识、同步间隔与重试策略。
/// 提供开发环境和生产环境的预设配置。
/// ============================================================

/// PowerSync 同步配置
class SyncConfig {
  /// PowerSync 服务 URL (或 Node-RED sync 端点)
  final String powerSyncUrl;

  /// 当前设备唯一标识 (用于 CRDT 冲突解决中的设备区分)
  final String deviceId;

  /// 同步间隔 (秒)
  final int syncInterval;

  /// 最大重试次数 (上行推送失败时的重试上限)
  final int maxRetryCount;

  /// 单次上行同步的批次大小
  final int pushBatchSize;

  /// 单次下行拉取的最大变更条数
  final int pullBatchSize;

  /// HTTP 请求超时时间 (秒)
  final int timeoutSeconds;

  const SyncConfig({
    required this.powerSyncUrl,
    required this.deviceId,
    this.syncInterval = 60,
    this.maxRetryCount = 3,
    this.pushBatchSize = 50,
    this.pullBatchSize = 100,
    this.timeoutSeconds = 10,
  });

  /// 开发环境配置
  static const dev = SyncConfig(
    powerSyncUrl: 'http://localhost:8080',
    deviceId: 'dev-device',
    syncInterval: 30,
    maxRetryCount: 3,
    pushBatchSize: 50,
    pullBatchSize: 100,
    timeoutSeconds: 10,
  );

  /// 生产环境配置
  /// deviceId 留空, 运行时通过 [SyncConfig.withDeviceId] 注入
  static const prod = SyncConfig(
    powerSyncUrl: 'https://sync.focus-fitness-os.com',
    deviceId: '',
    syncInterval: 60,
    maxRetryCount: 5,
    pushBatchSize: 100,
    pullBatchSize: 200,
    timeoutSeconds: 15,
  );

  /// 创建带运行时 deviceId 的配置副本
  /// 生产环境中 deviceId 通常在应用启动时生成或从安全存储读取
  SyncConfig withDeviceId(String runtimeDeviceId) {
    return SyncConfig(
      powerSyncUrl: powerSyncUrl,
      deviceId: runtimeDeviceId,
      syncInterval: syncInterval,
      maxRetryCount: maxRetryCount,
      pushBatchSize: pushBatchSize,
      pullBatchSize: pullBatchSize,
      timeoutSeconds: timeoutSeconds,
    );
  }

  /// 上行同步端点路径
  String get pushEndpoint => '/api/v1/sync/push';

  /// 下行同步端点路径
  String get pullEndpoint => '/api/v1/sync/pull';

  /// 构建完整的上行推送 URL
  String get pushUrl => '$powerSyncUrl$pushEndpoint';

  /// 构建完整的下行拉取 URL (不含 query 参数)
  String get pullUrl => '$powerSyncUrl$pullEndpoint';

  @override
  String toString() {
    return 'SyncConfig(powerSyncUrl: $powerSyncUrl, deviceId: $deviceId, '
        'syncInterval: ${syncInterval}s, maxRetryCount: $maxRetryCount)';
  }
}
