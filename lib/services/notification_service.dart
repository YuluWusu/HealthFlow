import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    _setupTimezone();

    _initialized = true;
  }

  /// Chọn múi giờ cho `tz.local` dựa trên độ lệch giờ thật của thiết bị.
  ///
  /// Không cần thêm package đọc tên múi giờ: ta tìm trong cơ sở dữ liệu một
  /// múi giờ có cùng độ lệch UTC ở hiện tại và ở hai mốc cách nhau nửa năm
  /// (để khớp cả quy tắc giờ mùa hè). Ví dụ máy ở Việt Nam (UTC+7) sẽ khớp
  /// `Asia/Bangkok`/`Asia/Ho_Chi_Minh`.
  void _setupTimezone() {
    tzdata.initializeTimeZones();

    final now = DateTime.now();
    final probes = <DateTime>[
      now,
      now.add(const Duration(days: 182)),
      now.subtract(const Duration(days: 182)),
    ];
    final wanted = [for (final t in probes) t.timeZoneOffset];

    tz.Location? best;
    tz.Location? nowOnly;
    for (final location in tz.timeZoneDatabase.locations.values) {
      final offsets = [
        for (final t in probes)
          tz.TZDateTime.from(t, location).timeZoneOffset,
      ];
      if (offsets[0] != wanted[0]) continue;
      nowOnly ??= location;
      if (offsets[1] == wanted[1] && offsets[2] == wanted[2]) {
        best = location;
        break;
      }
    }
    tz.setLocalLocation(best ?? nowOnly ?? tz.UTC);
  }

  Future<bool> requestPermission() async {
    bool? granted = false;
    
    // Request Android 13+ permissions
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      granted = await androidPlugin.requestNotificationsPermission();
    }

    // Request iOS permissions
    final iosPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    
    return granted ?? false;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'healthflow_channel_id',
      'HealthFlow Notifications',
      channelDescription: 'Nhắc nhở sức khỏe từ HealthFlow',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  static const AndroidNotificationDetails _reminderAndroid =
      AndroidNotificationDetails(
    'healthflow_reminder_channel_id',
    'Nhắc nhở ăn uống',
    channelDescription: 'Nhắc giờ ăn và uống nước hằng ngày',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: _reminderAndroid,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Lên lịch một thông báo lặp lại **mỗi ngày** vào [hour]:[minute] (giờ địa
  /// phương của thiết bị). Gọi lại với cùng [id] sẽ ghi đè lịch cũ.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();

    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: next,
      notificationDetails: _reminderDetails,
      // Nhắc ăn không cần chính xác từng giây → không đòi quyền báo thức chính xác.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) async {
    await init();
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
