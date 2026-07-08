import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

/// ============================================================
/// DAO 层: 5 个数据访问对象
/// ScheduleDao / SessionDao / UnitDao / GoalDao / OpLogDao
/// 共享同一个 codegen part 文件
/// ============================================================

part 'daos.g.dart';

@DriftAccessor(tables: [ScheduleEntries])
class ScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduleDaoMixin {
  ScheduleDao(AppDatabase db) : super(db);

  /// 查询某日所有日程 (按开始时间排序)
  Future<List<ScheduleEntry>> getByDate(String date) {
    return (select(scheduleEntries)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
  }

  /// 监听某日日程变化 (Stream)
  Stream<List<ScheduleEntry>> watchByDate(String date) {
    return (select(scheduleEntries)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .watch();
  }

  /// 创建日程行
  Future<int> createScheduleEntry(ScheduleEntriesCompanion entry) {
    return into(scheduleEntries).insert(entry);
  }

  /// 更新日程行
  Future<bool> updateScheduleEntry(ScheduleEntry entry) {
    return update(scheduleEntries).replace(entry);
  }

  /// 删除日程行
  Future<int> deleteScheduleEntry(int entryId) {
    return (delete(scheduleEntries)..where((t) => t.entryId.equals(entryId)))
        .go();
  }

  /// 查询某日某时段的日程 (冲突检测用)
  Future<List<ScheduleEntry>> getByDateAndTime(String date, String startTime) {
    return (select(scheduleEntries)
          ..where((t) => t.date.equals(date) & t.startTime.equals(startTime)))
        .get();
  }

  /// 锁定/解锁日程
  Future<void> setLockState(int entryId, String lockState) {
    return (update(scheduleEntries)
          ..where((t) => t.entryId.equals(entryId)))
        .write(ScheduleEntriesCompanion(lockState: Value(lockState)));
  }
}

/// ============================================================
/// SessionDAO: 会话 + 片段 CRUD
/// ============================================================

@DriftAccessor(tables: [Sessions, SessionSegments])
class SessionDao extends DatabaseAccessor<AppDatabase>
    with _$SessionDaoMixin {
  SessionDao(AppDatabase db) : super(db);

  /// 创建会话
  Future<int> createSession(SessionsCompanion session) {
    return into(sessions).insert(session);
  }

  /// 查询某日程的非终态会话 (续接用)
  Future<Session?> getActiveSessionByEntry(int entryId) {
    return (select(sessions)
          ..where((t) =>
              t.entryId.equals(entryId) &
              t.state.isIn(['CREATED', 'RUNNING', 'PAUSED'])))
        .getSingleOrNull();
  }

  /// 更新会话状态
  Future<void> updateSessionState(int sessionId, String state,
      {double? completionRatio, String? endedAt, int? lastSegmentIndex}) {
    final companion = SessionsCompanion(
      state: Value(state),
      completionRatio: completionRatio != null
          ? Value(completionRatio)
          : const Value.absent(),
      endedAt: endedAt != null ? Value(endedAt) : const Value.absent(),
      lastSegmentIndex: lastSegmentIndex != null
          ? Value(lastSegmentIndex)
          : const Value.absent(),
    );
    return (update(sessions)..where((t) => t.sessionId.equals(sessionId)))
        .write(companion);
  }

  /// 查询会话的所有片段
  Future<List<SessionSegment>> getSegments(int sessionId) {
    return (select(sessionSegments)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.segmentId)]))
        .get();
  }

  /// 创建片段
  Future<int> createSegment(SessionSegmentsCompanion segment) {
    return into(sessionSegments).insert(segment);
  }

  /// 批量创建片段
  Future<void> createSegments(List<SessionSegmentsCompanion> segments) {
    return batch((b) => b.insertAll(sessionSegments, segments));
  }

  /// 更新片段 (录入训练数据)
  Future<void> updateSegment(SessionSegment segment) {
    return (update(sessionSegments)
          ..where((t) => t.segmentId.equals(segment.segmentId)))
        .replace(segment);
  }

  /// 查询某周所有会话 (周报用)
  Future<List<Session>> getSessionsInRange(String startDate, String endDate) {
    return (select(sessions)
          ..where((t) =>
              t.startedAt.isBiggerOrEqualValue(startDate) &
              t.startedAt.isSmallerOrEqualValue(endDate)))
        .get();
  }
}

/// ============================================================
/// UnitDAO: 内容根 + 扩展表 CRUD
/// ============================================================

@DriftAccessor(
    tables: [ExecutableUnits, LearningTaskExts, WorkoutPlanExts, WorkoutExercises])
