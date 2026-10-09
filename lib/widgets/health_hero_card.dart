import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/health_assessor.dart';

/// Một chỉ số được đánh giá, dùng để vẽ một phân đoạn của vòng hero.
class HealthHeroItem {
  const HealthHeroItem(this.label, this.level);

  final String label;
  final HealthLevel level;
}

/// Màu của từng mức độ, chọn bản sáng để nổi trên nền ảnh tối.
Color heroLevelColor(HealthLevel level) {
  switch (level) {
    case HealthLevel.normal:
      return const Color(0xFF5BE3A0);
    case HealthLevel.caution:
      return AppTheme.orange;
    case HealthLevel.alert:
      return const Color(0xFFFF7A7A);
    case HealthLevel.unknown:
      return Colors.white24;
  }
}

/// Thẻ kính mờ đầu tab Tổng quan: vòng phân đoạn (mỗi chỉ số một đoạn, tô
/// theo mức độ) kèm câu tóm tắt ngắn.
///
/// Đây KHÔNG phải điểm sức khỏe: chỉ đếm số chỉ số đang ở mức bình thường
/// trên tổng số chỉ số đã có dữ liệu, theo đúng kết quả của [HealthAssessor].
class HealthHeroCard extends StatelessWidget {
  const HealthHeroCard({super.key, required this.items});

  final List<HealthHeroItem> items;

  int _count(HealthLevel level) =>
      items.where((item) => item.level == level).length;

  String _names(HealthLevel level) => items
      .where((item) => item.level == level)
      .map((item) => item.label)
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final normal = _count(HealthLevel.normal);
    final caution = _count(HealthLevel.caution);
    final alert = _count(HealthLevel.alert);
    final unknown = _count(HealthLevel.unknown);
    final measured = items.length - unknown;

    final String headline;
    final String detail;
    if (measured == 0) {
      headline = 'Chưa có dữ liệu';
      detail = 'Hãy thêm chỉ số đầu tiên để bắt đầu theo dõi.';
    } else if (alert > 0) {
      headline = 'Có chỉ số cần chú ý';
      detail = '${_names(HealthLevel.alert)}. Nếu kéo dài, hãy hỏi bác sĩ.';
    } else if (caution > 0) {
      headline = 'Có chỉ số cần để ý';
      detail = '${_names(HealthLevel.caution)} đang lệch nhẹ khỏi mức bình thường.';
    } else {
      headline = 'Các chỉ số đang ổn';
      detail = unknown > 0
          ? 'Hãy đo thêm $unknown chỉ số còn lại để theo dõi đầy đủ.'
          : 'Tiếp tục duy trì và đo đều đặn nhé.';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => CustomPaint(
                        size: const Size(112, 112),
                        painter: _SegmentRingPainter(
                          levels: [for (final item in items) item.level],
                          t: t,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          measured == 0 ? '--' : '$normal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          measured == 0 ? 'chỉ số' : 'trên $measured',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TÌNH TRẠNG HÔM NAY',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (normal > 0)
                          _LegendDot(HealthLevel.normal, 'Ổn', normal),
                        if (caution > 0)
                          _LegendDot(HealthLevel.caution, 'Lưu ý', caution),
                        if (alert > 0)
                          _LegendDot(HealthLevel.alert, 'Cảnh báo', alert),
                        if (unknown > 0)
                          _LegendDot(HealthLevel.unknown, 'Chưa đo', unknown),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.level, this.label, this.count);

  final HealthLevel level;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: level == HealthLevel.unknown
                ? Colors.white54
                : heroLevelColor(level),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $count',
          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
        ),
      ],
    );
  }
}

/// Vòng chia đều theo số chỉ số. Mỗi đoạn tô theo mức độ của chỉ số tương
/// ứng và lần lượt chạy ra khi [t] đi từ 0 đến 1.
class _SegmentRingPainter extends CustomPainter {
  _SegmentRingPainter({required this.levels, required this.t});

  final List<HealthLevel> levels;
  final double t;

  static const double _stroke = 11;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final arcRect = (Offset.zero & size).deflate(_stroke / 2);
    final radius = arcRect.width / 2;
    final n = levels.length;
    final slot = 2 * math.pi / n;

    // Đầu bo tròn kéo dài thêm stroke/2 mỗi phía, nên thu đoạn vẽ lại để vẫn
    // còn một khe hở nhìn thấy được giữa hai đoạn.
    final pad = n == 1 ? 0.0 : (_stroke / 2) / radius + 0.07;
    final sweep = math.max(0.05, slot - 2 * pad);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.14);
    final bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * slot + pad;
      canvas.drawArc(arcRect, start, sweep, false, track);

      final level = levels[i];
      if (level == HealthLevel.unknown) continue;
      final local = (t * n - i).clamp(0.0, 1.0).toDouble();
      if (local <= 0) continue;
      bar.color = heroLevelColor(level);
      canvas.drawArc(arcRect, start, sweep * local, false, bar);
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentRingPainter old) =>
      old.t != t || !_sameLevels(old.levels, levels);

  static bool _sameLevels(List<HealthLevel> a, List<HealthLevel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}