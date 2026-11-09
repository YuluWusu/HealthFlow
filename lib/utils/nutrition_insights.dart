import '../data/nutrition_repository.dart';
import '../data/vietnam_food_source.dart';
import '../models/ingredient.dart';
import '../models/nutrition.dart';

/// Mức khuyến nghị tham khảo (WHO / viện dinh dưỡng) tính theo mục tiêu calo.
///
/// Đây là mốc tham khảo cho người trưởng thành khỏe mạnh, không thay thế tư
/// vấn của bác sĩ hay chuyên gia dinh dưỡng.
class NutritionLimits {
  const NutritionLimits({required this.calorieGoal, this.weightKg});

  final int calorieGoal;
  final double? weightKg;

  /// Đường tối đa (g/ngày): khoảng 10% năng lượng (tính cả đường tự nhiên
  /// trong trái cây, sữa nên chỉ là mốc tham khảo).
  double get sugarMaxG => calorieGoal * 0.10 / 4;

  /// Natri tối đa 2000 mg/ngày (≈ 5 g muối).
  double get sodiumMaxMg => 2000;
  double get saltMaxG => saltGramsOf(sodiumMaxMg);

  /// Chất xơ tối thiểu: 14 g cho mỗi 1000 kcal, trong khoảng 20–35 g.
  double get fiberMinG => (calorieGoal / 1000 * 14).clamp(20.0, 35.0);

  /// Đạm tối thiểu: 0,8 g/kg thể trọng; không có cân nặng thì lấy 12% năng lượng.
  double get proteinMinG {
    final w = weightKg;
    if (w != null && w > 0) return w * 0.8;
    return calorieGoal * 0.12 / 4;
  }

  /// Chất béo tối đa 35% năng lượng; carb tối đa 65% năng lượng.
  double get fatMaxG => calorieGoal * 0.35 / 9;
  double get carbsMaxG => calorieGoal * 0.65 / 4;
}

enum InsightLevel { good, info, warn }

/// Một món gợi ý kèm khối lượng (số phần; nguyên liệu 1 phần = 100 g).
class SuggestedFood {
  const SuggestedFood({
    required this.food,
    required this.portion,
    required this.label,
  });

  final FoodItem food;
  final double portion;

  /// Ví dụ `Ức gà (chín) · 100g`.
  final String label;
}

class NutritionInsight {
  const NutritionInsight({
    required this.level,
    required this.title,
    required this.message,
    this.foods = const [],
  });

  final InsightLevel level;
  final String title;
  final String message;
  final List<SuggestedFood> foods;
}

/// Phân tích nhật ký ăn uống bằng các luật đơn giản và gợi ý món phù hợp.
///
/// Chỉ dựa trên những ngày người dùng có ghi nhật ký, để ngày bỏ trống không
/// làm trung bình bị thấp giả.
class NutritionInsights {
  const NutritionInsights._();

  static String _n(double v, [int digits = 0]) =>
      v.toStringAsFixed(digits).replaceAll('.', ',');

