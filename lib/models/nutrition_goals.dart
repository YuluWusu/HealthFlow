import 'dart:math' as math;

/// Chế độ ăn theo mục tiêu. Mỗi chế độ có sẵn hệ số calo và tỉ lệ macro.
///
/// Bốn chế độ đầu khớp với [healthGoal] trong hồ sơ ("Giảm cân", "Giữ dáng",
/// "Tăng cân", "Tăng cơ") ở màn hình Mục tiêu sức khỏe; "Eat clean" là chế độ
/// riêng của phần dinh dưỡng, ứng với hồ sơ "Giữ dáng".
enum DietMode {
  loseWeight(
    storeName: 'lose',
    label: 'Giảm cân',
    healthGoal: 'Giảm cân',
    summary: 'Thâm hụt nhẹ, nhiều đạm để giữ cơ và no lâu.',
    calorieFactor: 0.82,
    proteinPct: 30,
    carbsPct: 40,
    fatPct: 30,
  ),
  maintain(
    storeName: 'maintain',
    label: 'Giữ dáng',
    healthGoal: 'Giữ dáng',
    summary: 'Cân bằng để giữ cân nặng hiện tại.',
    calorieFactor: 1.0,
    proteinPct: 20,
    carbsPct: 50,
    fatPct: 30,
  ),
  gainMuscle(
    storeName: 'muscle',
    label: 'Tăng cơ',
    healthGoal: 'Tăng cơ',
    summary: 'Dư nhẹ calo, đạm cao để xây cơ cùng tập luyện.',
    calorieFactor: 1.10,
    proteinPct: 30,
    carbsPct: 45,
    fatPct: 25,
  ),
  gainWeight(
    storeName: 'gain',
    label: 'Tăng cân',
    healthGoal: 'Tăng cân',
    summary: 'Dư calo rõ rệt, nhiều tinh bột để lên cân.',
    calorieFactor: 1.18,
    proteinPct: 20,
    carbsPct: 52,
    fatPct: 28,
  ),
  eatClean(
    storeName: 'clean',
    label: 'Eat clean',
    healthGoal: 'Giữ dáng',
    summary: 'Ít đường, ít mặn, nhiều xơ; ưu tiên thực phẩm nguyên bản.',
    calorieFactor: 1.0,
    proteinPct: 25,
    carbsPct: 40,
    fatPct: 35,
  );

  const DietMode({
    required this.storeName,
    required this.label,
    required this.healthGoal,
    required this.summary,
    required this.calorieFactor,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
  });

  final String storeName;
  final String label;

  /// Giá trị tương ứng của `User.healthGoal`.
  final String healthGoal;
  final String summary;

  /// Nhân với mức calo duy trì để ra mục tiêu calo gợi ý.
  final double calorieFactor;

  /// Tỉ lệ % năng lượng từ đạm / carb / béo (cộng lại 100).
  final int proteinPct;
  final int carbsPct;
  final int fatPct;

  static DietMode fromStoreName(String? value) {
    for (final m in DietMode.values) {
      if (m.storeName == value) return m;
    }
    return DietMode.maintain;
  }

  /// Chế độ mặc định theo mục tiêu sức khỏe trong hồ sơ.
  static DietMode fromHealthGoal(String healthGoal) {
    switch (healthGoal) {
      case 'Giảm cân':
        return DietMode.loseWeight;
      case 'Tăng cân':
        return DietMode.gainWeight;
      case 'Tăng cơ':
        return DietMode.gainMuscle;
      default:
        return DietMode.maintain;
    }
  }

  /// Giới hạn đường/natri/xơ riêng cho chế độ (eat clean chặt hơn).
  NutrientLimits limitsFor(int calorieGoal) {
    final strict = this == DietMode.eatClean;
    final sugarShare = strict ? 0.05 : 0.10; // % năng lượng từ đường
    final fiber = (calorieGoal / 1000 * 14).clamp(20, 40).toDouble();
    return NutrientLimits(
      sodiumMaxMg: strict ? 1500 : 2000,
      sugarMaxG: (calorieGoal * sugarShare / 4).roundToDouble(),
      fiberMinG: fiber.roundToDouble(),
    );
  }
}

