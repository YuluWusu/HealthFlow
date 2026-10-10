import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/nutrition.dart';

/// Số liệu một ngày trong báo cáo.
class ReportDay {
  ReportDay(this.day);

  final DateTime day;
  final List<MealEntry> entries = [];

  int get calories => entries.fold(0, (s, e) => s + e.calories);
  double get protein => entries.fold(0.0, (s, e) => s + e.protein);
  double get carbs => entries.fold(0.0, (s, e) => s + e.carbs);
  double get fat => entries.fold(0.0, (s, e) => s + e.fat);
  double get fiber => entries.fold(0.0, (s, e) => s + e.fiber);
  double get sugar => entries.fold(0.0, (s, e) => s + e.sugar);
  double get sodium => entries.fold(0.0, (s, e) => s + e.sodium);
}

/// Dựng và chia sẻ báo cáo dinh dưỡng tuần/tháng dưới dạng PDF hoặc CSV.
class NutritionReportService {
  NutritionReportService._();

  static final NutritionReportService instance = NutritionReportService._();

  factory NutritionReportService() => instance;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _t(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _fileStamp(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static String _n1(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  }

  /// Gom các dòng theo ngày; ngày không có món vẫn xuất hiện (calo 0).
  static List<ReportDay> groupByDay(
    List<MealEntry> entries,
    DateTime from,
    DateTime to,
  ) {
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    final days = <DateTime, ReportDay>{};
    for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      days[d] = ReportDay(d);
    }
    for (final e in entries) {
      days[_dateOnly(e.eatenAt)]?.entries.add(e);
    }
    return days.values.toList();
  }

  // ---------------------------------------------------------------- CSV

  static String _csvCell(Object? v) {
    final s = '${v ?? ''}';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String buildCsv({
    required List<ReportDay> days,
    required int calorieGoal,
  }) {
    final b = StringBuffer();
    void row(List<Object?> cells) => b.writeln(cells.map(_csvCell).join(','));

    row([
      'Ngày', 'Giờ', 'Bữa', 'Món', 'Khẩu phần', 'Calo (kcal)', 'Đạm (g)',
      'Carb (g)', 'Béo (g)', 'Chất xơ (g)', 'Đường (g)', 'Natri (mg)', 'Ghi chú',
    ]);
    for (final day in days) {
      for (final e in day.entries) {
        row([
          _d(e.eatenAt), _t(e.eatenAt), e.slot.label, e.foodName, e.portionLabel,
          e.calories, _n1(e.protein), _n1(e.carbs), _n1(e.fat), _n1(e.fiber),
          _n1(e.sugar), e.sodium.round(), e.note ?? '',
        ]);
      }
    }

    b.writeln();
    row(['TỔNG HỢP THEO NGÀY']);
    row([
      'Ngày', 'Calo (kcal)', 'Mục tiêu (kcal)', 'Đạm (g)', 'Carb (g)',
      'Béo (g)', 'Chất xơ (g)', 'Đường (g)', 'Natri (mg)',
    ]);
    for (final day in days) {
      row([
        _d(day.day), day.calories, calorieGoal, _n1(day.protein),
        _n1(day.carbs), _n1(day.fat), _n1(day.fiber), _n1(day.sugar),
        day.sodium.round(),
      ]);
    }
    return b.toString();
  }

  Future<File> writeCsv({
    required List<ReportDay> days,
    required int calorieGoal,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/HealthFlow_dinh_duong_${_fileStamp(days.first.day)}_${_fileStamp(days.last.day)}.csv',
    );
    // BOM giúp Excel đọc đúng tiếng Việt có dấu.
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(buildCsv(days: days, calorieGoal: calorieGoal))]);
    return file;
  }

  // ---------------------------------------------------------------- PDF

  Future<File> writePdf({
    required List<ReportDay> days,
    required int calorieGoal,
    required String userName,
  }) async {
    // Font mặc định của gói pdf không có chữ Việt, nên nhúng font của app.
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/BeVietnamPro_400Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/BeVietnamPro_700Bold.ttf'),
    );

    const green = PdfColor.fromInt(0xFF23865B);
    const grey = PdfColor.fromInt(0xFF77847C);
    const light = PdfColor.fromInt(0xFFE5F3EA);

    final logged = days.where((d) => d.entries.isNotEmpty).toList();
    final n = logged.length;
    double avg(double Function(ReportDay) pick) =>
        n == 0 ? 0 : logged.fold(0.0, (s, d) => s + pick(d)) / n;
    final avgKcal = n == 0 ? 0 : (logged.fold(0, (s, d) => s + d.calories) / n).round();
    final goalDays = logged.where((d) {
      final r = calorieGoal <= 0 ? 0.0 : d.calories / calorieGoal;
      return r >= 0.9 && r <= 1.1;
    }).length;
    final maxKcal = days.fold<int>(calorieGoal, (m, d) => d.calories > m ? d.calories : m);

