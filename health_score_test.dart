import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/utils/health_assessor.dart';
import 'package:healthcare/utils/health_score.dart';

final DateTime _now = DateTime(2026, 10, 10, 12);

DateTime _ago(int days, [int hours = 0]) =>
    _now.subtract(Duration(days: days)).add(Duration(hours: hours));

HealthMetric _rec(
  HealthMetricType type,
  double value,
  DateTime at, {
  double? second,
}) {
  return HealthMetric(
    id: '${type.storeName}_${at.microsecondsSinceEpoch}',
    userId: 'u1',
    type: type,
    value: value,
    valueSecondary: second,
    recordedAt: at,
  );
}

HealthScoreItem _item(HealthScore score, HealthScoreFactor factor) =>
    score.items.firstWhere((item) => item.factor == factor);

/// Sáu ngày có ghi nhận khác nhau: đủ để độ đều đặn đạt tối đa.
List<HealthMetric> _regularDays({double systolic = 115, double diastolic = 75}) {
  return [
    _rec(HealthMetricType.bloodPressure, systolic, _ago(1), second: diastolic),
    _rec(HealthMetricType.heartRate, 70, _ago(2)),
    _rec(HealthMetricType.bloodGlucose, 90, _ago(3)),
    _rec(HealthMetricType.sleep, 8, _ago(4)),
    _rec(HealthMetricType.weight, 55, _ago(5)),
    _rec(HealthMetricType.weight, 55, _ago(6)),
  ];
}

