import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/nutrition.dart';

class OpenFoodFactsException implements Exception {
  const OpenFoodFactsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Sản phẩm tra theo mã vạch từ Open Food Facts (dinh dưỡng trên 100 g).
class BarcodeProduct {
  const BarcodeProduct({
    required this.code,
    required this.name,
    required this.brand,
    required this.servingGrams,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    required this.fiberPer100,
    required this.sugarPer100,
    required this.sodiumMgPer100,
  });

  final String code;
  final String name;
  final String brand;

  /// Khối lượng một khẩu phần ghi trên bao bì; 100 g nếu bao bì không ghi.
  final double servingGrams;
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  final double fiberPer100;
  final double sugarPer100;
  final double sodiumMgPer100;

  String get displayName => brand.isEmpty ? name : '$name ($brand)';

  /// Quy thành [FoodItem] với 1 phần = một khẩu phần trên bao bì.
  FoodItem toFoodItem() {
    final k = servingGrams / 100;
    double one(double v) => (v * 10).round() / 10;
    final grams = servingGrams.round();
    return FoodItem(
      id: 'off-$code',
      name: displayName,
      category: FoodCategory.other,
      calories: (kcalPer100 * k).round(),
      protein: one(proteinPer100 * k),
      carbs: one(carbsPer100 * k),
      fat: one(fatPer100 * k),
      servingLabel: '1 phần (${grams}g)',
      fiber: one(fiberPer100 * k),
      sugar: one(sugarPer100 * k),
      sodium: (sodiumMgPer100 * k).roundToDouble(),
    );
  }
}

/// Tra cứu sản phẩm đóng gói qua Open Food Facts (miễn phí, không cần key).
/// Cần có mạng; sản phẩm chưa có trong cơ sở dữ liệu sẽ trả về `null`.
class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<BarcodeProduct?> lookup(String barcode) async {
    final code = barcode.trim();
    if (!RegExp(r'^\d{6,14}$').hasMatch(code)) {
      throw const OpenFoodFactsException('Mã vạch không hợp lệ.');
    }

    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$code.json',
      {
        'fields': 'product_name,product_name_vi,brands,serving_quantity,'
            'nutriments',
      },
    );

    http.Response res;
    try {
      res = await _client.get(uri, headers: const {
        // Open Food Facts yêu cầu app tự giới thiệu qua User-Agent.
        'User-Agent': 'HealthFlow/1.0 (Flutter)',
      }).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const OpenFoodFactsException(
        'Open Food Facts phản hồi quá lâu. Hãy thử lại.',
      );
    } catch (_) {
      throw const OpenFoodFactsException(
        'Không kết nối được mạng để tra mã vạch.',
      );
    }

    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw OpenFoodFactsException('Open Food Facts lỗi (${res.statusCode}).');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['status'] != 1 || body['product'] is! Map) return null;
    final product = Map<String, dynamic>.from(body['product'] as Map);
    final n = Map<String, dynamic>.from(
      (product['nutriments'] as Map?) ?? const <String, dynamic>{},
    );

    double? num100(String key) {
      final v = n[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    var kcal = num100('energy-kcal_100g');
    if (kcal == null) {
      final kj = num100('energy_100g');
      if (kj != null) kcal = kj / 4.184;
    }
    // Không có calo thì không dùng được cho nhật ký.
    if (kcal == null) return null;

    // Natri tính bằng gram; nếu chỉ có muối thì natri ≈ muối / 2,5.
    var sodiumG = num100('sodium_100g');
    sodiumG ??= (num100('salt_100g') ?? 0) / 2.5;

    final vi = (product['product_name_vi'] as String?)?.trim() ?? '';
    final raw = (product['product_name'] as String?)?.trim() ?? '';
    final name = vi.isNotEmpty ? vi : (raw.isNotEmpty ? raw : 'Sản phẩm $code');
    final brand =
        ((product['brands'] as String?) ?? '').split(',').first.trim();

    final serving = product['serving_quantity'];
    final servingGrams = serving is num
        ? serving.toDouble()
        : (double.tryParse('${serving ?? ''}') ?? 100);

    return BarcodeProduct(
      code: code,
      name: name,
      brand: brand,
      servingGrams: servingGrams > 0 ? servingGrams : 100,
      kcalPer100: kcal,
      proteinPer100: num100('proteins_100g') ?? 0,
      carbsPer100: num100('carbohydrates_100g') ?? 0,
      fatPer100: num100('fat_100g') ?? 0,
      fiberPer100: num100('fiber_100g') ?? 0,
      sugarPer100: num100('sugars_100g') ?? 0,
      sodiumMgPer100: sodiumG * 1000,
    );
  }
}
