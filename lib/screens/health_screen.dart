import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemUiOverlayStyle;
import 'package:flutter/foundation.dart' show ValueListenable;
import '../data/app_scope.dart';
import '../data/auth_repository.dart';
import '../data/auth_scope.dart';
import '../data/health_repository.dart';
import '../models/health_metric.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../utils/health_analyzer.dart';
import '../utils/health_assessor.dart';
import '../utils/health_validator.dart';
import '../utils/series_summary.dart';
import '../widgets/error_banner.dart';
import '../widgets/health_form_fields.dart';
import '../widgets/health_hero_card.dart';
import '../widgets/health_insight_card.dart';
import '../widgets/health_visuals.dart';
import '../widgets/screen_backdrop.dart';

/// Màn hình theo dõi Sức khỏe với 4 tab:
/// 1. Tổng quan (Chỉ số & Cảnh báo)
/// 2. Lịch (Xem nhật ký ghi nhận theo lịch tháng)
/// 3. Chỉ số (Biểu đồ xu hướng)
/// 4. Lịch sử (Danh sách bản ghi)
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

/// Yêu cầu mở tab Chỉ số ở một loại chỉ số. Không định nghĩa `==` nên mỗi
/// yêu cầu mới luôn được coi là khác yêu cầu trước, kể cả cùng một loại.
class _ChartRequest {
  const _ChartRequest(this.type);

  final HealthMetricType type;
}

class _HealthScreenState extends State<HealthScreen> {
  final ValueNotifier<_ChartRequest> _chartRequest =
      ValueNotifier(const _ChartRequest(HealthMetricType.weight));

  @override
  void dispose() {
    _chartRequest.dispose();
    super.dispose();
  }

