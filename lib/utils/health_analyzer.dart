import '../models/health_metric.dart';
import 'health_assessor.dart';

enum InsightLevel { normal, warning, danger }

class HealthInsight {
  final String title;
  final String message;
  final InsightLevel level;

  HealthInsight({
    required this.title,
    required this.message,
    required this.level,
  });
}

class HealthAnalyzer {
  /// Phân tích danh sách HealthMetric và trả về các Lời khuyên / Cảnh báo
  static List<HealthInsight> analyze(List<HealthMetric> metrics, double? heightCm) {
    List<HealthInsight> insights = [];

    if (metrics.isEmpty) {
      return [
        HealthInsight(
          title: 'Chưa có dữ liệu',
          message: 'Hãy nhập chỉ số sức khỏe đầu tiên để nhận phân tích chi tiết.',
          level: InsightLevel.normal,
        )
      ];
    }

    // -------------------------------------------------------------
    // 1. Phân tích Cân nặng & BMI
    // -------------------------------------------------------------
    // Lọc danh sách bản ghi cân nặng và BMI (sắp xếp giảm dần theo ngày)
    final weightMetrics = metrics
        .where((m) => m.type == HealthMetricType.weight)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    final bmiMetrics = metrics
        .where((m) => m.type == HealthMetricType.bmi)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (weightMetrics.isNotEmpty) {
      final latestWeight = weightMetrics.first;

      // Lấy đúng BMI của CHÍNH lần cân mới nhất (id suy ra từ id lần cân).
      // Không dùng "BMI mới nhất bất kỳ" vì có thể là BMI của lần cân cũ.
      double bmiValue = 0;
      final bmiId = HealthMetric.bmiIdFor(latestWeight.id);
      final matched = bmiMetrics.where((m) => m.id == bmiId);
      if (matched.isNotEmpty) {
        bmiValue = matched.first.value;
      } else if (heightCm != null && heightCm > 0) {
        bmiValue =
            HealthAssessor.calculateBmi(latestWeight.value, heightCm) ?? 0;
      } else {
        // Không có BMI đã lưu và cũng không biết chiều cao: không đoán chiều
        // cao, nhắc người dùng bổ sung thay vì tính BMI sai.
        insights.add(HealthInsight(
          title: 'Chưa có chiều cao',
          message:
              'Hãy cập nhật chiều cao trong hồ sơ để ứng dụng tính BMI và đưa ra lời khuyên về thể trạng.',
          level: InsightLevel.normal,
        ));
      }

      if (bmiValue > 0) {
        // Phân loại bằng HealthAssessor để khớp 100% với thẻ BMI trên màn hình,
        // tránh tự viết ngưỡng riêng (bản cũ hở khoảng 22.9–23.0 và 24.9–25.0).
        final status = HealthAssessor.bmi(bmiValue);
        final shown = bmiValue.toStringAsFixed(1);
        final level = _levelOf(status.level);
        switch (status.label) {
          case 'Thiếu cân':
            insights.add(HealthInsight(
              title: 'Cảnh báo Thiếu cân (BMI: $shown)',
              message:
                  'Thể trạng hiện tại hơi gầy. Bạn nên tăng khẩu phần ăn và bổ sung Calo/Protein.',
              level: level,
            ));
          case 'Bình thường':
            insights.add(HealthInsight(
              title: 'Thể trạng Lý tưởng (BMI: $shown)',
              message:
                  'Chỉ số cơ thể rất ổn định! Hãy tiếp tục duy trì chế độ ăn uống và vận động hiện tại.',
              level: level,
            ));
          case 'Thừa cân':
            insights.add(HealthInsight(
              title: 'Thừa cân (BMI: $shown)',
              message:
                  'Cân nặng đang hơi vượt chuẩn. Bạn nên giảm bớt Tinh bột/Chất béo trong bữa ăn.',
              level: level,
            ));
          case 'Béo phì':
            insights.add(HealthInsight(
              title: 'Cảnh báo Béo phì (BMI: $shown)',
              message:
                  'Chỉ số BMI cao! Hãy kiểm soát lượng Calo nạp vào và tăng cường tập luyện Cardio.',
              level: level,
            ));
        }
      }

      // Xu hướng cân nặng theo THỜI GIAN thực (xem weightTrend).
      final trend = weightTrend(weightMetrics);
      if (trend != null) insights.add(trend);
    }

    // -------------------------------------------------------------
    // 2. Phân tích Huyết áp
    // -------------------------------------------------------------
    final bpMetrics = metrics
        .where((m) => m.type == HealthMetricType.bloodPressure)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (bpMetrics.isNotEmpty) {
      final latestBP = bpMetrics.first;
      final dia = latestBP.valueSecondary;
      if (dia != null) {
        // Phân loại bằng HealthAssessor để khớp với thẻ Huyết áp trên màn hình.
        final status = HealthAssessor.bloodPressure(latestBP.value, dia);
        final shown = latestBP.displayValue;
        final level = _levelOf(status.level);
        switch (status.label) {
          case 'Tăng huyết áp độ 2':
            insights.add(HealthInsight(
              title: 'Cảnh báo Tăng huyết áp độ 2 ($shown)',
              message:
                  'Huyết áp ở mức cao! Hãy hạn chế ăn mặn, giảm căng thẳng, nghỉ ngơi hợp lý và nên đi khám sớm.',
              level: level,
            ));
          case 'Tăng huyết áp độ 1':
            insights.add(HealthInsight(
              title: 'Tăng huyết áp độ 1 ($shown)',
              message:
                  'Huyết áp đã vượt mức bình thường. Hãy giảm muối, vận động đều đặn và theo dõi thêm vài ngày liên tiếp.',
              level: level,
            ));
          case 'Tiền tăng huyết áp':
            insights.add(HealthInsight(
              title: 'Tiền tăng huyết áp ($shown)',
              message: 'Huyết áp hơi tăng nhẹ. Chú ý theo dõi thêm và uống đủ nước.',
              level: level,
            ));
        }
      }
    }

    // -------------------------------------------------------------
    // 3. Phân tích Đường huyết
    // -------------------------------------------------------------
    final glucoseMetrics = metrics
        .where((m) => m.type == HealthMetricType.bloodGlucose)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (glucoseMetrics.isNotEmpty) {
      final latestGlucose = glucoseMetrics.first;
      final status = HealthAssessor.bloodGlucose(latestGlucose.value);
      final shown = latestGlucose.displayValue;
      final level = _levelOf(status.level);
      switch (status.label) {
        case 'Thấp':
          insights.add(HealthInsight(
            title: 'Đường huyết THẤP ($shown)',
            message:
                'Đường huyết dưới 70 mg/dL. Hãy bổ sung ngay đồ ăn/uống chứa đường nhanh, đo lại sau 15 phút và đi khám nếu tái diễn.',
            level: level,
          ));
        case 'Hơi cao':
          insights.add(HealthInsight(
            title: 'Đường huyết hơi cao ($shown)',
            message:
                'Đường huyết nhỉnh hơn mức bình thường. Hãy hạn chế đồ ngọt và theo dõi thêm.',
            level: level,
          ));
        case 'Cao':
          insights.add(HealthInsight(
            title: 'Đường huyết Cao ($shown)',
            message:
                'Nồng độ đường trong máu cao. Hãy hạn chế đồ uống có đường, món ngọt và nên đi khám.',
            level: level,
          ));
      }

      // Xu hướng tăng dần: chỉ báo thêm khi chỉ số mới nhất CHƯA vượt ngưỡng
      // cao (đã báo ở trên), để cảnh báo sớm.
      if (status.label != 'Cao') {
        final rising = glucoseRising(glucoseMetrics);
        if (rising != null) insights.add(rising);
      }
    }

    return insights;
  }

