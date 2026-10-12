import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/ingredient.dart';
import '../models/nutrition.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// Màn hình "Món tự nấu": gộp nhiều nguyên liệu theo gram thành một món mới,
/// tự tính calo/macro/xơ/đường/natri và chia theo số phần. Món lưu xong xuất
/// hiện trong danh mục tìm kiếm và ghi vào nhật ký như mọi món khác.
class RecipeBuilderScreen extends StatefulWidget {
  const RecipeBuilderScreen({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<RecipeBuilderScreen> createState() => _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends State<RecipeBuilderScreen> {
  final _name = TextEditingController();
  int _servings = 2;
  final List<RecipeItem> _items = [];

  /// Đang sửa công thức nào (null = công thức mới).
  String? _editingId;
  bool _saving = false;

  NutritionRepository get _n => widget.nutrition;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Recipe get _draft => Recipe(
        id: _editingId ?? 'draft',
        userId: '',
        name: _name.text.trim().isEmpty ? 'Món tự nấu' : _name.text.trim(),
        servings: _servings,
        items: _items,
      );

  void _toast(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(text),
          action: action,
        ),
      );
  }

  String _g(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  }

  Future<void> _addIngredient() async {
    final picked = await showModalBottomSheet<Ingredient>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IngredientPicker(nutrition: _n),
    );
    if (picked == null || !mounted) return;
    final grams = await showDialog<double>(
      context: context,
      builder: (_) => _GramsDialog(ingredient: picked),
    );
    if (grams == null || !mounted) return;
    setState(() => _items.add(RecipeItem.fromIngredient(picked, grams)));
  }

  Future<void> _editGrams(int index) async {
    final item = _items[index];
    final ingredient = _n.ingredients.cast<Ingredient?>().firstWhere(
          (i) => i!.name == item.name,
          orElse: () => null,
        );
    if (ingredient == null) {
      _toast('Không tìm thấy nguyên liệu "${item.name}". Hãy xóa và thêm lại.');
      return;
    }
    final grams = await showDialog<double>(
      context: context,
      builder: (_) => _GramsDialog(ingredient: ingredient, initial: item.grams),
    );
    if (grams == null || !mounted) return;
    setState(() => _items[index] = RecipeItem.fromIngredient(ingredient, grams));
  }

  void _reset() {
    setState(() {
      _editingId = null;
      _name.clear();
      _servings = 2;
      _items.clear();
    });
  }

  Future<void> _save() async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    if (_items.isEmpty) {
      _toast('Hãy thêm ít nhất một nguyên liệu.');
      return;
    }
    setState(() => _saving = true);
    final recipe = await _n.saveRecipe(
      userId: user.id,
      name: _name.text,
      servings: _servings,
      items: _items,
      id: _editingId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _toast('Đã lưu "${recipe.name}" · ${recipe.caloriesPerServing} kcal/phần.');
    _reset();
  }

  void _edit(Recipe r) {
    setState(() {
      _editingId = r.id;
      _name.text = r.name;
      _servings = r.servings;
      _items
        ..clear()
        ..addAll(r.items);
    });
  }

  Future<void> _log(Recipe r) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    final slot = await showModalBottomSheet<MealSlot>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ghi 1 phần vào bữa nào?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            for (final s in MealSlot.values)
              ListTile(
                title: Text(s.label),
                onTap: () => Navigator.of(sheetContext).pop(s),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (slot == null || !mounted) return;
    final goal = _n.summary.calorieGoal;
    final entry = await _n.addFood(
      userId: user.id,
      food: r.toFoodItem(),
      slot: slot,
      calorieGoal: goal,
    );
    if (!mounted) return;
    _toast(
      'Đã thêm ${r.name} vào ${slot.label.toLowerCase()}.',
      action: SnackBarAction(
        label: 'Hoàn tác',
        onPressed: () => _n.removeEntry(
          userId: user.id,
          entryId: entry.id,
          calorieGoal: goal,
        ),
      ),
    );
  }

