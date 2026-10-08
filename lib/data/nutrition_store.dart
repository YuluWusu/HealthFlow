import '../models/nutrition.dart';

/// Lớp lưu trữ dinh dưỡng: danh mục món ăn và nhật ký ăn uống.
abstract class NutritionStore {
  /// Danh mục món ăn dùng chung cho mọi người dùng.
  Future<List<FoodItem>> catalog();

  Future<FoodItem?> findFood(String foodId);

  /// Các món người dùng đã ăn trong một ngày.
  Future<List<MealEntry>> entriesByDay(String userId, DateTime day);

  Future<List<MealEntry>> allEntries(String userId);

  Future<void> insertEntry(MealEntry entry);

  Future<void> deleteEntry(String entryId);
}

class InMemoryNutritionStore implements NutritionStore {
  final List<FoodItem> _catalog = seedCatalog();
  final List<MealEntry> _entries = [];

  @override
  Future<List<FoodItem>> catalog() async => List.unmodifiable(_catalog);

  @override
  Future<FoodItem?> findFood(String foodId) async {
    for (final food in _catalog) {
      if (food.id == foodId) return food;
    }
    return null;
  }

  @override
  Future<List<MealEntry>> entriesByDay(String userId, DateTime day) async {
    return _entries.where((entry) {
      return entry.userId == userId && _isSameDay(entry.eatenAt, day);
    }).toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
  }

  @override
  Future<List<MealEntry>> allEntries(String userId) async {
    return _entries.where((entry) => entry.userId == userId).toList()
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
  }

  @override
  Future<void> insertEntry(MealEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    _entries.removeWhere((entry) => entry.id == entryId);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Danh mục món ăn lấy từ bản thiết kế màn hình "Thêm món ăn".
  ///
  /// Số liệu dinh dưỡng là giá trị tham khảo cho một phần ăn thông thường.
  static List<FoodItem> seedCatalog() {
    return const [
      // Nhóm Việt Nam
      FoodItem(
        id: 'food-pho-bo',
        name: 'Phở bò',
        category: FoodCategory.vietnamese,
        calories: 350,
        protein: 25,
        carbs: 45,
        fat: 12,
        servingLabel: '1 tô (300g)',
      ),
      FoodItem(
        id: 'food-com-ga',
        name: 'Cơm gà',
        category: FoodCategory.vietnamese,
        calories: 420,
        protein: 28,
        carbs: 52,
        fat: 14,
        servingLabel: '1 phần',
      ),
      FoodItem(
        id: 'food-banh-mi-thit',
        name: 'Bánh mì thịt',
        category: FoodCategory.vietnamese,
        calories: 300,
        protein: 14,
        carbs: 38,
        fat: 10,
        servingLabel: '1 ổ',
      ),
      FoodItem(
        id: 'food-salad-rau-cu',
        name: 'Salad rau củ',
        category: FoodCategory.vietnamese,
        calories: 150,
        protein: 6,
        carbs: 18,
        fat: 6,
        servingLabel: '1 phần',
      ),
      FoodItem(
        id: 'food-trung-luoc',
        name: 'Trứng luộc',
        category: FoodCategory.vietnamese,
        calories: 70,
        protein: 6,
        carbs: 1,
        fat: 5,
        servingLabel: '1 quả',
      ),
      // Nhóm món Tây
      FoodItem(
        id: 'food-yen-mach-sua',
        name: 'Yến mạch sữa',
        category: FoodCategory.asian,
        calories: 280,
        protein: 11,
        carbs: 42,
        fat: 7,
        servingLabel: '1 bát',
      ),
      FoodItem(
        id: 'food-uc-ga-ap-chao',
        name: 'Ức gà áp chảo',
        category: FoodCategory.asian,
        calories: 250,
        protein: 32,
        carbs: 2,
        fat: 12,
        servingLabel: '150g',
      ),
      FoodItem(
        id: 'food-pasta-bo',
        name: 'Pasta sốt bò',
        category: FoodCategory.asian,
        calories: 480,
        protein: 22,
        carbs: 58,
        fat: 16,
        servingLabel: '1 đĩa',
      ),
      // Nhóm đồ uống
      FoodItem(
        id: 'food-sua-chua',
        name: 'Sữa chua',
        category: FoodCategory.drink,
        calories: 250,
        protein: 8,
        carbs: 30,
        fat: 9,
        servingLabel: '1 hộp',
      ),
      FoodItem(
        id: 'food-sinh-to-bo',
        name: 'Sinh tố bơ',
        category: FoodCategory.drink,
        calories: 230,
        protein: 4,
        carbs: 24,
        fat: 14,
        servingLabel: '1 ly',
      ),
      FoodItem(
        id: 'food-nuoc-cam',
        name: 'Nước cam',
        category: FoodCategory.drink,
        calories: 110,
        protein: 2,
        carbs: 26,
        fat: 0,
        servingLabel: '1 ly (250ml)',
      ),
      FoodItem(
        id: 'food-ca-phe-sua',
        name: 'Cà phê sữa',
        category: FoodCategory.drink,
        calories: 120,
        protein: 3,
        carbs: 18,
        fat: 4,
        servingLabel: '1 ly',
      ),
      // Nhóm khác
      FoodItem(
        id: 'food-hat-dinh-duong',
        name: 'Hạt dinh dưỡng',
        category: FoodCategory.other,
        calories: 180,
        protein: 5,
        carbs: 8,
        fat: 15,
        servingLabel: '30g',
      ),
      FoodItem(
        id: 'food-banh-quy-yen-mach',
        name: 'Bánh quy yến mạch',
        category: FoodCategory.other,
        calories: 140,
        protein: 3,
        carbs: 20,
        fat: 5,
        servingLabel: '3 cái',
      ),
    ];
  }
}
