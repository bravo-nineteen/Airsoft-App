import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../features/shell/shell_navigation_service.dart';

class PersistentShellBottomNav extends StatelessWidget {
  const PersistentShellBottomNav({
    super.key,
    required this.selectedIndex,
  });

  final int selectedIndex;

  int _normalizeSelectedIndex(int index) {
    switch (index) {
      case 0:
        return 0;
      case 1:
        return 2;
      case 2:
        return 1;
      case 3:
      case 4:
        return 3;
      default:
        return 0;
    }
  }

  void _go(BuildContext context, int index) {
    final int normalizedSelectedIndex = _normalizeSelectedIndex(selectedIndex);
    if (index == normalizedSelectedIndex) {
      if (index == 3) {
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      }
      return;
    }
    if (index >= 0 && index <= 2) {
      ShellNavigationService.openTab(index);
    } else if (index == 3) {
      ShellNavigationService.openTab(3);
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.sizeOf(context).width >= 960;
    if (isTablet) {
      return const SafeArea(
        top: false,
        child: SizedBox.shrink(),
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 72,
              backgroundColor: colors.surfaceContainer,
              indicatorColor: colors.primary.withValues(alpha: 0.16),
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
              selectedIndex: _normalizeSelectedIndex(selectedIndex),
              onDestinationSelected: (int index) => _go(context, index),
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.dynamic_feed_outlined),
                  selectedIcon: const Icon(Icons.dynamic_feed),
                  label: l10n.t('newsfeed'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.forum_outlined),
                  selectedIcon: const Icon(Icons.forum),
                  label: l10n.t('boards'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.event_outlined),
                  selectedIcon: const Icon(Icons.event),
                  label: l10n.events,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_rounded),
                  selectedIcon: const Icon(Icons.menu_rounded),
                  label: l10n.t('menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}