import '../data/database.dart';
import '../data/daos/daos.dart';
import '../data/tables.dart';
import '../runners/session_state.dart';
import 'package:drift/drift.dart';

/// ============================================================
/// WorkoutRepository: 健身数据仓库
/// 整合 UnitDao + WorkoutExercises 查询
/// 提供健身会话所需的数据加载接口
/// ============================================================
class WorkoutRepository {
  final AppDatabase _db;
  final UnitDao _unitDao;

  WorkoutRepository(this._db) : _unitDao = UnitDao(_db);

  /// 加载健身计划数据 (动作列表)
  Future<WorkoutPlanData> loadWorkoutPlan(int unitId) async {
    final exercises = await _unitDao.getExercises(unitId);
    if (exercises.isEmpty) {
      throw StateError('未找到动作数据, unitId: $unitId');
    }

    final exerciseDataList = exercises.map((e) => ExerciseData(
      exerciseId: e.exerciseId,
      name: e.name,
      plannedSets: e.plannedSets,
      plannedReps: e.plannedReps,
      plannedWeight: e.plannedWeight,
      restSeconds: e.restSeconds,
    )).toList();

    return WorkoutPlanData(exercises: exerciseDataList);
  }

  /// 加载专注参数
  Future<FocusConfig> loadFocusConfig(int unitId) async {
    final ext = await _unitDao.getLearningTaskExt(unitId);
    return FocusConfig(
      focusMinutes: ext?.focusMinutes ?? 25,
      breakMinutes: ext?.breakMinutes ?? 5,
    );
  }

  /// 查询日程
  Future<ScheduleEntry?> getScheduleEntry(int entryId) async {
    final results = await (_db.select(_db.scheduleEntries)
          ..where((t) => t.entryId.equals(entryId)))
        .get();
    return results.isEmpty ? null : results.first;
  }
}

/// 健身计划数据包
class WorkoutPlanData {
  final List<ExerciseData> exercises;
  WorkoutPlanData({required this.exercises});
}

/// 专注配置
class FocusConfig {
  final int focusMinutes;
  final int breakMinutes;
  FocusConfig({required this.focusMinutes, required this.breakMinutes});
}
