import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/weight_forecast.dart';
import 'app_card.dart';

/// Thẻ "Dự báo cân nặng": với tốc độ hiện tại, sau ~6 tuần bạn sẽ nặng bao
/// nhiêu kg và còn bao lâu nữa chạm cân nặng mong muốn.
///
/// [forecast] là `null` khi chưa đủ dữ liệu; thẻ vẫn hiện để nói rõ cần gì.
class WeightForecastCard extends StatelessWidget {
  const WeightForecastCard({
    super.key,
    required this.forecast,
    this.hasTarget = false,
    this.onSetTarget,
  });

  final WeightForecast? forecast;

  /// Người dùng đã đặt cân nặng mong muốn hay chưa (để gợi ý đặt nếu chưa).
  final bool hasTarget;

  /// Bấm vào dòng gợi ý "Đặt cân nặng mong muốn".
  final VoidCallback? onSetTarget;

  static String _kg(double v) => '${v.toStringAsFixed(1)} kg';

  static String _signedKg(double v) {
    final sign = v > 0 ? '+' : (v < 0 ? '-' : '');
    return '$sign${v.abs().toStringAsFixed(1)} kg';
  }

  /// Số tuần dạng dễ đọc: "chưa đầy 1 tuần", "~3 tuần", "hơn 1 năm".
  static String weeksText(double weeks) {
    if (weeks < 1) return 'chưa đầy 1 tuần';
    if (weeks > 52) return 'hơn 1 năm';
    return '~${weeks.round()} tuần';
  }

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: f == null ? _buildEmpty() : _buildForecast(f),
    );
  }

  Widget _header({Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.lightBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.trending_down_rounded,
              color: AppTheme.blue, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Dự báo cân nặng',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 10),
        const Text(
          'Cần ít nhất 2 lần cân cách nhau từ 5 ngày trở lên để dự báo. '
          'Hãy ghi cân nặng đều đặn mỗi tuần nhé.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildForecast(WeightForecast f) {
    final headline = _headline(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          trailing: f.isLowConfidence
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.lightOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ít dữ liệu',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.orange,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _kg(f.projectedKg),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                'sau ${f.horizonWeeks} tuần (${_signedKg(f.changeKg)})',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          headline,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (f.isFastLoss || f.isFastGain) ...[
          const SizedBox(height: 8),
          Text(
            f.isFastLoss
                ? 'Tốc độ giảm hiện khá nhanh (hơn 1 kg/tuần). Hãy đảm bảo ăn đủ bữa và hỏi bác sĩ nếu bạn không chủ động giảm cân.'
                : 'Tốc độ tăng hiện khá nhanh (hơn 0,5 kg/tuần). Hãy xem lại khẩu phần ăn và vận động.',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.danger),
          ),
        ],
        if (!hasTarget && onSetTarget != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: onSetTarget,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Đặt cân nặng mong muốn để biết khi nào chạm mốc →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Dựa trên ${f.sampleCount} lần cân trong ${f.spanDays} ngày qua, '
          'tốc độ ${_signedKg(f.slopeKgPerWeek)}/tuần. '
          'Chỉ mang tính tham khảo.',
          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  /// Dòng kết luận so với cân nặng mong muốn.
  String _headline(WeightForecast f) {
    final target = f.targetKg;
    switch (f.targetState) {
      case ForecastTargetState.none:
        return 'Nếu giữ nguyên tốc độ hiện tại, bạn đang ở mức ${_kg(f.currentKg)}.';
      case ForecastTargetState.reached:
        return 'Bạn đang ở gần mức mong muốn ${_kg(target!)}. Hãy giữ nhịp này nhé!';
      case ForecastTargetState.flat:
        return 'Cân nặng gần như đứng yên nên chưa ước lượng được khi nào đạt ${_kg(target!)}.';
      case ForecastTargetState.wrongWay:
        return 'Xu hướng hiện tại đang đi xa mức mong muốn ${_kg(target!)}.';
      case ForecastTargetState.onTrack:
        final weeks = f.weeksToTarget!;
        if (f.reachesTargetWithinHorizon) {
          return 'Dự kiến chạm ${_kg(target!)} sau ${weeksText(weeks)}.';
        }
        return 'Còn ${weeksText(weeks)} nữa mới đạt ${_kg(target!)} nếu giữ tốc độ này.';
    }
  }
}
