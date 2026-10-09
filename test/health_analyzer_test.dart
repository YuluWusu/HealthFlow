import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/utils/health_analyzer.dart';

final _now = DateTime(2026, 10, 8, 8);

HealthMetric _metric(
  String id,
  HealthMetricType type,
  double value, {
  double? secondary,
  int daysAgo = 0,
}) {
  return HealthMetric(
    id: id,
    userId: 'u1',
    type: type,
    value: value,
    valueSecondary: secondary,
    recordedAt: _now.subtract(Duration(days: daysAgo)),
  );
}

HealthMetric _weight(String id, double kg, {int daysAgo = 0}) =>
    _metric(id, HealthMetricType.weight, kg, daysAgo: daysAgo);

HealthMetric _glucose(String id, double v, {int daysAgo = 0}) =>
    _metric(id, HealthMetricType.bloodGlucose, v, daysAgo: daysAgo);

List<String> _titles(List<HealthInsight> list) =>
    [for (final i in list) i.title];

HealthInsight? _firstWhereTitle(List<HealthInsight> list, String part) {
  for (final i in list) {
    if (i.title.contains(part)) return i;
  }
  return null;
}

void main() {
  group('Không có dữ liệu', () {
    test('danh sách rỗng trả về thẻ "Chưa có dữ liệu"', () {
      final result = HealthAnalyzer.analyze([], 170);
      expect(result, hasLength(1));
      expect(result.single.title, 'Chưa có dữ liệu');
      expect(result.single.level, InsightLevel.normal);
    });
  });

  group('BMI khớp với HealthAssessor (không hở khoảng)', () {
    test('56.9kg / 158cm (BMI ~22.8) là Bình thường', () {
      final result = HealthAnalyzer.analyze([_weight('w1', 56.9)], 158);
      final insight = _firstWhereTitle(result, 'Thể trạng Lý tưởng');
      expect(insight, isNotNull);
      expect(insight!.level, InsightLevel.normal);
      expect(_firstWhereTitle(result, 'Béo phì'), isNull);
    });

    test('57.3kg / 158cm (BMI ~22.95, hiển thị 23.0) là Thừa cân, khớp số hiển thị',
        () {
      final result = HealthAnalyzer.analyze([_weight('w1', 57.3)], 158);
      final insight = _firstWhereTitle(result, 'Thừa cân');
      expect(insight, isNotNull);
      expect(insight!.title, contains('23.0'));
      expect(insight.level, InsightLevel.warning);
      expect(_firstWhereTitle(result, 'Béo phì'), isNull);
    });

    test('59.5kg / 155cm (BMI ~24.77) là Thừa cân, không phải Béo phì', () {
      final result = HealthAnalyzer.analyze([_weight('w1', 59.5)], 155);
      expect(_firstWhereTitle(result, 'Thừa cân'), isNotNull);
      expect(_firstWhereTitle(result, 'Béo phì'), isNull);
    });

    test('BMI từ 25 trở lên là Béo phì (mức nguy hiểm)', () {
      final result = HealthAnalyzer.analyze([_weight('w1', 75)], 165);
      final insight = _firstWhereTitle(result, 'Béo phì');
      expect(insight, isNotNull);
      expect(insight!.level, InsightLevel.danger);
    });

    test('BMI dưới 18.5 là Thiếu cân', () {
      final result = HealthAnalyzer.analyze([_weight('w1', 45)], 170);
      expect(_firstWhereTitle(result, 'Thiếu cân'), isNotNull);
    });
  });

  group('Chọn đúng BMI của lần cân mới nhất', () {
    test('không dùng BMI của lần cân cũ khi lần cân mới chưa có BMI', () {
      final result = HealthAnalyzer.analyze([
        _weight('w1', 90, daysAgo: 30),
        _metric(HealthMetric.bmiIdFor('w1'), HealthMetricType.bmi, 31.1,
            daysAgo: 30),
        _weight('w2', 60), // lần cân mới, chưa có BMI đi kèm
      ], 170);
      // 60kg / 170cm ~ 20.8 => Bình thường, không phải 31.1 (Béo phì).
      expect(_firstWhereTitle(result, 'Thể trạng Lý tưởng'), isNotNull);
      expect(_firstWhereTitle(result, 'Béo phì'), isNull);
    });

    test('dùng BMI đã lưu của đúng lần cân mới nhất', () {
      final result = HealthAnalyzer.analyze([
        _weight('w1', 60),
        _metric(HealthMetric.bmiIdFor('w1'), HealthMetricType.bmi, 27.0),
      ], 170);
      expect(_firstWhereTitle(result, 'Béo phì'), isNotNull);
    });
  });

  group('Thiếu chiều cao', () {
    test('không đoán chiều cao, nhắc cập nhật hồ sơ', () {
      final result = HealthAnalyzer.analyze([_weight('w1', 60)], null);
      expect(_firstWhereTitle(result, 'Chưa có chiều cao'), isNotNull);
      expect(_firstWhereTitle(result, 'BMI'), isNull);
    });

    test('chiều cao <= 0 cũng coi là thiếu', () {
      final result = HealthAnalyzer.analyze([_weight('w1', 60)], 0);
      expect(_firstWhereTitle(result, 'Chưa có chiều cao'), isNotNull);
    });

    test('đã có BMI lưu sẵn thì không cần chiều cao', () {
      final result = HealthAnalyzer.analyze([
        _weight('w1', 60),
        _metric(HealthMetric.bmiIdFor('w1'), HealthMetricType.bmi, 20.8),
      ], null);
      expect(_firstWhereTitle(result, 'Chưa có chiều cao'), isNull);
      expect(_firstWhereTitle(result, 'Thể trạng Lý tưởng'), isNotNull);
    });
  });

  group('Huyết áp khớp với thẻ trên màn hình', () {
    HealthMetric bp(double sys, double dia) => _metric(
        'bp', HealthMetricType.bloodPressure, sys,
        secondary: dia);

    test('135/85 là Tăng huyết áp độ 1, không phải "Tiền cao huyết áp"', () {
      final result = HealthAnalyzer.analyze([bp(135, 85)], 170);
      expect(_firstWhereTitle(result, 'độ 1'), isNotNull);
      expect(_firstWhereTitle(result, 'Tiền tăng huyết áp'), isNull);
      expect(_firstWhereTitle(result, 'độ 1')!.level, InsightLevel.danger);
    });

    test('150/95 là độ 2', () {
      final result = HealthAnalyzer.analyze([bp(150, 95)], 170);
      expect(_firstWhereTitle(result, 'độ 2'), isNotNull);
    });

    test('125/75 là tiền tăng huyết áp (mức cảnh báo vàng)', () {
      final result = HealthAnalyzer.analyze([bp(125, 75)], 170);
      final insight = _firstWhereTitle(result, 'Tiền tăng huyết áp');
      expect(insight, isNotNull);
      expect(insight!.level, InsightLevel.warning);
    });

    test('110/70 bình thường thì không có cảnh báo huyết áp', () {
      final result = HealthAnalyzer.analyze([bp(110, 70)], 170);
      expect(result, isEmpty);
    });

    test('thiếu tâm trương thì bỏ qua, không văng lỗi', () {
      final result = HealthAnalyzer.analyze([
        _metric('bp', HealthMetricType.bloodPressure, 150),
      ], 170);
      expect(result, isEmpty);
    });
  });

  group('Đường huyết', () {
    test('dưới 70 là THẤP, mức nguy hiểm', () {
      final result = HealthAnalyzer.analyze([_glucose('g1', 65)], 170);
      final insight = _firstWhereTitle(result, 'THẤP');
      expect(insight, isNotNull);
      expect(insight!.level, InsightLevel.danger);
    });

    test('70–99 bình thường, không có cảnh báo', () {
      final result = HealthAnalyzer.analyze([_glucose('g1', 90)], 170);
      expect(result, isEmpty);
    });

    test('100–125 là hơi cao (mức cảnh báo vàng)', () {
      final result = HealthAnalyzer.analyze([_glucose('g1', 110)], 170);
      final insight = _firstWhereTitle(result, 'hơi cao');
      expect(insight, isNotNull);
      expect(insight!.level, InsightLevel.warning);
    });

    test('từ 126 là Cao (mức nguy hiểm)', () {
      final result = HealthAnalyzer.analyze([_glucose('g1', 130)], 170);
      final insight = _firstWhereTitle(result, 'Cao');
      expect(insight, isNotNull);
      expect(insight!.level, InsightLevel.danger);
    });

    test('3 lần đo tăng liên tiếp (>= 10 mg/dL) báo "đang tăng dần"', () {
      final result = HealthAnalyzer.analyze([
        _glucose('g1', 85, daysAgo: 20),
        _glucose('g2', 92, daysAgo: 10),
        _glucose('g3', 98),
      ], 170);
      expect(_firstWhereTitle(result, 'đang tăng dần'), isNotNull);
    });

    test('tăng dưới 10 mg/dL tổng cộng thì không báo', () {
      final result = HealthAnalyzer.analyze([
        _glucose('g1', 90, daysAgo: 20),
        _glucose('g2', 96, daysAgo: 10),
        _glucose('g3', 99),
      ], 170);
      expect(_firstWhereTitle(result, 'đang tăng dần'), isNull);
    });

    test('lên xuống thất thường thì không báo tăng dần', () {
      final result = HealthAnalyzer.analyze([
        _glucose('g1', 85, daysAgo: 20),
        _glucose('g2', 98, daysAgo: 10),
        _glucose('g3', 92),
      ], 170);
      expect(_firstWhereTitle(result, 'đang tăng dần'), isNull);
    });

    test('chưa đủ 3 lần đo thì không báo', () {
      final result = HealthAnalyzer.analyze([
        _glucose('g1', 85, daysAgo: 10),
        _glucose('g2', 98),
      ], 170);
      expect(_firstWhereTitle(result, 'đang tăng dần'), isNull);
    });

    test('đã ở mức Cao thì chỉ báo Cao, không báo thêm tăng dần', () {
      final result = HealthAnalyzer.analyze([
        _glucose('g1', 110, daysAgo: 20),
        _glucose('g2', 120, daysAgo: 10),
        _glucose('g3', 130),
      ], 170);
      expect(_firstWhereTitle(result, 'đang tăng dần'), isNull);
      expect(_firstWhereTitle(result, 'Cao'), isNotNull);
    });
  });

  group('Xu hướng cân nặng theo thời gian thực', () {
    List<HealthMetric> weights(double newest, double older, int gapDays) =>
        [_weight('w2', newest), _weight('w1', older, daysAgo: gapDays)];

    test('chỉ 1 lần cân thì chưa kết luận', () {
      expect(HealthAnalyzer.weightTrend([_weight('w1', 60)]), isNull);
    });

    test('2 lần cân cách nhau 1 ngày thì chưa kết luận', () {
      expect(HealthAnalyzer.weightTrend(weights(61, 60, 1)), isNull);
    });

    test('lần cân trước cách quá 60 ngày thì chưa kết luận', () {
      expect(HealthAnalyzer.weightTrend(weights(63, 60, 70)), isNull);
    });

    test('+1.5kg trong 14 ngày (0.75 kg/tuần) là TĂNG NHANH', () {
      final trend = HealthAnalyzer.weightTrend(weights(61.5, 60, 14));
      expect(trend, isNotNull);
      expect(trend!.title, contains('TĂNG NHANH'));
      expect(trend.level, InsightLevel.warning);
    });

    test('-3kg trong 14 ngày (-1.5 kg/tuần) là GIẢM NHANH', () {
      final trend = HealthAnalyzer.weightTrend(weights(57, 60, 14));
      expect(trend!.title, contains('GIẢM NHANH'));
    });

    test('+0.1kg trong 14 ngày là ổn định', () {
      final trend = HealthAnalyzer.weightTrend(weights(60.1, 60, 14));
      expect(trend!.title, contains('ổn định'));
      expect(trend.level, InsightLevel.normal);
    });

    test('cùng mức tăng 2kg: cách 2 tuần thì nhanh, cách 8 tuần thì không', () {
      final fast = HealthAnalyzer.weightTrend(weights(62, 60, 14));
      final slow = HealthAnalyzer.weightTrend(weights(62, 60, 56));
      expect(fast!.title, contains('TĂNG NHANH'));
      expect(slow!.title, isNot(contains('TĂNG NHANH')));
    });

    test('analyze đưa thẻ xu hướng vào kết quả', () {
      final result = HealthAnalyzer.analyze(weights(61.5, 60, 14), 170);
      expect(_titles(result).any((t) => t.contains('TĂNG NHANH')), isTrue);
    });
  });
}
