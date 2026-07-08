import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:focus_fitness_os/data/database.dart';
import 'package:focus_fitness_os/data/daos/daos.dart';
import 'package:focus_fitness_os/data/tables.dart';
import 'package:focus_fitness_os/repositories/session_repository.dart';
import 'package:focus_fitness_os/services/nodered_api.dart';

/// ============================================================
/// SessionRepository 单元测试
///
/// 使用 Drift 内存数据库 (NativeDatabase.memory()) 进行测试。
/// 种子数据在 AppDatabase.onCreate 回调中自动执行 (seedDatabase):
///   - unitId=1: LEARNING "专注学习"
///   - unitId=2: WORKOUT  "推日训练"
///
/// API 使用无效地址 (http://localhost:1) + maxRetries=0,
/// 确保网络请求立即失败, 触发本地降级逻辑, 同时避免测试长时间等待。
/// ============================================================
void main() {
  late AppDatabase db;
  late SessionRepository repo;

  setUp(() async {
    // 创建内存数据库
    // onCreate 回调会自动建表 + 插入种子数据 (无需手动调用 seedDatabase)
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 触发数据库连接初始化 (打开 → onCreate → 种子数据插入)
    await db.customStatement('PRAGMA foreign_keys = ON');

    // 构造 Repository, 使用无效 API 地址触发降级
    // maxRetries=0: 首次失败立即抛出, 不做指数退避重试, 加快测试速度
    repo = SessionRepository(
      db,
      NodeRedApi(
        baseUrl: 'http://localhost:1',
        apiToken: 'test',
        maxRetries: 0,
        timeoutSeconds: 1,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SessionRepository', () {
    // ============================================================
    // 测试1: createSession 创建会话并返回 sessionId
    // ============================================================
    test('createSession 创建会话并返回 sessionId', () async {
      // 先创建一个日程条目 (unitId=1 来自种子数据: LEARNING "专注学习")
      final entryId = await db.into(db.scheduleEntries).insert(
            ScheduleEntriesCompanion.insert(
              unitId: 1,
              date: '2026-07-08',
              startTime: '09:00',
              execMode: 'FOCUS',
            ),
          );

      // 执行: 通过 Repository 创建会话
      final sessionId = await repo.createSession(entryId);
      expect(sessionId, greaterThan(0));

      // 验证: 会话记录存在且状态为 CREATED
      final session = await (db.select(db.sessions)
            ..where((t) => t.sessionId.equals(sessionId)))
          .getSingle();
      expect(session.state, 'CREATED');
    });

    // ============================================================
    // 测试2: updateSessionState 更新会话状态
    // ============================================================
    test('updateSessionState 更新会话状态', () async {
      // 准备: 创建日程条目 + 会话
      final entryId = await db.into(db.scheduleEntries).insert(
            ScheduleEntriesCompanion.insert(
              unitId: 1,
              date: '2026-07-08',
              startTime: '10:00',
              execMode: 'FOCUS',
            ),
          );
      final sessionId = await repo.createSession(entryId);

      // 执行: 更新会话状态为 RUNNING
      await repo.updateSessionState(sessionId, 'RUNNING');

      // 验证: 数据库中状态已更新
      final session = await (db.select(db.sessions)
            ..where((t) => t.sessionId.equals(sessionId)))
          .getSingle();
      expect(session.state, 'RUNNING');
    });

    // ============================================================
    // 测试3: reportSessionComplete 失败时降级到本地规则
    // ============================================================
    test('reportSessionComplete 失败时降级到本地规则', () async {
      // 准备: 创建日程条目 (WORKOUT 模式) + 会话
      final entryId = await db.into(db.scheduleEntries).insert(
            ScheduleEntriesCompanion.insert(
              unitId: 1,
              date: '2026-07-08',
              startTime: '11:00',
              execMode: 'WORKOUT',
            ),
          );
      final sessionId = await repo.createSession(entryId);

      // 执行: 上报训练完成
      // API 地址无效 → reportSessionComplete 内部捕获异常 → 降级到 LocalFallbackRules
      final result = await repo.reportSessionComplete(
        sessionId: sessionId,
        entryId: entryId,
        completionRatio: 1.0,
        segments: [],
        currentWeight: 50.0,
      );

      // 验证: 降级成功, 来源为 localFallback, 返回本地计算的重量
      // LocalFallbackRules: completionRatio >= 1.0 → 递增 2.5kg → 50.0 + 2.5 = 52.5
      expect(result.success, true);
      expect(result.source, ReportSource.localFallback);
      expect(result.fallbackWeight, isNotNull);
      expect(result.fallbackWeight, 52.5);
    });

    // ============================================================
    // 测试4: getActiveSession 查询活跃会话
    // ============================================================
    test('getActiveSession 查询活跃会话', () async {
      // 准备: 创建日程 + 会话, 并将状态更新为 RUNNING
      final entryId = await db.into(db.scheduleEntries).insert(
            ScheduleEntriesCompanion.insert(
              unitId: 1,
              date: '2026-07-08',
              startTime: '12:00',
              execMode: 'FOCUS',
            ),
          );

      final sessionId = await repo.createSession(entryId);
      await repo.updateSessionState(sessionId, 'RUNNING');

      // 执行: 查询该日程的活跃会话 (CREATED/RUNNING/PAUSED 状态)
      final active = await repo.getActiveSession(entryId);

      // 验证: 返回非空且状态为 RUNNING
      expect(active, isNotNull);
      expect(active!.state, 'RUNNING');
    });

    // ============================================================
    // 测试5: OpLog 在操作后自动记录
    // ============================================================
    test('OpLog 在操作后自动记录', () async {
      // 准备: 创建日程条目
      final entryId = await db.into(db.scheduleEntries).insert(
            ScheduleEntriesCompanion.insert(
              unitId: 1,
              date: '2026-07-08',
              startTime: '13:00',
              execMode: 'FOCUS',
            ),
          );

      // 执行: 通过 Repository 创建会话
      // SessionRepository.createSession 内部会调用 OpLogDao.logOperation
      await repo.createSession(entryId);

      // 验证: OpLog 表中存在未同步记录, 且表名为 sessions
      final opLogDao = OpLogDao(db);
      final unsynced = await opLogDao.getUnsynced();
      expect(unsynced.length, greaterThan(0));
      expect(unsynced.first.tblName, 'sessions');
    });
  });
}
