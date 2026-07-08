import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/daos/daos.dart';
import '../main.dart';
import 'sync_config.dart';
import 'sync_engine.dart';

/// ============================================================
/// Riverpod Providers: PowerSync 双向同步层
///
/// 依赖关系:
///   syncConfigProvider
///       ↓
///   databaseProvider (来自 main.dart)  nodeRedApiProvider (来自 main.dart)
///       ↓                                  ↓
///       └──────────────┬───────────────────┘
///                     ↓
///              syncEngineProvider
///                     ↓
///              syncStatusProvider
/// ============================================================

/// 同步配置 Provider
///
/// 默认使用开发环境配置 [SyncConfig.dev]。
/// 生产环境可在应用启动时 override 此 Provider 为 [SyncConfig.prod]。
final syncConfigProvider = Provider<SyncConfig>((ref) {
  return SyncConfig.dev;
});

/// 同步引擎 Provider (全局单例)
///
/// 自动启动定时同步, 在 Provider 销毁时自动停止并释放资源。
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final api = ref.watch(nodeRedApiProvider);
  final config = ref.watch(syncConfigProvider);

  final engine = SyncEngine(db: db, api: api, config: config);
  // 启动定时同步 (内部会立即触发一次同步)
  engine.start();

  // Provider 销毁时停止同步并释放资源
  ref.onDispose(() => engine.dispose());

  return engine;
});

/// 同步状态 Stream Provider
///
/// UI 层通过 watch 此 Provider 实时展示同步状态:
///   ```dart
///   final asyncStatus = ref.watch(syncStatusProvider);
///   asyncStatus.when(
///     data: (status) => SyncStatusBadge(status: status),
///     loading: () => const SizedBox.shrink(),
///     error: (_, __) => const Icon(Icons.error_outline),
///   );
///   ```
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.statusStream;
});

/// 手动触发同步的 Action Provider
///
/// 返回一个可调用的函数, UI 层调用方式:
///   ```dart
///   final triggerSync = ref.read(triggerSyncProvider);
///   final result = await triggerSync();
///   // 处理同步结果
///   ```
final triggerSyncProvider =
    Provider<Future<SyncResult> Function()>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.sync;
});

/// 未同步操作计数 Provider
///
/// 用于 UI 展示待同步条数徽章。
/// 每次同步完成后自动刷新 (依赖 syncStatusProvider 的状态变化)。
final unsyncedCountProvider = FutureProvider<int>((ref) async {
  // 监听同步状态变化, 触发重新计算
  ref.watch(syncStatusProvider);

  final db = ref.watch(databaseProvider);
  final opLogDao = OpLogDao(db);
  return opLogDao.unsyncedCount();
});
