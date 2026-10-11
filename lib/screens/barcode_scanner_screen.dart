import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, HapticFeedback;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/nutrition.dart';
import '../services/open_food_facts_service.dart';
import '../theme/app_theme.dart';

/// Quét mã vạch bao bì rồi tra Open Food Facts để ghi nhanh vào nhật ký.
///
/// Cần mạng (để tra sản phẩm) và quyền camera. Máy không có camera hoặc bị từ
/// chối quyền thì vẫn nhập tay được dãy số dưới mã vạch.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final OpenFoodFactsService _service = OpenFoodFactsService();

  bool _busy = false;
  bool _torch = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim();
      // Chỉ nhận mã vạch dạng số (EAN/UPC); bỏ qua mã QR chứa đường dẫn...
      if (raw != null && RegExp(r'^\d{6,14}$').hasMatch(raw)) {
        _lookup(raw);
        return;
      }
    }
  }

  Future<void> _lookup(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    HapticFeedback.mediumImpact();
    try {
      await _controller.stop();
    } catch (_) {}

    BarcodeProduct? product;
    String? error;
    try {
      product = await _service.lookup(code);
      if (product == null) {
        error = 'Chưa có sản phẩm mã $code trong Open Food Facts '
            'hoặc thiếu thông tin calo.';
      }
    } on OpenFoodFactsException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Có lỗi khi tra mã vạch. Vui lòng thử lại.';
    }
    if (!mounted) return;

    if (product != null) {
      final added = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ProductSheet(
          product: product!,
          nutrition: widget.nutrition,
        ),
      );
      if (!mounted) return;
      if (added == true) {
        Navigator.of(context).pop();
        return;
      }
    }

    setState(() {
      _busy = false;
      _message = error;
    });
    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập mã vạch'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'Dãy số dưới mã vạch (vd. 8934563138165)',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Tra cứu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;
    await _lookup(code.trim());
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Thiết bị này không bật được đèn pin.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Quét mã vạch',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Đèn pin',
            onPressed: _toggleTorch,
            icon: Icon(
              _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(
              onManual: _enterManually,
            ),
          ),
          // Khung ngắm.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 170,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  if (_message != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  const Text(
                    'Đưa mã vạch vào khung để tự nhận diện',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _enterManually,
                    icon: const Icon(Icons.keyboard_rounded, size: 18),
                    label: const Text('Nhập mã bằng tay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.onManual});

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Không mở được camera.\nHãy cấp quyền camera cho HealthFlow trong '
            'cài đặt, hoặc nhập mã bằng tay.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.35),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onManual,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Nhập mã bằng tay'),
          ),
        ],
      ),
    );
  }
}

/// Thông tin sản phẩm vừa quét + chọn bữa/khẩu phần rồi ghi vào nhật ký.
class _ProductSheet extends StatefulWidget {
  const _ProductSheet({required this.product, required this.nutrition});

  final BarcodeProduct product;
  final NutritionRepository nutrition;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  static const _portions = [0.5, 1.0, 1.5, 2.0];

  late MealSlot _slot = _defaultSlot();
  double _portion = 1;
  bool _saving = false;

  MealSlot _defaultSlot() {
    final h = DateTime.now().hour;
    if (h < 10) return MealSlot.breakfast;
    if (h < 14) return MealSlot.lunch;
    if (h < 17) return MealSlot.snack;
    return MealSlot.dinner;
  }

  String _g(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  }

  String _portionLabel(double p) => p == 0.5
      ? '1/2'
      : p == 1.5
          ? '1,5'
          : p.toStringAsFixed(0);

  Future<void> _add() async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final food = widget.product.toFoodItem();
    await widget.nutrition.addFood(
      userId: user.id,
      food: food,
      slot: _slot,
      portion: _portion,
      calorieGoal: widget.nutrition.summary.calorieGoal,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Đã thêm ${food.name} vào ${_slot.label.toLowerCase()}.',
          ),
        ),
      );
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.product.toFoodItem();
    final kcal = (food.calories * _portion).round();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
              Text(
                food.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '1 phần = ${widget.product.servingGrams.round()} g · '
                'Mã ${widget.product.code}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$kcal kcal',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đạm ${_g(food.protein * _portion)} g · '
                      'Carb ${_g(food.carbs * _portion)} g · '
                      'Béo ${_g(food.fat * _portion)} g',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    Text(
                      'Xơ ${_g(food.fiber * _portion)} g · '
                      'Đường ${_g(food.sugar * _portion)} g · '
                      'Natri ${(food.sodium * _portion).round()} mg',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Khẩu phần',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in _portions)
                    ChoiceChip(
                      label: Text(_portionLabel(p)),
                      selected: _portion == p,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _portion = p),
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _portion == p ? Colors.white : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Bữa',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in MealSlot.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _slot == s,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _slot = s),
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _slot == s ? Colors.white : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _add,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Thêm vào nhật ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
