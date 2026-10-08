import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, HapticFeedback;

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/nutrition.dart';
import '../theme/app_theme.dart';

/// 1250 -> "1,25", 2000 -> "2,0" (đơn vị lít).
String _fmtL(int ml) {
  final l = ml / 1000;
  final text = ml % 100 == 0 ? l.toStringAsFixed(1) : l.toStringAsFixed(2);
  return text.replaceAll('.', ',');
}

/// Màn hình riêng cho nước uống: xem tiến độ trong ngày và thêm nước theo
/// nhiều cách (250 ml, 500 ml, 1 lít, "1 cốc nước" tự đặt dung tích, hoặc
/// nhập số bất kỳ theo ml / lít).
class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final TextEditingController _custom = TextEditingController();

  /// Đơn vị của ô nhập tay: false = ml, true = lít.
  bool _customInLiters = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// Số ml đang gõ trong ô nhập tay (0 nếu trống/sai).
  int get _customMl {
    final text = _custom.text.trim().replaceAll(',', '.');
    final value = double.tryParse(text);
    if (value == null || value <= 0) return 0;
    final ml = _customInLiters ? value * 1000 : value;
    return ml.round().clamp(0, 5000).toInt();
  }

  Future<void> _add(NutritionRepository nutrition, int ml) async {
    if (ml <= 0) return;
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.selectionClick();
    await nutrition.addWater(userId: user.id, deltaMl: ml);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text('Đã thêm $ml ml nước.'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => nutrition.undoWater(userId: user.id),
          ),
        ),
      );
  }

  Future<void> _addCustom(NutritionRepository nutrition) async {
    final ml = _customMl;
    if (ml <= 0) return;
    FocusScope.of(context).unfocus();
    await _add(nutrition, ml);
    _custom.clear();
    if (mounted) setState(() {});
  }

  Future<void> _undo(NutritionRepository nutrition) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    await nutrition.undoWater(userId: user.id);
  }

  Future<void> _editCup(NutritionRepository nutrition) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => _CupDialog(initial: nutrition.cupMl),
    );
    if (picked == null) return;
    await nutrition.setCupMl(userId: user.id, ml: picked);
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = AppScope.of(context).nutrition;
    final user = AuthScope.of(context, listen: false).currentUser;
    final goal = NutritionRepository.waterGoalFor(user?.weightKg ?? 55);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Quay lại',
        ),
        title: const Text(
          'Nước uống',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListenableBuilder(
        listenable: nutrition,
        builder: (context, _) {
          final fromDrinks = [
            for (final e in nutrition.todayEntries)
              if (e.waterMl > 0) e,
          ];

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
            children: [
              _ProgressCard(ml: nutrition.waterMl, goal: goal),
              const SizedBox(height: 22),
              const _SectionLabel('Thêm nhanh'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickButton(
                      label: '+250 ml',
                      onTap: () => _add(nutrition, 250),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickButton(
                      label: '+500 ml',
                      onTap: () => _add(nutrition, 500),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickButton(
                      label: '+1 lít',
                      onTap: () => _add(nutrition, 1000),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupCard(
                cupMl: nutrition.cupMl,
                onDrink: () => _add(nutrition, nutrition.cupMl),
                onEdit: () => _editCup(nutrition),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('Nhập số khác'),
              const SizedBox(height: 10),
              _buildCustomRow(nutrition),
              if (nutrition.canUndoWater) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _undo(nutrition),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Hoàn tác lần thêm gần nhất'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
              if (fromDrinks.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _SectionLabel('Từ đồ uống đã ghi'),
                const SizedBox(height: 10),
                _DrinkList(entries: fromDrinks),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomRow(NutritionRepository nutrition) {
    final ml = _customMl;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    hintText: _customInLiters ? 'Ví dụ 1,5' : 'Ví dụ 350',
                    suffixText: _customInLiters ? 'lít' : 'ml',
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _UnitChip(
                label: 'ml',
                selected: !_customInLiters,
                onTap: () => setState(() => _customInLiters = false),
              ),
              const SizedBox(width: 6),
              _UnitChip(
                label: 'lít',
                selected: _customInLiters,
                onTap: () => setState(() => _customInLiters = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: ml > 0 ? () => _addCustom(nutrition) : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(ml > 0 ? 'Thêm $ml ml' : 'Nhập lượng nước'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

/// Thẻ tiến độ: số lít đã uống, mục tiêu và còn thiếu bao nhiêu.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.ml, required this.goal});

  final int ml;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (ml / goal).clamp(0.0, 1.0).toDouble();
    final done = ml >= goal;
    final remain = (goal - ml).clamp(0, goal).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow(opacity: 0.05, blur: 14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppTheme.blue,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                _fmtL(ml),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.blue,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ ${_fmtL(goal)} L',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppTheme.lightBlue,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.blue),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            done
                ? 'Đã đạt mục tiêu nước hôm nay. Giữ nhịp này nhé!'
                : 'Còn thiếu ${_fmtL(remain)} L để đạt mục tiêu.',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút thêm nhanh một lượng cố định.
class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.lightBlue,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Icon(Icons.water_drop_rounded,
                  color: AppTheme.blue, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1 cốc nước": bấm để thêm đúng dung tích người dùng đã đặt, bút chì để đổi.
class _CupCard extends StatelessWidget {
  const _CupCard({
    required this.cupMl,
    required this.onDrink,
    required this.onEdit,
  });

  final int cupMl;
  final VoidCallback onDrink;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.blue,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onDrink,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    const Icon(Icons.local_drink_rounded,
                        color: Colors.white, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Uống 1 cốc nước',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '1 cốc = $cupMl ml',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 28, color: Colors.white38),
          InkWell(
            onTap: onEdit,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Icon(Icons.edit_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.blue : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Các đồ uống đã ghi trong bữa ăn của ngày và lượng nước chúng đã cộng vào.
class _DrinkList extends StatelessWidget {
  const _DrinkList({required this.entries});

  final List<MealEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.foodName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.slot.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${e.waterMl} ml',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.blue,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Hộp thoại đặt dung tích "1 cốc nước".
class _CupDialog extends StatefulWidget {
  const _CupDialog({required this.initial});

  final int initial;

  @override
  State<_CupDialog> createState() => _CupDialogState();
}

class _CupDialogState extends State<_CupDialog> {
  static const _presets = [200, 250, 330, 500, 750];

  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _value => int.tryParse(_controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final valid = _value >= 50 && _value <= 2000;

    return AlertDialog(
      title: const Text('Dung tích 1 cốc nước'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ml in _presets)
                ChoiceChip(
                  label: Text('$ml ml'),
                  selected: _value == ml,
                  onSelected: (_) => setState(() {
                    _controller.text = '$ml';
                  }),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              suffixText: 'ml',
              helperText: 'Từ 50 đến 2000 ml',
              isDense: true,
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.of(context).pop(_value) : null,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
