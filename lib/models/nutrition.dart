/// Nhóm món ăn dùng cho thanh chọn nhanh trong màn hình "Thêm món ăn".
enum FoodCategory {
  vietnamese('vietnamese', 'Món Việt'),
  asian('asian', 'Món Tây'),
  drink('drink', 'Đồ uống'),
  other('other', 'Khác');

  const FoodCategory(this.storeName, this.label);

  final String storeName;
  final String label;

  static FoodCategory fromStoreName(String value) {
    return FoodCategory.values.firstWhere(
      (category) => category.storeName == value,
      orElse: () => FoodCategory.other,
    );
  }
}

/// Buổi ăn trong ngày. Dùng chung cho cả món ăn lẫn thực đơn.
enum MealSlot {
  breakfast('breakfast', 'Bữa sáng'),
  lunch('lunch', 'Bữa trưa'),
  dinner('dinner', 'Bữa tối'),
  snack('snack', 'Bữa phụ');

  const MealSlot(this.storeName, this.label);

  final String storeName;
  final String label;

  static MealSlot fromStoreName(String value) {
    return MealSlot.values.firstWhere(
      (slot) => slot.storeName == value,
      orElse: () => MealSlot.breakfast,
    );
  }
}

/// Món ăn trong danh mục (dữ liệu dùng chung, không thuộc riêng ai).
class FoodItem {
  final String id;
  final String name;
  final FoodCategory category;

  /// Năng lượng cho một phần ăn chuẩn.
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  /// Mô tả khối lượng một phần, ví dụ `1 tô (300g)`.
  final String servingLabel;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingLabel,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.storeName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'serving_label': servingLabel,
    };
  }

  factory FoodItem.fromMap(Map<String, Object?> map) {
    return FoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: FoodCategory.fromStoreName(map['category'] as String),
      calories: (map['calories'] as num).toInt(),
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      servingLabel: map['serving_label'] as String? ?? '1 phần',
    );
  }
}

/// Một món ăn người dùng đã thêm vào nhật ký dinh dưỡng của mình.
class MealEntry {
  final String id;
  final String userId;
  final String foodId;

  /// Tên món được lưu kèm để hiển thị lịch sử ngay cả khi món bị xóa khỏi
  /// danh mục.
  final String foodName;

  final MealSlot slot;

  /// Khối lượng thực tế đã ăn. [portion] = 1 nghĩa là đúng một phần chuẩn.
  final double portion;

  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime eatenAt;

  const MealEntry({
    required this.id,
    required this.userId,
    required this.foodId,
    required this.foodName,
    required this.slot,
    required this.portion,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.eatenAt,
  });

  /// Tạo bản ghi nhật ký từ một món trong danh mục.
  ///
  /// Khi [portion] khác 1 (ví dụ 1/2 phần), toàn bộ dinh dưỡng được chia
  /// theo tỉ lệ để số liệu tổng không bị sai.
  factory MealEntry.fromFood({
    required String id,
    required String userId,
    required FoodItem food,
    required MealSlot slot,
    required DateTime eatenAt,
    double portion = 1,
    int? caloriesOverride,
  }) {
    // Người dùng tự nhập calo: các chất dinh dưỡng được co giãn theo cùng tỉ
    // lệ để tỉ lệ protein/carb/fat của món vẫn giữ nguyên.
    final base = food.calories * portion;
    final scale =
        (caloriesOverride != null && base > 0) ? caloriesOverride / base : 1.0;
    return MealEntry(
      id: id,
      userId: userId,
      foodId: food.id,
      foodName: food.name,
      slot: slot,
      portion: portion,
      calories: caloriesOverride ?? base.round(),
      protein: food.protein * portion * scale,
      carbs: food.carbs * portion * scale,
      fat: food.fat * portion * scale,
      eatenAt: eatenAt,
    );
  }

  /// Bản sao với vài trường được đổi (dùng khi chép bữa hôm qua, sửa món...).
  MealEntry copyWith({
    String? id,
    String? foodId,
    String? foodName,
    MealSlot? slot,
    double? portion,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? eatenAt,
  }) {
    return MealEntry(
      id: id ?? this.id,
      userId: userId,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      slot: slot ?? this.slot,
      portion: portion ?? this.portion,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      eatenAt: eatenAt ?? this.eatenAt,
    );
  }

  String get portionLabel {
    if (portion == 1) return '1 phần';
    if (portion == 0.5) return '1/2 phần';
    return '${portion.toStringAsFixed(1)} phần';
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'food_id': foodId,
      'food_name': foodName,
      'slot': slot.storeName,
      'portion': portion,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'eaten_at': eatenAt.millisecondsSinceEpoch,
    };
  }

  factory MealEntry.fromMap(Map<String, Object?> map) {
    return MealEntry(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      foodId: map['food_id'] as String,
      foodName: map['food_name'] as String,
      slot: MealSlot.fromStoreName(map['slot'] as String),
      portion: (map['portion'] as num).toDouble(),
      calories: (map['calories'] as num).toInt(),
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      eatenAt: DateTime.fromMillisecondsSinceEpoch(
        (map['eaten_at'] as num).toInt(),
      ),
    );
  }
}

/// Tổng hợp dinh dưỡng của một ngày, tính sẵn để giao diện chỉ việc hiển thị.
class NutritionSummary {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final int calorieGoal;

  const NutritionSummary({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calorieGoal,
  });

  static const NutritionSummary empty = NutritionSummary(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    calorieGoal: 2000,
  );

  int get remainingCalories => calorieGoal - calories;

  /// Tỉ lệ đã nạp so với mục tiêu, luôn nằm trong khoảng 0..1 để thanh tiến
  /// trình không tràn khi người dùng nạp quá mục tiêu.
  double get calorieProgress {
    if (calorieGoal <= 0) return 0;
    return (calories / calorieGoal).clamp(0.0, 1.0);
  }

  int get caloriePercent => (calorieProgress * 100).round();

  /// Phần trăm thực so với mục tiêu, không bị chặn ở 100% (dùng khi ăn lố).
  int get rawPercent =>
      calorieGoal <= 0 ? 0 : (calories / calorieGoal * 100).round();

  /// Phần trăm năng lượng đến từ từng nhóm chất, dùng cho biểu đồ tròn.
  double get proteinPercent => _macroPercent(protein * 4);
  double get carbsPercent => _macroPercent(carbs * 4);
  double get fatPercent => _macroPercent(fat * 9);

  double _macroPercent(double macroCalories) {
    final total = protein * 4 + carbs * 4 + fat * 9;
    if (total <= 0) return 0;
    return macroCalories / total;
  }

  NutritionSummary copyWith({int? calorieGoal}) {
    return NutritionSummary(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      calorieGoal: calorieGoal ?? this.calorieGoal,
    );
  }
}
