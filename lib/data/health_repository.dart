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
  Future<void> load(String userId) async {
    _isLoading = true;
    notifyListeners();

    await _store.seedIfEmpty(userId);
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

  Future<void> addMetric(HealthMetric metric) async {
    await _store.insert(metric);
    await load(metric.userId);
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
    return _metrics.take(limit).toList();
  }
}
