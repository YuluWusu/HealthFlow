import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_metric.dart';

/// Màu neon của từng chỉ số khi hiện cảnh báo.
///
/// Dùng chung enum [HealthMetricType] của model (không khai báo enum thứ hai
/// trùng tên), màu được gắn thêm bằng extension này.
extension AlertMetricColor on HealthMetricType {
  Color get alertColor {
    switch (this) {
      case HealthMetricType.heartRate:
        return const Color(0xFFFF2A55); // Nhịp tim - đỏ neon
      case HealthMetricType.bloodPressure:
        return const Color(0xFFFF6B00); // Huyết áp - cam đỏ
      case HealthMetricType.bloodGlucose:
        return const Color(0xFF9D00FF); // Đường huyết - tím neon
      case HealthMetricType.weight:
      case HealthMetricType.bmi:
        return const Color(0xFF00E5FF); // Cân nặng / BMI - xanh lam
      case HealthMetricType.sleep:
        return const Color(0xFF5B51D8); // Giấc ngủ - tím đêm
      case HealthMetricType.steps:
        return const Color(0xFF00E676); // Vận động - xanh lá
    }
  }

  /// Thời gian một vòng hiệu ứng.
  Duration get alertCycle {
    switch (this) {
      case HealthMetricType.heartRate:
        return const Duration(milliseconds: 1100); // nhanh như nhịp tim
      case HealthMetricType.bloodPressure:
        return const Duration(milliseconds: 2400);
      case HealthMetricType.bloodGlucose:
        return const Duration(milliseconds: 6000);
      case HealthMetricType.weight:
      case HealthMetricType.bmi:
      case HealthMetricType.steps:
        return const Duration(milliseconds: 4000);
      case HealthMetricType.sleep:
        return const Duration(milliseconds: 5000);
    }
  }
}

/// Bọc màn hình Dashboard: khi có chỉ số đang cảnh báo thì nền chuyển sang tối
/// và chạy hiệu ứng riêng của chỉ số đó phía sau nội dung.
///
/// [worstMetric] là chỉ số có mức độ tệ nhất; `null` nghĩa là mọi thứ ổn, nền
/// sáng và không chạy hoạt ảnh.
class AlertBackgroundWrapper extends StatefulWidget {
  final HealthMetricType? worstMetric;
  final Widget child;

  const AlertBackgroundWrapper({
    super.key,
    required this.worstMetric,
    required this.child,
  });

  @override
  State<AlertBackgroundWrapper> createState() => _AlertBackgroundWrapperState();
}

