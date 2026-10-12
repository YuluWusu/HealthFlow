import 'package:flutter/material.dart';

import '../models/health_metric.dart';
import '../theme/app_theme.dart';
import '../utils/measurement_schedule.dart';
import 'app_card.dart';

/// Thẻ nhắc lịch đo: "Còn 2 ngày tới hạn đo huyết áp", "Trễ 3 ngày: ...".
///
/// Không có mục nào thì thẻ không chiếm chỗ (trả về [SizedBox.shrink]), nên
/// có thể đặt vô điều kiện ở đầu danh sách.
class MeasurementDueCard extends StatelessWidget {
  const MeasurementDueCard({super.key, required this.items, this.title});

  final List<DueItem> items;

  /// Tiêu đề nhỏ phía trên danh sách (có thể bỏ trống).
  final String? title;

  /// Màu nhấn theo mức độ gấp, dùng chung với dấu đánh dấu trên lịch.
  static Color colorOf(DueStatus status) {
    switch (status) {
      case DueStatus.never:
      case DueStatus.overdue:
        return AppTheme.danger;
      case DueStatus.dueToday:
        return AppTheme.orange;
      case DueStatus.soon:
      case DueStatus.upcoming:
        return AppTheme.blue;
    }
  }

  static IconData _iconOf(HealthMetricType type) {
    switch (type) {
      case HealthMetricType.weight:
        return Icons.monitor_weight_outlined;
      case HealthMetricType.bloodPressure:
        return Icons.favorite_outline_rounded;
      case HealthMetricType.bloodGlucose:
        return Icons.bloodtype_outlined;
      default:
        return Icons.event_available_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_rounded,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title ?? 'Lịch đo đến hạn',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items) _DueRow(item: item),
        ],
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow({required this.item});

  final DueItem item;

  @override
  Widget build(BuildContext context) {
    final color = MeasurementDueCard.colorOf(item.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(MeasurementDueCard._iconOf(item.type),
                size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.message,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
