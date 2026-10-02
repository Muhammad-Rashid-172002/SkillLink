import 'package:flutter/material.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';

/// Primary navigation that fits the screen: a bottom bar on phones and
/// tablets, a side rail on desktop/web so wide screens aren't driven by a
/// phone-style bar stretched across the bottom.
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    required this.bottomBar,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  /// The phone/tablet bar (kept as each role's own widget).
  final Widget bottomBar;

  static const double railBreakpoint = 1000;
  static const double extendedBreakpoint = 1200;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < railBreakpoint) {
      return Scaffold(body: body, bottomNavigationBar: bottomBar);
    }
    final extended = width >= extendedBreakpoint;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(right: BorderSide(color: colors.outlineVariant)),
            ),
            child: SafeArea(
              right: false,
              child: NavigationRail(
                extended: extended,
                minExtendedWidth: 232,
                backgroundColor: colors.surface,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: extended
                      ? const SkillNovaWordmark(size: 28)
                      : const SkillNovaLogo(size: 32),
                ),
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