  /// Bấm thẻ ở Tổng quan: chuyển sang tab Chỉ số và chọn đúng loại chỉ số.
  void _openChart(BuildContext context, HealthMetricType type) {
    HapticFeedback.selectionClick();
    _chartRequest.value = _ChartRequest(type);
    DefaultTabController.maybeOf(context)?.animateTo(2);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = AuthScope.of(context, listen: false).currentUser;

    return DefaultTabController(
      length: 4,
      child: ScreenBackdrop(
        // Mỗi tab một ảnh nền riêng (720x1440). Thay ảnh thật bằng cách ghi
        // đè đúng tên file trong assets/images, không cần sửa code.
        assets: const [
          'assets/images/home/bg_health_overview.jpg',
          'assets/images/home/bg_health_calendar.jpg',
          'assets/images/home/bg_health_chart.jpg',
          'assets/images/home/bg_health_history.jpg',
        ],
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            centerTitle: false,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            title: const Text(
              'Sức khỏe',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
                  indicator: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: const [
                    Tab(text: 'Tổng quan'),
                    Tab(text: 'Lịch'),
                    Tab(text: 'Chỉ số'),
                    Tab(text: 'Lịch sử'),
                  ],
                ),
              ),
            ),
          ),
          body: ListenableBuilder(
            listenable: app.health,
            builder: (context, _) {
              if (app.health.isLoading) {
                return const HealthSkeleton();
              }

              return TabBarView(
                children: [
                  _OverviewTab(
                    health: app.health,
                    user: user,
                    onOpenMetric: (type) => _openChart(context, type),
                  ),
                  _CalendarTab(health: app.health, user: user),
                  _ChartTab(
                    health: app.health,
                    user: user,
                    request: _chartRequest,
                  ),
                  _HistoryTab(health: app.health, user: user),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Đưa cân nặng trong hồ sơ về đúng lần cân MỚI NHẤT theo thời gian.
Future<void> _syncProfileWeight(
  AuthRepository auth,
  HealthRepository health,
) async {
  final latest = health.latestOf(HealthMetricType.weight);
  if (latest == null) return;
  await auth.updateProfile(weightKg: latest.value);
}

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

Color _metricColor(HealthMetricType type) {
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
    case HealthMetricType.bmi:
      return AppTheme.primary;
  }
}

int _fractionDigitsOf(HealthMetricType type) {
  switch (type) {
    case HealthMetricType.weight:
    case HealthMetricType.sleep:
    case HealthMetricType.bmi:
      return 1;
    case HealthMetricType.bloodPressure:
    case HealthMetricType.heartRate:
    case HealthMetricType.bloodGlucose:
    case HealthMetricType.steps:
      return 0;
  }
}

/// Hình vẽ nhỏ ở đáy mỗi thẻ chỉ số.
enum _MetricViz {
  /// Đường xu hướng mini.
  line,

  /// 7 cột theo đêm (giấc ngủ).
  bars,

  /// Đường điện tim minh họa (nhịp tim).
  ecg,
}

/// Dữ liệu một thẻ chỉ số ở tab Tổng quan.
class _MetricData {
  final HealthMetricType type;
  final String title;
  final String value;
  final String note;
  final Color noteColor;
  final HealthLevel level;
  final bool assessed;
  final IconData icon;
  final Color color;
  final Color background;

  /// Tối đa 7 giá trị gần nhất (cũ trước, mới sau) cho hình vẽ ở đáy thẻ.
  final List<double> series;
  final _MetricViz viz;

  const _MetricData({
    required this.type,
    required this.title,
    required this.value,
    required this.note,
    required this.noteColor,
    required this.level,
    required this.icon,
    required this.color,
    required this.background,
    this.series = const [],
    this.viz = _MetricViz.line,
    this.assessed = true,
  });

  /// 2 = cảnh báo, 1 = lưu ý, 0 = còn lại. Dùng để chọn thẻ nổi bật.
  int get severity {
    switch (level) {
      case HealthLevel.alert:
        return 2;
      case HealthLevel.caution:
        return 1;
      case HealthLevel.normal:
      case HealthLevel.unknown:
        return 0;
    }
  }
}

/// Tab 1: Tổng quan chỉ số & Lời khuyên
class _OverviewTab extends StatelessWidget {
  final HealthRepository health;
  final User? user;

  /// Gọi khi bấm một thẻ chỉ số, để mở biểu đồ của chỉ số đó.
  final void Function(HealthMetricType type) onOpenMetric;

  const _OverviewTab({
    required this.health,
    required this.user,
    required this.onOpenMetric,
  });

  HealthStatus _statusOf(HealthMetricType type) {
    final latest = health.latestOf(type);
    if (latest == null) return HealthStatus.noData;
    return HealthAssessor.assess(latest);
  }

  /// Tối đa 7 giá trị gần nhất của một chỉ số (cũ trước, mới sau). Nếu 30
  /// ngày qua không có bản ghi nào mà vẫn có bản ghi cũ hơn thì lấy bản ghi đó.
  List<double> _sparkOf(HealthMetricType type) {
    var records = health.seriesOf(type, days: 30);
    if (records.isEmpty) {
      final latest = health.latestOf(type);
      if (latest == null) return const [];
      records = [latest];
    }
    final values = [for (final m in records) m.value];
    return values.length > 7 ? values.sublist(values.length - 7) : values;
  }

  @override
  Widget build(BuildContext context) {
    final weightTrend = health.trendOf(HealthMetricType.weight);
    final bmi = user?.bmi ?? 0;
    final bmiStatus = HealthAssessor.bmi(bmi);
    final pressure = _statusOf(HealthMetricType.bloodPressure);
    final heartRate = _statusOf(HealthMetricType.heartRate);
    final glucose = _statusOf(HealthMetricType.bloodGlucose);
    final sleep = _statusOf(HealthMetricType.sleep);

    final insights = HealthAnalyzer.analyze(health.metrics, user?.heightCm);

    final cards = <_MetricData>[
      _MetricData(
        type: HealthMetricType.weight,
        title: 'Cân nặng',
        value: health.displayOf(HealthMetricType.weight),
        note: weightTrend.display,
        noteColor: weightTrend.isDecrease
            ? AppTheme.primary
            : AppTheme.textSecondary,
        level: HealthLevel.unknown,
        // Cân nặng chỉ có xu hướng, không có ngưỡng đánh giá riêng.
        assessed: false,
        series: _sparkOf(HealthMetricType.weight),
        icon: Icons.monitor_weight_outlined,
        color: AppTheme.blue,
        background: AppTheme.lightBlue,
      ),
      _MetricData(
        type: HealthMetricType.bmi,
        title: 'BMI',
        value: bmi <= 0 ? '--' : bmi.toStringAsFixed(1),
        note: bmiStatus.label,
        noteColor: _levelColor(bmiStatus.level),
        level: bmiStatus.level,
        series: _sparkOf(HealthMetricType.bmi),
        icon: Icons.accessibility_new_rounded,
        color: AppTheme.primary,
        background: AppTheme.lightGreen,
      ),
      _MetricData(
        type: HealthMetricType.bloodPressure,
        title: 'Huyết áp',
        value: health.displayOf(HealthMetricType.bloodPressure),
        note: pressure.label,
        noteColor: _levelColor(pressure.level),
        level: pressure.level,
        series: _sparkOf(HealthMetricType.bloodPressure),
        icon: Icons.favorite_outline_rounded,
        color: AppTheme.pink,
        background: AppTheme.lightPink,
      ),
      _MetricData(
        type: HealthMetricType.heartRate,
        title: 'Nhịp tim',
        value: health.displayOf(HealthMetricType.heartRate),
        note: heartRate.label,
        noteColor: _levelColor(heartRate.level),
        level: heartRate.level,
        series: _sparkOf(HealthMetricType.heartRate),
        viz: _MetricViz.ecg,
        icon: Icons.monitor_heart_outlined,
        color: AppTheme.orange,
        background: AppTheme.lightOrange,
      ),
      _MetricData(
        type: HealthMetricType.bloodGlucose,
        title: 'Đường huyết',
        value: health.displayOf(HealthMetricType.bloodGlucose),
        note: glucose.label,
        noteColor: _levelColor(glucose.level),
        level: glucose.level,
        series: _sparkOf(HealthMetricType.bloodGlucose),
        icon: Icons.bloodtype_outlined,
        color: AppTheme.purple,
        background: AppTheme.lightPurple,
      ),
      _MetricData(
        type: HealthMetricType.sleep,
        title: 'Giấc ngủ',
        value: health.displayOf(HealthMetricType.sleep),
        note: sleep.label,
        noteColor: _levelColor(sleep.level),
        level: sleep.level,
        series: _sparkOf(HealthMetricType.sleep),
        viz: _MetricViz.bars,
        icon: Icons.bedtime_outlined,
        color: AppTheme.blue,
        background: AppTheme.lightBlue,
      ),
    ];

    // Thẻ nổi bật: chỉ số nghiêm trọng nhất (cảnh báo trước, rồi lưu ý). Khi
    // mọi chỉ số đều ổn thì không có thẻ nào nổi bật, giữ lưới đều nhau.
    _MetricData? featured;
    for (final card in cards) {
      if (card.severity > (featured?.severity ?? 0)) featured = card;
    }
    // Bản final để dùng được (và promote null) bên trong hàm onTap.
    final topCard = featured;
    final rest = [
      for (final card in cards)
        if (!identical(card, topCard)) card,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        HealthHeroCard(
          items: [
            for (final card in cards)
              if (card.assessed) HealthHeroItem(card.title, card.level),
          ],
        ),
        const SizedBox(height: 16),
        if (topCard != null) ...[
          _MetricCard(
            data: topCard,
            wide: true,
            onTap: () => onOpenMetric(topCard.type),
          ),
          const SizedBox(height: 12),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            for (final card in rest)
              _MetricCard(data: card, onTap: () => onOpenMetric(card.type)),
          ],
        ),
        const SizedBox(height: 20),
        _AddMetricButton(health: health, user: user),

        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Lời khuyên & Cảnh báo Sức khỏe',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              // Nằm trực tiếp trên nền ảnh tối nên dùng chữ trắng.
              color: Colors.white,
            ),
          ),
        ),
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: HealthInsightCard(insight: insight),
          ),
      ],
    );
  }
}

