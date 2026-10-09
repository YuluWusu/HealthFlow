/// Thống kê nhanh của một dãy giá trị: thấp nhất, trung bình, cao nhất.
class SeriesSummary {
  final double min;
  final double average;
  final double max;
  final int count;

  const SeriesSummary({
    required this.min,
    required this.average,
    required this.max,
    required this.count,
  });

  /// Trả về `null` khi dãy rỗng.
  static SeriesSummary? of(List<double> values) {
    if (values.isEmpty) return null;
    var min = values.first;
    var max = values.first;
    var sum = 0.0;
    for (final value in values) {
      if (value < min) min = value;
      if (value > max) max = value;
      sum += value;
    }
    return SeriesSummary(
      min: min,
      average: sum / values.length,
      max: max,
      count: values.length,
    );
  }
}
