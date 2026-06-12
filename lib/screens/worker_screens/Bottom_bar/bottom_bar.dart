import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Chat/Chat_screen.dart';
import 'package:skill_link/screens/worker_screens/Wallat/Wallat_screen.dart';
import 'package:skill_link/screens/worker_screens/home_screen/worker_dashbaord.dart';
import 'package:skill_link/screens/worker_screens/Map/Map_screen.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerProfileScreen.dart';

class WorkerBottomBar extends StatelessWidget {
  final int selectedIndex;

  const WorkerBottomBar({super.key, required this.selectedIndex});

  static const List<_NavItem> items = [
    _NavItem(Icons.dashboard_rounded, "Home"),
    _NavItem(Icons.map_rounded, "Map"),
    _NavItem(Icons.account_balance_wallet_rounded, "Wallet"),
    _NavItem(Icons.chat_rounded, "Chat"),
    _NavItem(Icons.person_rounded, "Profile"),
  ];

  void _navigate(BuildContext context, int index) {
    if (index == selectedIndex) return;

    Widget screen;

    switch (index) {
      case 0:
        screen = const WorkerHomeScreen();
        break;
      case 1:
        screen = const MapSreen();
        break;
      case 2:
        screen = const WallatScreen();
        break;
      case 3:
        screen = const ChatScreen();
        break;
      case 4:
        screen = const WorkerProfileScreen();
        break;

      default:
        screen = const WorkerHomeScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final selected = selectedIndex == index;

          return GestureDetector(
            onTap: () => _navigate(context, index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 15 : 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF16A34A) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    items[index].icon,
                    color: selected ? Colors.white : const Color(0xFF94A3B8),
                    size: 24,
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Text(
                      items[index].title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String title;

  const _NavItem(this.icon, this.title);
}
