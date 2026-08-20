import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/shared_file_reader.dart';
import '../widgets/ocr_progress_stepper.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final bool fetchCoverageOnInit;
  final String? sharedFilePath;
  final String? sharedFileName;

  const UploadScreen({
    super.key,
    this.fetchCoverageOnInit = true,
    this.sharedFilePath,
    this.sharedFileName,
  });

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  String? _selectedFileName;
  String? _selectedFileSize;
  bool _isFileSelected = false;
  PlatformFile? _pickedFile;
  bool _isUploading = false;
  bool _isLoadingCoverage = true;
  int _coveredDays = 0;
  int _requiredDays = 30;
  String _coverageStatus = 'none';
  String _coverageMessage =
      'Upload your latest 30-day statement to build a personal baseline.';

  @override
  void initState() {
    super.initState();
    if (widget.fetchCoverageOnInit) {
      _loadCoverage();
    } else {
      _isLoadingCoverage = false;
    }
    if (widget.sharedFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSharedFile());
    }
  }

  Future<void> _loadSharedFile() async {
    try {
      final bytes = await readSharedFileBytes(widget.sharedFilePath!);
      if (!mounted) return;
      final name = widget.sharedFileName ?? 'shared-statement';
      setState(() {
        _pickedFile = PlatformFile(
          name: name,
          size: bytes.length,
          bytes: bytes,
          path: widget.sharedFilePath,
        );
        _selectedFileName = name;
        _selectedFileSize = '${(bytes.length / 1024).toStringAsFixed(1)} KB';
        _isFileSelected = true;
      });
      await _processStatement();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Budgcoach could not open that shared file. Export the statement as PDF, Excel, CSV, or an image and try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadCoverage() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/history-coverage');
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _coveredDays = (data['covered_days'] as num?)?.toInt() ?? 0;
        _requiredDays = (data['required_days'] as num?)?.toInt() ?? 30;
        _coverageStatus = data['status']?.toString() ?? 'none';
        _coverageMessage = data['message']?.toString() ?? _coverageMessage;
        _isLoadingCoverage = false;
      });
    } catch (error) {
      debugPrint('Failed to load history coverage: $error');
      if (mounted) setState(() => _isLoadingCoverage = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType
            .any, // Using any since custom extensions can fail silently on some web browsers
        withData:
            true, // Need bytes since macOS might have sandbox issues with file paths
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
          ),
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

    final completer = Completer<int>();

    // Show the progress stepper overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          OcrProgressStepper(processingFuture: completer.future),
    );

    try {
      final apiClient = ref.read(apiClientProvider);
      final accountsResponse = await apiClient.dio.get('/accounts/');
      final accounts = accountsResponse.data as List<dynamic>;
      final String accountId;
      if (accounts.isEmpty) {
        final created = await apiClient.dio.post(
          '/accounts/',
          data: {'wallet_name': 'Default Wallet', 'balance': 0},
        );
        accountId = created.data['id'].toString();
      } else {
        accountId = accounts.first['id'].toString();
      }

      final formData = FormData.fromMap({
        'account_id': accountId,
        'file': MultipartFile.fromBytes(
          _pickedFile!.bytes!,
          filename: _pickedFile!.name,
        ),
      });

      final response = await apiClient.dio.post(
        '/upload-statement',
        data: formData,
      );

      final preview = Map<String, dynamic>.from(
        response.data as Map<String, dynamic>,
      );
      final transactions = preview['transactions'] as List<dynamic>;

      // Let the stepper know we're done and how many we got
      completer.complete(transactions.length);

      // The stepper will auto-pop after showing the success state
      // Wait for it to pop
      await Future.delayed(const Duration(milliseconds: 1600));

      if (mounted) {
        context.push('/upload/review', extra: preview);
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      debugPrint('Upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process statement: $e'),
            backgroundColor: Colors.red,
          ),
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
      appBar: AppBar(title: const Text('Upload Statement'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Budgcoach detects the statement format automatically.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _buildCoverageCard(),
            const SizedBox(height: 16),

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
                      color: AppColors.primary.withValues(alpha: 0.4),
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
                              style: AppTextStyles.titleLarge.copyWith(
                                fontSize: 16,
                              ),
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
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
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
                              icon: const Icon(
                                Icons.delete,
                                color: AppColors.danger,
                              ),
                              label: const Text(
                                'Remove',
                                style: TextStyle(color: AppColors.danger),
                              ),
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
              onPressed: _isFileSelected && !_isUploading
                  ? _processStatement
                  : null,
              child: Text(_isUploading ? 'Processing…' : 'Process Statement'),
            ),
            const SizedBox(height: 16),

            // Info Card at Bottom
            Card(
              elevation: 0,
              color: AppColors.primary.withValues(alpha: 0.05),
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

  Widget _buildCoverageCard() {
    final readiness = _requiredDays == 0
        ? 0.0
        : (_coveredDays / _requiredDays).clamp(0.0, 1.0);
    final isReady = _coveredDays >= _requiredDays;
    final isVerified = _coverageStatus == 'verified';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isReady ? AppColors.success : AppColors.primary).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isReady ? AppColors.success : AppColors.primary).withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: _isLoadingCoverage
          ? const SizedBox(
              height: 42,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: readiness,
                        strokeWidth: 6,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation(
                          isReady ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      Center(
                        child: Text(
                          '$_coveredDays',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReady
                            ? 'Your personal baseline is ready'
                            : '$_coveredDays of $_requiredDays days available',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _coverageMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall,
                      ),
                      if (isVerified) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Verified from committed statements',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