class UnitDao extends DatabaseAccessor<AppDatabase>
    with _$UnitDaoMixin {
  UnitDao(AppDatabase db) : super(db);

  /// 查询所有活跃的执行单元
  Future<List<ExecutableUnit>> getActiveUnits() {
    return (select(executableUnits)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .get();
  }

  /// 查询学习任务的专注参数
  Future<LearningTaskExt?> getLearningTaskExt(int unitId) {
    return (select(learningTaskExts)..where((t) => t.unitId.equals(unitId)))
        .getSingleOrNull();
  }

  /// 创建学习任务 (含扩展)
  /// 多表插入使用事务包裹，保证原子性
  Future<int> createLearningUnit({
    required String title,
    required int priority,
    required int expectedMinutes,
    required String taskKind,
    int focusMinutes = 25,
    int breakMinutes = 5,
  }) async {
    return transaction(() async {
      final now = DateTime.now().toIso8601String();
      final unitId = await into(executableUnits).insert(
            ExecutableUnitsCompanion.insert(
              unitType: 'LEARNING',
              title: title,
              priority: Value(priority),
              expectedMinutes: expectedMinutes,
              createdAt: Value(now),
            ),
          );

      await into(learningTaskExts).insert(
        LearningTaskExtsCompanion.insert(
          unitId: unitId,
          taskKind: taskKind,
          focusMinutes: Value(focusMinutes),
          breakMinutes: Value(breakMinutes),
        ),
      );

      return unitId;
    });
  }

  /// 创建健身计划 (含扩展)
  /// 多表插入使用事务包裹，保证原子性
  Future<int> createWorkoutUnit({
    required String title,
    required int priority,
    required int expectedMinutes,
    required String workoutKind,
    String? targetMuscle,
  }) async {
    return transaction(() async {
      final now = DateTime.now().toIso8601String();
      final unitId = await into(executableUnits).insert(
            ExecutableUnitsCompanion.insert(
              unitType: 'WORKOUT',
              title: title,
              priority: Value(priority),
              expectedMinutes: expectedMinutes,
              createdAt: Value(now),
            ),
          );

      await into(workoutPlanExts).insert(
        WorkoutPlanExtsCompanion.insert(
          unitId: unitId,
          workoutKind: workoutKind,
          targetMuscle: targetMuscle != null ? Value(targetMuscle) : const Value.absent(),
        ),
      );

      return unitId;
    });
  }

  /// 添加动作到健身计划
  Future<int> addExercise({
    required int unitId,
    required String name,
    required int plannedSets,
    required int plannedReps,
    required double plannedWeight,
    int restSeconds = 90,
  }) {
    return into(workoutExercises).insert(
      WorkoutExercisesCompanion.insert(
        unitId: unitId,
        name: name,
        plannedSets: plannedSets,
        plannedReps: plannedReps,
        plannedWeight: plannedWeight,
        restSeconds: Value(restSeconds),
      ),
    );
  }

  /// 查询某健身计划的所有动作
  Future<List<WorkoutExercise>> getExercises(int unitId) {
    return (select(workoutExercises)
          ..where((t) => t.unitId.equals(unitId))
          ..orderBy([(t) => OrderingTerm.asc(t.exerciseId)]))
        .get();
  }

  /// 更新动作的递增重量 (提案确认后调用)
  Future<void> updateExerciseWeight(int exerciseId, double newWeight) {
    return (update(workoutExercises)
          ..where((t) => t.exerciseId.equals(exerciseId)))
        .write(WorkoutExercisesCompanion(plannedWeight: Value(newWeight)));
  }
}

/// ============================================================
/// GoalDAO: 目标 + 连续记录 CRUD
/// ============================================================

@DriftAccessor(tables: [Goals, Streaks])
class GoalDao extends DatabaseAccessor<AppDatabase>
    with _$GoalDaoMixin {
  GoalDao(AppDatabase db) : super(db);

  /// 查询所有活跃目标
  Future<List<Goal>> getActiveGoals() {
    return (select(goals)..where((t) => t.status.equals('ACTIVE'))).get();
  }

  /// 更新目标当前值
  Future<void> updateGoalProgress(int goalId, double currentValue) {
    return (update(goals)..where((t) => t.goalId.equals(goalId)))
        .write(GoalsCompanion(currentValue: Value(currentValue)));
  }

  /// 查询某执行单元的连续记录
  Future<Streak?> getStreak(int unitId) {
    return (select(streaks)..where((t) => t.unitId.equals(unitId)))
        .getSingleOrNull();
  }

  /// 更新连续记录
  Future<void> updateStreak(int streakId, int currentCount, int longestCount,
      String lastDate) {
    return (update(streaks)..where((t) => t.streakId.equals(streakId)))
        .write(StreaksCompanion(
      currentCount: Value(currentCount),
      longestCount: Value(longestCount),
      lastDate: Value(lastDate),
    ));
  }
}

/// ============================================================
/// OpLogDao: 操作日志数据访问对象
/// 负责记录数据变更、扫描未同步记录、标记同步完成
/// ============================================================
@DriftAccessor(tables: [OpLogs])
class OpLogDao extends DatabaseAccessor<AppDatabase>
    with _$OpLogDaoMixin {
  OpLogDao(AppDatabase db) : super(db);

  /// 记录操作日志
  Future<int> logOperation({
    required String tableName,
    required int recordId,
    required String opType, // INSERT | UPDATE | DELETE
    required Map<String, dynamic> payload,
    String? deviceId,
    int? lamportClock,
  }) {
    return into(opLogs).insert(OpLogsCompanion.insert(
      tableName: tableName,
      recordId: recordId,
      opType: opType,
      payload: jsonEncode(payload), // 正确的 JSON 编码
      deviceId: deviceId != null ? Value(deviceId) : const Value.absent(),
      lamportClock: lamportClock != null ? Value(lamportClock) : const Value.absent(),
    ));
  }

  /// 查询所有未同步的操作日志
  Future<List<OpLog>> getUnsynced({int limit = 50}) {
    return (select(opLogs)
          ..where((t) => t.synced.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// 标记操作已同步
  Future<void> markSynced(int opId) {
    return (update(opLogs)..where((t) => t.opId.equals(opId)))
        .write(const OpLogsCompanion(synced: Value(true)));
  }

  /// 批量标记已同步
  Future<void> markBatchSynced(List<int> opIds) {
    return (update(opLogs)..where((t) => t.opId.isIn(opIds)))
        .write(const OpLogsCompanion(synced: Value(true)));
  }

  /// 统计未同步记录数
  Future<int> unsyncedCount() async {
    final count = countOf(opLogs);
    final result = await (selectOnly(opLogs)
          ..addColumns([count])
          ..where(opLogs.synced.equals(false)))
        .getSingle();
    return result.read(count) ?? 0;
  }
}
