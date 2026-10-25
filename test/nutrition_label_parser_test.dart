import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare/utils/nutrition_label_parser.dart';

void main() {
  test('đọc bảng tiếng Việt, số ở cùng dòng hoặc dòng kế', () {
    final v = parseNutritionLabel('''
GIÁ TRỊ DINH DƯỠNG
Trên 100 g
Năng lượng 452 kcal
Chất đạm (Protein)
9,5 g
Chất béo 18 g
Chất béo bão hòa 8 g
Carbohydrate 60 g
Đường 12 g
Chất xơ 2,1 g
Natri 620 mg
''');
    expect(v.kcal, 452);
    expect(v.protein, 9.5);
    expect(v.fat, 18); // không nhầm với chất béo bão hòa
    expect(v.carbs, 60);
    expect(v.sugar, 12);
    expect(v.fiber, 2.1);
    expect(v.sodiumMg, 620);
  });

  test('muối quy ra natri, kJ quy ra kcal, tiếng Anh', () {
    final v = parseNutritionLabel('Energy 418 kJ\nSalt 1.5 g\nSugars 4 g');
    expect(v.kcal!.round(), 100);
    expect(v.sodiumMg, 600);
    expect(v.sugar, 4);
  });
}
