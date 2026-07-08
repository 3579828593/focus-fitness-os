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
          unitType: const Constant('LEARNING'),
          title: const Constant('专注学习'),
          priority: const Constant(2),
          expectedMinutes: const Constant(50),
          createdAt: Value(now),
        ),
      );

  await db.into(db.learningTaskExts).insert(
        LearningTaskExtsCompanion.insert(
          unitId: learningUnitId,
          taskKind: const Constant('READING'),
          focusMinutes: const Constant(25),
          breakMinutes: const Constant(5),
        ),
      );

  // 4. 默认健身计划: 推日训练
  final workoutUnitId = await db.into(db.executableUnits).insert(
        ExecutableUnitsCompanion.insert(
          unitType: const Constant('WORKOUT'),
          title: const Constant('推日训练'),
          priority: const Constant(1),
          expectedMinutes: const Constant(60),
          createdAt: Value(now),
        ),
      );

  await db.into(db.workoutPlanExts).insert(
        WorkoutPlanExtsCompanion.insert(
          unitId: workoutUnitId,
          workoutKind: const Constant('PUSH'),
          targetMuscle: const Constant('胸/肩/三头'),
        ),
      );

  // 5. 推日动作明细: 卧推4×8 / 肩推3×10 / 三头下压3×12
  await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
        unitId: workoutUnitId,
        name: const Constant('杠铃卧推'),
        plannedSets: const Constant(4),
        plannedReps: const Constant(8),
        plannedWeight: const Constant(60.0),
        restSeconds: const Constant(120),
      ));

  await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
        unitId: workoutUnitId,
        name: const Constant('哑铃肩推'),
        plannedSets: const Constant(3),
        plannedReps: const Constant(10),
        plannedWeight: const Constant(20.0),
        restSeconds: const Constant(90),
      ));

  await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
        unitId: workoutUnitId,
        name: const Constant('绳索三头下压'),
        plannedSets: const Constant(3),
        plannedReps: const Constant(12),
        plannedWeight: const Constant(25.0),
        restSeconds: const Constant(60),
      ));

  // 6. 初始化连续记录
  await db.into(db.streaks).insert(StreaksCompanion.insert(
        unitId: learningUnitId,
      ));

  await db.into(db.streaks).insert(StreaksCompanion.insert(
        unitId: workoutUnitId,
      ));
}
