import 'nutrition.dart';

const String kIngredientIdPrefix = 'ing_';

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
    this.sugar = 0,
    this.sodium = 0,
    this.fiber = 0,
  });

  /// Tên nhóm gia vị trong `ingredients.json` (muối, đường, nước mắm...).
  static const String seasoningGroup = 'Gia vị';

  /// Tên nhóm trái cây trong `ingredients.json`.
  static const String fruitGroup = 'Trái cây';

  final String id;
  final String name;
  final String group;

  /// Các giá trị dưới đây đều trên 100 g.
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  /// Đường (g), natri (mg), chất xơ (g) trên 100 g (số ước tính).
  final double sugar;
  final double sodium;
  final double fiber;

  bool get isSeasoning => group == seasoningGroup;
  bool get isFruit => group == fruitGroup;

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'] as String,
        name: j['name'] as String,
        group: j['group'] as String? ?? '',
        calories: (j['calories'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        carbs: (j['carbs'] as num).toDouble(),
        fat: (j['fat'] as num).toDouble(),
        sugar: (j['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (j['sodium'] as num?)?.toDouble() ?? 0,
        fiber: (j['fiber'] as num?)?.toDouble() ?? 0,
      );

  int caloriesFor(num grams) => (calories * grams / 100).round();
  double proteinFor(num grams) => protein * grams / 100;
  double carbsFor(num grams) => carbs * grams / 100;
  double fatFor(num grams) => fat * grams / 100;
  double sugarFor(num grams) => sugar * grams / 100;
  double sodiumFor(num grams) => sodium * grams / 100;
  double fiberFor(num grams) => fiber * grams / 100;

  /// Quy về [FoodItem] với một "phần" = 100 g, để dùng chung toàn bộ luồng
  /// nhật ký/giỏ/thống kê hiện có: ăn `g` gram = `g / 100` phần.
  FoodItem toFoodItem() => FoodItem(
        id: '$kIngredientIdPrefix$id',
        name: name,
        category: FoodCategory.other,
        calories: calories.round(),
        protein: protein,
        carbs: carbs,
        fat: fat,
        servingLabel: '100g',
        sugar: sugar,
        sodium: sodium,
        fiber: fiber,
      );
}
