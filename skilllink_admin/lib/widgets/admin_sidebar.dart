import 'package:cloud_firestore/cloud_firestore.dart';
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

  static const _items = <_SidebarItemData>[
    _SidebarItemData('Dashboard', Icons.dashboard_rounded),
    _SidebarItemData('Users', Icons.groups_2_rounded),
    _SidebarItemData('Workers', Icons.engineering_rounded),
    _SidebarItemData('Jobs', Icons.work_rounded),
    _SidebarItemData('Reviews', Icons.star_rounded),
    _SidebarItemData('Reports', Icons.analytics_rounded),
    _SidebarItemData('Emergency Alerts', Icons.sos_rounded, emergency: true),
    _SidebarItemData('Credits', Icons.account_balance_wallet_rounded),
    _SidebarItemData('Payment Requests', Icons.receipt_long_rounded),
    _SidebarItemData('Notifications', Icons.notifications_rounded),
    _SidebarItemData('Verification Requests', Icons.verified_user_rounded),
    _SidebarItemData('Settings', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 88 : 280,
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 20,
                20,
                compact ? 14 : 20,
                18,
              ),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SkillNova Admin',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Control Center',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final selected = selectedIndex == index;
                  return _SidebarTile(
                    compact: compact,
                    selected: selected,
                    item: item,
                    onTap: () => onSelected(index),
                  );
                },
              ),
            ),
            if (!compact)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: const Color(0xFFDCFCE7),
                      child: Text(
                        adminName.isEmpty ? 'A' : adminName[0].toUpperCase(),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF15803D),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            adminEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onLogout,
                      tooltip: 'Logout',
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFFCA5A5),
                        size: 19,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: IconButton(
                  onPressed: onLogout,
                  tooltip: 'Logout',
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFFCA5A5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.compact,
    required this.selected,
    required this.item,
    required this.onTap,
  });

  final bool compact;
  final bool selected;
  final _SidebarItemData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseColor = item.emergency
        ? const Color(0xFFEF4444)
        : const Color(0xFFCBD5E1);
    final selectedColor = item.emergency
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A);

    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 13),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withOpacity(0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: selectedColor.withOpacity(0.28))
                : null,
          ),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    item.icon,
                    size: 21,
                    color: selected ? selectedColor : baseColor,
                  ),
                  if (item.emergency)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('emergency_alerts')
                          .where(
                            'status',
                            whereIn: const ['active', 'investigating'],
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.docs.length ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF0F172A),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.inter(
                      color: selected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: selectedColor,
                    size: 18,
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!compact) return content;
    return Tooltip(message: item.title, child: content);
  }
}

class _SidebarItemData {
  const _SidebarItemData(this.title, this.icon, {this.emergency = false});
  final String title;
  final IconData icon;
  final bool emergency;
}
