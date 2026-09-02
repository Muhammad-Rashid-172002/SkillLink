import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Chat/Chat_screen.dart';
import 'package:skill_link/screens/worker_screens/Map/Map_screen.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_screen.dart';
import 'package:skill_link/screens/worker_screens/home_screen/JobsByStatusScreen.dart';
import 'package:skill_link/screens/worker_screens/navigation/worker_navigation_scope.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerProfileScreen.dart';

class WorkerNavigationShell extends StatefulWidget {
  const WorkerNavigationShell({
    super.key,
    this.initialIndex = 0,
    this.screenBuilder,
  });

  final int initialIndex;
  final Widget Function(int index, ValueChanged<int> selectTab)? screenBuilder;

  @override
  State<WorkerNavigationShell> createState() => _WorkerNavigationShellState();
}

class _WorkerNavigationShellState extends State<WorkerNavigationShell> {
  late int _selectedIndex;
  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4);
    _screens = List<Widget?>.filled(5, null);
    _screens[_selectedIndex] = _createScreen(_selectedIndex);
  }

  Widget _createScreen(int index) {
    final builder = widget.screenBuilder;
    if (builder != null) return builder(index, _selectTab);
    return switch (index) {
      0 => WorkerHomeScreen(onSelectTab: _selectTab),
      1 => const MapSreen(),
      2 => const JobsByStatusScreen(
        title: 'My jobs',
        status: 'all',
        embedded: true,
      ),
      3 => const ChatScreen(),
      4 => const WorkerProfileScreen(),
      _ => WorkerHomeScreen(onSelectTab: _selectTab),
    };
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _screens.length || index == _selectedIndex) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _screens[index] ??= _createScreen(index);
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) _selectTab(0);
      },
      child: Scaffold(
        body: WorkerNavigationScope(
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens
                .map((screen) => screen ?? const SizedBox.shrink())
                .toList(growable: false),
          ),
        ),
        bottomNavigationBar: WorkerBottomBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
        ),
      ),
    );
  }
}
