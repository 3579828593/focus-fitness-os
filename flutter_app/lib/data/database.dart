import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';
import 'daos/daos.dart';

part 'database.g.dart';
part 'seed.dart';

/// ============================================================
/// Drift 数据库定义
/// 七表统一数据模型 + 辅助表 + 索引 + 迁移策略
/// ============================================================

@DriftDatabase(
  tables: [
    ExecutableUnits,
    LearningTaskExts,
    WorkoutPlanExts,
    WorkoutExercises,
    ScheduleEntries,
    Sessions,
    SessionSegments,
    Goals,
    Streaks,
    OpLogs,
  ],
  daos: [ScheduleDao, SessionDao, UnitDao, GoalDao, OpLogDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // 测试用构造函数
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          // 创建索引
          await customStatement(
              'CREATE INDEX idx_schedule_date_time ON schedule_entries(date, start_time)');
          await customStatement(
              'CREATE INDEX idx_session_entry_state ON sessions(entry_id, state)');
          await customStatement(
              'CREATE INDEX idx_segment_session ON session_segments(session_id, segment_id)');
          await customStatement(
              'CREATE INDEX idx_oplog_synced ON op_logs(synced, created_at)');
          await customStatement(
              'CREATE INDEX idx_exercise_unit ON workout_exercises(unit_id)');
          await customStatement(
              'CREATE INDEX idx_streak_unit_date ON streaks(unit_id, last_date)');

          // 插入种子数据
          await seedDatabase(this);
        },
        onUpgrade: (m, from, to) async {
          if (from == 1 && to >= 2) {
            // V2: 添加审计字段到业务表
            await customStatement('ALTER TABLE executable_units ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE executable_units ADD COLUMN deleted_at TEXT');

            await customStatement('ALTER TABLE learning_task_exts ADD COLUMN created_at TEXT DEFAULT "2026-01-01T00:00:00"');
            await customStatement('ALTER TABLE learning_task_exts ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE learning_task_exts ADD COLUMN deleted_at TEXT');

            await customStatement('ALTER TABLE workout_plan_exts ADD COLUMN created_at TEXT DEFAULT "2026-01-01T00:00:00"');
            await customStatement('ALTER TABLE workout_plan_exts ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE workout_plan_exts ADD COLUMN deleted_at TEXT');

            await customStatement('ALTER TABLE workout_exercises ADD COLUMN created_at TEXT DEFAULT "2026-01-01T00:00:00"');
            await customStatement('ALTER TABLE workout_exercises ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE workout_exercises ADD COLUMN deleted_at TEXT');

            await customStatement('ALTER TABLE schedule_entries ADD COLUMN created_at TEXT DEFAULT "2026-01-01T00:00:00"');
            await customStatement('ALTER TABLE schedule_entries ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE schedule_entries ADD COLUMN deleted_at TEXT');

            await customStatement('ALTER TABLE sessions ADD COLUMN created_at TEXT DEFAULT "2026-01-01T00:00:00"');
            await customStatement('ALTER TABLE sessions ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE sessions ADD COLUMN deleted_at TEXT');

            await customStatement('ALTER TABLE session_segments ADD COLUMN created_at TEXT DEFAULT "2026-01-01T00:00:00"');
            await customStatement('ALTER TABLE session_segments ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE session_segments ADD COLUMN deleted_at TEXT');

            await customStatement('ALTER TABLE goals ADD COLUMN created_at TEXT DEFAULT "2026-01-01T00:00:00"');
            await customStatement('ALTER TABLE goals ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE goals ADD COLUMN deleted_at TEXT');

            await customStatement('ALTER TABLE streaks ADD COLUMN created_at TEXT DEFAULT "2026-01-01T00:00:00"');
            await customStatement('ALTER TABLE streaks ADD COLUMN updated_at TEXT');
            await customStatement('ALTER TABLE streaks ADD COLUMN deleted_at TEXT');

            // V2: OpLogs 冲突元数据
            await customStatement('ALTER TABLE op_logs ADD COLUMN device_id TEXT');
            await customStatement('ALTER TABLE op_logs ADD COLUMN lamport_clock INTEGER DEFAULT 0');

            // V2: 软删除过滤索引
            await customStatement('CREATE INDEX idx_schedule_active ON schedule_entries(date, deleted_at)');
            await customStatement('CREATE INDEX idx_session_active ON sessions(entry_id, deleted_at)');
          }
        },
        beforeOpen: (details) async {
          // 启用外键约束
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await _getDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}

Future<io.File> _getDatabaseFile() async {
  // 实际项目中用 path_provider 获取应用文档目录
  // 这里用当前目录作为开发阶段占位
  return io.File('focus_fitness.db');
}
