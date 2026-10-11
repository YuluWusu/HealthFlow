import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/account_store.dart';
import '../data/health_store.dart';
import '../models/health_metric.dart';
import '../models/user.dart';

/// Lỗi nghiệp vụ của phần tài khoản, kèm thông báo hiển thị thẳng cho
/// người dùng bằng tiếng Việt.
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Quản lý tài khoản: đăng ký, đăng nhập, đăng xuất và phiên làm việc.
///
/// [AuthRepository] là một [ChangeNotifier] nên giao diện có thể lắng nghe
/// và tự vẽ lại khi trạng thái đăng nhập thay đổi.
class AuthRepository extends ChangeNotifier {
  AuthRepository({
    AccountStore? accountStore,
    HealthStore? healthStore,
  })  : _accounts = accountStore ?? InMemoryAccountStore.withDemoAccount(),
        _health = healthStore ?? InMemoryHealthStore();

  final AccountStore _accounts;
  final HealthStore _health;

  User? _currentUser;
  bool _isRestoring = true;

  /// Đánh dấu người dùng mới chưa hoàn thành onboarding
  bool _needsOnboarding = false;

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  /// `true` nếu người dùng mới đăng ký và chưa hoàn thành thiết lập ban đầu.
  bool get needsOnboarding => _needsOnboarding;

  /// `true` trong lúc ứng dụng đang kiểm tra phiên đăng nhập đã lưu.
  bool get isRestoring => _isRestoring;

  /// Key lưu trữ trong SharedPreferences
  static const String _keyLoggedInUserId = 'logged_in_user_id';
  static const String _keyOnboardingComplete = 'onboarding_complete';

  /// Khôi phục phiên đăng nhập đã lưu (nếu có).
  ///
  /// Đọc mã người dùng đã lưu trong SharedPreferences và đăng nhập lại.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_keyLoggedInUserId);

