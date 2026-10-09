import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/ingredient.dart';
import '../models/meal_combo.dart';
import '../models/nutrition.dart';
import '../theme/app_theme.dart';
import '../theme/food_images.dart';
import '../services/audio_service.dart';

/// Màn hình 7 trong bản thiết kế: thêm món ăn vào nhật ký.
///
/// Có ô tìm kiếm, các nhóm món ăn và danh sách món chỉ gồm chữ (không ảnh).
/// Bấm vào một món hoặc dấu + để mở màn hình chi tiết, chọn khẩu phần rồi bỏ
/// vào giỏ. Thanh giỏ ở cuối màn hình hiện số món và tổng kcal; bấm "Tiếp
/// tục" để ghi tất cả vào bữa đã chọn.
class AddFoodScreen extends StatefulWidget {
  /// Buổi ăn mặc định khi thêm món.
  final MealSlot initialSlot;

  const AddFoodScreen({super.key, this.initialSlot = MealSlot.breakfast});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final TextEditingController _searchController = TextEditingController();

  FoodCategory? _selectedCategory;
  MealSlot _selectedSlot = MealSlot.breakfast;

  /// `false`: ăn theo món (danh mục). `true`: ăn theo định lượng (gram).
  bool _byGrams = false;
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.initialSlot;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Quay lại',
        ),
        title: const Text(
          'Thêm món ăn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListenableBuilder(
        listenable: app.nutrition,
        builder: (context, _) {
          final foods = app.nutrition.search(
            keyword: _searchController.text,
            category: _selectedCategory,
          );

          final ingredients = app.nutrition.searchIngredients(
            keyword: _searchController.text,
            group: _selectedGroup,
          );

          final cartCount = app.nutrition.cartCount;

          return Column(
            children: [
              _buildModeToggle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _byGrams ? 'Tìm nguyên liệu...' : 'Tìm món ăn...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: ()  {
              AudioService().playTap();

                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 19),
                            tooltip: 'Xóa tìm kiếm',
                          ),
                  ),
                ),
              ),
              _byGrams ? _buildGroupChips() : _buildCategoryChips(),
              const SizedBox(height: 6),
              _buildSlotSelector(),
              const SizedBox(height: 8),
              Expanded(
                child: _byGrams
                    ? (ingredients.isEmpty
                        ? const _NoResult()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                            itemCount: ingredients.length,
                            itemBuilder: (context, index) {
                              final ing = ingredients[index];
                              return _IngredientTile(
                                ingredient: ing,
                                onTap: () => _openGramSheet(ing),
                              );
                            },
                          ))
                    : foods.isEmpty
                    ? const _NoResult()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                        itemCount: foods.length,
                        itemBuilder: (context, index) {
                          final food = foods[index];
                          return _FoodListTile(
                            food: food,
                            // Dấu + cũng mở trang chi tiết để chọn khẩu phần.
                            onTap: () => _openDetail(food),
                            onAdd: () => _openDetail(food),
                          );
                        },
                      ),
              ),
              if (cartCount > 0)
                _CartBar(
                  count: cartCount,
                  calories: app.nutrition.cartCalories,
                  onOpen: () => _openCart(app.nutrition),
                  onContinue: () => _commitCart(app.nutrition, _selectedSlot),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Công tắc 2 cách ăn: theo món (có sẵn) / theo định lượng (gram).
  Widget _buildModeToggle() {
    Widget seg(String label, bool value) {
      final selected = _byGrams == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _byGrams = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            seg('Theo món ăn', false),
            seg('Theo định lượng (g)', true),
          ],
        ),
      ),
    );
  }

  /// Chip nhóm nguyên liệu (Tinh bột, Đạm, Rau củ...).
  Widget _buildGroupChips() {
    final groups = <String>[];
    for (final i in AppScope.of(context).nutrition.ingredients) {
      if (!groups.contains(i.group)) groups.add(i.group);
    }
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _CategoryChip(
            label: 'Tất cả',
            isSelected: _selectedGroup == null,
            onTap: () => setState(() => _selectedGroup = null),
          ),
          for (final g in groups)
            _CategoryChip(
              label: g,
              isSelected: _selectedGroup == g,
              onTap: () => setState(() => _selectedGroup = g),
            ),
        ],
      ),
    );
  }

  /// Nhập số gram của một nguyên liệu rồi bỏ vào giỏ.
  Future<void> _openGramSheet(Ingredient ingredient) async {
    final nutrition = AppScope.of(context, listen: false).nutrition;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GramSheet(
        ingredient: ingredient,
        onAdd: (grams) => nutrition.addIngredientToCart(ingredient, grams),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _CategoryChip(
            label: 'Tất cả',
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          for (final category in FoodCategory.values)
            _CategoryChip(
              label: category.label,
              isSelected: _selectedCategory == category,
              onTap: () => setState(() => _selectedCategory = category),
            ),
        ],
      ),
    );
  }

  /// Chọn món sẽ được thêm vào bữu nào.
  Widget _buildSlotSelector() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 8),
            child: Text(
              'Thêm vào:',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ),
          for (final slot in MealSlot.values)
            GestureDetector(
              onTap: () => setState(() => _selectedSlot = slot),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedSlot == slot
                      ? AppTheme.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedSlot == slot
                        ? AppTheme.primary
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  slot.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _selectedSlot == slot
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Mở trang chi tiết; khi người dùng bỏ món vào giỏ, trang trả về bữa đã chọn.
  Future<void> _openDetail(FoodItem food) async {
    final slot = await Navigator.of(context).push<MealSlot>(
      MaterialPageRoute<MealSlot>(
        builder: (_) => FoodDetailScreen(food: food, initialSlot: _selectedSlot),
      ),
    );
    if (slot != null && mounted) setState(() => _selectedSlot = slot);
  }

  /// Mở giỏ để chỉnh số phần; bấm "Tiếp tục" trong giỏ sẽ ghi vào bữa.
  Future<void> _openCart(NutritionRepository nutrition) async {
    final picked = await showModalBottomSheet<MealSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(nutrition: nutrition, initialSlot: _selectedSlot),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedSlot = picked);
    await _commitCart(nutrition, picked);
  }

  /// "Tiếp tục": ghi mọi món trong giỏ vào [slot] rồi quay về màn hình trước.
  Future<void> _commitCart(NutritionRepository nutrition, MealSlot slot) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null || nutrition.cartCount == 0) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final count = nutrition.cartCount;
    final calories = nutrition.cartCalories;
    final water = NutritionRepository.waterOf(nutrition.cart);

    await nutrition.commitCart(
      userId: user.id,
      slot: slot,
      calorieGoal: user.dailyCalorieGoal,
    );

    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Đã thêm $count món vào ${slot.label.toLowerCase()} · $calories kcal'
            '${water > 0 ? ' · +$water ml nước' : ''}',
          ),
        ),
      );
  }
}

