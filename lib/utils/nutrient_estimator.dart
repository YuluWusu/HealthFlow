/// Bỏ dấu tiếng Việt và hạ chữ thường để so khớp từ khóa ("Nước mắm" -> "nuoc mam").
String foldVietnamese(String input) {
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString();
}

/// Đường (g) và natri (mg).
class SugarSodium {
  const SugarSodium({required this.sugar, required this.sodium});

  final double sugar;
  final double sodium;

  static const zero = SugarSodium(sugar: 0, sodium: 0);

  SugarSodium operator +(SugarSodium other) =>
      SugarSodium(sugar: sugar + other.sugar, sodium: sodium + other.sodium);

  SugarSodium scaled(double k) =>
      SugarSodium(sugar: sugar * k, sodium: sodium * k);
}

class _Row {
  const _Row(this.pattern, this.sodiumMgPer100g, this.sugarGPer100g);

  final String pattern;
  final double sodiumMgPer100g;
  final double sugarGPer100g;
}

/// Ước tính **đường** và **natri** từ tên nguyên liệu.
///
/// Bảng món Việt chỉ có calo/đạm/béo/carb/xơ, chưa có đường và natri, nên ta
/// ước tính theo từng nguyên liệu (giá trị trên 100 g lấy ở mức thường gặp
/// trong bảng thành phần thực phẩm). Đây là con số **tham khảo**, không thay
/// được số liệu đo thật; giao diện luôn ghi chú "ước tính".
class NutrientEstimator {
  NutrientEstimator._();

  // Thứ tự quan trọng: mẫu cụ thể đặt trước mẫu chung. Khớp đầu tiên thắng.
  static final List<_Row> _rows = [
    const _Row(r'nuoc mam', 7000, 3.5),
    const _Row(r'mam tom', 9000, 0),
    const _Row(r'dua cai muoi', 1200, 2),
    const _Row(r'nuoc dung', 450, 1),
    const _Row(r'cha lua|gio lua', 800, 1),
    const _Row(r'dau an', 0, 0),
    const _Row(r'duong', 1, 99.8),
    const _Row(r'che ', 15, 13),
    const _Row(r'rau cau|thach', 20, 5),
    const _Row(r'vo banh bao', 150, 5),
    const _Row(r'vo banh', 5, 0.5),
    const _Row(r'banh mi', 490, 3.5),
    const _Row(r'quay chay', 500, 1),
    const _Row(r'bam chay|ca chay', 400, 1),
    const _Row(r'tau hu ky', 100, 0.5),
    const _Row(r'dau phu|dau hu', 7, 0.6),
    const _Row(r'trung vit lon', 130, 0.5),
    const _Row(r'trung', 124, 0.4),
    const _Row(r'cua dong', 300, 0),
    const _Row(r'tom', 150, 0),
    const _Row(r'muc', 44, 0),
    const _Row(r'ca loc|ca qua|ca hoi|ca thu|ca ho', 80, 0),
    const _Row(r'thit|ga ta|uc ga|dui ga|ba chi|heo|vit|bo nac', 65, 0),
    const _Row(r'sua chua', 50, 4),
    const _Row(r'khoai lang', 36, 6.5),
    const _Row(r'khoai tay', 6, 0.8),
    const _Row(r'khoai', 10, 1),
    const _Row(r'yen mach', 2, 1),
    const _Row(r'lac |lac$|dau phong|dau phung|hat dieu|hanh nhan', 6, 4),
    const _Row(r'vung', 10, 0.3),
    const _Row(r'bo \(trai', 7, 0.7),
    const _Row(r'rau muong', 113, 0.4),
    const _Row(r'rau thom|hanh la', 20, 1),
    const _Row(r'ca chua', 5, 2.6),
    const _Row(r'dua leo|dua chuot', 2, 1.7),
    const _Row(r'cai trang|cu cai', 20, 2.5),
    const _Row(r'bap cai', 18, 3.2),
    const _Row(r'bau|bi dao', 2, 1.9),
    const _Row(r'muop dang|su su', 4, 1.8),
    const _Row(r'gia do', 6, 4),
    const _Row(r'hanh tay', 4, 4.2),
    const _Row(r'ca rot', 69, 4.7),
    const _Row(r'bong cai', 33, 1.7),
    const _Row(r'mang', 150, 2.5),
    const _Row(r'\bnam\b', 5, 1),
    const _Row(r'chuoi', 1, 12),
    const _Row(r'tao', 1, 10),
    const _Row(r'cam', 0, 9),
    const _Row(r'com |com$|bun|pho|mien|xoi|bot', 8, 0),
  ];

  static final List<RegExp> _compiled = [
    for (final r in _rows) RegExp(r.pattern),
  ];

  static const double _defaultSodium = 30;
  static const double _defaultSugar = 1;

  /// Ước tính cho [grams] gram của một nguyên liệu gọi tên [name].
  static SugarSodium forIngredient(String name, double grams) {
    final folded = foldVietnamese(name);
    var sodium = _defaultSodium;
    var sugar = _defaultSugar;
    for (var i = 0; i < _rows.length; i++) {
      if (_compiled[i].hasMatch(folded)) {
        sodium = _rows[i].sodiumMgPer100g;
        sugar = _rows[i].sugarGPer100g;
        break;
      }
    }
    return SugarSodium(
      sugar: sugar * grams / 100,
      sodium: sodium * grams / 100,
    );
  }

  static final RegExp _gramsInName =
      RegExp(r'^(.*?)\s*\((\d+(?:[.,]\d+)?)\s*g\)');

  /// Ước tính cho một món gồm các dòng dạng `"Bánh phở tươi (150g)"`.
  /// Dòng không đọc được khối lượng thì bỏ qua.
  static SugarSodium forDish(Iterable<String> ingredientLines) {
    var total = SugarSodium.zero;
    for (final line in ingredientLines) {
      final m = _gramsInName.firstMatch(line);
      if (m == null) continue;
      final grams = double.tryParse(m.group(2)!.replaceAll(',', '.'));
      if (grams == null) continue;
      total = total + forIngredient(m.group(1)!, grams);
    }
    return SugarSodium(
      sugar: (total.sugar * 10).round() / 10,
      sodium: total.sodium.roundToDouble(),
    );
  }

  /// Chất xơ (g/100 g) ước tính theo nhóm cho nguyên liệu chưa có số liệu xơ.
  static double fiberPer100g(String name, String group) {
    final folded = foldVietnamese(name);
    if (folded.contains('yen mach')) return 10.6;
    if (folded.contains('hanh nhan')) return 12.5;
    if (folded.contains('dau phong')) return 8.5;
    switch (group) {
      case 'Rau củ':
        return 2.5;
      case 'Trái cây':
        return 2.3;
      case 'Tinh bột':
        return folded.contains('khoai') ? 2.4 : 0.8;
      default:
        return 0;
    }
  }
}
