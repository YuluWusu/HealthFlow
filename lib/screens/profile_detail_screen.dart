// ignore_for_file: unused_import, deprecated_member_use

import 'package:flutter/material.dart';

import '../data/auth_scope.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../services/audio_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late String _originalName;
  late String _currentGender;
  late String _originalGender;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEditing) {
      final user = AuthScope.of(context).currentUser;
      _originalName = user?.fullName ?? '';
      _nameController.text = _originalName;
      _originalGender = user?.gender ?? 'male';
      _currentGender = _originalGender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Họ và tên không được để trống.');
      return;
    }
    if (name.length < 2) {
      _showMessage('Họ và tên phải có ít nhất 2 ký tự.');
      return;
    }
    
    final auth = AuthScope.of(context, listen: false);
    auth.updateProfile(fullName: name, gender: _currentGender);
    setState(() {
      _isEditing = false;
      _originalName = name;
      _originalGender = _currentGender;
    });
    _showMessage('Đã cập nhật thông tin cá nhân.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).currentUser;
    if (user == null) return const SizedBox();

    return PopScope(
      canPop: !_isEditing,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final hasChanges = _isEditing &&
            (_nameController.text.trim() != _originalName ||
             _currentGender != _originalGender);
        
        if (hasChanges) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Chưa lưu thay đổi'),
              content: const Text('Bạn có những thay đổi chưa được lưu. Bạn có chắc chắn muốn thoát?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Ở lại'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Thoát'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            setState(() {
              _isEditing = false;
              _nameController.text = _originalName;
              _currentGender = _originalGender;
            });
            if (context.mounted) Navigator.of(context).pop();
          }
        } else {
          setState(() => _isEditing = false);
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.surface,
              backgroundImage: AssetImage('assets/images/auth/$_currentGender.jpg'),
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  enabled: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên hiển thị',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _currentGender,
                  decoration: const InputDecoration(
                    labelText: 'Giới tính',
                    prefixIcon: Icon(Icons.wc_rounded, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Nam')),
                    DropdownMenuItem(value: 'female', child: Text('Nữ')),
                  ],
                  onChanged: _isEditing
                      ? (val) {
                          if (val != null) setState(() => _currentGender = val);
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: user.email),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isEditing)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: ()  {
              AudioService().playTap();

                      setState(() {
                        _isEditing = false;
                        _nameController.text = user.fullName;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Lưu thay đổi'),
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: () => setState(() => _isEditing = true),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Chỉnh sửa thông tin'),
            ),
        ],
      ),
      ),
    );
  }
}