class _AlertBackgroundWrapperState extends State<AlertBackgroundWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AlertBackgroundWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worstMetric != widget.worstMetric) _syncAnimation();
  }

  /// Chỉ chạy hoạt ảnh khi có cảnh báo, để không tốn pin lúc mọi thứ bình
  /// thường.
  void _syncAnimation() {
    final metric = widget.worstMetric;
    if (metric == null) {
      _controller.stop();
      return;
    }
    _controller.duration = metric.alertCycle;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metric = widget.worstMetric;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      // Nền tối khi có cảnh báo, nền sáng khi bình thường.
      color: metric != null ? const Color(0xFF0D0F12) : const Color(0xFFF8F9FA),
      child: Stack(
        children: [
          if (metric != null)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: FiveHealthMetricsPainter(
                          type: metric,
                          progress: _controller.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// Vẽ hiệu ứng nền theo loại chỉ số. [progress] chạy từ 0 đến 1 rồi lặp lại;
/// mọi hiệu ứng đều khớp vòng lặp nên không bị giật khi quay về 0.
class FiveHealthMetricsPainter extends CustomPainter {
  final HealthMetricType type;
  final double progress;

  const FiveHealthMetricsPainter({required this.type, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (type) {
      case HealthMetricType.heartRate:
        _paintHeartbeat(canvas, size);
      case HealthMetricType.bloodPressure:
        _paintPressureWaves(canvas, size);
      case HealthMetricType.bloodGlucose:
        _paintDroplets(canvas, size);
      case HealthMetricType.weight:
      case HealthMetricType.bmi:
      case HealthMetricType.steps:
        _paintScan(canvas, size);
      case HealthMetricType.sleep:
        _paintNightSky(canvas, size);
    }
  }

  Color get _color => type.alertColor;

  // ---- Nhịp tim: quầng sáng đập hai nhịp (thình-thịch) + đường ECG ---------
  void _paintHeartbeat(Canvas canvas, Size size) {
    final beat = _bump(progress, 0.05, 0.07) + 0.6 * _bump(progress, 0.25, 0.07);

    final center = Offset(size.width / 2, size.height * 0.4);
    final radius = size.longestSide * (0.5 + 0.18 * beat);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _color.withValues(alpha: 0.12 + 0.30 * beat),
          _color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);

    // Đường ECG trôi ngang, đỉnh nhọn nằm ở giữa mỗi chu kỳ.
    final baseY = size.height * 0.8;
    final amplitude = size.height * 0.06;
    final path = Path()..moveTo(0, baseY);
    for (double x = 0; x <= size.width; x += 3) {
      final phase = (x / size.width - progress) % 1.0;
      final y = baseY -
          amplitude * _bump(phase, 0.50, 0.012) +
          amplitude * 0.4 * _bump(phase, 0.46, 0.012);
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = _color.withValues(alpha: 0.5),
    );
  }

  // ---- Huyết áp: các vòng sóng áp lực lan ra từ tâm ------------------------
  void _paintPressureWaves(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);
    const rings = 3;
    for (var i = 0; i < rings; i++) {
      final p = (progress + i / rings) % 1.0;
      canvas.drawCircle(
        center,
        p * size.longestSide * 0.9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 6 * (1 - p)
          ..color = _color.withValues(alpha: 0.35 * (1 - p)),
      );
    }
    final core = Paint()
      ..shader = RadialGradient(
        colors: [_color.withValues(alpha: 0.18), _color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: 140));
    canvas.drawCircle(center, 140, core);
  }

  // ---- Đường huyết: giọt nổi lên từ đáy ------------------------------------
  void _paintDroplets(Canvas canvas, Size size) {
    const count = 14;
    for (var i = 0; i < count; i++) {
      final p = (progress + i / count) % 1.0;
      final x = size.width * _hash(i * 12.9898) +
          14 * math.sin(2 * math.pi * (p + i * 0.13));
      final y = size.height * (1 - p);
      final r = 4 + 10 * _hash(i * 78.233);
      final alpha = 0.4 * math.sin(math.pi * p); // mờ dần ở hai đầu

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = _color.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        Offset(x - r * 0.3, y - r * 0.3),
        r * 0.25,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.8),
      );
    }
  }

  // ---- Cân nặng / BMI: lưới mờ và dải quét chạy dọc ------------------------
  void _paintScan(Canvas canvas, Size size) {
    final grid = Paint()
      ..strokeWidth = 1
      ..color = _color.withValues(alpha: 0.07);
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    const bandHeight = 180.0;
    for (var i = 0; i < 2; i++) {
      final y = ((progress + i * 0.5) % 1.0) * (size.height + bandHeight) -
          bandHeight;
      final rect = Rect.fromLTWH(0, y, size.width, bandHeight);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _color.withValues(alpha: 0),
              _color.withValues(alpha: 0.22),
              _color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  // ---- Giấc ngủ: bầu trời đêm, sao lấp lánh, quầng trăng -------------------
  void _paintNightSky(Canvas canvas, Size size) {
    final moon = Offset(size.width * 0.8, size.height * 0.12);
    canvas.drawCircle(
      moon,
      130,
      Paint()
        ..shader = RadialGradient(
          colors: [_color.withValues(alpha: 0.35), _color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: moon, radius: 130)),
    );

    const count = 40;
    for (var i = 0; i < count; i++) {
      final pos = Offset(
        size.width * _hash(i * 12.9898),
        size.height * _hash(i * 78.233),
      );
      // Nhân progress với số nguyên để lấp lánh khớp vòng lặp.
      final twinkle =
          0.5 + 0.5 * math.sin(2 * math.pi * (progress * (1 + i % 3) + i * 0.37));
      canvas.drawCircle(
        pos,
        1 + 1.8 * _hash(i * 39.346),
        Paint()..color = Colors.white.withValues(alpha: 0.15 + 0.6 * twinkle),
      );
    }
  }

  // ---- Tiện ích ------------------------------------------------------------

  /// Đỉnh hình chuông (Gauss) tại [center] với độ rộng [width], trong 0..1.
  static double _bump(double t, double center, double width) {
    final d = (t - center) / width;
    return math.exp(-d * d);
  }

  /// Số giả ngẫu nhiên cố định trong [0, 1) từ [seed], để vị trí không nhảy
  /// giữa các khung hình.
  static double _hash(double seed) {
    final v = math.sin(seed) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant FiveHealthMetricsPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.progress != progress;
  }
}
