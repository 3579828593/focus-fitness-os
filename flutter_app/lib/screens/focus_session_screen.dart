import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../theme/tokens.dart';
import '../providers/focus_session_notifier.dart';
import '../runners/session_state.dart';
import '../widgets/timer_display.dart';

/// 专注计时屏幕 (重构为 HookConsumerWidget)
///
/// 状态管理从手动 FocusRunner + Timer + TtsQueue + DB
/// 升级为 Riverpod NotifierProvider 模式:
/// - ref.watch(focusSessionNotifierProvider) 获取状态
/// - useEffect 触发 notifier.init(entryId)
/// - 按钮操作调用 notifier.toggleTimer() / complete() / abandon()
class FocusSessionScreen extends HookConsumerWidget {
  final int entryId;

  const FocusSessionScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(focusSessionNotifierProvider);
    final notifier = ref.read(focusSessionNotifierProvider.notifier);

    // 初始化: 进入屏幕时调用 init, 离开时清理 Timer
    useEffect(() {
      notifier.init(entryId);
      return () => notifier.cleanup();
    }, [entryId]);

    // 初始化中: 显示加载指示器
    if (!state.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('专注计时')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final runner = state.runner!;
    final currentSeg = runner.segments[runner.currentSegmentIndex];
    final isFocus = currentSeg.segType == SegmentType.focusBlock;
    final totalSegments = runner.segments.length;
    final progress = (runner.currentSegmentIndex + 1) / totalSegments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('专注计时'),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 阶段标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isFocus
                    ? AppColors.celadon.withValues(alpha: 0.12)
                    : AppColors.signal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Text(
                isFocus ? '专注中' : '休息中',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isFocus ? AppColors.celadon : AppColors.signal,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 倒计时圆环
            TimerDisplay(
              totalSeconds: currentSeg.plannedSeconds,
              remainingSeconds: state.remainingSeconds,
              color: isFocus ? AppColors.celadon : AppColors.signal,
            ),

            const SizedBox(height: AppSpacing.md),

            // 轮次进度
            Text(
              '第 ${runner.currentSegmentIndex ~/ 2 + 1} / ${runner.totalRounds} 轮',
              style: theme.textTheme.bodyLarge,
            ),

            const SizedBox(height: AppSpacing.sm),

            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: LinearProgressIndicator(value: progress),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!runner.isTerminal)
                  FilledButton.icon(
                    onPressed: notifier.toggleTimer,
                    icon: Icon(runner.state == SessionState.running
                        ? Icons.pause
                        : Icons.play_arrow),
                    label: Text(runner.state == SessionState.running
                        ? '暂停'
                        : runner.state == SessionState.paused
                            ? '恢复'
                            : '开始'),
                  ),
                if (!runner.isTerminal)
                  OutlinedButton.icon(
                    onPressed: notifier.complete,
                    icon: const Icon(Icons.check),
                    label: const Text('完成'),
                  ),
                if (runner.isTerminal)
                  FilledButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.done_all),
                    label: Text(
                      runner.state == SessionState.completed
                          ? '已完成'
                          : '已结束',
                    ),
                  ),
              ],
            ),

            // TTS 消息日志
            if (state.ttsMessages.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  reverse: true,
                  itemCount: state.ttsMessages.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.volume_up, size: 16),
                    title: Text(state.ttsMessages[i],
                        style: theme.textTheme.bodySmall),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
