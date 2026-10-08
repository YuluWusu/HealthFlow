import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/auth_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_text_field.dart';
import '../widgets/error_banner.dart';
import 'login_screen.dart';

/// Màn hình 2 trong bản thiết kế: đăng ký tài khoản.
///
/// Sau khi đăng ký thành công, tài khoản được đăng nhập luôn và ứng dụng tự
/// chuyển vào màn hình chính (nhờ AuthGate ở gốc).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSubmitting = false;

  /// Đồng ý điều khoản là điều kiện bắt buộc trước khi tạo tài khoản.
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  String? _serverError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Quay lại',
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/auth_bg.jpg',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.15),
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 16, 26, 26),
              child: Form(
                key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tạo tài khoản',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bắt đầu hành trình sống khỏe cùng HealthFlow',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                AppTextField(
                  label: 'Họ và tên',
                  hint: 'Nhập họ và tên',
                  icon: Icons.person_outline_rounded,
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  enabled: !_isSubmitting,
                  onChanged: _clearServerError,
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
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
                  hint: 'Ít nhất 6 ký tự',
                  icon: Icons.lock_outline_rounded,
                  controller: _passwordController,
                  isPassword: true,
                  enabled: !_isSubmitting,
                  onChanged: _clearServerError,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Nhập lại mật khẩu',
                  hint: 'Nhập lại mật khẩu',
                  icon: Icons.lock_reset_rounded,
                  controller: _confirmController,
                  isPassword: true,
                  enabled: !_isSubmitting,
                  textInputAction: TextInputAction.done,
                  onChanged: _clearServerError,
                  onFieldSubmitted: (_) => _submit(),
                  validator: _validateConfirm,
                ),
                const SizedBox(height: 14),
                _buildTermsCheckbox(),
                if (_serverError != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _serverError!),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Đăng ký',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
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
                                  'Đăng ký bằng Google sẽ được bổ sung sau.',
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
                                  'Đăng ký bằng Apple sẽ được bổ sung sau.',
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Đã có tài khoản? ',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LoginScreen(),
                                ),
                              ),
                      child: const Text(
                        'Đăng nhập',
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

  Widget _buildTermsCheckbox() {
    final hasError = _showTermsError && !_acceptedTerms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 30,
              width: 30,
              child: Checkbox(
                value: _acceptedTerms,
                activeColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() {
                          _acceptedTerms = value ?? false;
                          _showTermsError = false;
                        }),
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Tôi đồng ý với Điều khoản sử dụng và Chính sách bảo mật của HealthFlow',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(left: 34, top: 2),
            child: Text(
              'Bạn cần đồng ý với điều khoản để tiếp tục.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.danger),
            ),
          ),
      ],
    );
  }

  void _clearServerError(String _) {
    if (_serverError != null) {
      setState(() => _serverError = null);
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Vui lòng nhập họ và tên.';
    if (name.length < 2) return 'Họ và tên quá ngắn.';
    return null;
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

  String? _validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'Vui lòng nhập lại mật khẩu.';
    if (value != _passwordController.text) return 'Mật khẩu nhập lại không khớp.';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _showTermsError = !_acceptedTerms;
      _serverError = null;
    });
    if (!formValid || !_acceptedTerms) return;

    setState(() => _isSubmitting = true);

    final auth = AuthScope.of(context, listen: false);
    try {
      await auth.register(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        confirmPassword: _confirmController.text,
      );
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Đăng ký thành công'),
            content: const Text('Tài khoản của bạn đã được tạo thành công. Vui lòng đăng nhập để tiếp tục.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
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
            'Hoặc đăng ký bằng',
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
