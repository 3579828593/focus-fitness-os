import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:focus_fitness_os/main.dart';
import 'package:focus_fitness_os/data/database.dart';
import 'package:focus_fitness_os/data/tables.dart';
import 'package:focus_fitness_os/services/nodered_api.dart';
import 'package:focus_fitness_os/runners/session_state.dart';
import 'package:focus_fitness_os/providers/workout_session_notifier.dart';

/// ============================================================
/// WorkoutSessionNotifier 单元测试
///
/// 使用 Drift 内存数据库 (NativeDatabase.memory()) 进行测试。
/// 种子数据在 AppDatabase.onCreate 回调中自动执行 (seedDatabase):
///   - unitId=1: LEARNING "专注学习"
///   - unitId=2: WORKOUT  "推日训练" (含3个动作: 卧推4×8, 肩推3×10, 三头下压3×12)
///
/// API 使用无效地址 (http://localhost:1) + maxRetries=0,
/// 确保网络请求立即失败, 触发本地降级逻辑, 同时避免测试长时间等待。
///
/// 测试覆盖 WorkoutSessionNotifier 的状态流转:
///   初始状态 → init → completeSet(完成一组→休息) → skipRest(跳过休息→下一组)
///   → abandon(放弃)
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

  /// 辅助方法: 在 DB 中插入一条 WORKOUT 模式的日程行并返回 entryId
  /// unitId=2 来自种子数据: WORKOUT "推日训练"
  Future<int> _createWorkoutScheduleEntry() async {
    return db.into(db.scheduleEntries).insert(
          ScheduleEntriesCompanion.insert(
            unitId: 2,
            date: '2026-07-08',
            startTime: '10:00',
            execMode: 'WORKOUT',
          ),
        );
  }

  group('WorkoutSessionNotifier', () {
    // ============================================================
    // 测试1: 初始状态 isInitialized=false, runner=null
    // ============================================================
    test('初始状态 isInitialized=false, runner=null', () {
      // Arrange — 容器已创建, 未调用 init

      // Act — 读取 provider 的初始状态 (触发 build())
      final state = container.read(workoutSessionNotifierProvider);

      // Assert — 默认空状态
      expect(state.isInitialized, false);
      expect(state.runner, isNull);
    });

    // ============================================================
    // 测试2: init(entryId) 后 isInitialized=true, runner不为null
    // ============================================================
    test('init(entryId) 后 isInitialized=true, runner不为null', () async {
      // Arrange — 插入日程行 (unitId=2 来自种子数据: WORKOUT "推日训练")
      final entryId = await _createWorkoutScheduleEntry();

      // Act — 初始化 Notifier (加载 Runner + 创建 DB 会话)
      await container
          .read(workoutSessionNotifierProvider.notifier)
          .init(entryId);
      final state = container.read(workoutSessionNotifierProvider);

      // Assert — 初始化成功
      expect(state.isInitialized, true);
      expect(state.runner, isNotNull);
      expect(state.runner, isA<WorkoutRunner>());
      expect(state.sessionId, isNotNull);
      expect(state.sessionId!, greaterThan(0));
    });

    // ============================================================
    // 测试3: completeSet 后 runner推进到休息段 (isResting=true 或 segment变化)
    // ============================================================
    test('completeSet 后 runner推进到休息段 (isResting=true 或 segment变化)',
        () async {
      // Arrange — 插入日程并初始化 Notifier
      // init 后 runner 处于 running 状态 (WorkoutRunner.init 会自动 start)
      final entryId = await _createWorkoutScheduleEntry();
      await container
          .read(workoutSessionNotifierProvider.notifier)
          .init(entryId);

      // 记录 init 后的片段索引, 用于后续比较
      final stateBefore = container.read(workoutSessionNotifierProvider);
      final segmentIndexBefore =
          stateBefore.runner!.currentSegmentIndex;

      // Act — 完成第一组 (8次, 60kg, RPE 7.5)
      // completeSet 内部: recordSet + advanceToNextSegment
      // workoutSet 段结束后自动推进到 rest 段
      container
          .read(workoutSessionNotifierProvider.notifier)
          .completeSet(8, 60.0, 7.5);
      final state = container.read(workoutSessionNotifierProvider);

      // Assert — runner 推进到休息段
      // 验证方式: isResting=true 或 currentSegmentIndex 发生变化
      expect(
        state.isResting ||
            state.runner!.currentSegmentIndex != segmentIndexBefore,
        true,
        reason: 'completeSet 后应推进到休息段 (isResting 或 segment 变化)',
      );

      // 额外验证: 当前片段类型应为 REST
      final currentSegment =
          state.runner!.segments[state.runner!.currentSegmentIndex];
      expect(currentSegment.segType, SegmentType.rest);
    });

    // ============================================================
    // 测试4: skipRest() 后推进到下一组
    // ============================================================
    test('skipRest() 后推进到下一组', () async {
      // Arrange — 插入日程、初始化、完成第一组 (进入休息段)
      final entryId = await _createWorkoutScheduleEntry();
      await container
          .read(workoutSessionNotifierProvider.notifier)
          .init(entryId);
      container
          .read(workoutSessionNotifierProvider.notifier)
          .completeSet(8, 60.0, 7.5);

      // 记录休息段的片段索引
      final stateInRest = container.read(workoutSessionNotifierProvider);
      final segmentIndexInRest =
          stateInRest.runner!.currentSegmentIndex;

      // Act — 跳过休息, 推进到下一组
      container.read(workoutSessionNotifierProvider.notifier).skipRest();
      final state = container.read(workoutSessionNotifierProvider);

      // Assert — 已离开休息段, 推进到下一组
      expect(state.isResting, false);
      expect(
        state.runner!.currentSegmentIndex,
        greaterThan(segmentIndexInRest),
        reason: 'skipRest 后 currentSegmentIndex 应推进到下一组',
      );

      // 额外验证: 当前片段类型应为 WORKOUT_SET
      final currentSegment =
          state.runner!.segments[state.runner!.currentSegmentIndex];
      expect(currentSegment.segType, SegmentType.workoutSet);
    });

    // ============================================================
    // 测试5: abandon() 后 isDone=true 或 runner.state为abandoned
    // ============================================================
    test('abandon() 后 isDone=true 或 runner.state为abandoned', () async {
      // Arrange — 插入日程并初始化 (abandon 可从任意状态调用)
      final entryId = await _createWorkoutScheduleEntry();
      await container
          .read(workoutSessionNotifierProvider.notifier)
          .init(entryId);

      // Act — 放弃会话
      container.read(workoutSessionNotifierProvider.notifier).abandon();
      final state = container.read(workoutSessionNotifierProvider);

      // Assert — 会话已终止 (isDone 或 runner 状态为 abandoned)
      expect(
        state.isDone || state.runner!.state == SessionState.abandoned,
        true,
        reason: 'abandon 后应标记 isDone 或 runner 状态为 abandoned',
      );

      // 额外验证: runner 处于终态
      if (state.runner != null) {
        expect(state.runner!.isTerminal, true);
      }
    });
  });
}
