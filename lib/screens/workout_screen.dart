
// ignore_for_file: unused_import, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/workout_repository.dart';
import '../models/workout.dart';
import '../theme/app_theme.dart';
import 'active_workout_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return DefaultTabController(
      length: 2,
      child: _WorkoutBackdrop(
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
              'Tập luyện',
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13.5),
                  tabs: const [
                    Tab(text: 'Tổng quan'),
                    Tab(text: 'Báo cáo'),
                  ],
                ),
              ),
            ),
          ),
          body: ListenableBuilder(
            listenable: app.workout,
            builder: (context, _) {
              return TabBarView(
                children: [
                  _OverviewTab(workout: app.workout),
                  _ReportTab(workout: app.workout),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkoutBackdrop extends StatelessWidget {
  const _WorkoutBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SizedBox.expand(
          child: Image.asset(
            'assets/images/exercise/workout_hero_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x88000000), Color(0xBB000000)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 1 – TỔNG QUAN
// ═══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final WorkoutRepository workout;

  const _OverviewTab({required this.workout});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        _WeeklyGoalSection(workout: workout),
        const SizedBox(height: 24),
        _BodyFocusAndWorkouts(workout: workout),
        const SizedBox(height: 24),
        const _CustomWorkoutSection(),
      ],
    );
  }
}

Future<int?> _showWeeklyGoalSheet(BuildContext context, int currentGoal) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (context) => _WeeklyGoalSheet(currentGoal: currentGoal),
  );
}

class _WeeklyGoalSheet extends StatefulWidget {
  final int currentGoal;
  const _WeeklyGoalSheet({required this.currentGoal});
  @override
  State<_WeeklyGoalSheet> createState() => _WeeklyGoalSheetState();
}

class _WeeklyGoalSheetState extends State<_WeeklyGoalSheet> {
  late int _selectedDays;
  String _firstDay = 'SUNDAY';

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.currentGoal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Đặt mục tiêu hàng tuần\ncủa bạn',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chúng tôi khuyến nghị tập luyện ít nhất 3\nngày mỗi tuần để có kết quả tốt hơn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Text('Ngày tập luyện hàng tuần', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final isSelected = day == _selectedDays;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDays = day),
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.textSecondary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              const Divider(color: Colors.black12),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🗓️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Text('Ngày đầu tiên của tuần', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _firstDay,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    items: ['SUNDAY', 'MONDAY'].map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _firstDay = val);
                    },
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedDays),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: const Text('Lưu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyGoalSection extends StatefulWidget {
  final WorkoutRepository workout;
  const _WeeklyGoalSection({required this.workout});

  @override
  State<_WeeklyGoalSection> createState() => _WeeklyGoalSectionState();
}

