import 'package:flutter/material.dart';

import 'data/app_scope.dart';
import 'data/auth_repository.dart';
import 'data/auth_scope.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitLifeApp());
}

/// Ứng dụng FitLife.
///
/// Các repository được tạo một lần ở đây rồi truyền xuống qua [AuthScope] và
/// [AppScope], nên không màn hình nào phải tự khởi tạo lại dữ liệu.
class FitLifeApp extends StatefulWidget {
  const FitLifeApp({super.key});

  @override
  State<FitLifeApp> createState() => _FitLifeAppState();
}

class _FitLifeAppState extends State<FitLifeApp> {
  late final AuthRepository _auth;
  late final AppData _data;

  @override
  void initState() {
    super.initState();
    _auth = AuthRepository();
    _data = AppData();
    _auth.restoreSession();
  }

  @override
  void dispose() {
    _auth.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      repository: _auth,
      child: AppScope(
        data: _data,
        child: MaterialApp(
          title: 'FitLife',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Cổng vào ứng dụng: chưa đăng nhập thì hiện màn hình chào mừng, đã đăng
/// nhập thì mở thẳng màn hình chính.
///
/// Nhờ widget này, màn hình đăng nhập/đăng ký không cần tự điều hướng sau khi
/// thành công — chỉ cần gọi repository là giao diện tự đổi.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    if (auth.isRestoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: auth.isLoggedIn
          ? const MainScreen(key: ValueKey('main'))
          : const WelcomeScreen(key: ValueKey('welcome')),
    );
  }
}
