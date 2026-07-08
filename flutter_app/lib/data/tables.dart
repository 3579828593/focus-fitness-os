import 'package:drift/drift.dart';

/// ============================================================
/// 七表统一数据模型 + 辅助表 (goal, streak, op_log)
/// 设计原则: 日程层统一、内容层分流、执行层统一、细节层分流
/// ============================================================

/// 表1: 内容根表 (学习任务/健身计划 统一)
class ExecutableUnits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get unitType => text()(); // LEARNING | WORKOUT
  TextColumn get title => text()();
  IntColumn get priority => integer().withDefault(const Constant(3))();
  IntColumn get expectedMinutes => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();
}

/// 表2: 学习专属扩展 (1:1 → executable_unit)
class LearningTaskExts extends Table {
  IntColumn get unitId => integer().customConstraint(
      'REFERENCES executable_units(id) ON DELETE CASCADE')();
  TextColumn get taskKind => text()(); // READING | EXERCISE | REVIEW
  IntColumn get focusMinutes => integer().withDefault(const Constant(25))();
  IntColumn get breakMinutes => integer().withDefault(const Constant(5))();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {unitId};
}

/// 表3: 健身专属扩展 (1:1 → executable_unit)
class WorkoutPlanExts extends Table {
  IntColumn get unitId => integer().customConstraint(
      'REFERENCES executable_units(id) ON DELETE CASCADE')();
  TextColumn get workoutKind => text()(); // PUSH | PULL | LEGS | FULL
  TextColumn get targetMuscle => text().nullable()();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {unitId};
}

/// 表4: 动作明细 (1:N → workout_plan_ext)
class WorkoutExercises extends Table {
  IntColumn get exerciseId => integer().autoIncrement()();
  IntColumn get unitId => integer().customConstraint(
      'REFERENCES executable_units(id) ON DELETE CASCADE')();
  TextColumn get name => text()();
  IntColumn get plannedSets => integer()();
  IntColumn get plannedReps => integer()();
  RealColumn get plannedWeight => real()();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
  RealColumn get rpe => real().nullable()();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {exerciseId};
}

/// 表5: 日程行 (统一, 可打开)
class ScheduleEntries extends Table {
  IntColumn get entryId => integer().autoIncrement()();
  IntColumn get unitId => integer().customConstraint(
      'REFERENCES executable_units(id) ON DELETE CASCADE')();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get startTime => text()(); // HH:mm
  TextColumn get execMode => text()(); // FOCUS | WORKOUT
  BoolColumn get isBaseline => boolean().withDefault(const Constant(false))();
  TextColumn get lockState => text().withDefault(const Constant('OPEN'))();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {entryId};
}

/// 表6: 执行会话 (通用状态机)
class Sessions extends Table {
  IntColumn get sessionId => integer().autoIncrement()();
  IntColumn get entryId => integer().customConstraint(
      'REFERENCES schedule_entries(entry_id) ON DELETE CASCADE')();
  TextColumn get state => text().withDefault(const Constant('CREATED'))();
  // CREATED → RUNNING → (PAUSED) → COMPLETED / PARTIAL / ABANDONED
  TextColumn get startedAt => text().nullable()();
  TextColumn get endedAt => text().nullable()();
  RealColumn get completionRatio => real().withDefault(const Constant(0.0))();
  TextColumn get outcome => text().nullable()(); // DONE | PARTIAL | SKIPPED
  IntColumn get lastSegmentIndex =>
      integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// 表7: 执行片段 (分流: 番茄块/健身组)
class SessionSegments extends Table {
  IntColumn get segmentId => integer().autoIncrement()();
  IntColumn get sessionId => integer().customConstraint(
      'REFERENCES sessions(session_id) ON DELETE CASCADE')();
  TextColumn get segType => text()();
  // FOCUS_BLOCK | BREAK | WORKOUT_SET | REST
  IntColumn get plannedSeconds => integer()();
  IntColumn get actualSeconds => integer().nullable()();
  IntColumn get repsDone => integer().nullable()();
  RealColumn get weightKgDone => real().nullable()();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {segmentId};
}

/// 表8: 目标 (OKR, 跨域聚合)
class Goals extends Table {
  IntColumn get goalId => integer().autoIncrement()();
  TextColumn get title => text()();
  RealColumn get targetValue => real()();
  RealColumn get currentValue => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text()(); // "次" / "分钟" / "kg"
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {goalId};
}

/// 表9: 连续记录 (派生)
class Streaks extends Table {
  IntColumn get streakId => integer().autoIncrement()();
  IntColumn get unitId => integer().customConstraint(
      'REFERENCES executable_units(id) ON DELETE CASCADE')();
  IntColumn get currentCount => integer().withDefault(const Constant(0))();
  IntColumn get longestCount => integer().withDefault(const Constant(0))();
  TextColumn get lastDate => text().nullable()();
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {streakId};
}

/// 表10: 操作日志 (同步用)
class OpLogs extends Table {
  IntColumn get opId => integer().autoIncrement()();
  TextColumn get tableName => text()();
  IntColumn get recordId => integer()();
  TextColumn get opType => text()(); // INSERT | UPDATE | DELETE
  TextColumn get payload => text()(); // JSON
  TextColumn get createdAt => text().withDefault(
      const Constant('2026-01-01T00:00:00'))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text().nullable()(); // 操作来源设备标识
  IntColumn get lamportClock => integer().withDefault(const Constant(0))(); // Lamport 逻辑时钟

  @override
  Set<Column> get primaryKey => {opId};
}
