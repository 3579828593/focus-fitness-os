import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:focus_fitness_os/data/database.dart';
import 'package:focus_fitness_os/data/daos/daos.dart';
import 'package:focus_fitness_os/services/oplog_sync_engine.dart';
import 'package:focus_fitness_os/services/nodered_api.dart';

/// ============================================================
/// OpLogSyncEngine 单元测试
///
/// 使用 Drift 内存数据库 + 无效 API 地址 (同步必然失败)。
/// 验证以下场景:
///   1. 空表同步正常返回
///   2. 同步失败的记录保留, 不标记为已同步
///   3. unsyncedCount 返回正确数量
///   4. 未知表的 OpLog 被标记为已同步 (避免无限重试)
///
/// API 使用 maxRetries=0 确保首次失败立即抛出, 不做指数退避,
/// 加快测试速度。
/// ============================================================
void main() {
  late AppDatabase db;
  late OpLogSyncEngine engine;
  late OpLogDao opLogDao;

  setUp(() async {
    // 创建内存数据库 (onCreate 自动建表 + 种子数据)
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');

    opLogDao = OpLogDao(db);

    // 构造同步引擎, 使用无效 API 地址
    // maxRetries=0: 首次失败立即抛出, 避免测试中长时间重试等待
    engine = OpLogSyncEngine(
      db: db,
      api: NodeRedApi(
        baseUrl: 'http://localhost:1',
        apiToken: 'test',
        maxRetries: 0,
        timeoutSeconds: 1,
      ),
    );
  });

  tearDown(() async {
    engine.dispose();
    // 等待 sync() 中未 await 的 _notifyStatus() 异步操作完成,
    // 避免在数据库关闭后仍有未完成的查询
    await Future.delayed(Duration.zero);
    await db.close();
  });

  group('OpLogSyncEngine', () {
    // ============================================================
    // 测试1: 空表同步正常返回
    // ============================================================
    test('sync 空表时正常返回', () async {
      // 无 OpLog 记录时, sync() 应正常返回, 不抛出异常
      await engine.sync();
    });

    // ============================================================
    // 测试2: 同步失败的记录保留不标记为已同步
    // ============================================================
    test('sync 失败的记录保留不标记为已同步', () async {
      // 插入一条 sessions 表的 UPDATE 操作日志
      await opLogDao.logOperation(
        tableName: 'sessions',
        recordId: 1,
        opType: 'UPDATE',
        payload: {'session_id': 1, 'test': true},
      );

      // 执行同步 (API 地址无效 → _syncSessionLog 调用失败 → 返回 false)
      await engine.sync();

      // 验证: 失败的记录应仍为未同步状态 (synced = false)
      final unsynced = await opLogDao.getUnsynced();
      expect(unsynced.length, 1);
    });

    // ============================================================
    // 测试3: unsyncedCount 返回正确数量
    // ============================================================
    test('unsyncedCount 返回正确数量', () async {
      // 插入两条操作日志
      await opLogDao.logOperation(
        tableName: 'sessions',
        recordId: 1,
        opType: 'INSERT',
        payload: {'test': 1},
      );
      await opLogDao.logOperation(
        tableName: 'sessions',
        recordId: 2,
        opType: 'INSERT',
        payload: {'test': 2},
      );

      // 验证: 未同步计数为 2
      final count = await opLogDao.unsyncedCount();
      expect(count, 2);
    });

    // ============================================================
    // 测试4: 未知表的 OpLog 被标记为已同步
    // ============================================================
    test('未知表的 OpLog 被标记为已同步', () async {
      // 插入一条未知表的操作日志
      await opLogDao.logOperation(
        tableName: 'unknown_table',
        recordId: 999,
        opType: 'INSERT',
        payload: {},
      );

      // 执行同步
      // _syncSingleLog 中 default 分支对未知表返回 true → 标记为已同步
      await engine.sync();

      // 验证: 未知表的 OpLog 应被标记为已同步 (避免无限重试)
      final unsynced = await opLogDao.getUnsynced();
      expect(unsynced.length, 0);
    });
  });
}