    pw.Widget cell(String text, {bool head = false, pw.Alignment? align}) {
      return pw.Container(
        alignment: align ?? pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    final dayRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: light),
        children: [
          for (final h in ['Ngày', 'Calo', 'Đạm g', 'Carb g', 'Béo g', 'Xơ g', 'Đường g', 'Natri mg'])
            cell(h, head: true),
        ],
      ),
      for (final d in days)
        pw.TableRow(children: [
          cell(_d(d.day)),
          cell('${d.calories}', align: pw.Alignment.centerRight),
          cell(_n1(d.protein), align: pw.Alignment.centerRight),
          cell(_n1(d.carbs), align: pw.Alignment.centerRight),
          cell(_n1(d.fat), align: pw.Alignment.centerRight),
          cell(_n1(d.fiber), align: pw.Alignment.centerRight),
          cell(_n1(d.sugar), align: pw.Alignment.centerRight),
          cell('${d.sodium.round()}', align: pw.Alignment.centerRight),
        ]),
    ];

    pw.Widget stat(String label, String value) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: light,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: green)),
                pw.SizedBox(height: 2),
                pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: grey)),
              ],
            ),
          ),
        );

    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'HealthFlow · trang ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: grey),
          ),
        ),
        build: (ctx) => [
          pw.Text('Báo cáo dinh dưỡng',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: green)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${userName.isEmpty ? '' : '$userName · '}${_d(days.first.day)} – ${_d(days.last.day)}',
            style: const pw.TextStyle(fontSize: 11, color: grey),
          ),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            stat('Calo trung bình/ngày', '$avgKcal kcal'),
            stat('Mục tiêu', '$calorieGoal kcal'),
            stat('Ngày có ghi', '$n/${days.length}'),
            stat('Ngày đạt mục tiêu', '$goalDays'),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            stat('Đạm TB', '${_n1(avg((d) => d.protein))} g'),
            stat('Carb TB', '${_n1(avg((d) => d.carbs))} g'),
            stat('Béo TB', '${_n1(avg((d) => d.fat))} g'),
            stat('Xơ / Đường / Natri TB',
                '${_n1(avg((d) => d.fiber))} g · ${_n1(avg((d) => d.sugar))} g · ${avg((d) => d.sodium).round()} mg'),
          ]),
          pw.SizedBox(height: 16),
          pw.Text('Calo theo ngày',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (final d in days)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(children: [
                pw.SizedBox(
                  width: 52,
                  child: pw.Text(_d(d.day).substring(0, 5), style: const pw.TextStyle(fontSize: 8, color: grey)),
                ),
                pw.Container(
                  width: maxKcal <= 0 ? 0 : 330 * d.calories / maxKcal,
                  height: 7,
                  color: d.calories > calorieGoal * 1.1 ? PdfColors.orange : green,
                ),
                pw.SizedBox(width: 6),
                pw.Text('${d.calories}', style: const pw.TextStyle(fontSize: 8)),
              ]),
            ),
          pw.SizedBox(height: 4),
          pw.Text('Thanh cam: vượt quá 110% mục tiêu.',
              style: const pw.TextStyle(fontSize: 7.5, color: grey)),
          pw.SizedBox(height: 16),
          pw.Text('Tổng hợp theo ngày',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            children: dayRows,
          ),
          pw.SizedBox(height: 16),
          pw.Text('Chi tiết món ăn',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (final d in days.where((d) => d.entries.isNotEmpty)) ...[
            pw.Text('${_d(d.day)} · ${d.calories} kcal',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: green)),
            pw.SizedBox(height: 2),
            for (final e in d.entries)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, bottom: 1.5),
                child: pw.Text(
                  '${_t(e.eatenAt)}  ${e.slot.label}: ${e.foodName} (${e.portionLabel}) — ${e.calories} kcal'
                  '${e.hasNote ? '  · ${e.note}' : ''}',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
            pw.SizedBox(height: 6),
          ],
          pw.SizedBox(height: 8),
          pw.Text(
            'Đường và natri của món Việt/nguyên liệu là số ước tính từ thành phần, chỉ mang tính tham khảo.',
            style: const pw.TextStyle(fontSize: 7.5, color: grey),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/HealthFlow_dinh_duong_${_fileStamp(days.first.day)}_${_fileStamp(days.last.day)}.pdf',
    );
    await file.writeAsBytes(await doc.save());
    return file;
  }

  /// Mở bảng chia sẻ của hệ điều hành cho [file].
  Future<void> share(File file, {String? subject}) async {
    final isPdf = file.path.toLowerCase().endsWith('.pdf');
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: isPdf ? 'application/pdf' : 'text/csv'),
        ],
        subject: subject ?? 'Báo cáo dinh dưỡng HealthFlow',
      ),
    );
  }
}