  /// [report] là dữ liệu của khoảng thời gian đang xem, [ingredients] và
  /// [catalog] dùng để chọn món gợi ý.
  static List<NutritionInsight> analyze({
    required NutritionReport report,
    required NutritionLimits limits,
    required List<Ingredient> ingredients,
    required List<FoodItem> catalog,
  }) {
    final days = report.loggedDays;
    if (days.isEmpty) {
      return const [
        NutritionInsight(
          level: InsightLevel.info,
          title: 'Chưa đủ dữ liệu',
          message:
              'Hãy ghi lại các bữa ăn của bạn, ứng dụng sẽ phân tích và gợi ý món phù hợp.',
        ),
      ];
    }

    final n = days.length;
    double avg(double Function(DayNutrition d) f) =>
        days.fold<double>(0, (a, d) => a + f(d)) / n;

    final avgCal = avg((d) => d.calories.toDouble());
    final avgProtein = avg((d) => d.protein);
    final avgCarbs = avg((d) => d.carbs);
    final avgFat = avg((d) => d.fat);
    final avgSugar = avg((d) => d.sugar);
    final avgSodium = avg((d) => d.sodium);
    final avgFiber = avg((d) => d.fiber);
    final fruitDays = days.where((d) => d.fruitGrams >= 80).length;

    final energy = avgProtein * 4 + avgCarbs * 4 + avgFat * 9;
    final fatPercent = energy > 0 ? avgFat * 9 / energy : 0.0;
    final carbPercent = energy > 0 ? avgCarbs * 4 / energy : 0.0;

    final period = n == 1 ? 'trong ngày' : 'mỗi ngày (trung bình $n ngày có ghi)';
    final out = <NutritionInsight>[];

    String sources(List<FoodContribution> top, String unit, {bool salt = false}) {
      if (top.isEmpty) return '';
      final parts = top.map((c) {
        final v = salt ? saltGramsOf(c.amount) : c.amount;
        return '${c.name} (${_n(v, salt ? 1 : 0)} $unit)';
      }).join(', ');
      return ' Nhiều nhất từ: $parts.';
    }

    // --- Năng lượng ------------------------------------------------------
    if (avgCal > limits.calorieGoal * 1.1) {
      out.add(NutritionInsight(
        level: InsightLevel.warn,
        title: 'Nạp nhiều hơn mục tiêu',
        message:
            'Bạn nạp khoảng ${_n(avgCal)} kcal $period, vượt mục tiêu ${limits.calorieGoal} kcal. '
            'Có thể giảm khẩu phần tinh bột, đồ chiên và đồ uống có đường.',
      ));
    } else if (avgCal < limits.calorieGoal * 0.75) {
      out.add(NutritionInsight(
        level: InsightLevel.info,
        title: 'Nạp ít hơn mục tiêu',
        message:
            'Bạn nạp khoảng ${_n(avgCal)} kcal $period, thấp hơn nhiều so với mục tiêu ${limits.calorieGoal} kcal. '
            'Nếu chưa ghi đủ bữa thì hãy bổ sung, còn không hãy ăn thêm bữa phụ lành mạnh.',
        foods: _pick(ingredients, const ['sua-chua', 'chuoi', 'trung-ga', 'hanh-nhan'],
            const {'hanh-nhan': 30}),
      ));
    }

    // --- Đường -----------------------------------------------------------
    if (avgSugar > limits.sugarMaxG) {
      out.add(NutritionInsight(
        level: InsightLevel.warn,
        title: 'Ăn khá nhiều đường',
        message:
            'Khoảng ${_n(avgSugar)} g đường $period, cao hơn mức tham khảo ≤ ${_n(limits.sugarMaxG)} g.'
            '${sources(report.topSugar, 'g')} '
            'Hãy giảm chè, nước ngọt, trà sữa, bánh ngọt; có thể thay bằng sữa chua không đường hoặc trái cây tươi.',
        foods: _pick(ingredients, const ['sua-chua', 'dau-tay', 'oi']),
      ));
    }

    // --- Muối ------------------------------------------------------------
    if (avgSodium > limits.sodiumMaxMg) {
      out.add(NutritionInsight(
        level: InsightLevel.warn,
        title: 'Ăn hơi mặn',
        message:
            'Khoảng ${_n(saltGramsOf(avgSodium), 1)} g muối $period, cao hơn mức tham khảo ≤ ${_n(limits.saltMaxG, 0)} g.'
            '${sources(report.topSodium, 'g muối', salt: true)} '
            'Hãy bớt nước mắm, muối, hạt nêm khi nấu và chấm; hạn chế húp hết nước dùng của bún/phở.',
        foods: _pick(ingredients, const ['bong-cai', 'dua-leo', 'ca-chua']),
      ));
    }

    // --- Chất béo --------------------------------------------------------
    if (fatPercent > 0.35) {
      out.add(NutritionInsight(
        level: InsightLevel.warn,
        title: 'Nhiều chất béo',
        message:
            'Chất béo chiếm khoảng ${_n(fatPercent * 100)}% năng lượng (nên ≤ 35%).'
            '${sources(report.topFat, 'g')} '
            'Ưu tiên luộc, hấp, nướng thay cho chiên rán; chọn thịt nạc, cá, đậu hũ.',
        foods: _pick(ingredients, const ['uc-ga-chin', 'tom', 'dau-hu']),
      ));
    }

    // --- Tinh bột --------------------------------------------------------
    if (carbPercent > 0.65) {
      out.add(NutritionInsight(
        level: InsightLevel.info,
        title: 'Nhiều tinh bột',
        message:
            'Carb chiếm khoảng ${_n(carbPercent * 100)}% năng lượng (nên ≤ 65%). '
            'Bớt cơm/bún/bánh và thay bằng thêm đạm nạc và rau.',
        foods: _pick(ingredients, const ['uc-ga-chin', 'trung-ga', 'bong-cai']),
      ));
    }

    // --- Đạm -------------------------------------------------------------
    if (avgProtein < limits.proteinMinG) {
      out.add(NutritionInsight(
        level: InsightLevel.warn,
        title: 'Thiếu đạm (protein)',
        message:
            'Khoảng ${_n(avgProtein)} g đạm $period, thấp hơn mức tham khảo ≥ ${_n(limits.proteinMinG)} g. '
            'Nên ăn thêm ức gà, trứng, cá, tôm, đậu hũ hoặc sữa chua.',
        foods: _pick(ingredients,
            const ['uc-ga-chin', 'trung-ga', 'dau-hu', 'ca-hoi', 'tom']),
      ));
    }

    // --- Chất xơ / rau ---------------------------------------------------
    if (avgFiber < limits.fiberMinG) {
      out.add(NutritionInsight(
        level: InsightLevel.warn,
        title: 'Ít chất xơ, nên ăn thêm rau',
        message:
            'Khoảng ${_n(avgFiber)} g chất xơ $period, thấp hơn mức tham khảo ≥ ${_n(limits.fiberMinG)} g. '
            'Hãy thêm rau xanh vào mỗi bữa, ăn trái cây và các món có nhiều rau.',
        foods: [
          ..._pick(ingredients,
              const ['bong-cai', 'rau-muong', 'ca-rot', 'khoai-lang']),
          ..._fiberDishes(catalog),
        ],
      ));
    }

    // --- Trái cây --------------------------------------------------------
    if (fruitDays * 2 < n) {
      out.add(NutritionInsight(
        level: InsightLevel.info,
        title: 'Ít trái cây',
        message: n == 1
            ? 'Hôm nay bạn chưa ghi trái cây. Nên ăn khoảng 100–200 g trái cây mỗi ngày để bổ sung vitamin và chất xơ.'
            : 'Chỉ $fruitDays/$n ngày có ghi trái cây. Nên ăn khoảng 100–200 g trái cây mỗi ngày để bổ sung vitamin và chất xơ.',
        foods: _pick(ingredients, const ['oi', 'chuoi', 'cam', 'thanh-long', 'xoai'],
            const {'chuoi': 120, 'cam': 150}),
      ));
    }

    if (!out.any((i) => i.level == InsightLevel.warn)) {
      out.insert(
        0,
        const NutritionInsight(
          level: InsightLevel.good,
          title: 'Chế độ ăn khá cân đối',
          message:
              'Các chỉ số đường, muối, chất béo, đạm và chất xơ của bạn đều trong mức tham khảo. Hãy duy trì nhé!',
        ),
      );
    }
    return out;
  }

