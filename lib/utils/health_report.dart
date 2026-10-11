import '../models/health_metric.dart';
import '../models/user.dart';
import 'health_analyzer.dart';
import 'health_assessor.dart';
import 'series_summary.dart';

/// Xu hướng của một chỉ số trong tháng.
enum ReportTrend { up, down, stable, notEnoughData }

/// Thông tin người bệnh in ở đầu báo cáo.
class ReportPatient {
  const ReportPatient({
    required this.name,
    required this.gender,
    required this.heightCm,
    this.healthGoal = '',
    this.targetWeightKg,
  });

  factory ReportPatient.fromUser(User user) => ReportPatient(
        name: user.fullName,
        gender: user.gender,
        heightCm: user.heightCm,
        healthGoal: user.healthGoal,
        targetWeightKg: user.targetWeightKg,
      );

  final String name;

  /// 'male' hoặc 'female'.
  final String gender;
  final double heightCm;
  final String healthGoal;
  final double? targetWeightKg;

  String get genderText => gender == 'female' ? 'Nữ' : 'Nam';
}

/// Tóm tắt một loại chỉ số trong tháng: thấp nhất / trung bình / cao nhất,
/// xu hướng và đánh giá lần ghi gần nhất.
class MetricSummary {
  const MetricSummary({
    required this.type,
    required this.count,
    required this.primary,
    required this.secondary,
    required this.trend,
    required this.change,
    required this.latest,
    required this.latestStatus,
    required this.flaggedCount,
    required this.alertCount,
    required this.latestFlagged,
  });

  final HealthMetricType type;
  final int count;

  /// Thống kê giá trị chính (huyết áp: tâm thu).
  final SeriesSummary primary;

  /// Chỉ huyết áp có: thống kê tâm trương.
  final SeriesSummary? secondary;

  final ReportTrend trend;

  /// Mức thay đổi giữa nửa đầu và nửa sau tháng (giá trị chính).
  /// `null` khi [trend] là [ReportTrend.notEnoughData].
  final double? change;

  final HealthMetric latest;
  final HealthStatus latestStatus;

  /// Số lần ghi ngoài ngưỡng bình thường (mức lưu ý hoặc cảnh báo).
  final int flaggedCount;

  /// Trong đó số lần ở mức cảnh báo (nặng).
  final int alertCount;

  /// Lần ghi ngoài ngưỡng gần nhất, `null` nếu không có.
  final HealthMetric? latestFlagged;

  bool get isBloodPressure => type == HealthMetricType.bloodPressure;

  String get minText => _pair(primary.min, secondary?.min);
  String get avgText => _pair(primary.average, secondary?.average);
  String get maxText => _pair(primary.max, secondary?.max);

  String _pair(double main, double? sub) {
    final digits = MonthlyHealthReport.fractionDigits(type);
    final a = main.toStringAsFixed(digits);
    return sub == null ? a : '$a/${sub.toStringAsFixed(digits)}';
  }

  /// Ví dụ "Giảm 0.5 kg", "Ổn định", "Tâm thu tăng 6 mmHg".
  String get trendText {
    switch (trend) {
      case ReportTrend.notEnoughData:
        return 'Chưa đủ dữ liệu';
      case ReportTrend.stable:
        return 'Ổn định';
      case ReportTrend.up:
      case ReportTrend.down:
        final digits = MonthlyHealthReport.fractionDigits(type);
        final amount = change!.abs().toStringAsFixed(digits);
        final verb = trend == ReportTrend.up ? 'tăng' : 'giảm';
        final unit = type.unit.isEmpty ? '' : ' ${type.unit}';
        if (isBloodPressure) return 'Tâm thu $verb $amount$unit';
        return '${verb[0].toUpperCase()}${verb.substring(1)} $amount$unit';
    }
  }

  /// Lần ghi gần nhất kèm đánh giá, ví dụ "120/80 mmHg (Tiền tăng huyết áp)".
  String get latestText {
    final label = latestStatus.level == HealthLevel.unknown
        ? ''
        : ' (${latestStatus.label})';
    return '${latest.displayValue}$label';
  }
}

/// Một dòng cảnh báo trong báo cáo.
class ReportAlert {
  const ReportAlert({
    required this.title,
    required this.message,
    required this.isSevere,
  });

  final String title;
  final String message;

  /// `true` khi có chỉ số ở mức cảnh báo (nặng), `false` khi chỉ cần lưu ý.
  final bool isSevere;
}

