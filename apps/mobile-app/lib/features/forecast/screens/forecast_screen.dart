import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/forecast_provider.dart';

class ForecastScreen extends ConsumerWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spending Forecast'), elevation: 0),
      body: forecastAsync.when(
        data: (forecast) => RefreshIndicator(
          onRefresh: () => ref.read(forecastProvider.notifier).fetchForecast(),
          child: _ForecastContent(forecast: forecast),
        ),
        loading: () => const _ForecastLoadingState(),
        error: (error, _) => ErrorStateWidget(
          message:
              'We could not load your forecast. Check your connection and try again.',
          onRetry: () => ref.read(forecastProvider.notifier).fetchForecast(),
        ),
      ),
    );
  }
}

class _ForecastContent extends StatelessWidget {
  final ForecastData forecast;

  const _ForecastContent({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);
    final hasChartData =
        forecast.actualPoints.isNotEmpty || forecast.predictedPoints.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(forecast: forecast),
        const SizedBox(height: 16),
        _LearningCard(status: forecast.aiStatus),
        if (forecast.upcomingFestivals.isNotEmpty) ...[
          const SizedBox(height: 16),
          _FestivalCard(festival: forecast.upcomingFestivals.first),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$monthLabel projection',
              style: AppTextStyles.titleLarge.copyWith(fontSize: 17),
            ),
            _ModelBadge(label: forecast.aiStatus.modelLabel),
          ],
        ),
        const SizedBox(height: 12),
        if (hasChartData)
          _ForecastChart(forecast: forecast)
        else
          const _EmptyForecastCard(),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: AppColors.primary, label: 'Actual spend'),
            SizedBox(width: 24),
            _Legend(
              color: AppColors.secondary,
              label: 'Projected spend',
              dashed: true,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _BudgetOutlookCard(forecast: forecast),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ForecastData forecast;

  const _SummaryCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final hasBudget = forecast.totalBudget > 0;
    final message = forecast.budgetBreachWarning
        ? forecast.daysUntilBreach > 0
              ? 'At this pace, your budget may be reached in ${forecast.daysUntilBreach} days.'
              : 'This projection is above your monthly budget.'
        : hasBudget
        ? '${Formatters.formatNpr(forecast.remainingBudget)} remains in this month\'s budget.'
        : 'Set category budgets to enable breach alerts.';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projected end-of-month spend',
              style: AppTextStyles.labelSmall.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              Formatters.formatNpr(forecast.predictedSpend),
              style: AppTextStyles.displayLarge.copyWith(
                color: forecast.budgetBreachWarning
                    ? AppColors.danger
                    : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Spent so far: ${Formatters.formatNpr(forecast.currentMonthSpend)}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  forecast.budgetBreachWarning
                      ? Icons.warning_amber_rounded
                      : Icons.insights_outlined,
                  size: 18,
                  color: forecast.budgetBreachWarning
                      ? AppColors.danger
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: forecast.budgetBreachWarning
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningCard extends StatelessWidget {
  final ForecastAiStatus status;

  const _LearningCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final progress = status.modelReadiness;
    final isLearning = status.isLearning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLearning ? Icons.psychology_outlined : Icons.auto_awesome,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLearning
                          ? 'Budgcoach is learning about you'
                          : 'Your personal forecast is ready',
                      style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${status.modelDaysLogged} of ${status.modelRequiredDays} days available for personal AI',
                      style: AppTextStyles.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.coverageLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: status.coverageStatus == 'verified'
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(status.modelReadiness * 100).round()}%',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            status.learningMessage,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FestivalCard extends StatelessWidget {
  final ForecastFestival festival;

  const _FestivalCard({required this.festival});

  @override
  Widget build(BuildContext context) {
    final days = festival.date.difference(DateTime.now()).inDays + 1;
    return Card(
      color: AppColors.secondary.withValues(alpha: 0.08),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.celebration_outlined)),
        title: Text('${festival.name} spending window'),
        subtitle: Text(
          days > 0
              ? 'Begins in $days days. Your projection includes a personalized festival adjustment.'
              : 'Your projection includes a personalized festival adjustment.',
        ),
        trailing: festival.isMajor ? const Chip(label: Text('Major')) : null,
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  final ForecastData forecast;

  const _ForecastChart({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final actual = forecast.actualPoints.entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
    final predicted = forecast.predictedPoints.entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
    final values = [...actual, ...predicted].map((point) => point.y);
    final highest = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final maxY = highest <= 0 ? 1000.0 : highest * 1.18;
    final daysInMonth = DateUtils.getDaysInMonth(
      DateTime.now().year,
      DateTime.now().month,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 20, 12),
        child: SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minX: 1,
              maxX: daysInMonth.toDouble(),
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.14),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5,
                    reservedSize: 24,
                    getTitlesWidget: (value, _) => Text(
                      '${value.toInt()}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: maxY / 4,
                    getTitlesWidget: (value, _) => Text(
                      value >= 1000
                          ? '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k'
                          : value.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              lineBarsData: [
                if (actual.isNotEmpty)
                  LineChartBarData(
                    spots: actual,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                if (predicted.isNotEmpty)
                  LineChartBarData(
                    spots: predicted,
                    isCurved: true,
                    color: AppColors.secondary,
                    barWidth: 3,
                    dashArray: [7, 5],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetOutlookCard extends StatelessWidget {
  final ForecastData forecast;

  const _BudgetOutlookCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final hasBudget = forecast.totalBudget > 0;
    final ratio = hasBudget
        ? (forecast.predictedSpend / forecast.totalBudget).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget outlook',
              style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (!hasBudget)
              Text(
                'No budget is set for this month. Your spending forecast will still update as transactions arrive.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else ...[
              LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  forecast.budgetBreachWarning
                      ? AppColors.danger
                      : AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Projected ${Formatters.formatNpr(forecast.predictedSpend)}',
                  ),
                  Text('Budget ${Formatters.formatNpr(forecast.totalBudget)}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelBadge extends StatelessWidget {
  final String label;

  const _ModelBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: dashed ? 3 : 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

class _EmptyForecastCard extends StatelessWidget {
  const _EmptyForecastCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            const Icon(
              Icons.upload_file_outlined,
              size: 44,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your transaction history',
              style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload your latest statement to create your first personal spending baseline.',
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

class _ForecastLoadingState extends StatelessWidget {
  const _ForecastLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerLoader(width: double.infinity, height: 170),
        SizedBox(height: 16),
        ShimmerLoader(width: double.infinity, height: 150),
        SizedBox(height: 24),
        ShimmerLoader(width: double.infinity, height: 260),
      ],
    );
  }
}
