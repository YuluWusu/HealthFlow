import 'package:flutter/foundation.dart';

import '../data/nutrition_store.dart';
import '../models/meal_combo.dart';
import '../models/nutrition.dart';
import 'usda_food_service.dart';
import 'vietnam_food_source.dart';

/// Tổng calo ăn vào của một ngày (dùng cho biểu đồ nhiều ngày).
class DayCalories {
  const DayCalories(this.day, this.calories);

  final DateTime day;
  final int calories;
}

/// Lượng nước (ml) uống trong một ngày, dùng cho biểu đồ thống kê.
class DayWater {
  const DayWater(this.day, this.ml);

  final DateTime day;
  final int ml;
}

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

  // --- Giỏ món (chọn nhiều món rồi thêm một lần) ---
  final List<PortionedFood> _cart = [];

  // --- Gợi ý nhập nhanh ---
  List<MealEntry> _prevDayEntries = const [];
  List<FoodItem> _frequentFoods = const [];
  List<MealCombo> _combos = const [];

  // --- Nước uống của ngày đang xem ---
  int _waterMl = 0;

  /// Dung tích "1 cốc nước" (ml) do người dùng tự đặt, mặc định 250 ml.
  static const int defaultCupMl = 250;
  int _cupMl = defaultCupMl;
  int get cupMl => _cupMl;

  List<FoodItem> get catalog => _catalog;
  List<MealEntry> get todayEntries => _todayEntries;
  NutritionSummary get summary => _summary;
  bool get usdaUsesDemoKey => _usda.usesDemoKey;

  List<PortionedFood> get cart => List.unmodifiable(_cart);
  int get cartCount => _cart.length;
  int get cartCalories => _cart.fold(0, (sum, item) => sum + item.calories);

  /// Số phần của một món đang nằm trong giỏ (0 nếu chưa có).
  double cartPortionOf(String foodId) {
    for (final item in _cart) {
      if (item.food.id == foodId) return item.portion;
    }
    return 0;
  }

  /// Các món đã ăn ở ngày liền trước ngày đang xem.
  List<MealEntry> get previousDayEntries => _prevDayEntries;

  /// Món người dùng hay ăn nhất (60 ngày gần đây), nhiều lần nhất trước.
  List<FoodItem> get frequentFoods => _frequentFoods;

  List<MealCombo> get combos => _combos;

  /// Lượng nước (ml) đã uống trong ngày đang xem.
  int get waterMl => _waterMl;

  /// Các lần cộng/trừ nước của ngày đang xem (mới nhất ở cuối) để hoàn tác.
  final List<int> _waterLog = [];

  /// Lượng nước của lần thêm gần nhất, dùng làm mặc định cho lần sau.
  int _lastWaterStep = 250;
  int get lastWaterStep => _lastWaterStep;

  /// Còn lần thêm nước nào để hoàn tác không.
  bool get canUndoWater => _waterLog.isNotEmpty;

  /// Mục tiêu nước/ngày ≈ 33 ml mỗi kg thể trọng, làm tròn 100 ml.
  static int waterGoalFor(double weightKg) {
    final ml = (weightKg * 33 / 100).round() * 100;
    return ml.clamp(1500, 4000).toInt();
  }

  /// Ngày đang được xem (đã bỏ phần giờ).
  DateTime get selectedDay => _selectedDay;
  bool get isToday => _selectedDay == _dateOnly(DateTime.now());
  bool get isFutureDay => _selectedDay.isAfter(_dateOnly(DateTime.now()));

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Tổng calo của [days] ngày liên tiếp kết thúc ở [endDay], xếp từ cũ đến mới.
  /// Ngày không có món nào trả về 0.
  Future<List<DayCalories>> caloriesLastDays(
    String userId,
    DateTime endDay, {
    int days = 7,
  }) async {
    final entries = await _store.allEntries(userId);
    final totals = <DateTime, int>{};
    for (final e in entries) {
      final d = _dateOnly(e.eatenAt);
      totals[d] = (totals[d] ?? 0) + e.calories;
    }
    final end = _dateOnly(endDay);
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final day = DateTime(end.year, end.month, end.day - i);
          return DayCalories(day, totals[day] ?? 0);
        }(),
    ];
  }

  /// Chuyển sang xem một ngày khác và nạp lại nhật ký của ngày đó.
  Future<void> selectDay(DateTime day) async {
    final next = _dateOnly(day);
    if (next != _selectedDay) _waterLog.clear();
    _selectedDay = next;
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
    if (day != null) {
      final next = _dateOnly(day);
      if (next != _selectedDay) _waterLog.clear();
      _selectedDay = next;
    }
    _userId = userId;
    _calorieGoal = calorieGoal;
    _todayEntries = await _store.entriesByDay(userId, _selectedDay);
    _summary = _buildSummary(_todayEntries, calorieGoal);
    _waterMl = await _store.waterMl(userId, _selectedDay);
    _cupMl = await _store.waterCupMl(userId) ?? defaultCupMl;
    _combos = await _store.combos(userId);
    await _refreshSuggestions(userId);
    notifyListeners();
  }

  /// Tính bữa hôm trước và danh sách món hay ăn cho thanh gợi ý nhập nhanh.
  Future<void> _refreshSuggestions(String userId) async {
    final all = await _store.allEntries(userId);
    final prev = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day - 1,
    );
    _prevDayEntries = all
        .where((e) => _dateOnly(e.eatenAt) == prev)
        .toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));

    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 60));
    final counts = <String, int>{};
    final latest = <String, MealEntry>{};
    for (final e in all) {
      // Chỉ tính những bữa đã ăn, bỏ kế hoạch tương lai và dữ liệu quá cũ.
      if (e.eatenAt.isAfter(now) || e.eatenAt.isBefore(since)) continue;
      counts[e.foodId] = (counts[e.foodId] ?? 0) + 1;
      final cur = latest[e.foodId];
      if (cur == null || e.eatenAt.isAfter(cur.eatenAt)) latest[e.foodId] = e;
    }
    final ids = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        if (byCount != 0) return byCount;
        return latest[b]!.eatenAt.compareTo(latest[a]!.eatenAt);
      });
    _frequentFoods = [for (final id in ids.take(8)) foodFromEntry(latest[id]!)];
  }

  /// Dựng lại món từ một dòng nhật ký: ưu tiên món gốc trong danh mục, nếu
  /// không còn thì suy ngược dinh dưỡng của một phần từ chính dòng đó.
  FoodItem foodFromEntry(MealEntry entry) {
    for (final food in _catalog) {
      if (food.id == entry.foodId) return food;
    }
    final p = entry.portion > 0 ? entry.portion : 1.0;
    return FoodItem(
      id: entry.foodId,
      name: entry.foodName,
      category: FoodCategory.other,
      calories: (entry.calories / p).round(),
      protein: entry.protein / p,
      carbs: entry.carbs / p,
      fat: entry.fat / p,
      servingLabel: '1 phần',
    );
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
    await _shiftWater(userId, entry.eatenAt, entry.waterMl);
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
    MealEntry? removed;
    for (final e in _todayEntries) {
      if (e.id == entryId) removed = e;
    }
    // Cập nhật giao diện ngay (vuốt để xóa cần dòng biến mất tức thì), rồi mới
    // ghi xuống kho.
    _todayEntries = _todayEntries.where((e) => e.id != entryId).toList();
    _summary = _buildSummary(_todayEntries, calorieGoal);
    notifyListeners();
    await _store.deleteEntry(entryId);
    // Xóa đồ uống thì trừ lại lượng nước đã cộng khi thêm.
    if (removed != null) {
      await _shiftWater(userId, removed.eatenAt, -removed.waterMl);
    }
    await loadDay(userId: userId, calorieGoal: calorieGoal);
  }

  /// Khôi phục một dòng vừa xóa (nút "Hoàn tác").
  Future<void> restoreEntry({
    required MealEntry entry,
    required int calorieGoal,
  }) async {
    await _store.insertEntry(entry);
    await _shiftWater(entry.userId, entry.eatenAt, entry.waterMl);
    await loadDay(userId: entry.userId, calorieGoal: calorieGoal);
  }

  /// Đổi một dòng nhật ký sang món khác (giữ nguyên buổi, giờ và id).
  Future<void> replaceEntryFood({
    required MealEntry entry,
    required FoodItem food,
    required double portion,
    required int calorieGoal,
  }) async {
    final updated = MealEntry.fromFood(
      id: entry.id,
      userId: entry.userId,
      food: food,
      slot: entry.slot,
      eatenAt: entry.eatenAt,
      portion: portion,
    );
    await _store.updateEntry(updated);
    await _shiftWater(
      entry.userId,
      entry.eatenAt,
      updated.waterMl - entry.waterMl,
    );
    await loadDay(userId: entry.userId, calorieGoal: calorieGoal);
  }

  // -------------------------------------------------------------------------
  // Thêm nhiều món một lúc: giỏ, combo, chép bữa hôm trước
  // -------------------------------------------------------------------------

  Future<void> addFoods({
    required String userId,
    required List<PortionedFood> items,
    required MealSlot slot,
    required int calorieGoal,
  }) async {
    if (items.isEmpty) return;
    final base = DateTime.now().microsecondsSinceEpoch;
    final eatenAt = _eatenAtForSelectedDay();
    var water = 0;
    for (var i = 0; i < items.length; i++) {
      final entry = MealEntry.fromFood(
        id: 'meal-${base + i}',
        userId: userId,
        food: items[i].food,
        slot: slot,
        portion: items[i].portion,
        eatenAt: eatenAt,
      );
      water += entry.waterMl;
      await _store.insertEntry(entry);
    }
    await _shiftWater(userId, eatenAt, water);
    await loadDay(userId: userId, calorieGoal: calorieGoal);
  }

  void addToCart(FoodItem food, {double portion = 1}) {
    final i = _cart.indexWhere((c) => c.food.id == food.id);
    if (i >= 0) {
      _cart[i] = _cart[i].copyWith(portion: _cart[i].portion + portion);
    } else {
      _cart.add(PortionedFood(food, portion));
    }
    notifyListeners();
  }

  /// Đặt số phần của một món trong giỏ; `<= 0` thì bỏ món khỏi giỏ.
  void setCartPortion(String foodId, double portion) {
    final i = _cart.indexWhere((c) => c.food.id == foodId);
    if (i < 0) return;
    if (portion <= 0) {
      _cart.removeAt(i);
    } else {
      _cart[i] = _cart[i].copyWith(portion: portion);
    }
    notifyListeners();
  }

  void clearCart() {
    if (_cart.isEmpty) return;
    _cart.clear();
    notifyListeners();
  }

  /// "Thêm tất cả vào bữa": ghi mọi món trong giỏ vào [slot] rồi dọn giỏ.
  Future<void> commitCart({
    required String userId,
    required MealSlot slot,
    required int calorieGoal,
  }) async {
    final items = List<PortionedFood>.of(_cart);
    _cart.clear();
    await addFoods(
      userId: userId,
      items: items,
      slot: slot,
      calorieGoal: calorieGoal,
    );
  }

  /// Các dòng của [slot] ở ngày liền trước (để hiện nút "Ăn lại").
  List<MealEntry> previousDayMeal(MealSlot slot) =>
      _prevDayEntries.where((e) => e.slot == slot).toList();

  /// Chép nguyên bữa [slot] của ngày trước sang ngày đang xem. Trả về số món.
  Future<int> repeatPreviousDay({
    required String userId,
    required MealSlot slot,
    required int calorieGoal,
  }) async {
    final source = previousDayMeal(slot);
    if (source.isEmpty) return 0;
    final base = DateTime.now().microsecondsSinceEpoch;
    final eatenAt = _eatenAtForSelectedDay();
    var water = 0;
    for (var i = 0; i < source.length; i++) {
      water += source[i].waterMl;
      await _store.insertEntry(
        source[i].copyWith(id: 'meal-${base + i}', eatenAt: eatenAt),
      );
    }
    await _shiftWater(userId, eatenAt, water);
    await loadDay(userId: userId, calorieGoal: calorieGoal);
    return source.length;
  }

  // --- Combo ---

  Future<void> saveCombo({
    required String userId,
    required String name,
    required List<PortionedFood> items,
  }) async {
    if (items.isEmpty) return;
    await _store.saveCombo(
      MealCombo(
        id: 'combo-${DateTime.now().microsecondsSinceEpoch}',
        userId: userId,
        name: name.trim().isEmpty ? 'Combo của tôi' : name.trim(),
        items: List.of(items),
      ),
    );
    _combos = await _store.combos(userId);
    notifyListeners();
  }

  Future<void> deleteCombo({
    required String userId,
    required String comboId,
  }) async {
    await _store.deleteCombo(comboId);
    _combos = await _store.combos(userId);
    notifyListeners();
  }

  Future<void> addCombo({
    required String userId,
    required MealCombo combo,
    required MealSlot slot,
    required int calorieGoal,
  }) {
    return addFoods(
      userId: userId,
      items: combo.items,
      slot: slot,
      calorieGoal: calorieGoal,
    );
  }

  // --- Nước uống ---

  /// Cộng/trừ lượng nước của một ngày do việc thêm/xóa/sửa đồ uống.
  /// Khác [addWater]: không đi vào danh sách hoàn tác của nút uống nước.
  Future<void> _shiftWater(String userId, DateTime day, int deltaMl) async {
    if (deltaMl == 0) return;
    final d = _dateOnly(day);
    final current = await _store.waterMl(userId, d);
    final next = (current + deltaMl).clamp(0, 10000).toInt();
    await _store.setWaterMl(userId, d, next);
  }

  /// Lượng nước (ml) mà các món trong [items] sẽ cộng vào mục nước uống.
  static int waterOf(Iterable<PortionedFood> items) => items.fold(
        0,
        (sum, item) => sum + (drinkMlOf(item.food) * item.portion).round(),
      );

  /// Đặt dung tích "1 cốc nước" (ml), được lưu cho lần sau.
  Future<void> setCupMl({required String userId, required int ml}) async {
    _cupMl = ml.clamp(50, 2000).toInt();
    notifyListeners();
    await _store.setWaterCupMl(userId, _cupMl);
  }

  /// Cộng/trừ nước của ngày đang xem (ví dụ +250 ml mỗi lần bấm ly nước).
  Future<void> addWater({required String userId, required int deltaMl}) async {
    final before = _waterMl;
    _waterMl = (_waterMl + deltaMl).clamp(0, 10000).toInt();
    final applied = _waterMl - before;
    if (applied != 0) {
      _waterLog.add(applied);
      if (applied > 0) _lastWaterStep = applied;
    }
    notifyListeners();
    await _store.setWaterMl(userId, _selectedDay, _waterMl);
  }

  /// Hoàn tác lần thêm/bớt nước gần nhất. Trả về số ml đã hoàn tác (có dấu).
  Future<int> undoWater({required String userId}) async {
    if (_waterLog.isEmpty) return 0;
    final last = _waterLog.removeLast();
    _waterMl = (_waterMl - last).clamp(0, 10000).toInt();
    notifyListeners();
    await _store.setWaterMl(userId, _selectedDay, _waterMl);
    return last;
  }

  /// Lượng nước của [days] ngày liên tiếp kết thúc ở [endDay], xếp từ cũ đến mới.
  /// Ngày không uống trả về 0.
  Future<List<DayWater>> waterLastDays(
    String userId,
    DateTime endDay, {
    int days = 7,
  }) async {
    final all = await _store.allWater(userId);
    final end = _dateOnly(endDay);
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final day = DateTime(end.year, end.month, end.day - i);
          return DayWater(day, all[day] ?? 0);
        }(),
    ];
  }

  void clear() {
    _todayEntries = const [];
    _summary = NutritionSummary.empty;
    _cart.clear();
    _prevDayEntries = const [];
    _frequentFoods = const [];
    _combos = const [];
    _waterMl = 0;
    _cupMl = defaultCupMl;
    _waterLog.clear();
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
