import '../utils/nutrient_estimator.dart';
import 'nutrition.dart';

/// Nguyên liệu/thực phẩm đơn lẻ, dinh dưỡng tính trên 100 g.
///
/// Dùng cho cách ăn "theo định lượng": người dùng tự nấu, cân được bao nhiêu
/// gram thì nhập bấy nhiêu, không cần có sẵn món trong danh mục.
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.group,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String id;
  final String name;
  final String group;

  /// Các giá trị dưới đây đều trên 100 g.
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'] as String,
        name: j['name'] as String,
        group: j['group'] as String? ?? '',
        calories: (j['calories'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        carbs: (j['carbs'] as num).toDouble(),
        fat: (j['fat'] as num).toDouble(),
      );

  int caloriesFor(num grams) => (calories * grams / 100).round();
  double proteinFor(num grams) => protein * grams / 100;
  double carbsFor(num grams) => carbs * grams / 100;
  double fatFor(num grams) => fat * grams / 100;

  /// Quy về [FoodItem] với một "phần" = 100 g, để dùng chung toàn bộ luồng
  /// nhật ký/giỏ/thống kê hiện có: ăn `g` gram = `g / 100` phần.
  FoodItem toFoodItem() {
    // Xơ/đường/natri chưa có trong bảng nguyên liệu nên ước tính theo tên, nhóm.
    final est = NutrientEstimator.forIngredient(name, 100);
    return FoodItem(
      id: '$kIngredientIdPrefix$id',
      name: name,
      category: FoodCategory.other,
      calories: calories.round(),
      protein: protein,
      carbs: carbs,
      fat: fat,
      servingLabel: '100g',
      fiber: NutrientEstimator.fiberPer100g(name, group),
      sugar: est.sugar,
      sodium: est.sodium,
    );
  }
}
