import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../widgets/ocr_progress_stepper.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  String _selectedPlatform = 'eSewa';
  String? _selectedFileName;
  String? _selectedFileSize;
  bool _isFileSelected = false;
  PlatformFile? _pickedFile;
  bool _isUploading = false;

  final List<String> _platforms = [
    'eSewa',
    'Khalti',
    'Nabil Bank',
    'Sunrise Bank',
    'Himalayan Bank',
  ];

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Using any since custom extensions can fail silently on some web browsers
        withData: true, // Need bytes since macOS might have sandbox issues with file paths
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFile = file;
          _selectedFileName = file.name;
          _selectedFileSize = '${(file.size / 1024).toStringAsFixed(1)} KB';
          _isFileSelected = true;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file picker: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  void _clearFile() {
    setState(() {
      _pickedFile = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _isFileSelected = false;
    });
  }

  Future<void> _processStatement() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) return;

    setState(() {
      _isUploading = true;
    });

    // Show the progress stepper overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OcrProgressStepper(
        onCompleted: () {}, // We will manually pop when upload finishes
      ),
    );

    try {
      final apiClient = ref.read(apiClientProvider);
      
      final formData = FormData.fromMap({
        'wallet_type': _selectedPlatform,
        // Passing a dummy UUID for the account ID constraint on the backend
        'account_id': '123e4567-e89b-12d3-a456-426614174000',
        'file': MultipartFile.fromBytes(
          _pickedFile!.bytes!,
          filename: _pickedFile!.name,
        ),
      });

      final response = await apiClient.dio.post(
        '/upload-statement',
        data: formData,
      );

      final transactions = response.data['transactions'] as List<dynamic>;

      if (mounted) {
        Navigator.of(context).pop(); // dismiss dialog
        context.push('/upload/review', extra: transactions);
      }
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (mounted) {
        Navigator.of(context).pop(); // dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process statement: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
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
                onTap: _isFileSelected ? null : _pickFile,
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
                    child: SingleChildScrollView(
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
                            'Tap to select a document',
                            style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supported formats: PDF, Excel, CSV, JPG, PNG',
                            style: AppTextStyles.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _pickFile,
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
                        'Supported formats: PDF statements, Excel/CSV exports, and Screenshots from supported banks and wallets.',
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
