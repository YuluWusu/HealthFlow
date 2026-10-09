import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_combo.dart';
import '../models/nutrition.dart';
import 'nutrition_store.dart';

/// Lưu nhật ký ăn uống bền vững bằng `shared_preferences` (một danh sách JSON).
///
/// Danh mục món ăn vẫn là dữ liệu mẫu trong bộ nhớ. Đủ cho đồ án/demo; nếu
/// nhật ký lớn lên nhiều thì chuyển sang SQLite và giữ nguyên [NutritionStore].
class PrefsNutritionStore implements NutritionStore {
  PrefsNutritionStore(this._prefs) {
    _entries = _load();
    _combos = _loadCombos();
    _water = _loadWater();
  }

  static const _key = 'hf_meals_v1';
  static const _comboKey = 'hf_combos_v1';
  static const _waterKey = 'hf_water_v1';
  static const _cupKey = 'hf_water_cup_v1';

  final SharedPreferences _prefs;
  late List<MealEntry> _entries;
  late List<MealCombo> _combos;
  late Map<String, int> _water;
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

  List<MealCombo> _loadCombos() {
    final raw = _prefs.getString(_comboKey);
    if (raw == null || raw.isEmpty) return <MealCombo>[];
    try {
      final out = <MealCombo>[];
      for (final item in jsonDecode(raw) as List<dynamic>) {
        try {
          out.add(MealCombo.fromMap(Map<String, Object?>.from(item as Map)));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return <MealCombo>[];
    }
  }

  Map<String, int> _loadWater() {
    final raw = _prefs.getString(_waterKey);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in map.entries) e.key: (e.value as num).toInt()};
    } catch (_) {
      return <String, int>{};
    }
  }

  @override
  Future<int?> waterCupMl(String userId) async {
    final raw = _prefs.getString(_cupKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (map[userId] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setWaterCupMl(String userId, int ml) async {
    Map<String, dynamic> map = <String, dynamic>{};
    final raw = _prefs.getString(_cupKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    map[userId] = ml;
    await _prefs.setString(_cupKey, jsonEncode(map));
  }

  Future<void> _persistCombos() => _prefs.setString(
        _comboKey,
        jsonEncode(_combos.map((c) => c.toMap()).toList()),
      );

  Future<void> _persistWater() =>
      _prefs.setString(_waterKey, jsonEncode(_water));

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

  @override
  Future<void> updateEntry(MealEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i < 0) return;
    _entries[i] = entry;
    await _persist();
  }

  @override
  Future<List<MealCombo>> combos(String userId) async {
    return _combos.where((c) => c.userId == userId).toList();
  }

  @override
  Future<void> saveCombo(MealCombo combo) async {
    _combos.removeWhere((c) => c.id == combo.id);
    _combos.add(combo);
    await _persistCombos();
  }

  @override
  Future<void> deleteCombo(String comboId) async {
    _combos.removeWhere((c) => c.id == comboId);
    await _persistCombos();
  }

  @override
  Future<int> waterMl(String userId, DateTime day) async {
    return _water[waterDayKey(userId, day)] ?? 0;
  }

  @override
  Future<void> setWaterMl(String userId, DateTime day, int ml) async {
    _water[waterDayKey(userId, day)] = ml;
    await _persistWater();
  }

  @override
  Future<Map<DateTime, int>> allWater(String userId) async =>
      parseWaterDays(userId, _water);
}
