part of 'database.dart';

/// ============================================================
/// 种子数据: 首次启动时插入默认数据
/// 包含: 默认目标 + 默认学习任务 + 默认健身计划(推日)
/// 作为 database.dart 的 part, 消除循环导入
/// ============================================================

Future<void> seedDatabase(AppDatabase db) async {
  final now = DateTime.now().toIso8601String();

  // 1. 默认目标: 每周训练3次
  await db.into(db.goals).insert(GoalsCompanion.insert(
        title: '每周训练3次',
        targetValue: 3.0,
        unit: '次',
      ));

  // 2. 默认目标: 每日专注学习100分钟
  await db.into(db.goals).insert(GoalsCompanion.insert(
        title: '每日专注学习100分钟',
        targetValue: 100.0,
        unit: '分钟',
      ));

  // 3. 默认学习任务: 专注学习 (番茄钟25分钟)
  final learningUnitId = await db.into(db.executableUnits).insert(
        ExecutableUnitsCompanion.insert(
          unitType: 'LEARNING',
          title: '专注学习',
          priority: Value(2),
          expectedMinutes: 50,
          createdAt: Value(now),
        ),
      );

  await db.into(db.learningTaskExts).insert(
        LearningTaskExtsCompanion.insert(
          unitId: learningUnitId,
          taskKind: 'READING',
          focusMinutes: Value(25),
          breakMinutes: Value(5),
        ),
      );

  // 4. 默认健身计划: 推日训练
  final workoutUnitId = await db.into(db.executableUnits).insert(
        ExecutableUnitsCompanion.insert(
          unitType: 'WORKOUT',
          title: '推日训练',
          priority: Value(1),
          expectedMinutes: 60,
          createdAt: Value(now),
        ),
      );

  await db.into(db.workoutPlanExts).insert(
        WorkoutPlanExtsCompanion.insert(
          unitId: workoutUnitId,
          workoutKind: 'PUSH',
          targetMuscle: Value('胸/肩/三头'),
        ),
      );

  // 5. 推日动作明细: 卧推4×8 / 肩推3×10 / 三头下压3×12
  await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
        unitId: workoutUnitId,
        name: '杠铃卧推',
        plannedSets: 4,
        plannedReps: 8,
        plannedWeight: 60.0,
        restSeconds: Value(120),
      ));

  await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
        unitId: workoutUnitId,
        name: '哑铃肩推',
        plannedSets: 3,
        plannedReps: 10,
        plannedWeight: 20.0,
        restSeconds: Value(90),
      ));

  await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
        unitId: workoutUnitId,
        name: '绳索三头下压',
        plannedSets: 3,
        plannedReps: 12,
        plannedWeight: 25.0,
        restSeconds: Value(60),
      ));

  // 6. 初始化连续记录
  await db.into(db.streaks).insert(StreaksCompanion.insert(
        unitId: learningUnitId,
      ));

  await db.into(db.streaks).insert(StreaksCompanion.insert(
        unitId: workoutUnitId,
      ));
}
