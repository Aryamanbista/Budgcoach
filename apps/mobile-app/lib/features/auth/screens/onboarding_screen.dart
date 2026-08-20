import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 2 Form States
  final _nameController = TextEditingController();
  String _selectedAge = '18–22';
  String _selectedOccupation = 'Student';

  // Financial baseline form state
  final _incomeController = TextEditingController();
  bool _startWithHistoryUpload = true;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      final income = double.tryParse(_incomeController.text.trim());
      if (_nameController.text.trim().isEmpty || income == null || income < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter your name and a valid monthly income.'),
          ),
        );
        return;
      }
      // Complete Onboarding
      await ref
          .read(authProvider.notifier)
          .completeOnboarding(
            name: _nameController.text,
            occupation: _selectedOccupation,
            monthlyIncome: income,
          );
      if (mounted) {
        context.go(
          _startWithHistoryUpload ? '/home/upload' : '/home/dashboard',
        );
      }
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: _prevPage,
              )
            : null,
        title: Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index <= _currentStep
                      ? AppColors.primary
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (step) {
                    setState(() {
                      _currentStep = step;
                    });
                  },
                  children: [
                    _buildStepWelcome(),
                    _buildStepProfile(),
                    _buildStepIncome(),
                    _buildStepHistoryBaseline(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentStep > 0
                      ? TextButton(
                          onPressed: _prevPage,
                          child: const Text('BACK'),
                        )
                      : const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 52),
                    ),
                    child: Text(
                      _currentStep == 3
                          ? _startWithHistoryUpload
                                ? 'UPLOAD HISTORY'
                                : 'FINISH'
                          : 'NEXT',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepWelcome() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: Text('💰', style: TextStyle(fontSize: 80))),
        const SizedBox(height: 40),
        Text('Meet Budgcoach', style: AppTextStyles.displayLarge),
        const SizedBox(height: 24),
        _buildBulletItem(
          icon: Icons.auto_graph,
          title: 'AI Spending Categorization',
          description:
              'Upload statements and let our ML model sort expenses instantly.',
        ),
        const SizedBox(height: 16),
        _buildBulletItem(
          icon: Icons.timeline,
          title: 'LSTM Spending Forecasts',
          description:
              'Project end-of-month totals to catch digital spending creep.',
        ),
        const SizedBox(height: 16),
        _buildBulletItem(
          icon: Icons.notifications_active_outlined,
          title: 'Behavioral Spendception Nudges',
          description:
              'Get notifications when you overspend on impulsive categories.',
        ),
      ],
    );
  }

  Widget _buildBulletItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepProfile() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text('Profile Setup', style: AppTextStyles.displayLarge),
          const SizedBox(height: 8),
          Text(
            'Help us tailor your budget advisor recommendation.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Full Name',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Age Group',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedAge,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: ['18–22', '23–28', '29–35', '35+']
                .map((age) => DropdownMenuItem(value: age, child: Text(age)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedAge = val);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Occupation',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedOccupation,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: ['Student', 'Working Professional', 'Business', 'Other']
                .map((occ) => DropdownMenuItem(value: occ, child: Text(occ)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedOccupation = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepIncome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Text('Monthly Income', style: AppTextStyles.displayLarge),
        const SizedBox(height: 8),
        Text(
          'What is your average monthly income in NPR?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _incomeController,
          keyboardType: TextInputType.number,
          style: AppTextStyles.headlineMedium,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Text(
                'NPR',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Used to calculate your savings rate and budget recommendations. You can change this anytime in profile settings.",
          style: AppTextStyles.labelSmall,
        ),
      ],
    );
  }

  Widget _buildStepHistoryBaseline() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Build your personal baseline',
            style: AppTextStyles.displayLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'For the most accurate forecast and timely nudges, start with your latest 30 consecutive days of transactions.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _buildBulletItem(
            icon: Icons.calendar_month_outlined,
            title: '30 days recommended',
            description:
                'One monthly statement is usually enough. Overlapping uploads are safely deduplicated.',
          ),
          const SizedBox(height: 16),
          _buildBulletItem(
            icon: Icons.psychology_outlined,
            title: 'Learns only from your history',
            description:
                'Your forecast begins with a statistical baseline and switches to the personal AI model when coverage is ready.',
          ),
          const SizedBox(height: 16),
          _buildBulletItem(
            icon: Icons.lock_outline,
            title: 'Your file is not retained',
            description:
                'Budgcoach extracts the transaction rows and discards the uploaded document.',
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: SwitchListTile(
              value: _startWithHistoryUpload,
              activeThumbColor: AppColors.primary,
              title: Text(
                'Start with statement upload',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'You can skip this and upload later. Budgcoach will use a fallback baseline in the meantime.',
              ),
              onChanged: (value) {
                setState(() => _startWithHistoryUpload = value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
