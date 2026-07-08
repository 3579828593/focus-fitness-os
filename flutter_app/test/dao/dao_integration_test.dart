import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_fitness_os/data/database.dart';
import 'package:focus_fitness_os/data/daos/daos.dart';

/// ============================================================
/// DAO 集成测试
/// 使用 Drift 内存数据库 (NativeDatabase.memory()) 进行测试
/// 种子数据在 AppDatabase.onCreate 中自动执行 (seedDatabase):
///   - 2 个目标 (ACTIVE): "每周训练3次", "每日专注学习100分钟"
///   - 2 个执行单元: LEARNING(id=1), WORKOUT(id=2)
///   - 1 个学习任务扩展, 1 个健身计划扩展 (PUSH)
///   - 3 个健身动作 (均属于 WORKOUT 单元)
///   - 2 条连续记录
/// ============================================================

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ============================================================
  // ScheduleDao (4 测)
  // ============================================================
  group('ScheduleDao', () {
    test('getByDate 返回空 (无日程时)', () async {
      final dao = ScheduleDao(db);
      final result = await dao.getByDate('2026-01-01');
      expect(result, isEmpty);
    });

    test('createScheduleEntry 后 getByDate 返回1条', () async {
      // Arrange — 获取种子数据中的单元 ID
      final unitDao = UnitDao(db);
      final units = await unitDao.getActiveUnits();
      final unitId = units.first.id;

      final dao = ScheduleDao(db);

      // Act — 插入一条日程
      await dao.createScheduleEntry(
        ScheduleEntriesCompanion.insert(
          unitId: unitId,
          date: '2026-07-07',
          startTime: '09:00',
          execMode: 'FOCUS',
        ),
      );

      // Assert — 查询该日期应返回1条
      final result = await dao.getByDate('2026-07-07');
      expect(result, hasLength(1));
      expect(result.first.date, '2026-07-07');
      expect(result.first.startTime, '09:00');
      expect(result.first.execMode, 'FOCUS');
    });

    test('watchByDate 发出初始数据', () async {
      final dao = ScheduleDao(db);

      // Drift 的 watch() 流在监听时立即发出当前结果
      final firstEmission = await dao.watchByDate('2026-01-01').first;

      expect(firstEmission, isEmpty);
    });

    test('setLockState 后 lockState 变为 LOCKED', () async {
      // Arrange — 创建一条日程 (默认 lockState = 'OPEN')
      final unitDao = UnitDao(db);
      final units = await unitDao.getActiveUnits();
      final unitId = units.first.id;

      final dao = ScheduleDao(db);
      final entryId = await dao.createScheduleEntry(
        ScheduleEntriesCompanion.insert(
          unitId: unitId,
          date: '2026-07-07',
          startTime: '10:00',
          execMode: 'WORKOUT',
        ),
      );

      // Act — 锁定日程
      await dao.setLockState(entryId, 'LOCKED');

      // Assert — lockState 应变为 'LOCKED'
      final result = await dao.getByDate('2026-07-07');
      expect(result, hasLength(1));
      expect(result.first.lockState, 'LOCKED');
    });
  });

  // ============================================================
  // SessionDao (3 测)
  // ============================================================
  group('SessionDao', () {
    /// 辅助: 创建日程行并返回 entryId (SessionDao 测试需要先有日程)
    Future<int> _createScheduleEntry() async {
      final unitDao = UnitDao(db);
      final units = await unitDao.getActiveUnits();
      final unitId = units.first.id;

      final scheduleDao = ScheduleDao(db);
      return scheduleDao.createScheduleEntry(
        ScheduleEntriesCompanion.insert(
          unitId: unitId,
          date: '2026-07-07',
          startTime: '09:00',
          execMode: 'FOCUS',
        ),
      );
    }

    test('createSession 后 getActiveSessionByEntry 返回该会话', () async {
      // Arrange
      final entryId = await _createScheduleEntry();
      final dao = SessionDao(db);

      // Act — 创建会话 (默认 state = 'CREATED')
      final sessionId = await dao.createSession(
        SessionsCompanion.insert(entryId: entryId),
      );

      // Assert — 查询该日程的活跃会话
      final session = await dao.getActiveSessionByEntry(entryId);
      expect(session, isNotNull);
      expect(session!.sessionId, sessionId);
      expect(session.entryId, entryId);
      expect(session.state, 'CREATED');
    });

    test('updateSessionState 后 state 变为 RUNNING', () async {
      // Arrange
      final entryId = await _createScheduleEntry();
      final dao = SessionDao(db);
      final sessionId = await dao.createSession(
        SessionsCompanion.insert(entryId: entryId),
      );

      // Act — 更新状态为 RUNNING
      await dao.updateSessionState(sessionId, 'RUNNING');

      // Assert
      final session = await dao.getActiveSessionByEntry(entryId);
      expect(session, isNotNull);
      expect(session!.state, 'RUNNING');
    });

    test('createSegments 批量插入后 getSegments 返回正确数量', () async {
      // Arrange
      final entryId = await _createScheduleEntry();
      final dao = SessionDao(db);
      final sessionId = await dao.createSession(
        SessionsCompanion.insert(entryId: entryId),
      );

      // Act — 批量插入3个片段
      await dao.createSegments([
        SessionSegmentsCompanion.insert(
          sessionId: sessionId,
          segType: 'WORKOUT_SET',
          plannedSeconds: 120,
        ),
        SessionSegmentsCompanion.insert(
          sessionId: sessionId,
          segType: 'REST',
          plannedSeconds: 90,
        ),
        SessionSegmentsCompanion.insert(
          sessionId: sessionId,
          segType: 'WORKOUT_SET',
          plannedSeconds: 120,
        ),
      ]);

      // Assert — 查询片段数量和顺序
      final segments = await dao.getSegments(sessionId);
      expect(segments, hasLength(3));
      expect(segments[0].segType, 'WORKOUT_SET');
      expect(segments[1].segType, 'REST');
      expect(segments[2].segType, 'WORKOUT_SET');
    });
  });

  // ============================================================
  // UnitDao (3 测)
  // ============================================================
  group('UnitDao', () {
    test('getActiveUnits 返回种子数据中的2个单元', () async {
      final dao = UnitDao(db);
      final units = await dao.getActiveUnits();

      expect(units, hasLength(2));
      // 验证包含 LEARNING 和 WORKOUT 两种类型
      final types = units.map((u) => u.unitType).toSet();
      expect(types, containsAll(['LEARNING', 'WORKOUT']));
    });

    test('createWorkoutUnit 后 getExercises 返回空', () async {
      // Arrange — 创建新的健身计划 (无动作)
      final dao = UnitDao(db);
      final unitId = await dao.createWorkoutUnit(
        title: '拉日训练',
        priority: 2,
        expectedMinutes: 45,
        workoutKind: 'PULL',
      );

      // Act
      final exercises = await dao.getExercises(unitId);

      // Assert — 新建的健身计划没有动作
      expect(exercises, isEmpty);
    });

    test('addExercise 后 getExercises 返回1条', () async {
      // Arrange — 创建健身计划
      final dao = UnitDao(db);
      final unitId = await dao.createWorkoutUnit(
        title: '腿日训练',
        priority: 2,
        expectedMinutes: 50,
        workoutKind: 'LEGS',
      );

      // Act — 添加一个动作
      await dao.addExercise(
        unitId: unitId,
        name: '杠铃深蹲',
        plannedSets: 5,
        plannedReps: 5,
        plannedWeight: 80.0,
      );

      // Assert
      final exercises = await dao.getExercises(unitId);
      expect(exercises, hasLength(1));
      expect(exercises.first.name, '杠铃深蹲');
      expect(exercises.first.plannedSets, 5);
      expect(exercises.first.plannedReps, 5);
      expect(exercises.first.plannedWeight, 80.0);
    });
  });

  // ============================================================
  // GoalDao (2 测)
  // ============================================================
  group('GoalDao', () {
    test('getActiveGoals 返回种子数据中的2个目标', () async {
      final dao = GoalDao(db);
      final goals = await dao.getActiveGoals();

      expect(goals, hasLength(2));
      // 验证目标标题
      final titles = goals.map((g) => g.title).toSet();
      expect(titles, contains('每周训练3次'));
      expect(titles, contains('每日专注学习100分钟'));
      // 种子数据中 currentValue 应为默认值 0.0
      for (final goal in goals) {
        expect(goal.currentValue, 0.0);
        expect(goal.status, 'ACTIVE');
      }
    });

    test('updateGoalProgress 后 currentValue 更新', () async {
      // Arrange — 获取第一个目标
      final dao = GoalDao(db);
      final goals = await dao.getActiveGoals();
      final goalId = goals.first.goalId;
      final originalValue = goals.first.currentValue;

      // Act — 更新进度为 2.5
      await dao.updateGoalProgress(goalId, 2.5);

      // Assert — 重新查询验证更新
      final updatedGoals = await dao.getActiveGoals();
      final updatedGoal = updatedGoals.firstWhere((g) => g.goalId == goalId);
      expect(updatedGoal.currentValue, 2.5);
      expect(updatedGoal.currentValue, isNot(originalValue));
    });
  });
}