/// Ngưỡng khuyến nghị trong ngày cho natri, đường và chất xơ.
class NutrientLimits {
  const NutrientLimits({
    required this.sodiumMaxMg,
    required this.sugarMaxG,
    required this.fiberMinG,
  });

  /// Natri tối đa (mg). Khuyến nghị chung: dưới 2.000 mg/ngày.
  final double sodiumMaxMg;

  /// Đường tối đa (g): 10% năng lượng (5% khi eat clean).
  final double sugarMaxG;

  /// Chất xơ tối thiểu (g): khoảng 14 g trên mỗi 1.000 kcal.
  final double fiberMinG;
}

/// Mục tiêu macro (gram/ngày).
class MacroTargets {
  const MacroTargets({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;
}

/// Mục tiêu macro do người dùng tự đặt: theo % năng lượng hoặc theo gram.
class MacroGoalConfig {
  const MacroGoalConfig({
    required this.byPercent,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// `true`: các số là % năng lượng (cộng lại 100). `false`: là gram.
  final bool byPercent;
  final double protein;
  final double carbs;
  final double fat;

  Map<String, Object?> toMap() => {
        'pct': byPercent,
        'p': protein,
        'c': carbs,
        'f': fat,
      };

  static MacroGoalConfig? fromMap(Map<String, Object?>? m) {
    if (m == null) return null;
    final p = (m['p'] as num?)?.toDouble();
    final c = (m['c'] as num?)?.toDouble();
    final f = (m['f'] as num?)?.toDouble();
    if (p == null || c == null || f == null) return null;
    return MacroGoalConfig(
      byPercent: m['pct'] as bool? ?? true,
      protein: p,
      carbs: c,
      fat: f,
    );
  }
}

/// Quy mục tiêu macro ra gram/ngày.
///
/// Ưu tiên cấu hình tự đặt [custom]; không có thì dùng tỉ lệ của [mode].
/// Đổi % ra gram theo 4 kcal/g (đạm, carb) và 9 kcal/g (béo).
MacroTargets resolveMacroTargets({
  required int calorieGoal,
  required DietMode mode,
  MacroGoalConfig? custom,
}) {
  if (custom != null && !custom.byPercent) {
    return MacroTargets(
      proteinG: custom.protein.round(),
      carbsG: custom.carbs.round(),
      fatG: custom.fat.round(),
    );
  }
  final p = custom?.protein ?? mode.proteinPct.toDouble();
  final c = custom?.carbs ?? mode.carbsPct.toDouble();
  final f = custom?.fat ?? mode.fatPct.toDouble();
  return MacroTargets(
    proteinG: (calorieGoal * p / 100 / 4).round(),
    carbsG: (calorieGoal * c / 100 / 4).round(),
    fatG: (calorieGoal * f / 100 / 9).round(),
  );
}

/// Mức calo duy trì ước tính (công thức Mifflin–St Jeor, hoạt động nhẹ ×1,375).
///
/// Hồ sơ chưa lưu tuổi nên mặc định 25 tuổi; đây chỉ là con số tham khảo để
/// gợi ý mục tiêu calo, người dùng vẫn tự chỉnh được.
int estimateMaintenanceKcal({
  required double weightKg,
  required double heightCm,
  required String gender,
  int age = 25,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  final bmr = gender == 'female' ? base - 161 : base + 5;
  return math.max(1000, (bmr * 1.375).round());
}

/// Mục tiêu calo gợi ý cho [mode], làm tròn 50 kcal.
int suggestedCalorieGoal({
  required DietMode mode,
  required double weightKg,
  required double heightCm,
  required String gender,
}) {
  final maintenance = estimateMaintenanceKcal(
    weightKg: weightKg,
    heightCm: heightCm,
    gender: gender,
  );
  final raw = maintenance * mode.calorieFactor;
  return ((raw / 50).round() * 50).clamp(1200, 5000).toInt();
}
