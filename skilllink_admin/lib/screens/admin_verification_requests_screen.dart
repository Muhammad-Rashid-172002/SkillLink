
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skilllink_admin/services/verification_management_service.dart';

enum VerificationFilter { all, pending, approved, rejected, moreInfo }

class AdminVerificationRequestsScreen extends StatefulWidget {
  const AdminVerificationRequestsScreen({super.key});

  @override
  State<AdminVerificationRequestsScreen> createState() =>
      _AdminVerificationRequestsScreenState();
}

class _AdminVerificationRequestsScreenState
    extends State<AdminVerificationRequestsScreen> {
  final VerificationManagementService _service =
      VerificationManagementService();
  final TextEditingController _searchController = TextEditingController();

  VerificationFilter _filter = VerificationFilter.all;
  String _query = '';
  String? _busyId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VerificationRequestModel> _applyFilters(
    List<VerificationRequestModel> requests,
  ) {
    final q = _query.trim().toLowerCase();

    return requests.where((request) {
      final searchMatches =
          q.isEmpty ||
          request.workerName.toLowerCase().contains(q) ||
          request.workerEmail.toLowerCase().contains(q) ||
          request.workerPhone.toLowerCase().contains(q) ||
          request.skill.toLowerCase().contains(q);

      final filterMatches = switch (_filter) {
        VerificationFilter.all => true,
        VerificationFilter.pending => request.isPending,
        VerificationFilter.approved => request.status == 'approved',
        VerificationFilter.rejected => request.status == 'rejected',
        VerificationFilter.moreInfo =>
          request.status == 'more_information_required',
      };

      return searchMatches && filterMatches;
    }).toList()..sort((a, b) {
      final aDate = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  }

  Future<String?> _askText(
    String title,
    String hint, {
    bool requiredValue = true,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
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
            onPressed: () {
              final text = controller.text.trim();
              if (requiredValue && text.isEmpty) return;
              Navigator.pop(dialogContext, text);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _approve(VerificationRequestModel request) async {
    final note = await _askText(
      'Approve worker identity?',
      'Optional review note...',
      requiredValue: false,
    );
    if (note == null) return;
    await _run(
      request,
      () => _service.approve(request, note: note),
      'Worker approved successfully.',
    );
  }

  Future<void> _reject(VerificationRequestModel request) async {
    final reason = await _askText(
      'Reject verification',
      'Clear rejection reason likhein...',
    );
    if (reason == null) return;
    await _run(
      request,
      () => _service.reject(request, reason),
      'Verification rejected.',
    );
  }

  Future<void> _requestAgain(VerificationRequestModel request) async {
    final reason = await _askText(
      'Request new documents',
      'Example: CNIC image blurred hai.',
    );
    if (reason == null) return;
    await _run(
      request,
      () => _service.requestResubmission(request, reason),
      'Resubmission requested.',
    );
  }

  Future<void> _run(
    VerificationRequestModel request,
    Future<void> Function() action,
    String success,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = request.id);
    try {
      await action();
      if (!mounted) return;
      _message(success);
    } catch (error) {
      if (!mounted) return;
      _message('Action failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? const Color(0xFFDC2626)
              : const Color(0xFF16A34A),
          content: Text(message),
        ),
      );
  }

  void _openDetails(VerificationRequestModel request) {
    showDialog<void>(
      context: context,
      builder: (_) => _VerificationDialog(
        request: request,
        service: _service,
        onApprove: () {
          Navigator.pop(context);
          _approve(request);
        },
        onReject: () {
          Navigator.pop(context);
          _reject(request);
        },
        onRequestAgain: () {
          Navigator.pop(context);
          _requestAgain(request);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.requestsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Verification requests load nahi ho sake.\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF16A34A)),
          );
        }

        final all = snapshot.data!.docs
            .map(VerificationRequestModel.fromDocument)
            .toList();
        final requests = _applyFilters(all);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verification Requests',
                style: GoogleFonts.inter(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Review and approve or reject worker CNIC and live selfie verification.',
                style: GoogleFonts.inter(color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              _Stats(requests: all),
              const SizedBox(height: 18),
              _Toolbar(
                controller: _searchController,
                filter: _filter,
                count: requests.length,
                onSearch: (value) => setState(() => _query = value),
                onFilter: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 18),
              if (requests.isEmpty)
                const _EmptyState()
              else
                LayoutBuilder(
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
                      children: requests.map((request) {
                        return SizedBox(
                          width: width,
                          child: _RequestCard(
                            request: request,
                            busy: _busyId == request.id,
                            onView: () => _openDetails(request),
                            onApprove: () => _approve(request),
                            onReject: () => _reject(request),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.requests});
  final List<VerificationRequestModel> requests;

  @override
  Widget build(BuildContext context) {
    final data = [
      ('Total', requests.length, Icons.badge_rounded, const Color(0xFF2563EB)),
      (
        'Pending',
        requests.where((e) => e.isPending).length,
        Icons.schedule_rounded,
        const Color(0xFFD97706),
      ),
      (
        'Approved',
        requests.where((e) => e.status == 'approved').length,
        Icons.verified_rounded,
        const Color(0xFF16A34A),
      ),
      (
        'Rejected',
        requests.where((e) => e.status == 'rejected').length,
        Icons.cancel_rounded,
        const Color(0xFFDC2626),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: data.map((item) {
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6ECF2)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: item.$4.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.$3, color: item.$4),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.$2}',
                          style: GoogleFonts.inter(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(item.$1, style: GoogleFonts.inter(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.filter,
    required this.count,
    required this.onSearch,
    required this.onFilter,
  });

  final TextEditingController controller;
  final VerificationFilter filter;
  final int count;
  final ValueChanged<String> onSearch;
  final ValueChanged<VerificationFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 330,
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search worker, email, phone or skill...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          ...VerificationFilter.values.map(
            (value) => ChoiceChip(
              selected: filter == value,
              onSelected: (_) => onFilter(value),
              label: Text(_filterLabel(value)),
            ),
          ),
          Text('$count requests'),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onView,
    required this.onApprove,
    required this.onReject,
  });

  final VerificationRequestModel request;
  final bool busy;
  final VoidCallback onView;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE8F7ED),
                child: Text(
                  request.workerName.isEmpty
                      ? 'W'
                      : request.workerName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.workerName,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      request.skill,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: request.status, color: color),
            ],
          ),
          const SizedBox(height: 16),
          Text(request.workerEmail),
          const SizedBox(height: 5),
          Text(request.workerPhone),
          const SizedBox(height: 5),
          Text(
            request.submittedAt == null
                ? 'No submission date'
                : DateFormat(
                    'dd MMM yyyy, hh:mm a',
                  ).format(request.submittedAt!),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onView,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Review documents'),
            ),
          ),
          if (request.isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                    child: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VerificationDialog extends StatelessWidget {
  const _VerificationDialog({
    required this.request,
    required this.service,
    required this.onApprove,
    required this.onReject,
    required this.onRequestAgain,
  });

  final VerificationRequestModel request;
  final VerificationManagementService service;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestAgain;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${request.workerName} verification',
                      style: GoogleFonts.inter(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _PrivateImageCard(
                        title: 'CNIC Front',
                        path: request.cnicFrontPath,
                        service: service,
                      ),
                      _PrivateImageCard(
                        title: 'CNIC Back',
                        path: request.cnicBackPath,
                        service: service,
                      ),
                      _PrivateImageCard(
                        title: 'Live Selfie',
                        path: request.liveSelfiePath,
                        service: service,
                      ),
                    ],
                  ),
                ),
              ),
              if (request.isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRequestAgain,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Request new documents'),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Approve worker'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateImageCard extends StatelessWidget {
  const _PrivateImageCard({
    required this.title,
    required this.path,
    required this.service,
  });

  final String title;
  final String path;
  final VerificationManagementService service;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 330,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 17),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Expanded(
              child: path.isEmpty
                  ? const Center(child: Text('Document path missing'))
                  : FutureBuilder<String?>(
                      future: service.getPrivateImageUrl(path),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF16A34A),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'Image load nahi hui.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          );
                        }

                        final imageUrl = snapshot.data;

                        if (imageUrl == null || imageUrl.isEmpty) {
                          return const Center(child: Text('Image unavailable'));
                        }

                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Image display nahi ho saki.\n$error',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 8.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 56,
            color: Color(0xFF16A34A),
          ),
          SizedBox(height: 14),
          Text('No verification requests found'),
        ],
      ),
    );
  }
}

String _filterLabel(VerificationFilter filter) => switch (filter) {
  VerificationFilter.all => 'All',
  VerificationFilter.pending => 'Pending',
  VerificationFilter.approved => 'Approved',
  VerificationFilter.rejected => 'Rejected',
  VerificationFilter.moreInfo => 'More info',
};

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return const Color(0xFF16A34A);
    case 'rejected':
      return const Color(0xFFDC2626);
    case 'more_information_required':
      return const Color(0xFF7C3AED);
    default:
      return const Color(0xFFD97706);
  }
}
