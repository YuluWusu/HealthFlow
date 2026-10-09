// ignore_for_file: deprecated_member_use, unused_element, unused_element_parameter, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/auth_repository.dart';
import '../data/auth_scope.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_card.dart';
import '../widgets/error_banner.dart';
import 'health_goal_screen.dart';
import 'profile_detail_screen.dart';

/// Màn hình 10 trong bản thiết kế: cài đặt tài khoản.
///
/// Gồm thông tin cá nhân, mục tiêu sức khỏe, thông báo, bảo mật và đăng xuất.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.currentUser;

    if (user == null) {
      // Trường hợp này chỉ xảy ra trong khoảnh khắc đăng xuất, khi AuthGate
      // chưa kịp thay màn hình.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          _ProfileHeader(user: user, onEdit: () => _editDisplayName(context, user)),
          const SizedBox(height: 22),
          const _SectionLabel('Tài khoản'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Thông tin cá nhân',
                  subtitle: 'Họ tên, email đăng nhập',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileDetailScreen())),
                ),
                const Divider(height: 1, indent: 64),
                SettingsTile(
                  icon: Icons.flag_outlined,
                  title: 'Mục tiêu sức khỏe',
                  subtitle: '${user.healthGoal} · ${user.dailyCalorieGoal} kcal/ngày',
                  iconColor: AppTheme.blue,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthGoalScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Quyền ứng dụng'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _NotificationSwitchTile(),
                const Divider(height: 1, indent: 64),
                _SoundSwitchTile(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Bảo mật và hỗ trợ'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Đổi mật khẩu',
                  subtitle: 'Cập nhật mật khẩu đăng nhập',
                  iconColor: AppTheme.purple,
                  showChevron: false,
                  onTap: () => _changePassword(context, user),
                ),
                const Divider(height: 1, indent: 64),
                SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Trợ giúp & hỗ trợ',
                  iconColor: AppTheme.blue,
                  showChevron: false,
                  onTap: () => _showHelp(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Đăng xuất',
              isDestructive: true,
              showChevron: false,
              onTap: () => _confirmLogout(context),
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'HealthFlow phiên bản 1.0.0',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Hộp thoại chỉnh sửa
  // ---------------------------------------------------------------------

  /// Chỉnh sửa tên hiển thị (bút chì cạnh avatar).
  Future<void> _editDisplayName(BuildContext context, User user) async {
    final auth = AuthScope.of(context, listen: false);
    final nameController = TextEditingController(text: user.fullName);
    final controller = _DialogController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() async {
              controller.clear();
              if (nameController.text.trim().isEmpty) {
                setDialogState(
                  () => controller.message = 'Họ và tên hiển thị không được để trống.',
                );
                return;
              }
              try {
                await auth.updateProfile(
                  fullName: nameController.text,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã cập nhật tên hiển thị.')),
                  );
                }
              } on AuthException catch (e) {
                setDialogState(() => controller.message = e.message);
              } catch (_) {
                setDialogState(() => controller.message = 'Có lỗi xảy ra, vui lòng thử lại.');
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Đổi tên hiển thị'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      onChanged: (_) => setDialogState(controller.clear),
                      decoration: const InputDecoration(
                        labelText: 'Tên hiển thị',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                    ),
                    if (controller.message != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: controller.message!),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(onPressed: submit, child: const Text('Lưu')),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }


  /// Đổi mật khẩu: phải nhập đúng mật khẩu hiện tại.
  Future<void> _changePassword(BuildContext context, User user) async {
    final auth = AuthScope.of(context, listen: false);
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final controller = _DialogController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              controller.clear();
              setDialogState(() => isSubmitting = true);
              try {
                await auth.changePassword(
                  currentPassword: currentController.text,
                  newPassword: newController.text,
                  confirmPassword: confirmController.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _showMessage(context, 'Đã đổi mật khẩu thành công.');
              } on AuthException catch (error) {
                setDialogState(() {
                  controller.message = error.message;
                  isSubmitting = false;
                });
              } catch (_) {
                setDialogState(() {
                  controller.message = 'Có lỗi xảy ra, vui lòng thử lại.';
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Đổi mật khẩu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PasswordField(
                      controller: currentController,
                      label: 'Mật khẩu hiện tại',
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(
                      controller: newController,
                      label: 'Mật khẩu mới',
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(
                      controller: confirmController,
                      label: 'Nhập lại mật khẩu mới',
                    ),
                    if (controller.message != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: controller.message!),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Đổi mật khẩu'),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  Future<void> _showHelp(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Trợ giúp & hỗ trợ'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpRow(
                icon: Icons.mail_outline_rounded,
                title: 'Email',
                value: 'hotro@healthflow.vn',
              ),
              SizedBox(height: 14),
              _HelpRow(
                icon: Icons.phone_outlined,
                title: 'Điện thoại',
                value: '1900 1234',
              ),
              SizedBox(height: 14),
              _HelpRow(
                icon: Icons.schedule_rounded,
                title: 'Thời gian hỗ trợ',
                value: '8:00 - 20:00 hằng ngày',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = AuthScope.of(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc muốn đăng xuất khỏi HealthFlow?',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: AppTheme.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    // AuthGate lắng nghe thay đổi này và tự đưa người dùng về màn hình chào
    // mừng, nên không cần điều hướng thủ công.
    await auth.logout();
  }

  // ---------------------------------------------------------------------
  // Tiện ích dùng chung trong màn hình
  // ---------------------------------------------------------------------

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Thẻ thông tin người dùng ở đầu màn hình cài đặt, có hỗ trợ avatar.
class _ProfileHeader extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;

  const _ProfileHeader({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _changeAvatar(context),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.lightGreen,
                  backgroundImage: user.avatarPath != null && user.avatarPath!.isNotEmpty
                      ? FileImage(File(user.avatarPath!))
                      : AssetImage('assets/images/auth/${user.gender}.jpg') as ImageProvider,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.healthGoal,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Chỉnh sửa thông tin',
          ),
        ],
      ),
    );
  }

  /// Hiện hộp thoại chọn ảnh đại diện.
  void _changeAvatar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Đổi ảnh đại diện',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.lightBlue,
                    child: Icon(Icons.photo_library_rounded, color: AppTheme.blue),
                  ),
                  title: const Text('Chọn từ thư viện ảnh'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAvatarFromGallery(context);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.lightGreen,
                    child: Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                  ),
                  title: const Text('Chụp ảnh mới'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAvatarFromCamera(context);
                  },
                ),
                if (user.avatarPath != null)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.lightPink,
                      child: Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
                    ),
                    title: const Text('Xóa ảnh đại diện'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _removeAvatar(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAvatarFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (!context.mounted) return;
        final auth = AuthScope.of(context, listen: false);
        await auth.updateProfile(avatarPath: pickedFile.path);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể truy cập thư viện ảnh. Vui lòng kiểm tra quyền trong cài đặt thiết bị.')),
      );
    }
  }

  Future<void> _pickAvatarFromCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        if (!context.mounted) return;
        final auth = AuthScope.of(context, listen: false);
        await auth.updateProfile(avatarPath: pickedFile.path);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể truy cập camera. Vui lòng kiểm tra quyền trong cài đặt thiết bị.')),
      );
    }
  }

  void _removeAvatar(BuildContext context) {
    final auth = AuthScope.of(context, listen: false);
    auth.updateProfile(avatarPath: '').then((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa ảnh đại diện.')),
      );
    });
  }
}

