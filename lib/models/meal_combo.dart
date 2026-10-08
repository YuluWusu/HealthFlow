import 'nutrition.dart';

/// Một món kèm số phần, dùng cho giỏ món và cho các món trong combo.
class PortionedFood {
  const PortionedFood(this.food, this.portion);

  final FoodItem food;

  /// 1 = đúng một phần chuẩn của món.
  final double portion;

  int get calories => (food.calories * portion).round();

  PortionedFood copyWith({double? portion}) =>
      PortionedFood(food, portion ?? this.portion);

  Map<String, Object?> toMap() => {
        'food': food.toMap(),
        'portion': portion,
      };

  factory PortionedFood.fromMap(Map<String, Object?> map) {
    return PortionedFood(
      FoodItem.fromMap(Map<String, Object?>.from(map['food'] as Map)),
      (map['portion'] as num).toDouble(),
    );
  }
}

/// Bữa ăn lưu sẵn, ví dụ "Bữa sáng quen thuộc" = phở bò + cà phê đen.
class MealCombo {
  const MealCombo({
    required this.id,
    required this.userId,
    required this.name,
    required this.items,
  });

  final String id;
  final String userId;
  final String name;
  final List<PortionedFood> items;

  int get calories => items.fold(0, (sum, item) => sum + item.calories);

  /// "Phở bò + Cà phê đen" — dùng làm dòng mô tả.
  String get description => items.map((item) => item.food.name).join(' + ');

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'items': items.map((item) => item.toMap()).toList(),
      };

  factory MealCombo.fromMap(Map<String, Object?> map) {
    return MealCombo(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      items: [
        for (final raw in map['items'] as List<dynamic>)
          PortionedFood.fromMap(Map<String, Object?>.from(raw as Map)),
      ],
    );
  }
}
