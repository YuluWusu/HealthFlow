import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_theme.dart';

/// Thanh điều hướng dưới cùng với 5 mục theo bản thiết kế.
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Trang chủ'),
      _NavItem(
        icon: Icons.favorite_border_rounded,
        selectedIcon: Icons.favorite_rounded,
        label: 'Sức khỏe',
      ),
      _NavItem(
        icon: Icons.fitness_center_outlined,
        selectedIcon: Icons.fitness_center_rounded,
        label: 'Tập luyện',
      ),
      _NavItem(
        icon: Icons.restaurant_outlined,
        selectedIcon: Icons.restaurant_rounded,
        label: 'Dinh dưỡng',
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: 'Cài đặt',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.softShadow(opacity: 0.06, blur: 18),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(items.length, (index) {
              final isSelected = selectedIndex == index;
              final item = items[index];

              return Expanded(
                child: InkWell(
                  onTap: () {
                    AudioService().playTap();
                    onItemTapped(index);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          size: 23,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
