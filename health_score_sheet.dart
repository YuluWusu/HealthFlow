import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/health_assessor.dart';
import '../utils/health_score.dart';

/// Mở bảng giải thích điểm sức khỏe: điểm hiện tại, mức tăng giảm so với tuần
/// trước và từng khoản bị trừ.
Future<void> showHealthScoreSheet(
  BuildContext context, {
  required HealthScore score,
  int? weeklyChange,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ScoreSheet(score: score, weeklyChange: weeklyChange),
  );
}

/// Màu mức độ trên nền trắng của bảng (khác bản sáng dùng trên nền ảnh tối).
Color _levelColor(HealthLevel level) {
  switch (level) {
    case HealthLevel.normal:
      return AppTheme.primary;
    case HealthLevel.caution:
      return AppTheme.orange;
    case HealthLevel.alert:
      return AppTheme.danger;
    case HealthLevel.unknown:
      return AppTheme.textSecondary;
  }
}

Color _bandColor(HealthScoreBand band) {
  switch (band) {
    case HealthScoreBand.good:
      return AppTheme.primary;
    case HealthScoreBand.fair:
      return const Color(0xFF6BAA3A);
    case HealthScoreBand.needsWork:
      return AppTheme.orange;
    case HealthScoreBand.attention:
      return AppTheme.danger;
  }
}

class _ScoreSheet extends StatelessWidget {
  const _ScoreSheet({required this.score, required this.weeklyChange});

  final HealthScore score;
  final int? weeklyChange;

  /// Mục bị trừ điểm lên trước, rồi mục không bị trừ, mục chưa đo xuống cuối.
  List<HealthScoreItem> get _ordered {
    final scored = score.items.where((i) => i.measured && i.factor.isClinical);
    final deducted = scored.where((i) => i.deduction > 0).toList()
      ..sort((a, b) => b.deduction.compareTo(a.deduction));
    final fine = scored.where((i) => i.deduction == 0).toList();
    final regularity =
        score.items.where((i) => !i.factor.isClinical).toList();
    final unmeasured =
        score.items.where((i) => !i.measured && i.factor.isClinical).toList();
    return [...deducted, ...fine, ...regularity, ...unmeasured];
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.88),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _Header(score: score, weeklyChange: weeklyChange),
              const SizedBox(height: 22),
              Text(
                score.isReady ? 'Điểm bị trừ vì đâu' : 'Các mục tính điểm',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                score.isReady && score.deductions.isEmpty
                    ? 'Chưa mục nào bị trừ điểm.'
                    : 'Số điểm bị trừ ở mỗi mục, cộng lại ra đúng điểm bên trên.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final item in _ordered) ...[
                _ItemRow(item: item, ready: score.isReady),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              _HowItWorks(score: score),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.score, required this.weeklyChange});

  final HealthScore score;
  final int? weeklyChange;

  @override
  Widget build(BuildContext context) {
    final value = score.value;
    final band = score.band;
    final color = band == null ? AppTheme.textSecondary : _bandColor(band);

    final String title;
    final String subtitle;
    if (value != null) {
      title = band!.label;
      subtitle = 'Tính trên ${score.measuredCount}/5 chỉ số cơ thể có dữ liệu '
          'trong ${HealthScoreCalculator.freshDays} ngày qua.';
    } else {
      title = 'Chưa đủ dữ liệu';
      subtitle = 'Cần ít nhất ${HealthScoreCalculator.minMeasured} chỉ số có '
          'dữ liệu trong ${HealthScoreCalculator.freshDays} ngày qua. '
          'Hiện có ${score.measuredCount}.';
    }

    return Row(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              painter: _ScoreArcPainter(
                fraction: (value ?? 0) / 100 * t,
                color: color,
              ),
              child: Center(
                child: Text(
                  value == null ? '--' : '${(value * t).round()}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ĐIỂM THAM KHẢO',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (weeklyChange != null) ...[
                const SizedBox(height: 4),
                _WeeklyLine(change: weeklyChange!),
              ],
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyLine extends StatelessWidget {
  const _WeeklyLine({required this.change});

  final int change;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    if (change > 0) {
      color = AppTheme.primary;
      text = '▲ Tăng $change điểm so với tuần trước';
    } else if (change < 0) {
      color = AppTheme.danger;
      text = '▼ Giảm ${-change} điểm so với tuần trước';
    } else {
      color = AppTheme.textSecondary;
      text = 'Không đổi so với tuần trước';
    }
    return Text(
      text,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.ready});

  final HealthScoreItem item;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(item.level);
    final counted = ready && item.measured && item.maxPoints > 0;
    final fraction = counted ? item.deduction / item.maxPoints : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (counted)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.deduction == 0 ? '0' : '−${item.deduction}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: item.deduction == 0
                            ? AppTheme.primary
                            : AppTheme.danger,
                      ),
                    ),
                    Text(
                      'trên ${item.maxPoints} điểm',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  item.measured ? '' : 'Chưa tính',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          if (counted) ...[
            const SizedBox(height: 10),
            _DeductionBar(fraction: fraction, color: color),
          ],
        ],
      ),
    );
  }
}

/// Thanh cho thấy phần điểm của mục đã bị trừ.
class _DeductionBar extends StatelessWidget {
  const _DeductionBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 6,
          color: AppTheme.lightGreen,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.score});

  final HealthScore score;

  @override
  Widget build(BuildContext context) {
    final maxText = [
      for (final f in HealthScoreFactor.values) '${f.label} ${f.weight}',
    ].join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Điểm được tính thế nào',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Điểm tối đa mỗi mục: $maxText. Mục ở mức lưu ý mất '
            '${(HealthScoreCalculator.cautionLoss * 100).round()}% điểm của '
            'mục đó, mức cảnh báo mất '
            '${(HealthScoreCalculator.alertLoss * 100).round()}%. Mức do '
            'ngưỡng WHO châu Á và AHA/AMA quyết định. Mục chưa có dữ liệu '
            'được bỏ ra và điểm các mục còn lại chia lại cho đủ 100. Độ đều '
            'đặn đo: có ghi nhận ít nhất '
            '${HealthScoreCalculator.regularityTargetDays} ngày trong '
            '${HealthScoreCalculator.regularityWindowDays} ngày gần nhất '
            'là đủ điểm.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Đây là điểm tham khảo để theo dõi xu hướng, không phải chẩn '
            'đoán y tế. Nếu có chỉ số bất thường, hãy hỏi bác sĩ.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vòng cung tiến độ của điểm, bắt đầu từ đỉnh và chạy theo chiều kim đồng hồ.
class _ScoreArcPainter extends CustomPainter {
  _ScoreArcPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  static const double _stroke = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color.withValues(alpha: 0.15);
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    final sweep = 2 * math.pi * fraction.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, bar);
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter old) =>
      old.fraction != fraction || old.color != color;
}