import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/ingredient.dart';

/// Đọc bảng nguyên liệu (dinh dưỡng trên 100 g) từ assets/data/ingredients.json.
class IngredientSource {
  static const assetPath = 'assets/data/ingredients.json';

  List<Ingredient>? _cache;

  Future<List<Ingredient>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    return _cache = List.unmodifiable(
      list.map((e) => Ingredient.fromJson(e as Map<String, dynamic>)),
    );
  }
}
