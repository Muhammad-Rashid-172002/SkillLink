import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilllink_admin/theme/admin_design.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skilllink_admin/models/dashboard_stats.dart';
import 'package:skilllink_admin/screens/admin_credits_screen.dart';
import 'package:skilllink_admin/screens/admin_emergency_alerts_screen.dart';
import 'package:skilllink_admin/screens/admin_jobs_screen.dart';
import 'package:skilllink_admin/screens/admin_login_screen.dart';
import 'package:skilllink_admin/screens/admin_notifications_screen.dart';
import 'package:skilllink_admin/screens/admin_payment_requests_screen.dart';
import 'package:skilllink_admin/screens/admin_reports_screen.dart';
import 'package:skilllink_admin/screens/admin_reviews_screen.dart';
import 'package:skilllink_admin/screens/admin_settings_screen.dart';
import 'package:skilllink_admin/screens/admin_users_screen.dart';
import 'package:skilllink_admin/screens/admin_verification_requests_screen.dart';
import 'package:skilllink_admin/screens/admin_workers_screen.dart';
import 'package:skilllink_admin/services/admin_auth_service.dart';
import 'package:skilllink_admin/services/dashboard_service.dart';
import 'package:skilllink_admin/widgets/admin_sidebar.dart';
import 'package:skilllink_admin/widgets/dashboard_stat_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.admin,
    required this.authService,
  });

  final AdminProfile admin;
  final AdminAuthService authService;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DashboardService _dashboardService = DashboardService();

  late Future<DashboardStats> _statsFuture;
  int _selectedIndex = 0;

  static const _pageTitles = <String>[
    'Dashboard',
    'Users',
    'Workers',
    'Jobs',
    'Reviews',
    'Reports',
    'Emergency alerts',
    'Credits',
    'Payment requests',
    'Notifications',
    'Verifications',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _statsFuture = _dashboardService.loadStats();
  }

  void _refresh() {
    setState(() {
      _statsFuture = _dashboardService.loadStats();
    });
  }

  Future<void> _logout() async {
    await widget.authService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminCanvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 760;
          final compactSidebar =
              constraints.maxWidth >= 760 && constraints.maxWidth < 1100;

          if (mobile) {
            return Scaffold(
              backgroundColor: kAdminCanvas,
              drawer: Drawer(
                width: 270,
                child: AdminSidebar(
                  selectedIndex: _selectedIndex,
                  onSelected: (index) {
                    setState(() => _selectedIndex = index);
                    Navigator.pop(context);
                  },
                  adminName: widget.admin.name,
                  adminEmail: widget.admin.email,
                  onLogout: _logout,
                ),
              ),
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                elevation: 0,
                title: Text(
                  _pageTitles[_selectedIndex],
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              body: switch (_selectedIndex) {
                0 => _DashboardBody(
                  admin: widget.admin,
                  statsFuture: _statsFuture,
                  dashboardService: _dashboardService,
                  onRefresh: _refresh,
                  onOpen: (index) => setState(() => _selectedIndex = index),
                ),

                1 => const AdminUsersScreen(),

                2 => const AdminWorkersScreen(),

                3 => const AdminJobsScreen(),

                4 => const AdminReviewsScreen(),

                5 => const AdminReportsScreen(),

                6 => const AdminEmergencyAlertsScreen(),

                7 => const AdminCreditsScreen(),

                8 => const AdminPaymentRequestsScreen(),

                9 => const AdminNotificationsScreen(),

                10 => const AdminVerificationRequestsScreen(),

                11 => const AdminSettingsScreen(),

                _ => const SizedBox.shrink(),
              },
            );
          }

          return Row(
            children: [
              AdminSidebar(
                compact: compactSidebar,
                selectedIndex: _selectedIndex,
                onSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                adminName: widget.admin.name,
                adminEmail: widget.admin.email,
                onLogout: _logout,
              ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      title: _pageTitles[_selectedIndex],
                      admin: widget.admin,
                      onRefresh: _refresh,
                    ),
                    Expanded(
                      child: switch (_selectedIndex) {
                        0 => _DashboardBody(
                          admin: widget.admin,
                          statsFuture: _statsFuture,
                          dashboardService: _dashboardService,
                          onRefresh: _refresh,
                          onOpen: (index) =>
                              setState(() => _selectedIndex = index),
                        ),

                        1 => const AdminUsersScreen(),

                        2 => const AdminWorkersScreen(),

                        3 => const AdminJobsScreen(),

                        4 => const AdminReviewsScreen(),

                        5 => const AdminReportsScreen(),

                        6 => const AdminEmergencyAlertsScreen(),

                        7 => const AdminCreditsScreen(),

                        8 => const AdminPaymentRequestsScreen(),

                        9 => const AdminNotificationsScreen(),

                        10 => const AdminVerificationRequestsScreen(),

                        11 => const AdminSettingsScreen(),

                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.admin,
    required this.onRefresh,
  });

  final String title;
  final AdminProfile admin;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE6ECF2))),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          Container(height: 40, width: 1, color: const Color(0xFFE2E8F0)),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 20,
            backgroundColor: kAdminBrandSoft,
            child: Text(
              admin.name.isNotEmpty ? admin.name[0].toUpperCase() : 'A',
              style: GoogleFonts.inter(
                color: kAdminBrand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                admin.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                admin.role.replaceAll('_', ' '),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.admin,
    required this.statsFuture,
    required this.dashboardService,
    required this.onRefresh,
    required this.onOpen,
  });

  final AdminProfile admin;
  final Future<DashboardStats> statsFuture;
  final DashboardService dashboardService;
  final VoidCallback onRefresh;

  /// Opens a console section by its sidebar index.
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: FutureBuilder<DashboardStats>(
              future: statsFuture,
              builder: (context, snapshot) {
                final stats = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, ${admin.name.split(' ').first}',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here’s what needs your attention on SkillNova today.',
                      style: text.bodyMedium?.copyWith(color: kAdminTextMuted),
                    ),
                    const SizedBox(height: 24),
                    if (snapshot.hasError)
                      _ErrorCard(
                        message:
                            'We couldn’t load the dashboard numbers. Check the '
                            'connection and try again.',
                        onRetry: onRefresh,
                      )
                    else if (stats == null)
                      const _StatsLoadingGrid()
                    else ...[
                      _NeedsAttention(stats: stats, onOpen: onOpen),
                      const SizedBox(height: 28),
                      Text(
                        'Platform overview',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _KpiGrid(stats: stats, onOpen: onOpen),
                    ],
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 920) {
                          return Column(
                            children: [
                              _RecentJobsCard(service: dashboardService),
                              const SizedBox(height: 18),
                              _RecentUsersCard(service: dashboardService),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _RecentJobsCard(service: dashboardService),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 2,
                              child: _RecentUsersCard(
                                service: dashboardService,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The queues an admin acts on, each linking straight to its section.
class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.stats, required this.onOpen});

  final DashboardStats stats;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Identity verifications',
        stats.pendingVerifications,
        'waiting for review',
        Icons.verified_user_outlined,
        kAdminBrand,
        10,
      ),
      (
        'Payment proofs',
        stats.pendingPayments,
        'waiting for approval',
        Icons.receipt_long_outlined,
        kAdminWarning,
        8,
      ),
      (
        'Active SOS alerts',
        stats.activeEmergencyAlerts,
        'need immediate action',
        Icons.sos_rounded,
        kAdminDanger,
        6,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final (label, count, detail, icon, color, index) in items)
              SizedBox(
                width: width,
                child: _AttentionCard(
                  label: label,
                  count: count,
                  detail: detail,
                  icon: icon,
                  color: color,
                  onTap: () => onOpen(index),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.label,
    required this.count,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clear = count == 0;
    return Semantics(
      button: true,
      label: '$label: ${clear ? 'none' : '$count $detail'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: clear ? kAdminBorder : color.withValues(alpha: 0.45),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (clear ? kAdminTextMuted : color).withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: clear ? kAdminTextMuted : color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: text.labelLarge?.copyWith(
                          color: kAdminTextMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clear ? 'All clear' : '$count $detail',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: clear ? kAdminSuccess : kAdminText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: kAdminTextMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats, required this.onOpen});

  final DashboardStats stats;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final cards = [
      DashboardStatCard(
        title: 'Customers',
        value: '${stats.totalCustomers}',
        icon: Icons.person_outline_rounded,
        accent: kAdminBrand,
        subtitle: '${stats.totalUsers} accounts in total',
        onTap: () => onOpen(1),
      ),
      DashboardStatCard(
        title: 'Workers',
        value: '${stats.totalWorkers}',
        icon: Icons.engineering_outlined,
        accent: kAdminBrand,
        subtitle: 'Registered professionals',
        onTap: () => onOpen(2),
      ),
      DashboardStatCard(
        title: 'Open requests',
        value: '${stats.pendingJobs}',
        icon: Icons.schedule_rounded,
        accent: kAdminWarning,
        subtitle: 'Waiting for a professional',
        onTap: () => onOpen(3),
      ),
      DashboardStatCard(
        title: 'Jobs in progress',
        value: '${stats.activeJobs}',
        icon: Icons.play_circle_outline_rounded,
        accent: kAdminBrand,
        subtitle: 'Accepted, on the way or started',
        onTap: () => onOpen(3),
      ),
      DashboardStatCard(
        title: 'Completed jobs',
        value: '${stats.completedJobs}',
        icon: Icons.task_alt_rounded,
        accent: kAdminSuccess,
        subtitle: 'of ${stats.totalJobs} requests overall',
        onTap: () => onOpen(3),
      ),
      DashboardStatCard(
        title: 'Reviews',
        value: '${stats.totalReviews}',
        icon: Icons.star_outline_rounded,
        accent: kAdminWarning,
        subtitle: 'Left by customers',
        onTap: () => onOpen(4),
      ),
      DashboardStatCard(
        title: 'Credit transactions',
        value: '${stats.totalTransactions}',
        icon: Icons.account_balance_wallet_outlined,
        accent: kAdminBrand,
        subtitle: 'Purchases and lead spends',
        onTap: () => onOpen(7),
      ),
      DashboardStatCard(
        title: 'SOS alerts',
        value: '${stats.totalEmergencyAlerts}',
        icon: Icons.sos_rounded,
        accent: kAdminDanger,
        subtitle: '${stats.activeEmergencyAlerts} currently active',
        onTap: () => onOpen(6),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _RecentJobsCard extends StatelessWidget {
  const _RecentJobsCard({required this.service});

  final DashboardService service;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent Jobs',
      subtitle: 'Latest service requests',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.latestJobsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _InlineMessage(
              'We couldn’t load recent jobs. Refresh to try again.',
            );
          }

          if (!snapshot.hasData) {
            return const _InlineLoader();
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const _InlineMessage('No job requests yet.');
          }

          return Column(
            children: docs.map((doc) {
              final data = doc.data();
              final title = _firstText(data, [
                'serviceName',
                'category',
                'title',
              ], fallback: 'Service Job');
              final customer = _firstText(data, [
                'customerName',
                'userName',
                'name',
              ], fallback: 'Customer');
              final status = _firstText(data, ['status'], fallback: 'pending');

              return _JobRow(title: title, customer: customer, status: status);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _RecentUsersCard extends StatelessWidget {
  const _RecentUsersCard({required this.service});

  final DashboardService service;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'New Users',
      subtitle: 'Recently registered accounts',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.latestUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _InlineMessage(
              'We couldn’t load recent users. Refresh to try again.',
            );
          }

          if (!snapshot.hasData) {
            return const _InlineLoader();
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const _InlineMessage('No registered users yet.');
          }

          return Column(
            children: docs.map((doc) {
              final data = doc.data();
              final name = _firstText(data, [
                'name',
                'fullName',
                'displayName',
              ], fallback: 'SkillNova User');
              final email = _firstText(data, ['email'], fallback: 'No email');
              final role = _firstText(data, [
                'role',
                'userType',
              ], fallback: 'user');

              return _UserRow(name: name, email: email, role: role);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.title,
    required this.customer,
    required this.status,
  });

  final String title;
  final String customer;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Color(0xFF475569),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.replaceAll('_', ' ').toUpperCase(),
              style: GoogleFonts.inter(
                color: color,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.name, required this.email, required this.role});

  final String name;
  final String email;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: kAdminBrandSoft,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: GoogleFonts.inter(
                color: kAdminBrand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            role.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsLoadingGrid extends StatelessWidget {
  const _StatsLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: CircularProgressIndicator(color: kAdminBrand),
      ),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: CircularProgressIndicator(strokeWidth: 2.5, color: kAdminBrand),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF991B1B),
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _firstText(
  Map<String, dynamic> data,
  List<String> keys, {
  required String fallback,
}) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return fallback;
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return const Color(0xFF059669);
    case 'accepted':
    case 'on_the_way':
    case 'in_progress':
      return const Color(0xFF0891B2);
    case 'cancelled':
    case 'rejected':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFFD97706);
  }
}
