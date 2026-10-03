import 'package:flutter/material.dart';

import 'health_repository.dart';
import 'nutrition_repository.dart';
import 'workout_repository.dart';

/// Nhóm các repository dữ liệu và phát thông báo khi bất kỳ repository nào
/// thay đổi.
///
/// Nhờ lớp này, giao diện chỉ cần lắng nghe một đối tượng duy nhất thay vì
/// tự gộp nhiều nguồn thông báo.
class AppData extends ChangeNotifier {
  AppData({
    HealthRepository? health,
    NutritionRepository? nutrition,
    WorkoutRepository? workout,
  })  : health = health ?? HealthRepository(),
        nutrition = nutrition ?? NutritionRepository(),
        workout = workout ?? WorkoutRepository();

  final HealthRepository health;
  final NutritionRepository nutrition;
  final WorkoutRepository workout;

  /// Danh sách các repository, dùng khi cần duyệt chung.
  List<ChangeNotifier> get repositories => [health, nutrition, workout];

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    for (final repository in repositories) {
      repository.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final repository in repositories) {
      repository.removeListener(listener);
    }
    super.removeListener(listener);
  }

  /// Xóa toàn bộ dữ liệu đang giữ khi đăng xuất.
  void clearAll() {
    health.clear();
    nutrition.clear();
    workout.clear();
  }

  @override
  void dispose() {
    for (final repository in repositories) {
      repository.dispose();
    }
    super.dispose();
  }
}

/// Đưa [AppData] xuống toàn bộ cây giao diện.
///
/// Widget nào cần vẽ lại theo dữ liệu thì bọc phần cần thiết trong
/// `ListenableBuilder(listenable: app, ...)`, hoặc lắng nghe riêng một
/// repository để phạm vi vẽ lại hẹp hơn nữa.
class AppScope extends InheritedNotifier<AppData> {
  const AppScope({
    super.key,
    required AppData data,
    required super.child,
  }) : super(notifier: data);

  static AppData of(BuildContext context, {bool listen = false}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AppScope>()
        : context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Không tìm thấy AppScope phía trên widget này.');
    return scope!.notifier!;
  }
}
