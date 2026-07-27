import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.adminName,
    required this.adminEmail,
    required this.onLogout,
    this.compact = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String adminName;
  final String adminEmail;
  final VoidCallback onLogout;
  final bool compact;

  static const items = <_SidebarItem>[
    _SidebarItem('Dashboard', Icons.dashboard_rounded),
    _SidebarItem('Users', Icons.groups_2_rounded),
    _SidebarItem('Workers', Icons.engineering_rounded),
    _SidebarItem('Jobs', Icons.work_rounded),
    _SidebarItem('Reviews', Icons.star_rounded),
    _SidebarItem('Reports', Icons.report_problem_rounded),
    _SidebarItem('Credits', Icons.account_balance_wallet_rounded),
    _SidebarItem('Notifications', Icons.notifications_rounded),
    _SidebarItem('Settings', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 92 : 270,
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 20,
        22,
        compact ? 14 : 20,
        20,
      ),
      child: Column(
        children: [
          _Brand(compact: compact),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = selectedIndex == index;

                return Tooltip(
                  message: compact ? item.label : '',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 0 : 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF16A34A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: compact
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Icon(
                              item.icon,
                              size: 21,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                            if (!compact) ...[
                              const SizedBox(width: 12),
                              Text(
                                item.label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!compact)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF16A34A),
                    child: Text(
                      adminName.isNotEmpty
                          ? adminName.trim()[0].toUpperCase()
                          : 'A',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          adminEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: onLogout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFCBD5E1),
                      size: 19,
                    ),
                  ),
                ],
              ),
            )
          else
            IconButton(
              tooltip: 'Logout',
              onPressed: onLogout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFCBD5E1),
              ),
            ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          compact ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.link_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SkillNova',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'ADMIN CONSOLE',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 8,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SidebarItem {
  const _SidebarItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
