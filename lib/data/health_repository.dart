import 'package:flutter/foundation.dart';

import '../data/health_store.dart';
import '../models/health_metric.dart';

/// Truy vấn và tổng hợp chỉ số sức khỏe cho giao diện.
///
/// Repository giữ sẵn danh sách chỉ số trong bộ nhớ đệm để giao diện đọc
/// đồng bộ, tránh phải dùng `FutureBuilder` ở mọi thẻ số liệu.
class HealthRepository extends ChangeNotifier {
  HealthRepository({HealthStore? store})
      : _store = store ?? InMemoryHealthStore();

  final HealthStore _store;

  List<HealthMetric> _metrics = const [];
  bool _isLoading = true;

  List<HealthMetric> get metrics => _metrics;
  bool get isLoading => _isLoading;

  /// Đọc lại toàn bộ chỉ số của người dùng đang đăng nhập.
  ///
  /// Nếu người dùng chưa có chỉ số nào (tài khoản mẫu hoặc tài khoản vừa
  /// tạo), bộ số liệu khởi tạo được thêm vào để giao diện có dữ liệu hiển thị.
  Future<void> load(String userId, {double? heightCm}) async {
    _isLoading = true;
    notifyListeners();

    await _store.seedIfEmpty(userId);
    
    if (heightCm != null && heightCm > 0) {
      final stored = await _store.byUser(userId);
      for (final m in stored.where((x) => x.type == HealthMetricType.weight)) {
        final bmiId = HealthMetric.bmiIdFor(m.id);
        if (!stored.any((x) => x.id == bmiId)) {
          await _store.insert(HealthMetric(
            id: bmiId,
            userId: m.userId,
            type: HealthMetricType.bmi,
            value: m.value / ((heightCm / 100) * (heightCm / 100)),
            recordedAt: m.recordedAt,
          ));
        }
      }
    }
    
    _metrics = await _store.byUser(userId);

    _isLoading = false;
    notifyListeners();
  }

  /// Xóa dữ liệu khi đăng xuất để tài khoản sau không thấy số liệu cũ.
  void clear() {
    _metrics = const [];
    _isLoading = true;
    notifyListeners();
  }

  Future<void> addMetric(HealthMetric metric, {double? heightCm}) async {
    await _store.insert(metric);
    if (metric.type == HealthMetricType.weight && heightCm != null && heightCm > 0) {
      final bmiValue = metric.value / ((heightCm / 100) * (heightCm / 100));
      await _store.insert(HealthMetric(
        id: HealthMetric.bmiIdFor(metric.id),
        userId: metric.userId,
        type: HealthMetricType.bmi,
        value: bmiValue,
        recordedAt: metric.recordedAt,
      ));
    }
    await load(metric.userId, heightCm: heightCm);
  }

  Future<void> updateMetric(HealthMetric metric, {double? heightCm}) async {
    await _store.update(metric);
    if (metric.type == HealthMetricType.weight) {
      final bmiId = HealthMetric.bmiIdFor(metric.id);
      if (heightCm != null && heightCm > 0) {
        final bmiValue = metric.value / ((heightCm / 100) * (heightCm / 100));
        final stored = await _store.byUser(metric.userId);
        final hasBmi = stored.any((x) => x.id == bmiId);
        final bmiMetric = HealthMetric(
          id: bmiId,
          userId: metric.userId,
          type: HealthMetricType.bmi,
          value: bmiValue,
          recordedAt: metric.recordedAt,
        );
        if (hasBmi) {
          await _store.update(bmiMetric);
        } else {
          await _store.insert(bmiMetric);
        }
      } else {
        await _store.delete(bmiId);
      }
    }
    await load(metric.userId, heightCm: heightCm);
  }

  Future<void> deleteMetric(String id, String userId) async {
    await _store.delete(id);
    await _store.delete(HealthMetric.bmiIdFor(id));
    await load(userId);
  }

  /// Chỉ số mới nhất của một loại, chưa có thì trả về `null`.
  HealthMetric? latestOf(HealthMetricType type) {
    for (final metric in _metrics) {
      if (metric.type == type) return metric;
    }
    return null;
  }

  /// Giá trị hiển thị của loại chỉ số, chưa có dữ liệu thì trả về `--`.
  String displayOf(HealthMetricType type) {
    return latestOf(type)?.displayValue ?? '--';
  }

  /// So sánh chỉ số mới nhất với lần ghi trước đó.
  MetricTrend trendOf(HealthMetricType type) {
    final sameType =
        _metrics.where((metric) => metric.type == type).toList(growable: false);
    if (sameType.length < 2) {
      return const MetricTrend(difference: 0, hasPrevious: false);
    }
    return MetricTrend(
      difference: sameType[0].value - sameType[1].value,
      hasPrevious: true,
    );
  }

  /// Chỉ số cân nặng trong 7 lần ghi gần nhất, cũ nhất xếp trước, dùng để vẽ
  /// biểu đồ đường trên màn hình Sức khỏe.
  List<HealthMetric> weightHistory({int limit = 7}) {
    final weights = _metrics
        .where((metric) => metric.type == HealthMetricType.weight)
        .take(limit)
        .toList();
    return weights.reversed.toList();
  }

  /// Lịch sử ghi nhận gần đây, mới nhất xếp trước.
  List<HealthMetric> recentHistory({int limit = 3}) {
    return _metrics.where((m) => !m.type.isDerived).take(limit).toList();
  }

  /// Lấy chuỗi dữ liệu theo thời gian của một chỉ số nhất định trong khoảng [days] ngày.
  List<HealthMetric> seriesOf(HealthMetricType type, {required int days, DateTime? now}) {
    final endDate = now ?? DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    final filtered = _metrics.where((m) =>
        m.type == type &&
        m.recordedAt.isAfter(startDate) &&
        (m.recordedAt.isBefore(endDate) || m.recordedAt.isAtSameMomentAs(endDate))).toList();
    return filtered.reversed.toList();
  }
}
