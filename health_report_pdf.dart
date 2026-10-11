import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/health_metric.dart';
import '../utils/health_assessor.dart';
import '../utils/health_report.dart';

/// Vẽ [MonthlyHealthReport] thành tệp PDF khổ A4 để gửi hoặc in cho bác sĩ.
///
/// PDF mặc định chỉ có font Latin cơ bản nên không hiện được dấu tiếng Việt;
/// vì vậy phải nhúng font TTF. Dự án đã có sẵn BeVietnamPro trong
/// `assets/fonts`, dùng lại luôn để chữ trong PDF đồng bộ với ứng dụng.
class HealthReportPdf {
  const HealthReportPdf._();

  static const String regularFontAsset =
      'assets/fonts/BeVietnamPro_400Regular.ttf';
  static const String boldFontAsset = 'assets/fonts/BeVietnamPro_700Bold.ttf';

  static const _ink = PdfColor.fromInt(0xFF1F2937);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _line = PdfColor.fromInt(0xFFD1D5DB);
  static const _headerBg = PdfColor.fromInt(0xFFE8F5EE);
  static const _brand = PdfColor.fromInt(0xFF1E8E5A);
  static const _severe = PdfColor.fromInt(0xFFC62828);
  static const _mild = PdfColor.fromInt(0xFFE65100);

  /// Dựng PDF với font lấy từ asset của ứng dụng.
  static Future<Uint8List> buildWithAssetFonts(MonthlyHealthReport report) async {
    final regular = await rootBundle.load(regularFontAsset);
    final bold = await rootBundle.load(boldFontAsset);
    return build(report, regularFont: regular, boldFont: bold);
  }

