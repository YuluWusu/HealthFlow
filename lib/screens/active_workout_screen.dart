import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/workout_repository.dart';
import '../data/auth_scope.dart';
import '../models/workout.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  MÀN HÌNH TẬP LUYỆN THỰC TẾ
//  Luồng: Chuẩn bị 15s → Bài tập (giây / reps) → Nghỉ 30s → … → Hoàn thành
// ═══════════════════════════════════════════════════════════════════════════════

enum _Phase { preparation, active, rest, completed }

class ActiveWorkoutScreen extends StatefulWidget {
  final WorkoutRepository repository;
  final Workout workout;
  final List<Map<String, dynamic>> exercises;

  const ActiveWorkoutScreen({
    super.key,
    required this.repository,
    required this.workout,
    required this.exercises,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.preparation;
  int _currentIndex = 0;

  Timer? _timer;
  int _timeLeft = 15;
  int _timeTotal = 15; // for progress indicator
  bool _isPaused = false;

  int _totalSeconds = 0;
  Timer? _totalTimer;

  int _selectedFeedback = 1; // 0=hard, 1=perfect, 2=easy

  // ── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && _phase != _Phase.completed) _totalSeconds++;
    });
    _startPreparation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _totalTimer?.cancel();
    super.dispose();
  }

  // ── timer helpers ──────────────────────────────────────────────────────────
  void _tick(VoidCallback onDone) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused) return;
      if (_timeLeft <= 1) {
        _timer?.cancel();
        onDone();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── phase transitions ──────────────────────────────────────────────────────
  void _startPreparation() {
    setState(() {
      _phase = _Phase.preparation;
      _timeLeft = 15;
      _timeTotal = 15;
      _isPaused = false;
    });
    _tick(() => _startExercise());
  }

  void _startExercise() {
    if (_currentIndex >= widget.exercises.length) {
      _complete();
      return;
    }
    final ex = widget.exercises[_currentIndex];
    final reps = ex['reps'] as String;
    setState(() {
      _phase = _Phase.active;
      _isPaused = false;
    });

    if (reps.contains(':')) {
      final parts = reps.split(':');
      final sec = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      setState(() {
        _timeLeft = sec;
        _timeTotal = sec;
      });
      _tick(() => _afterExercise());
    } else {
      _timer?.cancel();
      setState(() {
        _timeLeft = 0;
        _timeTotal = 0;
      });
    }
  }

  void _afterExercise() {
    if (_currentIndex < widget.exercises.length - 1) {
      _startRest();
    } else {
      _complete();
    }
  }

  void _startRest() {
    setState(() {
      _phase = _Phase.rest;
      _timeLeft = 30;
      _timeTotal = 30;
      _isPaused = false;
    });
    _tick(() {
      _currentIndex++;
      _startExercise();
    });
  }

  void _skipToNext() {
    _timer?.cancel();
    if (_currentIndex < widget.exercises.length - 1) {
      _currentIndex++;
      _startExercise();
    } else {
      _complete();
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      _timer?.cancel();
      _currentIndex--;
      _startExercise();
    }
  }

  Future<void> _complete() async {
    _timer?.cancel();
    _totalTimer?.cancel();
    setState(() => _phase = _Phase.completed);

    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user != null) {
      await widget.repository
          .completeWorkout(userId: user.id, workout: widget.workout);
    }
  }

  // ── quit dialog (ảnh 5) ────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    if (_phase == _Phase.completed) return true;

    final wasPaused = _isPaused;
    setState(() => _isPaused = true);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('💪', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$_currentIndex bài tập đã được hoàn thành.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mồ hôi nhiều hơn, tỏa\nsáng sau!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 28),
              // Tiếp tục
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Tiếp tục tập luyện',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              // Khởi động lại
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'restart'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Khởi động lại bài tập này',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              // Thực hiện sau
              TextButton(
                onPressed: () => Navigator.pop(context, 'quit'),
                child: const Text(
                  'Thực hiện sau',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'quit') return true;
    if (action == 'restart') {
      setState(() => _currentIndex = 0);
      _startPreparation();
      return false;
    }
    // resume
    if (!wasPaused) setState(() => _isPaused = false);
    return false;
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor:
            _phase == _Phase.rest ? AppTheme.primary : Colors.white,
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.preparation:
        return _buildPreparation();
      case _Phase.active:
        return _buildActive();
      case _Phase.rest:
        return _buildRest();
      case _Phase.completed:
        return _buildCompleted();
    }
  }

  // ── top bar ────────────────────────────────────────────────────────────────
  Widget _topBar({Color color = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: color),
            onPressed: () => _onWillPop().then((ok) {
              if (ok && mounted) Navigator.pop(context);
            }),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.videocam_outlined,
                color: color.withValues(alpha: 0.45)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.music_note_outlined,
                color: color.withValues(alpha: 0.45)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: color.withValues(alpha: 0.45)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  1. CHUẨN BỊ — 15 giây (ảnh 1)
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildPreparation() {
    final ex = widget.exercises[_currentIndex];
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ảnh minh hoạ
              _exerciseImage(ex, 220),
              const SizedBox(height: 36),
              // Tiêu đề
              const Text(
                'ĐÃ SẴN SÀNG TẬP!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  ex['name'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Vòng tròn đếm ngược + nút >
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 48),
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _timeLeft / _timeTotal,
                          strokeWidth: 7,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(
                              AppTheme.primary),
                        ),
                        Center(
                          child: Text(
                            '$_timeLeft',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      _timer?.cancel();
                      _startExercise();
                    },
                    icon: const Icon(Icons.chevron_right,
                        size: 36, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  2. BÀI TẬP ĐANG CHẠY (ảnh 2 = giây, ảnh 4 = reps)
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildActive() {
    final ex = widget.exercises[_currentIndex];
    final reps = ex['reps'] as String;
    final isTimeBased = reps.contains(':');

    return Column(
      children: [
        _topBar(),
        // Thanh tiến trình mỏng
        LinearProgressIndicator(
          value: (_currentIndex + 1) / widget.exercises.length,
          minHeight: 4,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _exerciseImage(ex, 280),
              const SizedBox(height: 36),
              // Tên bài tập
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  ex['name'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Số đếm
              if (isTimeBased)
                Text(
                  _fmt(_timeLeft),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else ...[
                Text(
                  reps,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lặp lại ',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary)),
                      Icon(Icons.swap_vert, size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Thanh điều khiển
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: isTimeBased ? _timerControls() : _repsControls(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Thanh điều khiển bài tập tính giây (ảnh 2): ◄ ▐▐ ►
  Widget _timerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _navBtn(Icons.skip_previous_rounded, _goBack),
        GestureDetector(
          onTap: () => setState(() => _isPaused = !_isPaused),
          child: Container(
            width: 90,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
        _navBtn(Icons.skip_next_rounded, _afterExercise),
      ],
    );
  }

  /// Thanh điều khiển bài tập đếm reps (ảnh 4): ◄  ✓  ►
  Widget _repsControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _navBtn(Icons.skip_previous_rounded, _goBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _afterExercise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Icon(Icons.check_rounded, size: 32),
              ),
            ),
          ),
        ),
        _navBtn(Icons.skip_next_rounded, _skipToNext),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: Colors.black54),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  3. NGHỈ NGƠI (ảnh 3) — nền xanh lá
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildRest() {
    final nextEx = widget.exercises[_currentIndex + 1];
    return Column(
      children: [
        _topBar(color: Colors.white),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                // Ảnh bài tập tiếp theo (trong vòng tròn trắng)
                Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: _exerciseImage(nextEx, 120),
                ),
                const SizedBox(height: 24),
                // Info bài tiếp theo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TIẾP THEO ${_currentIndex + 2}/${widget.exercises.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextEx['name'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        nextEx['reps'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // NGHỈ NGƠI + đồng hồ
                const Text(
                  'NGHỈ NGƠI',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(_timeLeft),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // Chỉnh sửa thời gian nghỉ
                TextButton(
                  onPressed: () => _showEditRestDialog(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                  ),
                  child: const Text('Chỉnh sửa thời gian nghỉ',
                      style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(height: 28),
                // +20s | Bỏ qua
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _timeLeft += 20),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('+20s',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            _timer?.cancel();
                            _currentIndex++;
                            _startExercise();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Bỏ qua',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showEditRestDialog() {
    int newRest = _timeLeft;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Thời gian nghỉ'),
        content: StatefulBuilder(
          builder: (context, setD) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  if (newRest > 5) setD(() => newRest -= 5);
                },
              ),
              Text('$newRest giây',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setD(() => newRest += 5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _timeLeft = newRest);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  //  4. HOÀN THÀNH (ảnh 5 – bảng chúc mừng)
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildCompleted() {
    final calo = (widget.workout.caloriesBurned > 0)
        ? widget.workout.caloriesBurned.toStringAsFixed(1)
        : (_totalSeconds * 0.12).toStringAsFixed(1);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero header
          Stack(
            children: [
              Image.asset(
                'assets/images/exercise/workout_hero_bg.png',
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.8),
                        AppTheme.primary,
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                height: 300,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black38, Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Row(
                  children: [
                    const Text('Nhắc nhở',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 8),
                    Icon(Icons.share_outlined,
                        color: Colors.white.withValues(alpha: 0.7), size: 20),
                  ],
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tuyệt, bạn đã hoàn\nthành bài tập!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.workout.category} ${widget.workout.intensity.label}',
                      style: const TextStyle(
                          fontSize: 15, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statCol('Bài tập', '${widget.exercises.length}'),
                _statCol('Calo', calo),
                _statCol('Thời gian', _fmt(_totalSeconds)),
              ],
            ),
          ),

          // Feedback card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bạn cảm thấy thế nào',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Phản hồi của bạn sẽ giúp chúng tôi cung cấp các bài tập phù hợp hơn cho bạn',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _feedbackOption(0, '😣', 'Quá khó'),
                      _feedbackOption(1, '😊', 'Đúng rồi'),
                      _feedbackOption(2, '😏', 'Quá dễ'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Tiếp theo button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Tiếp theo',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary)),
      ],
    );
  }

  Widget _feedbackOption(int index, String emoji, String label) {
    final selected = _selectedFeedback == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFeedback = index),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.black : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── exercise image helper ──────────────────────────────────────────────────
  Widget _exerciseImage(Map<String, dynamic> ex, double height) {
    final image = ex['image'] as String? ?? '';
    if (image.isEmpty) {
      return Container(
        height: height,
        color: AppTheme.background,
        child: const Center(
          child: Icon(Icons.fitness_center_rounded,
              size: 64, color: AppTheme.primary),
        ),
      );
    }
    return Image.asset(
      image,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) => Container(
        height: height,
        color: AppTheme.background,
        child: const Center(
          child: Icon(Icons.fitness_center_rounded,
              size: 64, color: AppTheme.primary),
        ),
      ),
    );
  }
}
