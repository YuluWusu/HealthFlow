import '../utils/sha256.dart';
import '../utils/health_assessor.dart';

/// Tài khoản người dùng của ứng dụng HealthFlow.
///
/// [toMap] / [fromMap] được viết theo đúng dạng bản ghi của `sqflite`
/// (kiểu dữ liệu chỉ gồm int, double, String, null) nên khi chuyển sang
/// SQLite chỉ cần đổi lớp lưu trữ, không phải sửa model này.
class User {
  final String id;
  final String fullName;
  final String email;

  /// Mật khẩu đã băm, không bao giờ lưu mật khẩu gốc.
  final String passwordHash;

  final double heightCm;

  /// Cân nặng hiện tại, sao chép từ chỉ số mới nhất để hiển thị nhanh.
  final double weightKg;

  final int dailyCalorieGoal;

  /// Mục tiêu sức khỏe người dùng tự mô tả, ví dụ "Giảm cân".
  final String healthGoal;

  /// Giới tính: 'male' hoặc 'female'
  final String gender;

  /// Đường dẫn tệp ảnh đại diện trên thiết bị (null nếu chưa đặt ảnh).
  final String? avatarPath;

  final DateTime createdAt;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    this.heightCm = 165,
    this.weightKg = 55,
    this.dailyCalorieGoal = 2000,
    this.healthGoal = 'Giữ dáng',
    this.gender = 'male',
    this.avatarPath,
    required this.createdAt,
  });

  /// Chỉ số khối cơ thể, tính từ chiều cao và cân nặng hiện tại.
  double get bmi => HealthAssessor.calculateBmi(weightKg, heightCm) ?? 0;

  /// Xếp loại BMI theo chuẩn WHO Châu Á, dùng chung với module Health
  /// (xem [HealthAssessor.bmi]).
  String get bmiLabel => HealthAssessor.bmi(bmi).label;

  /// Chữ cái đầu của tên, dùng làm ảnh đại diện thay thế.
  String get initial {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  User copyWith({
    String? fullName,
    String? email,
    String? passwordHash,
    double? heightCm,
    double? weightKg,
    int? dailyCalorieGoal,
    String? healthGoal,
    String? gender,
    String? avatarPath,
  }) {
    return User(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      healthGoal: healthGoal ?? this.healthGoal,
      gender: gender ?? this.gender,
      avatarPath: avatarPath != null
          ? (avatarPath.isEmpty ? null : avatarPath)
          : this.avatarPath,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'password_hash': passwordHash,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'daily_calorie_goal': dailyCalorieGoal,
      'health_goal': healthGoal,
      'gender': gender,
      'avatar_path': avatarPath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      heightCm: (map['height_cm'] as num?)?.toDouble() ?? 165,
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 55,
      dailyCalorieGoal: (map['daily_calorie_goal'] as num?)?.toInt() ?? 2000,
      healthGoal: map['health_goal'] as String? ?? 'Giữ dáng',
      gender: map['gender'] as String? ?? 'male',
      avatarPath: map['avatar_path'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Băm mật khẩu bằng SHA-256 kèm "muối" theo email để hai tài khoản dùng
/// cùng mật khẩu vẫn cho ra giá trị băm khác nhau.
///
/// Lưu ý: cách này phù hợp cho đồ án môn học, chưa phải chuẩn an toàn của
/// sản phẩm thật (sản phẩm thật nên dùng bcrypt/argon2 phía máy chủ).
String hashPassword(String rawPassword, String email) {
  final salt = email.trim().toLowerCase();
  return sha256Hex('healthflow::$salt::$rawPassword');
}
