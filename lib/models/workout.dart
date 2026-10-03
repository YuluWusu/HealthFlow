/// Cường độ buổi tập, dùng cho nhãn trên thẻ bài tập gợi ý.
enum WorkoutIntensity {
  light('light', 'Nhẹ'),
  moderate('moderate', 'Vừa'),
  intense('intense', 'Cao');

  const WorkoutIntensity(this.storeName, this.label);

  final String storeName;
  final String label;

  static WorkoutIntensity fromStoreName(String value) {
    return WorkoutIntensity.values.firstWhere(
      (intensity) => intensity.storeName == value,
      orElse: () => WorkoutIntensity.light,
    );
  }
}

/// Bài tập gợi ý trong danh mục của ứng dụng.
class Workout {
  final String id;
  final String name;
  final int durationMinutes;
  final int caloriesBurned;
  final WorkoutIntensity intensity;

  /// Nhóm bài tập, ví dụ `Cardio`, `Yoga`, `Sức mạnh`.
  final String category;

  const Workout({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.intensity,
    required this.category,
  });

  /// Nhãn phụ trên thẻ, ví dụ `20 phút · Đốt mỡ`.
  String get subtitle => '$durationMinutes phút · $category';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'duration_minutes': durationMinutes,
      'calories_burned': caloriesBurned,
      'intensity': intensity.storeName,
      'category': category,
    };
  }

  factory Workout.fromMap(Map<String, Object?> map) {
    return Workout(
      id: map['id'] as String,
      name: map['name'] as String,
      durationMinutes: (map['duration_minutes'] as num).toInt(),
      caloriesBurned: (map['calories_burned'] as num).toInt(),
      intensity: WorkoutIntensity.fromStoreName(map['intensity'] as String),
      category: map['category'] as String? ?? 'Khác',
    );
  }
}

/// Một buổi tập người dùng đã hoàn thành trong ngày.
class WorkoutLog {
  final String id;
  final String userId;
  final String workoutId;
  final String workoutName;
  final int minutes;
  final int caloriesBurned;
  final DateTime completedAt;

  const WorkoutLog({
    required this.id,
    required this.userId,
    required this.workoutId,
    required this.workoutName,
    required this.minutes,
    required this.caloriesBurned,
    required this.completedAt,
  });

  factory WorkoutLog.fromWorkout({
    required String id,
    required String userId,
    required Workout workout,
    required DateTime completedAt,
  }) {
    return WorkoutLog(
      id: id,
      userId: userId,
      workoutId: workout.id,
      workoutName: workout.name,
      minutes: workout.durationMinutes,
      caloriesBurned: workout.caloriesBurned,
      completedAt: completedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'workout_id': workoutId,
      'workout_name': workoutName,
      'minutes': minutes,
      'calories_burned': caloriesBurned,
      'completed_at': completedAt.millisecondsSinceEpoch,
    };
  }

  factory WorkoutLog.fromMap(Map<String, Object?> map) {
    return WorkoutLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      workoutId: map['workout_id'] as String,
      workoutName: map['workout_name'] as String,
      minutes: (map['minutes'] as num).toInt(),
      caloriesBurned: (map['calories_burned'] as num).toInt(),
      completedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['completed_at'] as num).toInt(),
      ),
    );
  }
}
