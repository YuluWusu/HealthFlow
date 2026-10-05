import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/nutrition.dart';

/// Nguồn của một món trong danh mục.
enum FoodSource { vietnam, usda, local }

/// Nhóm dùng cho món quốc tế (đúng với nhóm "món Tây" trong bản seed cũ).
/// Nếu enum của bạn có giá trị riêng cho món quốc tế, đổi ở đây.
const FoodCategory kWorldCategory = FoodCategory.asian;

/// [FoodItem] kèm thêm thông tin chi tiết (nguồn, thành phần, vi chất).
///
/// Là lớp con nên mọi nơi đang nhận [FoodItem] vẫn dùng được bình thường.
class CatalogFood extends FoodItem {
  const CatalogFood({
    required super.id,
    required super.name,
    required super.category,
    required super.calories,
    required super.protein,
    required super.carbs,
    required super.fat,
    required super.servingLabel,
    this.source = FoodSource.local,
    this.group = '',
    this.vegetarian = false,
    this.ingredients = const [],
    this.fiber,
    this.calcium,
    this.iron,
    this.servingGrams,
  });

  final FoodSource source;

  /// Nhóm món (Món nước, Món bánh...). Chỉ có với món Việt Nam.
  final String group;
  final bool vegetarian;
  final List<String> ingredients;

  /// Chất xơ (g), canxi (mg), sắt (mg) cho một khẩu phần.
  final double? fiber;
  final double? calcium;
  final double? iron;
  final int? servingGrams;

  factory CatalogFood.fromVietnamJson(Map<String, dynamic> j) {
    final grams = (j['servingGrams'] as num).toInt();
    return CatalogFood(
      id: j['id'] as String,
      name: j['name'] as String,
      category: FoodCategory.vietnamese,
      calories: (j['calories'] as num).toInt(),
      protein: (j['protein'] as num).toDouble(),
      carbs: (j['carbs'] as num).toDouble(),
      fat: (j['fat'] as num).toDouble(),
      servingLabel: '1 phần (${grams}g)',
      source: FoodSource.vietnam,
      group: j['group'] as String? ?? '',
      vegetarian: j['vegetarian'] as bool? ?? false,
      ingredients: List<String>.from(j['ingredients'] as List? ?? const []),
      fiber: (j['fiber'] as num?)?.toDouble(),
      calcium: (j['calcium'] as num?)?.toDouble(),
      iron: (j['iron'] as num?)?.toDouble(),
      servingGrams: grams,
    );
  }
}

/// Đọc danh mục món Việt Nam từ file Excel đã được chuyển sang JSON.
///
/// Số liệu mỗi món = tổng dinh dưỡng các nguyên liệu theo khối lượng
/// (sheet "Chi tiết Thành phần" tra từ "Bảng Tra Cứu", tính trên 100g).
class VietnamFoodSource {
  static const assetPath = 'assets/data/vn_foods.json';

  List<CatalogFood>? _cache;

  Future<List<CatalogFood>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    return _cache = List.unmodifiable(
      list.map((e) => CatalogFood.fromVietnamJson(e as Map<String, dynamic>)),
    );
  }
}
