import 'package:shared_preferences/shared_preferences.dart';

import '../models/nutrition.dart';
import 'notification_service.dart';

/// Các loại nhắc nhở hằng ngày: bốn bữa ăn và uống nước.
enum ReminderKind {
  breakfast(
    id: 1001,
    label: 'Bữa sáng',
    defaultHour: 7,
    defaultMinute: 0,
    title: 'Đến giờ ăn sáng rồi!',
    body: 'Ăn sáng đủ chất rồi nhớ ghi lại vào HealthFlow nhé.',
  ),
  lunch(
    id: 1002,
    label: 'Bữa trưa',
    defaultHour: 11,
    defaultMinute: 30,
    title: 'Đến giờ ăn trưa rồi!',
    body: 'Đừng bỏ bữa trưa, ăn xong nhớ ghi lại món đã ăn.',
  ),
  dinner(
    id: 1003,
    label: 'Bữa tối',
    defaultHour: 18,
    defaultMinute: 30,
    title: 'Đến giờ ăn tối rồi!',
    body: 'Bữa tối nhẹ nhàng giúp bạn ngủ ngon hơn. Ghi lại bữa ăn nhé.',
  ),
  snack(
    id: 1004,
    label: 'Bữa phụ',
    defaultHour: 15,
    defaultMinute: 30,
    title: 'Giờ ăn nhẹ',
    body: 'Một bữa phụ lành mạnh sẽ giúp bạn đủ năng lượng đến tối.',
  ),
  water(
    id: 1005,
    label: 'Uống nước',
    defaultHour: 10,
    defaultMinute: 0,
    title: 'Uống nước thôi!',
    body: 'Đừng quên uống nước để giữ cơ thể đủ nước.',
  );

  const ReminderKind({
    required this.id,
    required this.label,
    required this.defaultHour,
    required this.defaultMinute,
    required this.title,
    required this.body,
  });

  /// Id thông báo hệ thống (tránh trùng id 0 đang dùng cho thông báo chào).
  final int id;
  final String label;
  final int defaultHour;
  final int defaultMinute;
  final String title;
  final String body;

  static ReminderKind forSlot(MealSlot slot) {
    switch (slot) {
      case MealSlot.breakfast:
        return ReminderKind.breakfast;
      case MealSlot.lunch:
        return ReminderKind.lunch;
      case MealSlot.dinner:
        return ReminderKind.dinner;
      case MealSlot.snack:
        return ReminderKind.snack;
    }
  }
}

/// Cấu hình nhắc nhở của một loại: bật/tắt và giờ nhắc.
class ReminderConfig {
  const ReminderConfig({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  ReminderConfig copyWith({bool? enabled, int? hour, int? minute}) {
    return ReminderConfig(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Dạng lưu: `bật|giờ|phút`, ví dụ `1|7|0`.
  String encode() => '${enabled ? 1 : 0}|$hour|$minute';

  static ReminderConfig? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final hour = int.tryParse(parts[1]);
    final minute = int.tryParse(parts[2]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return ReminderConfig(enabled: parts[0] == '1', hour: hour, minute: minute);
  }
}

/// Lưu cấu hình nhắc nhở và đồng bộ với lịch thông báo của hệ thống.
///
/// Mỗi bữa (và nhắc uống nước) có một giờ riêng cùng công tắc bật/tắt. Mặc
/// định tất cả đều tắt cho tới khi người dùng tự bật.
class MealReminderService {
  MealReminderService._();

  static final MealReminderService instance = MealReminderService._();

  factory MealReminderService() => instance;

  static const _prefix = 'meal_reminder_';

  Future<ReminderConfig> _read(
    SharedPreferences prefs,
    ReminderKind kind,
  ) async {
    return ReminderConfig.decode(prefs.getString('$_prefix${kind.name}')) ??
        ReminderConfig(
          enabled: false,
          hour: kind.defaultHour,
          minute: kind.defaultMinute,
        );
  }

  Future<Map<ReminderKind, ReminderConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final kind in ReminderKind.values) kind: await _read(prefs, kind),
    };
  }

  /// Hỏi quyền thông báo (Android 13+/iOS). Trả về `true` nếu đã được cấp.
  Future<bool> ensurePermission() async {
    final service = NotificationService();
    await service.init();
    return service.requestPermission();
  }

  /// Lưu cấu hình của [kind] rồi đặt hoặc huỷ lịch tương ứng.
  Future<void> save(ReminderKind kind, ReminderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${kind.name}', config.encode());
    await _apply(kind, config);
  }

  /// Đặt lại toàn bộ lịch theo cấu hình đã lưu. Gọi khi mở app để lịch luôn
  /// khớp với múi giờ hiện tại của máy. Không hiện hộp xin quyền.
  Future<void> rescheduleAll() async {
    final configs = await load();
    if (!configs.values.any((c) => c.enabled)) return;
    for (final entry in configs.entries) {
      await _apply(entry.key, entry.value);
    }
  }

  Future<void> _apply(ReminderKind kind, ReminderConfig config) async {
    final service = NotificationService();
    if (!config.enabled) {
      await service.cancel(kind.id);
      return;
    }
    await service.scheduleDaily(
      id: kind.id,
      title: kind.title,
      body: kind.body,
      hour: config.hour,
      minute: config.minute,
    );
  }
}
