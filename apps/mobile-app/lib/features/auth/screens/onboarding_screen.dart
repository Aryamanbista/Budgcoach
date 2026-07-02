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
  final _nameController = TextEditingController(text: 'Aryaman Bista');
  String _selectedAge = '18–22';
  String _selectedOccupation = 'Student';

  // Step 3 Form States
  final Map<String, bool> _wallets = {
    'eSewa': true,
    'Khalti': true,
    'Nabil Bank': false,
    'Sunrise Bank': false,
    'Himalayan Bank': false,
  };

  // Step 4 Form States
  final _incomeController = TextEditingController(text: '35000');

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Complete Onboarding
      ref.read(authProvider.notifier).completeOnboarding(
            name: _nameController.text,
            occupation: _selectedOccupation,
            monthlyIncome: double.tryParse(_incomeController.text) ?? 35000,
          );
      context.go('/home/dashboard');
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
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
                  color: index <= _currentStep ? AppColors.primary : AppColors.divider,
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
                    _buildStepWallets(),
                    _buildStepIncome(),
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
                    child: Text(_currentStep == 3 ? 'GET STARTED' : 'NEXT'),
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
        const Center(
          child: Text(
            '💰',
            style: TextStyle(fontSize: 80),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'Meet Budgcoach',
          style: AppTextStyles.displayLarge,
        ),
        const SizedBox(height: 24),
        _buildBulletItem(
          icon: Icons.auto_graph,
          title: 'AI Spending Categorization',
          description: 'Upload statements and let our ML model sort expenses instantly.',
        ),
        const SizedBox(height: 16),
        _buildBulletItem(
          icon: Icons.timeline,
          title: 'LSTM Spending Forecasts',
          description: 'Project end-of-month totals to catch digital spending creep.',
        ),
        const SizedBox(height: 16),
        _buildBulletItem(
          icon: Icons.notifications_active_outlined,
          title: 'Behavioral Spendception Nudges',
          description: 'Get notifications when you overspend on impulsive categories.',
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
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
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
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          Text('Full Name', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          Text('Age Group', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedAge,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: ['18–22', '23–28', '29–35', '35+']
                .map((age) => DropdownMenuItem(value: age, child: Text(age)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedAge = val);
            },
          ),
          const SizedBox(height: 24),
          Text('Occupation', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedOccupation,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildStepWallets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Text('Connect Wallets & Banks', style: AppTextStyles.displayLarge),
        const SizedBox(height: 8),
        Text(
          'Which digital payment platforms do you spend on?',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: _wallets.keys.map((key) {
              return CheckboxListTile(
                title: Text(key, style: AppTextStyles.bodyLarge),
                value: _wallets[key],
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _wallets[key] = val ?? false;
                  });
                },
              );
            }).toList(),
          ),
        ),
        Card(
          color: AppColors.primary.withOpacity(0.05),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.primaryLight, width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.security, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "We don't connect directly to your bank account API. You'll upload exported statement files manually for processing.",
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
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
                style: AppTextStyles.headlineMedium.copyWith(color: AppColors.primary),
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
}
