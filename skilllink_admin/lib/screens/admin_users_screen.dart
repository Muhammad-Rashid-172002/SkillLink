import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skilllink_admin/screens/admin_user_detail_screen.dart';
import 'package:skilllink_admin/services/ser_management_service.dart';
import 'package:skilllink_admin/theme/admin_design.dart';
import 'package:skilllink_admin/widgets/user_deletion_dialogs.dart';

/// Admin > Users: overview, search/filter, details, suspension and
/// permanent deletion (single and bulk). All account changes are executed
/// by server-side Cloud Functions that re-check admin rights.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.gateway, this.now});

  /// Injected in tests; defaults to Firebase.
  final UserAdminGateway? gateway;

  /// Clock for "recently registered" (tests).
  final DateTime Function()? now;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const int pageSize = 20;

  late final UserAdminGateway _gateway =
      widget.gateway ?? UserManagementService();
  late final Stream<List<ManagedUser>> _users = _gateway.watchUsers();
  final _search = TextEditingController();

  UserListFilter _filter = UserListFilter.all;
  UserTypeFilter _type = UserTypeFilter.all;
  UserSort _sort = UserSort.newest;
  int _page = 0;
  final Set<String> _selected = {};
  final Set<String> _working = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  UserQuery get _query => UserQuery(
    filter: _filter,
    type: _type,
    search: _search.text,
    sort: _sort,
  );

  void _changed(VoidCallback update) => setState(() {
    update();
    _page = 0;
    _selected.clear();
  });

  bool _canDelete(ManagedUser user) =>
      user.id != _gateway.currentAdminUid && !_working.contains(user.id);

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? kAdminDanger : null,
      ),
    );
  }

  Future<void> _openDetails(ManagedUser user) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => AdminUserDetailScreen(user: user, gateway: _gateway),
      ),
    );
  }

  Future<void> _toggleSuspension(ManagedUser user) async {
    final suspend = !user.isSuspended;
    final reason = await showReasonDialog(
      context,
      title: suspend ? 'Suspend this account?' : 'Reactivate account?',
      message: suspend
          ? '${user.displayName} will be signed out and cannot use SkillNova '
                'until reactivated.'
          : '${user.displayName} will be able to sign in again.',
      confirmLabel: suspend ? 'Suspend' : 'Reactivate',
      askReason: suspend,
      danger: suspend,
      fieldKey: const Key('suspend-reason'),
      confirmKey: const Key('suspend-confirm'),
    );
    if (reason == null || !mounted) return;
    setState(() => _working.add(user.id));
    try {
      await _gateway.setAccountStatus(
        user.id,
        suspended: suspend,
        reason: reason,
      );
      _toast(suspend ? 'Account suspended.' : 'Account reactivated.');
    } catch (_) {
      _toast('The account status could not be changed.', error: true);
    } finally {
      if (mounted) setState(() => _working.remove(user.id));
    }
  }

  Future<void> _delete(ManagedUser user) async {
    if (!_canDelete(user)) return;
    final request = await showDeleteUserDialog(context, user);
    if (request == null || !mounted) return;
    setState(() => _working.add(user.id));
    final outcome = await _gateway.deleteUser(
      user.id,
      reason: request.reason,
      detail: request.detail,
    );
    if (!mounted) return;
    setState(() {
      _working.remove(user.id);
      if (outcome.succeeded) _selected.remove(user.id);
    });
    _toast(
      outcome.succeeded
          ? '${user.displayName} was deleted permanently.'
          : outcome.description,
      error: !outcome.succeeded,
    );
  }

  Future<void> _bulkDelete(List<ManagedUser> all) async {
    final users = all.where((u) => _selected.contains(u.id)).toList();
    if (users.isEmpty) return;
    if (users.length > UserManagementService.maxBulkSelection) {
      _toast(
        'Select at most ${UserManagementService.maxBulkSelection} accounts '
        'at a time.',
        error: true,
      );
      return;
    }
    final request = await showBulkDeleteDialog(context, users);
    if (request == null || !mounted) return;
    final outcome = await runBulkDeletion(
      context,
      gateway: _gateway,
      users: users,
      request: request,
    );
    if (!mounted || outcome == null) return;
    setState(() {
      for (final result in outcome.results) {
        if (result.succeeded) _selected.remove(result.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ManagedUser>>(
      stream: _users,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _StateMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Users could not be loaded',
            message: 'Check your connection and refresh the page.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: kAdminBrand),
          );
        }
        final all = snapshot.data!;
        final stats = UserStats.of(all, now: widget.now?.call());
        final filtered = _query.apply(all);
        final pages = (filtered.length / pageSize).ceil().clamp(1, 1 << 30);
        final page = _page.clamp(0, pages - 1);
        final visible = filtered.skip(page * pageSize).take(pageSize).toList();
        final selectable = filtered.where(_canDelete).toList();
        final allSelected =
            selectable.isNotEmpty &&
            selectable.every((u) => _selected.contains(u.id));

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1080;
            final pad = constraints.maxWidth < 600 ? 16.0 : 28.0;
            return ListView(
              padding: EdgeInsets.all(pad),
              children: [
                const _Header(),
                const SizedBox(height: 18),
                _StatsGrid(
                  stats: stats,
                  onSelect: (filter) => _changed(() => _filter = filter),
                ),
                const SizedBox(height: 18),
                _Toolbar(
                  search: _search,
                  filter: _filter,
                  type: _type,
                  sort: _sort,
                  results: filtered.length,
                  onSearch: () => _changed(() {}),
                  onFilter: (value) => _changed(() => _filter = value),
                  onType: (value) => _changed(() => _type = value),
                  onSort: (value) => setState(() => _sort = value),
                ),
                const SizedBox(height: 12),
                _SelectionBar(
                  selectedCount: _selected.length,
                  selectableCount: selectable.length,
                  allSelected: allSelected,
                  onSelectAll: (value) => setState(() {
                    if (value) {
                      _selected.addAll(selectable.map((u) => u.id));
                    } else {
                      _selected.clear();
                    }
                  }),
                  onDelete: () => _bulkDelete(all),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  _StateMessage(
                    icon: Icons.person_search_rounded,
                    title: all.isEmpty ? 'No users yet' : 'No matching users',
                    message: all.isEmpty
                        ? 'People who sign up in the app will appear here.'
                        : 'Try another search or filter.',
                  )
                else if (wide)
                  _UsersTable(
                    users: visible,
                    selected: _selected,
                    working: _working,
                    canDelete: _canDelete,
                    onSelect: (user, value) => setState(() {
                      value
                          ? _selected.add(user.id)
                          : _selected.remove(user.id);
                    }),
                    onView: _openDetails,
                    onSuspend: _toggleSuspension,
                    onDelete: _delete,
                  )
                else
                  Column(
                    children: [
                      for (final user in visible)
                        _UserCard(
                          user: user,
                          selected: _selected.contains(user.id),
                          busy: _working.contains(user.id),
                          canDelete: _canDelete(user),
                          onSelect: (value) => setState(() {
                            value
                                ? _selected.add(user.id)
                                : _selected.remove(user.id);
                          }),
                          onView: () => _openDetails(user),
                          onSuspend: () => _toggleSuspension(user),
                          onDelete: () => _delete(user),
                        ),
                    ],
                  ),
                if (filtered.isNotEmpty)
                  _Pagination(
                    page: page,
                    pages: pages,
                    total: filtered.length,
                    pageSize: pageSize,
                    onPage: (value) => setState(() => _page = value),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------------ parts

TextStyle _muted(double size) =>
    GoogleFonts.inter(fontSize: size, color: kAdminTextMuted);

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            color: kAdminText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review, verify, suspend or permanently delete customer and worker '
          'accounts.',
          style: _muted(13),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.onSelect});
  final UserStats stats;
  final ValueChanged<UserListFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final cards = <(String, int, IconData, Color, UserListFilter?)>[
      (
        'Total users',
        stats.total,
        Icons.groups_2_rounded,
        kAdminBrand,
        UserListFilter.all,
      ),
      (
        'Verified',
        stats.verified,
        Icons.verified_rounded,
        kAdminSuccess,
        UserListFilter.verified,
      ),
      (
        'Unverified',
        stats.unverified,
        Icons.help_outline_rounded,
        kAdminTextMuted,
        UserListFilter.unverified,
      ),
      (
        'Pending verification',
        stats.pending,
        Icons.hourglass_top_rounded,
        kAdminWarning,
        UserListFilter.pending,
      ),
      (
        'Rejected',
        stats.rejected,
        Icons.cancel_outlined,
        kAdminDanger,
        UserListFilter.rejected,
      ),
      (
        'Suspended',
        stats.suspended,
        Icons.block_rounded,
        kAdminDanger,
        UserListFilter.suspended,
      ),
      (
        'New this week',
        stats.recent,
        Icons.fiber_new_rounded,
        kAdminInfo,
        null,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 560
            ? 3
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, value, icon, color, filter) in cards)
              SizedBox(
                width: width,
                child: Semantics(
                  button: filter != null,
                  label: '$label: $value',
                  // The InkWell below is hidden from assistive technology,
                  // so the semantics node carries the tap itself.
                  onTap: filter == null ? null : () => onSelect(filter),
                  excludeSemantics: true,
                  child: InkWell(
                    key: Key('stat-$label'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: filter == null ? null : () => onSelect(filter),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kAdminBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$value',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: kAdminText,
                                  ),
                                ),
                                Text(
                                  label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _muted(11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.filter,
    required this.type,
    required this.sort,
    required this.results,
    required this.onSearch,
    required this.onFilter,
    required this.onType,
    required this.onSort,
  });

  final TextEditingController search;
  final UserListFilter filter;
  final UserTypeFilter type;
  final UserSort sort;
  final int results;
  final VoidCallback onSearch;
  final ValueChanged<UserListFilter> onFilter;
  final ValueChanged<UserTypeFilter> onType;
  final ValueChanged<UserSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  key: const Key('user-search'),
                  controller: search,
                  onChanged: (_) => onSearch(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search name, email, phone or user ID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              DropdownButton<UserTypeFilter>(
                key: const Key('type-filter'),
                value: type,
                onChanged: (value) => value == null ? null : onType(value),
                items: [
                  for (final value in UserTypeFilter.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
              ),
              DropdownButton<UserSort>(
                key: const Key('sort'),
                value: sort,
                onChanged: (value) => value == null ? null : onSort(value),
                items: [
                  for (final value in UserSort.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
              ),
              Text(
                '$results ${results == 1 ? 'user' : 'users'}',
                key: const Key('result-count'),
                style: _muted(12.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in UserListFilter.values)
                ChoiceChip(
                  key: Key('filter-${value.name}'),
                  label: Text(value.label),
                  selected: filter == value,
                  onSelected: (_) => onFilter(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.selectableCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onDelete,
  });

  final int selectedCount;
  final int selectableCount;
  final bool allSelected;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              key: const Key('select-all'),
              value: allSelected,
              onChanged: selectableCount == 0
                  ? null
                  : (value) => onSelectAll(value ?? false),
            ),
            Flexible(
              child: Text(
                'Select all filtered ($selectableCount)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (selectedCount > 0)
          FilledButton.icon(
            key: const Key('bulk-delete'),
            style: FilledButton.styleFrom(backgroundColor: kAdminDanger),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_sweep_rounded),
            label: Text('Delete selected ($selectedCount)'),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Widget _verificationBadge(ManagedUser user) => switch (user.verification) {
  UserVerification.verified => const _Badge('Verified', kAdminSuccess),
  UserVerification.pending => const _Badge('Pending', kAdminWarning),
  UserVerification.rejected => const _Badge('Rejected', kAdminDanger),
  UserVerification.unverified => const _Badge('Unverified', kAdminTextMuted),
};

Widget _statusBadge(ManagedUser user) => user.isSuspended
    ? _Badge(user.accountStatusLabel, kAdminDanger)
    : const _Badge('Active', kAdminSuccess);

Widget _check(bool ok, String label) => Tooltip(
  message: '$label ${ok ? 'verified' : 'not verified'}',
  child: Icon(
    ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
    size: 18,
    color: ok ? kAdminSuccess : kAdminTextMuted,
    semanticLabel: '$label ${ok ? 'verified' : 'not verified'}',
  ),
);

String _date(DateTime? value) =>
    value == null ? '—' : DateFormat('d MMM yyyy').format(value);

class _Actions extends StatelessWidget {
  const _Actions({
    required this.user,
    required this.busy,
    required this.canDelete,
    required this.onView,
    required this.onSuspend,
    required this.onDelete,
  });

  final ManagedUser user;
  final bool busy;
  final bool canDelete;
  final VoidCallback onView;
  final VoidCallback onSuspend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View details',
          onPressed: onView,
          icon: const Icon(Icons.visibility_outlined),
        ),
        IconButton(
          tooltip: user.isSuspended ? 'Reactivate' : 'Suspend',
          onPressed: canDelete ? onSuspend : null,
          icon: Icon(
            user.isSuspended
                ? Icons.lock_open_rounded
                : Icons.pause_circle_outline_rounded,
          ),
        ),
        IconButton(
          key: Key('delete-${user.id}'),
          tooltip: canDelete
              ? 'Delete user'
              : 'You cannot delete your own account',
          onPressed: canDelete ? onDelete : null,
          color: kAdminDanger,
          icon: const Icon(Icons.delete_forever_rounded),
        ),
      ],
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.selected,
    required this.working,
    required this.canDelete,
    required this.onSelect,
    required this.onView,
    required this.onSuspend,
    required this.onDelete,
  });

  final List<ManagedUser> users;
  final Set<String> selected;
  final Set<String> working;
  final bool Function(ManagedUser) canDelete;
  final void Function(ManagedUser, bool) onSelect;
  final ValueChanged<ManagedUser> onView;
  final ValueChanged<ManagedUser> onSuspend;
  final ValueChanged<ManagedUser> onDelete;

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: kAdminTextMuted,
      letterSpacing: 0.4,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            // Fill the card on wide screens; scroll sideways when narrower.
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 66,
              columnSpacing: 16,
              horizontalMargin: 12,
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: Text('USER · EMAIL · PHONE', style: header)),
                DataColumn(label: Text('TYPE', style: header)),
                DataColumn(label: Text('REGISTERED', style: header)),
                DataColumn(label: Text('EMAIL / PHONE ✓', style: header)),
                DataColumn(label: Text('CNIC', style: header)),
                DataColumn(label: Text('VERIFICATION', style: header)),
                DataColumn(label: Text('STATUS', style: header)),
                DataColumn(label: Text('ACTIONS', style: header)),
              ],
              rows: [
                for (final user in users)
                  DataRow(
                    key: ValueKey('row-${user.id}'),
                    cells: [
                      DataCell(
                        Checkbox(
                          key: Key('select-${user.id}'),
                          value: selected.contains(user.id),
                          onChanged: canDelete(user)
                              ? (value) => onSelect(user, value ?? false)
                              : null,
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kAdminText,
                                ),
                              ),
                              Text(
                                [
                                  user.email.isEmpty ? 'No email' : user.email,
                                  if (user.phone.isNotEmpty) user.phone,
                                ].join(' · '),
                                overflow: TextOverflow.ellipsis,
                                style: _muted(12),
                              ),
                            ],
                          ),
                        ),
                        onTap: () => onView(user),
                      ),
                      DataCell(Text(user.roleLabel)),
                      DataCell(Text(_date(user.createdAt))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _check(user.emailVerified, 'Email'),
                            const SizedBox(width: 6),
                            _check(user.phoneVerified, 'Phone'),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(user.isWorker ? user.identityStatusLabel : '—'),
                      ),
                      DataCell(_verificationBadge(user)),
                      DataCell(_statusBadge(user)),
                      DataCell(
                        _Actions(
                          user: user,
                          busy: working.contains(user.id),
                          canDelete: canDelete(user),
                          onView: () => onView(user),
                          onSuspend: () => onSuspend(user),
                          onDelete: () => onDelete(user),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.selected,
    required this.busy,
    required this.canDelete,
    required this.onSelect,
    required this.onView,
    required this.onSuspend,
    required this.onDelete,
  });

  final ManagedUser user;
  final bool selected;
  final bool busy;
  final bool canDelete;
  final ValueChanged<bool> onSelect;
  final VoidCallback onView;
  final VoidCallback onSuspend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('card-${user.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? kAdminBrand : kAdminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: Key('select-${user.id}'),
            value: selected,
            onChanged: canDelete ? (value) => onSelect(value ?? false) : null,
          ),
          Expanded(
            child: InkWell(
              onTap: onView,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kAdminText,
                    ),
                  ),
                  Text(
                    user.email.isEmpty ? 'No email' : user.email,
                    overflow: TextOverflow.ellipsis,
                    style: _muted(12),
                  ),
                  if (user.phone.isNotEmpty)
                    Text(user.phone, style: _muted(12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Badge(user.roleLabel, kAdminInfo),
                      _verificationBadge(user),
                      _statusBadge(user),
                      Text(
                        'Joined ${_date(user.createdAt)}',
                        style: _muted(11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _check(user.emailVerified, 'Email'),
                          const SizedBox(width: 4),
                          Text('Email', style: _muted(11.5)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _check(user.phoneVerified, 'Phone'),
                          const SizedBox(width: 4),
                          Text('Phone', style: _muted(11.5)),
                        ],
                      ),
                      if (user.isWorker)
                        Text(
                          'CNIC: ${user.identityStatusLabel}',
                          style: _muted(11.5),
                        ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _Actions(
                      user: user,
                      busy: busy,
                      canDelete: canDelete,
                      onView: onView,
                      onSuspend: onSuspend,
                      onDelete: onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pages,
    required this.total,
    required this.pageSize,
    required this.onPage,
  });

  final int page;
  final int pages;
  final int total;
  final int pageSize;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final from = page * pageSize + 1;
    final to = ((page + 1) * pageSize).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$from–$to of $total', key: const Key('page-label')),
          IconButton(
            key: const Key('page-prev'),
            tooltip: 'Previous page',
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            key: const Key('page-next'),
            tooltip: 'Next page',
            onPressed: page < pages - 1 ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: kAdminTextMuted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kAdminText,
            ),
          ),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: _muted(13)),
        ],
      ),
    );
  }
}
