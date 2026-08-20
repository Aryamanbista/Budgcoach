import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class OcrProgressStepper extends StatefulWidget {
  final Future<int> processingFuture;

  const OcrProgressStepper({super.key, required this.processingFuture});

  @override
  State<OcrProgressStepper> createState() => _OcrProgressStepperState();
}

class _OcrProgressStepperState extends State<OcrProgressStepper> {
  int _currentStep = 0; // 0: uploading, 1: extracting, 2: categorizing, 3: done

  int? _transactionCount;

  @override
  void initState() {
    super.initState();
    _startStepping();
  }

  void _startStepping() {
    // Step 1: Uploading statement -> 1s delay
    Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _currentStep = 1);
    });

    // Step 2: OCR Extracting -> 2s delay total
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _currentStep = 2);
    });

    // Wait for the backend processing to finish
    widget.processingFuture
        .then((count) {
          if (mounted) {
            setState(() {
              _currentStep = 3;
              _transactionCount = count;
            });
            // Auto dismiss after a short success delay
            Timer(const Duration(milliseconds: 1500), () {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }
        })
        .catchError((e) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Processing Statement',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildStepRow(index: 0, label: 'Uploading statement...'),
            const SizedBox(height: 16),
            _buildStepRow(
              index: 1,
              label: 'Extracting transactions with OCR...',
            ),
            const SizedBox(height: 16),
            _buildStepRow(index: 2, label: 'Categorizing with AI...'),
            const SizedBox(height: 16),
            _buildStepRow(
              index: 3,
              label: _transactionCount != null
                  ? 'Done! $_transactionCount transactions found'
                  : 'Finalizing extraction...',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({required int index, required String label}) {
    final isDone = _currentStep > index;
    final isActive = _currentStep == index;

    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: isDone
              ? const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 24,
                )
              : isActive
              ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                )
              : const Icon(Icons.circle_outlined, color: Colors.grey, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: isActive || isDone
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: isDone
                  ? AppColors.primary
                  : isActive
                  ? Theme.of(context).colorScheme.onBackground
                  : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
