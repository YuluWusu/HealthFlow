import 'package:flutter/material.dart';
import '../utils/health_analyzer.dart';

class HealthInsightCard extends StatelessWidget {
  final HealthInsight insight;

  const HealthInsightCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    // Cấu hình màu sắc & Icon theo InsightLevel
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    switch (insight.level) {
      case InsightLevel.danger:
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        textColor = Colors.red.shade900;
        icon = Icons.warning_rounded;
        break;
      case InsightLevel.warning:
        bgColor = Colors.amber.shade50;
        borderColor = Colors.amber.shade400;
        textColor = Colors.amber.shade900;
        icon = Icons.info_outline_rounded;
        break;
      case InsightLevel.normal:
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        textColor = Colors.green.shade900;
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      // Không đặt margin: khoảng cách ngang do ListView của màn hình lo,
      // khoảng cách dọc do Padding bọc bên ngoài, để thẻ thẳng hàng với các thẻ khác.
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}