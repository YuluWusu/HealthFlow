import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/nutrition.dart';
import 'nutrition_store.dart';

/// Lưu nhật ký ăn uống bền vững bằng `shared_preferences` (một danh sách JSON).
///
/// Danh mục món ăn vẫn là dữ liệu mẫu trong bộ nhớ. Đủ cho đồ án/demo; nếu
/// nhật ký lớn lên nhiều thì chuyển sang SQLite và giữ nguyên [NutritionStore].
class PrefsNutritionStore implements NutritionStore {
  PrefsNutritionStore(this._prefs) {
    _entries = _load();
  }

  static const _key = 'hf_meals_v1';

  final SharedPreferences _prefs;
  late List<MealEntry> _entries;
  final List<FoodItem> _catalog = InMemoryNutritionStore.seedCatalog();

  /// Bản ghi hỏng thì bỏ qua thay vì làm app sập.
  List<MealEntry> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <MealEntry>[];
    try {
      final out = <MealEntry>[];
      for (final item in jsonDecode(raw) as List<dynamic>) {
        try {
          out.add(MealEntry.fromMap(Map<String, Object?>.from(item as Map)));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return <MealEntry>[];
    }
  }

  Future<void> _persist() => _prefs.setString(
        _key,
        jsonEncode(_entries.map((e) => e.toMap()).toList()),
      );

  @override
  Future<List<FoodItem>> catalog() async => List.unmodifiable(_catalog);

  @override
  Future<FoodItem?> findFood(String foodId) async {
    for (final food in _catalog) {
      if (food.id == foodId) return food;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Future<List<MealEntry>> entriesByDay(String userId, DateTime day) async {
    return _entries
        .where((e) => e.userId == userId && _sameDay(e.eatenAt, day))
        .toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
  }

  @override
  Future<List<MealEntry>> allEntries(String userId) async {
    return _entries.where((e) => e.userId == userId).toList()
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
  }

  @override
  Future<void> insertEntry(MealEntry entry) async {
    _entries.add(entry);
    await _persist();
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    _entries.removeWhere((e) => e.id == entryId);
    await _persist();
  }
}
