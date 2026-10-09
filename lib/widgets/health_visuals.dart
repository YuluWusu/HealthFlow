import 'dart:math' as math;

import 'package:flutter/material.dart';

// Các hình vẽ nhỏ cho thẻ chỉ số. Tất cả đều là CustomPaint (không cần ảnh) và
// chỉ chạy MỘT lần khi xuất hiện rồi dừng, để không giữ máy luôn phải vẽ lại
// và không làm các bài test dùng pumpAndSettle bị treo.

Paint _stroke(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

/// Đường nét đứt nằm ngang, dùng khi chưa đủ dữ liệu để vẽ.
void _drawPlaceholder(Canvas canvas, Size size, Color color, double y) {
  final paint = _stroke(color.withValues(alpha: 0.35), 1.6);
  for (var x = 4.0; x < size.width - 4; x += 8) {
    canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width - 4), y), paint);
  }
}

bool _sameValues(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Số đếm lên
// ---------------------------------------------------------------------------

/// Hiện một chuỗi số liệu (vd. `56.5 kg`, `120/80 mmHg`) với các con số chạy
/// từ 0 lên giá trị thật một lần khi xuất hiện. Số chữ số thập phân giữ nguyên
/// như chuỗi gốc. Chuỗi không có số (vd. `--`) hiện nguyên.
class AnimatedNumberText extends StatelessWidget {
  const AnimatedNumberText(
    this.text, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  final String text;
  final TextStyle? style;
  final Duration duration;

  static final RegExp _number = RegExp(r'\d+(?:\.\d+)?');

  @override
  Widget build(BuildContext context) {
    final matches = _number.allMatches(text).toList();
    if (matches.isEmpty) return Text(text, style: style);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final out = StringBuffer();
        var last = 0;
        for (final m in matches) {
          out.write(text.substring(last, m.start));
          final raw = m.group(0)!;
          final dot = raw.indexOf('.');
          final decimals = dot < 0 ? 0 : raw.length - dot - 1;
          out.write((double.parse(raw) * t).toStringAsFixed(decimals));
          last = m.end;
        }
        out.write(text.substring(last));
        return Text(out.toString(), style: style);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sparkline: đường xu hướng mini
// ---------------------------------------------------------------------------

/// Đường xu hướng mini của [values] (cũ trước, mới sau), vẽ dần từ trái sang
/// phải kèm vùng tô mờ bên dưới. Dưới 2 giá trị thì hiện nét đứt.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(values: values, color: color, t: t),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.t,
  });

  final List<double> values;
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (values.length < 2) {
      _drawPlaceholder(canvas, size, color, size.height / 2);
      return;
    }

    const padX = 4.0;
    const padY = 5.0;
    final w = size.width - 2 * padX;
    final h = size.height - 2 * padY;

    var minV = values.first;
    var maxV = values.first;
    for (final v in values) {
      minV = math.min(minV, v);
      maxV = math.max(maxV, v);
    }
    final range = maxV - minV;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          padX + w * i / (values.length - 1),
          range == 0
              ? padY + h / 2
              : padY + h * (1 - (values[i] - minV) / range),
        ),
    ];

    // Nối bằng đường cong có tiếp tuyến nằm ngang tại mỗi điểm nên không bao
    // giờ vọt quá giá trị cao nhất/thấp nhất.
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }

    final metric = path.computeMetrics().first;
    final length = metric.length * t;
    final end = metric.getTangentForOffset(length)?.position ?? points.first;
    final partial = metric.extractPath(0, length);

    final fill = Path.from(partial)
      ..lineTo(end.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(partial, _stroke(color, 2));

    canvas.drawCircle(end, 4, Paint()..color = Colors.white);
    canvas.drawCircle(end, 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.t != t || old.color != color || !_sameValues(old.values, values);
}

// ---------------------------------------------------------------------------
// Cột giấc ngủ
// ---------------------------------------------------------------------------

/// 7 cột cho 7 đêm gần nhất, cao theo số giờ ngủ. Đêm ngủ 7 đến 9 giờ tô đậm,
/// các đêm còn lại tô nhạt. Đêm chưa có dữ liệu là một chấm nhỏ.
class SleepBars extends StatelessWidget {
  const SleepBars({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, _) => CustomPaint(
        size: Size.infinite,
        painter: _SleepBarsPainter(values: values, color: color, t: t),
      ),
    );
  }
}

class _SleepBarsPainter extends CustomPainter {
  _SleepBarsPainter({
    required this.values,
    required this.color,
    required this.t,
  });

  final List<double> values;
  final Color color;
  final double t;

  static const int _slots = 7;
  static const double _stagger = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final shown = values.length > _slots
        ? values.sublist(values.length - _slots)
        : values;
    final offset = _slots - shown.length;
    final slotW = size.width / _slots;
    final barW = math.min(slotW * 0.56, 14.0);

    var scale = 10.0;
    for (final v in shown) {
      scale = math.max(scale, v);
    }

    for (var i = 0; i < _slots; i++) {
      final cx = slotW * (i + 0.5);
      if (i < offset) {
        canvas.drawCircle(
          Offset(cx, size.height - 2),
          1.6,
          Paint()..color = color.withValues(alpha: 0.25),
        );
        continue;
      }

      final index = i - offset;
      final v = shown[index];
      final local = ((t - index * _stagger) / (1 - _stagger * (_slots - 1)))
          .clamp(0.0, 1.0)
          .toDouble();
      final eased = Curves.easeOutCubic.transform(local);
      final barH = math.max(4.0, (size.height - 2) * (v / scale)) * eased;

      final good = v >= 7 && v <= 9;
      final paint = Paint()
        ..color = good ? color : color.withValues(alpha: 0.38);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, size.height - barH, barW, barH),
          Radius.circular(barW / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SleepBarsPainter old) =>
      old.t != t || old.color != color || !_sameValues(old.values, values);
}