  /// Chọn món gợi ý theo danh sách id nguyên liệu (bỏ qua id không tồn tại).
  /// [grams] đổi số gram mặc định (100 g) cho từng món.
  static List<SuggestedFood> _pick(
    List<Ingredient> ingredients,
    List<String> ids, [
    Map<String, int> grams = const {},
  ]) {
    final out = <SuggestedFood>[];
    for (final id in ids) {
      Ingredient? ing;
      for (final i in ingredients) {
        if (i.id == id) {
          ing = i;
          break;
        }
      }
      if (ing == null) continue;
      final g = grams[id] ?? 100;
      out.add(SuggestedFood(
        food: ing.toFoodItem(),
        portion: g / 100,
        label: '${ing.name} · ${g}g',
      ));
    }
    return out;
  }

  /// Hai món Việt nhiều chất xơ nhất (ít calo) làm gợi ý thêm rau.
  static List<SuggestedFood> _fiberDishes(List<FoodItem> catalog) {
    final dishes = [
      for (final f in catalog)
        if (f is CatalogFood &&
            f.source == FoodSource.vietnam &&
            f.category == FoodCategory.vietnamese &&
            f.hasFiberData &&
            f.calories <= 350)
          f,
    ]..sort((a, b) => b.fiber.compareTo(a.fiber));
    return [
      for (final f in dishes.take(2))
        SuggestedFood(food: f, portion: 1, label: '${f.name} · 1 phần'),
    ];
  }
}
