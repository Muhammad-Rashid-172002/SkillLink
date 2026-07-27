import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/job_management_service.dart';

enum JobFilter {
  all,
  pending,
  active,
  completed,
  cancelled,
}

class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  final JobManagementService _service = JobManagementService();
  final TextEditingController _searchController = TextEditingController();

  JobFilter _selectedFilter = JobFilter.all;
  String _searchQuery = '';
  bool _gridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagedJob> _applyFilters(List<ManagedJob> jobs) {
    final query = _searchQuery.trim().toLowerCase();

    return jobs.where((job) {
      final matchesSearch = query.isEmpty ||
          job.title.toLowerCase().contains(query) ||
          job.category.toLowerCase().contains(query) ||
          job.customerName.toLowerCase().contains(query) ||
          job.workerName.toLowerCase().contains(query) ||
          job.address.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        JobFilter.all => true,
        JobFilter.pending => job.isPending,
        JobFilter.active => job.isActive,
        JobFilter.completed => job.isCompleted,
        JobFilter.cancelled => job.isCancelled,
      };

      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  Future<void> _changeStatus(ManagedJob job) async {
    final selectedStatus = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String value = job.status;

        const statuses = <String>[
          'pending',
          'waiting_worker',
          'accepted',
          'on_the_way',
          'in_progress',
          'completed',
          'cancelled',
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Update job status',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: statuses.contains(value) ? value : 'pending',
                      items: statuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(_statusLabel(status)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue == null) return;
                        setDialogState(() => value = newValue);
                      },
                      decoration: InputDecoration(
                        labelText: 'Status',
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
                  onPressed: () => Navigator.pop(dialogContext, value),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update status'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedStatus == null || selectedStatus == job.status) return;

    try {
      await _service.updateJobStatus(
        jobId: job.id,
        status: selectedStatus,
      );

      if (!mounted) return;
      _showMessage('${job.title} ka status update ho gaya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Status update nahi ho saka: $error',
        isError: true,
      );
    }
  }

  Future<void> _cancelJob(ManagedJob job) async {
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
            'Cancel job',
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
                  '${job.title} cancel karne ka reason enter karein.',
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
                    hintText: 'Example: Suspicious request or policy violation...',
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
              child: const Text('Back'),
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
              child: const Text('Cancel job'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || reason.isEmpty) return;

    try {
      await _service.cancelJob(
        jobId: job.id,
        reason: reason,
      );

      if (!mounted) return;
      _showMessage('${job.title} cancel ho gaya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Job cancel nahi ho saka: $error',
        isError: true,
      );
    }
  }

  Future<void> _deleteJob(ManagedJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete job document?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Ye action Firestore se job permanently delete karega. Isay undo nahi kiya ja sakta.',
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
              child: const Text('Delete permanently'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteJob(job.id);

      if (!mounted) return;
      _showMessage('${job.title} delete ho gaya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Job delete nahi ho saka: $error',
        isError: true,
      );
    }
  }

  void _showJobDetails(ManagedJob job) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Container(
              padding: const EdgeInsets.all(28),
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
                        Container(
                          height: 58,
                          width: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF16A34A),
                                Color(0xFF0D9488),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.work_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.title,
                                style: GoogleFonts.inter(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                job.category,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF16A34A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: job.status),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        job.description,
                        style: GoogleFonts.inter(
                          height: 1.6,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _InfoTile(
                          label: 'Customer',
                          value: job.customerName,
                          icon: Icons.person_rounded,
                        ),
                        _InfoTile(
                          label: 'Customer phone',
                          value: job.customerPhone,
                          icon: Icons.phone_outlined,
                        ),
                        _InfoTile(
                          label: 'Worker',
                          value: job.workerName,
                          icon: Icons.engineering_rounded,
                        ),
                        _InfoTile(
                          label: 'Budget',
                          value: _formatBudget(job.budget),
                          icon: Icons.payments_outlined,
                        ),
                        _InfoTile(
                          label: 'Created',
                          value: _formatDateTime(job.createdAt),
                          icon: Icons.calendar_today_outlined,
                        ),
                        _InfoTile(
                          label: 'Location',
                          value: job.address,
                          icon: Icons.location_on_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Document ID',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      job.id,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF475569),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _cancelJob(job);
                            },
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel job'),
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
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _changeStatus(job);
                            },
                            icon: const Icon(Icons.sync_alt_rounded),
                            label: const Text('Update status'),
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
      stream: _service.jobsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _JobsErrorState(
            message: 'Jobs load nahi ho sake.\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF16A34A),
            ),
          );
        }

        final allJobs = snapshot.data!.docs
            .map(ManagedJob.fromDocument)
            .toList();

        final filteredJobs = _applyFilters(allJobs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _JobsHeader(
                total: allJobs.length,
                pending:
                    allJobs.where((job) => job.isPending).length,
                active:
                    allJobs.where((job) => job.isActive).length,
                completed:
                    allJobs.where((job) => job.isCompleted).length,
                cancelled:
                    allJobs.where((job) => job.isCancelled).length,
              ),
              const SizedBox(height: 22),
              _JobsToolbar(
                controller: _searchController,
                selectedFilter: _selectedFilter,
                resultCount: filteredJobs.length,
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
              if (filteredJobs.isEmpty)
                const _EmptyJobsState()
              else if (_gridView)
                _JobsGrid(
                  jobs: filteredJobs,
                  onView: _showJobDetails,
                  onStatus: _changeStatus,
                  onCancel: _cancelJob,
                  onDelete: _deleteJob,
                )
              else
                _JobsTable(
                  jobs: filteredJobs,
                  onView: _showJobDetails,
                  onStatus: _changeStatus,
                  onCancel: _cancelJob,
                  onDelete: _deleteJob,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _JobsHeader extends StatelessWidget {
  const _JobsHeader({
    required this.total,
    required this.pending,
    required this.active,
    required this.completed,
    required this.cancelled,
  });

  final int total;
  final int pending;
  final int active;
  final int completed;
  final int cancelled;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _JobStatCard(
        title: 'Total Jobs',
        value: '$total',
        icon: Icons.work_rounded,
        color: const Color(0xFF2563EB),
      ),
      _JobStatCard(
        title: 'Pending',
        value: '$pending',
        icon: Icons.schedule_rounded,
        color: const Color(0xFFD97706),
      ),
      _JobStatCard(
        title: 'Active',
        value: '$active',
        icon: Icons.play_circle_rounded,
        color: const Color(0xFF0891B2),
      ),
      _JobStatCard(
        title: 'Completed',
        value: '$completed',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF16A34A),
      ),
      _JobStatCard(
        title: 'Cancelled',
        value: '$cancelled',
        icon: Icons.cancel_rounded,
        color: const Color(0xFFDC2626),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jobs Management',
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'All service requests ko monitor, update aur manage karein.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1180
                ? 5
                : constraints.maxWidth >= 760
                    ? 3
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

class _JobStatCard extends StatelessWidget {
  const _JobStatCard({
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
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
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

class _JobsToolbar extends StatelessWidget {
  const _JobsToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.gridView,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final JobFilter selectedFilter;
  final int resultCount;
  final bool gridView;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<JobFilter> onFilterChanged;
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
          final compact = constraints.maxWidth < 930;

          final search = SizedBox(
            width: compact ? double.infinity : 340,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search job, customer, worker or location...',
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
            children: JobFilter.values.map((filter) {
              final selected = selectedFilter == filter;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onFilterChanged(filter),
                label: Text(_jobFilterLabel(filter)),
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

          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$resultCount jobs',
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
                search,
                const SizedBox(height: 14),
                filters,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: controls,
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
              controls,
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

class _JobsTable extends StatelessWidget {
  const _JobsTable({
    required this.jobs,
    required this.onView,
    required this.onStatus,
    required this.onCancel,
    required this.onDelete,
  });

  final List<ManagedJob> jobs;
  final ValueChanged<ManagedJob> onView;
  final ValueChanged<ManagedJob> onStatus;
  final ValueChanged<ManagedJob> onCancel;
  final ValueChanged<ManagedJob> onDelete;

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
          dataRowMinHeight: 74,
          dataRowMaxHeight: 82,
          horizontalMargin: 20,
          columnSpacing: 28,
          columns: const [
            DataColumn(label: _TableHeading('JOB')),
            DataColumn(label: _TableHeading('CUSTOMER')),
            DataColumn(label: _TableHeading('WORKER')),
            DataColumn(label: _TableHeading('BUDGET')),
            DataColumn(label: _TableHeading('STATUS')),
            DataColumn(label: _TableHeading('CREATED')),
            DataColumn(label: _TableHeading('ACTIONS')),
          ],
          rows: jobs.map((job) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 230,
                    child: Row(
                      children: [
                        Container(
                          height: 43,
                          width: 43,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7ED),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.handyman_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.title,
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
                                job.category,
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
                    width: 130,
                    child: Text(
                      job.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 130,
                    child: Text(
                      job.workerName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _formatBudget(job.budget),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                DataCell(_StatusBadge(status: job.status)),
                DataCell(
                  Text(
                    _formatDate(job.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
                DataCell(
                  _JobActions(
                    job: job,
                    onView: onView,
                    onStatus: onStatus,
                    onCancel: onCancel,
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

class _JobsGrid extends StatelessWidget {
  const _JobsGrid({
    required this.jobs,
    required this.onView,
    required this.onStatus,
    required this.onCancel,
    required this.onDelete,
  });

  final List<ManagedJob> jobs;
  final ValueChanged<ManagedJob> onView;
  final ValueChanged<ManagedJob> onStatus;
  final ValueChanged<ManagedJob> onCancel;
  final ValueChanged<ManagedJob> onDelete;

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
          children: jobs.map((job) {
            return SizedBox(
              width: width,
              child: _JobCard(
                job: job,
                onView: onView,
                onStatus: onStatus,
                onCancel: onCancel,
                onDelete: onDelete,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.onView,
    required this.onStatus,
    required this.onCancel,
    required this.onDelete,
  });

  final ManagedJob job;
  final ValueChanged<ManagedJob> onView;
  final ValueChanged<ManagedJob> onStatus;
  final ValueChanged<ManagedJob> onCancel;
  final ValueChanged<ManagedJob> onDelete;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF16A34A),
                      Color(0xFF0D9488),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.work_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Spacer(),
              _JobActions(
                job: job,
                onView: onView,
                onStatus: onStatus,
                onCancel: onCancel,
                onDelete: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            job.title,
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
            job.category,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 13),
          _StatusBadge(status: job.status),
          const SizedBox(height: 16),
          _CardInfoRow(
            icon: Icons.person_outline_rounded,
            value: job.customerName,
          ),
          const SizedBox(height: 9),
          _CardInfoRow(
            icon: Icons.engineering_outlined,
            value: job.workerName,
          ),
          const SizedBox(height: 9),
          _CardInfoRow(
            icon: Icons.location_on_outlined,
            value: job.address,
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Budget',
                  value: _formatBudget(job.budget),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Created',
                  value: _formatDate(job.createdAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onView(job),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('View details'),
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

class _JobActions extends StatelessWidget {
  const _JobActions({
    required this.job,
    required this.onView,
    required this.onStatus,
    required this.onCancel,
    required this.onDelete,
  });

  final ManagedJob job;
  final ValueChanged<ManagedJob> onView;
  final ValueChanged<ManagedJob> onStatus;
  final ValueChanged<ManagedJob> onCancel;
  final ValueChanged<ManagedJob> onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Job actions',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView(job);
            break;
          case 'status':
            onStatus(job);
            break;
          case 'cancel':
            onCancel(job);
            break;
          case 'delete':
            onDelete(job);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'view',
          child: _ActionMenuItem(
            icon: Icons.visibility_outlined,
            text: 'View details',
          ),
        ),
        const PopupMenuItem(
          value: 'status',
          child: _ActionMenuItem(
            icon: Icons.sync_alt_rounded,
            text: 'Update status',
          ),
        ),
        if (!job.isCancelled && !job.isCompleted)
          const PopupMenuItem(
            value: 'cancel',
            child: _ActionMenuItem(
              icon: Icons.cancel_outlined,
              text: 'Cancel job',
              danger: true,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: _ActionMenuItem(
            icon: Icons.delete_outline_rounded,
            text: 'Delete job',
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _CardInfoRow extends StatelessWidget {
  const _CardInfoRow({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 4),
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
      width: 225,
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

class _EmptyJobsState extends StatelessWidget {
  const _EmptyJobsState();

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
            Icons.work_off_outlined,
            size: 58,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(
            'No jobs found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search ya selected filter ke mutabiq koi job nahi mili.',
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

class _JobsErrorState extends StatelessWidget {
  const _JobsErrorState({required this.message});

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

String _jobFilterLabel(JobFilter filter) {
  switch (filter) {
    case JobFilter.all:
      return 'All';
    case JobFilter.pending:
      return 'Pending';
    case JobFilter.active:
      return 'Active';
    case JobFilter.completed:
      return 'Completed';
    case JobFilter.cancelled:
      return 'Cancelled';
  }
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'waiting_worker':
      return 'Waiting Worker';
    case 'searching':
      return 'Searching';
    case 'accepted':
      return 'Accepted';
    case 'on_the_way':
      return 'On The Way';
    case 'in_progress':
      return 'In Progress';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Pending';
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return const Color(0xFF16A34A);
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

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  return DateFormat('dd MMM yyyy').format(date);
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Unknown';
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}

String _formatBudget(double budget) {
  if (budget <= 0) return 'Not set';
  return 'PKR ${NumberFormat('#,##0').format(budget)}';
}
