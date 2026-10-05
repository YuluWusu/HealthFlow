import '../models/user.dart';

/// Lớp lưu trữ tài khoản.
///
/// Hiện tại dùng [InMemoryAccountStore] (dữ liệu mất khi tắt ứng dụng).
/// Khi thêm `sqflite`, chỉ cần viết thêm một lớp `SqfliteAccountStore`
/// implements interface này rồi truyền vào [AuthRepository] — toàn bộ giao
/// diện phía trên không phải sửa gì.
abstract class AccountStore {
  Future<List<User>> all();

  Future<User?> findByEmail(String email);

  Future<User?> findById(String id);

  Future<void> insert(User user);

  Future<void> update(User user);
}

/// Lớp lưu trữ trong bộ nhớ, dùng cho giai đoạn chưa có cơ sở dữ liệu.
class InMemoryAccountStore implements AccountStore {
  /// Khởi tạo kho rỗng.
  InMemoryAccountStore();

  final Map<String, User> _usersById = {};
  final Map<String, String> _idByEmail = {};

  /// Tài khoản mẫu để mở app là đăng nhập được ngay, không cần đăng ký
  /// trước. Mật khẩu: `123456`.
  static const String demoEmail = 'minhanh@gmail.com';
  static const String demoPassword = '123456';

  /// Tạo sẵn một tài khoản demo khớp với bản thiết kế (Minh Anh).
  factory InMemoryAccountStore.withDemoAccount() {
    final store = InMemoryAccountStore();
    final demo = User(
      id: 'user-demo',
      fullName: 'Minh Anh',
      email: demoEmail,
      passwordHash: hashPassword(demoPassword, demoEmail),
      heightCm: 163,
      weightKg: 56.5,
      dailyCalorieGoal: 2000,
      healthGoal: 'Giảm cân',
      createdAt: DateTime(2026, 9, 5),
    );
    store._usersById[demo.id] = demo;
    store._idByEmail[demo.email.toLowerCase()] = demo.id;
    return store;
  }

  @override
  Future<List<User>> all() async => _usersById.values.toList();

  @override
  Future<User?> findByEmail(String email) async {
    final id = _idByEmail[email.trim().toLowerCase()];
    if (id == null) return null;
    return _usersById[id];
  }

  @override
  Future<User?> findById(String id) async => _usersById[id];

  @override
  Future<void> insert(User user) async {
    _usersById[user.id] = user;
    _idByEmail[user.email.toLowerCase()] = user.id;
  }

  @override
  Future<void> update(User user) async {
    _usersById[user.id] = user;
    _idByEmail[user.email.toLowerCase()] = user.id;
  }
}
