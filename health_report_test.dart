import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/services/health_report_pdf.dart';
import 'package:healthcare/utils/health_report.dart';

const _patient = ReportPatient(
  name: 'Nguyễn Minh Anh',
  gender: 'female',
  heightCm: 170,
  healthGoal: 'Giảm cân',
  targetWeightKg: 55,
);

int _seq = 0;

HealthMetric _m(
  HealthMetricType type,
  double value,
  int day, {
  double? secondary,
  int month = 10,
  int year = 2026,
  String note = '',
}) {
  return HealthMetric(
    id: 'm${_seq++}',
    userId: 'u1',
    type: type,
    value: value,
    valueSecondary: secondary,
    recordedAt: DateTime(year, month, day, 8),
    note: note,
  );
}

MonthlyHealthReport _report(
  List<HealthMetric> metrics, {
  ReportPatient patient = _patient,
  int month = 10,
}) {
  return MonthlyHealthReport.build(
    metrics: metrics,
    patient: patient,
    year: 2026,
    month: month,
    generatedAt: DateTime(2026, 10, 31, 20, 30),
  );
}

MetricSummary _summary(MonthlyHealthReport r, HealthMetricType t) =>
    r.summaries.firstWhere((s) => s.type == t);

void main() {
  group('Thống kê min / trung bình / max', () {
    final report = _report([
      _m(HealthMetricType.weight, 60.0, 1),
      _m(HealthMetricType.weight, 59.6, 8),
      _m(HealthMetricType.weight, 59.2, 15),
      _m(HealthMetricType.weight, 58.8, 22),
      _m(HealthMetricType.bloodPressure, 118, 3, secondary: 76),
      _m(HealthMetricType.bloodPressure, 124, 10, secondary: 78),
      _m(HealthMetricType.bloodPressure, 136, 17, secondary: 86),
      _m(HealthMetricType.bloodPressure, 142, 24, secondary: 92),
      _m(HealthMetricType.heartRate, 72, 5),
    ]);

    test('cân nặng: số lần, thấp nhất, trung bình, cao nhất', () {
      final w = _summary(report, HealthMetricType.weight);
      expect(w.count, 4);
      expect(w.minText, '58.8');
      expect(w.avgText, '59.4');
      expect(w.maxText, '60.0');
    });

    test('huyết áp: tâm thu và tâm trương tính riêng', () {
      final bp = _summary(report, HealthMetricType.bloodPressure);
      expect(bp.minText, '118/76');
      expect(bp.avgText, '130/83');
      expect(bp.maxText, '142/92');
    });

    test('chỉ một lần ghi: min = trung bình = max', () {
      final hr = _summary(report, HealthMetricType.heartRate);
      expect(hr.count, 1);
      expect(hr.minText, '72');
      expect(hr.avgText, '72');
      expect(hr.maxText, '72');
    });

    test('loại không có dữ liệu được liệt kê riêng', () {
      expect(report.missingTypes, [
        HealthMetricType.bloodGlucose,
        HealthMetricType.sleep,
        HealthMetricType.steps,
      ]);
      expect(report.summaries.map((s) => s.type), [
        HealthMetricType.weight,
        HealthMetricType.bloodPressure,
        HealthMetricType.heartRate,
      ]);
    });
  });

  group('Xu hướng', () {
    test('cân nặng giảm: so nửa đầu với nửa sau của tháng', () {
      final r = _report([
        _m(HealthMetricType.weight, 60.0, 1),
        _m(HealthMetricType.weight, 59.6, 8),
        _m(HealthMetricType.weight, 59.2, 15),
        _m(HealthMetricType.weight, 58.8, 22),
      ]);
      final w = _summary(r, HealthMetricType.weight);
      expect(w.trend, ReportTrend.down);
      expect(w.change, closeTo(-0.8, 1e-9));
      expect(w.trendText, 'Giảm 0.8 kg');
    });

    test('huyết áp tăng: ghi rõ là tâm thu', () {
      final r = _report([
        _m(HealthMetricType.bloodPressure, 118, 3, secondary: 76),
        _m(HealthMetricType.bloodPressure, 124, 10, secondary: 78),
        _m(HealthMetricType.bloodPressure, 136, 17, secondary: 86),
        _m(HealthMetricType.bloodPressure, 142, 24, secondary: 92),
      ]);
      final bp = _summary(r, HealthMetricType.bloodPressure);
      expect(bp.trend, ReportTrend.up);
      expect(bp.trendText, 'Tâm thu tăng 18 mmHg');
    });

    test('thay đổi nhỏ hơn ngưỡng: ổn định', () {
      final r = _report([
        _m(HealthMetricType.heartRate, 70, 2),
        _m(HealthMetricType.heartRate, 72, 20),
      ]);
      final hr = _summary(r, HealthMetricType.heartRate);
      expect(hr.trend, ReportTrend.stable);
      expect(hr.trendText, 'Ổn định');
    });

    test('số bước chân dùng ngưỡng riêng (1000 bước)', () {
      final r = _report([
        _m(HealthMetricType.steps, 5000, 2),
        _m(HealthMetricType.steps, 8000, 20),
      ]);
      final s = _summary(r, HealthMetricType.steps);
      expect(s.trend, ReportTrend.up);
      expect(s.trendText, 'Tăng 3000 bước');
    });

    test('một lần ghi: chưa đủ dữ liệu', () {
      final r = _report([_m(HealthMetricType.heartRate, 72, 5)]);
      final hr = _summary(r, HealthMetricType.heartRate);
      expect(hr.trend, ReportTrend.notEnoughData);
      expect(hr.change, isNull);
      expect(hr.trendText, 'Chưa đủ dữ liệu');
    });
  });

  group('Lọc dữ liệu theo tháng', () {
    test('bỏ qua tháng khác và BMI tự suy ra', () {
      final r = _report([
        _m(HealthMetricType.weight, 70, 15, month: 9),
        _m(HealthMetricType.weight, 60, 15),
        _m(HealthMetricType.weight, 50, 15, month: 11),
        _m(HealthMetricType.bmi, 20.8, 15),
      ]);
      expect(r.totalReadings, 1);
      expect(_summary(r, HealthMetricType.weight).count, 1);
      expect(r.latestWeightKg, 60);
    });

    test('tháng không có dữ liệu', () {
      final r = _report([_m(HealthMetricType.weight, 60, 15, month: 9)]);
      expect(r.hasData, isFalse);
      expect(r.summaries, isEmpty);
      expect(r.missingTypes, hasLength(MonthlyHealthReport.reportedTypes.length));
      expect(r.alerts, isEmpty);
      expect(r.bmi, isNull);
    });

    test('danh sách lần ghi xếp từ cũ đến mới và giữ ghi chú', () {
      final r = _report([
        _m(HealthMetricType.heartRate, 80, 20, note: 'Sau khi chạy'),
        _m(HealthMetricType.weight, 60, 3),
      ]);
      expect(r.readings.map((m) => m.recordedAt.day), [3, 20]);
      expect(r.readings.last.note, 'Sau khi chạy');
    });

    test('tiêu đề kỳ báo cáo', () {
      expect(_report([]).periodText, 'Tháng 10/2026');
    });
  });

  group('Cảnh báo', () {
    test('huyết áp ngoài ngưỡng: đếm số lần và nêu lần gần nhất', () {
      final r = _report([
        _m(HealthMetricType.bloodPressure, 118, 3, secondary: 76),
        _m(HealthMetricType.bloodPressure, 124, 10, secondary: 78),
        _m(HealthMetricType.bloodPressure, 136, 17, secondary: 86),
        _m(HealthMetricType.bloodPressure, 142, 24, secondary: 92),
      ]);
      final bp = _summary(r, HealthMetricType.bloodPressure);
      expect(bp.flaggedCount, 3);
      expect(bp.alertCount, 2);
      expect(bp.latestText, '142/92 mmHg (Tăng huyết áp độ 2)');

      expect(r.alerts, hasLength(1));
      expect(r.alerts.single.title, 'Huyết áp');
      expect(r.alerts.single.isSevere, isTrue);
      expect(
        r.alerts.single.message,
        '3/4 lần đo ngoài ngưỡng bình thường. '
        'Gần nhất: 142/92 mmHg (Tăng huyết áp độ 2, 24/10).',
      );
    });

    test('mọi chỉ số bình thường: không có cảnh báo', () {
      final r = _report([
        _m(HealthMetricType.bloodPressure, 112, 3, secondary: 72),
        _m(HealthMetricType.heartRate, 70, 3),
        _m(HealthMetricType.weight, 60, 3),
      ]);
      expect(r.alerts, isEmpty);
    });

    test('BMI béo phì được đưa vào cảnh báo mức nặng', () {
      final r = _report(
        [_m(HealthMetricType.weight, 70, 10)],
        patient: const ReportPatient(
          name: 'A',
          gender: 'male',
          heightCm: 160,
        ),
      );
      expect(r.bmi, closeTo(27.34, 0.01));
      final bmi = r.alerts.singleWhere((a) => a.title == 'Chỉ số BMI');
      expect(bmi.isSevere, isTrue);
      expect(bmi.message, contains('BMI 27.3 (Béo phì)'));
    });

    test('cân nặng tăng nhanh dùng lại ngưỡng của HealthAnalyzer', () {
      final r = _report([
        _m(HealthMetricType.weight, 70, 1),
        _m(HealthMetricType.weight, 72, 8),
      ]);
      final trend = r.alerts.singleWhere((a) => a.title == 'Xu hướng cân nặng');
      expect(trend.message, 'Cân nặng TĂNG NHANH (+2.0 kg / 7 ngày)');
      expect(trend.isSevere, isFalse);
    });

    test('đường huyết tăng dần qua 3 lần đo', () {
      final r = _report([
        _m(HealthMetricType.bloodGlucose, 90, 2),
        _m(HealthMetricType.bloodGlucose, 96, 9),
        _m(HealthMetricType.bloodGlucose, 103, 16),
      ]);
      final trend =
          r.alerts.singleWhere((a) => a.title == 'Xu hướng đường huyết');
      expect(trend.message, contains('+13 mg/dL qua 3 lần đo'));
    });

    test('cảnh báo mức nặng xếp trước cảnh báo lưu ý', () {
      final r = _report([
        _m(HealthMetricType.weight, 70, 1),
        _m(HealthMetricType.weight, 72, 8), // xu hướng tăng nhanh: lưu ý
        _m(HealthMetricType.bloodPressure, 150, 9, secondary: 95), // nặng
      ]);
      expect(r.alerts.first.title, 'Huyết áp');
      expect(r.alerts.first.isSevere, isTrue);
      expect(r.alerts.last.isSevere, isFalse);
    });
  });

  group('Thông tin người bệnh', () {
    test('giới tính hiển thị tiếng Việt', () {
      expect(_patient.genderText, 'Nữ');
      expect(
        const ReportPatient(name: 'B', gender: 'male', heightCm: 170).genderText,
        'Nam',
      );
    });

    test('BMI và cân nặng lấy theo lần cân gần nhất trong tháng', () {
      final r = _report([
        _m(HealthMetricType.weight, 58.8, 22),
        _m(HealthMetricType.weight, 60.0, 1),
      ]);
      expect(r.latestWeightKg, 58.8);
      expect(r.bmi, closeTo(58.8 / (1.7 * 1.7), 1e-9));
      expect(r.bmiStatus!.label, 'Bình thường');
    });
  });

  group('Tạo PDF', () {
    late ByteData regular;
    late ByteData bold;

    setUpAll(() {
      ByteData load(String path) {
        final bytes = File(path).readAsBytesSync();
        return ByteData.sublistView(Uint8List.fromList(bytes));
      }

      regular = load(HealthReportPdf.regularFontAsset);
      bold = load(HealthReportPdf.boldFontAsset);
    });

    bool isPdf(Uint8List bytes) =>
        bytes.length > 4 &&
        String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';

    test('báo cáo đầy đủ ra tệp PDF hợp lệ (có tiếng Việt)', () async {
      final r = _report([
        _m(HealthMetricType.weight, 60.0, 1, note: 'Sáng sớm, trước ăn'),
        _m(HealthMetricType.weight, 58.8, 22),
        _m(HealthMetricType.bloodPressure, 142, 24, secondary: 92),
        _m(HealthMetricType.bloodGlucose, 90, 2),
        _m(HealthMetricType.bloodGlucose, 96, 9),
        _m(HealthMetricType.bloodGlucose, 103, 16),
      ]);
      final bytes =
          await HealthReportPdf.build(r, regularFont: regular, boldFont: bold);
      expect(isPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(5000));
    });

    test('tháng không có dữ liệu vẫn tạo được PDF', () async {
      final bytes = await HealthReportPdf.build(
        _report([]),
        regularFont: regular,
        boldFont: bold,
      );
      expect(isPdf(bytes), isTrue);
    });

    test('rất nhiều lần ghi tự chia sang nhiều trang', () async {
      final many = <HealthMetric>[
        for (var i = 0; i < 300; i++)
          _m(HealthMetricType.heartRate, 60 + (i % 30).toDouble(), 1 + i % 28),
      ];
      final bytes = await HealthReportPdf.build(
        _report(many),
        regularFont: regular,
        boldFont: bold,
      );
      expect(isPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(20000));
    });
  });
}
