import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/data/health_repository.dart';
import 'package:healthcare/data/health_store.dart';
import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/utils/health_assessor.dart';
import 'package:healthcare/utils/health_validator.dart';

void main() {
  const userId = 'u1';
  final time = DateTime(2026, 10, 1, 8, 0);

  HealthMetric weight(String id, double kg, {DateTime? at}) {
    return HealthMetric(
      id: id,
      userId: userId,
      type: HealthMetricType.weight,
      value: kg,
      recordedAt: at ?? time,
    );
  }

  late InMemoryHealthStore store;
  late HealthRepository repo;

  setUp(() {
    store = InMemoryHealthStore();
    repo = HealthRepository(store: store);
  });

  List<HealthMetric> bmis() =>
      repo.metrics.where((m) => m.type == HealthMetricType.bmi).toList();

  group('BMI tự ghi theo từng lần cân', () {
    test('thêm cân nặng kèm chiều cao thì có bản ghi BMI cùng thời điểm', () async {
      await repo.addMetric(weight('w1', 65), heightCm: 170);

      expect(bmis(), hasLength(1));
      final bmi = bmis().single;
      expect(bmi.id, HealthMetric.bmiIdFor('w1'));
      expect(bmi.value, closeTo(22.49, 0.01));
      expect(bmi.recordedAt, time);
      expect(bmi.userId, userId);
    });

    test('thêm cân nặng không có chiều cao thì không ghi BMI', () async {
      await repo.addMetric(weight('w1', 65));
      expect(bmis(), isEmpty);
    });

    test('chỉ cân nặng mới sinh BMI', () async {
      await repo.addMetric(
        HealthMetric(
          id: 'h1',
          userId: userId,
          type: HealthMetricType.heartRate,
          value: 72,
          recordedAt: time,
        ),
        heightCm: 170,
      );
      expect(bmis(), isEmpty);
    });

    test('sửa cân nặng thì BMI được tính lại, không bị nhân đôi', () async {
      await repo.addMetric(weight('w1', 65), heightCm: 170);
      await repo.updateMetric(weight('w1', 80), heightCm: 170);

      expect(bmis(), hasLength(1));
      expect(bmis().single.value, closeTo(27.68, 0.01));
    });

    test('sửa thời điểm cân thì BMI đi theo', () async {
      await repo.addMetric(weight('w1', 65), heightCm: 170);
      final later = DateTime(2026, 10, 3, 9, 30);
      await repo.updateMetric(weight('w1', 65, at: later), heightCm: 170);

      expect(bmis().single.recordedAt, later);
    });

    test('sửa cân nặng mà thiếu chiều cao thì xóa BMI cũ, không để lệch', () async {
      await repo.addMetric(weight('w1', 65), heightCm: 170);
      await repo.updateMetric(weight('w1', 80));

      expect(bmis(), isEmpty);
    });

    test('xóa lần cân thì BMI đi kèm cũng bị xóa', () async {
      await repo.addMetric(weight('w1', 65), heightCm: 170);
      await repo.addMetric(
        weight('w2', 66, at: time.add(const Duration(days: 1))),
        heightCm: 170,
      );

      await repo.deleteMetric('w1', userId);

      expect(
        repo.metrics.where((m) => m.type == HealthMetricType.weight).map((m) => m.id),
        ['w2'],
      );
      expect(bmis().map((m) => m.id), [HealthMetric.bmiIdFor('w2')]);
    });

    test('xóa chỉ số khác không ảnh hưởng BMI', () async {
      await repo.addMetric(weight('w1', 65), heightCm: 170);
      await repo.addMetric(
        HealthMetric(
          id: 'h1',
          userId: userId,
          type: HealthMetricType.heartRate,
          value: 72,
          recordedAt: time,
        ),
      );

      await repo.deleteMetric('h1', userId);
      expect(bmis(), hasLength(1));
    });
  });

  group('bù BMI cho dữ liệu cũ', () {
    test('load kèm chiều cao bù BMI cho lần cân chưa có', () async {
      await store.insert(weight('w1', 65));
      await store.insert(weight('w2', 66, at: time.add(const Duration(days: 1))));

      await repo.load(userId, heightCm: 170);

      expect(bmis(), hasLength(2));
    });

    test('load nhiều lần không tạo bản ghi trùng', () async {
      await store.insert(weight('w1', 65));

      await repo.load(userId, heightCm: 170);
      await repo.load(userId, heightCm: 170);

      expect(bmis(), hasLength(1));
    });

    test('load không có chiều cao thì không bù', () async {
      await store.insert(weight('w1', 65));
      await repo.load(userId);
      expect(bmis(), isEmpty);
    });

    test('tài khoản mới (dữ liệu mẫu) cũng có BMI cho mỗi lần cân', () async {
      await repo.load(userId, heightCm: 170);

      final weights =
          repo.metrics.where((m) => m.type == HealthMetricType.weight).length;
      expect(weights, greaterThan(0));
      expect(bmis(), hasLength(weights));
    });
  });

  group('BMI trong giao diện và biểu đồ', () {
    test('recentHistory không liệt kê BMI', () async {
      await repo.addMetric(weight('w1', 65), heightCm: 170);
      expect(
        repo.recentHistory(limit: 10).every((m) => !m.type.isDerived),
        isTrue,
      );
    });

    test('seriesOf trả về BMI theo thời gian', () async {
      await repo.addMetric(weight('w1', 65, at: time), heightCm: 170);
      await repo.addMetric(
        weight('w2', 70, at: time.add(const Duration(days: 2))),
        heightCm: 170,
      );

      final series = repo.seriesOf(
        HealthMetricType.bmi,
        days: 30,
        now: time.add(const Duration(days: 3)),
      );
      expect(series.map((m) => m.id), [
        HealthMetric.bmiIdFor('w1'),
        HealthMetric.bmiIdFor('w2'),
      ]);
      expect(series.first.value, lessThan(series.last.value));
    });

    test('form nhập tay không có BMI', () {
      expect(HealthMetricType.userEntered, isNot(contains(HealthMetricType.bmi)));
      expect(HealthMetricType.userEntered, contains(HealthMetricType.weight));
    });

    test('validator từ chối nhập tay BMI', () {
      expect(HealthValidator.validate(HealthMetricType.bmi, 22), isNotNull);
    });

    test('đánh giá và vùng bình thường của BMI', () {
      final metric = HealthMetric(
        id: 'b',
        userId: userId,
        type: HealthMetricType.bmi,
        value: 24,
        recordedAt: time,
      );
      expect(HealthAssessor.assess(metric).label, 'Thừa cân');

      final range = HealthAssessor.normalRange(HealthMetricType.bmi)!;
      expect([range.min, range.max], [18.5, 22.9]);
    });

    test('calculateBmi', () {
      expect(HealthAssessor.calculateBmi(65, 170)!, closeTo(22.49, 0.01));
      expect(HealthAssessor.calculateBmi(0, 170), isNull);
      expect(HealthAssessor.calculateBmi(65, 0), isNull);
    });
  });
}
