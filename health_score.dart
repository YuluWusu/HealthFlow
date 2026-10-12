import '../models/health_metric.dart';
import 'health_assessor.dart';

/// Các mục cấu thành điểm sức khỏe, kèm số điểm tối đa của từng mục.
///
/// Tổng điểm tối đa là 100. Năm mục đầu lấy trạng thái từ [HealthAssessor]
/// (ngưỡng WHO châu Á, AHA/AMA...), mục cuối đo thói quen ghi nhận chứ không
/// phải tình trạng cơ thể.
enum HealthScoreFactor {
  bmi('BMI', 20),
  bloodPressure('Huyết áp', 25),
  bloodGlucose('Đường huyết', 20),
  heartRate('Nhịp tim', 10),
  sleep('Giấc ngủ', 10),
  regularity('Độ đều đặn đo', 15);

  const HealthScoreFactor(this.label, this.weight);

  final String label;

  /// Số điểm tối đa của mục này khi cả 6 mục đều có dữ liệu.
  final int weight;

  /// `true` với 5 mục đánh giá chỉ số cơ thể, `false` với độ đều đặn đo.
  bool get isClinical => this != HealthScoreFactor.regularity;

  /// Loại chỉ số tương ứng, `null` với [regularity].
  HealthMetricType? get metricType {
    switch (this) {
      case HealthScoreFactor.bmi:
        return HealthMetricType.bmi;
      case HealthScoreFactor.bloodPressure:
        return HealthMetricType.bloodPressure;
      case HealthScoreFactor.bloodGlucose:
        return HealthMetricType.bloodGlucose;
      case HealthScoreFactor.heartRate:
        return HealthMetricType.heartRate;
      case HealthScoreFactor.sleep:
        return HealthMetricType.sleep;
      case HealthScoreFactor.regularity:
        return null;
    }
  }
}

/// Mức xếp loại của điểm, dùng để chọn lời nhắn và màu.
enum HealthScoreBand {
  good('Tốt'),
  fair('Khá'),
  needsWork('Cần cải thiện'),
  attention('Cần chú ý');

  const HealthScoreBand(this.label);

  final String label;

  static HealthScoreBand of(int value) {
    if (value >= 85) return HealthScoreBand.good;
    if (value >= 70) return HealthScoreBand.fair;
    if (value >= 50) return HealthScoreBand.needsWork;
    return HealthScoreBand.attention;
  }
}

/// Một dòng trong phần "điểm bị trừ vì đâu".
class HealthScoreItem {
  const HealthScoreItem({
    required this.factor,
    required this.statusLabel,
    required this.level,
    required this.maxPoints,
    required this.deduction,
    required this.measured,
  });

  final HealthScoreFactor factor;

  /// Nhãn trạng thái, ví dụ `Tăng huyết áp độ 1` hoặc `4/14 ngày có ghi nhận`.
  final String statusLabel;
  final HealthLevel level;

  /// Số điểm tối đa của mục này SAU khi chia lại theo các mục có dữ liệu.
  /// Bằng 0 nếu mục không được tính.
  final int maxPoints;

  /// Số điểm bị trừ ở mục này (đã làm tròn). Tổng các mục bằng 100 trừ điểm.
  final int deduction;

  /// `false` nếu chưa có dữ liệu (hoặc dữ liệu quá cũ) nên mục không được tính.
  final bool measured;

  String get label => factor.label;
}

/// Kết quả tính điểm sức khỏe.
class HealthScore {
  const HealthScore({
    required this.value,
    required this.items,
    required this.measuredCount,
  });

  /// Điểm 0 đến 100. `null` khi chưa đủ dữ liệu để chấm.
  final int? value;

  /// Đủ 6 mục theo thứ tự của [HealthScoreFactor], kể cả mục chưa đo.
  final List<HealthScoreItem> items;

  /// Số chỉ số cơ thể (trong 5 mục) đang có dữ liệu còn mới.
  final int measuredCount;

  bool get isReady => value != null;

