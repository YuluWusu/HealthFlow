import 'package:flutter/foundation.dart';

import '../data/nutrition_store.dart';
import '../models/nutrition.dart';

/// Truy vấn danh mục món ăn và nhật ký ăn uống.
class NutritionRepository extends ChangeNotifier {
  NutritionRepository({NutritionStore? store})
      : _store = store ?? InMemoryNutritionStore();

  final NutritionStore _store;

  List<FoodItem> _catalog = const [];
  List<MealEntry> _todayEntries = const [];
  NutritionSummary _summary = NutritionSummary.empty;

  List<FoodItem> get catalog => _catalog;
  List<MealEntry> get todayEntries => _todayEntries;
  NutritionSummary get summary => _summary;

  /// Nạp danh mục món ăn (chỉ cần gọi một lần sau khi đăng nhập).
  Future<void> loadCatalog() async {
    _catalog = await _store.catalog();
    notifyListeners();
  }

  /// Nạp nhật ký của một ngày và tính sẵn phần tổng hợp.
  Future<void> loadDay({
    required String userId,
    required int calorieGoal,
    DateTime? day,
  }) async {
    final target = day ?? DateTime.now();
    _todayEntries = await _store.entriesByDay(userId, target);
    _summary = _buildSummary(_todayEntries, calorieGoal);
    notifyListeners();
  }

  /// Tìm món theo từ khóa và nhóm, phục vụ ô tìm kiếm ở màn hình thêm món ăn.
  List<FoodItem> search({
    String keyword = '',
    FoodCategory? category,
  }) {
    final query = keyword.trim().toLowerCase();
    return _catalog.where((food) {
      final matchCategory = category == null || food.category == category;
      final matchKeyword = query.isEmpty || food.name.toLowerCase().contains(query);
      return matchCategory && matchKeyword;
    }).toList();
  }

  /// Tên các món đã ăn trong một buổi, nối lại thành một dòng cho thẻ bữa ăn.
  String mealDescription(MealSlot slot) {
    final names = _todayEntries
        .where((entry) => entry.slot == slot)
        .map((entry) => entry.foodName)
        .toList();
    if (names.isEmpty) return 'Chưa thêm món ăn';
    return names.join(' + ');
  }

  /// Tổng năng lượng của một buổi ăn.
  int mealCalories(MealSlot slot) {
    return _todayEntries
        .where((entry) => entry.slot == slot)
        .fold(0, (sum, entry) => sum + entry.calories);
  }

  /// Thêm một món vào nhật ký.
  ///
  /// Trả về bản ghi vừa tạo để giao diện có thể hiển thị thông báo xác nhận.
  Future<MealEntry> addFood({
    required String userId,
    required FoodItem food,
    required MealSlot slot,
    required int calorieGoal,
    double portion = 1,
    DateTime? eatenAt,
  }) async {
    final entry = MealEntry.fromFood(
      id: 'meal-${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      food: food,
      slot: slot,
      portion: portion,
      eatenAt: eatenAt ?? DateTime.now(),
    );
    await _store.insertEntry(entry);
    await loadDay(userId: userId, calorieGoal: calorieGoal);
    return entry;
  }

  Future<void> removeEntry({
    required String userId,
    required String entryId,
    required int calorieGoal,
  }) async {
    await _store.deleteEntry(entryId);
    await loadDay(userId: userId, calorieGoal: calorieGoal);
  }

  void clear() {
    _todayEntries = const [];
    _summary = NutritionSummary.empty;
    notifyListeners();
  }

  static NutritionSummary _buildSummary(
    List<MealEntry> entries,
    int calorieGoal,
  ) {
    var calories = 0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    for (final entry in entries) {
      calories += entry.calories;
      protein += entry.protein;
      carbs += entry.carbs;
      fat += entry.fat;
    }
    return NutritionSummary(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      calorieGoal: calorieGoal,
    );
  }
}
