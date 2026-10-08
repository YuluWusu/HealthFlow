import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/utils/health_validator.dart';

void main() {
  group('parseNumber', () {
    test('chấp nhận dấu chấm, dấu phẩy và khoảng trắng', () {
      expect(HealthValidator.parseNumber('56.5'), 56.5);
      expect(HealthValidator.parseNumber(' 56,5 '), 56.5);
    });

    test('từ chối chữ, chuỗi rỗng, Infinity và NaN', () {
      expect(HealthValidator.parseNumber('abc'), isNull);
      expect(HealthValidator.parseNumber(''), isNull);
      expect(HealthValidator.parseNumber('Infinity'), isNull);
      expect(HealthValidator.parseNumber('NaN'), isNull);
    });
  });

  group('validate - giá trị đơn', () {
    test('thiếu giá trị', () {
      expect(
        HealthValidator.validate(HealthMetricType.weight, null),
        isNotNull,
      );
    });

    test('cân nặng 20–300 kg', () {
      expect(HealthValidator.validate(HealthMetricType.weight, 19.9), isNotNull);
      expect(HealthValidator.validate(HealthMetricType.weight, 20), isNull);
      expect(HealthValidator.validate(HealthMetricType.weight, 65.5), isNull);
      expect(HealthValidator.validate(HealthMetricType.weight, 300), isNull);
      expect(HealthValidator.validate(HealthMetricType.weight, 301), isNotNull);
      expect(HealthValidator.validate(HealthMetricType.weight, 0.1), isNotNull);
    });

    test('nhịp tim 30–220 và phải là số nguyên', () {
      expect(HealthValidator.validate(HealthMetricType.heartRate, 29), isNotNull);
      expect(HealthValidator.validate(HealthMetricType.heartRate, 72), isNull);
      expect(HealthValidator.validate(HealthMetricType.heartRate, 9999), isNotNull);
      expect(
        HealthValidator.validate(HealthMetricType.heartRate, 72.5),
        'Nhịp tim phải là số nguyên.',
      );
    });

    test('đường huyết 20–600 mg/dL', () {
      expect(HealthValidator.validate(HealthMetricType.bloodGlucose, 19), isNotNull);
      expect(HealthValidator.validate(HealthMetricType.bloodGlucose, 95.5), isNull);
      expect(HealthValidator.validate(HealthMetricType.bloodGlucose, 601), isNotNull);
    });

    test('giấc ngủ 0.5–24 giờ', () {
      expect(HealthValidator.validate(HealthMetricType.sleep, 0.4), isNotNull);
      expect(HealthValidator.validate(HealthMetricType.sleep, 7.5), isNull);
      expect(HealthValidator.validate(HealthMetricType.sleep, 25), isNotNull);
    });

    test('số bước là số nguyên từ 1', () {
      expect(HealthValidator.validate(HealthMetricType.steps, 0), isNotNull);
      expect(HealthValidator.validate(HealthMetricType.steps, 8000), isNull);
      expect(HealthValidator.validate(HealthMetricType.steps, 8000.5), isNotNull);
    });
  });

  group('validate - huyết áp', () {
    test('hợp lệ', () {
      expect(
        HealthValidator.validate(
          HealthMetricType.bloodPressure,
          120,
          secondary: 80,
        ),
        isNull,
      );
    });

    test('thiếu chỉ số dưới', () {
      expect(
        HealthValidator.validate(HealthMetricType.bloodPressure, 120),
        isNotNull,
      );
    });

    test('chỉ số trên phải lớn hơn chỉ số dưới', () {
      expect(
        HealthValidator.validate(
          HealthMetricType.bloodPressure,
          80,
          secondary: 120,
        ),
        'Huyết áp trên phải lớn hơn huyết áp dưới.',
      );
      expect(
        HealthValidator.validate(
          HealthMetricType.bloodPressure,
          90,
          secondary: 90,
        ),
        isNotNull,
      );
    });

    test('ngoài khoảng cho phép', () {
      expect(
        HealthValidator.validate(
          HealthMetricType.bloodPressure,
          300,
          secondary: 80,
        ),
        isNotNull,
      );
      expect(
        HealthValidator.validate(
          HealthMetricType.bloodPressure,
          120,
          secondary: 20,
        ),
        isNotNull,
      );
    });
  });

  group('thời điểm và ghi chú', () {
    final now = DateTime(2026, 10, 6, 9, 0);

    test('không cho ghi nhận ở tương lai', () {
      expect(
        HealthValidator.validateRecordedAt(DateTime(2026, 10, 6, 8, 0), now: now),
        isNull,
      );
      expect(
        HealthValidator.validateRecordedAt(DateTime(2026, 10, 6, 9, 0), now: now),
        isNull,
      );
      expect(
        HealthValidator.validateRecordedAt(DateTime(2026, 10, 7, 9, 0), now: now),
        isNotNull,
      );
    });

    test('ghi chú tối đa 200 ký tự', () {
      expect(HealthValidator.validateNote(''), isNull);
      expect(HealthValidator.validateNote('a' * 200), isNull);
      expect(HealthValidator.validateNote('a' * 201), isNotNull);
    });
  });
}
