import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _enableNotifications = true;

  void _showEditIncomeDialog(BuildContext context, double currentIncome) {
    final controller = TextEditingController(text: currentIncome.toInt().toString());
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
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                ref.read(authProvider.notifier).updateMonthlyIncome(val);
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
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDark = authState.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
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
                      'AB',
                      style: AppTextStyles.displayLarge.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Aryaman Bista',
                    style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user?.email ?? 'aryaman@example.com',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(user?.occupation ?? 'Student'),
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
                    subtitle: Text(Formatters.formatNpr(user?.monthlyIncome ?? 35000)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showEditIncomeDialog(context, user?.monthlyIncome ?? 35000),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Linked Platforms'),
                    subtitle: Wrap(
                      spacing: 8,
                      children: const [
                        Chip(label: Text('eSewa'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        Chip(label: Text('Khalti'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ],
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
                    subtitle: Text(isDark ? 'Dark mode enabled' : 'Light mode enabled'),
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
                    onChanged: (val) {
                      setState(() {
                        _enableNotifications = val;
                      });
                    },
                  ),
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
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon: PDF/Excel exports')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Clear Mock Data Cache', style: TextStyle(color: AppColors.danger)),
                    trailing: const Icon(Icons.refresh, color: AppColors.danger),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Reset Mock Data?'),
                          content: const Text('Are you sure you want to reset all transactions, goals, and budget limits back to the default state?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Mock database re-initialized. Restart app to apply.')),
                                );
                              },
                              child: const Text('RESET', style: TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      );
                    },
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
                      'Budgcoach takes security seriously. Your financial statements are processed locally on-device for categorizations and predictions. We do not store or transmit raw banking data to centralized servers.',
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
                    trailing: Text('1.0.0-beta', style: TextStyle(color: AppColors.textSecondary)),
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
