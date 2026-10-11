import 'ingredient.dart';
import 'nutrition.dart';

/// Một nguyên liệu trong công thức, đã quy ra dinh dưỡng cho đúng số gram.
class RecipeItem {
  const RecipeItem({
    required this.name,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
  });

  final String name;
  final double grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;

  /// Tính từ một [Ingredient] (dinh dưỡng trên 100 g) với [grams] gram.
  factory RecipeItem.fromIngredient(Ingredient ingredient, double grams) {
    final food = ingredient.toFoodItem();
    final k = grams / 100;
    return RecipeItem(
      name: ingredient.name,
      grams: grams,
      calories: ingredient.calories * k,
      protein: ingredient.protein * k,
      carbs: ingredient.carbs * k,
      fat: ingredient.fat * k,
      fiber: food.fiber * k,
      sugar: food.sugar * k,
      sodium: food.sodium * k,
    );
  }

  Map<String, Object?> toMap() => {
        'name': name,
        'grams': grams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
      };

  factory RecipeItem.fromMap(Map<String, Object?> m) => RecipeItem(
        name: m['name'] as String,
        grams: (m['grams'] as num).toDouble(),
        calories: (m['calories'] as num).toDouble(),
        protein: (m['protein'] as num).toDouble(),
        carbs: (m['carbs'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        fiber: (m['fiber'] as num?)?.toDouble() ?? 0,
        sugar: (m['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (m['sodium'] as num?)?.toDouble() ?? 0,
      );
}

/// Món tự nấu: gộp nhiều nguyên liệu theo gram, chia đều cho [servings] phần.
class Recipe {
  const Recipe({
    required this.id,
    required this.userId,
    required this.name,
    required this.servings,
    required this.items,
  });

  /// Tiền tố id của món sinh ra từ công thức.
  static const foodIdPrefix = 'recipe-';

  final String id;
  final String userId;
  final String name;
  final int servings;
  final List<RecipeItem> items;

  double _sum(double Function(RecipeItem) pick) =>
      items.fold(0.0, (a, b) => a + pick(b));

  double get totalGrams => _sum((i) => i.grams);
  double get totalCalories => _sum((i) => i.calories);
  double get totalProtein => _sum((i) => i.protein);
  double get totalCarbs => _sum((i) => i.carbs);
  double get totalFat => _sum((i) => i.fat);

  int get _n => servings < 1 ? 1 : servings;
  int get caloriesPerServing => (totalCalories / _n).round();
  int get gramsPerServing => (totalGrams / _n).round();

  static double _round1(double v) => (v * 10).round() / 10;

  /// Quy thành [FoodItem] (1 phần = 1/[servings] công thức) để dùng chung
  /// toàn bộ luồng nhật ký, giỏ món và thống kê hiện có.
  FoodItem toFoodItem() => FoodItem(
        id: '$foodIdPrefix$id',
        name: name,
        category: FoodCategory.other,
        calories: caloriesPerServing,
        protein: _round1(totalProtein / _n),
        carbs: _round1(totalCarbs / _n),
        fat: _round1(totalFat / _n),
        servingLabel: '1 phần (${gramsPerServing}g)',
        fiber: _round1(_sum((i) => i.fiber) / _n),
        sugar: _round1(_sum((i) => i.sugar) / _n),
        sodium: (_sum((i) => i.sodium) / _n).roundToDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'servings': servings,
        'items': [for (final i in items) i.toMap()],
      };

  factory Recipe.fromMap(Map<String, Object?> m) => Recipe(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        servings: (m['servings'] as num).toInt(),
        items: [
          for (final raw in m['items'] as List<dynamic>)
            RecipeItem.fromMap(Map<String, Object?>.from(raw as Map)),
        ],
      );
}
