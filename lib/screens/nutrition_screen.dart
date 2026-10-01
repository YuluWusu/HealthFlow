import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/section_title.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dinh dưỡng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theo dõi bữa ăn và dinh dưỡng mỗi ngày.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _buildNutritionSummary(),
            const SizedBox(height: 26),
            const SectionTitle(title: 'Các bữa ăn'),
            const SizedBox(height: 12),
            _buildMealCard(
              title: 'Bữa sáng',
              subtitle: 'Bánh mì trứng',
              calories: '350 kcal',
              icon: Icons.free_breakfast_rounded,
              color: AppTheme.orange,
              background: const Color(0xFFFFF5E8),
            ),
            _buildMealCard(
              title: 'Bữa trưa',
              subtitle: 'Cơm gà',
              calories: '650 kcal',
              icon: Icons.lunch_dining_rounded,
              color: AppTheme.primary,
              background: AppTheme.lightGreen,
            ),
            _buildMealCard(
              title: 'Bữa tối',
              subtitle: 'Chưa thêm món ăn',
              calories: '0 kcal',
              icon: Icons.dinner_dining_rounded,
              color: AppTheme.blue,
              background: const Color(0xFFEAF5FD),
            ),
            _buildMealCard(
              title: 'Bữa phụ',
              subtitle: 'Sữa chua',
              calories: '250 kcal',
              icon: Icons.icecream_rounded,
              color: AppTheme.pink,
              background: const Color(0xFFFFF0F3),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Dinh dưỡng hôm nay'),
            const SizedBox(height: 12),
            _buildMacroCard(
              title: 'Protein',
              value: '45 g',
              progress: 0.6,
              color: AppTheme.primary,
            ),
            _buildMacroCard(
              title: 'Carbohydrate',
              value: '120 g',
              progress: 0.5,
              color: AppTheme.orange,
            ),
            _buildMacroCard(
              title: 'Chất béo',
              value: '35 g',
              progress: 0.7,
              color: AppTheme.pink,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng năng lượng',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '1,250',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 6, left: 6),
                child: Text(
                  'kcal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mục tiêu: 2,000 kcal',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              value: 0.625,
              minHeight: 8,
              backgroundColor: Color(0x668FFFFFF),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Còn lại 750 kcal',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required String title,
    required String subtitle,
    required String calories,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                calories,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 21,
                color: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required String title,
    required String value,
    required double progress,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.13),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}