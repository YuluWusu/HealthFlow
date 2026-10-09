import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/auth_scope.dart';
import '../services/audio_service.dart';
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
  String _selectedGender = 'male';

  final List<String> _goals = [
    'Giảm cân',
    'Giữ dáng',
    'Tăng cơ',
    'Tăng cân',
    'Sống khỏe',
  ];

  static const int _totalSteps = 6;

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _calorieController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 3) {
      AudioService().playSuccess();
    } else {
      AudioService().playSlide();
    }

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
    AudioService().playSlide();
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
        gender: _selectedGender,
      );
      // Đánh dấu đã hoàn thành onboarding
      if (mounted) {
        AudioService().playSuccess();
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
            if (_currentStep < 4)
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
                            'Bước ${_currentStep + 1} / 4',
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
                        value: (_currentStep + 1) / 4,
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
                  _buildFinalWelcomePage(),
                  _buildTutorialPage(),
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
                          _currentStep < 4
                              ? 'Tiếp tục'
                              : _currentStep == 4
                                  ? 'Bắt đầu sử dụng'
                                  : 'Tôi đã hiểu',
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            'Bạn là ai?\nHãy chọn giới tính để HealthFlow\ncá nhân hóa gợi ý cho bạn nhé.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _buildGenderCard(
                  gender: 'male',
                  label: 'Nam',
                  imagePath: 'assets/images/auth/male.jpg',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGenderCard(
                  gender: 'female',
                  label: 'Nữ',
                  imagePath: 'assets/images/auth/female.jpg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard({
    required String gender,
    required String label,
    required String imagePath,
  }) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        AudioService().playTap();
        setState(() => _selectedGender = gender);
      },
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                ),
                child: ClipOval(
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 28)
              else
                const SizedBox(height: 28),
            ],
          ),
        ),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/auth/step_body.jpg', // Thay ảnh này
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.lightBlue,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.straighten_rounded, size: 50, color: AppTheme.blue),
                ),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/auth/step_goal.jpg', // Thay ảnh này
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.flag_rounded, size: 50, color: AppTheme.primary),
                ),
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
                  onTap: () {
                    AudioService().playTap();
                    setState(() => _selectedGoal = goal);
                  },
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/auth/step_calorie.jpg', // Thay ảnh này
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.lightOrange,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, size: 50, color: AppTheme.orange),
                ),
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
            onTap: () {
              AudioService().playTap();
              setState(() => _calorieController.text = '1500');
            },
          ),
          const SizedBox(height: 8),
          _CalorieSuggestion(
            label: 'Giữ cân',
            value: '2000',
            icon: Icons.balance_rounded,
            color: AppTheme.primary,
            onTap: () {
              AudioService().playTap();
              setState(() => _calorieController.text = '2000');
            },
          ),
          const SizedBox(height: 8),
          _CalorieSuggestion(
            label: 'Tăng cân',
            value: '2500',
            icon: Icons.trending_up_rounded,
            color: AppTheme.orange,
            onTap: () {
              AudioService().playTap();
              setState(() => _calorieController.text = '2500');
            },
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

  Widget _buildFinalWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              'assets/images/auth/step_welcome_final.jpg', // Ảnh chào mừng hoàn tất
              width: 180,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.celebration_rounded, size: 80, color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Hồ sơ đã hoàn tất!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cảm ơn bạn đã cung cấp thông tin.\nHealthFlow đã sẵn sàng đồng hành cùng bạn trên con đường chinh phục sức khỏe.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Hướng dẫn cơ bản',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/auth/step_tutorial.jpg', // Ảnh hướng dẫn
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.explore_rounded, size: 80, color: AppTheme.blue),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '• Trang Chủ: Xem tổng quan calo và hoạt động.\n'
            '• Sức Khỏe: Theo dõi cân nặng & các chỉ số.\n'
            '• Dinh Dưỡng: Quản lý bữa ăn trong ngày.\n'
            '• Tập Luyện: Các bài tập rèn luyện thể chất.',
            style: TextStyle(
              fontSize: 14.5,
              color: AppTheme.textSecondary,
              height: 1.8,
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
