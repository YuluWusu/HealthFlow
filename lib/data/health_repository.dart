import 'package:flutter/foundation.dart';

import '../data/health_store.dart';
import '../models/health_metric.dart';
import '../utils/health_assessor.dart';

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
  ///
  /// Truyền [heightCm] để bù BMI cho những lần cân chưa có BMI đi kèm (dữ
  /// liệu cũ hoặc dữ liệu mẫu); BMI bù được tính theo chiều cao hiện tại.
  Future<void> load(String userId, {double? heightCm}) async {
    _isLoading = true;
    notifyListeners();

    await _store.seedIfEmpty(userId);
    if (heightCm != null && heightCm > 0) {
      await _backfillBmi(userId, heightCm);
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

  /// Thêm một chỉ số. Với cân nặng, truyền [heightCm] (chiều cao hiện tại của
  /// người dùng) để ứng dụng ghi kèm BMI của lần cân đó.
  Future<void> addMetric(HealthMetric metric, {double? heightCm}) async {
    await _store.insert(metric);
    await _writeBmiFor(metric, heightCm);
    await load(metric.userId);
  }

  /// Sửa một chỉ số. Sửa cân nặng thì BMI đi kèm được tính lại theo
  /// [heightCm] (giá trị cân nặng hoặc thời điểm đo có thể đã đổi).
  Future<void> updateMetric(HealthMetric metric, {double? heightCm}) async {
    await _store.update(metric);
    await _writeBmiFor(metric, heightCm);
    await load(metric.userId);
  }

  /// Xóa một bản ghi chỉ số, rồi nạp lại danh sách để giao diện cập nhật.
  /// Xóa lần cân thì BMI đi kèm cũng bị xóa.
  ///
  /// Nhận thêm [userId] (thay vì tự suy ra từ bản ghi) để load() luôn chạy
  /// đúng theo người dùng đang xem màn hình, phòng khi sau này cho phép
  /// xóa chỉ số không phải của chính mình (ví dụ vai trò quản trị).
  Future<void> deleteMetric(String id, String userId) async {
    await _store.delete(id);
    // Không có bản ghi BMI đi kèm thì lệnh xóa này không làm gì.
    await _store.delete(HealthMetric.bmiIdFor(id));
    await load(userId);
  }

  /// Ghi (hoặc ghi đè) bản ghi BMI đi kèm một lần cân. Không phải cân nặng
  /// thì không làm gì. Thiếu chiều cao thì chỉ xóa BMI cũ (nếu có), vì để lại
  /// BMI không còn khớp với cân nặng vừa sửa còn tệ hơn là không có.
  Future<void> _writeBmiFor(HealthMetric weight, double? heightCm) async {
    if (weight.type != HealthMetricType.weight) return;

    final bmiId = HealthMetric.bmiIdFor(weight.id);
    await _store.delete(bmiId);

    if (heightCm == null) return;
    final bmi = HealthAssessor.calculateBmi(weight.value, heightCm);
    if (bmi == null) return;

    await _store.insert(
      HealthMetric(
        id: bmiId,
        userId: weight.userId,
        type: HealthMetricType.bmi,
        value: bmi,
        recordedAt: weight.recordedAt,
      ),
    );
  }

  /// Bù BMI cho các lần cân chưa có BMI đi kèm. Chạy lại nhiều lần không
  /// tạo bản ghi trùng.
  Future<void> _backfillBmi(String userId, double heightCm) async {
    final all = await _store.byUser(userId);
    final existing = {
      for (final metric in all)
        if (metric.type == HealthMetricType.bmi) metric.id,
    };

    for (final metric in all) {
      if (metric.type != HealthMetricType.weight) continue;
      if (existing.contains(HealthMetric.bmiIdFor(metric.id))) continue;
      await _writeBmiFor(metric, heightCm);
    }
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

  /// Các lần ghi của một loại chỉ số trong [days] ngày gần nhất, cũ nhất xếp
  /// trước, dùng để vẽ biểu đồ xu hướng. [now] chỉ để test.
  List<HealthMetric> seriesOf(
    HealthMetricType type, {
    required int days,
    DateTime? now,
  }) {
    final start = (now ?? DateTime.now()).subtract(Duration(days: days));
    final result = _metrics
        .where(
          (metric) => metric.type == type && !metric.recordedAt.isBefore(start),
        )
        .toList();
    result.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return result;
  }

  /// Lịch sử ghi nhận gần đây, mới nhất xếp trước.
  List<HealthMetric> recentHistory({int limit = 3}) {
    return _metrics.where((m) => !m.type.isDerived).take(limit).toList();
  }
}
