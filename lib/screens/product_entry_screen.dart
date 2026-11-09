import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../services/open_food_facts_service.dart';
import '../theme/app_theme.dart';
import '../utils/nutrition_label_parser.dart';

/// Nhập sản phẩm chưa có trong Open Food Facts: gõ tay hoặc chụp bảng "Giá trị
/// dinh dưỡng" để ML Kit (chạy trên máy) đọc rồi điền sẵn. Trả về sản phẩm
/// (đã quy về 100 g) hoặc null nếu hủy.
class ProductEntryScreen extends StatefulWidget {
  const ProductEntryScreen({super.key, required this.code});

  final String code;

  @override
  State<ProductEntryScreen> createState() => _ProductEntryScreenState();
}

class _ProductEntryScreenState extends State<ProductEntryScreen> {
  final _name = TextEditingController();
  final _serving = TextEditingController(text: '100');
  final _f = {
    for (final k in ['kcal', 'protein', 'carbs', 'fat', 'sugar', 'fiber', 'sodium'])
      k: TextEditingController(),
  };
  bool _per100 = true;
  bool _reading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _serving.dispose();
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _scan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000);
    if (picked == null || !mounted) return;
    setState(() => _reading = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text =
          (await recognizer.processImage(InputImage.fromFilePath(picked.path)))
              .text;
      final v = parseNutritionLabel(text);
      void put(String k, double? x) {
        if (x != null) _f[k]!.text = x.toStringAsFixed(x == x.roundToDouble() ? 0 : 1);
      }
      put('kcal', v.kcal);
      put('protein', v.protein);
      put('carbs', v.carbs);
      put('fat', v.fat);
      put('sugar', v.sugar);
      put('fiber', v.fiber);
      put('sodium', v.sodiumMg);
      _error = v.found == 0
          ? 'Không đọc được số nào. Thử chụp rõ, thẳng và đủ sáng hơn.'
          : 'Đọc được ${v.found}/7 mục. Hãy kiểm tra lại, nhất là chọn đúng '
              '"trên 100 g" hay "trên khẩu phần" như bảng ghi.';
    } catch (_) {
      _error = 'Không đọc được ảnh. Bạn có thể nhập tay.';
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _reading = false);
    }
  }

  void _save() {
    final serving = _v(_serving);
    final kcal = _v(_f['kcal']!);
    if (_name.text.trim().isEmpty || kcal <= 0 || serving <= 0) {
      setState(() => _error = 'Cần tên sản phẩm, calo và khối lượng lớn hơn 0.');
      return;
    }
    // Mọi số lưu theo 100 g; nhập theo khẩu phần thì quy đổi.
    final k = _per100 ? 1.0 : 100 / serving;
    double n(String key) => _v(_f[key]!) * k;
    Navigator.of(context).pop(BarcodeProduct(
      code: widget.code,
      name: _name.text.trim(),
      brand: '',
      servingGrams: serving,
      kcalPer100: kcal * k,
      proteinPer100: n('protein'),
      carbsPer100: n('carbs'),
      fatPer100: n('fat'),
      fiberPer100: n('fiber'),
      sugarPer100: n('sugar'),
      sodiumMgPer100: n('sodium'),
    ));
  }

  Widget _field(String label, TextEditingController c, {String? suffix}) =>
      TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: label, suffixText: suffix, isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final unit = _per100 ? '/100 g' : '/khẩu phần';
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm sản phẩm mới')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Mã ${widget.code} chưa có dữ liệu. Nhập một lần, lần sau quét là ra ngay.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
              onPressed: _reading ? null : () => _scan(ImageSource.camera),
              icon: const Icon(Icons.document_scanner_rounded, size: 18),
              label: const Text('Chụp bảng dinh dưỡng'),
            ),
            OutlinedButton.icon(
              onPressed: _reading ? null : () => _scan(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Chọn ảnh'),
            ),
          ]),
          if (_reading) const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên sản phẩm', isDense: true),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Trên 100 g')),
              ButtonSegment(value: false, label: Text('Trên khẩu phần')),
            ],
            selected: {_per100},
            onSelectionChanged: (s) => setState(() => _per100 = s.first),
          ),
          const SizedBox(height: 12),
          _field('Khối lượng 1 khẩu phần', _serving, suffix: 'g'),
          const SizedBox(height: 12),
          _field('Năng lượng $unit', _f['kcal']!, suffix: 'kcal'),
          const SizedBox(height: 12),
          _field('Chất đạm $unit', _f['protein']!, suffix: 'g'),
          const SizedBox(height: 12),
          _field('Carbohydrate $unit', _f['carbs']!, suffix: 'g'),
          const SizedBox(height: 12),
          _field('Chất béo $unit', _f['fat']!, suffix: 'g'),
          const SizedBox(height: 12),
          _field('Đường $unit', _f['sugar']!, suffix: 'g'),
          const SizedBox(height: 12),
          _field('Chất xơ $unit', _f['fiber']!, suffix: 'g'),
          const SizedBox(height: 12),
          _field('Natri $unit', _f['sodium']!, suffix: 'mg'),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Lưu sản phẩm')),
        ],
      ),
    );
  }
}
