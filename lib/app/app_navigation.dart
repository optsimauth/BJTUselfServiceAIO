import 'package:flutter/material.dart';

import '../shared/theme/spacing.dart';

/// 路由持有页面状态；这里只负责随窗口宽度切换导航形态。
class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.index,
    required this.onSelected,
    required this.child,
  });
  final int index;
  final ValueChanged<int> onSelected;
  final Widget child;

  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today),
      label: '今日',
    ),
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
      label: '服务',
    ),
    NavigationDestination(
      icon: Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune),
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final extended = constraints.maxWidth >= AppLayout.extendedRailMinWidth;
      if (constraints.maxWidth < AppLayout.railMinWidth) {
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: onSelected,
            destinations: destinations,
          ),
        );
      }
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: extended,
                selectedIndex: index,
                onDestinationSelected: onSelected,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.train_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                      if (extended) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '交大自由行',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    },
  );
}
