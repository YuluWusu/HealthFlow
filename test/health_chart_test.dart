import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/data/health_repository.dart';
import 'package:healthcare/data/health_store.dart';
import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/utils/health_assessor.dart';
import 'package:healthcare/utils/series_summary.dart';

void main() {
  group('HealthRepository.seriesOf', () {
    final now = DateTime(2026, 10, 6, 12, 0);

    HealthMetric metric(
      String id,
      HealthMetricType type,
      double value,
      int daysAgo,
    ) {
      return HealthMetric(
        id: id,
        userId: 'u1',
        type: type,
        value: value,
        recordedAt: now.subtract(Duration(days: daysAgo)),
      );
    }

    Future<HealthRepository> buildRepo() async {
      final repo = HealthRepository(store: InMemoryHealthStore());
      await repo.addMetric(metric('w1', HealthMetricType.weight, 66, 40));
      await repo.addMetric(metric('w2', HealthMetricType.weight, 65, 20));
      await repo.addMetric(metric('w3', HealthMetricType.weight, 64, 3));
      await repo.addMetric(metric('h1', HealthMetricType.heartRate, 72, 2));
      return repo;
    }

    test('chỉ lấy đúng loại và trong khoảng ngày, cũ nhất xếp trước', () async {
      final repo = await buildRepo();

      final week = repo.seriesOf(HealthMetricType.weight, days: 7, now: now);
      expect(week.map((m) => m.id), ['w3']);

      final month = repo.seriesOf(HealthMetricType.weight, days: 30, now: now);
      expect(month.map((m) => m.id), ['w2', 'w3']);

      final quarter = repo.seriesOf(HealthMetricType.weight, days: 90, now: now);
      expect(quarter.map((m) => m.id), ['w1', 'w2', 'w3']);
    });

    test('loại chưa có dữ liệu trả về danh sách rỗng', () async {
      final repo = await buildRepo();
      expect(
        repo.seriesOf(HealthMetricType.sleep, days: 90, now: now),
        isEmpty,
      );
    });
  });

  group('HealthAssessor.normalRange', () {
    test('cân nặng suy ra từ BMI 18.5–22.9 và chiều cao', () {
      final range = HealthAssessor.normalRange(
        HealthMetricType.weight,
        heightCm: 170,
      )!;
      expect(range.min, closeTo(53.465, 0.001));
      expect(range.max, closeTo(66.181, 0.001));
    });

    test('cân nặng thiếu chiều cao thì không có vùng', () {
      expect(HealthAssessor.normalRange(HealthMetricType.weight), isNull);
      expect(
        HealthAssessor.normalRange(HealthMetricType.weight, heightCm: 0),
        isNull,
      );
    });

    test('nhịp tim, đường huyết, giấc ngủ', () {
      final heart = HealthAssessor.normalRange(HealthMetricType.heartRate)!;
      expect([heart.min, heart.max], [60, 100]);
      final glucose = HealthAssessor.normalRange(HealthMetricType.bloodGlucose)!;
      expect([glucose.min, glucose.max], [70, 100]);
      final sleep = HealthAssessor.normalRange(HealthMetricType.sleep)!;
      expect([sleep.min, sleep.max], [7, 9]);
    });

    test('huyết áp và số bước không có vùng', () {
      expect(HealthAssessor.normalRange(HealthMetricType.bloodPressure), isNull);
      expect(HealthAssessor.normalRange(HealthMetricType.steps), isNull);
    });

    test('vạch ngưỡng huyết áp khớp với hàm đánh giá', () {
      expect(
        HealthAssessor.bloodPressure(
          HealthAssessor.systolicLimit - 1,
          HealthAssessor.diastolicLimit - 1,
        ).label,
        'Bình thường',
      );
      expect(
        HealthAssessor.bloodPressure(
          HealthAssessor.systolicLimit,
          HealthAssessor.diastolicLimit - 1,
        ).label,
        'Tiền tăng huyết áp',
      );
    });
  });

  group('SeriesSummary', () {
    test('dãy rỗng trả về null', () {
      expect(SeriesSummary.of(const []), isNull);
    });

    test('tính thấp nhất, trung bình, cao nhất', () {
      final summary = SeriesSummary.of(const [60, 62, 61, 65])!;
      expect(summary.min, 60);
      expect(summary.max, 65);
      expect(summary.average, 62);
      expect(summary.count, 4);
    });

    test('một giá trị', () {
      final summary = SeriesSummary.of(const [70])!;
      expect([summary.min, summary.average, summary.max], [70, 70, 70]);
    });
  });
}