  // ---- Xu hướng đường huyết ---------------------------------------------
  static const int _glucoseTrendWindowDays = 60;
  static const double _glucoseRiseMgDl = 10;

  /// Cảnh báo khi đường huyết ĐANG TĂNG DẦN: lấy tối đa 3 lần đo gần nhất
  /// trong 60 ngày, mỗi lần cao hơn lần trước và tổng mức tăng >= 10 mg/dL.
  /// [glucoseNewestFirst] đã xếp mới nhất trước. Trả về `null` nếu chưa đủ dữ
  /// liệu hoặc không có xu hướng tăng.
  static HealthInsight? glucoseRising(List<HealthMetric> glucoseNewestFirst) {
    if (glucoseNewestFirst.length < 3) return null;
    final latest = glucoseNewestFirst.first;
    final recent = glucoseNewestFirst
        .where((m) =>
            latest.recordedAt.difference(m.recordedAt).inHours / 24.0 <=
            _glucoseTrendWindowDays)
        .take(3)
        .toList();
    if (recent.length < 3) return null;

    // recent[0] mới nhất ... recent[2] cũ nhất
    final increasing =
        recent[0].value > recent[1].value && recent[1].value > recent[2].value;
    final rise = recent[0].value - recent[2].value;
    if (!increasing || rise < _glucoseRiseMgDl) return null;

    return HealthInsight(
      title: 'Đường huyết đang tăng dần (+${rise.toStringAsFixed(0)} mg/dL qua 3 lần đo)',
      message:
          'Đường huyết tăng liên tiếp qua các lần đo gần đây. Hãy hạn chế đồ ngọt, tăng vận động và đo lại đều đặn.',
      level: InsightLevel.warning,
    );
  }

