import '../models/health_metric.dart';

/// Mức độ của một kết quả đánh giá, dùng để chọn màu hiển thị.
enum HealthLevel {
  /// Trong ngưỡng bình thường.
  normal,

  /// Lệch nhẹ khỏi ngưỡng bình thường, cần để ý.
  caution,

  /// Vượt ngưỡng cần chú ý, nên theo dõi hoặc đi khám.
  alert,

  /// Chưa có dữ liệu để đánh giá.
  unknown,
}

/// Kết quả đánh giá một chỉ số: nhãn tiếng Việt kèm mức độ.
class HealthStatus {
  final String label;
  final HealthLevel level;

  const HealthStatus(this.label, this.level);

  static const noData = HealthStatus('Chưa có dữ liệu', HealthLevel.unknown);

  @override
  bool operator ==(Object other) =>
      other is HealthStatus && other.label == label && other.level == level;

  @override
  int get hashCode => Object.hash(label, level);

  @override
  String toString() => 'HealthStatus($label, $level)';
}

/// Khoảng giá trị bình thường dùng để tô vùng tham chiếu trên biểu đồ.
///
/// Đầu nào là `null` nghĩa là không giới hạn phía đó.
class NormalRange {
  final double? min;
  final double? max;

  const NormalRange({this.min, this.max});
}

/// Đánh giá các chỉ số sức khỏe theo ngưỡng tham chiếu.
///
/// Chỉ chứa hàm thuần (không đọc database, không dùng Flutter) nên test được
/// trực tiếp. Căn cứ ngưỡng:
/// - BMI: khuyến nghị WHO cho người Châu Á (Nishida, The Lancet, 2004).
/// - Huyết áp: phân loại AHA/AMA (Shimbo và cộng sự, Circulation, 2020).
/// - Nhịp tim, đường huyết, giấc ngủ: ngưỡng tham chiếu phổ biến cho người
///   lớn (nhịp tim lúc nghỉ, đường huyết lúc đói, ngủ 7–9 giờ).
///
/// Đây là công cụ tham khảo, không thay thế chẩn đoán của bác sĩ.
class HealthAssessor {
  const HealthAssessor._();

  /// BMI = cân nặng (kg) / chiều cao (m)^2. Trả về `null` nếu thiếu hoặc sai
  /// dữ liệu đầu vào.
  static double? calculateBmi(double weightKg, double heightCm) {
    if (weightKg <= 0 || heightCm <= 0) return null;
    final meters = heightCm / 100;
    return weightKg / (meters * meters);
  }

  /// BMI theo chuẩn Châu Á: <18.5 thiếu cân, 18.5–22.9 bình thường,
  /// 23–24.9 thừa cân (tiền béo phì), từ 25 béo phì.
  ///
  /// Phân loại theo giá trị đã LÀM TRÒN 1 chữ số, đúng với số mà giao diện hiển
  /// thị (toStringAsFixed(1)). Nếu không, BMI 22.95 hiện "23.0" nhưng lại bị
  /// xếp "Bình thường" (ngưỡng thừa cân là 23.0), nhìn như app tự mâu thuẫn.
  static HealthStatus bmi(double rawValue) {
    if (rawValue <= 0) return HealthStatus.noData;
    final value = (rawValue * 10).round() / 10;
    if (value < 18.5) return const HealthStatus('Thiếu cân', HealthLevel.caution);
    if (value < 23) return const HealthStatus('Bình thường', HealthLevel.normal);
    if (value < 25) return const HealthStatus('Thừa cân', HealthLevel.caution);
    return const HealthStatus('Béo phì', HealthLevel.alert);
  }

  /// Huyết áp theo AHA/AMA. Kiểm tra từ mức nặng xuống nhẹ; chỉ cần MỘT trong
  /// hai chỉ số (trên hoặc dưới) chạm ngưỡng là xếp vào mức đó.
  ///
  /// - Độ 2: tâm thu ≥ 140 hoặc tâm trương ≥ 90
  /// - Độ 1: tâm thu 130–139 hoặc tâm trương 80–89
  /// - Tiền tăng huyết áp: tâm thu 120–129 và tâm trương < 80
  /// - Bình thường: tâm thu < 120 và tâm trương < 80
  static HealthStatus bloodPressure(double systolic, double diastolic) {
    if (systolic <= 0 || diastolic <= 0) return HealthStatus.noData;
    if (systolic >= 140 || diastolic >= 90) {
      return const HealthStatus('Tăng huyết áp độ 2', HealthLevel.alert);
    }
    if (systolic >= 130 || diastolic >= 80) {
      return const HealthStatus('Tăng huyết áp độ 1', HealthLevel.alert);
    }
    if (systolic >= 120) {
      return const HealthStatus('Tiền tăng huyết áp', HealthLevel.caution);
    }
    return const HealthStatus('Bình thường', HealthLevel.normal);
  }

