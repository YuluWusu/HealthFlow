import '../models/meal_combo.dart';
import '../models/nutrition.dart';
import '../models/nutrition_goals.dart';

/// Một gợi ý bữa ăn: một hoặc hai món kèm lý do.
class MealSuggestion {
  const MealSuggestion({required this.items, required this.reason});

  final List<PortionedFood> items;
  final String reason;

  int get calories => items.fold(0, (s, i) => s + i.calories);
  double get protein =>
      items.fold(0.0, (s, i) => s + i.food.protein * i.portion);
  String get title => items.map((i) => i.food.name).join(' + ');
}

/// Gợi ý món theo lượng calo/đạm còn thiếu trong ngày, dựa trên danh mục món
/// có sẵn (không dùng AI): chỉ lọc và xếp hạng theo quy tắc.
class MealSuggester {
  MealSuggester._();

  /// Đạm còn thiếu từ mức này trở lên thì ưu tiên món giàu đạm.
  static const _proteinGapG = 15.0;

  static List<MealSuggestion> suggest({
    required List<FoodItem> catalog,
    required int remainingKcal,
    required double remainingProtein,
    required Set<String> eatenFoodIds,
    required DietMode mode,
    int limit = 3,
  }) {
    // Còn quá ít calo thì không gợi ý gì (tránh khuyến khích ăn thêm).
    if (remainingKcal < 80) return const [];

    // Một bữa không nên chiếm hết phần còn lại nếu còn nhiều.
    final budget = remainingKcal > 800 ? 700 : remainingKcal;

    final pool = catalog.where((f) {
      if (f.category == FoodCategory.drink) return false;
      if (f.calories <= 0) return false;
      if (eatenFoodIds.contains(f.id)) return false;
      return true;
    }).toList();

    final wantProtein = remainingProtein >= _proteinGapG ||
        mode == DietMode.gainMuscle ||
        mode == DietMode.loseWeight;

    double score(FoodItem f, int kcal) {
      final fits = 1 - ((budget - kcal).abs() / budget); // càng sát ngân sách càng tốt
      final proteinDensity = f.protein / (kcal / 100); // g đạm trên 100 kcal
      var s = fits * 40;
      if (wantProtein) s += proteinDensity * 6;
      if (mode == DietMode.eatClean) {
        s += f.fiber * 2 - f.sugar * 0.8 - f.sodium / 120;
      } else if (mode == DietMode.loseWeight) {
        s += f.fiber * 1.2 - f.sodium / 400;
      }
      return s;
    }

    final results = <MealSuggestion>[];

    // 1) Một món vừa ngân sách.
    final singles = pool
        .where((f) => f.calories <= budget && f.calories >= budget * 0.45)
        .toList()
      ..sort((a, b) => score(b, b.calories).compareTo(score(a, a.calories)));
    for (final f in singles.take(limit)) {
      results.add(MealSuggestion(
        items: [PortionedFood(f, 1)],
        reason: _reason(f.protein, f.calories, remainingProtein, wantProtein),
      ));
    }

    // 2) Khi còn ít calo: ghép hai món nhẹ giàu đạm (vd. trứng + sữa chua).
    if (budget <= 450) {
      final light = pool.where((f) => f.calories <= budget * 0.6).toList()
        ..sort((a, b) => (b.protein / b.calories).compareTo(a.protein / a.calories));
      final top = light.take(6).toList();
      MealSuggestion? bestPair;
      var bestScore = -1e9;
      for (var i = 0; i < top.length; i++) {
        for (var j = i + 1; j < top.length; j++) {
          final kcal = top[i].calories + top[j].calories;
          if (kcal > budget) continue;
          final protein = top[i].protein + top[j].protein;
          final s = protein * 3 - (budget - kcal).abs() / 10;
          if (s > bestScore) {
            bestScore = s;
            bestPair = MealSuggestion(
              items: [PortionedFood(top[i], 1), PortionedFood(top[j], 1)],
              reason: _reason(protein, kcal, remainingProtein, wantProtein),
            );
          }
        }
      }
      if (bestPair != null) results.insert(0, bestPair);
    }

    return results.take(limit).toList();
  }

  static String _reason(
    double protein,
    int kcal,
    double remainingProtein,
    bool wantProtein,
  ) {
    final p = protein.round();
    if (wantProtein && remainingProtein >= _proteinGapG) {
      return '$kcal kcal · $p g đạm giúp bù phần đạm còn thiếu';
    }
    return '$kcal kcal · vừa phần calo còn lại';
  }
}
