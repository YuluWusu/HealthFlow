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

  group('Đồ uống gắn với nước uống', () {
    test('ghi đồ uống vào bữa thì nước tăng, xóa thì nước giảm lại', () async {
      final repo = NutritionRepository();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000);
      repo.addToCart(food);
      repo.addToCart(drink); // nhãn không ghi ml -> mặc định 250 ml
      await repo.commitCart(
        userId: 'u1',
        slot: MealSlot.lunch,
        calorieGoal: 2000,
      );
      expect(repo.waterMl, 250);

      final entry = repo.todayEntries.firstWhere((e) => e.foodId == 'f2');
      expect(entry.waterMl, 250);
      await repo.removeEntry(
        userId: 'u1',
        entryId: entry.id,
        calorieGoal: 2000,
      );
      expect(repo.waterMl, 0);
    });

    test('đọc dung tích từ nhãn khẩu phần, món ăn thường không tính', () {
      const orange = FoodItem(
        id: 'f3',
        name: 'Nước cam',
        category: FoodCategory.drink,
        calories: 110,
        protein: 2,
        carbs: 26,
        fat: 0,
        servingLabel: '1 ly (330ml)',
      );
      expect(drinkMlOf(orange), 330);
      expect(drinkMlOf(food), 0);
    });

    test('đặt dung tích 1 cốc nước', () async {
      final repo = NutritionRepository();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000);
      expect(repo.cupMl, 250);
      await repo.setCupMl(userId: 'u1', ml: 500);
      expect(repo.cupMl, 500);
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

    test('nhớ lượng nước gần nhất và hoàn tác từng lần', () async {
      final repo = NutritionRepository();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000);
      expect(repo.lastWaterStep, 250);
      await repo.addWater(userId: 'u1', deltaMl: 500);
      expect(repo.lastWaterStep, 500);
      await repo.addWater(userId: 'u1', deltaMl: 330);
      expect(repo.waterMl, 830);
      expect(repo.canUndoWater, isTrue);
      expect(await repo.undoWater(userId: 'u1'), 330);
      expect(repo.waterMl, 500);
      await repo.undoWater(userId: 'u1');
      expect(repo.waterMl, 0);
      expect(repo.canUndoWater, isFalse);
    });

    test('thống kê nước nhiều ngày, ngày không uống là 0', () async {
      final repo = NutritionRepository();
      final today = DateTime.now();
      await repo.loadDay(userId: 'u1', calorieGoal: 2000, day: today);
      await repo.addWater(userId: 'u1', deltaMl: 1500);
      await repo.selectDay(DateTime(today.year, today.month, today.day - 2));
      await repo.addWater(userId: 'u1', deltaMl: 750);
      final data = await repo.waterLastDays('u1', today, days: 7);
      expect(data.length, 7);
      expect(data.last.ml, 1500);
      expect(data[4].ml, 750);
      expect(data.first.ml, 0);
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
