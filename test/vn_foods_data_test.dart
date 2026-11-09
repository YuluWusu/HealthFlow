import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vn_foods.json: id duy nhất, đủ trường bắt buộc, có đồ uống', () {
    final list = jsonDecode(File('assets/data/vn_foods.json').readAsStringSync())
        as List<dynamic>;
    expect(list.map((e) => e['id']).toSet().length, list.length);
    for (final e in list) {
      expect(e['servingGrams'], greaterThan(0), reason: '${e['name']}');
      for (final k in ['calories', 'protein', 'fat', 'carbs', 'sugar', 'sodium']) {
        expect(e[k], isA<num>(), reason: '${e['name']}.$k');
      }
    }
    expect(list.where((e) => e['drink'] == true), isNotEmpty);
  });
}