  Future<void> _delete(Recipe r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa món tự nấu?'),
        content: Text('"${r.name}" sẽ bị xóa khỏi danh mục. Nhật ký đã ghi vẫn giữ nguyên.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _n.deleteRecipe(r.id);
    if (_editingId == r.id) _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Món tự nấu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListenableBuilder(
        listenable: _n,
        builder: (context, _) {
          final recipes = _n.recipes;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _card(child: _builderForm()),
              if (recipes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Món tự nấu của bạn',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                for (final r in recipes) _recipeTile(r),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _builderForm() {
    final draft = _draft;
    final per = draft.toFoodItem();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _editingId == null ? 'Công thức mới' : 'Đang sửa công thức',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Tên món (vd. Canh bí đỏ nấu tôm)',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Chia thành',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              ),
            ),
            IconButton(
              onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: AppTheme.primary,
            ),
            Text(
              '$_servings phần',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            IconButton(
              onPressed: _servings < 30 ? () => setState(() => _servings++) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppTheme.primary,
            ),
          ],
        ),
        const Divider(height: 20),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Chưa có nguyên liệu. Bấm "Thêm nguyên liệu" rồi nhập số gram.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          )
        else
          for (var i = 0; i < _items.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: () => _editGrams(i),
              title: Text(
                _items[i].name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                '${_g(_items[i].grams)} g · ${_items[i].calories.round()} kcal',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: 'Xóa nguyên liệu',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addIngredient,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Thêm nguyên liệu'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
        ),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mỗi phần (${draft.gramsPerServing} g): ${per.calories} kcal',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đạm ${_g(per.protein)} g · Carb ${_g(per.carbs)} g · Béo ${_g(per.fat)} g',
                  style: const TextStyle(fontSize: 12.5),
                ),
                Text(
                  'Xơ ${_g(per.fiber)} g · Đường ${_g(per.sugar)} g · Natri ${per.sodium.round()} mg',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cả nồi: ${draft.totalCalories.round()} kcal · ${draft.totalGrams.round()} g',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Text(_editingId == null ? 'Lưu món' : 'Cập nhật món'),
              ),
            ),
            if (_editingId != null || _items.isNotEmpty) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _saving ? null : _reset,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  foregroundColor: AppTheme.textSecondary,
                ),
                child: Text(_editingId == null ? 'Làm lại' : 'Hủy sửa'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _recipeTile(Recipe r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.name,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${r.caloriesPerServing} kcal/phần · ${r.servings} phần · ${r.items.length} nguyên liệu',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: () => _log(r),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Ghi vào bữa'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Sửa',
                  onPressed: () => _edit(r),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Xóa',
                  onPressed: () => _delete(r),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bảng tìm và chọn một nguyên liệu (bỏ dấu khi tìm).
class _IngredientPicker extends StatefulWidget {
  const _IngredientPicker({required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.nutrition.searchIngredients(keyword: _query);
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Tìm nguyên liệu (vd. thịt gà, cà rốt)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'Không có nguyên liệu phù hợp.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final ing = results[i];
                        return ListTile(
                          title: Text(ing.name),
                          subtitle: Text(
                            '${ing.group} · ${ing.calories.round()} kcal/100 g',
                          ),
                          onTap: () => Navigator.of(context).pop(ing),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp nhập số gram của một nguyên liệu.
class _GramsDialog extends StatefulWidget {
  const _GramsDialog({required this.ingredient, this.initial});

  final Ingredient ingredient;
  final double? initial;

  @override
  State<_GramsDialog> createState() => _GramsDialogState();
}

class _GramsDialogState extends State<_GramsDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial == null
        ? '100'
        : (widget.initial! == widget.initial!.roundToDouble()
            ? widget.initial!.toStringAsFixed(0)
            : widget.initial!.toStringAsFixed(1)),
  );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0 || v > 5000) {
      setState(() => _error = 'Nhập số gram từ 1 đến 5000.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final grams = double.tryParse(_c.text.trim().replaceAll(',', '.')) ?? 0;
    return AlertDialog(
      title: Text(widget.ingredient.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _ok(),
            decoration: InputDecoration(
              labelText: 'Khối lượng',
              suffixText: 'g',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '≈ ${widget.ingredient.caloriesFor(grams)} kcal',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _ok,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}
