// ignore_for_file: deprecated_member_use, unused_import

import 'package:flutter/material.dart';

import '../data/auth_scope.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class HealthGoalScreen extends StatefulWidget {
  const HealthGoalScreen({super.key});

  @override
  State<HealthGoalScreen> createState() => _HealthGoalScreenState();
}

class _HealthGoalScreenState extends State<HealthGoalScreen> {
  bool _isEditing = false;
  
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _goalController;
  late TextEditingController _targetController;
  String _selectedGoal = '';
  
  late String _originalHeight;
  late String _originalWeight;
  late String _originalGoal;
  late String _originalTarget;
  late String _originalSelectedGoal;

  final List<String> _goals = ['Giảm cân', 'Giữ dáng', 'Tăng cân', 'Tăng cơ'];

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _goalController = TextEditingController();
    _targetController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEditing) {
      final user = AuthScope.of(context).currentUser;
      if (user != null) {
        _originalHeight = user.heightCm.toStringAsFixed(0);
        _originalWeight = user.weightKg.toStringAsFixed(1);
        _originalGoal = user.dailyCalorieGoal.toString();
        _originalTarget = user.targetWeightKg?.toStringAsFixed(1) ?? '';
        _originalSelectedGoal = user.healthGoal;
        
        _heightController.text = _originalHeight;
        _weightController.text = _originalWeight;
        _goalController.text = _originalGoal;
        _targetController.text = _originalTarget;
        _selectedGoal = _originalSelectedGoal;
      }
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _goalController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _save() {
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final goal = int.tryParse(_goalController.text.trim());
    // Cân nặng mong muốn không bắt buộc: để trống nghĩa là xóa mục tiêu.
    final targetText = _targetController.text.trim().replaceAll(',', '.');
    final target = targetText.isEmpty ? null : double.tryParse(targetText);

    if (height == null || height < 50 || height > 250) {
      _showMessage('Chiều cao phải từ 50 đến 250 cm.');
      return;
    }
    if (weight == null || weight < 10 || weight > 300) {
      _showMessage('Cân nặng phải từ 10 đến 300 kg.');
      return;
    }
    if (goal == null || goal < 500 || goal > 8000) {
      _showMessage('Mục tiêu năng lượng phải từ 500 đến 8000 kcal.');
      return;
    }
    if (targetText.isNotEmpty && (target == null || target < 10 || target > 300)) {
      _showMessage('Cân nặng mong muốn phải từ 10 đến 300 kg (hoặc để trống).');
      return;
    }

    final auth = AuthScope.of(context, listen: false);
    auth.updateProfile(
      heightCm: height,
      weightKg: weight,
      dailyCalorieGoal: goal,
      healthGoal: _selectedGoal,
      targetWeightKg: target,
      clearTargetWeight: target == null,
    );

    setState(() {
      _isEditing = false;
      _originalHeight = _heightController.text.trim();
      _originalWeight = _weightController.text.trim();
      _originalGoal = _goalController.text.trim();
      _originalTarget = _targetController.text.trim();
      _originalSelectedGoal = _selectedGoal;
    });
    _showMessage('Đã cập nhật mục tiêu sức khỏe.');
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

        final hasChanges = _isEditing && (
          _heightController.text.trim() != _originalHeight ||
          _weightController.text.trim() != _originalWeight ||
          _goalController.text.trim() != _originalGoal ||
          _targetController.text.trim() != _originalTarget ||
          _selectedGoal != _originalSelectedGoal
        );

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
              _heightController.text = _originalHeight;
              _weightController.text = _originalWeight;
              _goalController.text = _originalGoal;
              _targetController.text = _originalTarget;
              _selectedGoal = _originalSelectedGoal;
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
          title: const Text('Mục tiêu sức khỏe', style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedGoal.isNotEmpty ? _selectedGoal : user.healthGoal,
                  decoration: const InputDecoration(
                    labelText: 'Mục tiêu',
                    prefixIcon: Icon(Icons.flag_outlined, size: 20),
                  ),
                  items: _goals.map((goal) => DropdownMenuItem(value: goal, child: Text(goal))).toList(),
                  onChanged: _isEditing ? (value) {
                    if (value != null) setState(() => _selectedGoal = value);
                  } : null,
                  disabledHint: Text(user.healthGoal),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _heightController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Chiều cao (cm)',
                    prefixIcon: Icon(Icons.height_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _weightController,
                  enabled: _isEditing,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cân nặng (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _targetController,
                  enabled: _isEditing,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cân nặng mong muốn (kg) - không bắt buộc',
                    prefixIcon: Icon(Icons.flag_circle_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _goalController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mục tiêu năng lượng (kcal/ngày)',
                    prefixIcon: Icon(Icons.local_fire_department_outlined, size: 20),
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
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _heightController.text = user.heightCm.toStringAsFixed(0);
                        _weightController.text = user.weightKg.toStringAsFixed(1);
                        _goalController.text = user.dailyCalorieGoal.toString();
                        _targetController.text =
                            user.targetWeightKg?.toStringAsFixed(1) ?? '';
                        _selectedGoal = user.healthGoal;
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
              child: const Text('Chỉnh sửa mục tiêu'),
            ),
        ],
      ),
      ),
    );
  }
}
