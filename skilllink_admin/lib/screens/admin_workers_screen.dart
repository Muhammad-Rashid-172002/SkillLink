import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/worker_management_service.dart';

enum WorkerFilter {
  all,
  verified,
  pending,
  rejected,
  blocked,
}

class AdminWorkersScreen extends StatefulWidget {
  const AdminWorkersScreen({super.key});

  @override
  State<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends State<AdminWorkersScreen> {
  final WorkerManagementService _service = WorkerManagementService();
  final TextEditingController _searchController = TextEditingController();

  WorkerFilter _selectedFilter = WorkerFilter.all;
  String _searchQuery = '';
  bool _gridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagedWorker> _applyFilters(List<ManagedWorker> workers) {
    final query = _searchQuery.trim().toLowerCase();

    return workers.where((worker) {
      final matchesSearch = query.isEmpty ||
          worker.name.toLowerCase().contains(query) ||
          worker.email.toLowerCase().contains(query) ||
          worker.phone.toLowerCase().contains(query) ||
          worker.skill.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        WorkerFilter.all => true,
        WorkerFilter.verified => worker.isVerified,
        WorkerFilter.pending =>
          !worker.isVerified && worker.verificationStatus == 'pending',
        WorkerFilter.rejected => worker.verificationStatus == 'rejected',
        WorkerFilter.blocked => worker.isBlocked,
      };

      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  Future<void> _verifyWorker(ManagedWorker worker) async {
    final confirmed = await _confirmationDialog(
      title: 'Verify worker?',
      message:
          '${worker.name} ko verified worker mark kiya jayega. Verify karne se pehle CNIC aur profile details check karein.',
      confirmText: 'Verify worker',
      confirmColor: const Color(0xFF16A34A),
      icon: Icons.verified_rounded,
    );

    if (confirmed != true) return;

    try {
      await _service.setVerificationStatus(
        workerId: worker.id,
        status: 'verified',
      );

      if (!mounted) return;
      _showMessage('${worker.name} successfully verify ho gaya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Worker verify nahi ho saka: $error',
        isError: true,
      );
    }
  }

  Future<void> _rejectWorker(ManagedWorker worker) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Reject verification',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${worker.name} ki verification reject karne ka reason likhein.',
                  style: GoogleFonts.inter(
                    height: 1.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Example: CNIC image unclear...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || reason.isEmpty) return;

    try {
      await _service.setVerificationStatus(
        workerId: worker.id,
        status: 'rejected',
        reason: reason,
      );

      if (!mounted) return;
      _showMessage('${worker.name} ki verification reject ho gayi.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Verification reject nahi ho saki: $error',
        isError: true,
      );
    }
  }

  Future<void> _setPending(ManagedWorker worker) async {
    try {
      await _service.setVerificationStatus(
        workerId: worker.id,
        status: 'pending',
      );

      if (!mounted) return;
      _showMessage('${worker.name} ko pending verification par move kar diya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Status update nahi ho saka: $error',
        isError: true,
      );
    }
  }

  Future<void> _toggleBlocked(ManagedWorker worker) async {
    final confirmed = await _confirmationDialog(
      title: worker.isBlocked ? 'Unblock worker?' : 'Block worker?',
      message: worker.isBlocked
          ? '${worker.name} dobara app use kar sakega.'
          : '${worker.name} ka account block ho jayega.',
      confirmText: worker.isBlocked ? 'Unblock' : 'Block worker',
      confirmColor: worker.isBlocked
          ? const Color(0xFF16A34A)
          : const Color(0xFFDC2626),
      icon: worker.isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
    );

    if (confirmed != true) return;

    try {
      await _service.setWorkerBlocked(
        workerId: worker.id,
        isBlocked: !worker.isBlocked,
      );

      if (!mounted) return;

      _showMessage(
        worker.isBlocked
            ? '${worker.name} unblock ho gaya.'
            : '${worker.name} block ho gaya.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Status update nahi ho saka: $error',
        isError: true,
      );
    }
  }

  Future<bool?> _confirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: confirmColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
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
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  void _showWorkerDetails(ManagedWorker worker) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _WorkerAvatar(worker: worker, radius: 38),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      worker.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (worker.isVerified) ...[
                                    const SizedBox(width: 7),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 21,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                worker.email,
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
                        _InfoTile(
                          label: 'Skill',
                          value: worker.skill,
                          icon: Icons.handyman_rounded,
                        ),
                        _InfoTile(
                          label: 'Experience',
                          value: worker.experience,
                          icon: Icons.workspace_premium_rounded,
                        ),
                        _InfoTile(
                          label: 'Phone',
                          value: worker.phone,
                          icon: Icons.phone_outlined,
                        ),
                        _InfoTile(
                          label: 'CNIC',
                          value: worker.cnic,
                          icon: Icons.badge_outlined,
                        ),
                        _InfoTile(
                          label: 'Rating',
                          value: worker.rating.toStringAsFixed(1),
                          icon: Icons.star_rounded,
                        ),
                        _InfoTile(
                          label: 'Completed jobs',
                          value: '${worker.completedJobs}',
                          icon: Icons.task_alt_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verification documents',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DocumentPreview(
                            title: 'CNIC Front',
                            imageUrl: worker.cnicFrontUrl,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _DocumentPreview(
                            title: 'CNIC Back',
                            imageUrl: worker.cnicBackUrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _rejectWorker(worker);
                            },
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(
                                color: Color(0xFFDC2626),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: worker.isVerified
                                ? null
                                : () {
                                    Navigator.pop(dialogContext);
                                    _verifyWorker(worker);
                                  },
                            icon: const Icon(Icons.verified_rounded),
                            label: Text(
                              worker.isVerified
                                  ? 'Already verified'
                                  : 'Verify worker',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                            ),
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
      stream: _service.workersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _WorkerErrorState(
            message: 'Workers load nahi ho sake.\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF16A34A),
            ),
          );
        }

        final allWorkers = snapshot.data!.docs
            .map(ManagedWorker.fromDocument)
            .toList();

        final filteredWorkers = _applyFilters(allWorkers);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WorkersHeader(
                total: allWorkers.length,
                verified:
                    allWorkers.where((worker) => worker.isVerified).length,
                pending: allWorkers
                    .where(
                      (worker) =>
                          !worker.isVerified &&
                          worker.verificationStatus == 'pending',
                    )
                    .length,
                blocked:
                    allWorkers.where((worker) => worker.isBlocked).length,
              ),
              const SizedBox(height: 22),
              _WorkersToolbar(
                controller: _searchController,
                selectedFilter: _selectedFilter,
                resultCount: filteredWorkers.length,
                gridView: _gridView,
                onSearchChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                onFilterChanged: (filter) {
                  setState(() => _selectedFilter = filter);
                },
                onViewChanged: (value) {
                  setState(() => _gridView = value);
                },
              ),
              const SizedBox(height: 18),
              if (filteredWorkers.isEmpty)
                const _EmptyWorkersState()
              else if (_gridView)
                _WorkersGrid(
                  workers: filteredWorkers,
                  onView: _showWorkerDetails,
                  onVerify: _verifyWorker,
                  onReject: _rejectWorker,
                  onPending: _setPending,
                  onToggleBlocked: _toggleBlocked,
                )
              else
                _WorkersTable(
                  workers: filteredWorkers,
                  onView: _showWorkerDetails,
                  onVerify: _verifyWorker,
                  onReject: _rejectWorker,
                  onPending: _setPending,
                  onToggleBlocked: _toggleBlocked,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkersHeader extends StatelessWidget {
  const _WorkersHeader({
    required this.total,
    required this.verified,
    required this.pending,
    required this.blocked,
  });

  final int total;
  final int verified;
  final int pending;
  final int blocked;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _WorkerStatCard(
        title: 'Total Workers',
        value: '$total',
        icon: Icons.engineering_rounded,
        color: const Color(0xFF2563EB),
      ),
      _WorkerStatCard(
        title: 'Verified',
        value: '$verified',
        icon: Icons.verified_rounded,
        color: const Color(0xFF16A34A),
      ),
      _WorkerStatCard(
        title: 'Pending',
        value: '$pending',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFD97706),
      ),
      _WorkerStatCard(
        title: 'Blocked',
        value: '$blocked',
        icon: Icons.block_rounded,
        color: const Color(0xFFDC2626),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Worker Verification',
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Worker profiles, skills aur verification documents review karein.',
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

class _WorkerStatCard extends StatelessWidget {
  const _WorkerStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
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
            height: 46,
            width: 46,
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
                title,
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

class _WorkersToolbar extends StatelessWidget {
  const _WorkersToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.gridView,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final WorkerFilter selectedFilter;
  final int resultCount;
  final bool gridView;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<WorkerFilter> onFilterChanged;
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
          final compact = constraints.maxWidth < 920;

          final search = SizedBox(
            width: compact ? double.infinity : 320,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search worker, email, phone or skill...',
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
            children: WorkerFilter.values.map((filter) {
              final selected = selectedFilter == filter;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onFilterChanged(filter),
                label: Text(_workerFilterLabel(filter)),
                selectedColor:
                    const Color(0xFF16A34A).withOpacity(0.12),
                backgroundColor: const Color(0xFFF8FAFC),
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
                '$resultCount workers',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              _ViewToggleButton(
                icon: Icons.table_rows_rounded,
                selected: !gridView,
                onTap: () => onViewChanged(false),
              ),
              const SizedBox(width: 6),
              _ViewToggleButton(
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
                search,
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
              search,
              const SizedBox(width: 16),
              Expanded(child: filters),
              const SizedBox(width: 10),
              viewControls,
            ],
          );
        },
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
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

class _WorkersTable extends StatelessWidget {
  const _WorkersTable({
    required this.workers,
    required this.onView,
    required this.onVerify,
    required this.onReject,
    required this.onPending,
    required this.onToggleBlocked,
  });

  final List<ManagedWorker> workers;
  final ValueChanged<ManagedWorker> onView;
  final ValueChanged<ManagedWorker> onVerify;
  final ValueChanged<ManagedWorker> onReject;
  final ValueChanged<ManagedWorker> onPending;
  final ValueChanged<ManagedWorker> onToggleBlocked;

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
          dataRowMinHeight: 72,
          dataRowMaxHeight: 80,
          horizontalMargin: 20,
          columnSpacing: 28,
          columns: const [
            DataColumn(label: _TableHeading('WORKER')),
            DataColumn(label: _TableHeading('SKILL')),
            DataColumn(label: _TableHeading('RATING')),
            DataColumn(label: _TableHeading('JOBS')),
            DataColumn(label: _TableHeading('VERIFICATION')),
            DataColumn(label: _TableHeading('STATUS')),
            DataColumn(label: _TableHeading('ACTIONS')),
          ],
          rows: workers.map((worker) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 230,
                    child: Row(
                      children: [
                        _WorkerAvatar(worker: worker, radius: 21),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      worker.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (worker.isVerified) ...[
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 15,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                worker.email,
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
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(
                      worker.skill,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                DataCell(_RatingLabel(rating: worker.rating)),
                DataCell(
                  Text(
                    '${worker.completedJobs}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                DataCell(
                  _VerificationBadge(
                    status: worker.verificationStatus,
                    isVerified: worker.isVerified,
                  ),
                ),
                DataCell(_BlockedBadge(isBlocked: worker.isBlocked)),
                DataCell(
                  _WorkerActions(
                    worker: worker,
                    onView: onView,
                    onVerify: onVerify,
                    onReject: onReject,
                    onPending: onPending,
                    onToggleBlocked: onToggleBlocked,
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

class _WorkersGrid extends StatelessWidget {
  const _WorkersGrid({
    required this.workers,
    required this.onView,
    required this.onVerify,
    required this.onReject,
    required this.onPending,
    required this.onToggleBlocked,
  });

  final List<ManagedWorker> workers;
  final ValueChanged<ManagedWorker> onView;
  final ValueChanged<ManagedWorker> onVerify;
  final ValueChanged<ManagedWorker> onReject;
  final ValueChanged<ManagedWorker> onPending;
  final ValueChanged<ManagedWorker> onToggleBlocked;

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
          children: workers.map((worker) {
            return SizedBox(
              width: width,
              child: _WorkerCard(
                worker: worker,
                onView: onView,
                onVerify: onVerify,
                onReject: onReject,
                onPending: onPending,
                onToggleBlocked: onToggleBlocked,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({
    required this.worker,
    required this.onView,
    required this.onVerify,
    required this.onReject,
    required this.onPending,
    required this.onToggleBlocked,
  });

  final ManagedWorker worker;
  final ValueChanged<ManagedWorker> onView;
  final ValueChanged<ManagedWorker> onVerify;
  final ValueChanged<ManagedWorker> onReject;
  final ValueChanged<ManagedWorker> onPending;
  final ValueChanged<ManagedWorker> onToggleBlocked;

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
            child: _WorkerActions(
              worker: worker,
              onView: onView,
              onVerify: onVerify,
              onReject: onReject,
              onPending: onPending,
              onToggleBlocked: onToggleBlocked,
            ),
          ),
          _WorkerAvatar(worker: worker, radius: 36),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  worker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (worker.isVerified) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF2563EB),
                  size: 17,
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            worker.skill,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF16A34A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              _VerificationBadge(
                status: worker.verificationStatus,
                isVerified: worker.isVerified,
              ),
              _BlockedBadge(isBlocked: worker.isBlocked),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  icon: Icons.star_rounded,
                  label: 'Rating',
                  value: worker.rating.toStringAsFixed(1),
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.task_alt_rounded,
                  label: 'Jobs',
                  value: '${worker.completedJobs}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onView(worker),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Review profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerActions extends StatelessWidget {
  const _WorkerActions({
    required this.worker,
    required this.onView,
    required this.onVerify,
    required this.onReject,
    required this.onPending,
    required this.onToggleBlocked,
  });

  final ManagedWorker worker;
  final ValueChanged<ManagedWorker> onView;
  final ValueChanged<ManagedWorker> onVerify;
  final ValueChanged<ManagedWorker> onReject;
  final ValueChanged<ManagedWorker> onPending;
  final ValueChanged<ManagedWorker> onToggleBlocked;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Worker actions',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView(worker);
            break;
          case 'verify':
            onVerify(worker);
            break;
          case 'reject':
            onReject(worker);
            break;
          case 'pending':
            onPending(worker);
            break;
          case 'block':
            onToggleBlocked(worker);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'view',
          child: _ActionMenuItem(
            icon: Icons.visibility_outlined,
            text: 'View profile',
          ),
        ),
        if (!worker.isVerified)
          const PopupMenuItem(
            value: 'verify',
            child: _ActionMenuItem(
              icon: Icons.verified_outlined,
              text: 'Verify worker',
            ),
          ),
        const PopupMenuItem(
          value: 'reject',
          child: _ActionMenuItem(
            icon: Icons.cancel_outlined,
            text: 'Reject verification',
            danger: true,
          ),
        ),
        if (worker.verificationStatus != 'pending')
          const PopupMenuItem(
            value: 'pending',
            child: _ActionMenuItem(
              icon: Icons.hourglass_top_rounded,
              text: 'Move to pending',
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'block',
          child: _ActionMenuItem(
            icon: worker.isBlocked
                ? Icons.lock_open_rounded
                : Icons.block_rounded,
            text: worker.isBlocked ? 'Unblock worker' : 'Block worker',
            danger: !worker.isBlocked,
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

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({
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

class _WorkerAvatar extends StatelessWidget {
  const _WorkerAvatar({
    required this.worker,
    required this.radius,
  });

  final ManagedWorker worker;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = worker.photoUrl;

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8F7ED),
      backgroundImage: photo != null ? NetworkImage(photo) : null,
      child: photo == null
          ? Text(
              worker.name.isNotEmpty
                  ? worker.name[0].toUpperCase()
                  : 'W',
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

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({
    required this.status,
    required this.isVerified,
  });

  final String status;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final normalized = isVerified ? 'verified' : status.toLowerCase();

    final color = switch (normalized) {
      'verified' => const Color(0xFF16A34A),
      'rejected' => const Color(0xFFDC2626),
      _ => const Color(0xFFD97706),
    };

    final text = switch (normalized) {
      'verified' => 'VERIFIED',
      'rejected' => 'REJECTED',
      _ => 'PENDING',
    };

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
        text,
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _BlockedBadge extends StatelessWidget {
  const _BlockedBadge({required this.isBlocked});

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

class _RatingLabel extends StatelessWidget {
  const _RatingLabel({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star_rounded,
          size: 17,
          color: Color(0xFFEAB308),
        ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF16A34A),
          size: 20,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 215,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    required this.title,
    required this.imageUrl,
  });

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.image_not_supported_outlined,
                  color: Color(0xFF94A3B8),
                  size: 34,
                ),
                const SizedBox(height: 9),
                Text(
                  '$title not uploaded',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF94A3B8),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.58),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
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

class _EmptyWorkersState extends StatelessWidget {
  const _EmptyWorkersState();

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
            Icons.engineering_outlined,
            size: 58,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(
            'No workers found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search ya filter ke mutabiq koi worker nahi mila.',
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

class _WorkerErrorState extends StatelessWidget {
  const _WorkerErrorState({required this.message});

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

String _workerFilterLabel(WorkerFilter filter) {
  switch (filter) {
    case WorkerFilter.all:
      return 'All';
    case WorkerFilter.verified:
      return 'Verified';
    case WorkerFilter.pending:
      return 'Pending';
    case WorkerFilter.rejected:
      return 'Rejected';
    case WorkerFilter.blocked:
      return 'Blocked';
  }
}
