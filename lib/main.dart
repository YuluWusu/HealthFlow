import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_scope.dart';
import 'data/auth_repository.dart';
import 'data/auth_scope.dart';
import 'data/nutrition_repository.dart';
import 'data/prefs_nutrition_store.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await AudioService().init();
  runApp(HealthFlowApp(prefs: prefs));
}

/// Ứng dụng HealthFlow.
///
/// Các repository được tạo một lần ở đây rồi truyền xuống qua [AuthScope] và
/// [AppScope], nên không màn hình nào phải tự khởi tạo lại dữ liệu.
class HealthFlowApp extends StatefulWidget {
  const HealthFlowApp({super.key, this.prefs});

  /// Chỉ dùng để lưu nhật ký dinh dưỡng. Để trống thì lưu trong bộ nhớ tạm
  /// (dùng cho kiểm thử).
  final SharedPreferences? prefs;

  @override
  State<HealthFlowApp> createState() => _HealthFlowAppState();
}

class _HealthFlowAppState extends State<HealthFlowApp> {
  late final AuthRepository _auth;
  late final AppData _data;

  @override
  void initState() {
    super.initState();
    _auth = AuthRepository();
    final prefs = widget.prefs;
    _data = AppData(
      nutrition: prefs == null
          ? null
          : NutritionRepository(store: PrefsNutritionStore(prefs)),
    );
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
          title: 'HealthFlow',
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

    if (!auth.isLoggedIn) {
      return const AnimatedSwitcher(
        duration: Duration(milliseconds: 250),
        child: WelcomeScreen(key: ValueKey('welcome')),
      );
    }

    // Nếu người dùng mới đăng nhập lần đầu, hiện onboarding
    if (auth.needsOnboarding) {
      return const AnimatedSwitcher(
        duration: Duration(milliseconds: 250),
        child: OnboardingScreen(key: ValueKey('onboarding')),
      );
    }

    return const AnimatedSwitcher(
      duration: Duration(milliseconds: 250),
      child: MainScreen(key: ValueKey('main')),
    );
  }
}
