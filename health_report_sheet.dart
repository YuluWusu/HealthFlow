import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../services/health_report_pdf.dart';
import '../theme/app_theme.dart';
import '../utils/health_report.dart';

/// Mở bảng chọn tháng để xuất báo cáo PDF gửi bác sĩ.
Future<void> showHealthReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _HealthReportSheet(),
  );
}

class _HealthReportSheet extends StatefulWidget {
  const _HealthReportSheet();

  @override
  State<_HealthReportSheet> createState() => _HealthReportSheetState();
}

class _HealthReportSheetState extends State<_HealthReportSheet> {
  late DateTime _month;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  MonthlyHealthReport? _buildReport() {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return null;
    return MonthlyHealthReport.build(
      metrics: AppScope.of(context).health.metrics,
      patient: ReportPatient.fromUser(user),
      year: _month.year,
      month: _month.month,
      generatedAt: DateTime.now(),
    );
  }

  Future<void> _export() async {
    final report = _buildReport();
    if (report == null || !report.hasData) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await HealthReportPdf.buildWithAssetFonts(report);
      final mm = _month.month.toString().padLeft(2, '0');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'bao-cao-suc-khoe-${_month.year}-$mm.pdf',
      );
      if (mounted) navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Không tạo được báo cáo. Vui lòng thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _buildReport();
    final count = report?.totalReadings ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Báo cáo cho bác sĩ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tóm tắt thấp nhất, trung bình, cao nhất, xu hướng và cảnh báo '
              'của một tháng, xuất thành tệp PDF.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Tháng trước',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _busy ? null : () => _shiftMonth(-1),
                ),
                Text(
                  'Tháng ${_month.month}/${_month.year}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  tooltip: 'Tháng sau',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _busy || _isCurrentMonth ? null : () => _shiftMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                count == 0
                    ? 'Tháng này chưa có lần ghi nào để xuất.'
                    : 'Có $count lần ghi trong tháng này.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_busy || count == 0) ? null : _export,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_busy ? 'Đang tạo báo cáo...' : 'Xuất PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