// ---------------------------------------------------------------------------
// Đường điện tim (ECG)
// ---------------------------------------------------------------------------

/// Đường ECG minh họa cho nhịp tim: số nhịp hiển thị tăng theo [bpm] (2 đến 4
/// nhịp). Đường chạy ra từ trái sang phải một lần, đầu đường có chấm sáng.
///
/// Đây là hình minh họa, không phải điện tâm đồ thật. `bpm == null` thì hiện
/// nét đứt.
class EcgLine extends StatelessWidget {
  const EcgLine({super.key, required this.bpm, required this.color});

  final double? bpm;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      builder: (context, t, _) => CustomPaint(
        size: Size.infinite,
        painter: _EcgPainter(bpm: bpm, color: color, t: t),
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({required this.bpm, required this.color, required this.t});

  final double? bpm;
  final Color color;
  final double t;

  /// Một nhịp: x chạy 0 đến 1, y là biên độ (dương là lên). Lần lượt là sóng
  /// P, phức bộ QRS rồi sóng T.
  static const List<Offset> _beat = [
    Offset(0, 0),
    Offset(0.12, 0),
    Offset(0.17, 0.12),
    Offset(0.22, 0),
    Offset(0.30, 0),
    Offset(0.33, -0.15),
    Offset(0.36, 1.0),
    Offset(0.40, -0.30),
    Offset(0.44, 0),
    Offset(0.55, 0),
    Offset(0.64, 0.25),
    Offset(0.73, 0),
    Offset(1, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final base = size.height * 0.62;
    final rate = bpm;
    if (rate == null || rate <= 0) {
      _drawPlaceholder(canvas, size, color, base);
      return;
    }

    final beats = (rate / 60 * 2).round().clamp(2, 4).toInt();
    final amp = base - 4;

    final path = Path()..moveTo(0, base);
    for (var b = 0; b < beats; b++) {
      for (final p in _beat) {
        path.lineTo((b + p.dx) / beats * size.width, base - p.dy * amp);
      }
    }

    final metric = path.computeMetrics().first;
    final length = metric.length * t;
    final end = metric.getTangentForOffset(length)?.position ?? Offset(0, base);

    canvas.drawPath(metric.extractPath(0, length), _stroke(color, 1.8));
    canvas.drawCircle(end, 7, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawCircle(end, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EcgPainter old) =>
      old.t != t || old.color != color || old.bpm != bpm;
}

// ---------------------------------------------------------------------------
// Trạng thái trống: hình minh họa vector
// ---------------------------------------------------------------------------

/// Hình minh họa cho trạng thái chưa có dữ liệu: vài vòng tròn mờ đồng tâm và
/// một nhịp tim chạy ra một lần. Chỉ dùng nét vẽ, không cần ảnh.
class HealthEmptyArt extends StatelessWidget {
  const HealthEmptyArt({
    super.key,
    this.size = 120,
    this.color = Colors.white,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeInOut,
        builder: (context, t, _) => CustomPaint(
          painter: _EmptyArtPainter(color: color, t: t),
        ),
      ),
    );
  }
}

class _EmptyArtPainter extends CustomPainter {
  _EmptyArtPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.08));
    canvas.drawCircle(
      c,
      r * 0.8,
      _stroke(color.withValues(alpha: 0.18), 1.4),
    );
    canvas.drawCircle(c, r * 0.58, Paint()..color = color.withValues(alpha: 0.12));

    // Nhịp tim ngang qua tâm: phẳng, nhô nhẹ, mũi nhọn, rồi về phẳng.
    const shape = <Offset>[
      Offset(0, 0),
      Offset(0.26, 0),
      Offset(0.34, -0.12),
      Offset(0.42, 0),
      Offset(0.50, 0),
      Offset(0.55, 0.22),
      Offset(0.62, -0.62),
      Offset(0.69, 0.30),
      Offset(0.75, 0),
      Offset(1, 0),
    ];
    final left = c.dx - r * 0.74;
    final width = r * 1.48;
    final path = Path();
    for (var i = 0; i < shape.length; i++) {
      final p = Offset(left + shape[i].dx * width, c.dy + shape[i].dy * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    final metric = path.computeMetrics().first;
    final length = metric.length * t;
    final end = metric.getTangentForOffset(length)?.position ?? Offset(left, c.dy);
    canvas.drawPath(
      metric.extractPath(0, length),
      _stroke(color.withValues(alpha: 0.9), 3),
    );
    canvas.drawCircle(end, 5, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(end, 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EmptyArtPainter old) =>
      old.t != t || old.color != color;
}

// ---------------------------------------------------------------------------
// Skeleton khi đang tải
// ---------------------------------------------------------------------------

/// Khung xương của tab Tổng quan (một thẻ hero và lưới 6 thẻ) với vệt sáng
/// chạy ngang, dùng thay cho vòng xoay khi dữ liệu đang tải. Vệt sáng lặp
/// liên tục nên chỉ nên có mặt trong lúc tải.
class HealthSkeleton extends StatefulWidget {
  const HealthSkeleton({super.key});

  @override
  State<HealthSkeleton> createState() => _HealthSkeletonState();
}

class _HealthSkeletonState extends State<HealthSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box(double t, {double? height, double radius = 18}) {
    final x = -2 + 4 * t;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(x - 1, 0),
          end: Alignment(x + 1, 0),
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.10),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          children: [
            _box(t, height: 144, radius: 24),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [for (var i = 0; i < 6; i++) _box(t)],
            ),
          ],
        );
      },
    );
  }
}