import '../models/health_metric.dart';

/// Khoảng giá trị hợp lý của một ô nhập.
class _Range {
  final double min;
  final double max;
  final bool wholeOnly;

  const _Range(this.min, this.max, {this.wholeOnly = false});
}

/// Kiểm tra dữ liệu người dùng nhập vào form chỉ số sức khỏe.
///
/// Chỉ chứa hàm thuần (không dùng Flutter UI) nên test được trực tiếp.
/// Hàm `validate*` trả về `null` khi hợp lệ, ngược lại trả về câu báo lỗi
/// tiếng Việt để hiện ngay dưới form.
class HealthValidator {
  const HealthValidator._();

  static const int maxNoteLength = 200;

  static const _weight = _Range(20, 300);
  static const _systolic = _Range(60, 260, wholeOnly: true);
  static const _diastolic = _Range(30, 160, wholeOnly: true);
  static const _heartRate = _Range(30, 220, wholeOnly: true);
  static const _glucose = _Range(20, 600);
  static const _sleep = _Range(0.5, 24);
  static const _steps = _Range(1, 100000, wholeOnly: true);

  /// Đọc số từ ô nhập, chấp nhận cả dấu phẩy (`56,5`). Không đọc được hoặc
  /// không phải số hữu hạn thì trả về `null`.
  static double? parseNumber(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite) return null;
    return value;
  }

  /// Kiểm tra giá trị chính (và giá trị phụ với huyết áp).
  static String? validate(
    HealthMetricType type,
    double? value, {
    double? secondary,
  }) {
    switch (type) {
      case HealthMetricType.weight:
        return _check('Cân nặng', value, _weight, type.unit);
      case HealthMetricType.bloodPressure:
        final systolicError =
            _check('Huyết áp trên (tâm thu)', value, _systolic, type.unit);
        if (systolicError != null) return systolicError;
        final diastolicError = _check(
          'Huyết áp dưới (tâm trương)',
          secondary,
          _diastolic,
          type.unit,
        );
        if (diastolicError != null) return diastolicError;
        if (value! <= secondary!) {
          return 'Huyết áp trên phải lớn hơn huyết áp dưới.';
        }
        return null;
      case HealthMetricType.heartRate:
        return _check('Nhịp tim', value, _heartRate, type.unit);
      case HealthMetricType.bloodGlucose:
        return _check('Đường huyết', value, _glucose, type.unit);
      case HealthMetricType.sleep:
        return _check('Giấc ngủ', value, _sleep, type.unit);
      case HealthMetricType.steps:
        return _check('Số bước', value, _steps, type.unit);
      case HealthMetricType.bmi:
        return 'BMI được tự tính từ cân nặng và chiều cao, không nhập tay.';
    }
  }

  /// Thời điểm ghi nhận không được ở tương lai (cho lệch tối đa 1 phút để
  /// tránh báo sai khi người dùng chọn đúng giờ hiện tại).
  static String? validateRecordedAt(DateTime recordedAt, {DateTime? now}) {
    final limit = (now ?? DateTime.now()).add(const Duration(minutes: 1));
    if (recordedAt.isAfter(limit)) {
      return 'Thời điểm ghi nhận không được ở tương lai.';
    }
    return null;
  }

  static String? validateNote(String note) {
    if (note.trim().length > maxNoteLength) {
      return 'Ghi chú tối đa $maxNoteLength ký tự.';
    }
    return null;
  }

  static String? _check(String name, double? value, _Range range, String unit) {
    if (value == null) return 'Vui lòng nhập $name hợp lệ.';
    if (value < range.min || value > range.max) {
      return '$name cần nằm trong khoảng '
          '${_fmt(range.min)}–${_fmt(range.max)} $unit.';
    }
    if (range.wholeOnly && value != value.roundToDouble()) {
      return '$name phải là số nguyên.';
    }
    return null;
  }

  static String _fmt(double number) {
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }
}
