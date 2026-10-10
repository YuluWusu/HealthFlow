import 'package:flutter/material.dart';

import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../services/nutrition_report_service.dart';
import '../theme/app_theme.dart';

/// Bảng chọn khoảng thời gian rồi xuất báo cáo dinh dưỡng ra PDF hoặc CSV để
/// chia sẻ (gửi cho bác sĩ, huấn luyện viên, lưu vào Drive...).
Future<void> showReportExportSheet(
  BuildContext context,
  NutritionRepository nutrition,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReportExportSheet(nutrition: nutrition),
  );
}

enum _Range {
  last7('7 ngày gần nhất'),
  thisWeek('Tuần này'),
  last30('30 ngày gần nhất'),
  thisMonth('Tháng này');

  const _Range(this.label);
  final String label;

  /// Khoảng ngày (gồm cả hai đầu) tính đến hôm nay.
  (DateTime, DateTime) span(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case _Range.last7:
        return (today.subtract(const Duration(days: 6)), today);
      case _Range.thisWeek:
        // Tuần bắt đầu từ thứ Hai.
        return (today.subtract(Duration(days: today.weekday - 1)), today);
      case _Range.last30:
        return (today.subtract(const Duration(days: 29)), today);
      case _Range.thisMonth:
        return (DateTime(today.year, today.month, 1), today);
    }
  }
}

class ReportExportSheet extends StatefulWidget {
  const ReportExportSheet({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<ReportExportSheet> createState() => _ReportExportSheetState();
}

class _ReportExportSheetState extends State<ReportExportSheet> {
  _Range _range = _Range.last7;
  bool _busy = false;
  String? _busyLabel;

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

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

  Future<void> _export({required bool pdf}) async {
    if (_busy) return;
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() {
      _busy = true;
      _busyLabel = pdf ? 'PDF' : 'CSV';
    });
    try {
      final (from, to) = _range.span(DateTime.now());
      final entries =
          await widget.nutrition.entriesInRange(user.id, from, to);
      final days = NutritionReportService.groupByDay(entries, from, to);
      if (entries.isEmpty) {
        if (mounted) {
          _toast('Chưa có món nào trong khoảng ${_d(from)} – ${_d(to)}.');
        }
        return;
      }

      final service = NutritionReportService();
      final goal = widget.nutrition.calorieGoal;
      final file = pdf
          ? await service.writePdf(
              days: days,
              calorieGoal: goal,
              userName: user.fullName,
            )
          : await service.writeCsv(days: days, calorieGoal: goal);
      await service.share(file);
    } catch (e) {
      if (mounted) _toast('Không xuất được báo cáo. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (from, to) = _range.span(DateTime.now());
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
                'Xuất báo cáo dinh dưỡng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tổng hợp calo, macro, chất xơ, đường, natri và chi tiết từng món.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _Range.values)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: _range == r,
                      showCheckmark: false,
                      onSelected:
                          _busy ? null : (_) => setState(() => _range = r),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            _range == r ? Colors.white : AppTheme.textPrimary,
                      ),
                      selectedColor: AppTheme.primary,
                      backgroundColor: const Color(0xFFF1F4F2),
                      side: BorderSide.none,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Từ ${_d(from)} đến ${_d(to)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _export(pdf: true),
                      icon: _busyLabel == 'PDF'
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Xuất PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _export(pdf: false),
                      icon: _busyLabel == 'CSV'
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.table_chart_outlined, size: 18),
                      label: const Text('Xuất CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
