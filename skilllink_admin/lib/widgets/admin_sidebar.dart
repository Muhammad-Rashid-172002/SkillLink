import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skilllink_admin/theme/admin_design.dart';

/// Primary admin navigation, grouped by job-to-be-done. Item indices match
/// the page switch in the dashboard shell and must not be reordered.
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

  static const _groups = <(String, List<_SidebarItemData>)>[
    (
      'Overview',
      [_SidebarItemData(0, 'Dashboard', Icons.space_dashboard_outlined)],
    ),
    (
      'People',
      [
        _SidebarItemData(1, 'Users', Icons.groups_2_outlined),
        _SidebarItemData(2, 'Workers', Icons.engineering_outlined),
        _SidebarItemData(
          10,
          'Verifications',
          Icons.verified_user_outlined,
          pending: _PendingQueue.verifications,
        ),
      ],
    ),
    (
      'Operations',
      [
        _SidebarItemData(3, 'Jobs', Icons.work_outline_rounded),
        _SidebarItemData(4, 'Reviews', Icons.star_outline_rounded),
        _SidebarItemData(5, 'Reports', Icons.flag_outlined),
        _SidebarItemData(
          6,
          'Emergency alerts',
          Icons.sos_rounded,
          emergency: true,
        ),
      ],
    ),
    (
      'Finance',
      [
        _SidebarItemData(7, 'Credits', Icons.account_balance_wallet_outlined),
        _SidebarItemData(
          8,
          'Payment requests',
          Icons.receipt_long_outlined,
          pending: _PendingQueue.payments,
        ),
      ],
    ),
    (
      'System',
      [
        _SidebarItemData(9, 'Notifications', Icons.campaign_outlined),
        _SidebarItemData(11, 'Settings', Icons.settings_outlined),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: compact ? 84 : 264,
      color: kAdminInk,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 20,
                22,
                compact ? 18 : 20,
                18,
              ),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 40,
                      height: 40,
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
                            'SkillNova',
                            style: text.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Admin console',
                            style: text.bodySmall?.copyWith(
                              color: const Color(0xFF98A2B3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  for (final (title, items) in _groups) ...[
                    if (!compact)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                        child: Text(
                          title.toUpperCase(),
                          style: text.labelSmall?.copyWith(
                            color: const Color(0xFF667085),
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _SidebarTile(
                          compact: compact,
                          selected: selectedIndex == item.index,
                          item: item,
                          onTap: () => onSelected(item.index),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(color: Color(0xFF1D2939), height: 1),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: compact
                  ? IconButton(
                      tooltip: 'Sign out',
                      onPressed: onLogout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFD0D5DD),
                      ),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: kAdminBrand,
                          child: Text(
                            adminName.isEmpty
                                ? 'A'
                                : adminName[0].toUpperCase(),
                            style: text.labelLarge?.copyWith(
                              color: Colors.white,
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
                                style: text.labelLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                adminEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  color: const Color(0xFF98A2B3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sign out',
                          onPressed: onLogout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFD0D5DD),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PendingQueue { verifications, payments }

class _SidebarItemData {
  const _SidebarItemData(
    this.index,
    this.label,
    this.icon, {
    this.emergency = false,
    this.pending,
  });

  final int index;
  final String label;
  final IconData icon;
  final bool emergency;
  final _PendingQueue? pending;
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
    final text = Theme.of(context).textTheme;
    final foreground = selected
        ? Colors.white
        : item.emergency
        ? const Color(0xFFFDA29B)
        : const Color(0xFFD0D5DD);
    final tile = Material(
      color: selected ? const Color(0xFF1D2939) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
          decoration: selected
              ? const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: kAdminBrand, width: 3),
                  ),
                )
              : null,
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(item.icon, size: 20, color: foreground),
              if (!compact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (item.pending != null) _PendingBadge(queue: item.pending!),
              ],
            ],
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: compact ? Tooltip(message: item.label, child: tile) : tile,
    );
  }
}

/// Live count of items waiting for an admin decision.
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.queue});

  final _PendingQueue queue;

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final query = switch (queue) {
      _PendingQueue.verifications =>
        firestore
            .collection('verification_requests')
            .where('identityStatus', isEqualTo: 'pending'),
      _PendingQueue.payments =>
        firestore
            .collection('payment_requests')
            .where('status', isEqualTo: 'pending'),
    };
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.limit(99).snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: kAdminBrand,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            count >= 99 ? '99+' : '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
