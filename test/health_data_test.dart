import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/data/health_repository.dart';
import 'package:healthcare/data/health_store.dart';
import 'package:healthcare/models/health_metric.dart';

void main() {
  group('Chỉ số sức khỏe', () {
    test('hiển thị giá trị kèm đơn vị, bỏ số 0 thừa', () {
      final metric = HealthMetric(
        id: 'm1',
        userId: 'u1',
        type: HealthMetricType.weight,
        value: 56.5,
        recordedAt: DateTime(2026),
      );
      expect(metric.displayValue, '56.5 kg');

      final heartRate = HealthMetric(
        id: 'm2',
        userId: 'u1',
        type: HealthMetricType.heartRate,
        value: 72,
        recordedAt: DateTime(2026),
      );
      expect(heartRate.displayValue, '72 bpm');
    });

    test('huyết áp hiển thị cả hai chỉ số', () {
      final metric = HealthMetric(
        id: 'm3',
        userId: 'u1',
        type: HealthMetricType.bloodPressure,
        value: 120,
        valueSecondary: 80,
        recordedAt: DateTime(2026),
      );

      expect(metric.displayValue, '120/80 mmHg');
    });

    test('lưu và đọc lại từ map giữ nguyên dữ liệu', () {
      final metric = HealthMetric(
        id: 'm4',
        userId: 'u1',
        type: HealthMetricType.bloodGlucose,
        value: 95,
        recordedAt: DateTime(2026, 9, 28, 7, 30),
        note: 'Đo lúc đói',
      );

      final restored = HealthMetric.fromMap(metric.toMap());

      expect(restored.id, metric.id);
      expect(restored.type, metric.type);
      expect(restored.value, metric.value);
      expect(restored.note, metric.note);
      expect(restored.recordedAt, metric.recordedAt);
    });
  });
  group('Sửa chỉ số sức khỏe', () {
    HealthMetric weightAt(String id, double value, DateTime time) {
      return HealthMetric(
        id: id,
        userId: 'u1',
        type: HealthMetricType.weight,
        value: value,
        recordedAt: time,
      );
    }

    test(
      'sửa giá trị thì đọc lại thấy giá trị mới, các trường khác giữ nguyên',
      () async {
        final health = HealthRepository(store: InMemoryHealthStore());
        final time = DateTime(2026, 10, 1, 8, 0);
        final metric = weightAt('m1', 56.5, time);
        await health.addMetric(metric);

        await health.updateMetric(metric.copyWith(value: 60));

        expect(health.metrics, hasLength(1));
        expect(health.metrics.first.value, 60);
        expect(health.metrics.first.id, 'm1');
        expect(health.metrics.first.type, HealthMetricType.weight);
        expect(health.metrics.first.recordedAt, time);
      },
    );

    test('sửa huyết áp thì cập nhật cả hai chỉ số', () async {
      final health = HealthRepository(store: InMemoryHealthStore());
      final bp = HealthMetric(
        id: 'bp1',
        userId: 'u1',
        type: HealthMetricType.bloodPressure,
        value: 120,
        valueSecondary: 80,
        recordedAt: DateTime(2026, 10, 1, 8, 0),
      );
      await health.addMetric(bp);

      await health.updateMetric(bp.copyWith(value: 130, valueSecondary: 85));

      expect(
        health.latestOf(HealthMetricType.bloodPressure)!.displayValue,
        '130/85 mmHg',
      );
    });

    test(
      'chỉ sửa đúng bản ghi được chọn, bản ghi khác và thứ tự giữ nguyên',
      () async {
        final health = HealthRepository(store: InMemoryHealthStore());
        final older = weightAt('m1', 56.8, DateTime(2026, 9, 24, 8, 0));
        final newer = weightAt('m2', 56.5, DateTime(2026, 10, 1, 8, 0));
        await health.addMetric(older);
        await health.addMetric(newer);

        await health.updateMetric(older.copyWith(value: 57.2));

        expect(health.metrics.map((m) => m.id), ['m2', 'm1']);
        expect(health.metrics[0].value, 56.5);
        expect(health.metrics[1].value, 57.2);
      },
    );

    test(
      'sửa bản ghi không tồn tại thì không báo lỗi và không thêm mới',
      () async {
        final health = HealthRepository(store: InMemoryHealthStore());
        final time = DateTime(2026, 10, 1, 8, 0);
        await health.addMetric(weightAt('m1', 56.5, time));

        await health.updateMetric(weightAt('khong-co', 99, time));

        expect(health.metrics, hasLength(1));
        expect(health.metrics.first.value, 56.5);
      },
    );
  });
}
