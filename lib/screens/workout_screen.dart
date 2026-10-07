import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/workout_repository.dart';
import '../models/workout.dart';
import '../theme/app_theme.dart';

/// Màn hình 5 trong bản thiết kế: module Tập luyện.
///
/// Ba thẻ: Tổng quan (tiến trình hôm nay và bài tập gợi ý), Bài tập (toàn bộ
/// danh mục), Lịch sử (các buổi đã hoàn thành hôm nay).
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tập luyện',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 13.5),
            tabs: [
              Tab(text: 'Tổng quan'),
              Tab(text: 'Bài tập'),
              Tab(text: 'Lịch sử'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: app.workout,
          builder: (context, _) {
            return TabBarView(
              physics: const ClampingScrollPhysics(),
              children: [
                _OverviewTab(workout: app.workout),
                _CatalogTab(workout: app.workout),
                _HistoryTab(workout: app.workout),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tab 1: tiến trình hôm nay và vài bài tập gợi ý.
class _OverviewTab extends StatelessWidget {
  final WorkoutRepository workout;

  const _OverviewTab({required this.workout});

  @override
  Widget build(BuildContext context) {
    final suggestions = workout.catalog.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        _ProgressCard(workout: workout),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bài tập gợi ý',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              'Hôm nay',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (suggestions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final item in suggestions)
            _WorkoutTile(
              workout: item,
              onStart: () => _showWorkoutSheet(context, workout, item),
            ),
      ],
    );
  }
}

/// Tab 2: toàn bộ danh mục bài tập.
class _CatalogTab extends StatelessWidget {
  final WorkoutRepository workout;

  const _CatalogTab({required this.workout});

  @override
  Widget build(BuildContext context) {
    if (workout.catalog.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Nhóm bài tập theo danh mục để dễ chọn.
    final grouped = <String, List<Workout>>{};
    for (final item in workout.catalog) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          for (final item in entry.value)
            _WorkoutTile(
              workout: item,
              onStart: () => _showWorkoutSheet(context, workout, item),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Tab 3: các buổi tập đã hoàn thành trong ngày.
class _HistoryTab extends StatelessWidget {
  final WorkoutRepository workout;

  const _HistoryTab({required this.workout});

  @override
  Widget build(BuildContext context) {
    final logs = workout.todayLogs;

    if (logs.isEmpty) {
      return const _EmptyState(
        icon: Icons.fitness_center_rounded,
        message:
            'Hôm nay bạn chưa hoàn thành buổi tập nào.\nChọn một bài tập ở thẻ '
            '"Bài tập" để bắt đầu nhé!',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Tổng thời gian',
                  value: '${workout.minutesToday} phút',
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Năng lượng đốt',
                  value: '${workout.caloriesBurnedToday} kcal',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final log in logs)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppTheme.primary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.workoutName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${log.minutes} phút · ${_formatTime(log.completedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${log.caloriesBurned} kcal',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Thẻ tiến trình tập luyện hôm nay với vòng tròn phần trăm hoàn thành.
class _ProgressCard extends StatelessWidget {
  final WorkoutRepository workout;

  const _ProgressCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hôm nay',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${workout.minutesToday}',
                      style: const TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 5, bottom: 6),
                      child: Text(
                        'phút',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Mục tiêu ${WorkoutRepository.dailyMinuteGoal} phút',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.lightOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: AppTheme.orange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${workout.caloriesBurnedToday} kcal đã đốt',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: workout.goalProgress,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppTheme.lightGreen,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${workout.goalPercent}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const Text(
                      'mục tiêu',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng bài tập kèm nút bắt đầu.
class _WorkoutTile extends StatelessWidget {
  final Workout workout;
  final VoidCallback onStart;

  const _WorkoutTile({required this.workout, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppTheme.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  workout.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cường độ ${workout.intensity.label}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onStart,
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              size: 32,
              color: AppTheme.primary,
            ),
            tooltip: 'Bắt đầu ${workout.name}',
          ),
        ],
      ),
    );
  }
}

/// Thông tin tóm tắt trong thẻ xanh ở tab Lịch sử.
class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppTheme.textSecondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại chi tiết bài tập, có nút xác nhận đã hoàn thành.
///
/// Khi xác nhận, buổi tập được ghi vào nhật ký và thẻ tiến trình cập nhật ngay.
void _showWorkoutSheet(
  BuildContext context,
  WorkoutRepository repository,
  Workout workout,
) {
  final auth = AuthScope.of(context, listen: false);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      var isSaving = false;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> complete() async {
            final user = auth.currentUser;
            if (user == null) return;

            setSheetState(() => isSaving = true);
            await repository.completeWorkout(userId: user.id, workout: workout);
            if (!sheetContext.mounted) return;

            Navigator.of(sheetContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đã ghi nhận ${workout.name} · ${workout.durationMinutes} phút',
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              14,
              22,
              22 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: AppTheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workout.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DetailBox(
                        icon: Icons.schedule_rounded,
                        label: 'Thời gian',
                        value: '${workout.durationMinutes} phút',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailBox(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Năng lượng',
                        value: '${workout.caloriesBurned} kcal',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailBox(
                        icon: Icons.speed_rounded,
                        label: 'Cường độ',
                        value: workout.intensity.label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : complete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Hoàn thành bài tập',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Ô thông tin nhỏ trong hộp thoại chi tiết bài tập.
class _DetailBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: AppTheme.primary),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