  HealthScoreBand? get band => value == null ? null : HealthScoreBand.of(value!);

  /// 5 mục đánh giá chỉ số cơ thể, không gồm độ đều đặn đo.
  List<HealthScoreItem> get clinicalItems =>
      items.where((item) => item.factor.isClinical).toList(growable: false);

  /// Các mục bị trừ điểm, trừ nhiều nhất xếp trước.
  List<HealthScoreItem> get deductions {
    final list = items.where((item) => item.deduction > 0).toList();
    list.sort((a, b) {
      final byPoints = b.deduction.compareTo(a.deduction);
      return byPoints != 0
          ? byPoints
          : a.factor.index.compareTo(b.factor.index);
    });
    return list;
  }
}

/// Tính điểm sức khỏe 0 đến 100 từ các bản ghi.
///
/// Đây là ĐIỂM THAM KHẢO để theo dõi xu hướng, không phải chẩn đoán y tế.
/// Mọi con số đều truy ngược được:
///
/// - Mỗi mục có số điểm tối đa ([HealthScoreFactor.weight]).
/// - Mục ở mức "lưu ý" mất [cautionLoss] điểm của mục đó, mức "cảnh báo" mất
///   [alertLoss]. Mức do [HealthAssessor] quyết định, không có ngưỡng riêng.
/// - Chỉ dùng bản ghi mới nhất của từng loại và chỉ khi nó không quá
///   [freshDays] ngày. Mục thiếu dữ liệu bị bỏ ra khỏi phép tính (không bị coi
///   là 0 điểm) và điểm các mục còn lại được chia lại cho đủ 100.
/// - Cần ít nhất [minMeasured] trong 5 chỉ số cơ thể thì mới chấm điểm.
/// - Độ đều đặn đo: số ngày có ghi nhận trong [regularityWindowDays] ngày gần
///   nhất so với mục tiêu [regularityTargetDays] ngày. Đây là quy ước về thói
///   quen, không phải chuẩn y khoa.
///
/// Điểm = 100 trừ tổng các khoản đã làm tròn, nên các dòng "điểm bị trừ" cộng
/// lại luôn khớp đúng với điểm hiển thị.
class HealthScoreCalculator {
  const HealthScoreCalculator._();

  static const int freshDays = 30;
  static const int minMeasured = 3;
  static const int regularityWindowDays = 14;
  static const int regularityTargetDays = 6;
  static const double cautionLoss = 0.4;
  static const double alertLoss = 0.8;

  static double _lossOf(HealthLevel level) {
    switch (level) {
      case HealthLevel.caution:
        return cautionLoss;
      case HealthLevel.alert:
        return alertLoss;
      case HealthLevel.normal:
      case HealthLevel.unknown:
        return 0;
    }
  }