class _WeeklyGoalSectionState extends State<_WeeklyGoalSection> {
  int _goalDays = 4;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await _showWeeklyGoalSheet(context, _goalDays);
        if (result != null) {
          setState(() {
            _goalDays = result;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow(opacity: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mục tiêu hàng tuần', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Row(
                  children: [
                    Text('1/$_goalDays', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 14, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 4; i <= 10; i++)
                  if (i == 8)
                    Container(
                      width: 30, height: 30,
                      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 18),
                    )
                  else if (i == 9)
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3))),
                      alignment: Alignment.center,
                      child: Text('$i', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    )
                  else
                    SizedBox(
                      width: 30, height: 30,
                      child: Center(child: Text('$i', style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 18, color: AppTheme.orange),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.workout.caloriesBurnedToday} kcal',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.schedule_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.workout.minutesToday} phút đã tập hôm nay',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyFocusAndWorkouts extends StatefulWidget {
  final WorkoutRepository workout;
  const _BodyFocusAndWorkouts({required this.workout});

  @override
  State<_BodyFocusAndWorkouts> createState() => _BodyFocusAndWorkoutsState();
}

class _BodyFocusAndWorkoutsState extends State<_BodyFocusAndWorkouts> {
  int _selectedIndex = 0;

  static const _bodyParts = [
    {'label': 'Bụng', 'prefix': 'Bụng'},
    {'label': 'Cánh tay', 'prefix': 'Cánh tay'},
    {'label': 'Cẳng tay', 'prefix': 'Cẳng tay'},
    {'label': 'Ngực', 'prefix': 'Ngực'},
    {'label': 'Chân', 'prefix': 'Chân'},
    {'label': 'Mông', 'prefix': 'Mông'},
    {'label': 'Vai', 'prefix': 'Vai'},
    {'label': 'Lưng', 'prefix': 'Lưng'},
  ];

  @override
  Widget build(BuildContext context) {
    final selectedPrefix = _bodyParts[_selectedIndex]['prefix'] as String;
    // Luôn tạo 3 bài tập cố định cho mỗi nhóm cơ thể
    final workouts = [
      Workout(
        id: '${selectedPrefix}_beginner',
        name: '$selectedPrefix Người bắt đầu',
        durationMinutes: 16,
        caloriesBurned: 80,
        intensity: WorkoutIntensity.light,
        category: selectedPrefix,
      ),
      Workout(
        id: '${selectedPrefix}_intermediate',
        name: '$selectedPrefix Trung bình',
        durationMinutes: 25,
        caloriesBurned: 150,
        intensity: WorkoutIntensity.moderate,
        category: selectedPrefix,
      ),
      Workout(
        id: '${selectedPrefix}_advanced',
        name: '$selectedPrefix Nâng cao',
        durationMinutes: 20,
        caloriesBurned: 200,
        intensity: WorkoutIntensity.intense,
        category: selectedPrefix,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cơ thể tập trung',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _bodyParts.length,
            separatorBuilder: (context2, i) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = index == _selectedIndex;
              final part = _bodyParts[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    part['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppTheme.primary : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        for (final item in workouts)
          _WorkoutTile(
            workout: item,
            titlePrefix: selectedPrefix,
            onStart: () => _openWorkoutDetail(context, widget.workout, item),
          ),
      ],
    );
  }
}

class _CustomWorkoutSection extends StatelessWidget {
  const _CustomWorkoutSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tùy chỉnh bài tập', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _CustomWorkoutListScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF53C28B), AppTheme.primary]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TẠO CỦA\nRIÊNG BẠN', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.1)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: const Text('ĐI', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MÀN HÌNH TÙY CHỈNH BÀI TẬP
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomWorkoutListScreen extends StatefulWidget {
  const _CustomWorkoutListScreen();

  @override
  State<_CustomWorkoutListScreen> createState() => _CustomWorkoutListScreenState();
}

class _CustomWorkoutListScreenState extends State<_CustomWorkoutListScreen> {
  final List<Map<String, dynamic>> _customWorkouts = [
    {
      'name': 'NEW',
      'minutes': 3,
      'exercises': 4,
      'exerciseList': [
        {'name': 'Chống đẩy vào tường', 'reps': 'x15', 'image': 'assets/images/exercise/logo_bung1.png'},
        {'name': 'Đấm', 'reps': '00:20', 'image': 'assets/images/exercise/logo_bung2.png'},
        {'name': 'Giang cánh tay sang hai bên', 'reps': '00:20', 'image': 'assets/images/exercise/logo_bung3.png'},
        {'name': 'Gập người 90/90', 'reps': 'x10', 'image': 'assets/images/exercise/logo_bung1.png'},
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('TÙY CHỈNH BÀI TẬP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 0.5)),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const _EditCustomWorkoutScreen()));
          if (result != null && result is Map<String, dynamic>) {
            setState(() {
              _customWorkouts.add(result);
            });
          }
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _customWorkouts.length,
        itemBuilder: (context, index) {
          final w = _customWorkouts[index];
          return ListTile(
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => _CustomWorkoutDetailScreen(workout: w)));
              if (result != null && result is Map<String, dynamic>) {
                final action = result['action'];
                if (action == 'delete') {
                  setState(() => _customWorkouts.removeAt(index));
                } else if (action == 'update') {
                  setState(() => _customWorkouts[index] = result['data'] as Map<String, dynamic>);
                }
              }
            },
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit, color: AppTheme.primary, size: 22),
            ),
            title: Text(w['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${w['minutes']} phút · ${w['exercises']} bài tập', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          );
        },
      ),
    );
  }
}

class _EditCustomWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic>? initialWorkout;
  const _EditCustomWorkoutScreen({this.initialWorkout});

  @override
  State<_EditCustomWorkoutScreen> createState() => _EditCustomWorkoutScreenState();
}

class _EditCustomWorkoutScreenState extends State<_EditCustomWorkoutScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Chương trình mới');
  final List<Map<String, dynamic>> _exercises = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkout != null) {
      _nameController.text = widget.initialWorkout!['name'] as String;
      if (widget.initialWorkout!['exerciseList'] != null) {
        _exercises.addAll(List<Map<String, dynamic>>.from(widget.initialWorkout!['exerciseList'] as List<dynamic>));
      }
    } else {
      _exercises.addAll([
        {'name': 'Chống đẩy vào tường', 'reps': 'x10', 'image': 'assets/images/exercise/logo_bung1.png'},
        {'name': 'Đấm', 'reps': '00:20', 'image': 'assets/images/exercise/logo_bung2.png'},
      ]);
    }
  }

