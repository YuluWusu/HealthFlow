/// Giá trị đọc được từ bảng "Giá trị dinh dưỡng" (cùng một mốc: 100 g hoặc
/// 1 khẩu phần, tùy bảng). Mục nào không đọc được thì để null.
class LabelValues {
  const LabelValues({
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.sugar,
    this.fiber,
    this.sodiumMg,
  });

  final double? kcal, protein, carbs, fat, sugar, fiber, sodiumMg;

  int get found => [kcal, protein, carbs, fat, sugar, fiber, sodiumMg]
      .where((v) => v != null)
      .length;
}

const _from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Bỏ dấu, chữ thường: "Chất đạm" -> "chat dam".
String foldVietnamese(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = _from.indexOf(c);
    b.write(i < 0 ? c : _to[i]);
  }
  return b.toString();
}

final _num = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kcal|kj|mg|g)\b');

/// Đọc văn bản OCR của bảng dinh dưỡng (tiếng Việt hoặc tiếng Anh).
///
/// shortcut: dò theo từ khóa trên cùng dòng hoặc dòng kế tiếp, nên bảng có
/// nhiều cột (100 g và khẩu phần) sẽ lấy cột đầu tiên; luôn để người dùng kiểm
/// tra lại trước khi lưu.
LabelValues parseNutritionLabel(String text) {
  final lines = [
    for (final l in text.split('\n'))
      if (l.trim().isNotEmpty) foldVietnamese(l),
  ];

  // Số + đơn vị đầu tiên sau từ khóa (cùng dòng, không có thì dòng kế).
  (double, String)? valueFor(RegExp key, {RegExp? skip}) {
    for (var i = 0; i < lines.length; i++) {
      final m = key.firstMatch(lines[i]);
      if (m == null || (skip != null && skip.hasMatch(lines[i]))) continue;
      final rest = lines[i].substring(m.end);
      final hit = _num.firstMatch(rest) ??
          (i + 1 < lines.length ? _num.firstMatch(lines[i + 1]) : null);
      if (hit != null) {
        return (
          double.parse(hit.group(1)!.replaceAll(',', '.')),
          hit.group(2)!,
        );
      }
    }
    return null;
  }

  double? grams(RegExp key, {RegExp? skip}) {
    final v = valueFor(key, skip: skip);
    if (v == null) return null;
    return v.$2 == 'mg' ? v.$1 / 1000 : v.$1;
  }

  double? kcal;
  final e = valueFor(RegExp(r'nang luong|energy|calo'));
  if (e != null) kcal = e.$2 == 'kj' ? e.$1 / 4.184 : e.$1;
  if (kcal == null) {
    final k = RegExp(r'(\d+(?:[.,]\d+)?)\s*kcal').firstMatch(lines.join(' '));
    if (k != null) kcal = double.parse(k.group(1)!.replaceAll(',', '.'));
  }

  double? sodium;
  final na = valueFor(RegExp(r'natri|sodium'));
  if (na != null) sodium = na.$2 == 'g' ? na.$1 * 1000 : na.$1;
  if (sodium == null) {
    final salt = grams(RegExp(r'\bmuoi\b|\bsalt\b'));
    if (salt != null) sodium = salt * 400; // muối ≈ natri × 2,5
  }

  return LabelValues(
    kcal: kcal,
    protein: grams(RegExp(r'chat dam|protein|dam\b')),
    carbs: grams(RegExp(r'carbohydrat|chat bot duong|tinh bot|glucid')),
    fat: grams(RegExp(r'chat beo|\bfat\b|lipid'),
        skip: RegExp(r'bao hoa|saturated|trans')),
    sugar: grams(RegExp(r'\bduong\b|sugar'), skip: RegExp(r'bot duong|dinh duong')),
    fiber: grams(RegExp(r'chat xo|\bxo\b|fib(?:er|re)')),
    sodiumMg: sodium,
  );
}
