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
  steps('steps', 'Vận động', 'bước');

  const HealthMetricType(this.storeName, this.label, this.unit);

  final String storeName;
  final String label;
  final String unit;

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
