import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/nutrition_repository.dart';
import '../models/nutrition.dart';
import '../theme/app_theme.dart';

/// Bảng ghi chú và ảnh chụp cho một dòng nhật ký (vd. "ăn ở nhà bạn").
Future<void> showEntryNoteSheet(
  BuildContext context,
  NutritionRepository nutrition,
  MealEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EntryNoteSheet(nutrition: nutrition, entry: entry),
  );
}

/// Xem ảnh bữa ăn phóng to.
void showMealPhoto(BuildContext context, String path) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'Không mở được ảnh.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

class EntryNoteSheet extends StatefulWidget {
  const EntryNoteSheet({
    super.key,
    required this.nutrition,
    required this.entry,
  });

  final NutritionRepository nutrition;
  final MealEntry entry;

  @override
  State<EntryNoteSheet> createState() => _EntryNoteSheetState();
}

class _EntryNoteSheetState extends State<EntryNoteSheet> {
  static const _folder = 'meal_photos';

  late final TextEditingController _note =
      TextEditingController(text: widget.entry.note ?? '');
  late String? _photo = widget.entry.photoPath;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked != null && mounted) setState(() => _photo = picked.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được camera/thư viện ảnh. Hãy kiểm tra quyền truy cập.'),
        ),
      );
    }
  }

  /// Chép ảnh vào thư mục riêng của app (ảnh tạm của image_picker có thể bị hệ
  /// thống dọn mất).
  Future<String> _persist(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest =
        '${dir.path}/${widget.entry.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(sourcePath).copy(dest);
    return dest;
  }

  Future<void> _deleteIfOurs(String? path) async {
    if (path == null || !path.contains('/$_folder/')) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final old = widget.entry.photoPath;
    String? photo = _photo;
    try {
      if (photo != null && photo != old) photo = await _persist(photo);
    } catch (_) {
      photo = old; // chép ảnh lỗi thì giữ ảnh cũ, vẫn lưu ghi chú
    }
    await widget.nutrition.updateEntryNote(
      widget.entry,
      note: _note.text,
      photoPath: photo,
    );
    if (old != photo) await _deleteIfOurs(old);
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Ghi chú · ${widget.entry.foodName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: ăn ở nhà bạn, ít cơm, thêm trứng...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_photo != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_photo!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: const Color(0xFFF1F4F2),
                          alignment: Alignment.center,
                          child: const Text('Không mở được ảnh'),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: 'Xóa ảnh',
                          onPressed: () => setState(() => _photo = null),
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Chụp ảnh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Thư viện'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
