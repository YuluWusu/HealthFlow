import 'package:flutter/material.dart';

import 'auth_repository.dart';

/// Đưa [AuthRepository] xuống toàn bộ cây giao diện.
///
/// Dùng [InheritedNotifier] có sẵn của Flutter nên không cần thêm package
/// quản lý trạng thái. Khi repository phát thông báo, mọi widget gọi
/// [AuthScope.of] với `listen: true` sẽ được vẽ lại.
class AuthScope extends InheritedNotifier<AuthRepository> {
  const AuthScope({
    super.key,
    required AuthRepository repository,
    required super.child,
  }) : super(notifier: repository);

  /// Lấy repository gần nhất.
  ///
  /// Truyền `listen: false` khi chỉ cần gọi hàm (ví dụ trong `onPressed`)
  /// để widget đó không bị vẽ lại không cần thiết.
  static AuthRepository of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AuthScope>()
        : context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'Không tìm thấy AuthScope phía trên widget này.');
    return scope!.notifier!;
  }
}
