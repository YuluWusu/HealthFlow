import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/nutrition.dart';
import '../theme/app_theme.dart';
import '../theme/food_images.dart';

/// Màn hình 7 trong bản thiết kế: thêm món ăn vào nhật ký.
///
/// Có ô tìm kiếm, các nhóm món ăn và danh sách món kèm nút thêm nhanh.
/// Bấm vào một món để mở màn hình chi tiết và chọn khẩu phần.
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm món ăn...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 19),
                            tooltip: 'Xóa tìm kiếm',
                          ),
                  ),
                ),
              ),
              _buildCategoryChips(),
              const SizedBox(height: 6),
              _buildSlotSelector(),
              const SizedBox(height: 8),
              Expanded(
                child: foods.isEmpty
                    ? const _NoResult()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                        itemCount: foods.length,
                        itemBuilder: (context, index) {
                          final food = foods[index];
                          return _FoodListTile(
                            food: food,
                            onTap: () => _openDetail(app.nutrition, food),
                            onAdd: () => _addFood(app.nutrition, food, 1),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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

  Future<void> _openDetail(NutritionRepository nutrition, FoodItem food) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodDetailScreen(food: food, initialSlot: _selectedSlot),
      ),
    );
  }

  Future<void> _addFood(
    NutritionRepository nutrition,
    FoodItem food,
    double portion,
  ) async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);

    await nutrition.addFood(
      userId: user.id,
      food: food,
      slot: _selectedSlot,
      calorieGoal: user.dailyCalorieGoal,
      portion: portion,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${food.name} vào ${_selectedSlot.label.toLowerCase()}.'),
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

/// Một dòng món ăn trong danh sách.
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FoodThumb(
                  food: food,
                  size: 50,
                  radius: 14,
                  background: _backgroundFor(food.category),
                  fallback: Icon(
                    _iconFor(food.category),
                    color: _colorFor(food.category),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
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
                  tooltip: 'Thêm ${food.name}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(FoodCategory category) {
    switch (category) {
      case FoodCategory.vietnamese:
        return Icons.ramen_dining_rounded;
      case FoodCategory.asian:
        return Icons.dinner_dining_rounded;
      case FoodCategory.drink:
        return Icons.local_cafe_rounded;
      case FoodCategory.other:
        return Icons.bakery_dining_rounded;
    }
  }

  static Color _colorFor(FoodCategory category) {
    switch (category) {
      case FoodCategory.vietnamese:
        return AppTheme.primary;
      case FoodCategory.asian:
        return AppTheme.blue;
      case FoodCategory.drink:
        return AppTheme.orange;
      case FoodCategory.other:
        return AppTheme.purple;
    }
  }

  static Color _backgroundFor(FoodCategory category) {
    switch (category) {
      case FoodCategory.vietnamese:
        return AppTheme.lightGreen;
      case FoodCategory.asian:
        return AppTheme.lightBlue;
      case FoodCategory.drink:
        return AppTheme.lightOrange;
      case FoodCategory.other:
        return AppTheme.lightPurple;
    }
  }
}

/// Màn hình 8 trong bản thiết kế: chi tiết món ăn.
///
/// Cho chọn khẩu phần và số lượng trước khi thêm vào nhật ký.
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

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final calories = (food.calories * _totalPortion).round();
    final protein = food.protein * _totalPortion;
    final carbs = food.carbs * _totalPortion;
    final fat = food.fat * _totalPortion;

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
                          label: '1 ${food.servingLabel}',
                          isSelected: _portion == 1,
                          onTap: () => setState(() => _portion = 1),
                        ),
                        const SizedBox(height: 8),
                        _PortionOption(
                          label: '1/2 ${food.servingLabel}',
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

  /// Phần ảnh minh họa món ăn ở đầu trang.
  ///
  /// Chưa có ảnh thật nên dùng khối màu chuyển sắc kèm biểu tượng; khi bổ sung
  /// ảnh chỉ cần thay phần này bằng `Image.asset`.
  Widget _buildHero(BuildContext context, FoodItem food) {
    return Stack(
      children: [
        Container(
          height: 210,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E9E6B), Color(0xFF7FC79C)],
            ),
          ),
          child: Image.asset(
            'assets/images/hero_food.png',
            fit: BoxFit.cover,
            cacheWidth: 1080,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.ramen_dining_rounded,
                size: 96,
                color: Colors.white24,
              ),
            ),
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
          onPressed: () => _addToDiary(calories),
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

  Future<void> _addToDiary(int calories) async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final app = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await app.nutrition.addFood(
      userId: user.id,
      food: widget.food,
      slot: _slot,
      calorieGoal: user.dailyCalorieGoal,
      portion: _totalPortion,
    );

    if (!mounted) return;
    navigator.pop();

    final portionText =
        _quantity > 1 ? '$_quantity × ${widget.food.servingLabel}' : '1 phần';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Đã thêm ${widget.food.name} ($portionText) · $calories kcal',
        ),
      ),
    );
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