  // ---- Xu hướng cân nặng -------------------------------------------------
  // Ngưỡng tham khảo (kg/tuần), không phải chỉ định y khoa:
  //  • tăng > 0,5 kg/tuần hoặc giảm > 1,0 kg/tuần được coi là nhanh.
  //  • |thay đổi| <= 0,25 kg/tuần được coi là ổn định.
  static const int _minTrendGapDays = 5;
  static const int _maxTrendGapDays = 60;
  static const double _fastGainPerWeek = 0.5;
  static const double _fastLossPerWeek = -1.0;
  static const double _stablePerWeek = 0.25;

  /// Đánh giá xu hướng cân nặng. [weightsNewestFirst] đã xếp mới nhất trước.
  ///
  /// So lần cân mới nhất với lần cân gần nhất cách nó từ 5 đến 60 ngày, rồi
  /// quy ra kg/tuần. Trả về `null` khi chưa đủ dữ liệu (chỉ 1 lần cân, các
  /// lần cân sát nhau, hoặc lần cân trước quá cũ) để không kết luận bừa.
  static HealthInsight? weightTrend(List<HealthMetric> weightsNewestFirst) {
    if (weightsNewestFirst.length < 2) return null;
    final latest = weightsNewestFirst.first;

    HealthMetric? reference;
    double days = 0;
    for (final m in weightsNewestFirst.skip(1)) {
      final gap = latest.recordedAt.difference(m.recordedAt).inHours / 24.0;
      if (gap > _maxTrendGapDays) break;
      if (gap >= _minTrendGapDays) {
        reference = m;
        days = gap;
        break;
      }
    }
    if (reference == null) return null;

    final diff = latest.value - reference.value;
    final perWeek = diff / days * 7;
    final sign = diff >= 0 ? '+' : '-';
    final span = '$sign${diff.abs().toStringAsFixed(1)} kg / ${days.round()} ngày';

    if (perWeek > _fastGainPerWeek) {
      return HealthInsight(
        title: 'Cân nặng TĂNG NHANH ($span)',
        message:
            'Cân nặng tăng nhanh hơn mức thường gặp. Hãy xem lại khẩu phần ăn, đồ ngọt và bữa ăn muộn.',
        level: InsightLevel.warning,
      );
    }
    if (perWeek < _fastLossPerWeek) {
      return HealthInsight(
        title: 'Cân nặng GIẢM NHANH ($span)',
        message:
            'Cân nặng giảm khá nhanh. Nếu bạn không chủ động giảm cân, hãy đảm bảo ăn đủ bữa và theo dõi sức khỏe.',
        level: InsightLevel.warning,
      );
    }
    if (perWeek.abs() <= _stablePerWeek) {
      return HealthInsight(
        title: 'Cân nặng duy trì ổn định ($span)',
        message: 'Mức biến động cân nặng của bạn rất nhỏ, hãy giữ nhịp sinh hoạt hiện tại.',
        level: InsightLevel.normal,
      );
    }
    return HealthInsight(
      title: perWeek > 0
          ? 'Cân nặng nhích tăng nhẹ ($span)'
          : 'Cân nặng đang giảm đều ($span)',
      message: perWeek > 0
          ? 'Cân nặng tăng nhẹ và vẫn trong tầm kiểm soát. Theo dõi thêm vài tuần.'
          : 'Tốc độ giảm cân đang ở mức an toàn, hãy duy trì.',
      level: InsightLevel.normal,
    );
  }

  /// Đổi mức độ của HealthAssessor sang mức của thẻ lời khuyên.
  static InsightLevel _levelOf(HealthLevel level) {
    switch (level) {
      case HealthLevel.alert:
        return InsightLevel.danger;
      case HealthLevel.caution:
        return InsightLevel.warning;
      case HealthLevel.normal:
      case HealthLevel.unknown:
        return InsightLevel.normal;
    }
  }
}
