import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../widgets/ocr_progress_stepper.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String _selectedPlatform = 'eSewa';
  String? _selectedFileName;
  String? _selectedFileSize;
  bool _isFileSelected = false;

  final List<String> _platforms = [
    'eSewa',
    'Khalti',
    'Nabil Bank',
    'Sunrise Bank',
    'Himalayan Bank',
  ];

  void _pickMockFile() {
    setState(() {
      _selectedFileName = 'statement_june_2026_${_selectedPlatform.toLowerCase().replaceAll(' ', '_')}.pdf';
      _selectedFileSize = '245 KB';
      _isFileSelected = true;
    });
  }

  void _clearFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileSize = null;
      _isFileSelected = false;
    });
  }

  void _processStatement() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OcrProgressStepper(
        onCompleted: () {
          Navigator.of(context).pop(); // Dismiss stepper dialog
          context.push('/upload/review'); // Navigate to review screen
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Statement'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Platform Selector Title
            Text(
              'Select Platform',
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Platform Selector Horizontal Row
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _platforms.length,
                itemBuilder: (context, index) {
                  final platform = _platforms[index];
                  final isSelected = _selectedPlatform == platform;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(platform),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedPlatform = platform;
                            // Update file name if already selected
                            if (_isFileSelected) {
                              _selectedFileName = 'statement_june_2026_${platform.toLowerCase().replaceAll(' ', '_')}.pdf';
                            }
                          });
                        }
                      },
                      selectedColor: AppColors.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Upload Area
            Expanded(
              child: InkWell(
                onTap: _isFileSelected ? null : _pickMockFile,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.4),
                      style: BorderStyle.solid, // Simple dashed simulation
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isFileSelected) ...[
                          const Icon(
                            Icons.upload_file,
                            size: 64,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to select PDF or image',
                            style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supported formats: PDF, JPG, PNG',
                            style: AppTextStyles.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _pickMockFile,
                            child: const Text('Or take a photo'),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.picture_as_pdf,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFileName ?? '',
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFileSize ?? '',
                            style: AppTextStyles.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: _clearFile,
                            icon: const Icon(Icons.delete, color: AppColors.danger),
                            label: const Text('Remove', style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Process Statement Button
            ElevatedButton(
              onPressed: _isFileSelected ? _processStatement : null,
              child: const Text('Process Statement'),
            ),
            const SizedBox(height: 16),

            // Info Card at Bottom
            Card(
              elevation: 0,
              color: AppColors.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Supported formats: eSewa PDF statement exports, Khalti statement screens, and PDF bank statements from Nabil Bank, Sunrise Bank, and Himalayan Bank.',
                        style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
                      ),
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
