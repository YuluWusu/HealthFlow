import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/data/app_scope.dart';
import 'package:healthcare/data/auth_repository.dart';
import 'package:healthcare/data/auth_scope.dart';
import 'package:healthcare/data/health_repository.dart';
import 'package:healthcare/data/health_store.dart';
import 'package:healthcare/data/nutrition_repository.dart';
import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/screens/health_screen.dart';

/// Test tab "Lịch" của màn hình Sức khỏe.
///
/// `_CalendarTab` là class private nên test đi qua `HealthScreen`: dựng màn
/// hình với repository chạy trong bộ nhớ rồi bấm sang tab Lịch.
void main() {
  HealthMetric metric(
    String id,
    HealthMetricType type,
    double value, {
    required DateTime at,
  }) {
    return HealthMetric(
      id: id,
      userId: 'u1',
      type: type,
      value: value,
      recordedAt: at,
    );
  }

  /// Mở màn hình Sức khỏe, sang tab Lịch. Trả về repository để test thêm dữ liệu.
  Future<HealthRepository> openCalendar(
    WidgetTester tester, {
    required List<HealthMetric> metrics,
    double? heightCm,
  }) async {
    // Màn hình đủ cao để lưới lịch và danh sách bản ghi cùng được dựng.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final health = HealthRepository(store: InMemoryHealthStore());
    for (final m in metrics) {
      await health.addMetric(m, heightCm: heightCm);
    }
    final data = AppData(health: health, nutrition: NutritionRepository());
    final auth = AuthRepository();

    await tester.pumpWidget(
      AuthScope(
        repository: auth,
        child: AppScope(
          data: data,
          child: const MaterialApp(home: HealthScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lịch'));
    await tester.pumpAndSettle();
    return health;
  }

  String monthTitle(DateTime d) => 'Tháng ${d.month} ${d.year}';

  testWidgets('mở tab Lịch: hiện tháng hiện tại và bản ghi của hôm nay', (
    tester,
  ) async {
    final now = DateTime.now();
    await openCalendar(tester, metrics: [
      metric('h1', HealthMetricType.heartRate, 72, at: now),
    ]);

    expect(find.text(monthTitle(now)), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(
      find.text('Ghi nhận ngày ${now.day}/${now.month}/${now.year}'),
      findsOneWidget,
    );
    expect(find.text('72 bpm'), findsOneWidget);
  });

  testWidgets('BMI tự ghi kèm lần cân không hiện thành bản ghi riêng', (
    tester,
  ) async {
    final now = DateTime.now();
    await openCalendar(
      tester,
      heightCm: 170,
      metrics: [metric('w1', HealthMetricType.weight, 56.5, at: now)],
    );

    expect(find.text('56.5 kg'), findsOneWidget);
    // Đơn vị kg/m² chỉ có ở bản ghi BMI, nó phải bị ẩn khỏi danh sách ngày.
    expect(find.textContaining('kg/m²'), findsNothing);
  });

  testWidgets('chọn ngày không có dữ liệu thì hiện thông báo trống', (
    tester,
  ) async {
    final now = DateTime.now();
    await openCalendar(tester, metrics: [
      metric('h1', HealthMetricType.heartRate, 72, at: now),
    ]);

    // Ngày 15 (hoặc 16 nếu hôm nay là 15) tháng nào cũng có và khác hôm nay.
    final otherDay = now.day == 15 ? 16 : 15;
    await tester.tap(find.text('$otherDay'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ghi nhận ngày $otherDay/${now.month}/${now.year}'),
      findsOneWidget,
    );
    expect(
      find.text('Không có chỉ số sức khỏe nào được ghi nhận trong ngày này.'),
      findsOneWidget,
    );
    expect(find.text('72 bpm'), findsNothing);
    expect(find.text('Hôm nay'), findsNothing);
  });

  testWidgets('chuyển về tháng trước rồi chọn ngày có bản ghi', (tester) async {
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 15, 12);
    await openCalendar(tester, metrics: [
      metric('s1', HealthMetricType.sleep, 7.5, at: prevMonth),
    ]);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text(monthTitle(prevMonth)), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Ghi nhận ngày 15/${prevMonth.month}/${prevMonth.year}',
      ),
      findsOneWidget,
    );
    expect(find.text('7.5 giờ'), findsOneWidget);
  });

  testWidgets('bấm sang tháng sau rồi quay lại thì về đúng tháng hiện tại', (
    tester,
  ) async {
    final now = DateTime.now();
    await openCalendar(tester, metrics: [
      metric('h1', HealthMetricType.heartRate, 72, at: now),
    ]);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    final next = DateTime(now.year, now.month + 1, 1);
    expect(find.text(monthTitle(next)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text(monthTitle(now)), findsOneWidget);
  });

  testWidgets('thêm chỉ số mới thì tab Lịch cập nhật theo', (tester) async {
    final now = DateTime.now();
    final health = await openCalendar(tester, metrics: [
      metric('h1', HealthMetricType.heartRate, 72, at: now),
    ]);
    expect(find.text('5.0 giờ'), findsNothing);

    await tester.runAsync(() async {
      await health.addMetric(
        metric('s1', HealthMetricType.sleep, 5, at: now),
      );
    });
    await tester.pumpAndSettle();

    expect(find.text('5 giờ'), findsOneWidget);
  });
}