/// Switch tile cho thông báo với chức năng thực sự (#4)
class _NotificationSwitchTile extends StatefulWidget {
  @override
  State<_NotificationSwitchTile> createState() => _NotificationSwitchTileState();
}

class _NotificationSwitchTileState extends State<_NotificationSwitchTile> {
  bool _value = false;
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.notifications_active_outlined,
      title: 'Cho phép thông báo',
      subtitle: _value ? 'Đã bật thông báo' : 'Nhắc nhở lịch tập và uống nước',
      iconColor: AppTheme.orange,
      showChevron: false,
      trailing: _isRequesting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: _value,
              activeColor: AppTheme.primary,
              onChanged: (val) => _toggleNotification(val),
            ),
      onTap: () => _toggleNotification(!_value),
    );
  }

  Future<void> _toggleNotification(bool enable) async {
    if (_isRequesting) return;

    if (enable) {
      setState(() => _isRequesting = true);

      final service = NotificationService();
      await service.init();
      final granted = await service.requestPermission();

      if (granted && mounted) {
        setState(() {
          _value = true;
          _isRequesting = false;
        });
        
        await service.showNotification(
          id: 0,
          title: 'HealthFlow xin chào!',
          body: 'Bạn đã sẵn sàng nhận thông báo nhắc nhở sức khỏe.',
        );
      } else {
        if (mounted) {
          setState(() {
            _value = false;
            _isRequesting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng cấp quyền thông báo trong cài đặt hệ thống để tiếp tục.')),
          );
        }
      }
    } else {
      setState(() => _value = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tắt thông báo. Bạn có thể bật lại bất cứ lúc nào.')),
        );
      }
    }
  }
}

/// Nhãn nhóm mục trong màn hình cài đặt.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

/// Ô nhập số có sẵn biểu tượng và bàn phím số.
class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool allowDecimal;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.icon,
    this.allowDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}

/// Ô nhập mật khẩu có nút hiện/ẩn.
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const _PasswordField({required this.controller, required this.label});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Ô chỉ đọc, dùng để hiển thị email không cho sửa.
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Một dòng thông tin liên hệ trong hộp thoại trợ giúp.
class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _HelpRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppTheme.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Giữ thông báo lỗi của hộp thoại, giúp `StatefulBuilder` chỉ cần vẽ lại
/// phần nội dung khi lỗi thay đổi.
class _DialogController {
  String? message;

  void clear() => message = null;
}

class _SoundSwitchTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioService(),
      builder: (context, _) {
        final isEnabled = AudioService().soundEnabled;
        return SettingsTile(
          icon: isEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
          title: 'Âm thanh ứng dụng',
          subtitle: isEnabled ? 'Đã bật âm thanh' : 'Tắt âm thanh hệ thống',
          iconColor: AppTheme.blue,
          showChevron: false,
          trailing: Switch(
            value: isEnabled,
            activeColor: AppTheme.primary,
            onChanged: (val) {
              AudioService().setSoundEnabled(val);
              if (val) AudioService().playDing();
            },
          ),
          onTap: () {
            AudioService().setSoundEnabled(!isEnabled);
            if (!isEnabled) AudioService().playDing();
          },
        );
      },
    );
  }
}