/// Chip chọn nhóm món ăn.
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Một dòng món ăn trong danh sách: chỉ có chữ, không ảnh.
class _FoodListTile extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _FoodListTile({
    required this.food,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${food.calories} kcal / ${food.servingLabel}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    color: AppTheme.primary,
                    size: 27,
                  ),
                  tooltip: 'Chọn ${food.name}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh giỏ ở cuối màn hình (kiểu Shopee): biểu tượng giỏ kèm số món, tổng
/// kcal và nút "Tiếp tục". Chỉ có chữ và biểu tượng, không ảnh món.
class _CartBar extends StatelessWidget {
  final int count;
  final int calories;
  final VoidCallback onOpen;
  final VoidCallback onContinue;

  const _CartBar({
    required this.count,
    required this.calories,
    required this.onOpen,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.softShadow(opacity: 0.08, blur: 16),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Badge(
                      label: Text('$count'),
                      backgroundColor: AppTheme.danger,
                      child: const Icon(
                        Icons.shopping_basket_rounded,
                        color: AppTheme.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$calories kcal',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Text(
                            'Bấm để xem giỏ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
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
          const SizedBox(width: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Tiếp tục',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Giỏ món (dạng sheet): chỉ chữ, chỉnh số phần, chọn bữa và bấm "Tiếp tục".
class _CartSheet extends StatefulWidget {
  final NutritionRepository nutrition;
  final MealSlot initialSlot;

  const _CartSheet({required this.nutrition, required this.initialSlot});

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  late MealSlot _slot = widget.initialSlot;

  static double _down(double p) => p > 1 ? p - 1 : p - 0.5;
  static double _up(double p) => p >= 1 ? p + 1 : p + 0.5;

  static String _portionText(double p) {
    final n = p % 1 == 0 ? '${p.toInt()}' : p.toStringAsFixed(1).replaceAll('.', ',');
    return '$n phần';
  }

  /// Nguyên liệu hiện số gram; món thường hiện số phần.
  static String _amountText(PortionedFood item) => isIngredientFoodId(item.food.id)
      ? '${gramsOfPortion(item.portion)}g'
      : _portionText(item.portion);

  /// Nguyên liệu tăng/giảm 50 g mỗi lần bấm.
  static double _stepDown(PortionedFood item) => isIngredientFoodId(item.food.id)
      ? item.portion - 0.5
      : _down(item.portion);
  static double _stepUp(PortionedFood item) => isIngredientFoodId(item.food.id)
      ? item.portion + 0.5
      : _up(item.portion);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ListenableBuilder(
      listenable: widget.nutrition,
      builder: (context, _) {
        final cart = widget.nutrition.cart;
        final water = NutritionRepository.waterOf(cart);

        return Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Giỏ món (${cart.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (cart.isNotEmpty)
                      TextButton(
                        onPressed: widget.nutrition.clearCart,
                        child: const Text('Xóa hết'),
                      ),
                  ],
                ),
                if (cart.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Giỏ đang trống. Bấm + cạnh món để thêm.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in cart)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.food.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.calories} kcal · ${_amountText(item)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    widget.nutrition.setCartPortion(
                                  item.food.id,
                                  _stepDown(item),
                                ),
                                icon: Icon(
                                  item.portion <= 0.5
                                      ? Icons.delete_outline_rounded
                                      : Icons.remove_circle_outline_rounded,
                                  color: item.portion <= 0.5
                                      ? AppTheme.danger
                                      : null,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    widget.nutrition.setCartPortion(
                                  item.food.id,
                                  _stepUp(item),
                                ),
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (water > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Đồ uống trong giỏ sẽ cộng $water ml vào nước uống.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.blue,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SlotPicker(
                  selected: _slot,
                  onChanged: (slot) => setState(() => _slot = slot),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: cart.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_slot),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Tiếp tục · ${_slot.label}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Màn hình 8 trong bản thiết kế: chi tiết món ăn.
///
/// Cho chọn khẩu phần và số lượng, rồi bỏ món vào giỏ của màn hình trước
/// (bấm "Tiếp tục" ở đó mới ghi vào nhật ký). Ảnh bìa là ảnh của chính món.
class FoodDetailScreen extends StatefulWidget {
  final FoodItem food;
  final MealSlot initialSlot;

  const FoodDetailScreen({
    super.key,
    required this.food,
    this.initialSlot = MealSlot.breakfast,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late MealSlot _slot = widget.initialSlot;

  /// Khẩu phần đang chọn: 1 phần hoặc 1/2 phần.
  double _portion = 1;

  /// Số lượng phần ăn.
  int _quantity = 1;

  /// Tổng khẩu phần = khẩu phần × số lượng.
  double get _totalPortion => _portion * _quantity;

  /// "1 phần (460g)" đã có sẵn số 1 ở đầu thì giữ nguyên, tránh hiện "1 1 phần".
  static final RegExp _leadingOne = RegExp(r'^1\s');

  static String _fullLabel(String serving) =>
      _leadingOne.hasMatch(serving) ? serving : '1 phần ($serving)';

  static String _halfLabel(String serving) => _leadingOne.hasMatch(serving)
      ? '1/2 ${serving.substring(2)}'
      : '1/2 phần ($serving)';

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final calories = (food.calories * _totalPortion).round();
    final protein = food.protein * _totalPortion;
    final carbs = food.carbs * _totalPortion;
    final fat = food.fat * _totalPortion;
    final waterMl = (drinkMlOf(food) * _totalPortion).round();

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHero(context, food),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                food.name,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$calories kcal',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${food.servingLabel}'
                                  '${_quantity > 1 ? ' × $_quantity' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _MacroBox(
                                label: 'Protein',
                                value: '${protein.toStringAsFixed(0)}g',
                                color: AppTheme.primary,
                                background: AppTheme.lightGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MacroBox(
                                label: 'Carbs',
                                value: '${carbs.toStringAsFixed(0)}g',
                                color: AppTheme.orange,
                                background: AppTheme.lightOrange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MacroBox(
                                label: 'Fat',
                                value: '${fat.toStringAsFixed(0)}g',
                                color: AppTheme.pink,
                                background: AppTheme.lightPink,
                              ),
                            ),
                          ],
                        ),
                        if (waterMl > 0) ...[
                          const SizedBox(height: 12),
                          _WaterNote(ml: waterMl),
                        ],
                        const SizedBox(height: 22),
                        const Text(
                          'Điều chỉnh khẩu phần',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PortionOption(
                          label: _fullLabel(food.servingLabel),
                          isSelected: _portion == 1,
                          onTap: () => setState(() => _portion = 1),
                        ),
                        const SizedBox(height: 8),
                        _PortionOption(
                          label: _halfLabel(food.servingLabel),
                          isSelected: _portion == 0.5,
                          onTap: () => setState(() => _portion = 0.5),
                        ),
                        const SizedBox(height: 8),
                        _QuantityRow(
                          quantity: _quantity,
                          onDecrease: _quantity > 1
                              ? () => setState(() => _quantity -= 1)
                              : null,
                          onIncrease: _quantity < 10
                              ? () => setState(() => _quantity += 1)
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _SlotPicker(
                          selected: _slot,
                          onChanged: (slot) => setState(() => _slot = slot),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomBar(context, calories),
          ],
        ),
      ),
    );
  }

  /// Ảnh bìa ở đầu trang: chính là ảnh minh họa của món (theo nhóm món), không
  /// dùng một ảnh chung cho mọi món. Thiếu ảnh thì hiện biểu tượng trên nền xanh.
  Widget _buildHero(BuildContext context, FoodItem food) {
    return Stack(
      children: [
        FoodThumb(
          food: food,
          size: 210,
          width: double.infinity,
          radius: 0,
          cacheWidth: 1080,
          background: const Color(0xFF7FC79C),
          fallback: const Icon(
            Icons.ramen_dining_rounded,
            size: 96,
            color: Colors.white24,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                  tooltip: 'Quay lại',
                ),
                const Spacer(),
                _CircleIconButton(
                  icon: Icons.favorite_border_rounded,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Danh sách món yêu thích sẽ có ở bản sau.'),
                    ),
                  ),
                  tooltip: 'Yêu thích',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, int calories) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.softShadow(opacity: 0.07, blur: 16),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _addToCart,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Thêm vào ${_slot.label.toLowerCase()}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  /// Bỏ món vào giỏ rồi quay lại danh sách, trả về bữa đã chọn.
  void _addToCart() {
    AppScope.of(context).nutrition.addToCart(
          widget.food,
          portion: _totalPortion,
        );
    Navigator.of(context).pop(_slot);
  }
}

/// Nút tròn mờ trên nền ảnh.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

/// Ghi chú: đồ uống này sẽ được cộng vào mục "Nước uống" của ngày.
class _WaterNote extends StatelessWidget {
  final int ml;

  const _WaterNote({required this.ml});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop_rounded, size: 16, color: AppTheme.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cộng $ml ml vào nước uống hôm nay',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô số liệu nhóm chất trong màn hình chi tiết.
class _MacroBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _MacroBox({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một lựa chọn khẩu phần.
class _PortionOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PortionOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : Colors.black.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
            color: isSelected ? AppTheme.lightGreen : Colors.white,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 21,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 11),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng chọn số lượng phần ăn.
class _QuantityRow extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _QuantityRow({
    required this.quantity,
    this.onDecrease,
    this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Số lượng',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _RoundButton(
            icon: Icons.remove_rounded,
            onTap: onDecrease,
            tooltip: 'Giảm số lượng',
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _RoundButton(
            icon: Icons.add_rounded,
            onTap: onIncrease,
            tooltip: 'Tăng số lượng',
          ),
        ],
      ),
    );
  }
}

/// Nút tròn nhỏ dùng cho bộ tăng/giảm số lượng.
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled ? AppTheme.lightGreen : AppTheme.background,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Chọn buổi ăn sẽ thêm món vào.
class _SlotPicker extends StatelessWidget {
  final MealSlot selected;
  final ValueChanged<MealSlot> onChanged;

  const _SlotPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thêm vào bữa',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in MealSlot.values)
              GestureDetector(
                onTap: () => onChanged(slot),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected == slot ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected == slot
                          ? AppTheme.primary
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    slot.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected == slot
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Trạng thái không tìm thấy món nào.
class _NoResult extends StatelessWidget {
  const _NoResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 46, color: AppTheme.textSecondary),
            SizedBox(height: 14),
            Text(
              'Không tìm thấy món ăn phù hợp.\nHãy thử từ khóa hoặc nhóm khác.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Một dòng nguyên liệu trong chế độ "Theo định lượng".
class _IngredientTile extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback onTap;

  const _IngredientTile({required this.ingredient, required this.onTap});

  static String _n(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ingredient.calories.round()} kcal / 100g · '
                        'Đạm ${_n(ingredient.protein)} · '
                        'Carb ${_n(ingredient.carbs)} · '
                        'Béo ${_n(ingredient.fat)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onTap,
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    color: AppTheme.primary,
                    size: 27,
                  ),
                  tooltip: 'Nhập số gram ${ingredient.name}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bảng nhập số gram: gõ trực tiếp hoặc chọn nhanh, kcal và macro tính ngay.
class _GramSheet extends StatefulWidget {
  final Ingredient ingredient;
  final int initialGrams;
  final void Function(int grams) onAdd;

  const _GramSheet({
    required this.ingredient,
    required this.onAdd,
    this.initialGrams = 100,
  });

  @override
  State<_GramSheet> createState() => _GramSheetState();
}

class _GramSheetState extends State<_GramSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initialGrams}');

  static const _quick = [50, 100, 150, 200, 300];

  int get _grams => int.tryParse(_controller.text.trim()) ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(int grams) {
    _controller.text = '$grams';
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  static String _n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final ing = widget.ingredient;
    final g = _grams;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              const SizedBox(height: 14),
              Text(
                ing.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ing.calories.round()} kcal / 100g',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Khối lượng',
                  suffixText: 'g',
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final q in _quick)
                    ActionChip(
                      label: Text('${q}g'),
                      onPressed: () => _set(q),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ing.caloriesFor(g)} kcal',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đạm ${_n(ing.proteinFor(g))}g · '
                      'Carb ${_n(ing.carbsFor(g))}g · '
                      'Béo ${_n(ing.fatFor(g))}g',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: g <= 0
                      ? null
                      : () {
                          widget.onAdd(g);
                          Navigator.of(context).pop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    g <= 0 ? 'Nhập số gram' : 'Thêm vào giỏ · ${g}g',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
