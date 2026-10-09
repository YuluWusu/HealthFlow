import 'package:flutter/material.dart';

/// Ô chọn ngày giờ đo trong form chỉ số sức khỏe.
///
/// Chạm vào ô sẽ mở hộp chọn ngày, rồi hộp chọn giờ. Không cho chọn ngày
/// sau hôm nay; việc chặn giờ ở tương lai do `HealthValidator` kiểm tra.
class HealthDateTimeField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  const HealthDateTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// Định dạng `06/10/2026 09:05`.
  static String format(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value.isAfter(now) ? now : value,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) return;

    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? () => _pick(context) : null,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Thời điểm đo',
          prefixIcon: Icon(Icons.event_outlined, size: 20),
        ),
        child: Text(format(value)),
      ),
    );
  }
}
