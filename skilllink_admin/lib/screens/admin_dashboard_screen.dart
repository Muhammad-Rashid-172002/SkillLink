import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skilllink_admin/models/dashboard_stats.dart';
import 'package:skilllink_admin/screens/admin_credits_screen.dart';
import 'package:skilllink_admin/screens/admin_jobs_screen.dart';
import 'package:skilllink_admin/screens/admin_login_screen.dart';
import 'package:skilllink_admin/screens/admin_notifications_screen.dart';
import 'package:skilllink_admin/screens/admin_reports_screen.dart';
import 'package:skilllink_admin/screens/admin_reviews_screen.dart';
import 'package:skilllink_admin/screens/admin_settings_screen.dart';
import 'package:skilllink_admin/screens/admin_users_screen.dart';
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
    'Credits',
    'Notifications',
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
      backgroundColor: const Color(0xFFF4F7FB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 760;
          final compactSidebar =
              constraints.maxWidth >= 760 && constraints.maxWidth < 1100;

          if (mobile) {
            return Scaffold(
              backgroundColor: const Color(0xFFF4F7FB),
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
                    fontWeight: FontWeight.w900,
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
                ),

                1 => const AdminUsersScreen(),

                2 => const AdminWorkersScreen(),

                3 => const AdminJobsScreen(),

                4 => const AdminReviewsScreen(),

                5 => const AdminReportsScreen(),

                6 => const AdminCreditsScreen(),

                7 => const AdminNotificationsScreen(),

                8 => const AdminSettingsScreen(),

                _ => _ComingSoonPage(title: _pageTitles[_selectedIndex]),
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
                        ),

                        1 => const AdminUsersScreen(),

                        2 => const AdminWorkersScreen(),

                        3 => const AdminJobsScreen(),

                        4 => const AdminReviewsScreen(),

                        5 => const AdminReportsScreen(),

                        6 => const AdminCreditsScreen(),

                        7 => const AdminNotificationsScreen(),

                        8 => const AdminSettingsScreen(),

                        _ => _ComingSoonPage(
                          title: _pageTitles[_selectedIndex],
                        ),
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
              fontWeight: FontWeight.w900,
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
            backgroundColor: const Color(0xFFE8F7ED),
            child: Text(
              admin.name.isNotEmpty ? admin.name[0].toUpperCase() : 'A',
              style: GoogleFonts.inter(
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w800,
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
  });

  final AdminProfile admin;
  final Future<DashboardStats> statsFuture;
  final DashboardService dashboardService;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeCard(adminName: admin.name),
            const SizedBox(height: 24),
            FutureBuilder<DashboardStats>(
              future: statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _StatsLoadingGrid();
                }

                if (snapshot.hasError) {
                  return _ErrorCard(
                    message:
                        'Dashboard data load nahi ho saka.\n${snapshot.error}',
                    onRetry: onRefresh,
                  );
                }

                final stats = snapshot.data!;

                final cards = <Widget>[
                  DashboardStatCard(
                    title: 'Total Users',
                    value: '${stats.totalUsers}',
                    icon: Icons.groups_2_rounded,
                    accent: const Color(0xFF2563EB),
                    subtitle: 'Registered platform users',
                  ),
                  DashboardStatCard(
                    title: 'Workers',
                    value: '${stats.totalWorkers}',
                    icon: Icons.engineering_rounded,
                    accent: const Color(0xFF16A34A),
                    subtitle: 'Service providers',
                  ),
                  DashboardStatCard(
                    title: 'Customers',
                    value: '${stats.totalCustomers}',
                    icon: Icons.person_rounded,
                    accent: const Color(0xFF7C3AED),
                    subtitle: 'Service customers',
                  ),
                  DashboardStatCard(
                    title: 'Total Jobs',
                    value: '${stats.totalJobs}',
                    icon: Icons.work_rounded,
                    accent: const Color(0xFFEA580C),
                    subtitle: 'All service requests',
                  ),
                  DashboardStatCard(
                    title: 'Pending Jobs',
                    value: '${stats.pendingJobs}',
                    icon: Icons.schedule_rounded,
                    accent: const Color(0xFFD97706),
                    subtitle: 'Waiting for a worker',
                  ),
                  DashboardStatCard(
                    title: 'Active Jobs',
                    value: '${stats.activeJobs}',
                    icon: Icons.play_circle_rounded,
                    accent: const Color(0xFF0891B2),
                    subtitle: 'Accepted or in progress',
                  ),
                  DashboardStatCard(
                    title: 'Completed Jobs',
                    value: '${stats.completedJobs}',
                    icon: Icons.task_alt_rounded,
                    accent: const Color(0xFF059669),
                    subtitle: 'Successfully completed',
                  ),
                  DashboardStatCard(
                    title: 'Reviews',
                    value: '${stats.totalReviews}',
                    icon: Icons.star_rounded,
                    accent: const Color(0xFFEAB308),
                    subtitle: 'Customer feedback',
                  ),
                ];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1180
                        ? 4
                        : constraints.maxWidth >= 760
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - ((columns - 1) * 16)) / columns;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: cards
                          .map((card) => SizedBox(width: width, child: card))
                          .toList(),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
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
                      child: _RecentUsersCard(service: dashboardService),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.adminName});

  final String adminName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -35,
            child: Icon(
              Icons.dashboard_customize_rounded,
              size: 145,
              color: Colors.white.withOpacity(0.09),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $adminName 👋',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yahan se aap SkillNova ki users, workers, jobs aur platform activity monitor kar sakte hain.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.white.withOpacity(0.82),
                ),
              ),
            ],
          ),
        ],
      ),
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
              'Recent jobs load nahi ho sake. createdAt index/field check karein.',
            );
          }

          if (!snapshot.hasData) {
            return const _InlineLoader();
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const _InlineMessage('Abhi koi job request nahi hai.');
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
              'Recent users load nahi ho sake. createdAt field check karein.',
            );
          }

          if (!snapshot.hasData) {
            return const _InlineLoader();
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const _InlineMessage('Abhi koi registered user nahi hai.');
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
              fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w900,
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
            backgroundColor: const Color(0xFFE8F7ED),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: GoogleFonts.inter(
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w900,
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
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
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
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFF16A34A),
        ),
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

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE6ECF2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction_rounded,
              size: 52,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(height: 16),
            Text(
              '$title module',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ye screen next step mein banayenge.',
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
          ],
        ),
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
