import 'package:flutter/foundation.dart';

import '../data/nutrition_store.dart';
import '../models/nutrition.dart';
import 'usda_food_service.dart';
import 'vietnam_food_source.dart';

/// Truy vấn danh mục món ăn và nhật ký ăn uống.
///
/// Danh mục gồm:
///  - Món Việt Nam: đọc từ file Excel (assets/data/vn_foods.json).
///  - Món quốc tế: tra cứu USDA FoodData Central khi người dùng tìm kiếm,
///    kèm vài món có sẵn trong [NutritionStore] để dùng khi offline.
class NutritionRepository extends ChangeNotifier {
  NutritionRepository({
    NutritionStore? store,
    VietnamFoodSource? vietnam,
    UsdaFoodService? usda,
  })  : _store = store ?? InMemoryNutritionStore(),
        _vietnam = vietnam ?? VietnamFoodSource(),
        _usda = usda ?? UsdaFoodService();

  final NutritionStore _store;
  final VietnamFoodSource _vietnam;
  final UsdaFoodService _usda;

  List<FoodItem> _catalog = const [];
  List<MealEntry> _todayEntries = const [];
  NutritionSummary _summary = NutritionSummary.empty;

  // Ngày đang xem trên tab "Hôm nay" (chỉ lấy phần ngày, bỏ giờ).
  DateTime _selectedDay = _dateOnly(DateTime.now());
  String? _userId;
  int _calorieGoal = NutritionSummary.empty.calorieGoal;

  List<FoodItem> get catalog => _catalog;
  List<MealEntry> get todayEntries => _todayEntries;
  NutritionSummary get summary => _summary;
  bool get usdaUsesDemoKey => _usda.usesDemoKey;

  /// Ngày đang được xem (đã bỏ phần giờ).
  DateTime get selectedDay => _selectedDay;
  bool get isToday => _selectedDay == _dateOnly(DateTime.now());
  bool get isFutureDay => _selectedDay.isAfter(_dateOnly(DateTime.now()));

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Chuyển sang xem một ngày khác và nạp lại nhật ký của ngày đó.
  Future<void> selectDay(DateTime day) async {
    _selectedDay = _dateOnly(day);
    final userId = _userId;
    if (userId == null) {
      notifyListeners();
      return;
    }
    await loadDay(userId: userId, calorieGoal: _calorieGoal);
  }

  /// Nạp danh mục món ăn (chỉ cần gọi một lần sau khi đăng nhập).
  Future<void> loadCatalog() async {
    List<FoodItem> vietnamese = const [];
    try {
      vietnamese = await _vietnam.load();
    } catch (e) {
      debugPrint('Không đọc được vn_foods.json: $e');
    }

    final seed = await _store.catalog();
    // Món Việt trong seed cũ bị thay bằng dữ liệu Excel; giữ lại món quốc tế
    // làm dữ liệu offline.
    final fallback = vietnamese.isEmpty
        ? seed
        : seed.where((f) => f.category != FoodCategory.vietnamese);

    _catalog = List.unmodifiable([...vietnamese, ...fallback]);
    notifyListeners();
  }

  /// Nạp nhật ký của một ngày và tính sẵn phần tổng hợp.
  Future<void> loadDay({
    required String userId,
    required int calorieGoal,
    DateTime? day,
  }) async {
    // Không truyền [day] thì dùng ngày đang xem (mặc định là hôm nay).
    if (day != null) _selectedDay = _dateOnly(day);
    _userId = userId;
    _calorieGoal = calorieGoal;
    _todayEntries = await _store.entriesByDay(userId, _selectedDay);
    _summary = _buildSummary(_todayEntries, calorieGoal);
    notifyListeners();
  }

  /// Tìm món trong danh mục có sẵn (Excel + dữ liệu offline).
  List<FoodItem> search({
    String keyword = '',
    FoodCategory? category,
  }) {
    final query = _fold(keyword.trim());
    return _catalog.where((food) {
      final matchCategory = category == null || food.category == category;
      final matchKeyword = query.isEmpty || _fold(food.name).contains(query);
      return matchCategory && matchKeyword;
    }).toList();
  }

  /// Tra cứu món quốc tế trên USDA. Ném [UsdaException] khi lỗi mạng/key.
  Future<List<CatalogFood>> searchUsda(String keyword) =>
      _usda.search(keyword);

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
    int? customCalories,
  }) async {
    final entry = MealEntry.fromFood(
      id: 'meal-${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      food: food,
      slot: slot,
      portion: portion,
      eatenAt: eatenAt ?? _eatenAtForSelectedDay(),
      caloriesOverride: customCalories,
    );
    await _store.insertEntry(entry);
    await loadDay(userId: userId, calorieGoal: calorieGoal);
    return entry;
  }

  /// Món thêm khi đang xem ngày khác sẽ được ghi vào đúng ngày đó
  /// (giữ giờ hiện tại để sắp xếp trong ngày vẫn đúng thứ tự).
  DateTime _eatenAtForSelectedDay() {
    final now = DateTime.now();
    if (isToday) return now;
    return DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      now.hour,
      now.minute,
    );
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
    _selectedDay = _dateOnly(DateTime.now());
    _userId = null;
    notifyListeners();
  }

  /// Bỏ dấu tiếng Việt để gõ "pho bo" vẫn tìm ra "Phở Bò".
  static String _fold(String input) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
    return buffer.toString();
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
