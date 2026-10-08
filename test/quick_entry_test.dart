import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare/data/nutrition_repository.dart';
import 'package:healthcare/models/nutrition.dart';

void main() {
  summaryTests();

  const food = FoodItem(
    id: 'f1',
    name: 'Phở bò',
    category: FoodCategory.vietnamese,
    calories: 350,
    protein: 25,
    carbs: 45,
    fat: 12,
    servingLabel: '1 tô',
  );
  const drink = FoodItem(
    id: 'f2',
    name: 'Cà phê đen',
    category: FoodCategory.drink,
    calories: 10,
    protein: 0,
    carbs: 1,
    fat: 0,
    servingLabel: '1 ly',
  );

  group('Giỏ món', () {
    test('thêm nhiều món rồi ghi vào một bữa, giỏ được dọn sạch', () async {
      final repo = NutritionRepository();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000);
      repo.addToCart(food);
      repo.addToCart(food); // cùng món -> cộng phần
      repo.addToCart(drink);
      expect(repo.cartCount, 2);
      expect(repo.cartPortionOf('f1'), 2);
      expect(repo.cartCalories, 710);

      await repo.commitCart(
        userId: 'u1',
        slot: MealSlot.breakfast,
        calorieGoal: 2000,
      );
      expect(repo.cartCount, 0);
      expect(repo.mealCalories(MealSlot.breakfast), 710);
    });
  });

  group('Combo, nước uống, sửa món', () {
    test('lưu combo rồi thêm combo vào bữa', () async {
      final repo = NutritionRepository();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000);
      repo.addToCart(food);
      repo.addToCart(drink);
      await repo.saveCombo(userId: 'u1', name: 'Bữa sáng', items: repo.cart);
      expect(repo.combos.single.calories, 360);

      await repo.addCombo(
        userId: 'u1',
        combo: repo.combos.single,
        slot: MealSlot.breakfast,
        calorieGoal: 2000,
      );
      expect(repo.mealCalories(MealSlot.breakfast), 360);
    });

    test('cộng nước 250 ml và không âm', () async {
      final repo = NutritionRepository();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000);
      await repo.addWater(userId: 'u1', deltaMl: 250);
      await repo.addWater(userId: 'u1', deltaMl: 250);
      expect(repo.waterMl, 500);
      await repo.addWater(userId: 'u1', deltaMl: -1000);
      expect(repo.waterMl, 0);
    });

    test('đổi món tại chỗ giữ nguyên buổi ăn', () async {
      final repo = NutritionRepository();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000);
      final entry = await repo.addFood(
        userId: 'u1',
        food: food,
        slot: MealSlot.lunch,
        calorieGoal: 2000,
      );
      await repo.replaceEntryFood(
        entry: entry,
        food: drink,
        portion: 2,
        calorieGoal: 2000,
      );
      expect(repo.todayEntries.single.foodName, 'Cà phê đen');
      expect(repo.todayEntries.single.slot, MealSlot.lunch);
      expect(repo.mealCalories(MealSlot.lunch), 20);
    });

    test('xóa rồi hoàn tác khôi phục đúng dòng', () async {
      final repo = NutritionRepository();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000);
      final entry = await repo.addFood(
        userId: 'u1',
        food: food,
        slot: MealSlot.dinner,
        calorieGoal: 2000,
      );
      await repo.removeEntry(
        userId: 'u1',
        entryId: entry.id,
        calorieGoal: 2000,
      );
      expect(repo.todayEntries, isEmpty);
      await repo.restoreEntry(entry: entry, calorieGoal: 2000);
      expect(repo.todayEntries.single.id, entry.id);
    });

    test('mục tiêu nước theo cân nặng, giới hạn 1,5–4 L', () {
      expect(NutritionRepository.waterGoalFor(55), 1800);
      expect(NutritionRepository.waterGoalFor(30), 1500);
      expect(NutritionRepository.waterGoalFor(200), 4000);
    });
  });
}

void summaryTests() {
  group('NutritionSummary', () {
    test('rawPercent không bị chặn ở 100% khi ăn lố', () {
      const s = NutritionSummary(
        calories: 2500,
        protein: 0,
        carbs: 0,
        fat: 0,
        calorieGoal: 2000,
      );
      expect(s.rawPercent, 125);
      expect(s.caloriePercent, 100);
    });
  });
}
