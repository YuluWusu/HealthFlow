import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../services/meal_reminder_service.dart';
import '../theme/app_theme.dart';

/// Mở bảng cài đặt nhắc giờ ăn (mỗi bữa một giờ riêng, bật/tắt độc lập).
Future<void> showMealReminderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const MealReminderSheet(),
  );
}

class MealReminderSheet extends StatefulWidget {
  const MealReminderSheet({super.key});

  @override
  State<MealReminderSheet> createState() => _MealReminderSheetState();
}

class _MealReminderSheetState extends State<MealReminderSheet> {
  final _service = MealReminderService();
  Map<ReminderKind, ReminderConfig>? _configs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configs = await _service.load();
    if (!mounted) return;
    setState(() => _configs = configs);
  }

  IconData _icon(ReminderKind kind) {
    switch (kind) {
      case ReminderKind.breakfast:
        return Icons.free_breakfast_outlined;
      case ReminderKind.lunch:
        return Icons.lunch_dining_outlined;
      case ReminderKind.dinner:
        return Icons.dinner_dining_outlined;
      case ReminderKind.snack:
        return Icons.cookie_outlined;
      case ReminderKind.water:
        return Icons.water_drop_outlined;
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(text),
        ),
      );
  }

  Future<void> _update(ReminderKind kind, ReminderConfig next) async {
    setState(() => _configs = {..._configs!, kind: next});
    try {
      await _service.save(kind, next);
    } catch (_) {
      if (mounted) _toast('Không đặt được lịch nhắc. Vui lòng thử lại.');
    }
  }

  Future<void> _toggle(ReminderKind kind, bool on) async {
    final current = _configs![kind]!;
    if (on) {
      final granted = await _service.ensurePermission();
      if (!mounted) return;
      if (!granted) {
        _toast('Hãy cấp quyền thông báo trong cài đặt hệ thống để nhận nhắc nhở.');
        return;
      }
    }
    await _update(kind, current.copyWith(enabled: on));
    if (on && mounted) {
      _toast('Sẽ nhắc ${kind.label.toLowerCase()} lúc ${_configs![kind]!.timeLabel} mỗi ngày.');
    }
  }

  Future<void> _pickTime(ReminderKind kind) async {
    final current = _configs![kind]!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Giờ nhắc ${kind.label.toLowerCase()}',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    var next = current.copyWith(hour: picked.hour, minute: picked.minute);
    // Chọn giờ cho mục đang tắt thì tự bật luôn cho tiện.
    if (!current.enabled) {
      final granted = await _service.ensurePermission();
      if (!mounted) return;
      if (granted) next = next.copyWith(enabled: true);
    }
    await _update(kind, next);
  }

  @override
  Widget build(BuildContext context) {
    final configs = _configs;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nhắc giờ ăn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mỗi bữa có một giờ riêng, nhắc lặp lại hằng ngày.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              if (configs == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final kind in ReminderKind.values)
                  _ReminderRow(
                    icon: _icon(kind),
                    label: kind.label,
                    config: configs[kind]!,
                    onToggle: (on) => _toggle(kind, on),
                    onPickTime: () => _pickTime(kind),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.label,
    required this.config,
    required this.onToggle,
    required this.onPickTime,
  });

  final IconData icon;
  final String label;
  final ReminderConfig config;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final enabled = config.enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: enabled
            ? AppTheme.primary.withValues(alpha: 0.07)
            : const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onPickTime,
                style: TextButton.styleFrom(
                  foregroundColor:
                      enabled ? AppTheme.primary : AppTheme.textSecondary,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                child: Text(config.timeLabel),
              ),
              Switch(
                value: enabled,
                activeThumbColor: AppTheme.primary,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