  /// Tính điểm tại thời điểm [asOf]: chỉ xét các bản ghi không muộn hơn [asOf].
  ///
  /// [bmi] là BMI hiện tại theo hồ sơ. Khi `null` thì lấy bản ghi BMI mới nhất
  /// (dùng để tính lại điểm của tuần trước).
  static HealthScore calculate(
    List<HealthMetric> metrics, {
    required DateTime asOf,
    double? bmi,
  }) {
    final cutoff = asOf.subtract(const Duration(days: freshDays));

    // Bản ghi mới nhất còn "tươi" của từng loại; loại nào chỉ có bản ghi quá
    // cũ thì nhớ lại để báo "đã quá 30 ngày chưa đo".
    final latest = <HealthMetricType, HealthMetric>{};
    final stale = <HealthMetricType>{};
    for (final metric in metrics) {
      if (metric.recordedAt.isAfter(asOf)) continue;
      if (metric.recordedAt.isBefore(cutoff)) {
        stale.add(metric.type);
        continue;
      }
      final current = latest[metric.type];
      if (current == null || metric.recordedAt.isAfter(current.recordedAt)) {
        latest[metric.type] = metric;
      }
    }

    HealthStatus statusOf(HealthMetricType type) {
      if (type == HealthMetricType.bmi && bmi != null && bmi > 0) {
        return HealthAssessor.bmi(bmi);
      }
      final record = latest[type];
      return record == null ? HealthStatus.noData : HealthAssessor.assess(record);
    }

    final clinicalFactors =
        HealthScoreFactor.values.where((f) => f.isClinical).toList();
    final statuses = <HealthScoreFactor, HealthStatus>{
      for (final factor in clinicalFactors) factor: statusOf(factor.metricType!),
    };
    bool isMeasured(HealthScoreFactor f) =>
        statuses[f]!.level != HealthLevel.unknown;
    final measuredCount = clinicalFactors.where(isMeasured).length;

    // Độ đều đặn: số ngày (theo lịch) có ít nhất một bản ghi do người dùng
    // nhập trong cửa sổ gần nhất. BMI tự sinh nên không tính.
    final windowStart = asOf.subtract(const Duration(days: regularityWindowDays));
    final activeDays = <int>{};
    for (final metric in metrics) {
      if (metric.type.isDerived) continue;
      if (metric.recordedAt.isAfter(asOf)) continue;
      if (!metric.recordedAt.isAfter(windowStart)) continue;
      final d = metric.recordedAt;
      activeDays.add(d.year * 10000 + d.month * 100 + d.day);
    }
    final regularityMissing =
        1 - (activeDays.length / regularityTargetDays).clamp(0.0, 1.0).toDouble();
    final regularityLevel = regularityMissing == 0
        ? HealthLevel.normal
        : regularityMissing <= 0.5
            ? HealthLevel.caution
            : HealthLevel.alert;
    final regularityLabel =
        '${activeDays.length}/$regularityWindowDays ngày có ghi nhận';

    final ready = measuredCount >= minMeasured;

    // Chia lại điểm: tổng điểm tối đa của các mục được tính phải là 100.
    var possible = HealthScoreFactor.regularity.weight;
    for (final factor in clinicalFactors) {
      if (isMeasured(factor)) possible += factor.weight;
    }
    final scale = 100 / possible;

    final items = <HealthScoreItem>[];
    var totalDeduction = 0;
    for (final factor in HealthScoreFactor.values) {
      if (factor.isClinical) {
        final status = statuses[factor]!;
        final measured = isMeasured(factor);
        final max = measured && ready ? factor.weight * scale : 0.0;
        final deduction = (max * _lossOf(status.level)).round();
        totalDeduction += deduction;
        items.add(HealthScoreItem(
          factor: factor,
          statusLabel: measured
              ? status.label
              : stale.contains(factor.metricType)
                  ? 'Đã quá $freshDays ngày chưa đo'
                  : status.label,
          level: status.level,
          maxPoints: max.round(),
          deduction: deduction,
          measured: measured,
        ));
      } else {
        final max = ready ? factor.weight * scale : 0.0;
        final deduction = (max * regularityMissing).round();
        totalDeduction += deduction;
        items.add(HealthScoreItem(
          factor: factor,
          statusLabel: regularityLabel,
          level: regularityLevel,
          maxPoints: max.round(),
          deduction: deduction,
          measured: true,
        ));
      }
    }

    return HealthScore(
      value: ready ? (100 - totalDeduction).clamp(0, 100).toInt() : null,
      items: items,
      measuredCount: measuredCount,
    );
  }

  /// Điểm hiện tại hơn kém điểm cách đây [days] ngày bao nhiêu. `null` nếu một
  /// trong hai thời điểm chưa đủ dữ liệu để chấm.
  ///
  /// Điểm cũ tính lại từ chính các bản ghi tại thời điểm đó, nên không cần lưu
  /// lịch sử điểm.
  static int? changeSince(
    List<HealthMetric> metrics, {
    required HealthScore current,
    required DateTime asOf,
    int days = 7,
  }) {
    final now = current.value;
    if (now == null) return null;
    final before = calculate(
      metrics,
      asOf: asOf.subtract(Duration(days: days)),
    ).value;
    if (before == null) return null;
    return now - before;
  }
}