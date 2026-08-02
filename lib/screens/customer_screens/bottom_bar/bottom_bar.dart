import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_screen.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore.dart';
import 'package:skill_link/screens/customer_screens/Profile_screen/Profile_scree.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/customer_home_screen.dart';

class CustomerBottomBar extends StatelessWidget {
  final int selectedIndex;

  const CustomerBottomBar({
    super.key,
    required this.selectedIndex,
  });

  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _inactive = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.home_rounded,
      outlinedIcon: Icons.home_outlined,
      title: 'Home',
    ),
    _NavItem(
      icon: Icons.explore_rounded,
      outlinedIcon: Icons.explore_outlined,
      title: 'Explore',
    ),
    _NavItem(
      icon: Icons.add_task_rounded,
      outlinedIcon: Icons.add_task_outlined,
      title: 'Request',
      isPrimaryAction: true,
    ),
    _NavItem(
      icon: Icons.chat_bubble_rounded,
      outlinedIcon: Icons.chat_bubble_outline_rounded,
      title: 'Chat',
    ),
    _NavItem(
      icon: Icons.person_rounded,
      outlinedIcon: Icons.person_outline_rounded,
      title: 'Profile',
    ),
  ];

  void _navigate(
    BuildContext context,
    int index,
  ) {
    if (index == selectedIndex) {
      return;
    }

    final screen = _screenForIndex(index);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) =>
            screen,
        transitionDuration:
            const Duration(milliseconds: 280),
        reverseTransitionDuration:
            const Duration(milliseconds: 220),
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          final slide = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _screenForIndex(int index) {
    switch (index) {
      case 0:
        return const CustomerHomeScreen();

      case 1:
        return const Explore();

      case 2:
        return const Request();

      case 3:
        return const CustomerChatsScreen();

      case 4:
        return const CustomerProfileScreen();

      default:
        return const CustomerHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.sizeOf(context).width;

    final horizontalMargin =
        screenWidth < 370 ? 12.0 : 16.0;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        horizontalMargin,
        0,
        horizontalMargin,
        12,
      ),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.97),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: _border.withOpacity(0.85),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160F172A),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
            BoxShadow(
              color: Color(0x08FFFFFF),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: List.generate(
                _items.length,
                (index) {
                  final item = _items[index];
                  final selected =
                      selectedIndex == index;

                  return Expanded(
                    child: _NavButton(
                      item: item,
                      selected: selected,
                      onTap: () =>
                          _navigate(context, index),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() =>
      _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = widget.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration:
            const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(
            horizontal: 3,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CustomerBottomBar._primary,
                      CustomerBottomBar._secondary,
                    ],
                  )
                : null,
            color: selected
                ? null
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: CustomerBottomBar
                          ._primary
                          .withOpacity(0.23),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (selected)
                Positioned(
                  top: 5,
                  child: Container(
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withOpacity(0.78),
                      borderRadius:
                          BorderRadius.circular(3),
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 220,
                    ),
                    height: item.isPrimaryAction
                        ? 32
                        : 28,
                    width: item.isPrimaryAction
                        ? 32
                        : 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                              .withOpacity(0.14)
                          : item.isPrimaryAction
                              ? CustomerBottomBar
                                  ._primary
                                  .withOpacity(0.09)
                              : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Icon(
                      selected
                          ? item.icon
                          : item.outlinedIcon,
                      color: selected
                          ? Colors.white
                          : item.isPrimaryAction
                              ? CustomerBottomBar
                                  ._primary
                              : CustomerBottomBar
                                  ._inactive,
                      size: item.isPrimaryAction
                          ? 21
                          : 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(
                      milliseconds: 220,
                    ),
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : item.isPrimaryAction
                              ? CustomerBottomBar
                                  ._textPrimary
                              : CustomerBottomBar
                                  ._inactive,
                      fontSize: 9.2,
                      fontWeight: selected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      letterSpacing: -0.05,
                    ),
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData outlinedIcon;
  final String title;
  final bool isPrimaryAction;

  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.title,
    this.isPrimaryAction = false,
  });
}
