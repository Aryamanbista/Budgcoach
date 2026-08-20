import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/nudge_model.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/nudges_provider.dart';

class NudgesScreen extends ConsumerWidget {
  const NudgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nudgesAsync = ref.watch(nudgesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts & Nudges'), elevation: 0),
      body: nudgesAsync.when(
        data: (nudges) => _NudgesContent(nudges: nudges),
        loading: () => const _NudgesLoadingState(),
        error: (error, _) => ErrorStateWidget(
          message: 'We could not refresh your personalized nudges.',
          onRetry: () => ref.read(nudgesProvider.notifier).fetchNudges(),
        ),
      ),
    );
  }
}

class _NudgesContent extends ConsumerWidget {
  final List<NudgeModel> nudges;

  const _NudgesContent({required this.nudges});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = nudges.where((nudge) => !nudge.isDismissed).toList();
    final history = nudges.where((nudge) => nudge.isDismissed).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(nudgesProvider.notifier).fetchNudges(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _CoachIntroCard(activeCount: active.length),
          const SizedBox(height: 24),
          Text(
            'For you now',
            style: AppTextStyles.titleLarge.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            'Calculated from your budgets, goals, and recent spending pattern.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            const _AllClearCard()
          else
            ...active.map(
              (nudge) => _NudgeCard(
                nudge: nudge,
                onDismiss: () =>
                    ref.read(nudgesProvider.notifier).dismissNudge(nudge.id),
                onAction: nudge.actionRoute == null
                    ? null
                    : () => _openAction(context, nudge.actionRoute!),
              ),
            ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Dismissed in the last 30 days',
              style: AppTextStyles.titleLarge.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < history.length; index++) ...[
                    _HistoryTile(nudge: history[index]),
                    if (index < history.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openAction(BuildContext context, String route) {
    if (route.startsWith('/home/')) {
      context.go(route);
    } else {
      context.push(route);
    }
  }
}

class _CoachIntroCard extends StatelessWidget {
  final int activeCount;

  const _CoachIntroCard({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your personal budget coach',
                  style: AppTextStyles.titleLarge.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  activeCount == 1
                      ? '1 timely insight is ready for you.'
                      : '$activeCount timely insights are ready for you.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NudgeCard extends StatelessWidget {
  final NudgeModel nudge;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;

  const _NudgeCard({
    required this.nudge,
    required this.onDismiss,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(nudge.severity);
    final icon = _severityIcon(nudge.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nudge.title,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            nudge.description,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          if (onAction != null &&
                              nudge.actionLabel != null) ...[
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: onAction,
                              style: TextButton.styleFrom(
                                foregroundColor: color,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: Text(nudge.actionLabel!),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            _relativeTime(nudge.date),
                            style: AppTextStyles.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss nudge',
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final NudgeModel nudge;

  const _HistoryTile({required this.nudge});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(nudge.severity);
    return ListTile(
      leading: Icon(_severityIcon(nudge.severity), color: color),
      title: Text(
        nudge.title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        nudge.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.labelSmall,
      ),
      trailing: Text(
        DateFormat('dd MMM').format(nudge.date),
        style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              'All clear',
              style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'No active insight needs your attention right now.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NudgesLoadingState extends StatelessWidget {
  const _NudgesLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerLoader(width: double.infinity, height: 100),
        SizedBox(height: 24),
        ShimmerLoader(width: double.infinity, height: 155),
        SizedBox(height: 12),
        ShimmerLoader(width: double.infinity, height: 155),
      ],
    );
  }
}

Color _severityColor(NudgeSeverity severity) {
  switch (severity) {
    case NudgeSeverity.critical:
      return AppColors.danger;
    case NudgeSeverity.warning:
      return AppColors.secondary;
    case NudgeSeverity.success:
      return AppColors.success;
    case NudgeSeverity.info:
      return AppColors.primary;
  }
}

IconData _severityIcon(NudgeSeverity severity) {
  switch (severity) {
    case NudgeSeverity.critical:
      return Icons.error_outline;
    case NudgeSeverity.warning:
      return Icons.warning_amber_rounded;
    case NudgeSeverity.success:
      return Icons.trending_down;
    case NudgeSeverity.info:
      return Icons.lightbulb_outline;
  }
}

String _relativeTime(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 2) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  if (difference.inDays == 1) return 'Yesterday';
  return '${difference.inDays} days ago';
}
