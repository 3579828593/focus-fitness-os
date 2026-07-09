import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../theme/tokens.dart';
import '../data/database.dart';
import '../data/daos/daos.dart';
import '../data/tables.dart';

/// 指定日期的日程 Stream
final scheduleByDateProvider =
    StreamProvider.family<List, String>((ref, date) {
  final db = ref.watch(databaseProvider);
  return ScheduleDao(db).watchByDate(date);
});

/// 执行单元缓存 (按 unitId 查 title)
final unitTitleProvider =
    FutureProvider.family<String, int>((ref, unitId) async {
  final db = ref.watch(databaseProvider);
  final dao = UnitDao(db);
  final units = await dao.getActiveUnits();
  return units.where((u) => u.id == unitId).firstOrNull?.title ?? '未知';
});

class ScheduleScreen extends HookConsumerWidget {
  final String date;

  const ScheduleScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleByDateProvider(date));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('$date 日程')),
      body: scheduleAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: AppSpacing.md),
                  Text('今日暂无安排',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => _showAddSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('添加日程'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index] as ScheduleEntry;
              final isWorkout = entry.execMode == 'WORKOUT';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isWorkout
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.celadon.withValues(alpha: 0.12),
                    child: Icon(
                      isWorkout ? Icons.fitness_center : Icons.menu_book,
                      color: isWorkout ? AppColors.accent : AppColors.celadon,
                    ),
                  ),
                  title: Text(entry.startTime),
                  subtitle: Text(isWorkout ? '健身训练' : '专注学习'),
                  trailing: entry.lockState == 'LOCKED'
                      ? Chip(
                          label: const Text('锁定'),
                          backgroundColor: AppColors.brass.withValues(alpha: 0.12),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    final path = isWorkout
                        ? '/session/workout/${entry.entryId}'
                        : '/session/focus/${entry.entryId}';
                    context.push(path);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book, color: AppColors.celadon),
              title: const Text('添加学习任务'),
              onTap: () async {
                final db = ref.read(databaseProvider);
                final dao = UnitDao(db);
                final unitId = await dao.createLearningUnit(
                  title: '专注学习',
                  priority: 2,
                  expectedMinutes: 50,
                  taskKind: 'READING',
                );
                await ScheduleDao(db).createScheduleEntry(
                  ScheduleEntriesCompanion.insert(
                    unitId: unitId,
                    date: date,
                    startTime: '09:00',
                    execMode: 'FOCUS',
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.fitness_center, color: AppColors.accent),
              title: const Text('添加健身计划'),
              onTap: () async {
                final db = ref.read(databaseProvider);
                final dao = UnitDao(db);
                final unitId = await dao.createWorkoutUnit(
                  title: '推日训练',
                  priority: 1,
                  expectedMinutes: 60,
                  workoutKind: 'PUSH',
                  targetMuscle: '胸/肩/三头',
                );
                await dao.addExercise(
                  unitId: unitId,
                  name: '杠铃卧推',
                  plannedSets: 4,
                  plannedReps: 8,
                  plannedWeight: 60.0,
                );
                await ScheduleDao(db).createScheduleEntry(
                  ScheduleEntriesCompanion.insert(
                    unitId: unitId,
                    date: date,
                    startTime: '18:00',
                    execMode: 'WORKOUT',
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
