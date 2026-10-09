import '../models/health_metric.dart';

/// Lớp lưu trữ chỉ số sức khỏe.
///
/// Cùng một cách tiếp cận với [AccountStore]: hiện dùng bản trong bộ nhớ,
/// sau này thay bằng bản `sqflite` mà không đổi phần gọi.
abstract class HealthStore {
  /// Toàn bộ chỉ số của một người dùng, mới nhất xếp trước.
  Future<List<HealthMetric>> byUser(String userId);

  Future<void> insert(HealthMetric metric);
  Future<void> update(HealthMetric metric);
  Future<void> delete(String id);

  /// Tạo số liệu khởi tạo nếu người dùng chưa có chỉ số nào.
  ///
  /// Nhờ vậy trang chủ và trang Sức khỏe luôn có dữ liệu hiển thị ngay sau
  /// khi đăng nhập, kể cả với tài khoản mẫu.
  Future<void> seedIfEmpty(String userId);
}

class InMemoryHealthStore implements HealthStore {
  final List<HealthMetric> _metrics = [];

  @override
  Future<List<HealthMetric>> byUser(String userId) async {
    final result = _metrics.where((m) => m.userId == userId).toList();
    result.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return result;
  }

  @override
  Future<void> insert(HealthMetric metric) async {
    _metrics.add(metric);
  }

  @override
  Future<void> update(HealthMetric metric) async {
    final index = _metrics.indexWhere((m) => m.id == metric.id);
    if (index >= 0) {
      _metrics[index] = metric;
    }
  }

  @override
  Future<void> delete(String id) async {
    _metrics.removeWhere((m) => m.id == id);
  }

  @override
  Future<void> seedIfEmpty(String userId) async {
    final existing = await byUser(userId);
    if (existing.isNotEmpty) return;
    _metrics.addAll(seedFor(userId));
  }

  /// Số liệu khởi tạo cho một tài khoản mới.
  ///
  /// Người dùng vừa đăng ký chưa có dữ liệu, nhưng trang chủ và trang Sức
  /// khỏe cần số liệu để hiển thị đúng như bản thiết kế. Bộ số liệu này
  /// đóng vai trò dữ liệu mẫu ban đầu và sẽ bị thay bằng số liệu thật ngay
  /// khi người dùng tự thêm chỉ số.
  static List<HealthMetric> seedFor(String userId) {
    final now = DateTime.now();
    HealthMetric metric(
      HealthMetricType type,
      double value,
      int daysAgo, {
      double? secondary,
    }) {
      return HealthMetric(
        id: 'seed-${type.storeName}-$daysAgo',
        userId: userId,
        type: type,
        value: value,
        valueSecondary: secondary,
        recordedAt: now.subtract(Duration(days: daysAgo)),
      );
    }

    return [
      metric(HealthMetricType.weight, 56.5, 0),
      metric(HealthMetricType.weight, 56.8, 7),
      metric(HealthMetricType.bloodPressure, 120, 0, secondary: 80),
      metric(HealthMetricType.heartRate, 72, 0),
      metric(HealthMetricType.bloodGlucose, 95, 0),
      metric(HealthMetricType.sleep, 7.5, 0),
      metric(HealthMetricType.steps, 5230, 0),
    ];
  }
}
