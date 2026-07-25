import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Chat/Chat_screen.dart';
import 'package:skill_link/screens/worker_screens/Map/Map_screen.dart';
import 'package:skill_link/screens/worker_screens/Wallat/Wallat_screen.dart';
import 'package:skill_link/screens/worker_screens/home_screen/worker_dashbaord.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerProfileScreen.dart';

class WorkerBottomBar extends StatelessWidget {
  final int selectedIndex;

  const WorkerBottomBar({
    super.key,
    required this.selectedIndex,
  });

  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF14B8A6);
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
      icon: Icons.location_on_rounded,
      outlinedIcon: Icons.location_on_outlined,
      title: 'Map',
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_rounded,
      outlinedIcon: Icons.account_balance_wallet_outlined,
      title: 'Wallet',
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
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
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
        return const WorkerHomeScreen();

      case 1:
        return const MapSreen();

      case 2:
        return const WallatScreen();

      case 3:
        return const ChatScreen();

      case 4:
        return const WorkerProfileScreen();

      default:
        return const WorkerHomeScreen();
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
        child: Row(
          children: List.generate(
            _items.length,
            (index) {
              final item = _items[index];
              final selected =
                  selectedIndex == index;

              return Expanded(
                child: _WorkerNavButton(
                  item: item,
                  selected: selected,
                  onTap: () =>
                      _navigate(context, index),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkerNavButton extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _WorkerNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_WorkerNavButton> createState() =>
      _WorkerNavButtonState();
}

class _WorkerNavButtonState
    extends State<_WorkerNavButton> {
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
                      WorkerBottomBar._primary,
                      WorkerBottomBar._secondary,
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
                      color: WorkerBottomBar
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
                              ? WorkerBottomBar
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
                              ? WorkerBottomBar
                                  ._primary
                              : WorkerBottomBar
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
                              ? WorkerBottomBar
                                  ._textPrimary
                              : WorkerBottomBar
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
