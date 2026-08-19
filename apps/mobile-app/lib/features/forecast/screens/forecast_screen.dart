import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/utils/formatters.dart';

class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Prepare LineChart data points
    final actualPoints = MockData.mockForecastData
        .where((pt) => !pt.isPrediction)
        .map((pt) => FlSpot(pt.day.toDouble(), pt.amount))
        .toList();

    final predictedPoints = MockData.mockForecastData
        .where((pt) => pt.isPrediction || pt.day == 15) // overlay day 15 to connect
        .map((pt) => FlSpot(pt.day.toDouble(), pt.amount))
        .toList();

    // Mock AI Status from Backend
    final double readinessPercentage = 45.0; // Mock: 45% complete (< 30 days data)
    final String activeModel = 'rule_based'; // 'rule_based', 'arima_baseline', or 'lstm_network'
    
    final String subtitleLabel = activeModel == 'lstm_network' 
        ? '(Powered by Budgcoach AI)' 
        : '(Rule-Based Estimate)';
    
    final bool isCalibrating = readinessPercentage < 100.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Forecast'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Projected End-of-Month Spend',
                        style: AppTextStyles.labelSmall.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'NPR 27,800',
                        style: AppTextStyles.displayLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'vs Last Month: NPR 24,300 (↑ 14.5%)',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'No festival in June 2026',
                              style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Chart Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'June Spending Projection',
                    style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: activeModel == 'lstm_network' ? AppColors.primary : AppColors.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Line Chart Container
              Stack(
                alignment: Alignment.center,
                children: [
                  Card(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0, left: 10.0, top: 20.0, bottom: 10.0),
                  child: SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[250]!,
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (value) => FlLine(
                            color: Colors.grey[250]!,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: 5,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  'D${value.toInt()}',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 10000,
                              reservedSize: 45,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${(value / 1000).toInt()}k',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        minX: 1,
                        maxX: 30,
                        minY: 0,
                        maxY: 30000,
                        lineBarsData: [
                          // Actual Days 1-15 (Solid blue/green line)
                          LineChartBarData(
                            spots: actualPoints,
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withOpacity(0.08),
                            ),
                          ),
                          // Predicted Days 15-30 (Dashed orange line)
                          LineChartBarData(
                            spots: predictedPoints,
                            isCurved: true,
                            color: AppColors.secondary,
                            barWidth: 3.5,
                            dashArray: [6, 4],
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.secondary.withOpacity(0.04),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isCalibrating)
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: readinessPercentage / 100.0,
                                    strokeWidth: 8,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                                  ),
                                  Center(
                                    child: Text(
                                      '${readinessPercentage.toInt()}%',
                                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Calibrating AI...',
                              style: AppTextStyles.titleLarge.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Need more days of data to unlock LSTM.',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(color: AppColors.primary, label: 'Actual Spent (Days 1–15)'),
                  const SizedBox(width: 24),
                  _buildLegendItem(color: AppColors.secondary, label: 'Forecast (Days 16–30)', isDashed: true),
                ],
              ),
              const SizedBox(height: 24),

              // Category breakdown forecast
              Text(
                'Category Breakdown Forecast',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Category Forecast bars
              _buildCategoryForecastBar(
                categoryName: '🛍️ Shopping',
                actual: 4300,
                predicted: 5500,
                limit: 4000,
                alertText: 'Shopping is projected to exceed budget!',
                isExceeded: true,
              ),
              _buildCategoryForecastBar(
                categoryName: '🍜 Food & Dining',
                actual: 5200,
                predicted: 7200,
                limit: 8000,
              ),
              _buildCategoryForecastBar(
                categoryName: '🚌 Transport',
                actual: 2100,
                predicted: 2800,
                limit: 3000,
              ),
              _buildCategoryForecastBar(
                categoryName: '💡 Utilities',
                actual: 1200,
                predicted: 1900,
                limit: 2000,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label, bool isDashed = false}) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildCategoryForecastBar({
    required String categoryName,
    required double actual,
    required double predicted,
    required double limit,
    String? alertText,
    bool isExceeded = false,
  }) {
    final double maxVal = predicted > limit ? predicted : limit;
    final double actualRatio = actual / maxVal;
    final double predictedRatio = predicted / maxVal;
    final double limitRatio = limit / maxVal;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(categoryName, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  'Proj: ${Formatters.formatNpr(predicted)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isExceeded ? AppColors.danger : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Bar representation (Actual - solid, Forecast - lighter, Limit - dotted marker)
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Base Background
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                
                // Forecast (predicted) bar
                FractionallySizedBox(
                  widthFactor: predictedRatio.clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: isExceeded ? AppColors.danger.withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                // Actual bar
                FractionallySizedBox(
                  widthFactor: actualRatio.clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: isExceeded ? AppColors.danger : AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                // Limit marker
                Positioned(
                  left: (limitRatio * 200), // Visual rough mapping
                  child: Container(
                    width: 3,
                    height: 16,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Limit: ${Formatters.formatNpr(limit)}', style: AppTextStyles.labelSmall),
                Text('Actual: ${Formatters.formatNpr(actual)}', style: AppTextStyles.labelSmall),
              ],
            ),
            if (isExceeded && alertText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.danger, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    alertText,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
