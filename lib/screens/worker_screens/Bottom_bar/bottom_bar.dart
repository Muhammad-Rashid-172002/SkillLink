import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Map/Map_screen.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_screen.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_screen.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_messages_screen.dart';
import 'package:skill_link/screens/worker_screens/navigation/worker_navigation_scope.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_screen.dart';

class WorkerBottomBar extends StatelessWidget {
  const WorkerBottomBar({
    super.key,
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  static const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore_rounded),
      label: 'Leads',
    ),
    NavigationDestination(
      icon: Icon(Icons.work_outline_rounded),
      selectedIcon: Icon(Icons.work_rounded),
      label: 'Jobs',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: Icon(Icons.chat_bubble_rounded),
      label: 'Messages',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  void _legacyNavigate(BuildContext context, int index) {
    if (index == selectedIndex) return;
    final screen = switch (index) {
      0 => const WorkerHomeScreen(),
      1 => const MapSreen(),
      2 => const WorkerJobsScreen(),
      3 => const WorkerMessagesScreen(),
      4 => const WorkerProfileScreen(),
      _ => const WorkerHomeScreen(),
    };
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (WorkerNavigationScope.isEmbedded(context)) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: selectedIndex.clamp(0, 4),
          onDestinationSelected: (index) {
            final callback = onDestinationSelected;
            if (callback != null) {
              callback(index);
            } else {
              _legacyNavigate(context, index);
            }
          },
          destinations: destinations,
          animationDuration: const Duration(milliseconds: 220),
        ),
      ),
    );
  }
}
