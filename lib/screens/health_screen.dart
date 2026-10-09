import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/health_repository.dart';
import '../models/health_metric.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

/// Màn hình 4 trong bản thiết kế: module Sức khỏe.
///
/// Ba thẻ theo dõi: Tổng quan (các chỉ số), Chỉ số (biểu đồ cân nặng) và
/// Lịch sử (danh sách ghi nhận).
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = AuthScope.of(context, listen: false).currentUser;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Sức khỏe',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 13.5),
            tabs: [
              Tab(text: 'Tổng quan'),
              Tab(text: 'Chỉ số'),
              Tab(text: 'Lịch sử'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: app.health,
          builder: (context, _) {
            if (app.health.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              physics: const ClampingScrollPhysics(),
              children: [
                _OverviewTab(health: app.health, user: user),
                _ChartTab(health: app.health),
                _HistoryTab(health: app.health, user: user),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tab 1: lưới các chỉ số sức khỏe mới nhất.
class _OverviewTab extends StatelessWidget {
  final HealthRepository health;
  final User? user;

  const _OverviewTab({required this.health, required this.user});

  @override
  Widget build(BuildContext context) {
    final weightTrend = health.trendOf(HealthMetricType.weight);
    final bmi = user?.bmi ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            _MetricCard(
              title: 'Cân nặng',
              value: health.displayOf(HealthMetricType.weight),
              note: weightTrend.display,
              noteColor: weightTrend.isDecrease
                  ? AppTheme.primary
                  : AppTheme.textSecondary,
              icon: Icons.monitor_weight_outlined,
              color: AppTheme.blue,
              background: AppTheme.lightBlue,
            ),
            _MetricCard(
              title: 'BMI',
              value: bmi <= 0 ? '--' : bmi.toStringAsFixed(1),
              note: user?.bmiLabel ?? 'Chưa có dữ liệu',
              noteColor: AppTheme.primary,
              icon: Icons.accessibility_new_rounded,
              color: AppTheme.primary,
              background: AppTheme.lightGreen,
            ),
            _MetricCard(
              title: 'Huyết áp',
              value: health.displayOf(HealthMetricType.bloodPressure),
              note: 'Bình thường',
              noteColor: AppTheme.primary,
              icon: Icons.favorite_outline_rounded,
              color: AppTheme.pink,
              background: AppTheme.lightPink,
            ),
            _MetricCard(
              title: 'Nhịp tim',
              value: health.displayOf(HealthMetricType.heartRate),
              note: 'Bình thường',
              noteColor: AppTheme.primary,
              icon: Icons.monitor_heart_outlined,
              color: AppTheme.orange,
              background: AppTheme.lightOrange,
            ),
            _MetricCard(
              title: 'Đường huyết',
              value: health.displayOf(HealthMetricType.bloodGlucose),
              note: 'Bình thường',
              noteColor: AppTheme.primary,
              icon: Icons.bloodtype_outlined,
              color: AppTheme.purple,
              background: AppTheme.lightPurple,
            ),
            _MetricCard(
              title: 'Giấc ngủ',
              value: health.displayOf(HealthMetricType.sleep),
              note: 'Tốt',
              noteColor: AppTheme.primary,
              icon: Icons.bedtime_outlined,
              color: AppTheme.blue,
              background: AppTheme.lightBlue,
            ),
          ],
        ),
        const SizedBox(height: 22),
        _AddMetricButton(health: health, user: user),
      ],
    );
  }
}

/// Tab 2: biểu đồ đường theo dõi cân nặng 7 lần ghi gần nhất.
class _ChartTab extends StatelessWidget {
  final HealthRepository health;

  const _ChartTab({required this.health});

  @override
  Widget build(BuildContext context) {
    final history = health.weightHistory();
    final latest = health.latestOf(HealthMetricType.weight);
    final trend = health.trendOf(HealthMetricType.weight);

    if (history.isEmpty) {
      return const _EmptyState(
        icon: Icons.show_chart_rounded,
        message: 'Chưa có dữ liệu cân nặng để vẽ biểu đồ.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cân nặng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${history.length} lần ghi',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    latest == null ? '--' : latest.value.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 5),
                    child: Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        trend.isDecrease
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 15,
                        color: trend.isDecrease
                            ? AppTheme.primary
                            : AppTheme.orange,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        trend.hasPrevious
                            ? '${trend.difference.abs().toStringAsFixed(1)} kg'
                            : '--',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: trend.isDecrease
                              ? AppTheme.primary
                              : AppTheme.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'So với lần ghi trước đó',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 150,
                child: _WeightChart(history: history),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.insights_rounded,
                color: AppTheme.primary,
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Theo dõi cân nặng đều đặn mỗi tuần giúp bạn thấy rõ tiến trình '
                  'và điều chỉnh chế độ ăn uống, luyện tập hợp lý hơn.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Biểu đồ đường vẽ bằng [CustomPaint] nên không cần thư viện biểu đồ.
class _WeightChart extends StatelessWidget {
  final List<HealthMetric> history;

  const _WeightChart({required this.history});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WeightChartPainter(history),
      child: const SizedBox.expand(),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<HealthMetric> history;

  _WeightChartPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final values = history.map((metric) => metric.value).toList();
    var minValue = values.reduce((a, b) => a < b ? a : b);
    var maxValue = values.reduce((a, b) => a > b ? a : b);

    // Nới khoảng giá trị để đường biểu diễn không dính sát mép trên/dưới.
    if (maxValue - minValue < 1) {
      minValue -= 0.5;
      maxValue += 0.5;
    } else {
      final padding = (maxValue - minValue) * 0.18;
      minValue -= padding;
      maxValue += padding;
    }

    const bottomPadding = 24.0;
    final chartHeight = size.height - bottomPadding;

    Offset pointAt(int index) {
      final x = history.length == 1
          ? size.width / 2
          : index * (size.width / (history.length - 1));
      final ratio = (values[index] - minValue) / (maxValue - minValue);
      final y = chartHeight - ratio * chartHeight;
      return Offset(x, y);
    }

    // Lưới ngang mờ.
    final gridPaint = Paint()
      ..color = AppTheme.textSecondary.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = List.generate(history.length, pointAt);

    // Vùng tô dưới đường biểu diễn.
    final areaPath = Path()..moveTo(points.first.dx, chartHeight);
    for (final point in points) {
      areaPath.lineTo(point.dx, point.dy);
    }
    areaPath
      ..lineTo(points.last.dx, chartHeight)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primary.withValues(alpha: 0.22),
            AppTheme.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight)),
    );

    // Đường biểu diễn.
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppTheme.primary
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Điểm dữ liệu (điểm cuối được làm nổi bật).
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      canvas.drawCircle(
        points[i],
        isLast ? 5.5 : 3.5,
        Paint()..color = AppTheme.primary,
      );
      if (isLast) {
        canvas.drawCircle(
          points[i],
          9.5,
          Paint()..color = AppTheme.primary.withValues(alpha: 0.18),
        );
      }
    }

    // Nhãn ngày dưới trục hoành.
    for (var i = 0; i < points.length; i++) {
      final date = history[i].recordedAt;
      final painter = TextPainter(
        text: TextSpan(
          text: '${date.day}/${date.month}',
          style: const TextStyle(
            fontSize: 9.5,
            color: AppTheme.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (points[i].dx - painter.width / 2)
              .clamp(0.0, size.width - painter.width),
          chartHeight + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}

/// Tab 3: danh sách các lần ghi nhận chỉ số.
class _HistoryTab extends StatelessWidget {
  final HealthRepository health;
  final User? user;

  const _HistoryTab({required this.health, required this.user});

  @override
  Widget build(BuildContext context) {
    final metrics = health.metrics;

    if (metrics.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        message: 'Chưa có lần ghi nhận nào. Hãy thêm chỉ số đầu tiên của bạn.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        for (final metric in metrics)
          _HistoryRow(
            icon: _iconFor(metric.type),
            title: metric.type.label,
            date: _formatDateTime(metric.recordedAt),
            value: metric.displayValue,
            color: _colorFor(metric.type),
          ),
        const SizedBox(height: 8),
        _AddMetricButton(health: health, user: user),
      ],
    );
  }

  static IconData _iconFor(HealthMetricType type) {
    switch (type) {
      case HealthMetricType.weight:
        return Icons.monitor_weight_outlined;
      case HealthMetricType.bloodPressure:
        return Icons.favorite_outline_rounded;
      case HealthMetricType.heartRate:
        return Icons.monitor_heart_outlined;
      case HealthMetricType.bloodGlucose:
        return Icons.bloodtype_outlined;
      case HealthMetricType.sleep:
        return Icons.bedtime_outlined;
      case HealthMetricType.steps:
        return Icons.directions_walk_rounded;
    }
  }

  static Color _colorFor(HealthMetricType type) {
    switch (type) {
      case HealthMetricType.weight:
        return AppTheme.blue;
      case HealthMetricType.bloodPressure:
        return AppTheme.pink;
      case HealthMetricType.heartRate:
        return AppTheme.orange;
      case HealthMetricType.bloodGlucose:
        return AppTheme.purple;
      case HealthMetricType.sleep:
        return AppTheme.blue;
      case HealthMetricType.steps:
        return AppTheme.primary;
    }
  }

  /// Định dạng `Hôm nay, 08:30` hoặc `28/09/2026, 07:30`.
  static String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (isToday) return 'Hôm nay, $time';
    if (isYesterday) return 'Hôm qua, $time';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}, $time';
  }
}

/// Thẻ chỉ số trong lưới tổng quan.
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String note;
  final Color noteColor;
  final IconData icon;
  final Color color;
  final Color background;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.note,
    required this.noteColor,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: noteColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String date;
  final Color color;

  const _HistoryRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.date,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: color.withValues(alpha: 0.13),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút mở hộp thoại thêm chỉ số mới.
class _AddMetricButton extends StatelessWidget {
  final HealthRepository health;
  final User? user;

  const _AddMetricButton({required this.health, required this.user});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _showAddMetricDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm chỉ số',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  /// Hộp thoại nhập chỉ số mới.
  ///
  /// Chỉ số sẽ được lưu thật vào kho dữ liệu, và nếu là cân nặng thì hồ sơ
  /// người dùng cũng được cập nhật theo.
  void _showAddMetricDialog(BuildContext context) {
    final auth = AuthScope.of(context, listen: false);
    final currentUser = user;
    if (currentUser == null) return;

    var selectedType = HealthMetricType.weight;
    final valueController = TextEditingController();
    final secondaryController = TextEditingController();
    String? errorMessage;
    var isSaving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Nhập huyết áp cần thêm ô chỉ số dưới.
            final needsSecondary =
                selectedType == HealthMetricType.bloodPressure;

            Future<void> save() async {
              final raw = valueController.text.trim().replaceAll(',', '.');
              final value = double.tryParse(raw);

              if (value == null) {
                setDialogState(
                  () => errorMessage = 'Vui lòng nhập giá trị hợp lệ.',
                );
                return;
              }
              if (value <= 0) {
                setDialogState(
                  () => errorMessage = 'Giá trị phải lớn hơn 0.',
                );
                return;
              }

              double? secondary;
              if (needsSecondary) {
                secondary = double.tryParse(
                  secondaryController.text.trim().replaceAll(',', '.'),
                );
                if (secondary == null) {
                  setDialogState(
                    () => errorMessage = 'Vui lòng nhập chỉ số huyết áp dưới.',
                  );
                  return;
                }
              }

              setDialogState(() {
                isSaving = true;
                errorMessage = null;
              });

              final metric = HealthMetric(
                id: 'metric-${selectedType.storeName}-'
                    '${DateTime.now().microsecondsSinceEpoch}',
                userId: currentUser.id,
                type: selectedType,
                value: value,
                valueSecondary: secondary,
                recordedAt: DateTime.now(),
              );

              try {
                await health.addMetric(metric);

                // Cân nặng mới được đồng bộ vào hồ sơ để BMI hiển thị đúng.
                if (selectedType == HealthMetricType.weight) {
                  await auth.updateProfile(weightKg: value);
                }

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã lưu ${selectedType.label.toLowerCase()}.'),
                  ),
                );
              } catch (_) {
                setDialogState(() {
                  isSaving = false;
                  errorMessage = 'Không lưu được chỉ số, vui lòng thử lại.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Thêm chỉ số'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<HealthMetricType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Loại chỉ số',
                        prefixIcon: Icon(Icons.category_outlined, size: 20),
                      ),
                      items: HealthMetricType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (type) {
                              if (type != null) {
                                setDialogState(() {
                                  selectedType = type;
                                  errorMessage = null;
                                  secondaryController.clear();
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: valueController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Giá trị',
                        suffixText: needsSecondary ? 'tâm thu' : selectedType.unit,
                        prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ),
                    if (needsSecondary) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: secondaryController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Huyết áp dưới',
                          suffixText: 'tâm trương',
                          prefixIcon: Icon(Icons.edit_outlined, size: 20),
                        ),
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : save,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      valueController.dispose();
      secondaryController.dispose();
    });
  }
}

/// Trạng thái rỗng dùng chung cho các tab.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppTheme.textSecondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
