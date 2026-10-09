import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/auth_scope.dart';
import '../theme/app_theme.dart';

/// Màn hình thiết lập thông tin ban đầu cho người dùng mới.
///
/// Sau khi đăng ký thành công và đăng nhập lần đầu, người dùng sẽ được
/// hướng dẫn nhập các thông tin cơ bản: chiều cao, cân nặng, mục tiêu sức khỏe
/// và lượng calo mục tiêu.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Controllers cho các trường nhập
  final _heightController = TextEditingController(text: '165');
  final _weightController = TextEditingController(text: '55');
  final _calorieController = TextEditingController(text: '2000');
  String _selectedGoal = 'Giữ dáng';

  final List<String> _goals = [
    'Giảm cân',
    'Giữ dáng',
    'Tăng cơ',
    'Tăng cân',
    'Sống khỏe',
  ];

  static const int _totalSteps = 4;

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _calorieController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndContinue();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveAndContinue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final auth = AuthScope.of(context, listen: false);
    final height = double.tryParse(_heightController.text.trim()) ?? 165;
    final weight = double.tryParse(_weightController.text.trim()) ?? 55;
    final calorie = int.tryParse(_calorieController.text.trim()) ?? 2000;

    try {
      await auth.updateProfile(
        heightCm: height,
        weightKg: weight,
        dailyCalorieGoal: calorie,
        healthGoal: _selectedGoal,
      );
      // Đánh dấu đã hoàn thành onboarding
      if (mounted) {
        auth.completeOnboarding();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Có lỗi xảy ra: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_currentStep > 0)
                        IconButton(
                          onPressed: _prevStep,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        )
                      else
                        const SizedBox(width: 32),
                      Expanded(
                        child: Text(
                          'Bước ${_currentStep + 1} / $_totalSteps',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      minHeight: 6,
                      backgroundColor: AppTheme.lightGreen,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentStep = index),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildHeightWeightPage(),
                  _buildGoalPage(),
                  _buildCaloriePage(),
                ],
              ),
            ),
            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep < _totalSteps - 1
                              ? 'Tiếp tục'
                              : 'Hoàn tất thiết lập',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              size: 50,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Chào mừng bạn đến\nvới HealthFlow! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hãy dành vài phút để thiết lập hồ sơ sức khỏe của bạn.\n'
            'Thông tin này giúp HealthFlow đưa ra gợi ý phù hợp nhất cho bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          // Các tính năng
          _FeatureItem(
            icon: Icons.monitor_weight_outlined,
            title: 'Theo dõi cân nặng & chiều cao',
            color: AppTheme.blue,
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.flag_outlined,
            title: 'Đặt mục tiêu sức khỏe cá nhân',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.restaurant_rounded,
            title: 'Quản lý dinh dưỡng hàng ngày',
            color: AppTheme.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildHeightWeightPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.straighten_rounded,
                size: 40,
                color: AppTheme.blue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Thông số cơ thể',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Giúp chúng tôi tính toán chỉ số BMI\nvà đưa ra gợi ý phù hợp cho bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 36),
          _buildInputCard(
            icon: Icons.height_rounded,
            label: 'Chiều cao (cm)',
            controller: _heightController,
            hint: 'VD: 165',
            suffix: 'cm',
          ),
          const SizedBox(height: 16),
          _buildInputCard(
            icon: Icons.monitor_weight_outlined,
            label: 'Cân nặng (kg)',
            controller: _weightController,
            hint: 'VD: 55',
            suffix: 'kg',
            allowDecimal: true,
          ),
          const SizedBox(height: 24),
          // BMI preview
          Builder(
            builder: (context) {
              final height = double.tryParse(_heightController.text.trim()) ?? 0;
              final weight = double.tryParse(_weightController.text.trim()) ?? 0;
              if (height > 0 && weight > 0) {
                final heightM = height / 100;
                final bmi = weight / (heightM * heightM);
                String bmiLabel;
                Color bmiColor;
                if (bmi < 18.5) {
                  bmiLabel = 'Thiếu cân';
                  bmiColor = AppTheme.blue;
                } else if (bmi < 25) {
                  bmiLabel = 'Bình thường';
                  bmiColor = AppTheme.primary;
                } else if (bmi < 30) {
                  bmiLabel = 'Thừa cân';
                  bmiColor = AppTheme.orange;
                } else {
                  bmiLabel = 'Béo phì';
                  bmiColor = AppTheme.danger;
                }
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bmiColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bmiColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: bmiColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'BMI: ${bmi.toStringAsFixed(1)} — $bmiLabel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: bmiColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.flag_rounded,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Mục tiêu của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Chọn mục tiêu sức khỏe mà bạn\nmuốn đạt được',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
          ...List.generate(_goals.length, (index) {
            final goal = _goals[index];
            final isSelected = _selectedGoal == goal;
            final icons = [
              Icons.trending_down_rounded,
              Icons.balance_rounded,
              Icons.fitness_center_rounded,
              Icons.trending_up_rounded,
              Icons.favorite_rounded,
            ];
            final colors = [
              AppTheme.blue,
              AppTheme.primary,
              AppTheme.orange,
              AppTheme.pink,
              AppTheme.purple,
            ];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => setState(() => _selectedGoal = goal),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.withValues(alpha: 0.15),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors[index].withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icons[index], color: colors[index], size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            goal,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCaloriePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.lightOrange,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 40,
                color: AppTheme.orange,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Mục tiêu calo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Đặt mức calo mục tiêu hàng ngày\nphù hợp với lối sống của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 36),
          _buildInputCard(
            icon: Icons.local_fire_department_rounded,
            label: 'Lượng calo mục tiêu mỗi ngày',
            controller: _calorieController,
            hint: 'VD: 2000',
            suffix: 'kcal',
          ),
          const SizedBox(height: 20),
          // Gợi ý calo
          const Text(
            'Gợi ý tham khảo:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _CalorieSuggestion(
            label: 'Giảm cân',
            value: '1500',
            icon: Icons.trending_down_rounded,
            color: AppTheme.blue,
            onTap: () => setState(() => _calorieController.text = '1500'),
          ),
          const SizedBox(height: 8),
          _CalorieSuggestion(
            label: 'Giữ cân',
            value: '2000',
            icon: Icons.balance_rounded,
            color: AppTheme.primary,
            onTap: () => setState(() => _calorieController.text = '2000'),
          ),
          const SizedBox(height: 8),
          _CalorieSuggestion(
            label: 'Tăng cân',
            value: '2500',
            icon: Icons.trending_up_rounded,
            color: AppTheme.orange,
            onTap: () => setState(() => _calorieController.text = '2500'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bạn có thể thay đổi mục tiêu bất cứ lúc nào trong phần Cài đặt.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
    required String suffix,
    bool allowDecimal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
            inputFormatters: [
              if (!allowDecimal)
                FilteringTextInputFormatter.digitsOnly
              else
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              suffixText: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieSuggestion extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CalorieSuggestion({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Text(
                '$value kcal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