/// Tab 2: Lịch theo dõi sức khỏe trực quan theo tháng
class _CalendarTab extends StatefulWidget {
  final HealthRepository health;
  final User? user;

  const _CalendarTab({required this.health, required this.user});

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1 = Th 2, 7 = CN

    // Gom nhóm bản ghi theo ngày trong tháng đang xem
    final metricsByDay = <int, List<HealthMetric>>{};
    for (final metric in widget.health.metrics) {
      if (metric.type.isDerived) continue;
      final d = metric.recordedAt;
      if (d.year == _focusedMonth.year && d.month == _focusedMonth.month) {
        metricsByDay.putIfAbsent(d.day, () => []).add(metric);
      }
    }

    // Các bản ghi của ngày đang chọn
    final selectedMetrics = widget.health.metrics.where((m) {
      if (m.type.isDerived) return false;
      return _isSameDay(m.recordedAt, _selectedDay);
    }).toList();

    const weekDays = ['Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        // Khối Calendar View
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Thanh chuyển Tháng/Năm
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tháng ${_focusedMonth.month} ${_focusedMonth.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _previousMonth,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tiêu đề các thứ trong tuần
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: weekDays.map((day) {
                  final isWeekend = day == 'Th 7' || day == 'CN';
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isWeekend ? AppTheme.danger : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              // Lưới các ngày trong tháng
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (firstWeekday - 1) + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  if (index < firstWeekday - 1) {
                    return const SizedBox.shrink();
                  }

                  final dayNum = index - (firstWeekday - 1) + 1;
                  final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
                  final isSelected = _isSameDay(cellDate, _selectedDay);
                  final isToday = _isSameDay(cellDate, now);
                  final hasData = metricsByDay.containsKey(dayNum);

                  return InkWell(
                    onTap: () => setState(() => _selectedDay = cellDate),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : (isToday ? AppTheme.lightGreen : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : (isToday
                                      ? AppTheme.primary
                                      : AppTheme.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Chấm nhỏ báo có dữ liệu
                          if (hasData)
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(height: 5),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Danh sách chỉ số của ngày đang chọn
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ghi nhận ngày ${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_isSameDay(_selectedDay, now))
              const Text(
                'Hôm nay',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8EE3B5),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (selectedMetrics.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Không có chỉ số sức khỏe nào được ghi nhận trong ngày này.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          for (final metric in selectedMetrics)
            _HistoryRow(
              icon: _HistoryTab._iconFor(metric.type),
              title: metric.type.label,
              date: _HistoryTab._formatDateTime(metric.recordedAt),
              note: metric.note,
              value: metric.displayValue,
              color: _metricColor(metric.type),
            ),
      ],
    );
  }
}

/// Tab 3: Biểu đồ xu hướng
class _ChartTab extends StatefulWidget {
  final HealthRepository health;
  final User? user;

  /// Yêu cầu chọn loại chỉ số từ bên ngoài (bấm thẻ ở tab Tổng quan).
  final ValueListenable<_ChartRequest> request;

  const _ChartTab({
    required this.health,
    required this.user,
    required this.request,
  });

  @override
  State<_ChartTab> createState() => _ChartTabState();
}

class _ChartTabState extends State<_ChartTab> {
  static const _rangeOptions = [7, 30, 90];

  late HealthMetricType _type;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _type = widget.request.value.type;
    widget.request.addListener(_onRequest);
  }

  void _onRequest() {
    if (!mounted) return;
    setState(() => _type = widget.request.value.type);
  }

  @override
  void dispose() {
    widget.request.removeListener(_onRequest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPressure = _type == HealthMetricType.bloodPressure;
    final digits = _fractionDigitsOf(_type);
    String fmt(double v) => v.toStringAsFixed(digits);

    var series = widget.health.seriesOf(_type, days: _days);
    if (isPressure) {
      series = series.where((m) => m.valueSecondary != null).toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final type in HealthMetricType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    showCheckmark: false,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    selectedColor: Colors.white,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          _type == type ? FontWeight.bold : FontWeight.normal,
                      color: _type == type
                          ? AppTheme.primaryDark
                          : Colors.white,
                    ),
                    onSelected: (_) => setState(() => _type = type),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.16),
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppTheme.primaryDark
                    : Colors.white,
              ),
              side: WidgetStateProperty.all(
                BorderSide(color: Colors.white.withValues(alpha: 0.28)),
              ),
            ),
            segments: [
              for (final days in _rangeOptions)
                ButtonSegment<int>(value: days, label: Text('$days ngày')),
            ],
            selected: {_days},
            onSelectionChanged: (selection) =>
                setState(() => _days = selection.first),
          ),
        ),
        const SizedBox(height: 14),
        if (series.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const HealthEmptyArt(size: 84, color: AppTheme.primary),
                const SizedBox(height: 10),
                Text(
                  'Chưa có dữ liệu ${_type.label.toLowerCase()} '
                  'trong $_days ngày gần nhất.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          _buildChartCard(series, isPressure, fmt, digits),
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
              Icon(Icons.insights_rounded, color: AppTheme.primary, size: 21),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vùng xanh trên biểu đồ là khoảng bình thường tham khảo. '
                  'Đo đều đặn và ghi lại thời điểm đo giúp bạn thấy rõ xu '
                  'hướng; nếu chỉ số bất thường kéo dài, hãy hỏi bác sĩ.',
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

  Widget _buildChartCard(
    List<HealthMetric> series,
    bool isPressure,
    String Function(double) fmt,
    int digits,
  ) {
    final last = series.last;
    final status = HealthAssessor.assess(last);
    final statusColor = _levelColor(status.level);

    final primaryValues = [for (final m in series) m.value];
    final secondaryValues = [
      if (isPressure) for (final m in series) m.valueSecondary!,
    ];

    final lines = [
      _ChartLine(primaryValues, _metricColor(_type)),
      if (isPressure) _ChartLine(secondaryValues, AppTheme.blue),
    ];

    final summary = SeriesSummary.of(primaryValues)!;
    final secondarySummary =
        isPressure ? SeriesSummary.of(secondaryValues) : null;

    String stat(double Function(SeriesSummary) pick) {
      final main = fmt(pick(summary));
      final second = secondarySummary;
      return second == null ? main : '$main/${fmt(pick(second))}';
    }

    final bigValue = isPressure
        ? '${fmt(last.value)}/${fmt(last.valueSecondary!)}'
        : fmt(last.value);

    final previous = series.length >= 2 ? series[series.length - 2] : null;
    final diff = previous == null ? null : last.value - previous.value;

    return Container(
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
              Expanded(
                child: Text(
                  _type.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${series.length} lần ghi',
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
                bigValue,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 5, bottom: 5),
                child: Text(
                  _type.unit,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              if (diff != null && !isPressure)
                Row(
                  children: [
                    Icon(
                      diff < 0
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 15,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      diff.abs().toStringAsFixed(digits == 0 ? 0 : 1),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Lần ghi gần nhất: ${_formatShortDateTime(last.recordedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (status.level != HealthLevel.unknown)
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TrendChartPainter(
                times: [for (final m in series) m.recordedAt],
                lines: lines,
                band: HealthAssessor.normalRange(
                  _type,
                  heightCm: widget.user?.heightCm,
                ),
                limits: isPressure
                    ? const [
                        HealthAssessor.systolicLimit,
                        HealthAssessor.diastolicLimit,
                      ]
                    : const [],
                fractionDigits: digits,
              ),
            ),
          ),
          if (isPressure) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                _LegendDot(color: AppTheme.pink, label: 'Tâm thu'),
                SizedBox(width: 16),
                _LegendDot(color: AppTheme.blue, label: 'Tâm trương'),
                SizedBox(width: 16),
                _LegendDot(color: AppTheme.orange, label: 'Vạch ngưỡng'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Thấp nhất',
                  value: stat((s) => s.min),
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: 'Trung bình',
                  value: stat((s) => s.average),
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: 'Cao nhất',
                  value: stat((s) => s.max),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatShortDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _ChartLine {
  final List<double> values;
  final Color color;

  const _ChartLine(this.values, this.color);
}

class _TrendChartPainter extends CustomPainter {
  final List<DateTime> times;
  final List<_ChartLine> lines;
  final NormalRange? band;
  final List<double> limits;
  final int fractionDigits;

  _TrendChartPainter({
    required this.times,
    required this.lines,
    required this.band,
    required this.limits,
    required this.fractionDigits,
  });

  static const double _left = 38;
  static const double _right = 12;
  static const double _top = 8;
  static const double _bottom = 24;

  TextPainter _text(String text, double fontSize, Color color) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (times.isEmpty || lines.isEmpty) return;

    final plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );

    final all = [for (final line in lines) ...line.values];
    var minValue = all.reduce((a, b) => a < b ? a : b);
    var maxValue = all.reduce((a, b) => a > b ? a : b);
    if (maxValue - minValue < 1) {
      minValue -= 0.5;
      maxValue += 0.5;
    } else {
      final padding = (maxValue - minValue) * 0.18;
      minValue -= padding;
      maxValue += padding;
    }

    double yOf(double value) {
      return plot.bottom -
          (value - minValue) / (maxValue - minValue) * plot.height;
    }

    final start = times.first;
    final span = times.last.difference(start).inMinutes;
    final singleX = times.length == 1 || span <= 0;

    double xOf(int index) {
      if (singleX) return plot.center.dx;
      return plot.left + times[index].difference(start).inMinutes / span * plot.width;
    }

    final gridPaint = Paint()
      ..color = AppTheme.textSecondary.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      final value = maxValue - (maxValue - minValue) * i / 3;
      final label = _text(
        value.toStringAsFixed(fractionDigits),
        9.5,
        AppTheme.textSecondary,
      );
      label.paint(canvas, Offset(plot.left - 6 - label.width, y - label.height / 2));
    }

    final range = band;
    if (range != null) {
      final top = range.max == null
          ? plot.top
          : yOf(range.max!).clamp(plot.top, plot.bottom).toDouble();
      final bottom = range.min == null
          ? plot.bottom
          : yOf(range.min!).clamp(plot.top, plot.bottom).toDouble();
      if (bottom - top > 1) {
        canvas.drawRect(
          Rect.fromLTRB(plot.left, top, plot.right, bottom),
          Paint()..color = AppTheme.primary.withValues(alpha: 0.09),
        );
      }
    }

    for (final line in lines) {
      final points = [
        for (var i = 0; i < line.values.length; i++)
          Offset(xOf(i), yOf(line.values[i])),
      ];

      if (points.length > 1) {
        final linePath = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          linePath.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(
          linePath,
          Paint()
            ..color = line.color
            ..strokeWidth = 2.4
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }

      for (var i = 0; i < points.length; i++) {
        canvas.drawCircle(points[i], 4.0, Paint()..color = line.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) => true;
}

/// Tab 4: Danh sách tất cả các lần ghi nhận
class _HistoryTab extends StatelessWidget {
  final HealthRepository health;
  final User? user;

  const _HistoryTab({required this.health, required this.user});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      for (final metric in health.metrics)
        if (!metric.type.isDerived) metric,
    ];

    if (metrics.isEmpty) {
      return const _EmptyState(
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
            note: metric.note,
            value: metric.displayValue,
            color: _metricColor(metric.type),
            onEdit: user == null ? null : () => _showEditDialog(context, metric),
            onDelete: user == null ? null : () => _confirmDelete(context, metric),
          ),
        const SizedBox(height: 8),
        _AddMetricButton(health: health, user: user),
      ],
    );
  }

  void _confirmDelete(BuildContext context, HealthMetric metric) {
    final auth = AuthScope.of(context, listen: false);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bản ghi?'),
        content: Text('Bạn có chắc muốn xóa "${metric.type.label}: ${metric.displayValue}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await health.deleteMetric(metric.id, user!.id);
              if (metric.type == HealthMetricType.weight) {
                await _syncProfileWeight(auth, health);
              }
            },
            child: const Text('Xóa', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, HealthMetric metric) {
    final auth = AuthScope.of(context, listen: false);
    final needsSecondary = metric.type == HealthMetricType.bloodPressure;

    final valueController = TextEditingController(text: _plain(metric.value));
    final secondaryController = TextEditingController(
      text: metric.valueSecondary == null ? '' : _plain(metric.valueSecondary!),
    );
    final noteController = TextEditingController(text: metric.note);
    var recordedAt = metric.recordedAt;
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Sửa ${metric.type.label.toLowerCase()}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null) ...[
                      ErrorBanner(message: errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Giá trị',
                        suffixText: needsSecondary ? 'tâm thu' : metric.type.unit,
                      ),
                    ),
                    if (needsSecondary) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: secondaryController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Huyết áp dưới',
                          suffixText: 'tâm trương',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    HealthDateTimeField(
                      value: recordedAt,
                      onChanged: (date) => setDialogState(() => recordedAt = date),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final value = HealthValidator.parseNumber(valueController.text);
                    final secondary = needsSecondary
                        ? HealthValidator.parseNumber(secondaryController.text)
                        : null;

                    // Kiểm tra giống form thêm: khoảng hợp lý, không ở tương
                    // lai, ghi chú không quá dài.
                    final error = HealthValidator.validate(
                          metric.type,
                          value,
                          secondary: secondary,
                        ) ??
                        HealthValidator.validateRecordedAt(recordedAt) ??
                        HealthValidator.validateNote(noteController.text);
                    if (error != null) {
                      setDialogState(() => errorMessage = error);
                      return;
                    }

                    await health.updateMetric(
                      metric.copyWith(
                        value: value!,
                        valueSecondary: secondary,
                        recordedAt: recordedAt,
                        note: noteController.text.trim(),
                      ),
                      heightCm: auth.currentUser?.heightCm,
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    if (metric.type == HealthMetricType.weight) {
                      await _syncProfileWeight(auth, health);
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _plain(double number) {
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
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
      case HealthMetricType.bmi:
        return Icons.accessibility_new_rounded;
    }
  }

  static String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Hôm nay, $time';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}, $time';
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  /// Thẻ rộng hai cột, dành cho chỉ số cần chú ý nhất.
  final bool wide;

  final VoidCallback? onTap;

  const _MetricCard({required this.data, this.wide = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Chỉ số lệch ngưỡng có viền theo mức độ; thẻ rộng thêm quầng sáng.
    final accent = data.severity > 0 ? heroLevelColor(data.level) : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: accent == null ? null : Border.all(color: accent, width: 1.6),
        boxShadow: wide && accent != null
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.38),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(wide ? 16 : 14),
            child: wide ? _buildWide() : _buildCompact(),
          ),
        ),
      ),
    );
  }

  Widget _iconBox(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(data.icon, color: data.color, size: size * 0.57),
    );
  }

  Widget _viz() {
    switch (data.viz) {
      case _MetricViz.bars:
        return SleepBars(values: data.series, color: data.color);
      case _MetricViz.ecg:
        return EcgLine(
          bpm: data.series.isEmpty ? null : data.series.last,
          color: data.color,
        );
      case _MetricViz.line:
        return Sparkline(values: data.series, color: data.color);
    }
  }

  Widget _buildWide() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildWideTop(),
        const SizedBox(height: 12),
        SizedBox(height: 44, child: _viz()),
      ],
    );
  }

  Widget _buildWideTop() {
    return Row(
      children: [
        _iconBox(46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedNumberText(
                data.value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // Giới hạn bề rộng để nhãn dài tự xuống dòng thay vì tràn khỏi thẻ.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: data.noteColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.note,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: data.noteColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _iconBox(30),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedNumberText(
          data.value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.note,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: data.noteColor,
          ),
        ),
        const SizedBox(height: 8),
        // Hình vẽ lấy phần chiều cao còn lại nên không bao giờ gây tràn thẻ.
        Expanded(child: _viz()),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String date;
  final String note;
  final String value;
  final Color color;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _HistoryRow({
    required this.icon,
    required this.title,
    required this.date,
    this.note = '',
    required this.value,
    required this.color,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

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
        label: const Text('Thêm chỉ số', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _showAddMetricDialog(BuildContext screenContext) {
    final auth = AuthScope.of(screenContext, listen: false);
    final currentUser = user;
    if (currentUser == null) return;

    var selectedType = HealthMetricType.weight;
    var recordedAt = DateTime.now();
    final valueController = TextEditingController();
    final secondaryController = TextEditingController();
    final noteController = TextEditingController();

    showDialog<void>(
      context: screenContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            final needsSecondary = selectedType == HealthMetricType.bloodPressure;

            return AlertDialog(
              title: const Text('Thêm chỉ số'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<HealthMetricType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Loại chỉ số'),
                      items: HealthMetricType.userEntered.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type.label));
                      }).toList(),
                      onChanged: (type) {
                        if (type != null) setDialogState(() => selectedType = type);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Giá trị',
                        suffixText: needsSecondary ? 'tâm thu' : selectedType.unit,
                      ),
                    ),
                    if (needsSecondary) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: secondaryController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Huyết áp dưới',
                          suffixText: 'tâm trương',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    HealthDateTimeField(
                      value: recordedAt,
                      onChanged: (date) => setDialogState(() => recordedAt = date),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final value = HealthValidator.parseNumber(valueController.text);
                    final secondary = needsSecondary
                        ? HealthValidator.parseNumber(secondaryController.text)
                        : null;

                    if (value == null) return;

                    final metric = HealthMetric(
                      id: 'metric-${selectedType.storeName}-${DateTime.now().microsecondsSinceEpoch}',
                      userId: currentUser.id,
                      type: selectedType,
                      value: value,
                      valueSecondary: secondary,
                      recordedAt: recordedAt,
                      note: noteController.text.trim(),
                    );

                    await health.addMetric(metric, heightCm: auth.currentUser?.heightCm);
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    if (selectedType == HealthMetricType.weight) {
                      await _syncProfileWeight(auth, health);
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HealthEmptyArt(size: 128),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}