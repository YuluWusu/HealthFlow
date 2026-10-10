import '../models/health_metric.dart';

/// Tình trạng so với cân nặng mong muốn của người dùng.
enum ForecastTargetState {
  /// Người dùng chưa đặt cân nặng mong muốn.
  none,

  /// Cân nặng hiện tại đã (gần) bằng mức mong muốn.
  reached,

  /// Đang đi đúng hướng, có thể ước lượng số tuần còn lại.
  onTrack,

  /// Cân nặng gần như không đổi nên không thể ước lượng thời điểm đạt mục tiêu.
  flat,

  /// Đang đi ngược hướng với mục tiêu (ví dụ muốn giảm nhưng đang tăng).
  wrongWay,
}

/// Kết quả dự báo cân nặng "với tốc độ này, sau N tuần bạn sẽ nặng bao nhiêu".
///
/// Tốc độ được tính bằng hồi quy tuyến tính (bình phương tối thiểu) trên các
/// lần cân trong [WeightForecast.windowDays] ngày gần nhất, nên một lần cân
/// lệch (do ăn mặn, giữ nước...) ít làm méo kết quả hơn cách chỉ so hai lần
/// cân đầu - cuối. Đây là ước lượng tham khảo, không phải chỉ định y khoa.
class WeightForecast {
  const WeightForecast({
    required this.currentKg,
    required this.slopeKgPerWeek,
    required this.horizonWeeks,
    required this.projectedKg,
    required this.sampleCount,
    required this.spanDays,
    required this.targetState,
    this.targetKg,
    this.weeksToTarget,
  });

  /// Số ngày gần nhất được dùng để tính tốc độ.
  static const int windowDays = 42;

  /// Cần các lần cân trải trên ít nhất chừng này ngày mới kết luận
  /// (cùng ngưỡng với [HealthAnalyzer.weightTrend]).
  static const int minSpanDays = 5;

  /// Chênh lệch (kg) coi như đã đạt mục tiêu.
  static const double reachedToleranceKg = 0.3;

  /// Tốc độ (kg/tuần) nhỏ hơn mức này coi là đứng yên.
  static const double flatKgPerWeek = 0.05;

  /// Ngưỡng cảnh báo tốc độ thay đổi quá nhanh (kg/tuần), khớp với analyzer.
  static const double fastGainKgPerWeek = 0.5;
  static const double fastLossKgPerWeek = -1.0;

  /// Cân nặng ở lần cân mới nhất.
  final double currentKg;

  /// Tốc độ thay đổi ước lượng, kg/tuần (âm = đang giảm).
  final double slopeKgPerWeek;

  final int horizonWeeks;

  /// Cân nặng dự báo sau [horizonWeeks] tuần nếu giữ nguyên tốc độ.
  final double projectedKg;

  /// Số lần cân đã dùng và khoảng thời gian chúng trải ra (ngày).
  final int sampleCount;
  final int spanDays;

  final double? targetKg;
  final ForecastTargetState targetState;

  /// Số tuần còn lại để chạm mục tiêu; chỉ có khi [targetState] là onTrack.
  final double? weeksToTarget;

  double get changeKg => projectedKg - currentKg;

  /// Ít dữ liệu: dưới 3 lần cân hoặc các lần cân trải dưới 14 ngày.
  bool get isLowConfidence => sampleCount < 3 || spanDays < 14;

  bool get isFastLoss => slopeKgPerWeek < fastLossKgPerWeek;
  bool get isFastGain => slopeKgPerWeek > fastGainKgPerWeek;

  /// Có chạm mục tiêu trong khoảng dự báo hay không.
  bool get reachesTargetWithinHorizon =>
      targetState == ForecastTargetState.onTrack &&
      weeksToTarget != null &&
      weeksToTarget! <= horizonWeeks;

  /// Tính dự báo từ danh sách chỉ số (mọi loại, thứ tự bất kỳ).
  ///
  /// Trả về `null` khi chưa đủ dữ liệu: dưới 2 lần cân, các lần cân cách
  /// nhau chưa tới [minSpanDays] ngày, hoặc kết quả vô lý.
  static WeightForecast? compute(
    List<HealthMetric> metrics, {
    required DateTime asOf,
    double? targetKg,
    int horizonWeeks = 6,
  }) {
    final windowStart = asOf.subtract(const Duration(days: windowDays));
    final weights = metrics
        .where((m) =>
            m.type == HealthMetricType.weight &&
            !m.recordedAt.isAfter(asOf) &&
            !m.recordedAt.isBefore(windowStart))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    if (weights.length < 2) return null;

    final first = weights.first.recordedAt;
    final latest = weights.last;
    final spanDays = latest.recordedAt.difference(first).inHours / 24.0;
    if (spanDays < minSpanDays) return null;

    // Hồi quy y = a + b·t với t là số ngày kể từ lần cân đầu tiên.
    final n = weights.length;
    final ts = [
      for (final w in weights) w.recordedAt.difference(first).inMinutes / 1440.0
    ];
    final ys = [for (final w in weights) w.value];
    final meanT = ts.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    var sxx = 0.0;
    var sxy = 0.0;
    for (var i = 0; i < n; i++) {
      sxx += (ts[i] - meanT) * (ts[i] - meanT);
      sxy += (ts[i] - meanT) * (ys[i] - meanY);
    }
    if (sxx == 0) return null;

    final slopePerWeek = sxy / sxx * 7;
    final current = latest.value;
    final projected = current + slopePerWeek * horizonWeeks;
    // Cùng khoảng hợp lệ với màn hình nhập cân nặng (10-300 kg).
    if (projected < 10 || projected > 300) return null;

    var state = ForecastTargetState.none;
    double? weeksToTarget;
    if (targetKg != null) {
      final gap = targetKg - current;
      if (gap.abs() <= reachedToleranceKg) {
        state = ForecastTargetState.reached;
      } else if (slopePerWeek.abs() < flatKgPerWeek) {
        state = ForecastTargetState.flat;
      } else if ((gap > 0) != (slopePerWeek > 0)) {
        state = ForecastTargetState.wrongWay;
      } else {
        state = ForecastTargetState.onTrack;
        weeksToTarget = gap / slopePerWeek;
      }
    }

    return WeightForecast(
      currentKg: current,
      slopeKgPerWeek: slopePerWeek,
      horizonWeeks: horizonWeeks,
      projectedKg: projected,
      sampleCount: n,
      spanDays: spanDays.round(),
      targetKg: targetKg,
      targetState: state,
      weeksToTarget: weeksToTarget,
    );
  }
}
