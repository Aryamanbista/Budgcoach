import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/mock/mock_data.dart';

class HealthScoreScreen extends StatelessWidget {
  const HealthScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const score = MockData.healthScoreValue;
    const subScores = MockData.healthSubScores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Health Score'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Score Arc Gauge
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CustomPaint(
                          painter: ScoreArcPainter(score: score),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 12),
                                Text(
                                  '$score',
                                  style: AppTextStyles.displayLarge.copyWith(
                                    fontSize: 54,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Good',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your score is calculated based on last 30 days',
                        style: AppTextStyles.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sub-score breakdown title
              Text(
                'Breakdown Analysis',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),

              // 2x2 Grid Sub-Score Cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildSubScoreCard(
                    icon: Icons.assignment_outlined,
                    label: 'Budget Adherence',
                    value: subScores['budgetAdherence']!,
                    color: AppColors.secondary,
                  ),
                  _buildSubScoreCard(
                    icon: Icons.savings_outlined,
                    label: 'Savings Rate',
                    value: subScores['savingsRate']!,
                    color: AppColors.danger,
                  ),
                  _buildSubScoreCard(
                    icon: Icons.trending_up,
                    label: 'Spending Consistency',
                    value: subScores['consistency']!,
                    color: AppColors.success,
                  ),
                  _buildSubScoreCard(
                    icon: Icons.pie_chart_outline,
                    label: 'Category Diversity',
                    value: subScores['diversity']!,
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Personalized Recommendations list
              Text(
                'Personalized Coach Tips',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),

              _buildCoachTipCard(
                icon: '💡',
                message: 'Your savings rate is below average (55%). Try automating NPR 2,000/month to savings.',
              ),
              _buildCoachTipCard(
                icon: '⚠️',
                message: 'Budget adherence dropped due to Shopping overspend. Consider reducing Daraz/Shopping limits by NPR 500 next month.',
              ),
              _buildCoachTipCard(
                icon: '✅',
                message: 'Outstanding spending consistency! Daily cash flow is extremely stable compared to previous months.',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubScoreCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  '$value%',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: value / 100.0,
                    minHeight: 4,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachTipCard({required String icon, required String message}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreArcPainter extends CustomPainter {
  final int score;

  ScoreArcPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8;
    
    const double startAngle = pi * 0.75;
    const double sweepAngle = pi * 1.5;

    // Track arc paint
    final trackPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Active arc gradient color (red -> orange -> green)
    final double scoreRatio = score / 100.0;
    final activeSweepAngle = sweepAngle * scoreRatio;
    
    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          AppColors.danger,
          AppColors.secondary,
          AppColors.success,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
