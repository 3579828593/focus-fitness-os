import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../theme/tokens.dart';
import '../providers/workout_session_notifier.dart';
import '../runners/session_state.dart';
import '../widgets/timer_display.dart';

/// 健身训练屏幕 (重构为 HookConsumerWidget)
///
/// 状态管理从手动 WorkoutRunner + Timer + TtsQueue + DB + NodeRedApi
/// 升级为 Riverpod NotifierProvider 模式:
/// - ref.watch(workoutSessionNotifierProvider) 获取状态
/// - useEffect 触发 notifier.init(entryId)
/// - reps/weight TextController 使用 useTextEditingController 本地管理
/// - rpe 从 notifier state 读取
/// - 按钮操作调用 notifier.completeSet() / confirmNextExercise() / skipRest() / abandon()
class WorkoutSessionScreen extends HookConsumerWidget {
  final int entryId;

  const WorkoutSessionScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(workoutSessionNotifierProvider);
    final notifier = ref.read(workoutSessionNotifierProvider.notifier);

    // reps / weight 输入框本地管理 (使用 hooks)
    final repsController = useTextEditingController();
    final weightController = useTextEditingController();

    // 初始化: 进入屏幕时调用 init, 离开时清理 Timer
    useEffect(() {
      notifier.init(entryId).then((_) {
        // 预填默认值 (当前动作的计划次数和重量)
        final runner = ref.read(workoutSessionNotifierProvider).runner;
        if (runner?.currentExercise != null) {
          repsController.text =
              runner!.currentExercise!.plannedReps.toString();
          weightController.text =
              runner.currentExercise!.plannedWeight.toString();
        }
      }).catchError((e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
          context.pop();
        }
      });
      return () => notifier.cleanup();
    }, [entryId]);

    // 初始化中: 显示加载指示器
    if (!state.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('健身训练')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final runner = state.runner!;
    final exercise = runner.currentExercise;

    return Scaffold(
      appBar: AppBar(
        title: const Text('健身训练'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (!runner.isTerminal) {
              notifier.abandon();
            } else {
              notifier.cleanup();
            }
            context.pop();
          },
        ),
      ),
      body: state.isDone
          ? _buildSummary(context, runner, theme)
          : state.isResting
              ? _buildRestView(runner, state.remainingSeconds, notifier, theme)
              : state.isWaitingConfirm
                  ? _buildConfirmView(runner, notifier, repsController,
                      weightController, theme)
                  : _buildSetInputView(runner, exercise!, state.rpe,
                      repsController, weightController, notifier, theme),
    );
  }

  /// 组录入视图: 动作名称 + 次数/重量/RPE 录入
  Widget _buildSetInputView(
    WorkoutRunner runner,
    ExerciseData exercise,
    double rpe,
    TextEditingController repsController,
    TextEditingController weightController,
    WorkoutSessionNotifier notifier,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 动作名称
            Text(exercise.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '第 ${runner.currentSetInExercise} / ${exercise.plannedSets} 组',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 次数录入
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '完成次数',
                border: OutlineInputBorder(),
                suffixText: '次',
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // 重量录入
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '重量',
                border: OutlineInputBorder(),
                suffixText: 'kg',
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // RPE 滑块 (从 notifier state 读取)
            Row(
              children: [
                const Text('RPE'),
                Expanded(
                  child: Slider(
                    value: rpe,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: rpe.toStringAsFixed(0),
                    onChanged: (v) => notifier.updateRpe(v),
                  ),
                ),
                Text(rpe.toStringAsFixed(0)),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            FilledButton.icon(
              onPressed: () {
                final reps = int.tryParse(repsController.text) ?? 0;
                final weight = double.tryParse(weightController.text) ?? 0.0;
                notifier.completeSet(reps, weight, rpe);
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('完成本组'),
            ),
          ],
        ),
      ),
    );
  }

  /// 休息视图: 倒计时 + 跳过休息
  Widget _buildRestView(
    WorkoutRunner runner,
    int remainingSeconds,
    WorkoutSessionNotifier notifier,
    ThemeData theme,
  ) {
    final currentSeg = runner.segments[runner.currentSegmentIndex];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('休息中', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          TimerDisplay(
            totalSeconds: currentSeg.plannedSeconds,
            remainingSeconds: remainingSeconds,
            color: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (remainingSeconds <= 0)
            FilledButton.icon(
              onPressed: () {
                // 手动推进到下一组
                notifier.skipRest();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始下一组'),
            )
          else
            OutlinedButton(
              onPressed: notifier.skipRest,
              child: const Text('跳过休息'),
            ),
        ],
      ),
    );
  }

  /// 确认下一动作视图
  Widget _buildConfirmView(
    WorkoutRunner runner,
    WorkoutSessionNotifier notifier,
    TextEditingController repsController,
    TextEditingController weightController,
    ThemeData theme,
  ) {
    final next = runner.currentExercise;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('下一个动作', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              next?.name ?? '未知',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${next?.plannedSets ?? 0}组 × ${next?.plannedReps ?? 0}次',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () {
                notifier.confirmNextExercise();
                // 确认后预填新动作的默认值
                if (runner.currentExercise != null) {
                  repsController.text =
                      runner.currentExercise!.plannedReps.toString();
                  weightController.text =
                      runner.currentExercise!.plannedWeight.toString();
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('确认开始'),
            ),
          ],
        ),
      ),
    );
  }

  /// 训练总结视图
  Widget _buildSummary(
      BuildContext context, WorkoutRunner runner, ThemeData theme) {
    final totalSets = runner.segments
        .where((s) => s.segType == SegmentType.workoutSet && s.repsDone! > 0)
        .length;
    final totalVolume = runner.segments
        .where((s) => s.segType == SegmentType.workoutSet)
        .fold<double>(
            0, (sum, s) => sum + (s.repsDone ?? 0) * (s.weightKgDone ?? 0));
    final ratio = runner.completionRatio;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              runner.state == SessionState.completed
                  ? Icons.emoji_events
                  : Icons.stop_circle,
              size: 64,
              color: runner.state == SessionState.completed
                  ? AppColors.brass
                  : AppColors.inkSoftDark,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              runner.state == SessionState.completed ? '训练完成！' : '训练结束',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SummaryRow(label: '完成组数', value: '$totalSets 组'),
            _SummaryRow(
                label: '总训练量', value: '${totalVolume.toStringAsFixed(1)} kg'),
            _SummaryRow(label: '完成率', value: '${(ratio * 100).toInt()}%'),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
