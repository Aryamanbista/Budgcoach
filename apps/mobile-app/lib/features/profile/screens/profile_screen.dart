import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _enableNotifications = false;
  bool _smsImportEnabled = false;

  @override
  void initState() {
    super.initState();
    if (SmsService.isAvailable) {
      SmsService.hasPermission().then((enabled) {
        if (mounted) setState(() => _smsImportEnabled = enabled);
      });
    }
    NotificationService.isEnabled().then((enabled) {
      if (mounted) setState(() => _enableNotifications = enabled);
    });
  }

  Future<void> _requestSmsImport() async {
    final consented = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import financial SMS?'),
        content: const Text(
          'On Android, Budgcoach can detect new bank and wallet transaction '
          'messages. It ignores messages that do not contain both a known '
          'financial sender and a transaction amount. Matching messages stay '
          'privately on this device until they are sent to your Budgcoach '
          'account for transaction parsing. This is optional.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NOT NOW'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
    if (consented != true || !mounted) return;
    final granted = await SmsService.enable();
    if (!mounted) return;
    setState(() => _smsImportEnabled = granted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Financial SMS import is enabled.'
              : 'SMS permission was not granted.',
        ),
      ),
    );
  }

  void _showEditIncomeDialog(BuildContext context, double currentIncome) {
    final controller = TextEditingController(
      text: currentIncome.toInt().toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Monthly Income'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monthly Income (NPR)',
            prefixText: 'NPR ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                await ref.read(authProvider.notifier).updateMonthlyIncome(val);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Income updated successfully')),
                );
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTransactions() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get<List<int>>(
            '/transactions/export.csv',
            options: Options(responseType: ResponseType.bytes),
          );
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/budgcoach-transactions.csv';
      await File(path).writeAsBytes(response.data ?? const [], flush: true);
      await Share.shareXFiles([
        XFile(path, mimeType: 'text/csv'),
      ], subject: 'Budgcoach transaction export');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not export transactions. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDark = authState.themeMode == ThemeMode.dark;
    final initials =
        (user?.name.trim().isNotEmpty == true ? user!.name : 'User')
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Large Avatar Circle & Name
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Theme.of(context).cardTheme.color,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initials,
                      style: AppTextStyles.displayLarge.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'User',
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      user?.occupation.isNotEmpty == true
                          ? user!.occupation
                          : 'Profile not completed',
                    ),
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Settings Groups
            _buildGroupHeader('Account'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Monthly Income'),
                    subtitle: Text(
                      Formatters.formatNpr(user?.monthlyIncome ?? 0),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showEditIncomeDialog(
                      context,
                      user?.monthlyIncome ?? 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildGroupHeader('Preferences'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Dark Theme'),
                    subtitle: Text(
                      isDark ? 'Dark mode enabled' : 'Light mode enabled',
                    ),
                    value: isDark,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      ref.read(authProvider.notifier).toggleTheme();
                    },
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    title: Text('Currency'),
                    subtitle: Text('NPR (Nepalese Rupee)'),
                    trailing: Icon(Icons.lock_outline, size: 18),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    value: _enableNotifications,
                    activeColor: AppColors.primary,
                    onChanged: (val) async {
                      final enabled = await NotificationService.setEnabled(val);
                      if (mounted) {
                        setState(() => _enableNotifications = enabled);
                      }
                    },
                  ),
                  if (SmsService.isAvailable) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Import financial SMS'),
                      subtitle: const Text(
                        'Android only · bank and wallet transactions',
                      ),
                      value: _smsImportEnabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: (enabled) {
                        if (enabled && !_smsImportEnabled) {
                          _requestSmsImport();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Disable SMS permission from Android Settings.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildGroupHeader('Data Actions'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Export Spending Data'),
                    trailing: const Icon(Icons.download),
                    onTap: _exportTransactions,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildGroupHeader('Legal & Application'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showPolicyDialog(
                      context,
                      'Privacy Policy',
                      'Budgcoach sends statements you choose to upload to your configured Budgcoach server for extraction. Parsed transactions and account data are stored in PostgreSQL under your authenticated account. Raw upload bytes are processed temporarily and are not retained by the import service. Android SMS import is optional and filters financial transaction messages before authenticated synchronization.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showPolicyDialog(
                      context,
                      'Terms of Service',
                      'By using Budgcoach, you agree to upload manual bank statements under your own legal authority. The spending projections and LSTM forecasts are visual estimates for budgeting help and do not constitute professional financial advice.',
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    title: Text('App Version'),
                    trailing: Text(
                      '1.0.0',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Danger Zone Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: OutlinedButton(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                ),
                child: const Text('Logout'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, top: 12.0, bottom: 6.0),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