  /// Dựng PDF với font truyền vào (dùng được cả trong test, không cần asset).
  static Future<Uint8List> build(
    MonthlyHealthReport report, {
    required ByteData regularFont,
    required ByteData boldFont,
  }) async {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularFont),
      bold: pw.Font.ttf(boldFont),
    );

    final doc = pw.Document(
      title: 'Báo cáo sức khỏe ${report.periodText}',
      author: 'HealthFlow',
      theme: theme,
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
          theme: theme,
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Tạo bởi HealthFlow lúc ${_dateTime(report.generatedAt)}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.Text(
                'Trang ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
        build: (context) => [
          _title(report),
          pw.SizedBox(height: 12),
          _patientBlock(report),
          pw.SizedBox(height: 16),
          _sectionTitle('1. Tóm tắt chỉ số trong tháng'),
          _summaryTable(report),
          ..._missingNote(report),
          pw.SizedBox(height: 16),
          _sectionTitle('2. Cảnh báo cần lưu ý'),
          ..._alertBlock(report),
          pw.SizedBox(height: 16),
          _sectionTitle('3. Chi tiết các lần ghi (${report.totalReadings} lần)'),
          _readingsTable(report),
          pw.SizedBox(height: 16),
          _disclaimer(),
        ],
      ),
    );

    return doc.save();
  }

  // ---- Các khối nội dung --------------------------------------------------

  static pw.Widget _title(MonthlyHealthReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BÁO CÁO SỨC KHỎE',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: _brand,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          report.periodText,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
      ],
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _patientBlock(MonthlyHealthReport report) {
    final p = report.patient;
    final weight = report.latestWeightKg;
    final bmi = report.bmi;
    final bmiStatus = report.bmiStatus;

    final goalParts = <String>[
      if (p.healthGoal.trim().isNotEmpty) p.healthGoal.trim(),
      if (p.targetWeightKg != null)
        'cân nặng mong muốn ${p.targetWeightKg!.toStringAsFixed(1)} kg',
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _headerBg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv('Họ và tên', p.name),
          _kv('Giới tính', p.genderText),
          _kv('Chiều cao', '${p.heightCm.toStringAsFixed(0)} cm'),
          if (weight != null)
            _kv('Cân nặng (gần nhất)', '${weight.toStringAsFixed(1)} kg'),
          if (bmi != null)
            _kv(
              'BMI',
              '${bmi.toStringAsFixed(1)}'
                  '${bmiStatus == null ? '' : ' (${bmiStatus.label})'}',
            ),
          if (goalParts.isNotEmpty) _kv('Mục tiêu', goalParts.join(', ')),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = _ink,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _summaryTable(MonthlyHealthReport report) {
    if (report.summaries.isEmpty) {
      return pw.Text(
        'Không có lần ghi nào trong ${report.periodText.toLowerCase()}.',
        style: const pw.TextStyle(fontSize: 10, color: _muted),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _headerBg),
        children: [
          _cell('Chỉ số', bold: true),
          _cell('Số lần', bold: true, align: pw.TextAlign.center),
          _cell('Thấp nhất', bold: true, align: pw.TextAlign.center),
          _cell('Trung bình', bold: true, align: pw.TextAlign.center),
          _cell('Cao nhất', bold: true, align: pw.TextAlign.center),
          _cell('Xu hướng', bold: true),
          _cell('Lần ghi gần nhất', bold: true),
        ],
      ),
      for (final s in report.summaries)
        pw.TableRow(
          children: [
            _cell(_nameWithUnit(s.type), bold: true),
            _cell('${s.count}', align: pw.TextAlign.center),
            _cell(s.minText, align: pw.TextAlign.center),
            _cell(s.avgText, align: pw.TextAlign.center),
            _cell(s.maxText, align: pw.TextAlign.center),
            _cell(s.trendText),
            _cell(
              s.latestText,
              color: _levelColor(s.latestStatus.level),
            ),
          ],
        ),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.1),
            1: pw.FlexColumnWidth(0.8),
            2: pw.FlexColumnWidth(1.1),
            3: pw.FlexColumnWidth(1.2),
            4: pw.FlexColumnWidth(1.1),
            5: pw.FlexColumnWidth(1.9),
            6: pw.FlexColumnWidth(2.6),
          },
          children: rows,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Huyết áp ghi dạng tâm thu/tâm trương, mỗi giá trị được tính riêng. '
          'Xu hướng so trung bình nửa đầu với nửa sau của tháng.',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    );
  }

  static String _nameWithUnit(HealthMetricType type) {
    return type.unit.isEmpty ? type.label : '${type.label} (${type.unit})';
  }

  static List<pw.Widget> _missingNote(MonthlyHealthReport report) {
    if (report.missingTypes.isEmpty) return const [];
    final names = report.missingTypes.map((t) => t.label).join(', ');
    return [
      pw.SizedBox(height: 6),
      pw.Text(
        'Không có dữ liệu trong tháng: $names.',
        style: const pw.TextStyle(fontSize: 9, color: _muted),
      ),
    ];
  }

  static List<pw.Widget> _alertBlock(MonthlyHealthReport report) {
    if (report.alerts.isEmpty) {
      return [
        pw.Text(
          report.hasData
              ? 'Không phát hiện chỉ số nào ngoài ngưỡng bình thường trong tháng.'
              : 'Chưa có dữ liệu để đánh giá.',
          style: const pw.TextStyle(fontSize: 10, color: _ink),
        ),
      ];
    }

    return [
      for (final a in report.alerts)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 6,
                height: 6,
                margin: const pw.EdgeInsets.only(top: 4, right: 8),
                decoration: pw.BoxDecoration(
                  color: a.isSevere ? _severe : _mild,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${a.title}${a.isSevere ? ' - cần chú ý' : ' - lưu ý'}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: a.isSevere ? _severe : _mild,
                      ),
                    ),
                    pw.Text(
                      a.message,
                      style: const pw.TextStyle(fontSize: 9.5, color: _ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  static pw.Widget _readingsTable(MonthlyHealthReport report) {
    if (report.readings.isEmpty) {
      return pw.Text(
        'Không có lần ghi nào.',
        style: const pw.TextStyle(fontSize: 10, color: _muted),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.7),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: [
            _cell('Thời gian', bold: true),
            _cell('Chỉ số', bold: true),
            _cell('Giá trị', bold: true),
            _cell('Ghi chú', bold: true),
          ],
        ),
        for (final m in report.readings)
          pw.TableRow(
            children: [
              _cell(_dateTime(m.recordedAt)),
              _cell(m.type.label),
              _cell(m.displayValue),
              _cell(m.note),
            ],
          ),
      ],
    );
  }

  static pw.Widget _disclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Lưu ý: số liệu do người dùng tự nhập trong ứng dụng nên có thể chưa '
        'đầy đủ hoặc chưa được đo chuẩn. Ngưỡng đánh giá chỉ mang tính tham '
        'khảo (BMI theo chuẩn Châu Á, huyết áp theo AHA/AMA) và không thay thế '
        'chẩn đoán của bác sĩ.',
        style: const pw.TextStyle(fontSize: 8.5, color: _muted),
      ),
    );
  }

  // ---- Tiện ích ------------------------------------------------------------

  static PdfColor _levelColor(HealthLevel level) {
    switch (level) {
      case HealthLevel.alert:
        return _severe;
      case HealthLevel.caution:
        return _mild;
      case HealthLevel.normal:
      case HealthLevel.unknown:
        return _ink;
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _dateTime(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}
