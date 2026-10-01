import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/section_title.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Luyện tập',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.local_fire_department_rounded),
            color: AppTheme.orange,
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
              'Mỗi ngày một chút, khỏe mạnh hơn mỗi ngày.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _buildProgressCard(),
            const SizedBox(height: 26),
            const SectionTitle(title: 'Lộ trình của bạn'),
            const SizedBox(height: 12),
            _buildPlanCard(
              title: 'Bắt đầu vận động',
              subtitle: 'Dành cho người mới bắt đầu',
              level: 'Cơ bản',
              duration: '7 ngày',
              icon: Icons.directions_walk_rounded,
              color: AppTheme.primary,
              background: AppTheme.lightGreen,
            ),
            _buildPlanCard(
              title: 'Năng động mỗi ngày',
              subtitle: 'Tăng cường sức bền',
              level: 'Trung cấp',
              duration: '14 ngày',
              icon: Icons.directions_run_rounded,
              color: AppTheme.blue,
              background: const Color(0xFFEAF5FD),
            ),
            _buildPlanCard(
              title: 'Thử thách bản thân',
              subtitle: 'Dành cho người đã quen tập',
              level: 'Nâng cao',
              duration: '21 ngày',
              icon: Icons.bolt_rounded,
              color: AppTheme.orange,
              background: const Color(0xFFFFF5E8),
            ),
            const SizedBox(height: 12),
            const SectionTitle(title: 'Bài tập gợi ý'),
            const SizedBox(height: 12),
            _buildExercise(
              title: 'Đi bộ tại chỗ',
              subtitle: '10 phút · Nhẹ nhàng',
              icon: Icons.directions_walk_rounded,
              color: AppTheme.primary,
            ),
            _buildExercise(
              title: 'Squat cơ bản',
              subtitle: '8 phút · Toàn thân',
              icon: Icons.fitness_center_rounded,
              color: AppTheme.blue,
            ),
            _buildExercise(
              title: 'Giãn cơ',
              subtitle: '5 phút · Thư giãn',
              icon: Icons.self_improvement_rounded,
              color: AppTheme.pink,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chuỗi luyện tập',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '5',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 7, left: 5),
                      child: Text(
                        'ngày liên tiếp',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tiếp tục duy trì thói quen nhé!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.local_fire_department_rounded,
            size: 58,
            color: Color(0xFFFFD36A),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String subtitle,
    required String level,
    required String duration,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
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
                const SizedBox(height: 7),
                Row(
                  children: [
                    _SmallTag(text: level, color: color),
                    const SizedBox(width: 6),
                    Text(
                      duration,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildExercise({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
          const Icon(
            Icons.play_circle_fill_rounded,
            color: AppTheme.primary,
            size: 29,
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallTag({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}