/// Báo cáo sức khỏe một tháng, dùng để in/gửi cho bác sĩ.
///
/// Chỉ chứa dữ liệu đã tính sẵn (không phụ thuộc Flutter hay thư viện PDF) nên
/// test được trực tiếp; phần vẽ PDF nằm ở `HealthReportPdf`.
class MonthlyHealthReport {
  const MonthlyHealthReport({
    required this.year,
    required this.month,
    required this.generatedAt,
    required this.patient,
    required this.summaries,
    required this.missingTypes,
    required this.alerts,
    required this.readings,
    required this.latestWeightKg,
    required this.bmi,
    required this.bmiStatus,
  });

  /// Các chỉ số người dùng tự nhập được đưa vào báo cáo, theo thứ tự hiển thị.
  static const List<HealthMetricType> reportedTypes = [
    HealthMetricType.weight,
    HealthMetricType.bloodPressure,
    HealthMetricType.heartRate,
    HealthMetricType.bloodGlucose,
    HealthMetricType.sleep,
    HealthMetricType.steps,
  ];

  final int year;
  final int month;
  final DateTime generatedAt;
  final ReportPatient patient;

  /// Chỉ các loại chỉ số có dữ liệu trong tháng.
  final List<MetricSummary> summaries;

  /// Các loại chỉ số hoàn toàn không có dữ liệu trong tháng.
  final List<HealthMetricType> missingTypes;

  /// Cảnh báo, mức nặng xếp trước.
  final List<ReportAlert> alerts;

  /// Toàn bộ lần ghi trong tháng (không gồm BMI tự suy ra), cũ đến mới.
  final List<HealthMetric> readings;

  /// Cân nặng lần cân gần nhất trong tháng, `null` nếu không có.
  final double? latestWeightKg;

  /// BMI tính từ [latestWeightKg] và chiều cao; `null` nếu thiếu dữ liệu.
  final double? bmi;
  final HealthStatus? bmiStatus;

  String get periodText => 'Tháng $month/$year';
  bool get hasData => readings.isNotEmpty;
  int get totalReadings => readings.length;

  /// Số chữ số thập phân khi in thống kê của từng loại chỉ số.
  static int fractionDigits(HealthMetricType type) {
    switch (type) {
      case HealthMetricType.weight:
      case HealthMetricType.bloodGlucose:
      case HealthMetricType.sleep:
        return 1;
      case HealthMetricType.bloodPressure:
      case HealthMetricType.heartRate:
      case HealthMetricType.steps:
      case HealthMetricType.bmi:
        return 0;
    }
  }

  /// Mức thay đổi nhỏ hơn ngưỡng này coi là "ổn định".
  static double stableTolerance(HealthMetricType type) {
    switch (type) {
      case HealthMetricType.weight:
        return 0.5;
      case HealthMetricType.bloodPressure:
      case HealthMetricType.heartRate:
      case HealthMetricType.bloodGlucose:
        return 5;
      case HealthMetricType.sleep:
        return 0.5;
      case HealthMetricType.steps:
        return 1000;
      case HealthMetricType.bmi:
        return 0.3;
    }
  }

  /// Dựng báo cáo tháng [month]/[year] từ danh sách chỉ số bất kỳ.
  static MonthlyHealthReport build({
    required List<HealthMetric> metrics,
    required ReportPatient patient,
    required int year,
    required int month,
    required DateTime generatedAt,
  }) {
    final inMonth = metrics
        .where((m) =>
            !m.type.isDerived &&
            m.recordedAt.year == year &&
            m.recordedAt.month == month)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final summaries = <MetricSummary>[];
    final missing = <HealthMetricType>[];
    for (final type in reportedTypes) {
      final list = inMonth.where((m) => m.type == type).toList();
      if (list.isEmpty) {
        missing.add(type);
      } else {
        summaries.add(_summarize(type, list));
      }
    }

    final weights = inMonth.where((m) => m.type == HealthMetricType.weight);
    final latestWeight = weights.isEmpty ? null : weights.last.value;
    final bmi = latestWeight == null
        ? null
        : HealthAssessor.calculateBmi(latestWeight, patient.heightCm);
    final bmiStatus = bmi == null ? null : HealthAssessor.bmi(bmi);

    return MonthlyHealthReport(
      year: year,
      month: month,
      generatedAt: generatedAt,
      patient: patient,
      summaries: summaries,
      missingTypes: missing,
      alerts: _buildAlerts(summaries, inMonth, bmi, bmiStatus, weights.toList()),
      readings: inMonth,
      latestWeightKg: latestWeight,
      bmi: bmi,
      bmiStatus: bmiStatus,
    );
  }

