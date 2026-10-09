import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/utils/health_assessor.dart';

void main() {
  group('BMI chuẩn Châu Á', () {
    test('các mốc ranh giới', () {
      expect(HealthAssessor.bmi(18.4).label, 'Thiếu cân');
      expect(HealthAssessor.bmi(18.5).label, 'Bình thường');
      expect(HealthAssessor.bmi(22.9).label, 'Bình thường');
      expect(HealthAssessor.bmi(23.0).label, 'Thừa cân');
      expect(HealthAssessor.bmi(24.9).label, 'Thừa cân');
      expect(HealthAssessor.bmi(25.0).label, 'Béo phì');
    });

    test('phân loại theo số đã làm tròn 1 chữ số, khớp với số hiển thị', () {
      // 22.95 hiển thị là "23.0" nên phải là Thừa cân, không phải Bình thường.
      expect(HealthAssessor.bmi(22.95).label, 'Thừa cân');
      expect(HealthAssessor.bmi(22.94).label, 'Bình thường');
      expect(HealthAssessor.bmi(24.97).label, 'Béo phì'); // hiển thị "25.0"
      expect(HealthAssessor.bmi(24.94).label, 'Thừa cân');
      expect(HealthAssessor.bmi(18.46).label, 'Bình thường'); // hiển thị "18.5"
      expect(HealthAssessor.bmi(18.44).label, 'Thiếu cân');
    });

    test('BMI 0 hoặc âm là chưa có dữ liệu', () {
      expect(HealthAssessor.bmi(0), HealthStatus.noData);
      expect(HealthAssessor.bmi(-1), HealthStatus.noData);
    });
  });

  group('Huyết áp AHA/AMA', () {
    test('bình thường', () {
      expect(HealthAssessor.bloodPressure(119, 79).label, 'Bình thường');
    });

    test('tiền tăng huyết áp: tâm thu 120–129 và tâm trương < 80', () {
      expect(HealthAssessor.bloodPressure(120, 79).label, 'Tiền tăng huyết áp');
      expect(HealthAssessor.bloodPressure(129, 79).label, 'Tiền tăng huyết áp');
    });

    test('độ 1: một trong hai chỉ số chạm ngưỡng', () {
      expect(HealthAssessor.bloodPressure(130, 70).label, 'Tăng huyết áp độ 1');
      expect(HealthAssessor.bloodPressure(110, 80).label, 'Tăng huyết áp độ 1');
      expect(HealthAssessor.bloodPressure(139, 89).label, 'Tăng huyết áp độ 1');
    });

    test('độ 2 được xét trước độ 1', () {
      expect(HealthAssessor.bloodPressure(140, 70).label, 'Tăng huyết áp độ 2');
      expect(HealthAssessor.bloodPressure(125, 90).label, 'Tăng huyết áp độ 2');
      expect(HealthAssessor.bloodPressure(180, 120).label, 'Tăng huyết áp độ 2');
    });

    test('thiếu dữ liệu thì không đánh giá', () {
      expect(HealthAssessor.bloodPressure(0, 80), HealthStatus.noData);
    });
  });

  group('Nhịp tim, đường huyết, giấc ngủ', () {
    test('nhịp tim', () {
      expect(HealthAssessor.heartRate(59).label, 'Chậm');
      expect(HealthAssessor.heartRate(60).label, 'Bình thường');
      expect(HealthAssessor.heartRate(100).label, 'Bình thường');
      expect(HealthAssessor.heartRate(101).label, 'Nhanh');
    });

    test('đường huyết lúc đói', () {
      expect(HealthAssessor.bloodGlucose(69).label, 'Thấp');
      expect(HealthAssessor.bloodGlucose(70).label, 'Bình thường');
      expect(HealthAssessor.bloodGlucose(99).label, 'Bình thường');
      expect(HealthAssessor.bloodGlucose(100).label, 'Hơi cao');
      expect(HealthAssessor.bloodGlucose(125).label, 'Hơi cao');
      expect(HealthAssessor.bloodGlucose(126).label, 'Cao');
    });

    test('giấc ngủ', () {
      expect(HealthAssessor.sleep(5.5).label, 'Thiếu ngủ');
      expect(HealthAssessor.sleep(6.5).label, 'Hơi thiếu');
      expect(HealthAssessor.sleep(7).label, 'Tốt');
      expect(HealthAssessor.sleep(9).label, 'Tốt');
      expect(HealthAssessor.sleep(10).label, 'Ngủ nhiều');
    });
  });

  group('assess() theo bản ghi', () {
    HealthMetric metric(HealthMetricType type, double v, {double? v2}) {
      return HealthMetric(
        id: 'x',
        userId: 'u1',
        type: type,
        value: v,
        valueSecondary: v2,
        recordedAt: DateTime(2026, 10, 1),
      );
    }

    test('huyết áp dùng cả hai giá trị', () {
      final status = HealthAssessor.assess(
        metric(HealthMetricType.bloodPressure, 150, v2: 95),
      );
      expect(status.label, 'Tăng huyết áp độ 2');
      expect(status.level, HealthLevel.alert);
    });

    test('huyết áp thiếu chỉ số dưới thì chưa đánh giá', () {
      final status =
          HealthAssessor.assess(metric(HealthMetricType.bloodPressure, 150));
      expect(status, HealthStatus.noData);
    });

    test('cân nặng không có ngưỡng riêng', () {
      expect(
        HealthAssessor.assess(metric(HealthMetricType.weight, 60)),
        HealthStatus.noData,
      );
    });
  });
}
