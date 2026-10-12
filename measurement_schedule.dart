import '../models/health_metric.dart';

/// Mức độ gấp của một lịch đo, xếp từ gấp nhất đến ít gấp nhất
/// (thứ tự khai báo được dùng để sắp xếp).
enum DueStatus {
  /// Chưa từng đo loại chỉ số này.
  never,

  /// Đã quá hạn.
  overdue,

  /// Hôm nay đến hạn.
  dueToday,

  /// Sắp đến hạn (trong [MeasurementSchedule.soonWithinDays] ngày tới).
  soon,

  /// Còn lâu mới đến hạn.
  upcoming,
}

/// Quy tắc: một loại chỉ số cần đo lại sau mỗi [intervalDays] ngày.
class MeasurementRule {
  const MeasurementRule(this.type, this.intervalDays);

  final HealthMetricType type;
  final int intervalDays;

  /// "1 tuần", "1 tháng", hoặc "N ngày" cho chu kỳ khác.
  String get intervalText {
    if (intervalDays == 7) return '1 tuần';
    if (intervalDays == 30) return '1 tháng';
    return '$intervalDays ngày';
  }
}

/// Trạng thái đến hạn của một loại chỉ số tại thời điểm tính.
class DueItem {
  const DueItem({
    required this.rule,
    required this.lastMeasuredAt,
    required this.dueDate,
    required this.daysUntilDue,
    required this.status,
  });

  final MeasurementRule rule;

  /// Lần đo gần nhất; `null` nếu chưa từng đo.
  final DateTime? lastMeasuredAt;

  /// Ngày đến hạn (chỉ có phần ngày, giờ = 0, giờ địa phương).
  final DateTime dueDate;

  /// Số ngày lịch còn lại đến hạn: dương = còn, 0 = hôm nay, âm = trễ.
  final int daysUntilDue;

  final DueStatus status;

  HealthMetricType get type => rule.type;

  /// Cần nhắc người dùng ngay (mọi trạng thái trừ [DueStatus.upcoming]).
  bool get needsAttention => status != DueStatus.upcoming;

  String get _what => 'đo ${rule.type.label.toLowerCase()}';

  /// Câu nhắc chính, ví dụ "Còn 2 ngày tới hạn đo huyết áp".
  String get message {
    switch (status) {
      case DueStatus.never:
        return 'Chưa có lần $_what nào, hãy đo lần đầu';
      case DueStatus.overdue:
        return 'Trễ ${-daysUntilDue} ngày: đã đến hạn $_what';
      case DueStatus.dueToday:
        return 'Hôm nay đến hạn $_what';
      case DueStatus.soon:
      case DueStatus.upcoming:
        return 'Còn $daysUntilDue ngày tới hạn $_what';
    }
  }

  /// Dòng phụ: chu kỳ và lần đo gần nhất.
  String get subtitle {
    final last = lastMeasuredAt;
    final cycle = 'Chu kỳ ${rule.intervalText}/lần';
    if (last == null) return cycle;
    return '$cycle · gần nhất ${last.day}/${last.month}/${last.year}';
  }
}

/// Tính các chỉ số nào đến hạn đo lại.
///
/// Mặc định: cân nặng 1 tuần/lần, huyết áp và đường huyết 1 tháng/lần. Các
/// chỉ số còn lại (nhịp tim, giấc ngủ, bước chân) được ghi hằng ngày nên không
/// đặt lịch. Muốn đổi chu kỳ chỉ cần sửa [defaultRules].
class MeasurementSchedule {
  const MeasurementSchedule._();

  static const List<MeasurementRule> defaultRules = [
    MeasurementRule(HealthMetricType.weight, 7),
    MeasurementRule(HealthMetricType.bloodPressure, 30),
    MeasurementRule(HealthMetricType.bloodGlucose, 30),
  ];

  /// Thẻ nhắc hiện khi còn tối đa chừng này ngày nữa là đến hạn.
  static const int soonWithinDays = 3;

  /// Tính trạng thái từng quy tắc, sắp xếp gấp nhất trước (rồi theo số ngày).
  static List<DueItem> compute(
    List<HealthMetric> metrics, {
    required DateTime now,
    List<MeasurementRule> rules = defaultRules,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final items = <DueItem>[];

    for (final rule in rules) {
      DateTime? last;
      for (final m in metrics) {
        if (m.type != rule.type || m.recordedAt.isAfter(now)) continue;
        if (last == null || m.recordedAt.isAfter(last)) last = m.recordedAt;
      }

      if (last == null) {
        items.add(DueItem(
          rule: rule,
          lastMeasuredAt: null,
          dueDate: today,
          daysUntilDue: 0,
          status: DueStatus.never,
        ));
        continue;
      }

      // Cộng ngày theo lịch (không cộng theo giờ) để không lệch khi đổi giờ.
      final dueDate = DateTime(last.year, last.month, last.day + rule.intervalDays);
      final daysUntil = _calendarDaysBetween(today, dueDate);
      final DueStatus status;
      if (daysUntil < 0) {
        status = DueStatus.overdue;
      } else if (daysUntil == 0) {
        status = DueStatus.dueToday;
      } else if (daysUntil <= soonWithinDays) {
        status = DueStatus.soon;
      } else {
        status = DueStatus.upcoming;
      }

      items.add(DueItem(
        rule: rule,
        lastMeasuredAt: last,
        dueDate: dueDate,
        daysUntilDue: daysUntil,
        status: status,
      ));
    }

    items.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      if (byStatus != 0) return byStatus;
      return a.daysUntilDue.compareTo(b.daysUntilDue);
    });
    return items;
  }

  /// Chỉ các mục cần nhắc ngay.
  static List<DueItem> attention(List<DueItem> items) =>
      [for (final i in items) if (i.needsAttention) i];

  /// Số ngày lịch từ [from] đến [to] (đều là ngày, bỏ qua giờ và đổi giờ).
  static int _calendarDaysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
