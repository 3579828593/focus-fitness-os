import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../data/daos/daos.dart';
import '../data/tables.dart';
import '../data/database.dart';
import '../repositories/providers.dart';

/// 今日日期字符串
final todayProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
});

/// 今日日程 Stream Provider
/// 通过 SessionRepository 访问数据, 不再直接操作 ScheduleDao
final todayScheduleProvider = StreamProvider<List<ScheduleEntry>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  final date = ref.watch(todayProvider);
  return repo.watchSchedule(date);
});

/// 活跃目标 Provider
final activeGoalsProvider = FutureProvider<List>((ref) async {
  final db = ref.watch(databaseProvider);
  final dao = GoalDao(db);
  return dao.getActiveGoals();
});

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final scheduleAsync = ref.watch(todayScheduleProvider);
    final goalsAsync = ref.watch(activeGoalsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('专注健身OS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outline),
            onPressed: () => context.push('/proposals'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 日期卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MM月dd日 EEEE', 'zh_CN').format(DateTime.now()),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  scheduleAsync.when(
                    data: (entries) => Text(
                      '今日 ${entries.length} 项安排',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    loading: () => const Text('加载中...'),
                    error: (_, __) => const Text('暂无数据'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 快速导航
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.calendar_today,
                  label: '今日日程',
                  color: Colors.blue.shade100,
                  onTap: () => context.push('/schedule/$today'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.lightbulb_outline,
                  label: '待确认提案',
                  color: Colors.amber.shade100,
                  onTap: () => context.push('/proposals'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 目标进度
          Text('目标进度', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          goalsAsync.when(
            data: (goals) => goals.isEmpty
                ? const Card(
                    child: ListTile(
                      leading: Icon(Icons.flag_outlined),
                      title: Text('暂无目标'),
                    ),
                  )
                : Column(
                    children: goals.map((g) {
                      final pct = g.targetValue > 0
                          ? (g.currentValue / g.targetValue).clamp(0.0, 1.0)
                          : 0.0;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.track_changes),
                          title: Text(g.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(value: pct),
                              const SizedBox(height: 4),
                              Text(
                                '${g.currentValue.toStringAsFixed(0)} / ${g.targetValue.toStringAsFixed(0)} ${g.unit}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: Text('${(pct * 100).toInt()}%'),
                        ),
                      );
                    }).toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('加载失败'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/schedule/$today'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
