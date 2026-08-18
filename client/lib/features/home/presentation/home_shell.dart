import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:momen_pair_client/features/countdowns/presentation/countdowns_page.dart';
import 'package:momen_pair_client/features/logs/presentation/logs_page.dart';
import 'package:momen_pair_client/features/notices/presentation/notices_page.dart';
import 'package:momen_pair_client/features/notifications/presentation/notifications_page.dart';
import 'package:momen_pair_client/features/profile/presentation/profile_page.dart';
import 'package:momen_pair_client/l10n/generated/app_localizations.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _desktopBreakpoint = 840.0;
  static const _pages = <Widget>[
    LogsPage(),
    NoticesPage(),
    CountdownsPage(),
    NotificationsPage(),
    ProfilePage(),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = <_Destination>[
      _Destination(
          l10n.logsTitle, Icons.auto_stories_outlined, Icons.auto_stories),
      _Destination(l10n.noticesTitle, Icons.campaign_outlined, Icons.campaign),
      _Destination(
          l10n.countdownsTitle, Icons.hourglass_empty, Icons.hourglass_full),
      _Destination(
        l10n.notificationsTitle,
        Icons.notifications_outlined,
        Icons.notifications,
      ),
      _Destination(l10n.profileTitle, Icons.person_outline, Icons.person),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = _AnimatedPage(
          selectedIndex: _selectedIndex,
          child: _pages[_selectedIndex],
        );

        if (constraints.maxWidth >= _desktopBreakpoint) {
          return Scaffold(
            body: Row(
              children: [
                _GlassNavigationRail(
                  destinations: destinations,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectDestination,
                ),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          body: content,
          bottomNavigationBar: _GlassNavigationBar(
            destinations: destinations,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectDestination,
          ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
  }
}

class _AnimatedPage extends StatelessWidget {
  const _AnimatedPage({required this.selectedIndex, required this.child});

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.025, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(selectedIndex), child: child),
    );
  }
}

class _GlassNavigationBar extends StatelessWidget {
  const _GlassNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: ColoredBox(
          color: colorScheme.surface.withValues(alpha: 0.82),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final destination in destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassNavigationRail extends StatelessWidget {
  const _GlassNavigationRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: ColoredBox(
          color: colorScheme.surface.withValues(alpha: 0.82),
          child: SafeArea(
            child: NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
