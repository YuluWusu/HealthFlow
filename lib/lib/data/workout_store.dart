import '../models/workout.dart';

/// Lớp lưu trữ bài tập: danh mục gợi ý và nhật ký buổi tập đã hoàn thành.
abstract class WorkoutStore {
  Future<List<Workout>> catalog();

  Future<Workout?> findWorkout(String workoutId);

  Future<List<WorkoutLog>> logsByDay(String userId, DateTime day);

  Future<void> insertLog(WorkoutLog log);
}

class InMemoryWorkoutStore implements WorkoutStore {
  final List<Workout> _catalog = seedCatalog();
  final List<WorkoutLog> _logs = [];

  @override
  Future<List<Workout>> catalog() async => List.unmodifiable(_catalog);

  @override
  Future<Workout?> findWorkout(String workoutId) async {
    for (final workout in _catalog) {
      if (workout.id == workoutId) return workout;
    }
    return null;
  }

  @override
  Future<List<WorkoutLog>> logsByDay(String userId, DateTime day) async {
    return _logs.where((log) {
      return log.userId == userId &&
          log.completedAt.year == day.year &&
          log.completedAt.month == day.month &&
          log.completedAt.day == day.day;
    }).toList();
  }

  @override
  Future<void> insertLog(WorkoutLog log) async {
    _logs.add(log);
  }

  /// Danh sách bài tập gợi ý lấy từ bản thiết kế màn hình "Tập luyện".
  static List<Workout> seedCatalog() {
    return const [
      Workout(
        id: 'workout-cardio-nhe',
        name: 'Cardio nhẹ',
        durationMinutes: 20,
        caloriesBurned: 180,
        intensity: WorkoutIntensity.light,
        category: 'Đốt mỡ',
      ),
      Workout(
        id: 'workout-yoga',
        name: 'Yoga',
        durationMinutes: 15,
        caloriesBurned: 90,
        intensity: WorkoutIntensity.light,
        category: 'Thư giãn',
      ),
      Workout(
        id: 'workout-tap-suc-manh',
        name: 'Tập sức mạnh',
        durationMinutes: 30,
        caloriesBurned: 260,
        intensity: WorkoutIntensity.intense,
        category: 'Tăng cơ',
      ),
      Workout(
        id: 'workout-di-bo-nhanh',
        name: 'Đi bộ nhanh',
        durationMinutes: 25,
        caloriesBurned: 150,
        intensity: WorkoutIntensity.moderate,
        category: 'Tim mạch',
      ),
      Workout(
        id: 'workout-gian-co',
        name: 'Giãn cơ toàn thân',
        durationMinutes: 10,
        caloriesBurned: 60,
        intensity: WorkoutIntensity.light,
        category: 'Thư giãn',
      ),
    ];
  }
}
