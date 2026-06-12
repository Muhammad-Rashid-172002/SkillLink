import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_screen.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore.dart';
import 'package:skill_link/screens/customer_screens/Profile_screen/Profile_scree.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/customer_home_screen.dart';

class CustomerBottomBar extends StatelessWidget {
  final int selectedIndex;

  const CustomerBottomBar({super.key, required this.selectedIndex});

  static const List<_NavItem> items = [
    _NavItem(Icons.dashboard_rounded, "Home"),
    _NavItem(Icons.map_rounded, "Explore"),
    _NavItem(Icons.request_page_rounded, "Request"),
    _NavItem(Icons.chat_rounded, "Chat"),
    _NavItem(Icons.person_rounded, "Profile"),
  ];

  void _navigate(BuildContext context, int index) {
    if (index == selectedIndex) return;

    Widget screen;

    switch (index) {
      case 0:
        screen = const CustomerHomeScreen();
        break;
      case 1:
        screen = const Explore();
        break;
      case 2:
        screen = const Request();
        break;
      case 3:
        screen = const CustomerChatScreen();
        break;
      case 4:
        screen = const CustomerProfileScreen();
        break;

      default:
        screen = const CustomerHomeScreen();
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
                color: selected ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(.30),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
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
