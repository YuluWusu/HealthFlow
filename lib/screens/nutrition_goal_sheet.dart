import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/nutrition_goals.dart';
import '../theme/app_theme.dart';

/// Bảng chọn chế độ ăn theo mục tiêu (giảm cân, tăng cơ, eat clean...) và tự
/// đặt mục tiêu macro theo % hoặc theo gram.
Future<void> showNutritionGoalSheet(
  BuildContext context,
  NutritionRepository nutrition,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NutritionGoalSheet(nutrition: nutrition),
  );
}

class NutritionGoalSheet extends StatefulWidget {
  const NutritionGoalSheet({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<NutritionGoalSheet> createState() => _NutritionGoalSheetState();
}

class _NutritionGoalSheetState extends State<NutritionGoalSheet> {
  late DietMode _mode;
  late bool _custom;
  late bool _byPercent;
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  String? _error;
  bool _busy = false;

  NutritionRepository get _n => widget.nutrition;
  int get _kcal => _n.summary.calorieGoal;

  @override
  void initState() {
    super.initState();
    final healthGoal =
        AuthScope.of(context, listen: false).currentUser?.healthGoal ??
            'Giữ dáng';
    _mode = _n.effectiveDietMode(healthGoal);
    final config = _n.macroConfig;
    _custom = config != null;
    _byPercent = config?.byPercent ?? true;
    if (config != null) {
      _fill(config.protein, config.carbs, config.fat);
    } else {
      _fillFromMode();
    }
  }

  @override
  void dispose() {
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _fill(double p, double c, double f) {
    _protein.text = _fmt(p);
    _carbs.text = _fmt(c);
    _fat.text = _fmt(f);
  }

  /// Điền ô nhập theo tỉ lệ của chế độ ăn (đổi ra gram nếu đang nhập gram).
  void _fillFromMode() {
    if (_byPercent) {
      _fill(
        _mode.proteinPct.toDouble(),
        _mode.carbsPct.toDouble(),
        _mode.fatPct.toDouble(),
      );
    } else {
      final t = resolveMacroTargets(calorieGoal: _kcal, mode: _mode);
      _fill(t.proteinG.toDouble(), t.carbsG.toDouble(), t.fatG.toDouble());
    }
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(text),
        ),
      );
  }

  Future<void> _selectMode(DietMode mode) async {
    setState(() {
      _mode = mode;
      _custom = false;
      _error = null;
      _fillFromMode();
    });
    // Chọn chế độ thì macro quay về tỉ lệ của chế độ đó.
    await _n.setMacroConfig(null);
    await _n.setDietMode(mode);
  }

  void _switchUnit(bool byPercent) {
    if (byPercent == _byPercent) return;
    final p = _parse(_protein) ?? 0;
    final c = _parse(_carbs) ?? 0;
    final f = _parse(_fat) ?? 0;
    final kcal = _kcal.toDouble();
    setState(() {
      _error = null;
      if (byPercent) {
        // gram -> % năng lượng
        _fill(
          kcal > 0 ? (p * 4 / kcal * 100).roundToDouble() : 0,
          kcal > 0 ? (c * 4 / kcal * 100).roundToDouble() : 0,
          kcal > 0 ? (f * 9 / kcal * 100).roundToDouble() : 0,
        );
      } else {
        // % năng lượng -> gram
        _fill(
          (kcal * p / 100 / 4).roundToDouble(),
          (kcal * c / 100 / 4).roundToDouble(),
          (kcal * f / 100 / 9).roundToDouble(),
        );
      }
      _byPercent = byPercent;
    });
  }

  Future<void> _saveMacros() async {
    final p = _parse(_protein);
    final c = _parse(_carbs);
    final f = _parse(_fat);
    if (p == null || c == null || f == null || p < 0 || c < 0 || f < 0) {
      setState(() => _error = 'Hãy nhập đủ ba số hợp lệ.');
      return;
    }
    if (_byPercent) {
      if ((p + c + f - 100).abs() > 0.5) {
        setState(() => _error =
            'Tổng ba tỉ lệ phải bằng 100% (hiện ${_fmt(p + c + f)}%).');
        return;
      }
    } else if (p + c + f <= 0) {
      setState(() => _error = 'Hãy nhập số gram lớn hơn 0.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    await _n.setMacroConfig(
      MacroGoalConfig(byPercent: _byPercent, protein: p, carbs: c, fat: f),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _custom = true;
    });
    _toast('Đã lưu mục tiêu macro của bạn.');
  }

  Future<void> _resetMacros() async {
    await _n.setMacroConfig(null);
    if (!mounted) return;
    setState(() {
      _custom = false;
      _error = null;
      _fillFromMode();
    });
    _toast('Đã dùng tỉ lệ macro theo chế độ ${_mode.label.toLowerCase()}.');
  }

  /// Áp dụng chế độ + calo gợi ý vào hồ sơ (cùng nơi với màn hình Mục tiêu
  /// sức khỏe), nên hai màn hình luôn khớp nhau.
  Future<void> _applyToProfile(int suggested) async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await auth.updateProfile(
        dailyCalorieGoal: suggested,
        healthGoal: _mode.healthGoal,
      );
      // Chế độ riêng (vd. Eat clean) giữ nguyên dù hồ sơ ghi "Giữ dáng".
      await _n.setDietMode(_mode);
      await _n.loadDay(userId: user.id, calorieGoal: suggested);
      if (mounted) {
        _toast('Đã đặt mục tiêu $suggested kcal/ngày cho chế độ ${_mode.label}.');
      }
    } catch (_) {
      if (mounted) _toast('Không cập nhật được hồ sơ. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context, listen: false).currentUser;
    final suggested = user == null
        ? null
        : suggestedCalorieGoal(
            mode: _mode,
            weightKg: user.weightKg,
            heightCm: user.heightCm,
            gender: user.gender,
          );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mục tiêu & chế độ ăn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mục tiêu hiện tại: $_kcal kcal/ngày',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              for (final mode in DietMode.values)
                _ModeTile(
                  mode: mode,
                  selected: mode == _mode,
                  onTap: () => _selectMode(mode),
                ),
              if (suggested != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Gợi ý cho chế độ ${_mode.label.toLowerCase()}: '
                          '$suggested kcal/ngày (tính từ chiều cao, cân nặng '
                          'trong hồ sơ).',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy ? null : () => _applyToProfile(suggested),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Áp dụng'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tự đặt macro',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: true, label: Text('%')),
                      ButtonSegment(value: false, label: Text('gram')),
                    ],
                    selected: {_byPercent},
                    onSelectionChanged: (s) => _switchUnit(s.first),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field('Đạm', _protein)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Carb', _carbs)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Béo', _fat)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _hint(),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _saveMacros,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('Lưu macro'),
                    ),
                  ),
                  if (_custom) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _busy ? null : _resetMacros,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: AppTheme.textSecondary,
                      ),
                      child: const Text('Dùng theo chế độ'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dòng gợi ý dưới ô nhập: tổng % hoặc quy đổi ra calo.
  String _hint() {
    final p = _parse(_protein) ?? 0;
    final c = _parse(_carbs) ?? 0;
    final f = _parse(_fat) ?? 0;
    if (_byPercent) {
      final total = p + c + f;
      final g = resolveMacroTargets(
        calorieGoal: _kcal,
        mode: _mode,
        custom: MacroGoalConfig(byPercent: true, protein: p, carbs: c, fat: f),
      );
      return 'Tổng ${_fmt(total)}% (cần 100%) · ≈ ${g.proteinG} g đạm, '
          '${g.carbsG} g carb, ${g.fatG} g béo';
    }
    final kcal = (p * 4 + c * 4 + f * 9).round();
    return '≈ $kcal kcal từ macro (mục tiêu $_kcal kcal)';
  }

  Widget _field(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() => _error = null),
      decoration: InputDecoration(
        labelText: label,
        suffixText: _byPercent ? '%' : 'g',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final DietMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.08)
            : const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mode.summary,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Đạm ${mode.proteinPct}% · Carb ${mode.carbsPct}% · Béo ${mode.fatPct}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
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
    );
  }
}
