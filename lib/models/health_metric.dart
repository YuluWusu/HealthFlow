/// Các loại chỉ số sức khỏe mà ứng dụng theo dõi.
///
/// [label] dùng cho giao diện, [unit] là đơn vị hiển thị, [storeName] là giá
/// trị lưu xuống cơ sở dữ liệu (không dùng chỉ số thứ tự của enum để dữ liệu
/// không bị lệch khi sau này thêm loại mới vào giữa danh sách).
enum HealthMetricType {
  weight('weight', 'Cân nặng', 'kg'),
  bloodPressure('blood_pressure', 'Huyết áp', 'mmHg'),
  heartRate('heart_rate', 'Nhịp tim', 'bpm'),
  bloodGlucose('blood_glucose', 'Đường huyết', 'mg/dL'),
  sleep('sleep', 'Giấc ngủ', 'giờ'),
  steps('steps', 'Vận động', 'bước'),

  /// BMI theo từng lần cân. Do ứng dụng TỰ GHI từ cân nặng và chiều cao tại
  /// thời điểm cân, người dùng không nhập tay (xem [isDerived]).
  bmi('bmi', 'BMI', 'kg/m²');

  const HealthMetricType(this.storeName, this.label, this.unit);

  final String storeName;
  final String label;
  final String unit;

  /// Loại chỉ số được tính ra từ chỉ số khác, không cho nhập, sửa hay xóa
  /// riêng lẻ (xóa hoặc sửa lần cân thì BMI đi kèm tự cập nhật theo).
  bool get isDerived => this == HealthMetricType.bmi;

  /// Các loại người dùng được nhập tay (dùng cho form thêm chỉ số).
  static List<HealthMetricType> get userEntered => [
    for (final type in values)
      if (!type.isDerived) type,
  ];

  static HealthMetricType fromStoreName(String value) {
    return HealthMetricType.values.firstWhere(
      (type) => type.storeName == value,
      orElse: () => HealthMetricType.weight,
    );
  }
}

/// Một lần ghi nhận chỉ số sức khỏe của người dùng.
///
/// [value] là giá trị chính. Riêng huyết áp dùng thêm [valueSecondary] cho
/// chỉ số dưới (ví dụ 120/80).
class HealthMetric {
  final String id;
  final String userId;
  final HealthMetricType type;
  final double value;
  final double? valueSecondary;
  final DateTime recordedAt;
  final String note;

  const HealthMetric({
    required this.id,
    required this.userId,
    required this.type,
    required this.value,
    this.valueSecondary,
    required this.recordedAt,
    this.note = '',
  });

  /// Mã bản ghi BMI đi kèm một lần cân. Suy ra từ mã lần cân nên sửa hoặc xóa
  /// lần cân là tìm được đúng bản ghi BMI tương ứng.
  static String bmiIdFor(String weightId) => 'bmi-$weightId';

  /// Chuỗi hiển thị đã kèm đơn vị, ví dụ `120/80 mmHg` hoặc `56.5 kg`.
  String get displayValue {
    final main = _formatNumber(value);
    if (valueSecondary != null) {
      return '$main/${_formatNumber(valueSecondary!)} ${type.unit}';
    }
    return '$main ${type.unit}';
  }

  /// Giá trị dạng số đã bỏ số 0 thừa ở phần thập phân (56.50 -> 56.5,
  /// 72.0 -> 72) để giao diện gọn như bản thiết kế.
  static String _formatNumber(double number) {
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(1);
  }

  HealthMetric copyWith({
    double? value,
    double? valueSecondary,
    DateTime? recordedAt,
    String? note,
  }) {
    return HealthMetric(
      id: id,
      userId: userId,
      type: type,
      value: value ?? this.value,
      valueSecondary: valueSecondary ?? this.valueSecondary,
      recordedAt: recordedAt ?? this.recordedAt,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.storeName,
      'value': value,
      'value_secondary': valueSecondary,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
      'note': note,
    };
  }

  factory HealthMetric.fromMap(Map<String, Object?> map) {
    return HealthMetric(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: HealthMetricType.fromStoreName(map['type'] as String),
      value: (map['value'] as num).toDouble(),
      valueSecondary: (map['value_secondary'] as num?)?.toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['recorded_at'] as num).toInt(),
      ),
      note: map['note'] as String? ?? '',
    );
  }
}

/// Kết quả so sánh chỉ số mới nhất với lần ghi trước đó, phục vụ dòng
/// "giảm 0.3 kg so với tuần trước" trên trang chủ.
class MetricTrend {
  final double difference;
  final bool hasPrevious;

  const MetricTrend({required this.difference, required this.hasPrevious});

  bool get isDecrease => difference < 0;
  bool get isIncrease => difference > 0;

  String get display {
    if (!hasPrevious) return 'Chưa có dữ liệu so sánh';
    if (difference == 0) return 'Không đổi so với lần trước';
    final amount = difference.abs().toStringAsFixed(1);
    return isDecrease
        ? 'Giảm $amount so với lần trước'
        : 'Tăng $amount so với lần trước';
  }
}
