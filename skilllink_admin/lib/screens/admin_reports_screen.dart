import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skilllink_admin/services/report_management_service.dart';


enum ReportFilter {
  all,
  open,
  investigating,
  resolved,
  rejected,
  highPriority,
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ReportManagementService _service = ReportManagementService();
  final TextEditingController _searchController = TextEditingController();

  ReportFilter _selectedFilter = ReportFilter.all;
  String _searchQuery = '';
  bool _gridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagedReport> _applyFilters(List<ManagedReport> reports) {
    final query = _searchQuery.trim().toLowerCase();

    return reports.where((report) {
      final matchesSearch = query.isEmpty ||
          report.title.toLowerCase().contains(query) ||
          report.description.toLowerCase().contains(query) ||
          report.reporterName.toLowerCase().contains(query) ||
          report.reportedUserName.toLowerCase().contains(query) ||
          report.jobTitle.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        ReportFilter.all => true,
        ReportFilter.open => report.isOpen,
        ReportFilter.investigating => report.isInvestigating,
        ReportFilter.resolved => report.isResolved,
        ReportFilter.rejected => report.isRejected,
        ReportFilter.highPriority => report.priority == 'high',
      };

      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  Future<void> _changeStatus(ManagedReport report) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String value = report.status;
        const statuses = <String>[
          'open',
          'investigating',
          'resolved',
          'rejected',
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
                'Update report status',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              content: SizedBox(
                width: 430,
                child: DropdownButtonFormField<String>(
                  value: statuses.contains(value) ? value : 'open',
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
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || selected == report.status) return;

    try {
      await _service.updateReportStatus(
        reportId: report.id,
        status: selected,
      );

      if (!mounted) return;
      _showMessage('Report status update ho gaya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Status update nahi ho saka: $error',
        isError: true,
      );
    }
  }

  Future<void> _resolveReport(ManagedReport report) async {
    final noteController = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Resolve complaint',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resolution note likhein jo admin record mein save hogi.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Example: Issue investigated and resolved...',
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
            FilledButton.icon(
              onPressed: () {
                final value = noteController.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Mark resolved'),
            ),
          ],
        );
      },
    );

    noteController.dispose();

    if (note == null || note.isEmpty) return;

    try {
      await _service.updateReportStatus(
        reportId: report.id,
        status: 'resolved',
        resolutionNote: note,
      );

      if (!mounted) return;
      _showMessage('Complaint resolve ho gayi.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Complaint resolve nahi ho saki: $error',
        isError: true,
      );
    }
  }

  Future<void> _changePriority(ManagedReport report) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String value = report.priority;
        const priorities = <String>['low', 'medium', 'high'];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Set priority',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              content: SizedBox(
                width: 420,
                child: DropdownButtonFormField<String>(
                  value: priorities.contains(value) ? value : 'medium',
                  items: priorities.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Text(priority.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue == null) return;
                    setDialogState(() => value = newValue);
                  },
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
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
                  child: const Text('Save priority'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || selected == report.priority) return;

