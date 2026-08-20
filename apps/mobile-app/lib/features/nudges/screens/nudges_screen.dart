import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/nudges_provider.dart';
import '../../../shared/models/nudge_model.dart';

class NudgesScreen extends ConsumerStatefulWidget {
  const NudgesScreen({super.key});

  @override
  ConsumerState<NudgesScreen> createState() => _NudgesScreenState();
}

class _NudgesScreenState extends ConsumerState<NudgesScreen> {
  bool _enableNotifications = true;
  double _warningThreshold = 0.80;
  double _criticalThreshold = 0.95;

  @override
  Widget build(BuildContext context) {
    final allNudges = ref.watch(nudgesProvider);

    final activeNudges = allNudges.where((n) => !n.isDismissed).toList();
    final historicalNudges = allNudges.where((n) => n.isDismissed).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts & Nudges'), elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Nudges Title
              Text(
                'Active Nudges',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),

              if (activeNudges.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'All clear! No active warnings.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...activeNudges.map((nudge) => _buildNudgeCard(nudge)),

              const SizedBox(height: 24),

              // Historical Nudges Title
              Text(
                'Nudge History (Past 30 Days)',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),

              if (historicalNudges.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No historical logs.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: historicalNudges.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final nudge = historicalNudges[index];
                      return ListTile(
                        leading: Text(
                          nudge.severity == NudgeSeverity.critical
                              ? '🚨'
                              : '⚠️',
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(
                          nudge.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          nudge.description,
                          style: AppTextStyles.labelSmall,
                        ),
                        trailing: Text(
                          DateFormat('dd MMM').format(nudge.date),
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),

              // Notification Settings
              Text(
                'Nudge Configuration',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        title: Text(
                          'Enable Push Notifications',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'Get notified immediately when budget limits approach overspend.',
                        ),
                        value: _enableNotifications,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _enableNotifications = val;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Warning Notification Threshold',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(_warningThreshold * 100).toInt()}%',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _warningThreshold,
                        min: 0.50,
                        max: 0.90,
                        activeColor: AppColors.secondary,
                        inactiveColor: AppColors.secondary.withOpacity(0.2),
                        onChanged: _enableNotifications
                            ? (val) {
                                setState(() {
                                  _warningThreshold = val;
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Critical Notification Threshold',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(_criticalThreshold * 100).toInt()}%',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _criticalThreshold,
                        min: 0.85,
                        max: 1.0,
                        activeColor: AppColors.danger,
                        inactiveColor: AppColors.danger.withOpacity(0.2),
                        onChanged: _enableNotifications
                            ? (val) {
                                setState(() {
                                  _criticalThreshold = val;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNudgeCard(NudgeModel nudge) {
    final isCritical = nudge.severity == NudgeSeverity.critical;
    final borderColor = isCritical ? AppColors.danger : AppColors.secondary;
    final icon = isCritical ? '🚨' : '⚠️';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored Left Border strip
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 24)),
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
                          const SizedBox(height: 4),
                          Text(
                            nudge.description,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatRelativeTime(nudge.date),
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        ref
                            .read(nudgesProvider.notifier)
                            .dismissNudge(nudge.id);
                      },
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

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) {
      return 'Just now';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return 'Yesterday';
    }
  }
}
