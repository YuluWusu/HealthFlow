import 'package:flutter/material.dart';

/// Nền ảnh toàn màn hình dùng chung cho các module (Dinh dưỡng, Sức khỏe...).
///
/// Cách hoạt động giống `_NutritionBackdrop`: mỗi tab một ảnh, chuyển mờ khi
/// đổi tab, phủ lớp tối để chữ trắng và thẻ kính mờ luôn đọc rõ.
///
/// Phải đặt BÊN TRONG một [DefaultTabController].
///
/// - [assets]: danh sách ảnh theo thứ tự tab. Nếu ít hơn số tab thì tab dư
///   dùng ảnh cuối cùng; nếu một ảnh lỗi/thiếu thì hiện [fallbackColor].
/// - [overlayColors]: hai màu gradient phủ từ trên xuống dưới.
class ScreenBackdrop extends StatelessWidget {
  const ScreenBackdrop({
    super.key,
    required this.assets,
    required this.child,
    this.fallbackColor = const Color(0xFF1B3A2A),
    this.overlayColors = const [Color(0x66000000), Color(0x99000000)],
    this.cacheWidth = 720,
  }) : assert(assets.length > 0, 'Cần ít nhất một ảnh nền');

  final List<String> assets;
  final Widget child;
  final Color fallbackColor;
  final List<Color> overlayColors;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final animation = DefaultTabController.of(context).animation!;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final index = animation.value.round().clamp(0, assets.length - 1);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: SizedBox.expand(
                key: ValueKey(index),
                child: Image.asset(
                  assets[index],
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  errorBuilder: (_, _, _) => ColoredBox(color: fallbackColor),
                ),
              ),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: overlayColors,
            ),
          ),
          child: const SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}