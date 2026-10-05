import 'package:flutter/foundation.dart';

import '../data/workout_store.dart';
import '../models/workout.dart';

/// Truy vấn bài tập gợi ý và nhật ký tập luyện trong ngày.
class WorkoutRepository extends ChangeNotifier {
  WorkoutRepository({WorkoutStore? store}) : _store = store ?? InMemoryWorkoutStore();

  final WorkoutStore _store;

  List<Workout> _catalog = const [];
  List<WorkoutLog> _todayLogs = const [];

  List<Workout> get catalog => _catalog;
  List<WorkoutLog> get todayLogs => _todayLogs;

  /// Tổng số phút đã tập hôm nay.
  int get minutesToday =>
      _todayLogs.fold(0, (sum, log) => sum + log.minutes);

  /// Tổng năng lượng đã đốt hôm nay.
  int get caloriesBurnedToday =>
      _todayLogs.fold(0, (sum, log) => sum + log.caloriesBurned);

  /// Mục tiêu số phút tập mỗi ngày, dùng cho vòng tròn tiến trình.
  static const int dailyMinuteGoal = 60;

  /// Tỉ lệ hoàn thành mục tiêu tập luyện, giới hạn trong khoảng 0..1.
  double get goalProgress =>
      (minutesToday / dailyMinuteGoal).clamp(0.0, 1.0);

  int get goalPercent => (goalProgress * 100).round();

  Future<void> loadCatalog() async {
    _catalog = await _store.catalog();
    notifyListeners();
  }

  Future<void> loadDay(String userId, {DateTime? day}) async {
    _todayLogs = await _store.logsByDay(userId, day ?? DateTime.now());
    notifyListeners();
  }

  /// Ghi nhận một buổi tập đã hoàn thành.
  Future<WorkoutLog> completeWorkout({
    required String userId,
    required Workout workout,
  }) async {
    final log = WorkoutLog.fromWorkout(
      id: 'log-${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      workout: workout,
      completedAt: DateTime.now(),
    );
    await _store.insertLog(log);
    await loadDay(userId);
    return log;
  }

  void clear() {
    _todayLogs = const [];
    notifyListeners();
  }
}