  /// [ascending] đã xếp cũ -> mới và không rỗng.
  static MetricSummary _summarize(
    HealthMetricType type,
    List<HealthMetric> ascending,
  ) {
    final primary = SeriesSummary.of([for (final m in ascending) m.value])!;
    final secondaryValues = [
      for (final m in ascending)
        if (m.valueSecondary != null) m.valueSecondary!
    ];
    final secondary = type == HealthMetricType.bloodPressure
        ? SeriesSummary.of(secondaryValues)
        : null;

    // Xu hướng: trung bình nửa đầu so với nửa sau (bỏ lần ở giữa nếu số lẻ),
    // để một lần đo lệch không làm đổi kết luận như khi chỉ so đầu - cuối.
    ReportTrend trend = ReportTrend.notEnoughData;
    double? change;
    final n = ascending.length;
    if (n >= 2) {
      final h = n ~/ 2;
      double avg(Iterable<HealthMetric> items) =>
          items.map((m) => m.value).reduce((a, b) => a + b) / items.length;
      change = avg(ascending.skip(n - h)) - avg(ascending.take(h));
      final tolerance = stableTolerance(type);
      if (change.abs() < tolerance) {
        trend = ReportTrend.stable;
      } else {
        trend = change > 0 ? ReportTrend.up : ReportTrend.down;
      }
    }

    var flagged = 0;
    var alerts = 0;
    HealthMetric? latestFlagged;
    for (final m in ascending) {
      final level = HealthAssessor.assess(m).level;
      if (level == HealthLevel.caution || level == HealthLevel.alert) {
        flagged++;
        latestFlagged = m;
        if (level == HealthLevel.alert) alerts++;
      }
    }

    final latest = ascending.last;
    return MetricSummary(
      type: type,
      count: n,
      primary: primary,
      secondary: secondary,
      trend: trend,
      change: change,
      latest: latest,
      latestStatus: HealthAssessor.assess(latest),
      flaggedCount: flagged,
      alertCount: alerts,
      latestFlagged: latestFlagged,
    );
  }

  static String _dm(DateTime d) => '${d.day}/${d.month}';

  static List<ReportAlert> _buildAlerts(
    List<MetricSummary> summaries,
    List<HealthMetric> inMonth,
    double? bmi,
    HealthStatus? bmiStatus,
    List<HealthMetric> weightsAscending,
  ) {
    final alerts = <ReportAlert>[];

    for (final s in summaries) {
      final flagged = s.latestFlagged;
      if (s.flaggedCount == 0 || flagged == null) continue;
      final status = HealthAssessor.assess(flagged);
      alerts.add(ReportAlert(
        title: s.type.label,
        message: '${s.flaggedCount}/${s.count} lần đo ngoài ngưỡng bình thường. '
            'Gần nhất: ${flagged.displayValue} (${status.label}, ${_dm(flagged.recordedAt)}).',
        isSevere: s.alertCount > 0,
      ));
    }

    if (bmi != null && bmiStatus != null && bmiStatus.level != HealthLevel.normal &&
        bmiStatus.level != HealthLevel.unknown) {
      alerts.add(ReportAlert(
        title: 'Chỉ số BMI',
        message:
            'BMI ${bmi.toStringAsFixed(1)} (${bmiStatus.label}) theo lần cân gần nhất trong tháng.',
        isSevere: bmiStatus.level == HealthLevel.alert,
      ));
    }

    // Cảnh báo xu hướng dùng lại ngưỡng của HealthAnalyzer; chỉ lấy tiêu đề
    // (có số liệu) vì phần lời khuyên viết cho người dùng chứ không cho bác sĩ.
    final weightsNewestFirst = weightsAscending.reversed.toList();
    final weightTrend = HealthAnalyzer.weightTrend(weightsNewestFirst);
    if (weightTrend != null && weightTrend.level != InsightLevel.normal) {
      alerts.add(ReportAlert(
        title: 'Xu hướng cân nặng',
        message: weightTrend.title,
        isSevere: weightTrend.level == InsightLevel.danger,
      ));
    }

    final glucoseNewestFirst = inMonth
        .where((m) => m.type == HealthMetricType.bloodGlucose)
        .toList()
        .reversed
        .toList();
    final glucoseTrend = HealthAnalyzer.glucoseRising(glucoseNewestFirst);
    if (glucoseTrend != null) {
      alerts.add(ReportAlert(
        title: 'Xu hướng đường huyết',
        message: glucoseTrend.title,
        isSevere: glucoseTrend.level == InsightLevel.danger,
      ));
    }

    // Mức nặng xếp trước, giữ nguyên thứ tự còn lại.
    return [
      ...alerts.where((a) => a.isSevere),
      ...alerts.where((a) => !a.isSevere),
    ];
  }
}
