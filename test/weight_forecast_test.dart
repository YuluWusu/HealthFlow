import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/models/user.dart';
import 'package:healthcare/utils/weight_forecast.dart';
import 'package:healthcare/widgets/weight_forecast_card.dart';

final _now = DateTime(2026, 10, 10, 8);

HealthMetric _weight(double kg, int daysAgo, {String? id}) {
  return HealthMetric(
    id: id ?? 'w$daysAgo',
    userId: 'u1',
    type: HealthMetricType.weight,
    value: kg,
    recordedAt: _now.subtract(Duration(days: daysAgo)),
  );
}

void main() {
  group('Chưa đủ dữ liệu', () {
    test('không có lần cân nào -> null', () {
      expect(WeightForecast.compute([], asOf: _now), isNull);
    });

    test('chỉ 1 lần cân -> null', () {
      expect(WeightForecast.compute([_weight(60, 0)], asOf: _now), isNull);
    });

    test('hai lần cân cách dưới 5 ngày -> null', () {
      final result = WeightForecast.compute(
        [_weight(60, 3), _weight(59.5, 0)],
        asOf: _now,
      );
      expect(result, isNull);
    });

    test('lần cân cũ hơn 42 ngày bị bỏ qua -> không đủ dữ liệu', () {
      final result = WeightForecast.compute(
        [_weight(70, 60), _weight(60, 0)],
        asOf: _now,
      );
      expect(result, isNull);
    });

    test('chỉ số khác cân nặng không được tính', () {
      final bmi = HealthMetric(
        id: 'b1',
        userId: 'u1',
        type: HealthMetricType.bmi,
        value: 22,
        recordedAt: _now.subtract(const Duration(days: 10)),
      );
      final result = WeightForecast.compute(
        [bmi, _weight(60, 0)],
        asOf: _now,
      );
      expect(result, isNull);
    });
  });

  group('Tính tốc độ và dự báo', () {
    test('dữ liệu mẫu 56.8 -> 56.5 trong 7 ngày: -0.3 kg/tuần, 6 tuần còn 54.7',
        () {
      final f = WeightForecast.compute(
        [_weight(56.5, 0), _weight(56.8, 7)], // thứ tự bất kỳ
        asOf: _now,
      )!;
      expect(f.slopeKgPerWeek, closeTo(-0.3, 1e-9));
      expect(f.currentKg, 56.5);
      expect(f.projectedKg, closeTo(54.7, 1e-9));
      expect(f.changeKg, closeTo(-1.8, 1e-9));
      expect(f.horizonWeeks, 6);
      expect(f.targetState, ForecastTargetState.none);
    });

    test('giảm đều 0.5 kg/tuần qua 4 lần cân', () {
      final f = WeightForecast.compute(
        [_weight(60, 21), _weight(59.5, 14), _weight(59, 7), _weight(58.5, 0)],
        asOf: _now,
      )!;
      expect(f.slopeKgPerWeek, closeTo(-0.5, 1e-9));
      expect(f.projectedKg, closeTo(55.5, 1e-9));
      expect(f.sampleCount, 4);
      expect(f.spanDays, 21);
      expect(f.isLowConfidence, isFalse);
    });

    test('một lần cân lệch ít làm méo kết quả hơn so hai điểm đầu-cuối', () {
      final f = WeightForecast.compute(
        [_weight(60, 21), _weight(59.2, 14), _weight(59.4, 7), _weight(58.4, 0)],
        asOf: _now,
      )!;
      expect(f.slopeKgPerWeek, closeTo(-0.46, 1e-9));
      expect(f.projectedKg, closeTo(55.64, 1e-9));
    });

    test('đang tăng 0.5 kg/tuần -> dự báo tăng', () {
      final f = WeightForecast.compute(
        [_weight(70, 14), _weight(70.5, 7), _weight(71, 0)],
        asOf: _now,
      )!;
      expect(f.slopeKgPerWeek, closeTo(0.5, 1e-9));
      expect(f.projectedKg, closeTo(74.0, 1e-9));
    });

    test('lần cân trong tương lai so với asOf bị bỏ qua', () {
      final future = HealthMetric(
        id: 'future',
        userId: 'u1',
        type: HealthMetricType.weight,
        value: 99,
        recordedAt: _now.add(const Duration(days: 2)),
      );
      final f = WeightForecast.compute(
        [future, _weight(56.8, 7), _weight(56.5, 0)],
        asOf: _now,
      )!;
      expect(f.currentKg, 56.5);
    });

    test('ít dữ liệu: 2 lần cân -> isLowConfidence', () {
      final f = WeightForecast.compute(
        [_weight(56.8, 7), _weight(56.5, 0)],
        asOf: _now,
      )!;
      expect(f.isLowConfidence, isTrue);
    });
  });

  group('Cảnh báo tốc độ', () {
    test('giảm 1.5 kg/tuần -> isFastLoss', () {
      final f = WeightForecast.compute(
        [_weight(75, 14), _weight(73.5, 7), _weight(72, 0)],
        asOf: _now,
      )!;
      expect(f.isFastLoss, isTrue);
      expect(f.isFastGain, isFalse);
    });

    test('kết quả vô lý (dưới 10 kg) -> null', () {
      final f = WeightForecast.compute(
        [_weight(14, 7), _weight(10.5, 0)],
        asOf: _now,
      );
      expect(f, isNull);
    });
  });

  group('So với cân nặng mong muốn', () {
    test('đang giảm đúng hướng: tính số tuần còn lại', () {
      final f = WeightForecast.compute(
        [_weight(60, 21), _weight(59.5, 14), _weight(59, 7), _weight(58.5, 0)],
        asOf: _now,
        targetKg: 55,
      )!;
      expect(f.targetState, ForecastTargetState.onTrack);
      expect(f.weeksToTarget, closeTo(7.0, 1e-9));
      // 7 tuần > 6 tuần dự báo -> chưa chạm trong khoảng dự báo.
      expect(f.reachesTargetWithinHorizon, isFalse);
    });

    test('chạm mục tiêu trong 6 tuần', () {
      final f = WeightForecast.compute(
        [_weight(60, 21), _weight(59.5, 14), _weight(59, 7), _weight(58.5, 0)],
        asOf: _now,
        targetKg: 56,
      )!;
      expect(f.weeksToTarget, closeTo(5.0, 1e-9));
      expect(f.reachesTargetWithinHorizon, isTrue);
    });

    test('muốn giảm nhưng đang tăng -> wrongWay', () {
      final f = WeightForecast.compute(
        [_weight(70, 14), _weight(70.5, 7), _weight(71, 0)],
        asOf: _now,
        targetKg: 65,
      )!;
      expect(f.targetState, ForecastTargetState.wrongWay);
      expect(f.weeksToTarget, isNull);
    });

    test('muốn tăng và đang tăng -> onTrack', () {
      final f = WeightForecast.compute(
        [_weight(70, 14), _weight(70.5, 7), _weight(71, 0)],
        asOf: _now,
        targetKg: 73,
      )!;
      expect(f.targetState, ForecastTargetState.onTrack);
      expect(f.weeksToTarget, closeTo(4.0, 1e-9));
    });

    test('đã gần mức mong muốn (<= 0.3 kg) -> reached', () {
      final f = WeightForecast.compute(
        [_weight(56.8, 7), _weight(56.5, 0)],
        asOf: _now,
        targetKg: 56.3,
      )!;
      expect(f.targetState, ForecastTargetState.reached);
    });

    test('cân nặng đứng yên -> flat, không chia cho 0', () {
      final f = WeightForecast.compute(
        [_weight(65, 14), _weight(65.02, 7), _weight(65, 0)],
        asOf: _now,
        targetKg: 60,
      )!;
      expect(f.targetState, ForecastTargetState.flat);
      expect(f.weeksToTarget, isNull);
    });
  });

  group('Văn bản hiển thị', () {
    test('weeksText', () {
      expect(WeightForecastCard.weeksText(0.4), 'chưa đầy 1 tuần');
      expect(WeightForecastCard.weeksText(3.2), '~3 tuần');
      expect(WeightForecastCard.weeksText(80), 'hơn 1 năm');
    });
  });

  group('User.targetWeightKg', () {
    final base = User(
      id: 'u',
      fullName: 'Test',
      email: 't@gmail.com',
      passwordHash: 'x',
      createdAt: DateTime(2026),
    );

    test('mặc định là null và giữ nguyên khi copyWith không truyền', () {
      expect(base.targetWeightKg, isNull);
      final withTarget = base.copyWith(targetWeightKg: 52);
      expect(withTarget.targetWeightKg, 52);
      expect(withTarget.copyWith(fullName: 'Khác').targetWeightKg, 52);
    });

    test('clearTargetWeight xóa mục tiêu', () {
      final cleared =
          base.copyWith(targetWeightKg: 52).copyWith(clearTargetWeight: true);
      expect(cleared.targetWeightKg, isNull);
    });

    test('toMap/fromMap giữ nguyên, bản ghi cũ không có khóa vẫn đọc được', () {
      final restored =
          User.fromMap(base.copyWith(targetWeightKg: 52.5).toMap());
      expect(restored.targetWeightKg, 52.5);

      final legacy = base.toMap()..remove('target_weight_kg');
      expect(User.fromMap(legacy).targetWeightKg, isNull);
    });
  });
}
