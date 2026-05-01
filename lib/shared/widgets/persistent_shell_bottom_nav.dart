import 'package:flutter/material.dart';

import '../../features/shell/shell_navigation_service.dart';

class PersistentShellBottomNav extends StatelessWidget {
  const PersistentShellBottomNav({
    super.key,
    required this.selectedIndex,
  });

  final int selectedIndex;

  void _go(BuildContext context, int index) {
    if (index == selectedIndex) {
      if (index == 4) {
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      }
      return;
    }
    if (index >= 0 && index <= 3) {
      ShellNavigationService.openTab(index);
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.sizeOf(context).width >= 960;
    if (isTablet) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 72,
            backgroundColor: colors.surface,
            indicatorColor: colors.primary.withValues(alpha: 0.18),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((Set<WidgetState> states) {
              final bool selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: selected ? 25 : 22,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((Set<WidgetState> states) {
              final bool selected = states.contains(WidgetState.selected);
              return theme.textTheme.labelSmall!.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) => _go(context, index),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event),
                label: 'Events',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_3_outlined),
                selectedIcon: Icon(Icons.groups_3),
                label: 'Boards',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Menu',
              ),
            ],
          ),
        ),
      ),
    );
  }
}