      if (savedUserId != null && savedUserId.isNotEmpty) {
        final user = await _accounts.findById(savedUserId);
        if (user != null) {
          _currentUser = user;
          // Kiểm tra xem đã onboarding chưa
          final onboardingDone = prefs.getBool('${_keyOnboardingComplete}_${user.id}') ?? false;
          _needsOnboarding = !onboardingDone;
        }
      }
    } catch (_) {
      // Bỏ qua lỗi đọc SharedPreferences
    }

    _isRestoring = false;
    notifyListeners();
  }

  /// Lưu phiên đăng nhập vào SharedPreferences
  Future<void> _saveSession(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLoggedInUserId, userId);
    } catch (_) {
      // Bỏ qua lỗi lưu
    }
  }

  /// Xóa phiên đăng nhập khỏi SharedPreferences
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLoggedInUserId);
    } catch (_) {
      // Bỏ qua lỗi xóa
    }
  }

  /// Đánh dấu đã hoàn thành onboarding
  Future<void> completeOnboarding() async {
    _needsOnboarding = false;
    if (_currentUser != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('${_keyOnboardingComplete}_${_currentUser!.id}', true);
      } catch (_) {
        // Bỏ qua lỗi lưu
      }
    }
    notifyListeners();
  }

  /// Đăng ký tài khoản mới và đăng nhập luôn.
  ///
  /// Ném [AuthException] với thông báo tiếng Việt khi dữ liệu không hợp lệ,
  /// để màn hình đăng ký chỉ việc hiển thị lỗi đó.
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final name = fullName.trim();
    final mail = email.trim().toLowerCase();

    if (name.isEmpty) {
      throw const AuthException('Vui lòng nhập họ và tên.');
    }
    if (name.length < 2) {
      throw const AuthException('Họ và tên quá ngắn.');
    }
    if (!isValidEmail(mail)) {
      throw const AuthException('Email không hợp lệ.');
    }
    if (password.length < 6) {
      throw const AuthException('Mật khẩu cần ít nhất 6 ký tự.');
    }
    if (password != confirmPassword) {
      throw const AuthException('Mật khẩu nhập lại không khớp.');
    }

    await _delay();

    final existing = await _accounts.findByEmail(mail);
    if (existing != null) {
      throw const AuthException('Email này đã được đăng ký.');
    }

    final user = User(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      fullName: name,
      email: mail,
      passwordHash: hashPassword(password, mail),
      createdAt: DateTime.now(),
    );

    await _accounts.insert(user);

    // Tạo sẵn số liệu ban đầu để trang chủ và trang Sức khỏe có dữ liệu
    // hiển thị ngay sau khi đăng ký.
    for (final metric in InMemoryHealthStore.seedFor(user.id)) {
      await _health.insert(metric);
    }

    return user;
  }

  /// Đăng nhập bằng email và mật khẩu.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final mail = email.trim().toLowerCase();

    if (mail.isEmpty || password.isEmpty) {
      throw const AuthException('Vui lòng nhập email và mật khẩu.');
    }
    if (!isValidEmail(mail)) {
      throw const AuthException('Email không hợp lệ.');
    }

    await _delay();

    final user = await _accounts.findByEmail(mail);
    // Cố tình dùng chung một thông báo cho cả hai trường hợp sai email và
    // sai mật khẩu, tránh tiết lộ email nào đã tồn tại trong hệ thống.
    if (user == null || user.passwordHash != hashPassword(password, mail)) {
      throw const AuthException('Email hoặc mật khẩu không đúng.');
    }

    _currentUser = user;

    // Kiểm tra onboarding
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('${_keyOnboardingComplete}_${user.id}') ?? false;
      _needsOnboarding = !onboardingDone;
    } catch (_) {
      _needsOnboarding = false;
    }

    // Lưu phiên đăng nhập
    await _saveSession(user.id);

    notifyListeners();
    return user;
  }

  Future<void> logout() async {
    await _clearSession();
    _currentUser = null;
    _needsOnboarding = false;
    notifyListeners();
  }

  /// Đổi mật khẩu của tài khoản đang đăng nhập.
  ///
  /// Bắt buộc nhập đúng mật khẩu hiện tại trước khi đặt mật khẩu mới.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để đổi mật khẩu.');
    }
    if (user.passwordHash != hashPassword(currentPassword, user.email)) {
      throw const AuthException('Mật khẩu hiện tại không đúng.');
    }
    if (newPassword.length < 6) {
      throw const AuthException('Mật khẩu mới cần ít nhất 6 ký tự.');
    }
    if (newPassword != confirmPassword) {
      throw const AuthException('Mật khẩu nhập lại không khớp.');
    }
    if (newPassword == currentPassword) {
      throw const AuthException('Mật khẩu mới trùng với mật khẩu hiện tại.');
    }

    await _delay();

    final updated = user.copyWith(
      passwordHash: hashPassword(newPassword, user.email),
    );
    await _accounts.update(updated);
    _currentUser = updated;
    notifyListeners();
  }

  /// Cập nhật thông tin cá nhân và chỉ số cơ thể.
  ///
  /// Nếu cân nặng thay đổi, một bản ghi chỉ số mới được thêm vào nhật ký sức
  /// khỏe và trả về cho nơi gọi để nạp lại biểu đồ theo dõi.
  Future<HealthMetric?> updateProfile({
    String? fullName,
    String? healthGoal,
    double? heightCm,
    double? weightKg,
    int? dailyCalorieGoal,
    String? gender,
    double? targetWeightKg,
    bool clearTargetWeight = false,
    String? avatarPath,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để cập nhật thông tin.');
    }

    final name = fullName?.trim();
    if (name != null && name.isEmpty) {
      throw const AuthException('Họ và tên không được để trống.');
    }

    final updated = user.copyWith(
      fullName: name,
      healthGoal: healthGoal,
      heightCm: heightCm,
      weightKg: weightKg,
      dailyCalorieGoal: dailyCalorieGoal,
      gender: gender,
      targetWeightKg: targetWeightKg,
      clearTargetWeight: clearTargetWeight,
      avatarPath: avatarPath,
    );
    await _accounts.update(updated);
    _currentUser = updated;

    HealthMetric? newWeightMetric;
    if (weightKg != null && weightKg != user.weightKg) {
      newWeightMetric = HealthMetric(
        id: 'metric-weight-${DateTime.now().microsecondsSinceEpoch}',
        userId: updated.id,
        type: HealthMetricType.weight,
        value: weightKg,
        recordedAt: DateTime.now(),
        note: 'Cập nhật từ hồ sơ cá nhân',
      );
      await _health.insert(newWeightMetric);
    }

    // Sử dụng WidgetsBinding.instance.addPostFrameCallback để tránh lỗi
    // "setState() or markNeedsBuild() called during build" khi
    // notifyListeners() được gọi từ trong một dialog context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    return newWeightMetric;
  }

  /// Kiểm tra định dạng email ở mức cơ bản.
  ///
  /// Biểu thức chính quy yêu cầu có ký tự trước `@`, có dấu chấm và tên miền
  /// phía sau; đủ chặt để bắt lỗi gõ nhầm thường gặp.
  static bool isValidEmail(String email) {
    final pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]{2,}$');
    return pattern.hasMatch(email.trim());
  }

  /// Độ trễ giả lập.
  ///
  /// Có độ trễ thì trạng thái "đang xử lý" trên nút bấm mới quan sát được,
  /// đồng thời mọi lời gọi đều là bất đồng bộ sẵn sàng cho lúc gọi cơ sở dữ
  /// liệu thật. Đặt bằng 0 khi chạy kiểm thử.
  static Duration simulatedLatency = const Duration(milliseconds: 450);

  Future<void> _delay() {
    if (simulatedLatency == Duration.zero) return Future.value();
    return Future.delayed(simulatedLatency);
  }
}
