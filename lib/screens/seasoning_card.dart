import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, HapticFeedback;

import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/ingredient.dart';
import '../models/nutrition.dart';
import '../theme/app_theme.dart';
import 'nutrition_cards.dart' show NutritionCard, suggestedSlot;

/// Thẻ "Nêm nếm thêm": ghi nhanh muối, đường, nước mắm, bột ngọt... mà bạn
/// nêm thêm lúc nấu/ăn, tính theo gram (1 muỗng cà phê ≈ 5 g, 1 muỗng canh
/// ≈ 15 g). Gia vị được lưu như một dòng nhật ký nên cộng vào đường/muối/natri
/// trong ngày.
class SeasoningCard extends StatelessWidget {
  const SeasoningCard({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final i in nutrition.ingredients)
        if (i.isSeasoning) i,
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nêm nếm thêm',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lỡ nêm thêm mắm, muối, đường, bột ngọt...? Bấm để ghi nhanh.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ing in items)
                ActionChip(
                  label: Text(ing.name),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  backgroundColor: const Color(0xFFF1F4F2),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _open(context, ing),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, Ingredient ing) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeasoningSheet(nutrition: nutrition, ingredient: ing),
    );
  }
}

class _SeasoningSheet extends StatefulWidget {
  const _SeasoningSheet({required this.nutrition, required this.ingredient});

  final NutritionRepository nutrition;
  final Ingredient ingredient;

  @override
  State<_SeasoningSheet> createState() => _SeasoningSheetState();
}

class _SeasoningSheetState extends State<_SeasoningSheet> {
  static const _quick = [1, 2, 5, 10, 15, 20];

  late final TextEditingController _controller =
      TextEditingController(text: '5');
  late MealSlot _slot = suggestedSlot(widget.nutrition);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _grams => int.tryParse(_controller.text.trim()) ?? 0;

  String _n(double v) {
    final s = v.toStringAsFixed(1);
    return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s)
        .replaceAll('.', ',');
  }

  Future<void> _add() async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null || _grams <= 0) return;
    final n = widget.nutrition;
    final goal = n.summary.calorieGoal;
    final messenger = ScaffoldMessenger.of(context);
    final name = widget.ingredient.name;
    final slotLabel = _slot.label.toLowerCase();
    final grams = _grams;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    final entry = await n.addFood(
      userId: user.id,
      food: widget.ingredient.toFoodItem(),
      slot: _slot,
      portion: grams / 100,
      calorieGoal: goal,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
 persist: false, duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          content: Text('Đã thêm $grams g $name vào $slotLabel.'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => n.removeEntry(
              userId: user.id,
              entryId: entry.id,
              calorieGoal: goal,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ing = widget.ingredient;
    final g = _grams;
    final valid = g > 0 && g <= 500;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ing.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '1 muỗng cà phê ≈ 5 g · 1 muỗng canh ≈ 15 g',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in _quick)
                    ChoiceChip(
                      label: Text('$q g'),
                      selected: g == q,
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _controller.text = '$q'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  suffixText: 'g',
                  helperText: 'Từ 1 đến 500 g',
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 8,
                children: [
                  for (final s in MealSlot.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _slot == s,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _slot = s),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                valid
                    ? '$g g ≈ ${ing.caloriesFor(g)} kcal · đường ${_n(ing.sugarFor(g))} g · muối ${_n(saltGramsOf(ing.sodiumFor(g)))} g'
                    : 'Nhập số gram hợp lệ',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: valid ? _add : null,
                  child: const Text('Thêm vào nhật ký'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
