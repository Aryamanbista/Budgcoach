import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class HealthScoreBadge extends StatelessWidget {
  final int score;
  final VoidCallback onTap;

  const HealthScoreBadge({super.key, required this.score, required this.onTap});

  Color _getScoreColor(int val) {
    if (val >= 80) return AppColors.success;
    if (val >= 60) return AppColors.secondary;
    return AppColors.danger;
  }

  String _getScoreLabel(int val) {
    if (val >= 80) return 'Excellent';
    if (val >= 65) return 'Good';
    if (val >= 50) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 4.5,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text(
                  '$score',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Health Score',
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                ),
                Text(
                  _getScoreLabel(score),
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
