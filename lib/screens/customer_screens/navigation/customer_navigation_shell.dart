import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_screen.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore.dart';
import 'package:skill_link/screens/customer_screens/Profile_screen/Profile_scree.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/customer_home_screen.dart';
import 'package:skill_link/screens/customer_screens/muneTile/My_request.dart';

/// Persistent navigation root for the customer experience.
///
/// IndexedStack keeps scroll position, controllers, and live-query state intact
/// while customers move between primary destinations.
class CustomerNavigationShell extends StatefulWidget {
  const CustomerNavigationShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CustomerNavigationShell> createState() =>
      _CustomerNavigationShellState();
}

class _CustomerNavigationShellState extends State<CustomerNavigationShell> {
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
    return switch (index) {
      0 => CustomerHomeScreen(onSelectTab: _selectTab),
      1 => const Explore(),
      2 => const MyRequestsScreen(embedded: true),
      3 => const CustomerChatsScreen(),
      4 => CustomerProfileScreen(onSelectTab: _selectTab),
      _ => CustomerHomeScreen(onSelectTab: _selectTab),
    };
  }

  void _selectTab(int index) {
    if (index == _selectedIndex || index < 0 || index >= _screens.length) {
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
        if (!didPop && _selectedIndex != 0) {
          _selectTab(0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens
              .map((screen) => screen ?? const SizedBox.shrink())
              .toList(growable: false),
        ),
        bottomNavigationBar: CustomerBottomBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
        ),
      ),
    );
  }
}