void main() {
  group('Chấm điểm', () {
    test('mọi chỉ số bình thường và đo đều thì được 100', () {
      final score = HealthScoreCalculator.calculate(
        _regularDays(),
        asOf: _now,
        bmi: 21.0,
      );
      expect(score.value, 100);
      expect(score.measuredCount, 5);
      expect(score.deductions, isEmpty);
      expect(score.band, HealthScoreBand.good);
    });

    test('một chỉ số ở mức cảnh báo mất 80% điểm của mục đó', () {
      final score = HealthScoreCalculator.calculate(
        _regularDays(systolic: 135, diastolic: 85),
        asOf: _now,
        bmi: 21.0,
      );
      final bp = _item(score, HealthScoreFactor.bloodPressure);
      expect(bp.level, HealthLevel.alert);
      expect(bp.maxPoints, 25);
      expect(bp.deduction, 20); // 25 x 0.8
      expect(score.value, 80);
      expect(score.band, HealthScoreBand.fair);
    });

    test('chỉ số ở mức lưu ý mất 40% điểm của mục đó', () {
      final metrics = [
        _rec(HealthMetricType.bloodPressure, 115, _ago(1), second: 75),
        _rec(HealthMetricType.heartRate, 110, _ago(2)), // nhanh: lưu ý
        _rec(HealthMetricType.bloodGlucose, 90, _ago(3)),
        _rec(HealthMetricType.sleep, 8, _ago(4)),
        _rec(HealthMetricType.weight, 55, _ago(5)),
        _rec(HealthMetricType.weight, 55, _ago(6)),
      ];
      final score = HealthScoreCalculator.calculate(
        metrics,
        asOf: _now,
        bmi: 23.5, // thừa cân: lưu ý
      );
      expect(_item(score, HealthScoreFactor.bmi).deduction, 8); // 20 x 0.4
      expect(_item(score, HealthScoreFactor.heartRate).deduction, 4); // 10 x 0.4
      expect(score.value, 88);
    });

    test('điểm bằng 100 trừ tổng các khoản bị trừ', () {
      final score = HealthScoreCalculator.calculate(
        _regularDays(systolic: 135, diastolic: 85),
        asOf: _now,
        bmi: 23.5,
      );
      final total = score.items.fold<int>(0, (sum, i) => sum + i.deduction);
      expect(score.value, 100 - total);
    });

    test('các khoản bị trừ xếp từ nhiều đến ít', () {
      final score = HealthScoreCalculator.calculate(
        _regularDays(systolic: 135, diastolic: 85),
        asOf: _now,
        bmi: 23.5,
      );
      final points = score.deductions.map((i) => i.deduction).toList();
      expect(points, [20, 8]);
      expect(score.deductions.first.factor, HealthScoreFactor.bloodPressure);
    });
  });

  group('Thiếu dữ liệu', () {
    test('dưới 3 chỉ số thì chưa chấm điểm', () {
      final metrics = [
        _rec(HealthMetricType.bloodPressure, 115, _ago(1), second: 75),
        _rec(HealthMetricType.sleep, 8, _ago(2)),
      ];
      final score = HealthScoreCalculator.calculate(metrics, asOf: _now);
      expect(score.value, isNull);
      expect(score.isReady, isFalse);
      expect(score.measuredCount, 2);
      expect(score.band, isNull);
      expect(score.deductions, isEmpty);
    });

    test('mục thiếu dữ liệu bị bỏ ra, điểm các mục còn lại chia lại cho đủ 100', () {
      // Không có BMI và đường huyết: chỉ còn huyết áp, nhịp tim, giấc ngủ.
      final metrics = [
        _rec(HealthMetricType.bloodPressure, 135, _ago(1), second: 85),
        _rec(HealthMetricType.heartRate, 70, _ago(2)),
        _rec(HealthMetricType.sleep, 8, _ago(3)),
        _rec(HealthMetricType.weight, 55, _ago(4)),
        _rec(HealthMetricType.weight, 55, _ago(5)),
        _rec(HealthMetricType.weight, 55, _ago(6)),
      ];
      final score = HealthScoreCalculator.calculate(metrics, asOf: _now);
      final bp = _item(score, HealthScoreFactor.bloodPressure);
      // Tổng tối đa của các mục được tính là 25+10+10+15 = 60, nhân 100/60.
      expect(bp.maxPoints, 42);
      expect(bp.deduction, 33);
      expect(_item(score, HealthScoreFactor.bmi).measured, isFalse);
      expect(_item(score, HealthScoreFactor.bmi).maxPoints, 0);
      expect(score.value, 67);
      expect(score.band, HealthScoreBand.needsWork);
    });

    test('bản ghi quá 30 ngày không được tính và được báo rõ', () {
      final metrics = [
        _rec(HealthMetricType.bloodPressure, 135, _ago(40), second: 85),
        _rec(HealthMetricType.heartRate, 70, _ago(2)),
        _rec(HealthMetricType.sleep, 8, _ago(3)),
        _rec(HealthMetricType.bloodGlucose, 90, _ago(1)),
        _rec(HealthMetricType.weight, 55, _ago(4)),
        _rec(HealthMetricType.weight, 55, _ago(5)),
        _rec(HealthMetricType.weight, 55, _ago(6)),
      ];
      final score = HealthScoreCalculator.calculate(metrics, asOf: _now);
      final bp = _item(score, HealthScoreFactor.bloodPressure);
      expect(bp.measured, isFalse);
      expect(bp.statusLabel, 'Đã quá 30 ngày chưa đo');
      expect(score.measuredCount, 3);
      expect(score.value, 100);
    });

    test('bản ghi sau thời điểm tính điểm bị bỏ qua', () {
      final metrics = [
        ..._regularDays(),
        _rec(HealthMetricType.bloodPressure, 150, _now.add(const Duration(days: 1)), second: 95),
      ];
      final score = HealthScoreCalculator.calculate(metrics, asOf: _now, bmi: 21.0);
      expect(_item(score, HealthScoreFactor.bloodPressure).level, HealthLevel.normal);
      expect(score.value, 100);
    });
  });

  group('Độ đều đặn đo', () {
    test('ghi nhận ít ngày thì bị trừ theo tỉ lệ so với mục tiêu 6 ngày', () {
      // 5 chỉ số nhưng chỉ rơi vào 2 ngày khác nhau.
      final metrics = [
        _rec(HealthMetricType.bloodPressure, 115, _ago(1), second: 75),
        _rec(HealthMetricType.heartRate, 70, _ago(1, 1)),
        _rec(HealthMetricType.bloodGlucose, 90, _ago(1, 2)),
        _rec(HealthMetricType.sleep, 8, _ago(2)),
      ];
      final score = HealthScoreCalculator.calculate(metrics, asOf: _now, bmi: 21.0);
      final reg = _item(score, HealthScoreFactor.regularity);
      expect(reg.statusLabel, '2/14 ngày có ghi nhận');
      expect(reg.level, HealthLevel.alert);
      expect(reg.deduction, 10); // 15 x (1 - 2/6)
      expect(score.value, 90);
    });

    test('BMI tự sinh không được tính là một lần đo của người dùng', () {
      final metrics = [
        ..._regularDays(),
        for (var d = 7; d <= 12; d++) _rec(HealthMetricType.bmi, 21, _ago(d)),
      ];
      final score = HealthScoreCalculator.calculate(metrics, asOf: _now, bmi: 21.0);
      expect(_item(score, HealthScoreFactor.regularity).statusLabel, '6/14 ngày có ghi nhận');
    });
  });

  group('Mức xếp loại', () {
    test('các mốc ranh giới', () {
      expect(HealthScoreBand.of(100), HealthScoreBand.good);
      expect(HealthScoreBand.of(85), HealthScoreBand.good);
      expect(HealthScoreBand.of(84), HealthScoreBand.fair);
      expect(HealthScoreBand.of(70), HealthScoreBand.fair);
      expect(HealthScoreBand.of(69), HealthScoreBand.needsWork);
      expect(HealthScoreBand.of(50), HealthScoreBand.needsWork);
      expect(HealthScoreBand.of(49), HealthScoreBand.attention);
      expect(HealthScoreBand.of(0), HealthScoreBand.attention);
    });
  });

  group('So với tuần trước', () {
    final metrics = [
      // Tuần trước: mọi thứ bình thường.
      _rec(HealthMetricType.bloodPressure, 110, _ago(10), second: 70),
      _rec(HealthMetricType.heartRate, 70, _ago(10, 1)),
      _rec(HealthMetricType.sleep, 8, _ago(10, 2)),
      _rec(HealthMetricType.bloodGlucose, 90, _ago(10, 3)),
      for (var d = 11; d <= 15; d++) _rec(HealthMetricType.weight, 55, _ago(d)),
      // Gần đây: huyết áp tăng.
      _rec(HealthMetricType.bloodPressure, 135, _ago(1), second: 85),
      _rec(HealthMetricType.heartRate, 70, _ago(2)),
      _rec(HealthMetricType.sleep, 8, _ago(3)),
      _rec(HealthMetricType.bloodGlucose, 90, _ago(4)),
      _rec(HealthMetricType.weight, 55, _ago(5)),
      _rec(HealthMetricType.weight, 55, _ago(6)),
    ];

    test('điểm tuần trước tính lại từ các bản ghi tại thời điểm đó', () {
      final lastWeek = HealthScoreCalculator.calculate(
        metrics,
        asOf: _now.subtract(const Duration(days: 7)),
      );
      expect(lastWeek.value, 100);
      expect(_item(lastWeek, HealthScoreFactor.bloodPressure).level, HealthLevel.normal);
    });

    test('hiệu số điểm hiện tại và tuần trước', () {
      final current = HealthScoreCalculator.calculate(metrics, asOf: _now);
      expect(current.value, 75);
      expect(
        HealthScoreCalculator.changeSince(metrics, current: current, asOf: _now),
        -25,
      );
    });

    test('chưa đủ dữ liệu tuần trước thì không có hiệu số', () {
      final recent = _regularDays();
      final current = HealthScoreCalculator.calculate(recent, asOf: _now, bmi: 21.0);
      expect(current.value, 100);
      expect(
        HealthScoreCalculator.changeSince(recent, current: current, asOf: _now),
        isNull,
      );
    });
  });
}