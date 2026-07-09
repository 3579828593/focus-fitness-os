import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../data/daos/daos.dart';
import '../theme/tokens.dart';

/// ============================================================
/// ProposalScreen: LOCKED 提案确认页 (HITL 人机回环)
/// 展示 Node-RED 生成的待确认提案, 用户可接受/拒绝
/// Node-RED 不可用时显示离线状态 + 本地降级提示
/// nodeRedApiProvider 使用 main.dart 中的全局定义, 避免重复配置
/// ============================================================

/// 待确认提案 FutureProvider
final proposalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(nodeRedApiProvider);
  try {
    return await api.getProposals(status: 'LOCKED');
  } catch (e) {
    // 抛出异常, 由 UI 层处理离线状态
    throw Exception('Node-RED 不可达: $e');
  }
});

class ProposalScreen extends HookConsumerWidget {
  const ProposalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(proposalsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待确认提案'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(proposalsProvider),
            tooltip: '刷新',
          ),
        ],
      ),
      body: proposalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _OfflineView(
          theme: theme,
          onRetry: () => ref.refresh(proposalsProvider),
        ),
        data: (proposals) {
          if (proposals.isEmpty) {
            return _EmptyView(theme: theme);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: proposals.length,
            itemBuilder: (context, index) {
              final proposal = proposals[index];
              return _ProposalCard(
                proposal: proposal,
                theme: theme,
                onAccept: () async {
                  final api = ref.read(nodeRedApiProvider);
                  final proposalId = proposal['proposal_id'] as int? ??
                      proposal['id'] as int? ??
                      0;
                  try {
                    await api.acceptProposal(proposalId);
                    // 记录 OpLog 操作日志 (接受提案)
                    final db = ref.read(databaseProvider);
                    final opLogDao = OpLogDao(db);
                    await opLogDao.logOperation(
                      tableName: 'proposals',
                      recordId: proposalId,
                      opType: 'UPDATE',
                      payload: {'action': 'accept', 'proposal_id': proposalId},
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('提案 #$proposalId 已接受'),
                          backgroundColor: AppColors.celadon,
                        ),
                      );
                    }
                    ref.invalidate(proposalsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('操作失败: $e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  }
                },
                onReject: () async {
                  final api = ref.read(nodeRedApiProvider);
                  final proposalId = proposal['proposal_id'] as int? ??
                      proposal['id'] as int? ??
                      0;
                  try {
                    await api.rejectProposal(proposalId);
                    // 记录 OpLog 操作日志 (拒绝提案)
                    final db = ref.read(databaseProvider);
                    final opLogDao = OpLogDao(db);
                    await opLogDao.logOperation(
                      tableName: 'proposals',
                      recordId: proposalId,
                      opType: 'UPDATE',
                      payload: {'action': 'reject', 'proposal_id': proposalId},
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('提案 #$proposalId 已拒绝'),
                          backgroundColor: AppColors.accent,
                        ),
                      );
                    }
                    ref.invalidate(proposalsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('操作失败: $e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// ============================================================
/// 提案卡片
/// ============================================================

class _ProposalCard extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final ThemeData theme;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ProposalCard({
    required this.proposal,
    required this.theme,
    required this.onAccept,
    required this.onReject,
  });

  /// 提案类型图标
  IconData get _typeIcon {
    final type = proposal['type'] as String? ?? '';
    switch (type) {
      case 'WEIGHT_INCREMENT':
        return Icons.fitness_center;
      case 'WEIGHT_DECREMENT':
        return Icons.trending_down;
      case 'SCHEDULE_CONFLICT':
        return Icons.schedule;
      case 'DAILY_REMINDER':
        return Icons.notifications;
      default:
        return Icons.lightbulb;
    }
  }

  /// 提案类型颜色
  Color get _typeColor {
    final type = proposal['type'] as String? ?? '';
    switch (type) {
      case 'WEIGHT_INCREMENT':
        return AppColors.celadon;
      case 'WEIGHT_DECREMENT':
        return AppColors.accent;
      case 'SCHEDULE_CONFLICT':
        return AppColors.danger;
      case 'DAILY_REMINDER':
        return AppColors.signal;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = proposal['type'] as String? ?? '未知';
    final title = proposal['title'] as String? ?? '未命名提案';
    final description = proposal['description'] as String? ??
        proposal['reason'] as String? ??
        '无描述';
    final createdAt = proposal['created_at'] as String? ?? '';
    final payload = proposal['payload'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部: 图标 + 类型标签 + LOCKED 徽章
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        type,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // LOCKED 徽章
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 12, color: AppColors.inkSoftDark),
                      const SizedBox(width: 4),
                      Text(
                        '待确认',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.inkSoftDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // 描述
            Text(description, style: theme.textTheme.bodyMedium),

            // 载荷详情 (如果有)
            if (payload != null && payload.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: payload.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e.key}: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${e.value}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '生成时间: $createdAt',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('拒绝'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('接受'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// 空状态视图
/// ============================================================

class _EmptyView extends StatelessWidget {
  final ThemeData theme;
  const _EmptyView({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '没有待确认的提案',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Node-RED 规则引擎当前没有生成需要人工确认的操作',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// 离线状态视图 (Node-RED 不可达)
/// ============================================================

class _OfflineView extends StatelessWidget {
  final ThemeData theme;
  final VoidCallback onRetry;
  const _OfflineView({required this.theme, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: AppColors.accent.withValues(alpha: 0.5),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_off,
                      size: 20,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Node-RED 离线',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '无法连接到规则引擎服务\n提案确认功能暂不可用\n\n本地降级规则仍在运行:\n'
              '• 训练完成 → 本地渐进超负荷 (+2.5kg / -2.5kg)\n'
              '• 日程变更 → 本地冲突检测 (时间比对)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试连接'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }
}
