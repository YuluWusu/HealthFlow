import '../models/nutrition.dart';

/// Một huy hiệu thành tích.
class AchievementBadge {
  const AchievementBadge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.progress,
  });

  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool unlocked;

  /// Tiến độ 0..1 tới khi mở khóa.
  final double progress;
}

/// Chuỗi ngày ghi nhật ký và các huy hiệu, tính từ toàn bộ nhật ký.
class NutritionAchievements {
  const NutritionAchievements({
    required this.currentStreak,
    required this.bestStreak,
    required this.loggedDays,
    required this.goalDays,
    required this.todayLogged,
    required this.todayGoalReached,
    required this.badges,
  });

  static const empty = NutritionAchievements(
    currentStreak: 0,
    bestStreak: 0,
    loggedDays: 0,
    goalDays: 0,
    todayLogged: false,
    todayGoalReached: false,
    badges: [],
  );

  /// Số ngày liên tiếp có ghi nhật ký tính tới hôm nay (hôm nay chưa ghi thì
  /// tính tới hôm qua — chuỗi chưa đứt cho tới hết hôm nay).
  final int currentStreak;
  final int bestStreak;
  final int loggedDays;

  /// Số ngày đạt mục tiêu calo (trong khoảng 90–110%).
  final int goalDays;
  final bool todayLogged;
  final bool todayGoalReached;
  final List<AchievementBadge> badges;

  int get unlockedCount => badges.where((b) => b.unlocked).length;
}

/// Một ngày được coi là "đạt mục tiêu" khi calo nằm trong 90–110% mục tiêu.
bool isGoalDay(int calories, int calorieGoal) {
  if (calorieGoal <= 0) return false;
  final ratio = calories / calorieGoal;
  return ratio >= 0.9 && ratio <= 1.1;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

NutritionAchievements computeAchievements({
  required Iterable<MealEntry> entries,
  required int calorieGoal,
  required DateTime now,
}) {
  final today = _dateOnly(now);
  final perDay = <DateTime, int>{};
  for (final e in entries) {
    // Bỏ món lên kế hoạch cho tương lai: chưa ăn thì chưa tính.
    if (e.eatenAt.isAfter(now)) continue;
    final d = _dateOnly(e.eatenAt);
    perDay[d] = (perDay[d] ?? 0) + e.calories;
  }

  final days = perDay.keys.toList()..sort();

  var best = 0;
  var run = 0;
  DateTime? prev;
  for (final d in days) {
    if (prev != null && d.difference(prev).inHours <= 36) {
      run += 1;
    } else {
      run = 1;
    }
    if (run > best) best = run;
    prev = d;
  }

  var current = 0;
  var cursor = perDay.containsKey(today)
      ? today
      : DateTime(today.year, today.month, today.day - 1);
  while (perDay.containsKey(cursor)) {
    current += 1;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  if (current > best) best = current;

  final goalDays =
      perDay.values.where((kcal) => isGoalDay(kcal, calorieGoal)).length;
  final todayCalories = perDay[today] ?? 0;

  AchievementBadge streakBadge(int n, String emoji, String title) {
    return AchievementBadge(
      id: 'streak-$n',
      emoji: emoji,
      title: title,
      description: 'Ghi nhật ký $n ngày liên tiếp',
      unlocked: best >= n,
      progress: (best / n).clamp(0.0, 1.0).toDouble(),
    );
  }

  AchievementBadge goalBadge(int n, String emoji, String title) {
    return AchievementBadge(
      id: 'goal-$n',
      emoji: emoji,
      title: title,
      description: 'Đạt mục tiêu calo $n ngày',
      unlocked: goalDays >= n,
      progress: (goalDays / n).clamp(0.0, 1.0).toDouble(),
    );
  }

  return NutritionAchievements(
    currentStreak: current,
    bestStreak: best,
    loggedDays: perDay.length,
    goalDays: goalDays,
    todayLogged: perDay.containsKey(today),
    todayGoalReached: isGoalDay(todayCalories, calorieGoal),
    badges: [
      streakBadge(3, '🔥', 'Khởi động'),
      streakBadge(7, '🌟', 'Một tuần đều đặn'),
      streakBadge(14, '💪', 'Hai tuần bền bỉ'),
      streakBadge(30, '🏆', 'Một tháng kỷ luật'),
      goalBadge(1, '🎯', 'Trúng mục tiêu'),
      goalBadge(7, '🥇', 'Bảy ngày chuẩn'),
      goalBadge(30, '👑', 'Ba mươi ngày chuẩn'),
    ],
  );
}
