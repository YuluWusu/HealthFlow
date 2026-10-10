import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/utils/measurement_schedule.dart';
import 'package:healthcare/widgets/measurement_due_card.dart';

final _now = DateTime(2026, 10, 10, 8);

HealthMetric _metric(HealthMetricType type, DateTime at, {String? id}) {
  return HealthMetric(
    id: id ?? '${type.storeName}-${at.microsecondsSinceEpoch}',
    userId: 'u1',
    type: type,
    value: 1,
    recordedAt: at,
  );
}

HealthMetric _daysAgo(HealthMetricType type, int days) =>
    _metric(type, _now.subtract(Duration(days: days)));

DueItem _of(List<DueItem> items, HealthMetricType type) =>
    items.firstWhere((i) => i.type == type);

void main() {
  group('Chu kỳ mặc định', () {
    test('cân 1 tuần/lần, huyết áp và đường huyết 1 tháng/lần', () {
      final byType = {
        for (final r in MeasurementSchedule.defaultRules) r.type: r.intervalDays
      };
      expect(byType, {
        HealthMetricType.weight: 7,
        HealthMetricType.bloodPressure: 30,
        HealthMetricType.bloodGlucose: 30,
      });
    });
  });

  group('Trạng thái đến hạn', () {
    test('huyết áp đo 28 ngày trước: còn 2 ngày tới hạn', () {
      final items = MeasurementSchedule.compute(
        [_daysAgo(HealthMetricType.bloodPressure, 28)],
        now: _now,
      );
      final bp = _of(items, HealthMetricType.bloodPressure);
      expect(bp.status, DueStatus.soon);
      expect(bp.daysUntilDue, 2);
      expect(bp.dueDate, DateTime(2026, 10, 12));
      expect(bp.message, 'Còn 2 ngày tới hạn đo huyết áp');
      expect(bp.needsAttention, isTrue);
    });

    test('cân đo đúng 7 ngày trước: hôm nay đến hạn', () {
      final items = MeasurementSchedule.compute(
        [_daysAgo(HealthMetricType.weight, 7)],
        now: _now,
      );
      final w = _of(items, HealthMetricType.weight);
      expect(w.status, DueStatus.dueToday);
      expect(w.daysUntilDue, 0);
      expect(w.message, 'Hôm nay đến hạn đo cân nặng');
    });

    test('cân đo 8 ngày trước: trễ 1 ngày', () {
      final items = MeasurementSchedule.compute(
        [_daysAgo(HealthMetricType.weight, 8)],
        now: _now,
      );
      final w = _of(items, HealthMetricType.weight);
      expect(w.status, DueStatus.overdue);
      expect(w.daysUntilDue, -1);
      expect(w.message, 'Trễ 1 ngày: đã đến hạn đo cân nặng');
    });

    test('cân đo 4 ngày trước: còn 3 ngày (vẫn nhắc), 3 ngày trước: còn 4 (chưa nhắc)',
        () {
      final soon = _of(
        MeasurementSchedule.compute(
            [_daysAgo(HealthMetricType.weight, 4)], now: _now),
        HealthMetricType.weight,
      );
      expect(soon.status, DueStatus.soon);
      expect(soon.daysUntilDue, 3);

      final later = _of(
        MeasurementSchedule.compute(
            [_daysAgo(HealthMetricType.weight, 3)], now: _now),
        HealthMetricType.weight,
      );
      expect(later.status, DueStatus.upcoming);
      expect(later.daysUntilDue, 4);
      expect(later.needsAttention, isFalse);
    });

    test('chưa từng đo: trạng thái never, nhắc đo lần đầu', () {
      final items = MeasurementSchedule.compute([], now: _now);
      expect(items, hasLength(3));
      for (final i in items) {
        expect(i.status, DueStatus.never);
        expect(i.lastMeasuredAt, isNull);
        expect(i.dueDate, DateTime(2026, 10, 10));
      }
      expect(
        _of(items, HealthMetricType.bloodGlucose).message,
        'Chưa có lần đo đường huyết nào, hãy đo lần đầu',
      );
    });
  });

  group('Tính theo ngày lịch', () {
    test('đo 23:59 cách 7 ngày, bây giờ 00:01 vẫn là hôm nay đến hạn', () {
      final items = MeasurementSchedule.compute(
        [_metric(HealthMetricType.weight, DateTime(2026, 10, 3, 23, 59))],
        now: DateTime(2026, 10, 10, 0, 1),
      );
      expect(_of(items, HealthMetricType.weight).status, DueStatus.dueToday);
    });

    test('cộng chu kỳ qua cuối tháng: 31/1 + 30 ngày = 2/3', () {
      final items = MeasurementSchedule.compute(
        [_metric(HealthMetricType.bloodPressure, DateTime(2026, 1, 31, 9))],
        now: DateTime(2026, 2, 1, 9),
      );
      final bp = _of(items, HealthMetricType.bloodPressure);
      expect(bp.dueDate, DateTime(2026, 3, 2));
      expect(bp.daysUntilDue, 29);
    });
  });

  group('Chọn lần đo gần nhất', () {
    test('nhiều lần đo: lấy lần mới nhất', () {
      final items = MeasurementSchedule.compute([
        _daysAgo(HealthMetricType.weight, 30),
        _daysAgo(HealthMetricType.weight, 2),
        _daysAgo(HealthMetricType.weight, 15),
      ], now: _now);
      final w = _of(items, HealthMetricType.weight);
      expect(w.daysUntilDue, 5);
      expect(w.lastMeasuredAt, _now.subtract(const Duration(days: 2)));
    });

    test('lần đo ghi trong tương lai bị bỏ qua', () {
      final items = MeasurementSchedule.compute([
        _daysAgo(HealthMetricType.weight, 8),
        _metric(HealthMetricType.weight, _now.add(const Duration(days: 3))),
      ], now: _now);
      expect(_of(items, HealthMetricType.weight).status, DueStatus.overdue);
    });

    test('chỉ số khác (nhịp tim, BMI) không ảnh hưởng', () {
      final items = MeasurementSchedule.compute([
        _daysAgo(HealthMetricType.heartRate, 0),
        _daysAgo(HealthMetricType.bmi, 0),
      ], now: _now);
      expect(items.every((i) => i.status == DueStatus.never), isTrue);
    });
  });

  group('Sắp xếp và lọc', () {
    test('gấp nhất xếp trước: never, rồi overdue, dueToday, soon, upcoming', () {
      final items = MeasurementSchedule.compute([
        _daysAgo(HealthMetricType.weight, 9), // trễ 2 ngày
        _daysAgo(HealthMetricType.bloodPressure, 28), // còn 2 ngày
        // đường huyết chưa đo
      ], now: _now);
      expect(
        [for (final i in items) i.type],
        [
          HealthMetricType.bloodGlucose,
          HealthMetricType.weight,
          HealthMetricType.bloodPressure,
        ],
      );
    });

    test('attention bỏ các mục còn lâu mới đến hạn', () {
      final items = MeasurementSchedule.compute([
        _daysAgo(HealthMetricType.weight, 1),
        _daysAgo(HealthMetricType.bloodPressure, 1),
        _daysAgo(HealthMetricType.bloodGlucose, 1),
      ], now: _now);
      expect(MeasurementSchedule.attention(items), isEmpty);
    });

    test('truyền quy tắc riêng', () {
      final items = MeasurementSchedule.compute(
        [_daysAgo(HealthMetricType.sleep, 2)],
        now: _now,
        rules: const [MeasurementRule(HealthMetricType.sleep, 3)],
      );
      expect(items, hasLength(1));
      expect(items.single.daysUntilDue, 1);
      expect(items.single.rule.intervalText, '3 ngày');
    });
  });

  group('Văn bản', () {
    test('subtitle nêu chu kỳ và lần đo gần nhất', () {
      final items = MeasurementSchedule.compute(
        [_metric(HealthMetricType.bloodPressure, DateTime(2026, 9, 12, 7))],
        now: _now,
      );
      expect(
        _of(items, HealthMetricType.bloodPressure).subtitle,
        'Chu kỳ 1 tháng/lần · gần nhất 12/9/2026',
      );
      expect(
        _of(MeasurementSchedule.compute([], now: _now), HealthMetricType.weight)
            .subtitle,
        'Chu kỳ 1 tuần/lần',
      );
    });
  });

  group('MeasurementDueCard', () {
    Widget host(List<DueItem> items, {String? title}) => MaterialApp(
          home: Scaffold(body: MeasurementDueCard(items: items, title: title)),
        );

    testWidgets('hiện câu nhắc và dòng phụ của từng mục', (tester) async {
      final items = MeasurementSchedule.compute(
        [_daysAgo(HealthMetricType.bloodPressure, 28)],
        now: _now,
      );
      await tester.pumpWidget(host(MeasurementSchedule.attention(items)));

      expect(find.text('Lịch đo đến hạn'), findsOneWidget);
      expect(find.text('Còn 2 ngày tới hạn đo huyết áp'), findsOneWidget);
      expect(find.textContaining('Chu kỳ 1 tháng/lần'), findsWidgets);
    });

    testWidgets('danh sách rỗng thì không hiện gì', (tester) async {
      await tester.pumpWidget(host(const []));
      expect(find.text('Lịch đo đến hạn'), findsNothing);
    });

    testWidgets('dùng tiêu đề tùy chọn', (tester) async {
      final items = MeasurementSchedule.compute([], now: _now);
      await tester.pumpWidget(host(items, title: 'Đến hạn đo trong ngày này'));
      expect(find.text('Đến hạn đo trong ngày này'), findsOneWidget);
    });
  });
}
