import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'vietnam_food_source.dart';

class UsdaException implements Exception {
  const UsdaException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Tra cứu món quốc tế qua USDA FoodData Central.
///
/// Chạy app với key riêng (đăng ký miễn phí tại fdc.nal.usda.gov/api-key-signup):
///   flutter run --dart-define=USDA_API_KEY=xxxxxxxx
/// Không truyền thì dùng DEMO_KEY (giới hạn số lượt gọi rất thấp).
class UsdaFoodService {
  UsdaFoodService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? _envKey;

  static const _envKey = String.fromEnvironment(
    'USDA_API_KEY',
    defaultValue: 'b8Ri2dkz9bdr9OUMSJT60p5FPmI8ReB1ZmWDNvoU',
  );

  final http.Client _client;
  final String _apiKey;
  final Map<String, List<CatalogFood>> _cache = {};

  bool get usesDemoKey => _apiKey == 'DEMO_KEY';

  /// Từ khóa tiếng Việt thông dụng -> tiếng Anh (USDA chỉ hiểu tiếng Anh).
  static const _viToEn = <String, String>{
    'gà': 'chicken',
    'ức gà': 'chicken breast',
    'bò': 'beef',
    'thịt bò': 'beef',
    'heo': 'pork',
    'lợn': 'pork',
    'thịt heo': 'pork',
    'cá': 'fish',
    'cá hồi': 'salmon',
    'tôm': 'shrimp',
    'trứng': 'egg',
    'sữa': 'milk',
    'sữa chua': 'yogurt',
    'phô mai': 'cheese',
    'cơm': 'rice',
    'gạo': 'rice',
    'khoai tây': 'potato',
    'khoai lang': 'sweet potato',
    'chuối': 'banana',
    'táo': 'apple',
    'cam': 'orange',
    'xoài': 'mango',
    'nho': 'grapes',
    'dâu': 'strawberry',
    'bơ': 'avocado',
    'yến mạch': 'oatmeal',
    'bánh mì': 'bread',
    'đậu phụ': 'tofu',
    'rau': 'vegetables',
    'salad': 'salad',
    'mì ý': 'spaghetti',
    'cà phê': 'coffee',
    'hạt điều': 'cashew',
    'hạnh nhân': 'almonds',
    'cá ngừ': 'tuna',
    'cá thu': 'mackerel',
    'bông cải xanh': 'broccoli',
    'súp lơ': 'cauliflower',
    'cà chua': 'tomato',
    'cà rốt': 'carrot',
    'dưa leo': 'cucumber',
    'dưa hấu': 'watermelon',
    'đậu nành': 'soybeans',
    'sữa đậu nành': 'soy milk',
    'đậu phộng': 'peanuts',
    'bắp': 'corn',
    'mì': 'noodles',
    'nướng': 'grilled',
    'luộc': 'boiled',
    'chiên': 'fried',
    'rán': 'fried',
    'hấp': 'steamed',
    'sống': 'raw',
  };

  /// Dịch cụm tiếng Việt sang tiếng Anh: khớp nguyên cụm trước, nếu không thì
  /// thay từng cụm đã biết (dài nhất trước). Không biết cụm nào thì giữ nguyên.
  static String _translate(String raw) {
    final lower = raw.toLowerCase().trim();
    final exact = _viToEn[lower];
    if (exact != null) return exact;

    final keys = _viToEn.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    var out = ' $lower ';
    var changed = false;
    for (final key in keys) {
      final pattern = ' $key ';
      if (out.contains(pattern)) {
        out = out.replaceAll(pattern, ' ${_viToEn[key]} ');
        changed = true;
      }
    }
    return changed ? out.trim() : raw;
  }

  Future<List<CatalogFood>> search(String query, {int pageSize = 60}) async {
    final raw = query.trim();
    if (raw.length < 2) return const [];
    final term = _translate(raw);

    final cacheKey = term.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'api_key': _apiKey,
      'query': term,
      'pageSize': '$pageSize',
      'dataType': 'Foundation,SR Legacy,Survey (FNDDS)',
    });

    http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const UsdaException('USDA phản hồi quá lâu. Hãy thử lại sau.');
    } catch (_) {
      throw const UsdaException('Không kết nối được USDA. Kiểm tra mạng.');
    }

    if (res.statusCode == 429) {
      throw UsdaException(
        usesDemoKey
            ? 'DEMO_KEY đã hết lượt gọi. Hãy dùng API key riêng của bạn.'
            : 'Đã vượt giới hạn truy vấn USDA. Thử lại sau ít phút.',
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const UsdaException('API key USDA không hợp lệ.');
    }
    if (res.statusCode != 200) {
      throw UsdaException('USDA lỗi (${res.statusCode}).');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final seen = <String>{};
    final foods = <CatalogFood>[];
    for (final item in (body['foods'] as List<dynamic>? ?? const [])) {
      final food = _parse(item as Map<String, dynamic>);
      if (food != null && seen.add(food.name.toLowerCase())) foods.add(food);
    }
    return _cache[cacheKey] = List.unmodifiable(foods);
  }

  /// Giá trị trong kết quả tìm kiếm của USDA tính trên 100g.
  CatalogFood? _parse(Map<String, dynamic> json) {
    final nutrients = <int, double>{};
    for (final n in (json['foodNutrients'] as List<dynamic>? ?? const [])) {
      final map = n as Map<String, dynamic>;
      final id = map['nutrientId'];
      final value = map['value'];
      if (id is int && value is num) nutrients[id] = value.toDouble();
    }

    // 1008 = Energy (kcal); Foundation foods đôi khi chỉ có 2047/2048 (Atwater).
    final kcal = nutrients[1008] ?? nutrients[2047] ?? nutrients[2048];
    if (kcal == null) return null;

    double one(double? v) => ((v ?? 0) * 10).round() / 10;

    return CatalogFood(
      id: 'usda-${json['fdcId']}',
      name: _pretty(json['description'] as String? ?? 'Food'),
      category: kWorldCategory,
      calories: kcal.round(),
      protein: one(nutrients[1003]),
      fat: one(nutrients[1004]),
      carbs: one(nutrients[1005]),
      servingLabel: '100g',
      source: FoodSource.usda,
      fiber: nutrients[1079],
      calcium: nutrients[1087],
      iron: nutrients[1089],
      servingGrams: 100,
    );
  }

  /// "CHICKEN, BREAST" -> "Chicken, breast".
  static String _pretty(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
    final shouting = letters.isNotEmpty && letters == letters.toUpperCase();
    final base = shouting ? t.toLowerCase() : t;
    return base[0].toUpperCase() + base.substring(1);
  }
}
