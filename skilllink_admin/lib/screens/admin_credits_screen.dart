import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/credit_management_service.dart';

enum CreditFilter { all, zeroBalance, lowBalance, healthy, blocked }

class AdminCreditsScreen extends StatefulWidget {
  const AdminCreditsScreen({super.key});

  @override
  State<AdminCreditsScreen> createState() => _AdminCreditsScreenState();
}

class _AdminCreditsScreenState extends State<AdminCreditsScreen> {
  final CreditManagementService _service = CreditManagementService();
  final TextEditingController _searchController = TextEditingController();

  CreditFilter _selectedFilter = CreditFilter.all;
  String _searchQuery = '';
  bool _gridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CreditWorker> _filterWorkers(List<CreditWorker> workers) {
    final query = _searchQuery.trim().toLowerCase();

    return workers.where((worker) {
      final matchesSearch =
          query.isEmpty ||
          worker.name.toLowerCase().contains(query) ||
          worker.email.toLowerCase().contains(query) ||
          worker.phone.toLowerCase().contains(query) ||
          worker.skill.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        CreditFilter.all => true,
        CreditFilter.zeroBalance => worker.credits == 0,
        CreditFilter.lowBalance => worker.credits > 0 && worker.credits <= 5,
        CreditFilter.healthy => worker.credits > 5,
        CreditFilter.blocked => worker.isBlocked,
      };

      return matchesSearch && matchesFilter;
    }).toList()..sort((a, b) => b.credits.compareTo(a.credits));
  }

  Future<void> _showCreditDialog({
    required CreditWorker worker,
    required bool isAdding,
  }) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    final result = await showDialog<_CreditDialogResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          title: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color:
                      (isAdding
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626))
                          .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  isAdding
                      ? Icons.add_card_rounded
                      : Icons.remove_circle_outline_rounded,
                  color: isAdding
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAdding ? 'Add credits' : 'Deduct credits',
                      style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${worker.name} • ${worker.credits} available',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Credit amount',
                    hintText: 'Example: 10',
                    prefixIcon: const Icon(Icons.toll_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    hintText: isAdding
                        ? 'Example: Promotional bonus'
                        : 'Example: Invalid lead refund adjustment',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 52),
                      child: Icon(Icons.notes_rounded),
                    ),
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
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final amount = int.tryParse(amountController.text.trim());
                final reason = reasonController.text.trim();

                if (amount == null || amount <= 0 || reason.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  _CreditDialogResult(amount: amount, reason: reason),
                );
              },
              icon: Icon(isAdding ? Icons.add_rounded : Icons.remove_rounded),
              label: Text(isAdding ? 'Add credits' : 'Deduct credits'),
              style: FilledButton.styleFrom(
                backgroundColor: isAdding
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    amountController.dispose();
    reasonController.dispose();

    if (result == null) return;

    try {
      if (isAdding) {
        await _service.addCredits(
          workerId: worker.id,
          workerName: worker.name,
          amount: result.amount,
          reason: result.reason,
        );
      } else {
        await _service.deductCredits(
          workerId: worker.id,
          workerName: worker.name,
          currentBalance: worker.credits,
          amount: result.amount,
          reason: result.reason,
        );
      }

      if (!mounted) return;

      _showMessage(
        isAdding
            ? '${result.amount} credits add ho gaye.'
            : '${result.amount} credits deduct ho gaye.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Credits update nahi ho sake: $error', isError: true);
    }
  }

  Future<void> _setBalance(CreditWorker worker) async {
    final balanceController = TextEditingController(
      text: worker.credits.toString(),
    );
    final reasonController = TextEditingController();

    final result = await showDialog<_CreditDialogResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: Text(
            'Set credit balance',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'New balance',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Adjustment reason',
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
                final amount = int.tryParse(balanceController.text.trim());
                final reason = reasonController.text.trim();

                if (amount == null || amount < 0 || reason.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  _CreditDialogResult(amount: amount, reason: reason),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save balance'),
            ),
          ],
        );
      },
    );

    balanceController.dispose();
    reasonController.dispose();

    if (result == null) return;

    try {
      await _service.setCreditBalance(
        workerId: worker.id,
        workerName: worker.name,
        oldBalance: worker.credits,
        newBalance: result.amount,
        reason: result.reason,
      );

      if (!mounted) return;
      _showMessage('${worker.name} ka balance update ho gaya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Balance update nahi ho saka: $error', isError: true);
    }
  }

  void _showWorkerDetails(CreditWorker worker) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _WorkerAvatar(worker: worker, radius: 35),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              worker.name,
                              style: GoogleFonts.inter(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              worker.skill,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'AVAILABLE CREDITS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${worker.credits}',
                          style: GoogleFonts.inter(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Lead credits',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: worker.email,
                      ),
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: worker.phone,
                      ),
                      _InfoTile(
                        icon: Icons.task_alt_rounded,
                        label: 'Completed Jobs',
                        value: '${worker.completedJobs}',
                      ),
                      _InfoTile(
                        icon: Icons.shield_outlined,
                        label: 'Account',
                        value: worker.isBlocked ? 'Blocked' : 'Active',
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
                            _showCreditDialog(worker: worker, isAdding: false);
                          },
                          icon: const Icon(Icons.remove_rounded),
                          label: const Text('Deduct'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showCreditDialog(worker: worker, isAdding: true);
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add credits'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.workersStream(),
      builder: (context, workerSnapshot) {
        if (workerSnapshot.hasError) {
          return _CreditsErrorState(
            message: 'Workers load nahi ho sake.\n${workerSnapshot.error}',
          );
        }

        if (!workerSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF16A34A)),
          );
        }

        final allWorkers = workerSnapshot.data!.docs
            .map(CreditWorker.fromDocument)
            .toList();

        final filteredWorkers = _filterWorkers(allWorkers);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.transactionsStream(),
          builder: (context, transactionSnapshot) {
            final transactions = transactionSnapshot.hasData
                ? (transactionSnapshot.data!.docs
                      .map(CreditTransaction.fromDocument)
                      .toList()
                    ..sort((a, b) {
                      final aDate =
                          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bDate =
                          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return bDate.compareTo(aDate);
                    }))
                : <CreditTransaction>[];

            final totalCredits = allWorkers.fold<int>(
              0,
              (sum, worker) => sum + worker.credits,
            );
            final zeroBalance = allWorkers
                .where((worker) => worker.credits == 0)
                .length;
            final lowBalance = allWorkers
                .where((worker) => worker.credits > 0 && worker.credits <= 5)
                .length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CreditsHeader(
                    totalWorkers: allWorkers.length,
                    totalCredits: totalCredits,
                    zeroBalance: zeroBalance,
                    lowBalance: lowBalance,
                  ),
                  const SizedBox(height: 22),
                  _CreditsToolbar(
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
                    const _EmptyCreditsState()
                  else if (_gridView)
                    _CreditsGrid(
                      workers: filteredWorkers,
                      onView: _showWorkerDetails,
                      onAdd: (worker) =>
                          _showCreditDialog(worker: worker, isAdding: true),
                      onDeduct: (worker) =>
                          _showCreditDialog(worker: worker, isAdding: false),
                      onSetBalance: _setBalance,
                    )
                  else
                    _CreditsTable(
                      workers: filteredWorkers,
                      onView: _showWorkerDetails,
                      onAdd: (worker) =>
                          _showCreditDialog(worker: worker, isAdding: true),
                      onDeduct: (worker) =>
                          _showCreditDialog(worker: worker, isAdding: false),
                      onSetBalance: _setBalance,
                    ),
                  const SizedBox(height: 22),
                  _RecentTransactions(
                    transactions: transactions.take(8).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CreditsHeader extends StatelessWidget {
  const _CreditsHeader({
    required this.totalWorkers,
    required this.totalCredits,
    required this.zeroBalance,
    required this.lowBalance,
  });

  final int totalWorkers;
  final int totalCredits;
  final int zeroBalance;
  final int lowBalance;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CreditStatCard(
        title: 'Credit Workers',
        value: '$totalWorkers',
        icon: Icons.engineering_rounded,
        color: const Color(0xFF2563EB),
      ),
      _CreditStatCard(
        title: 'Credits in Circulation',
        value: NumberFormat('#,##0').format(totalCredits),
        icon: Icons.toll_rounded,
        color: const Color(0xFF16A34A),
      ),
      _CreditStatCard(
        title: 'Zero Balance',
        value: '$zeroBalance',
        icon: Icons.money_off_csred_rounded,
        color: const Color(0xFFDC2626),
      ),
      _CreditStatCard(
        title: 'Low Balance',
        value: '$lowBalance',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFD97706),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Credits Management',
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Worker lead credits monitor, add, deduct aur adjust karein.',
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
                : constraints.maxWidth >= 540
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

class _CreditStatCard extends StatelessWidget {
  const _CreditStatCard({
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 22,
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
          ),
        ],
      ),
    );
  }
}

class _CreditsToolbar extends StatelessWidget {
  const _CreditsToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.gridView,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final CreditFilter selectedFilter;
  final int resultCount;
  final bool gridView;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CreditFilter> onFilterChanged;
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
          final compact = constraints.maxWidth < 940;

          final search = SizedBox(
            width: compact ? double.infinity : 340,
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
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
            children: CreditFilter.values.map((filter) {
              final selected = selectedFilter == filter;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onFilterChanged(filter),
                label: Text(_filterLabel(filter)),
                selectedColor: const Color(0xFF16A34A).withOpacity(0.12),
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
                '$resultCount workers',
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
                Align(alignment: Alignment.centerRight, child: controls),
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

class _CreditsTable extends StatelessWidget {
  const _CreditsTable({
    required this.workers,
    required this.onView,
    required this.onAdd,
    required this.onDeduct,
    required this.onSetBalance,
  });

  final List<CreditWorker> workers;
  final ValueChanged<CreditWorker> onView;
  final ValueChanged<CreditWorker> onAdd;
  final ValueChanged<CreditWorker> onDeduct;
  final ValueChanged<CreditWorker> onSetBalance;

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
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMinHeight: 74,
          dataRowMaxHeight: 82,
          horizontalMargin: 20,
          columnSpacing: 30,
          columns: const [
            DataColumn(label: _TableHeading('WORKER')),
            DataColumn(label: _TableHeading('SKILL')),
            DataColumn(label: _TableHeading('CREDITS')),
            DataColumn(label: _TableHeading('COMPLETED JOBS')),
            DataColumn(label: _TableHeading('BALANCE STATUS')),
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
                              Text(
                                worker.name,
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
                DataCell(_CreditBalance(value: worker.credits)),
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
                DataCell(_BalanceStatusBadge(credits: worker.credits)),
                DataCell(
                  _CreditActions(
                    worker: worker,
                    onView: onView,
                    onAdd: onAdd,
                    onDeduct: onDeduct,
                    onSetBalance: onSetBalance,
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

class _CreditsGrid extends StatelessWidget {
  const _CreditsGrid({
    required this.workers,
    required this.onView,
    required this.onAdd,
    required this.onDeduct,
    required this.onSetBalance,
  });

  final List<CreditWorker> workers;
  final ValueChanged<CreditWorker> onView;
  final ValueChanged<CreditWorker> onAdd;
  final ValueChanged<CreditWorker> onDeduct;
  final ValueChanged<CreditWorker> onSetBalance;

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

        final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: workers.map((worker) {
            return SizedBox(
              width: width,
              child: _CreditWorkerCard(
                worker: worker,
                onView: onView,
                onAdd: onAdd,
                onDeduct: onDeduct,
                onSetBalance: onSetBalance,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CreditWorkerCard extends StatelessWidget {
  const _CreditWorkerCard({
    required this.worker,
    required this.onView,
    required this.onAdd,
    required this.onDeduct,
    required this.onSetBalance,
  });

  final CreditWorker worker;
  final ValueChanged<CreditWorker> onView;
  final ValueChanged<CreditWorker> onAdd;
  final ValueChanged<CreditWorker> onDeduct;
  final ValueChanged<CreditWorker> onSetBalance;

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
            child: _CreditActions(
              worker: worker,
              onView: onView,
              onAdd: onAdd,
              onDeduct: onDeduct,
              onSetBalance: onSetBalance,
            ),
          ),
          _WorkerAvatar(worker: worker, radius: 34),
          const SizedBox(height: 12),
          Text(
            worker.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
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
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Text(
                  '${worker.credits}',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Available credits',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _BalanceStatusBadge(credits: worker.credits),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onDeduct(worker),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                  child: const Text('Deduct'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => onAdd(worker),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.transactions});

  final List<CreditTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Credit Transactions',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Abhi koi credit transaction available nahi hai.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
            ...transactions.map(
              (transaction) => _TransactionRow(transaction: transaction),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final CreditTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = transaction.isCredit
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.workerName,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.reason,
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
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.isCredit ? '+' : '-'}${transaction.amount}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatDateTime(transaction.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditActions extends StatelessWidget {
  const _CreditActions({
    required this.worker,
    required this.onView,
    required this.onAdd,
    required this.onDeduct,
    required this.onSetBalance,
  });

  final CreditWorker worker;
  final ValueChanged<CreditWorker> onView;
  final ValueChanged<CreditWorker> onAdd;
  final ValueChanged<CreditWorker> onDeduct;
  final ValueChanged<CreditWorker> onSetBalance;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Credit actions',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView(worker);
            break;
          case 'add':
            onAdd(worker);
            break;
          case 'deduct':
            onDeduct(worker);
            break;
          case 'set':
            onSetBalance(worker);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'view',
          child: _ActionMenuItem(
            icon: Icons.visibility_outlined,
            text: 'View details',
          ),
        ),
        PopupMenuItem(
          value: 'add',
          child: _ActionMenuItem(
            icon: Icons.add_circle_outline_rounded,
            text: 'Add credits',
          ),
        ),
        PopupMenuItem(
          value: 'deduct',
          child: _ActionMenuItem(
            icon: Icons.remove_circle_outline_rounded,
            text: 'Deduct credits',
            danger: true,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'set',
          child: _ActionMenuItem(
            icon: Icons.tune_rounded,
            text: 'Set exact balance',
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
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF334155);

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
  const _WorkerAvatar({required this.worker, required this.radius});

  final CreditWorker worker;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8F7ED),
      backgroundImage: worker.photoUrl != null
          ? NetworkImage(worker.photoUrl!)
          : null,
      child: worker.photoUrl == null
          ? Text(
              worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
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

class _CreditBalance extends StatelessWidget {
  const _CreditBalance({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.toll_rounded, size: 18, color: Color(0xFF16A34A)),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _BalanceStatusBadge extends StatelessWidget {
  const _BalanceStatusBadge({required this.credits});

  final int credits;

  @override
  Widget build(BuildContext context) {
    final color = credits == 0
        ? const Color(0xFFDC2626)
        : credits <= 5
        ? const Color(0xFFD97706)
        : const Color(0xFF16A34A);

    final text = credits == 0
        ? 'EMPTY'
        : credits <= 5
        ? 'LOW'
        : 'HEALTHY';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 255,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
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
          color: selected ? const Color(0xFF16A34A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
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

class _EmptyCreditsState extends StatelessWidget {
  const _EmptyCreditsState();

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
          const Icon(Icons.toll_outlined, size: 58, color: Color(0xFF94A3B8)),
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
            'Search ya selected filter ke mutabiq koi worker nahi mila.',
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

class _CreditsErrorState extends StatelessWidget {
  const _CreditsErrorState({required this.message});

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
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF991B1B)),
        ),
      ),
    );
  }
}

class _CreditDialogResult {
  const _CreditDialogResult({required this.amount, required this.reason});

  final int amount;
  final String reason;
}

String _filterLabel(CreditFilter filter) {
  switch (filter) {
    case CreditFilter.all:
      return 'All';
    case CreditFilter.zeroBalance:
      return 'Zero Balance';
    case CreditFilter.lowBalance:
      return 'Low Balance';
    case CreditFilter.healthy:
      return 'Healthy';
    case CreditFilter.blocked:
      return 'Blocked';
  }
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Just now';
  return DateFormat('dd MMM, hh:mm a').format(date);
}
