import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/auth_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_text_field.dart';
import '../widgets/error_banner.dart';
import '../widgets/fitlife_logo.dart';
import 'register_screen.dart';

/// Màn hình đăng nhập.
///
/// Kiểm tra dữ liệu hai lớp: `Form` bắt lỗi ngay trên ô nhập, còn
/// [AuthRepository.login] kiểm tra lại email/mật khẩu thật khi bấm nút.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _rememberMe = true;

  /// Lỗi trả về từ lớp nghiệp vụ (sai mật khẩu, không tìm thấy tài khoản...).
  String? _serverError;

  static const _bgImage = AssetImage('assets/images/welcome/bg_login-register.jpg');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_bgImage, context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          tooltip: 'Quay lại',
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hình nền mờ cho trang đăng nhập / đăng ký
          Opacity(
            opacity: 0.15,
            child: Image(
              image: _bgImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 16, 26, 26),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: FitLifeLogo(size: 56)),
                const SizedBox(height: 20),
                const Text(
                  'Đăng nhập',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tiếp tục hành trình sống khỏe của bạn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'Email',
                  hint: 'Nhập email của bạn',
                  icon: Icons.mail_outline_rounded,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isSubmitting,
                  onChanged: _clearServerError,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Mật khẩu',
                  hint: 'Nhập mật khẩu',
                  icon: Icons.lock_outline_rounded,
                  controller: _passwordController,
                  isPassword: true,
                  enabled: !_isSubmitting,
                  textInputAction: TextInputAction.done,
                  onChanged: _clearServerError,
                  onFieldSubmitted: (_) => _submit(),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      height: 34,
                      width: 34,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(
                                  () => _rememberMe = value ?? false,
                                ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Ghi nhớ đăng nhập',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _showMessage(
                                'Vui lòng liên hệ quản trị viên để lấy lại mật khẩu.',
                              ),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 10),
                  ErrorBanner(message: _serverError!),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Đăng nhập',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                if (_isSubmitting)
                  const SizedBox.shrink()
                else
                  _buildDemoHint(context),
                const SizedBox(height: 22),
                const _OrDivider(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SocialButton(
                        label: 'Google',
                        icon: Icons.g_mobiledata_rounded,
                        iconColor: const Color(0xFFDB4437),
                        onPressed: _isSubmitting
                            ? null
                            : () => _showMessage(
                                  'Đăng nhập bằng Google sẽ được bổ sung sau.',
                                ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SocialButton(
                        label: 'Apple',
                        icon: Icons.apple_rounded,
                        iconColor: AppTheme.textPrimary,
                        onPressed: _isSubmitting
                            ? null
                            : () => _showMessage(
                                  'Đăng nhập bằng Apple sẽ được bổ sung sau.',
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Chưa có tài khoản? ',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                      child: const Text(
                        'Đăng ký ngay',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ],
    ),
    );
  }

  /// Gợi ý tài khoản mẫu để người chấm thử được ngay mà không cần đăng ký.
  Widget _buildDemoHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tài khoản dùng thử',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'minhanh@gmail.com  ·  123456',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _fillDemoAccount,
                  child: const Text(
                    'Điền sẵn tài khoản này',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _fillDemoAccount() {
    _emailController.text = 'minhanh@gmail.com';
    _passwordController.text = '123456';
    setState(() => _serverError = null);
  }

  void _clearServerError(String _) {
    if (_serverError != null) {
      setState(() => _serverError = null);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (!AuthRepository.isValidEmail(email)) return 'Email không hợp lệ.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (password.length < 6) return 'Mật khẩu cần ít nhất 6 ký tự.';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    // Bỏ qua kiểm tra của Form nếu người dùng chưa nhập gì, để lỗi hiển thị
    // ngay dưới từng ô thay vì báo chung chung.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });

    final auth = AuthScope.of(context, listen: false);
    try {
      await auth.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // AuthGate ở gốc đã đổi sang màn hình chính; đóng màn hình đăng nhập
      // này để người dùng nhìn thấy màn hình đó.
      if (mounted) Navigator.of(context).maybePop();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _serverError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _serverError = 'Có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Đường kẻ ngang kèm chữ "Hoặc" ở giữa.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final lineColor = Colors.black.withValues(alpha: 0.10);

    return Row(
      children: [
        Expanded(child: Divider(color: lineColor, height: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Hoặc đăng nhập bằng',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: lineColor, height: 1)),
      ],
    );
  }
}
