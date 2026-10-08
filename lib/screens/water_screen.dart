import 'dart:async';
import 'dart:math' as math;

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
    _hideToast();
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
    HapticFeedback.selectionClick();
    await nutrition.addWater(userId: user.id, deltaMl: ml);
    if (!mounted) return;
    _showToast(
      'Đã thêm $ml ml nước',
      actionLabel: 'Hoàn tác',
      onAction: () => nutrition.undoWater(userId: user.id),
    );
  }

  OverlayEntry? _toast;
  Timer? _toastTimer;

  void _hideToast() {
    _toastTimer?.cancel();
    _toast?.remove();
    _toast = null;
  }

  /// Thông báo nhỏ dạng pop-up, tự biến mất sau ~2 giây và không bám sang màn khác.
  void _showToast(String message, {String? actionLabel, VoidCallback? onAction}) {
    _hideToast();
    final entry = OverlayEntry(
      builder: (_) => _Toast(
        message: message,
        actionLabel: actionLabel,
        onAction: () {
          _hideToast();
          onAction?.call();
        },
      ),
    );
    _toast = entry;
    Overlay.of(context).insert(entry);
    _toastTimer = Timer(const Duration(milliseconds: 2200), _hideToast);
  }

  /// Bớt một lượng nước đã ghi nhầm.
  Future<void> _remove(NutritionRepository nutrition) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    final ml = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RemoveSheet(
        currentMl: nutrition.waterMl,
        canUndo: nutrition.canUndoWater,
      ),
    );
    if (ml == null || !mounted) return;
    if (ml < 0) {
      final undone = await nutrition.undoWater(userId: user.id);
      if (!mounted || undone == 0) return;
      _showToast(undone > 0
          ? 'Đã bỏ lần thêm $undone ml'
          : 'Đã khôi phục ${-undone} ml');
      return;
    }
    final amount = ml.clamp(0, nutrition.waterMl).toInt();
    if (amount <= 0) return;
    await nutrition.addWater(userId: user.id, deltaMl: -amount);
    if (mounted) {
      _showToast(
        'Đã bớt $amount ml nước',
        actionLabel: 'Hoàn tác',
        onAction: () => nutrition.undoWater(userId: user.id),
      );
    }
  }

  Future<void> _addCustom(NutritionRepository nutrition) async {
    final ml = _customMl;
    if (ml <= 0) return;
    FocusScope.of(context).unfocus();
    await _add(nutrition, ml);
    _custom.clear();
    if (mounted) setState(() {});
  }

  /// Xóa số đang gõ trong ô nhập tay (không đụng tới lượng nước đã ghi).
  void _clearCustom() {
    HapticFeedback.selectionClick();
    _custom.clear();
    setState(() {});
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
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.lightBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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

          final progress = goal <= 0
              ? 0.0
              : (nutrition.waterMl / goal).clamp(0.0, 1.0).toDouble();
          final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;

          return Stack(
            children: [
              Positioned.fill(child: _WaterBackground(progress: progress)),
              ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, topPad + 6, 20, 32),
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
              if (nutrition.waterMl > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _remove(nutrition),
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text('Uống nhầm? Chỉnh lại lượng nước'),
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
          ),
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
                    suffixIcon: _custom.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _clearCustom,
                            tooltip: 'Xóa số đã nhập',
                            icon: const Icon(Icons.cancel_rounded, size: 20),
                            color: AppTheme.textSecondary,
                          ),
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


/// Pop-up nhỏ ở đầu màn hình, tự trượt vào rồi mờ đi.
class _Toast extends StatelessWidget {
  const _Toast({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 64;
    return Positioned(
      top: top,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, (1 - t) * -12), child: child),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.textPrimary,
                borderRadius: BorderRadius.circular(30),
                boxShadow: AppTheme.softShadow(opacity: 0.18, blur: 16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_drop_rounded,
                      color: AppTheme.blue, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onAction,
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(
                          color: AppTheme.blue,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bảng chọn lượng nước muốn bớt. Trả về số ml, hoặc -1 nếu chọn hoàn tác thao tác gần nhất.
class _RemoveSheet extends StatefulWidget {
  const _RemoveSheet({required this.currentMl, required this.canUndo});

  final int currentMl;
  final bool canUndo;

  @override
  State<_RemoveSheet> createState() => _RemoveSheetState();
}

class _RemoveSheetState extends State<_RemoveSheet> {
  final _c = TextEditingController();
  bool _liters = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int get _ml {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return 0;
    return (_liters ? v * 1000 : v).round().clamp(0, widget.currentMl).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final ml = _ml;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chỉnh lại lượng nước',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hôm nay đã ghi ${widget.currentMl} ml. Nhập số muốn bớt đi nhé.',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          if (widget.canUndo)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(-1),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Quay lại như trước'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    hintText: _liters ? 'Ví dụ 0,5' : 'Ví dụ 250',
                    suffixText: _liters ? 'lít' : 'ml',
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
                selected: !_liters,
                onTap: () => setState(() => _liters = false),
              ),
              const SizedBox(width: 6),
              _UnitChip(
                label: 'lít',
                selected: _liters,
                onTap: () => setState(() => _liters = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: ml > 0 ? () => Navigator.of(context).pop(ml) : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(ml > 0 ? 'Bớt $ml ml' : 'Nhập lượng muốn bớt'),
            ),
          ),
        ],
      ),
    );
  }
}


/// Nền nước: dải màu xanh nhạt, sóng chuyển động và bong bóng nổi lên.
/// Mực sóng dâng cao dần theo tiến độ uống nước trong ngày.
class _WaterBackground extends StatefulWidget {
  const _WaterBackground({required this.progress});

  final double progress;

  @override
  State<_WaterBackground> createState() => _WaterBackgroundState();
}

class _WaterBackgroundState extends State<_WaterBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.progress),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, level, __) => CustomPaint(
            painter: _WavePainter(_c, level),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t, this.level) : super(repaint: t);

  final Animation<double> t;
  final double level;

  static const _bubbles = [
    // x (0..1), bán kính, tốc độ (số nguyên để vòng lặp liền mạch), lệch pha
    [0.10, 7.0, 1.0, 0.00],
    [0.24, 4.5, 2.0, 0.35],
    [0.38, 9.0, 1.0, 0.62],
    [0.52, 5.0, 2.0, 0.10],
    [0.66, 8.0, 1.0, 0.80],
    [0.78, 4.0, 2.0, 0.55],
    [0.90, 6.5, 1.0, 0.28],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final v = t.value;

    // Nền chuyển màu từ xanh nhạt sang trắng ngà.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDCEBFA), Color(0xFFEAF3FC), Color(0xFFF5F8F6)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(Offset.zero & size),
    );

    // Mực nước: từ 12% đến 40% chiều cao màn hình.
    final baseY = h * (1 - (0.12 + 0.28 * level));

    // Bong bóng nổi từ đáy lên mặt nước.
    for (final b in _bubbles) {
      final p = (v * b[2] + b[3]) % 1.0;
      final y = h - p * (h - baseY + 10);
      final x = w * b[0] + math.sin((v * b[2] + b[3]) * 2 * math.pi * 2) * 10;
      final r = b[1];
      final fade = math.sin(p * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = AppTheme.blue.withValues(alpha: 0.12 * fade),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppTheme.blue.withValues(alpha: 0.30 * fade),
      );
    }

    // Ba lớp sóng với pha và biên độ khác nhau.
    _wave(canvas, size, baseY + 14, 16, 1, v * 2 * math.pi, 0.10);
    _wave(canvas, size, baseY + 6, 13, 2, -v * 2 * math.pi + 1.2, 0.14);
    _wave(canvas, size, baseY, 10, 1, v * 2 * math.pi * 2 + 2.4, 0.20);
  }

  void _wave(Canvas canvas, Size size, double y, double amp, int cycles,
      double phase, double alpha) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, y);
    for (double x = 0; x <= size.width; x += 4) {
      final dy = math.sin(x / size.width * 2 * math.pi * (cycles + 0.5) + phase);
      path.lineTo(x, y + dy * amp);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = AppTheme.blue.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.level != level;
}
