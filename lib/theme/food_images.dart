import 'package:flutter/material.dart';

import '../data/vietnam_food_source.dart';
import '../models/nutrition.dart';

/// Chọn ảnh minh họa cho một món ăn.
///
/// Ảnh được dùng theo **nhóm món** (9 nhóm món Việt, món Tây, đồ uống) chứ
/// không theo từng món, vì danh mục có 199 món Việt và hàng nghìn món USDA.
/// Món không thuộc nhóm nào dùng ảnh mặc định.
String foodImageBase(FoodItem food) {
  if (food is CatalogFood) {
    switch (food.group) {
      case 'Món nước':
        return 'assets/images/food/food_mon_nuoc';
      case 'Món bánh':
        return 'assets/images/food/food_mon_banh';
      case 'Món kho/xào':
        return 'assets/images/food/food_kho_xao';
      case 'Món chiên/nướng':
        return 'assets/images/food/food_chien_nuong';
      case 'Món cơm/xôi':
        return 'assets/images/food/food_com_xoi';
      case 'Món canh/lẩu':
        return 'assets/images/food/food_canh_lau';
      case 'Món tráng miệng/chè':
        return 'assets/images/food/food_trang_mieng';
      case 'Món gỏi/nộm':
        return 'assets/images/food/food_goi_nom';
      case 'Món luộc':
        return 'assets/images/food/food_luoc';
    }
    if (food.source == FoodSource.usda) {
      return 'assets/images/food/food_tay';
    }
  }
  switch (food.category) {
    case FoodCategory.drink:
      return 'assets/images/food/food_drink';
    case FoodCategory.asian:
      return 'assets/images/food/food_tay';
    case FoodCategory.vietnamese:
    case FoodCategory.other:
      return 'assets/images/food/food_default';
  }
}

/// Ô ảnh vuông bo góc hiển thị ảnh của món.
///
/// Thứ tự ưu tiên: ảnh chụp thật `<tên>.jpg` -> ảnh minh họa `<tên>.png`
/// -> [fallback] (icon). Nhờ vậy chỉ cần thả ảnh thật vào assets/images với
/// đúng tên là app tự dùng, không phải sửa code.
class FoodThumb extends StatelessWidget {
  final FoodItem food;
  final double size;
  final double radius;
  final Color background;
  final Widget fallback;

  /// Chiều rộng riêng (vd. `double.infinity` cho ảnh bìa); mặc định bằng [size].
  final double? width;

  /// Độ phân giải giải mã ảnh; mặc định `size * 3`.
  final int? cacheWidth;

  const FoodThumb({
    super.key,
    required this.food,
    required this.size,
    required this.radius,
    required this.background,
    required this.fallback,
    this.width,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final base = foodImageBase(food);
    final decode = cacheWidth ?? (size * 3).round();
    return Container(
      width: width ?? size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Image.asset(
        '$base.jpg',
        width: width ?? size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: decode,
        errorBuilder: (_, __, ___) => Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: Image.asset(
            '$base.png',
            fit: BoxFit.contain,
            cacheWidth: decode,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Center(child: fallback),
          ),
        ),
      ),
    );
  }
}
