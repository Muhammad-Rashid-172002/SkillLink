import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skilllink_admin/services/ser_management_service.dart';


enum UserRoleFilter {
  all,
  customers,
  workers,
  blocked,
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final UserManagementService _service = UserManagementService();
  final TextEditingController _searchController = TextEditingController();

  UserRoleFilter _selectedFilter = UserRoleFilter.all;
  bool _gridView = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagedUser> _filterUsers(List<ManagedUser> users) {
    return users.where((user) {
      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.phone.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        UserRoleFilter.all => true,
        UserRoleFilter.customers => user.isCustomer,
        UserRoleFilter.workers => user.isWorker,
        UserRoleFilter.blocked => user.isBlocked,
      };

      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  Future<void> _toggleBlocked(ManagedUser user) async {
    final action = user.isBlocked ? 'unblock' : 'block';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            '${action[0].toUpperCase()}${action.substring(1)} user?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            user.isBlocked
                ? '${user.name} ka account dobara active ho jayega.'
                : '${user.name} app use nahi kar sakega jab tak aap unblock na karein.',
            style: GoogleFonts.inter(
              height: 1.5,
              color: const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: user.isBlocked
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: Text(
                user.isBlocked ? 'Unblock' : 'Block user',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.setUserBlocked(
        userId: user.id,
        isBlocked: !user.isBlocked,
      );

      if (!mounted) return;

      _showMessage(
        user.isBlocked
            ? '${user.name} unblock ho gaya.'
            : '${user.name} block ho gaya.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Status update nahi ho saka: $error',
        isError: true,
      );
    }
  }

  Future<void> _toggleVerified(ManagedUser user) async {
    try {
      await _service.setWorkerVerified(
        userId: user.id,
        isVerified: !user.isVerified,
      );

      if (!mounted) return;

      _showMessage(
        user.isVerified
            ? '${user.name} ki verification remove ho gayi.'
            : '${user.name} verify ho gaya.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Verification update nahi ho saki: $error',
        isError: true,
      );
    }
  }

  Future<void> _deleteUserDocument(ManagedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Delete Firestore profile?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Ye sirf Firestore users document delete karega. Firebase Authentication account automatically delete nahi hoga.',
            style: GoogleFonts.inter(
              height: 1.5,
              color: const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete profile'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteUserDocument(user.id);

      if (!mounted) return;

      _showMessage('${user.name} ka Firestore profile delete ho gaya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Profile delete nahi ho saka: $error',
        isError: true,
      );
    }
  }

  void _showUserDetails(ManagedUser user) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _UserAvatar(user: user, radius: 34),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _DetailChip(
                        icon: Icons.badge_outlined,
                        label: user.role.toUpperCase(),
                      ),
                      _DetailChip(
                        icon: Icons.phone_outlined,
                        label: user.phone,
                      ),
                      _DetailChip(
                        icon: Icons.calendar_today_outlined,
                        label: _formatDate(user.createdAt),
                      ),
                      _DetailChip(
                        icon: user.isBlocked
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        label: user.isBlocked ? 'BLOCKED' : 'ACTIVE',
                      ),
                      if (user.isWorker)
                        _DetailChip(
                          icon: Icons.verified_rounded,
                          label: user.isVerified
                              ? 'VERIFIED WORKER'
                              : 'NOT VERIFIED',
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Document ID',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    user.id,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.usersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _UsersErrorState(
            message: 'Users load nahi ho sake.\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF16A34A),
            ),
          );
        }

        final allUsers = snapshot.data!.docs
            .map(ManagedUser.fromDocument)
            .toList();

        final filteredUsers = _filterUsers(allUsers);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UsersHeader(
                totalUsers: allUsers.length,
                workers:
                    allUsers.where((user) => user.isWorker).length,
                customers:
                    allUsers.where((user) => user.isCustomer).length,
                blocked:
                    allUsers.where((user) => user.isBlocked).length,
              ),
              const SizedBox(height: 22),
              _UsersToolbar(
                controller: _searchController,
                selectedFilter: _selectedFilter,
                gridView: _gridView,
                resultCount: filteredUsers.length,
                onSearchChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                onFilterChanged: (value) {
                  setState(() => _selectedFilter = value);
                },
                onViewChanged: (value) {
                  setState(() => _gridView = value);
                },
              ),
              const SizedBox(height: 18),
              if (filteredUsers.isEmpty)
                const _EmptyUsersState()
              else if (_gridView)
                _UsersGrid(
                  users: filteredUsers,
                  onView: _showUserDetails,
                  onToggleBlocked: _toggleBlocked,
                  onToggleVerified: _toggleVerified,
                  onDelete: _deleteUserDocument,
                )
              else
                _UsersTable(
                  users: filteredUsers,
                  onView: _showUserDetails,
                  onToggleBlocked: _toggleBlocked,
                  onToggleVerified: _toggleVerified,
                  onDelete: _deleteUserDocument,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({
    required this.totalUsers,
    required this.workers,
    required this.customers,
    required this.blocked,
  });

  final int totalUsers;
  final int workers;
  final int customers;
  final int blocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Users Management',
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'SkillLink customers aur workers ko manage, verify aur monitor karein.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950
                ? 4
                : constraints.maxWidth >= 520
                    ? 2
                    : 1;

            final width =
                (constraints.maxWidth - ((columns - 1) * 14)) / columns;

            final cards = [
              _MiniStatCard(
                label: 'Total Users',
                value: '$totalUsers',
                icon: Icons.groups_2_rounded,
                color: const Color(0xFF2563EB),
              ),
              _MiniStatCard(
                label: 'Workers',
                value: '$workers',
                icon: Icons.engineering_rounded,
                color: const Color(0xFF16A34A),
              ),
              _MiniStatCard(
                label: 'Customers',
                value: '$customers',
                icon: Icons.person_rounded,
                color: const Color(0xFF7C3AED),
              ),
              _MiniStatCard(
                label: 'Blocked',
                value: '$blocked',
                icon: Icons.block_rounded,
                color: const Color(0xFFDC2626),
              ),
            ];

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Row(
        children: [
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsersToolbar extends StatelessWidget {
  const _UsersToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.gridView,
    required this.resultCount,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final UserRoleFilter selectedFilter;
  final bool gridView;
  final int resultCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<UserRoleFilter> onFilterChanged;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;

          final searchField = SizedBox(
            width: compact ? double.infinity : 330,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search name, email or phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF16A34A),
                    width: 1.6,
                  ),
                ),
              ),
            ),
          );

          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserRoleFilter.values.map((filter) {
              final selected = selectedFilter == filter;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onFilterChanged(filter),
                label: Text(_filterLabel(filter)),
                backgroundColor: const Color(0xFFF8FAFC),
                selectedColor:
                    const Color(0xFF16A34A).withOpacity(0.12),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFE2E8F0),
                ),
                labelStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF64748B),
                ),
              );
            }).toList(),
          );

          final viewControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$resultCount users',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              _ViewButton(
                icon: Icons.table_rows_rounded,
                selected: !gridView,
                onTap: () => onViewChanged(false),
              ),
              const SizedBox(width: 6),
              _ViewButton(
                icon: Icons.grid_view_rounded,
                selected: gridView,
                onTap: () => onViewChanged(true),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                searchField,
                const SizedBox(height: 14),
                filters,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: viewControls,
                ),
              ],
            );
          }

          return Row(
            children: [
              searchField,
              const SizedBox(width: 16),
              Expanded(child: filters),
              const SizedBox(width: 12),
              viewControls,
            ],
          );
        },
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF16A34A)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.onView,
    required this.onToggleBlocked,
    required this.onToggleVerified,
    required this.onDelete,
  });

  final List<ManagedUser> users;
  final ValueChanged<ManagedUser> onView;
  final ValueChanged<ManagedUser> onToggleBlocked;
  final ValueChanged<ManagedUser> onToggleVerified;
  final ValueChanged<ManagedUser> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFFF8FAFC),
          ),
          dataRowMinHeight: 70,
          dataRowMaxHeight: 78,
          horizontalMargin: 20,
          columnSpacing: 34,
          columns: const [
            DataColumn(label: _TableHeading('USER')),
            DataColumn(label: _TableHeading('ROLE')),
            DataColumn(label: _TableHeading('PHONE')),
            DataColumn(label: _TableHeading('STATUS')),
            DataColumn(label: _TableHeading('JOINED')),
            DataColumn(label: _TableHeading('ACTIONS')),
          ],
          rows: users.map((user) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 230,
                    child: Row(
                      children: [
                        _UserAvatar(user: user, radius: 21),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
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
                      ],
                    ),
                  ),
                ),
                DataCell(_RoleBadge(role: user.role)),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(
                      user.phone,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                DataCell(_StatusBadge(isBlocked: user.isBlocked)),
                DataCell(
                  Text(
                    _formatDate(user.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
                DataCell(
                  _UserActions(
                    user: user,
                    onView: onView,
                    onToggleBlocked: onToggleBlocked,
                    onToggleVerified: onToggleVerified,
                    onDelete: onDelete,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _UsersGrid extends StatelessWidget {
  const _UsersGrid({
    required this.users,
    required this.onView,
    required this.onToggleBlocked,
    required this.onToggleVerified,
    required this.onDelete,
  });

  final List<ManagedUser> users;
  final ValueChanged<ManagedUser> onView;
  final ValueChanged<ManagedUser> onToggleBlocked;
  final ValueChanged<ManagedUser> onToggleVerified;
  final ValueChanged<ManagedUser> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 820
                ? 3
                : constraints.maxWidth >= 540
                    ? 2
                    : 1;

        final width =
            (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: users.map((user) {
            return SizedBox(
              width: width,
              child: _UserCard(
                user: user,
                onView: onView,
                onToggleBlocked: onToggleBlocked,
                onToggleVerified: onToggleVerified,
                onDelete: onDelete,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onView,
    required this.onToggleBlocked,
    required this.onToggleVerified,
    required this.onDelete,
  });

  final ManagedUser user;
  final ValueChanged<ManagedUser> onView;
  final ValueChanged<ManagedUser> onToggleBlocked;
  final ValueChanged<ManagedUser> onToggleVerified;
  final ValueChanged<ManagedUser> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE6ECF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _UserActions(
              user: user,
              onView: onView,
              onToggleBlocked: onToggleBlocked,
              onToggleVerified: onToggleVerified,
              onDelete: onDelete,
            ),
          ),
          _UserAvatar(user: user, radius: 34),
          const SizedBox(height: 13),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              _RoleBadge(role: user.role),
              _StatusBadge(isBlocked: user.isBlocked),
              if (user.isWorker && user.isVerified)
                const _VerifiedBadge(),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  user.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 7),
              Text(
                _formatDate(user.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserActions extends StatelessWidget {
  const _UserActions({
    required this.user,
    required this.onView,
    required this.onToggleBlocked,
    required this.onToggleVerified,
    required this.onDelete,
  });

  final ManagedUser user;
  final ValueChanged<ManagedUser> onView;
  final ValueChanged<ManagedUser> onToggleBlocked;
  final ValueChanged<ManagedUser> onToggleVerified;
  final ValueChanged<ManagedUser> onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'User actions',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView(user);
            break;
          case 'block':
            onToggleBlocked(user);
            break;
          case 'verify':
            onToggleVerified(user);
            break;
          case 'delete':
            onDelete(user);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'view',
          child: _MenuItem(
            icon: Icons.visibility_outlined,
            text: 'View details',
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: _MenuItem(
            icon: user.isBlocked
                ? Icons.lock_open_rounded
                : Icons.block_rounded,
            text: user.isBlocked ? 'Unblock user' : 'Block user',
          ),
        ),
        if (user.isWorker)
          PopupMenuItem(
            value: 'verify',
            child: _MenuItem(
              icon: Icons.verified_outlined,
              text: user.isVerified
                  ? 'Remove verification'
                  : 'Verify worker',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: _MenuItem(
            icon: Icons.delete_outline_rounded,
            text: 'Delete profile',
            danger: true,
          ),
        ),
      ],
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Color(0xFF64748B),
          size: 20,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color =
        danger ? const Color(0xFFDC2626) : const Color(0xFF334155);

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.user,
    required this.radius,
  });

  final ManagedUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = user.photoUrl;

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8F7ED),
      backgroundImage:
          photo != null ? NetworkImage(photo) : null,
      child: photo == null
          ? Text(
              user.name.isNotEmpty
                  ? user.name[0].toUpperCase()
                  : 'U',
              style: GoogleFonts.inter(
                color: const Color(0xFF16A34A),
                fontSize: radius * 0.70,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final worker = role.toLowerCase() == 'worker';
    final color =
        worker ? const Color(0xFF16A34A) : const Color(0xFF7C3AED);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isBlocked});

  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
    final color = isBlocked
        ? const Color(0xFFDC2626)
        : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isBlocked ? 'BLOCKED' : 'ACTIVE',
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'VERIFIED',
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF2563EB),
        ),
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  const _TableHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF16A34A),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyUsersState extends StatelessWidget {
  const _EmptyUsersState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 70),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_search_rounded,
            size: 55,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(
            'No users found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search ya selected filter ke mutabiq koi user nahi mila.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersErrorState extends StatelessWidget {
  const _UsersErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFDA4AF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF991B1B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _filterLabel(UserRoleFilter filter) {
  switch (filter) {
    case UserRoleFilter.all:
      return 'All';
    case UserRoleFilter.customers:
      return 'Customers';
    case UserRoleFilter.workers:
      return 'Workers';
    case UserRoleFilter.blocked:
      return 'Blocked';
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  return DateFormat('dd MMM yyyy').format(date);
}
