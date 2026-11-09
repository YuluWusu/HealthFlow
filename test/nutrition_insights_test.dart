import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare/data/nutrition_repository.dart';
import 'package:healthcare/models/ingredient.dart';
import 'package:healthcare/models/nutrition.dart';
import 'package:healthcare/utils/nutrition_insights.dart';

DayNutrition _day(
  int d, {
  int calories = 2000,
  double protein = 100,
  double carbs = 250,
  double fat = 65,
  double sugar = 30,
  double sodium = 1500,
  double fiber = 30,
  double fruitGrams = 150,
}) {
  return DayNutrition(
    DateTime(2026, 10, d),
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    sugar: sugar,
    sodium: sodium,
    fiber: fiber,
    fruitGrams: fruitGrams,
    entries: 3,
  );
}

const _ingredients = [
  Ingredient(
    id: 'uc-ga-chin',
    name: 'Ức gà (chín)',
    group: 'Đạm',
    calories: 165,
    protein: 31,
    carbs: 0,
    fat: 3.6,
  ),
  Ingredient(
    id: 'bong-cai',
    name: 'Bông cải xanh',
    group: 'Rau củ',
    calories: 34,
    protein: 2.8,
    carbs: 6.6,
    fat: 0.4,
  ),
  Ingredient(
    id: 'oi',
    name: 'Ổi',
    group: 'Trái cây',
    calories: 68,
    protein: 2.6,
    carbs: 14.3,
    fat: 1,
  ),
];

void main() {
  group('Tiền tố nguyên liệu và bước gram', () {
    test('nhận cả ing_ lẫn ing-', () {
      expect(isIngredientFoodId('ing_com-trang'), isTrue);
      expect(isIngredientFoodId('ing-com-trang'), isTrue);
      expect(isIngredientFoodId('vn-001'), isFalse);
    });

    test('bước gram nhỏ khi ít, lớn khi nhiều', () {
      expect(gramStepUp(5), 5);
      expect(gramStepUp(20), 10);
      expect(gramStepUp(50), 50);
      expect(gramStepDown(5), 5);
      expect(gramStepDown(20), 5);
      expect(gramStepDown(50), 10);
      expect(gramStepDown(100), 50);
    });

    test('muối = natri × 2,5', () {
      expect(saltGramsOf(2000), closeTo(5, 1e-9));
    });
  });

  group('MealEntry với đường/natri/chất xơ', () {
    test('nhân theo khẩu phần và lưu/đọc lại được', () {
      const food = FoodItem(
        id: 'f1',
        name: 'Món thử',
        category: FoodCategory.vietnamese,
        calories: 300,
        protein: 10,
        carbs: 40,
        fat: 8,
        servingLabel: '1 phần',
        sugar: 10,
        sodium: 500,
        fiber: 2,
      );
      final entry = MealEntry.fromFood(
        id: 'm1',
        userId: 'u1',
        food: food,
        slot: MealSlot.lunch,
        eatenAt: DateTime(2026, 10, 1, 12),
        portion: 2,
      );
      expect(entry.sugar, closeTo(20, 1e-9));
      expect(entry.sodium, closeTo(1000, 1e-9));
      expect(entry.fiber, closeTo(4, 1e-9));

      final again = MealEntry.fromMap(entry.toMap());
      expect(again.hasMicro, isTrue);
      expect(again.sodium, closeTo(1000, 1e-9));
    });

    test('bản ghi cũ không có natri thì hasMicro = false', () {
      final legacy = MealEntry.fromMap({
        'id': 'm0',
        'user_id': 'u1',
        'food_id': 'f1',
        'food_name': 'Món cũ',
        'slot': 'lunch',
        'portion': 1.0,
        'calories': 100,
        'protein': 1.0,
        'carbs': 1.0,
        'fat': 1.0,
        'eaten_at': DateTime(2026, 10, 1).millisecondsSinceEpoch,
      });
      expect(legacy.hasMicro, isFalse);
      expect(legacy.sodium, 0);
    });
  });

  group('NutritionInsights', () {
    const limits = NutritionLimits(calorieGoal: 2000, weightKg: 60);

    test('chưa có dữ liệu thì báo chưa đủ dữ liệu', () {
      final out = NutritionInsights.analyze(
        report: NutritionReport.empty,
        limits: limits,
        ingredients: _ingredients,
        catalog: const [],
      );
      expect(out, hasLength(1));
      expect(out.single.title, 'Chưa đủ dữ liệu');
    });

    test('ăn cân đối thì chỉ có nhận xét tốt', () {
      final out = NutritionInsights.analyze(
        report: NutritionReport(days: [_day(1), _day(2)]),
        limits: limits,
        ingredients: _ingredients,
        catalog: const [],
      );
      expect(out.first.level, InsightLevel.good);
      expect(out.where((i) => i.level == InsightLevel.warn), isEmpty);
    });

    test('nhiều đường, mặn, thiếu đạm/xơ/trái cây thì cảnh báo và gợi ý', () {
      final bad = [
        for (var d = 1; d <= 3; d++)
          _day(
            d,
            protein: 30,
            carbs: 280,
            sugar: 80,
            sodium: 3500,
            fiber: 8,
            fruitGrams: 0,
          ),
      ];
      final out = NutritionInsights.analyze(
        report: NutritionReport(days: bad),
        limits: limits,
        ingredients: _ingredients,
        catalog: const [],
      );
      final titles = out.map((i) => i.title).toList();
      expect(titles, contains('Ăn khá nhiều đường'));
      expect(titles, contains('Ăn hơi mặn'));
      expect(titles, contains('Thiếu đạm (protein)'));
      expect(titles, contains('Ít chất xơ, nên ăn thêm rau'));
      expect(titles, contains('Ít trái cây'));
      expect(out.first.level, isNot(InsightLevel.good));

      final protein = out.firstWhere((i) => i.title == 'Thiếu đạm (protein)');
      expect(
        protein.foods.map((f) => f.label),
        contains('Ức gà (chín) · 100g'),
      );
    });
  });
}