  void _addExercise() async {
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => const _AddExerciseSheet(),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _exercises.addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('CHỈNH SỬA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: AppTheme.background, shape: BoxShape.circle),
                    child: const Icon(Icons.edit, size: 16, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bài tập (${_exercises.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: _addExercise,
                    child: const Text('Thêm', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _exercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _exercises.removeAt(oldIndex);
                    _exercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final ex = _exercises[index];
                  return Container(
                    key: ValueKey('${ex['name']}_$index'),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.menu, color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            ex['image'] as String,
                            width: 60, height: 60, fit: BoxFit.cover,
                            errorBuilder: (c,e,s) => Container(width: 60, height: 60, color: AppTheme.lightGreen, child: const Icon(Icons.fitness_center_rounded, color: AppTheme.primary)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.remove, size: 14),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(ex['reps'] as String, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.add, size: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.swap_vert, color: AppTheme.primary),
                      ],
                    ),
                  );
                },
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add, color: AppTheme.primary, size: 20),
                label: const Text('Thêm bài tập', style: TextStyle(color: AppTheme.primary, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'name': _nameController.text,
                      'minutes': _exercises.length * 2,
                      'exercises': _exercises.length,
                      'exerciseList': _exercises,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Lưu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet();

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final List<Map<String, dynamic>> _recommended = [
    {'name': 'Chống đẩy vào tường', 'reps': 'x10', 'image': 'assets/images/exercise/logo_bung1.png'},
    {'name': 'Đấm', 'reps': '00:20', 'image': 'assets/images/exercise/logo_bung2.png'},
    {'name': 'Giang cánh tay sang hai bên', 'reps': '00:20', 'image': 'assets/images/exercise/logo_bung3.png'},
    {'name': 'Căng bắp chân phải', 'reps': '00:20', 'image': 'assets/images/exercise/logo_bung1.png'},
    {'name': 'Duỗi mông bên trái', 'reps': '00:20', 'image': 'assets/images/exercise/logo_bung2.png'},
  ];
  
  final List<Map<String, dynamic>> _recent = [
    {'name': 'Gập người 90/90', 'reps': 'x10', 'image': 'assets/images/exercise/logo_bung3.png'},
  ];

  final Set<Map<String, dynamic>> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text('Thêm bài tập', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: AppTheme.background, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      children: [
                        Icon(Icons.filter_alt_outlined, size: 16, color: AppTheme.textSecondary),
                        SizedBox(width: 8),
                        Text('Tất cả các khu vực (370)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(24)),
                child: const TextField(
                  decoration: InputDecoration(
                    icon: Icon(Icons.search, color: AppTheme.textSecondary),
                    hintText: 'Tìm kiếm bài tập',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  const Text('Được khuyến nghị', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 16),
                  ..._recommended.map((ex) => _buildItem(ex)),
                  const SizedBox(height: 24),
                  const Text('Gần đây', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 16),
                  ..._recent.map((ex) => _buildItem(ex)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selected.toList()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(_selected.isEmpty ? 'Đóng' : 'Thêm (${_selected.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> ex) {
    final isSelected = _selected.contains(ex);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) _selected.remove(ex);
          else _selected.add(ex);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                ex['image'] as String,
                width: 50, height: 50, fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Container(width: 50, height: 50, color: AppTheme.lightGreen, child: const Icon(Icons.fitness_center_rounded, color: AppTheme.primary)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(ex['reps'] as String, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.background,
                shape: BoxShape.circle,
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomWorkoutDetailScreen extends StatefulWidget {
  final Map<String, dynamic> workout;
  const _CustomWorkoutDetailScreen({required this.workout});

  @override
  State<_CustomWorkoutDetailScreen> createState() => _CustomWorkoutDetailScreenState();
}

class _CustomWorkoutDetailScreenState extends State<_CustomWorkoutDetailScreen> {
  late Map<String, dynamic> _workout;

  @override
  void initState() {
    super.initState();
    _workout = Map<String, dynamic>.from(widget.workout);
  }

  void _renameWorkout() {
    final controller = TextEditingController(text: _workout['name'] as String);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Đổi tên bài tập'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nhập tên mới'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () {
              setState(() => _workout['name'] = controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _editWorkout() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => _EditCustomWorkoutScreen(initialWorkout: _workout)));
    if (result != null && result is Map<String, dynamic>) {
      setState(() => _workout = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _workout['exerciseList'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context, {'action': 'update', 'data': _workout}),
        ),
        actions: [
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'rename') _renameWorkout();
              else if (value == 'edit') _editWorkout();
              else if (value == 'delete') {
                Navigator.pop(context, {'action': 'delete'});
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(children: [Icon(Icons.loop, size: 20), SizedBox(width: 12), Text('Đổi tên')]),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('Chỉnh sửa')]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete_outline, size: 20), SizedBox(width: 12), Text('Xóa')]),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _workout['name'] as String,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  const Icon(Icons.tune, color: AppTheme.textSecondary),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${_workout['minutes']} phút', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 16),
                  const Icon(Icons.local_fire_department_rounded, size: 15, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${_workout['exercises']} Bài tập', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final appScope = AppScope.of(context, listen: false);
                    final mins = _workout['minutes'] as int;
                    final workoutObj = Workout(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: _workout['name'] as String,
                      category: 'TÙY CHỈNH',
                      intensity: WorkoutIntensity.moderate,
                      durationMinutes: mins,
                      caloriesBurned: mins * 6,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveWorkoutScreen(
                          repository: appScope.workout,
                          workout: workoutObj,
                          exercises: List<Map<String, dynamic>>.from(_workout['exerciseList'] as List<dynamic>? ?? []),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Khởi đầu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Bài tập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final ex = exercises[index] as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        const Icon(Icons.menu, color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            ex['image'] as String,
                            width: 64, height: 64, fit: BoxFit.cover,
                            errorBuilder: (c,e,s) => Container(width: 64, height: 64, color: AppTheme.lightGreen, child: const Icon(Icons.fitness_center_rounded, color: AppTheme.primary)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(ex['reps'] as String, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.swap_vert, color: AppTheme.textSecondary),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MÀN HÌNH CHI TIẾT BÀI TẬP (khi bấm vào tile)
// ═══════════════════════════════════════════════════════════════════════════════

void _openWorkoutDetail(BuildContext context, WorkoutRepository repository, Workout workout) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => _WorkoutDetailScreen(repository: repository, workout: workout)));
}

class _WorkoutDetailScreen extends StatelessWidget {
  final WorkoutRepository repository;
  final Workout workout;

  const _WorkoutDetailScreen({required this.repository, required this.workout});

  // Tạo danh sách bài tập giả
  List<Map<String, String>> get _exercises {
    final exerciseData = <Map<String, String>>[
      {'name': 'Bật nhảy', 'reps': '00:30'},
      {'name': 'Chạm gót chân', 'reps': 'x26'},
      {'name': 'Vặn chéo', 'reps': 'x20'},
      {'name': 'Leo núi', 'reps': 'x20'},
      {'name': 'Gập bụng', 'reps': 'x15'},
      {'name': 'Plank', 'reps': '00:30'},
    ];
    // Thêm bài tập dựa theo cường độ
    final count = workout.intensity == WorkoutIntensity.light
        ? 4
        : workout.intensity == WorkoutIntensity.moderate
            ? 5
            : 6;
    return exerciseData.take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _exercises;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/exercise/workout_hero_bg.png', fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x88000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & settings icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          workout.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Icon(Icons.tune_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text('${workout.durationMinutes} phút', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(width: 16),
                      const Icon(Icons.fitness_center_rounded, size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text('${exercises.length} Bài tập', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Nút Khởi đầu
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        // Chuyển exercises từ Map<String,String> sang Map<String,dynamic>
                        final exerciseMaps = exercises.map((e) => <String, dynamic>{
                          'name': e['name']!,
                          'reps': e['reps']!,
                          'image': 'assets/images/exercise/logo_bung1.png',
                        }).toList();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActiveWorkoutScreen(
                              repository: repository,
                              workout: workout,
                              exercises: exerciseMaps,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Khởi đầu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Danh sách bài tập header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bài tập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Chỉnh sửa >', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Exercise list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ex = exercises[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.menu, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/exercise/logo_bung1.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 56, height: 56,
                            color: AppTheme.lightGreen,
                            child: const Icon(Icons.fitness_center_rounded, color: AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex['name']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(ex['reps']!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.swap_vert_rounded, color: AppTheme.textSecondary),
                    ],
                  ),
                );
              },
              childCount: exercises.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  WORKOUT TILE – Một dòng bài tập kèm nút Play
// ═══════════════════════════════════════════════════════════════════════════════

class _WorkoutTile extends StatelessWidget {
  final Workout workout;
  final String titlePrefix;
  final VoidCallback onStart;

  const _WorkoutTile({
    required this.workout,
    required this.titlePrefix,
    required this.onStart,
  });

  String get _imagePath {
    switch (workout.intensity) {
      case WorkoutIntensity.light: return 'assets/images/exercise/logo_bung1.png';
      case WorkoutIntensity.moderate: return 'assets/images/exercise/logo_bung2.png';
      case WorkoutIntensity.intense: return 'assets/images/exercise/logo_bung3.png';
    }
  }

  int get _bolts {
    switch (workout.intensity) {
      case WorkoutIntensity.light: return 1;
      case WorkoutIntensity.moderate: return 2;
      case WorkoutIntensity.intense: return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow(opacity: 0.04),
        ),
        child: Row(
          children: [
            // Ảnh logo_bung
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                _imagePath,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (context2, error, stackTrace) => Container(
                  width: 76,
                  height: 76,
                  color: AppTheme.lightGreen,
                  child: const Icon(Icons.fitness_center_rounded, color: AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Thông tin bài tập
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.intensity == WorkoutIntensity.light
                        ? '$titlePrefix Người bắt đầu'
                        : workout.intensity == WorkoutIntensity.moderate
                            ? '$titlePrefix Trung bình'
                            : '$titlePrefix Nâng cao',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${workout.durationMinutes} phút • ${workout.durationMinutes ~/ 1.5} Bài tập',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(3, (index) => Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: index < _bolts ? AppTheme.primary : AppTheme.textSecondary.withValues(alpha: 0.2),
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 2 – BÁO CÁO (theo ảnh tham khảo cuối)
// ═══════════════════════════════════════════════════════════════════════════════

class _ReportTab extends StatelessWidget {
  final WorkoutRepository workout;

  const _ReportTab({required this.workout});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        // ── Tổng quan nhanh ──
        _QuickStatsCard(workout: workout),
        const SizedBox(height: 20),

        // ── Lịch sử ──
        _HistorySection(workout: workout),
        const SizedBox(height: 20),

        // ── Cân nặng ──
        const _WeightSection(),
      ],
    );
  }
}

/// Thẻ thống kê nhanh: Tập luyện, kcal, Phút.
class _QuickStatsCard extends StatelessWidget {
  final WorkoutRepository workout;

  const _QuickStatsCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final logs = workout.todayLogs.length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow(opacity: 0.05),
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.local_fire_department_rounded,
            iconColor: AppTheme.orange,
            value: '$logs',
            label: 'Tập luyện',
          ),
          _StatItem(
            icon: Icons.bolt_rounded,
            iconColor: AppTheme.blue,
            value: '${workout.caloriesBurnedToday}',
            label: 'kcal',
          ),
          _StatItem(
            icon: Icons.schedule_rounded,
            iconColor: AppTheme.primary,
            value: '${workout.minutesToday}',
            label: 'Phút',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Phần Lịch sử với lịch tuần + streak.
class _HistorySection extends StatelessWidget {
  final WorkoutRepository workout;

  const _HistorySection({required this.workout});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Lấy ngày bắt đầu tuần (Chủ nhật)
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final dayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lịch sử',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Tất cả bản ghi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lịch tuần
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day = weekStart.add(Duration(days: i));
              final isToday = day.day == now.day &&
                  day.month == now.month &&
                  day.year == now.year;
              final isPast = day.isBefore(
                DateTime(now.year, now.month, now.day),
              );
              // Giả lập: các ngày đã qua đều có tập
              final hasWorked = isPast;

              return Column(
                children: [
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasWorked)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    )
                  else if (isToday)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Streak info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ngày liên tiếp',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          '🔥',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${workout.todayLogs.isNotEmpty ? 1 : 0}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(
                      'Tốt nhất của Cá nhân',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '1 ngày',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Phần Cân nặng – biểu đồ đơn giản + thông tin.
class _WeightSection extends StatelessWidget {
  const _WeightSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + nút ghi lại
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cân nặng',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Ghi lại',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Thông tin cân nặng
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Hiện tại',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '55 kg',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(
                      'Nặng nhất   55',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Nhẹ nhất   55',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Biểu đồ cân nặng đơn giản
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: Size.infinite,
              painter: _WeightChartPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vẽ biểu đồ cân nặng đơn giản.
class _WeightChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = AppTheme.textSecondary.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    // Trục Y labels
    final yLabels = ['55.2', '55', '54.8', '54.6', '54.4', '54.2', '54'];
    final yStep = size.height / (yLabels.length - 1);

    for (int i = 0; i < yLabels.length; i++) {
      final y = i * yStep;
      canvas.drawLine(
        Offset(40, y),
        Offset(size.width, y),
        gridPaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: yLabels[i],
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // Trục X labels
    final xLabels = ['29', '30', '01', '02', '03', '04', '05', '06'];
    final xStep = (size.width - 50) / (xLabels.length - 1);

    for (int i = 0; i < xLabels.length; i++) {
      final x = 45.0 + i * xStep;
      final textPainter = TextPainter(
        text: TextSpan(
          text: xLabels[i],
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - 6, size.height + 4));
    }

    // Đường biểu đồ
    // Giả lập dữ liệu cân nặng: chỉ 1 điểm ở ngày 05 = 55.0
    final dataPoint = Offset(
      45.0 + 6 * xStep,
      1 * yStep, // 55.0 nằm tại y = 1
    );

    // Vẽ chấm data
    canvas.drawCircle(dataPoint, 5, dotPaint);
    canvas.drawCircle(
      dataPoint,
      3,
      Paint()..color = Colors.white,
    );

    // Label nổi
    final labelBg = Paint()..color = AppTheme.textPrimary;
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: dataPoint.translate(0, -20), width: 50, height: 24),
      const Radius.circular(12),
    );
    canvas.drawRRect(labelRect, labelBg);

    final labelText = TextPainter(
      text: const TextSpan(
        text: '55.0',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelText.paint(
      canvas,
      Offset(dataPoint.dx - labelText.width / 2, dataPoint.dy - 31),
    );

    // Tháng label
    final monthLabel = TextPainter(
      text: TextSpan(
        text: 'Tháng ${DateTime.now().month}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary.withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    monthLabel.paint(canvas, Offset(size.width / 2 - monthLabel.width / 2, -20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