    try {
      await _service.assignPriority(
        reportId: report.id,
        priority: selected,
      );

      if (!mounted) return;
      _showMessage('Report priority update ho gayi.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Priority update nahi ho saki: $error',
        isError: true,
      );
    }
  }

  Future<void> _deleteReport(ManagedReport report) async {
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
            'Delete report?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Ye report Firestore se permanently delete ho jayegi.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              height: 1.5,
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
              child: const Text('Delete report'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteReport(report.id);

      if (!mounted) return;
      _showMessage('Report delete ho gayi.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Report delete nahi ho saki: $error',
        isError: true,
      );
    }
  }

  void _showReportDetails(ManagedReport report) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
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
                            color: const Color(0xFFFFE7E7),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.report_problem_rounded,
                            color: Color(0xFFDC2626),
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.title,
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _StatusBadge(status: report.status),
                                  _PriorityBadge(priority: report.priority),
                                  _TypeBadge(type: report.type),
                                ],
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        report.description,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          height: 1.7,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _InfoTile(
                          label: 'Reporter',
                          value: report.reporterName,
                          icon: Icons.person_outline_rounded,
                        ),
                        _InfoTile(
                          label: 'Reported user',
                          value: report.reportedUserName,
                          icon: Icons.person_off_outlined,
                        ),
                        _InfoTile(
                          label: 'Linked job',
                          value: report.jobTitle,
                          icon: Icons.work_outline_rounded,
                        ),
                        _InfoTile(
                          label: 'Submitted',
                          value: _formatDateTime(report.createdAt),
                          icon: Icons.calendar_today_outlined,
                        ),
                      ],
                    ),
                    if (report.resolutionNote.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text(
                        'Resolution note',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF8EF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFBBE4C8),
                          ),
                        ),
                        child: Text(
                          report.resolutionNote,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF166534),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _changePriority(report);
                            },
                            icon: const Icon(Icons.priority_high_rounded),
                            label: const Text('Change priority'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD97706),
                              side: const BorderSide(
                                color: Color(0xFFD97706),
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
                            onPressed: report.isResolved
                                ? null
                                : () {
                                    Navigator.pop(dialogContext);
                                    _resolveReport(report);
                                  },
                            icon: const Icon(Icons.task_alt_rounded),
                            label: Text(
                              report.isResolved
                                  ? 'Already resolved'
                                  : 'Resolve complaint',
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
      stream: _service.reportsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ReportsErrorState(
            message: 'Reports load nahi ho sake.\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF16A34A),
            ),
          );
        }

        final allReports = snapshot.data!.docs
            .map(ManagedReport.fromDocument)
            .toList();

        final filteredReports = _applyFilters(allReports);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReportsHeader(
                total: allReports.length,
                open: allReports.where((report) => report.isOpen).length,
                investigating:
                    allReports.where((report) => report.isInvestigating).length,
                resolved:
                    allReports.where((report) => report.isResolved).length,
                highPriority:
                    allReports.where((report) => report.priority == 'high').length,
              ),
              const SizedBox(height: 22),
              _ReportsToolbar(
                controller: _searchController,
                selectedFilter: _selectedFilter,
                resultCount: filteredReports.length,
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
              if (filteredReports.isEmpty)
                const _EmptyReportsState()
              else if (_gridView)
                _ReportsGrid(
                  reports: filteredReports,
                  onView: _showReportDetails,
                  onStatus: _changeStatus,
                  onResolve: _resolveReport,
                  onPriority: _changePriority,
                  onDelete: _deleteReport,
                )
              else
                _ReportsTable(
                  reports: filteredReports,
                  onView: _showReportDetails,
                  onStatus: _changeStatus,
                  onResolve: _resolveReport,
                  onPriority: _changePriority,
                  onDelete: _deleteReport,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.total,
    required this.open,
    required this.investigating,
    required this.resolved,
    required this.highPriority,
  });

  final int total;
  final int open;
  final int investigating;
  final int resolved;
  final int highPriority;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ReportStatCard(
        title: 'Total Reports',
        value: '$total',
        icon: Icons.report_rounded,
        color: const Color(0xFF2563EB),
      ),
      _ReportStatCard(
        title: 'Open',
        value: '$open',
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xFFD97706),
      ),
      _ReportStatCard(
        title: 'Investigating',
        value: '$investigating',
        icon: Icons.manage_search_rounded,
        color: const Color(0xFF0891B2),
      ),
      _ReportStatCard(
        title: 'Resolved',
        value: '$resolved',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF16A34A),
      ),
      _ReportStatCard(
        title: 'High Priority',
        value: '$highPriority',
        icon: Icons.priority_high_rounded,
        color: const Color(0xFFDC2626),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports & Complaints',
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'User complaints investigate karein, priority assign karein aur issues resolve karein.',
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

class _ReportStatCard extends StatelessWidget {
  const _ReportStatCard({
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

class _ReportsToolbar extends StatelessWidget {
  const _ReportsToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.gridView,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final ReportFilter selectedFilter;
  final int resultCount;
  final bool gridView;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ReportFilter> onFilterChanged;
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
          final compact = constraints.maxWidth < 990;

          final search = SizedBox(
            width: compact ? double.infinity : 350,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search title, reporter, user or job...',
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
            children: ReportFilter.values.map((filter) {
              final selected = selectedFilter == filter;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onFilterChanged(filter),
                label: Text(_filterLabel(filter)),
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
                '$resultCount reports',
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

class _ReportsTable extends StatelessWidget {
  const _ReportsTable({
    required this.reports,
    required this.onView,
    required this.onStatus,
    required this.onResolve,
    required this.onPriority,
    required this.onDelete,
  });

  final List<ManagedReport> reports;
  final ValueChanged<ManagedReport> onView;
  final ValueChanged<ManagedReport> onStatus;
  final ValueChanged<ManagedReport> onResolve;
  final ValueChanged<ManagedReport> onPriority;
  final ValueChanged<ManagedReport> onDelete;

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
          dataRowMinHeight: 80,
          dataRowMaxHeight: 94,
          horizontalMargin: 20,
          columnSpacing: 28,
          columns: const [
            DataColumn(label: _TableHeading('REPORT')),
            DataColumn(label: _TableHeading('REPORTER')),
            DataColumn(label: _TableHeading('REPORTED USER')),
            DataColumn(label: _TableHeading('PRIORITY')),
            DataColumn(label: _TableHeading('STATUS')),
            DataColumn(label: _TableHeading('DATE')),
            DataColumn(label: _TableHeading('ACTIONS')),
          ],
          rows: reports.map((report) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 270,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          report.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            height: 1.35,
                            color: const Color(0xFF64748B),
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
                      report.reporterName,
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
                      report.reportedUserName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                DataCell(_PriorityBadge(priority: report.priority)),
                DataCell(_StatusBadge(status: report.status)),
                DataCell(
                  Text(
                    _formatDate(report.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
                DataCell(
                  _ReportActions(
                    report: report,
                    onView: onView,
                    onStatus: onStatus,
                    onResolve: onResolve,
                    onPriority: onPriority,
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

class _ReportsGrid extends StatelessWidget {
  const _ReportsGrid({
    required this.reports,
    required this.onView,
    required this.onStatus,
    required this.onResolve,
    required this.onPriority,
    required this.onDelete,
  });

  final List<ManagedReport> reports;
  final ValueChanged<ManagedReport> onView;
  final ValueChanged<ManagedReport> onStatus;
  final ValueChanged<ManagedReport> onResolve;
  final ValueChanged<ManagedReport> onPriority;
  final ValueChanged<ManagedReport> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;

        final width =
            (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: reports.map((report) {
            return SizedBox(
              width: width,
              child: _ReportCard(
                report: report,
                onView: onView,
                onStatus: onStatus,
                onResolve: onResolve,
                onPriority: onPriority,
                onDelete: onDelete,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onView,
    required this.onStatus,
    required this.onResolve,
    required this.onPriority,
    required this.onDelete,
  });

  final ManagedReport report;
  final ValueChanged<ManagedReport> onView;
  final ValueChanged<ManagedReport> onStatus;
  final ValueChanged<ManagedReport> onResolve;
  final ValueChanged<ManagedReport> onPriority;
  final ValueChanged<ManagedReport> onDelete;

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
                  color: const Color(0xFFFFE7E7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.report_problem_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const Spacer(),
              _ReportActions(
                report: report,
                onView: onView,
                onStatus: onStatus,
                onResolve: onResolve,
                onPriority: onPriority,
                onDelete: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            report.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.55,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _StatusBadge(status: report.status),
              _PriorityBadge(priority: report.priority),
              _TypeBadge(type: report.type),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          _ReportPersonRow(
            icon: Icons.person_outline_rounded,
            label: 'Reporter',
            value: report.reporterName,
          ),
          const SizedBox(height: 9),
          _ReportPersonRow(
            icon: Icons.person_off_outlined,
            label: 'Reported',
            value: report.reportedUserName,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onView(report),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('View complaint'),
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

class _ReportActions extends StatelessWidget {
  const _ReportActions({
    required this.report,
    required this.onView,
    required this.onStatus,
    required this.onResolve,
    required this.onPriority,
    required this.onDelete,
  });

  final ManagedReport report;
  final ValueChanged<ManagedReport> onView;
  final ValueChanged<ManagedReport> onStatus;
  final ValueChanged<ManagedReport> onResolve;
  final ValueChanged<ManagedReport> onPriority;
  final ValueChanged<ManagedReport> onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Report actions',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView(report);
            break;
          case 'status':
            onStatus(report);
            break;
          case 'resolve':
            onResolve(report);
            break;
          case 'priority':
            onPriority(report);
            break;
          case 'delete':
            onDelete(report);
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
        const PopupMenuItem(
          value: 'priority',
          child: _ActionMenuItem(
            icon: Icons.priority_high_rounded,
            text: 'Change priority',
          ),
        ),
        if (!report.isResolved)
          const PopupMenuItem(
            value: 'resolve',
            child: _ActionMenuItem(
              icon: Icons.task_alt_rounded,
              text: 'Resolve complaint',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: _ActionMenuItem(
            icon: Icons.delete_outline_rounded,
            text: 'Delete report',
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority.toLowerCase()) {
      'high' => const Color(0xFFDC2626),
      'low' => const Color(0xFF16A34A),
      _ => const Color(0xFFD97706),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

class _ReportPersonRow extends StatelessWidget {
  const _ReportPersonRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
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

class _EmptyReportsState extends StatelessWidget {
  const _EmptyReportsState();

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
            Icons.report_gmailerrorred_outlined,
            size: 58,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(
            'No reports found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search ya selected filter ke mutabiq koi report nahi mili.',
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

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({required this.message});

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

String _filterLabel(ReportFilter filter) {
  switch (filter) {
    case ReportFilter.all:
      return 'All';
    case ReportFilter.open:
      return 'Open';
    case ReportFilter.investigating:
      return 'Investigating';
    case ReportFilter.resolved:
      return 'Resolved';
    case ReportFilter.rejected:
      return 'Rejected';
    case ReportFilter.highPriority:
      return 'High Priority';
  }
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'investigating':
    case 'in_review':
    case 'reviewing':
      return 'Investigating';
    case 'resolved':
      return 'Resolved';
    case 'rejected':
    case 'dismissed':
      return 'Rejected';
    default:
      return 'Open';
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'investigating':
    case 'in_review':
    case 'reviewing':
      return const Color(0xFF0891B2);
    case 'resolved':
      return const Color(0xFF16A34A);
    case 'rejected':
    case 'dismissed':
      return const Color(0xFF64748B);
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