  /// Nhịp tim lúc nghỉ của người lớn: 60–100 lần/phút là bình thường.
  static HealthStatus heartRate(double bpm) {
    if (bpm <= 0) return HealthStatus.noData;
    if (bpm < 60) return const HealthStatus('Chậm', HealthLevel.caution);
    if (bpm <= 100) return const HealthStatus('Bình thường', HealthLevel.normal);
    return const HealthStatus('Nhanh', HealthLevel.caution);
  }

  /// Đường huyết (mg/dL), tính theo mức lúc đói: <70 thấp, 70–99 bình thường,
  /// 100–125 hơi cao, từ 126 cao.
  static HealthStatus bloodGlucose(double mgDl) {
    if (mgDl <= 0) return HealthStatus.noData;
    if (mgDl < 70) return const HealthStatus('Thấp', HealthLevel.alert);
    if (mgDl < 100) return const HealthStatus('Bình thường', HealthLevel.normal);
    if (mgDl < 126) return const HealthStatus('Hơi cao', HealthLevel.caution);
    return const HealthStatus('Cao', HealthLevel.alert);
  }

  /// Giấc ngủ (giờ/đêm): 7–9 giờ là tốt cho người lớn.
  static HealthStatus sleep(double hours) {
    if (hours <= 0) return HealthStatus.noData;
    if (hours < 6) return const HealthStatus('Thiếu ngủ', HealthLevel.alert);
    if (hours < 7) return const HealthStatus('Hơi thiếu', HealthLevel.caution);
    if (hours <= 9) return const HealthStatus('Tốt', HealthLevel.normal);
    return const HealthStatus('Ngủ nhiều', HealthLevel.caution);
  }

  /// Ngưỡng huyết áp tâm thu: từ mức này trở lên không còn "bình thường".
  static const double systolicLimit = 120;

  /// Ngưỡng huyết áp tâm trương: từ mức này trở lên không còn "bình thường".
  static const double diastolicLimit = 80;

  /// Vùng bình thường của một loại chỉ số để vẽ lên biểu đồ, khớp với các
  /// hàm đánh giá ở trên. Trả về `null` nếu loại đó không có vùng riêng:
  /// - huyết áp có hai đường nên dùng [systolicLimit]/[diastolicLimit] vẽ
  ///   vạch ngưỡng thay cho vùng;
  /// - số bước chân không có ngưỡng;
  /// - cân nặng cần [heightCm] để suy ra từ BMI 18.5–22.9.
  ///
  /// Mốc trên của đường huyết (100) là mốc loại trừ: từ 100 trở lên là
  /// "Hơi cao".
  static NormalRange? normalRange(HealthMetricType type, {double? heightCm}) {
    switch (type) {
      case HealthMetricType.weight:
        if (heightCm == null || heightCm <= 0) return null;
        final meters = heightCm / 100;
        return NormalRange(min: 18.5 * meters * meters, max: 22.9 * meters * meters);
      case HealthMetricType.bmi:
        return const NormalRange(min: 18.5, max: 22.9);
      case HealthMetricType.heartRate:
        return const NormalRange(min: 60, max: 100);
      case HealthMetricType.bloodGlucose:
        return const NormalRange(min: 70, max: 100);
      case HealthMetricType.sleep:
        return const NormalRange(min: 7, max: 9);
      case HealthMetricType.bloodPressure:
      case HealthMetricType.steps:
        return null;
    }
  }

  /// Đánh giá một bản ghi bất kỳ theo loại của nó. Cân nặng và bước chân
  /// không có ngưỡng riêng nên trả về [HealthStatus.noData].
  static HealthStatus assess(HealthMetric metric) {
    switch (metric.type) {
      case HealthMetricType.bloodPressure:
        final diastolic = metric.valueSecondary;
        if (diastolic == null) return HealthStatus.noData;
        return bloodPressure(metric.value, diastolic);
      case HealthMetricType.heartRate:
        return heartRate(metric.value);
      case HealthMetricType.bloodGlucose:
        return bloodGlucose(metric.value);
      case HealthMetricType.sleep:
        return sleep(metric.value);
      case HealthMetricType.bmi:
        return bmi(metric.value);
      case HealthMetricType.weight:
      case HealthMetricType.steps:
        return HealthStatus.noData;
    }
  }
}
