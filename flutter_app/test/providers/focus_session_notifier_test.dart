import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

import 'package:focus_fitness_os/main.dart';
import 'package:focus_fitness_os/data/database.dart';
import 'package:focus_fitness_os/data/tables.dart';
import 'package:focus_fitness_os/services/nodered_api.dart';
import 'package:focus_fitness_os/runners/session_state.dart';
import 'package:focus_fitness_os/providers/focus_session_notifier.dart';

/// ============================================================
/// FocusSessionNotifier 单元测试
///
/// 使用 Drift 内存数据库 (NativeDatabase.memory()) 进行测试。
/// 种子数据在 AppDatabase.onCreate 回调中自动执行 (seedDatabase):
///   - unitId=1: LEARNING "专注学习" (focusMinutes=25, breakMinutes=5)
///   - unitId=2: WORKOUT  "推日训练"
///
/// API 使用无效地址 (http://localhost:1) + maxRetries=0,
/// 确保网络请求立即失败, 触发本地降级逻辑, 同时避免测试长时间等待。
///
/// 测试覆盖 FocusSessionNotifier 的状态流转:
///   初始状态 → init → toggleTimer(开始) → toggleTimer(暂停)
///   → complete(完成) / abandon(放弃)
/// ============================================================
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    // 创建内存数据库
    // onCreate 回调会自动建表 + 插入种子数据 (无需手动调用 seedDatabase)
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 触发数据库连接初始化 (打开 → onCreate → 种子数据插入)
    await db.customStatement('PRAGMA foreign_keys = ON');

    // 创建测试容器, override databaseProvider 和 nodeRedApiProvider
    // maxRetries=0: 首次失败立即抛出, 不做指数退避重试, 加快测试速度
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      nodeRedApiProvider.overrideWithValue(NodeRedApi(
        baseUrl: 'http://localhost:1',
        apiToken: 'test',
        maxRetries: 0,
        timeoutSeconds: 1,
      )),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 辅助方法: 在 DB 中插入一条 FOCUS 模式的日程行并返回 entryId
  /// unitId=1 来自种子数据: LEARNING "专注学习"
  Future<int> _createFocusScheduleEntry() async {
    return db.into(db.scheduleEntries).insert(
          ScheduleEntriesCompanion.insert(
            unitId: 1,
            date: '2026-07-08',
            startTime: '09:00',
            execMode: 'FOCUS',
          ),
        );
  }

  group('FocusSessionNotifier', () {
    // ============================================================
    // 测试1: 初始状态 isInitialized=false, runner=null
    // ============================================================
    test('初始状态 isInitialized=false, runner=null', () {
      // Arrange — 容器已创建, 未调用 init

      // Act — 读取 provider 的初始状态 (触发 build())
      final state = container.read(focusSessionNotifierProvider);

      // Assert — 默认空状态
      expect(state.isInitialized, false);
      expect(state.runner, isNull);
    });

    // ============================================================
    // 测试2: init(entryId) 后 isInitialized=true, runner不为null, sessionId>0
    // ============================================================
    test('init(entryId) 后 isInitialized=true, runner不为null, sessionId>0',
        () async {
      // Arrange — 插入日程行 (unitId=1 来自种子数据)
      final entryId = await _createFocusScheduleEntry();

      // Act — 初始化 Notifier (加载 Runner + 创建 DB 会话)
      await container.read(focusSessionNotifierProvider.notifier).init(entryId);
      final state = container.read(focusSessionNotifierProvider);

      // Assert — 初始化成功
      expect(state.isInitialized, true);
      expect(state.runner, isNotNull);
      expect(state.runner, isA<FocusRunner>());
      expect(state.sessionId, isNotNull);
      expect(state.sessionId!, greaterThan(0));
    });

    // ============================================================
    // 测试3: toggleTimer() 从created状态调用后 isRunning=true
    // ============================================================
    test('toggleTimer() 从created状态调用后 isRunning=true', () async {
      // Arrange — 插入日程并初始化 Notifier
      final entryId = await _createFocusScheduleEntry();
      await container.read(focusSessionNotifierProvider.notifier).init(entryId);

      // Act — 首次 toggleTimer: 从 created → running
      container.read(focusSessionNotifierProvider.notifier).toggleTimer();
      final state = container.read(focusSessionNotifierProvider);

      // Assert — 计时器已启动
      expect(state.isRunning, true);
      expect(state.runner!.state, SessionState.running);
    });

    // ============================================================
    // 测试4: 再次 toggleTimer() 后 isRunning=false (暂停)
    // ============================================================
    test('再次 toggleTimer() 后 isRunning=false (暂停)', () async {
      // Arrange — 插入日程并初始化, 然后启动计时器
      final entryId = await _createFocusScheduleEntry();
      await container.read(focusSessionNotifierProvider.notifier).init(entryId);
      container.read(focusSessionNotifierProvider.notifier).toggleTimer();

      // Act — 第二次 toggleTimer: 从 running → paused
      container.read(focusSessionNotifierProvider.notifier).toggleTimer();
      final state = container.read(focusSessionNotifierProvider);

      // Assert — 计时器已暂停
      expect(state.isRunning, false);
      expect(state.runner!.state, SessionState.paused);
    });

    // ============================================================
    // 测试5: complete() 后 runner.state 为 completed
    // ============================================================
    test('complete() 后 runner.state 为 completed', () async {
      // Arrange — 插入日程、初始化并启动计时器 (complete 需要从 running 状态调用)
      final entryId = await _createFocusScheduleEntry();
      await container.read(focusSessionNotifierProvider.notifier).init(entryId);
      container.read(focusSessionNotifierProvider.notifier).toggleTimer();

      // Act — 完成会话
      container.read(focusSessionNotifierProvider.notifier).complete();
      final state = container.read(focusSessionNotifierProvider);

      // Assert — 会话状态为已完成
      expect(state.runner!.state, SessionState.completed);
      expect(state.runner!.isTerminal, true);
    });

    // ============================================================
    // 测试6: abandon() 后 runner.state 为 abandoned
    // ============================================================
    test('abandon() 后 runner.state 为 abandoned', () async {
      // Arrange — 插入日程并初始化 (abandon 可从任意状态调用)
      final entryId = await _createFocusScheduleEntry();
      await container.read(focusSessionNotifierProvider.notifier).init(entryId);

      // Act — 放弃会话
      container.read(focusSessionNotifierProvider.notifier).abandon();
      final state = container.read(focusSessionNotifierProvider);

      // Assert — 会话状态为已放弃
      expect(state.runner!.state, SessionState.abandoned);
      expect(state.runner!.isTerminal, true);
    });
  });
}
