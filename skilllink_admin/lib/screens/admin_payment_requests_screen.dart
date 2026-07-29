import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/credit_management_service.dart';

enum PaymentRequestFilter { all, pending, approved, rejected }

class AdminPaymentRequestsScreen extends StatefulWidget {
  const AdminPaymentRequestsScreen({super.key});

  @override
  State<AdminPaymentRequestsScreen> createState() =>
      _AdminPaymentRequestsScreenState();
}

class _AdminPaymentRequestsScreenState
    extends State<AdminPaymentRequestsScreen> {
  static const _primary = Color(0xFF16A34A);
  static const _warning = Color(0xFFF59E0B);
  static const _danger = Color(0xFFDC2626);
  static const _blue = Color(0xFF2563EB);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _background = Color(0xFFF5F7FB);

  final CreditManagementService _service = CreditManagementService();
  final TextEditingController _searchController = TextEditingController();

  PaymentRequestFilter _filter = PaymentRequestFilter.pending;
  String _search = '';
  String? _processingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _search.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data();
      final status =
          data['status']?.toString().toLowerCase().trim() ?? 'pending';

      final statusMatches = switch (_filter) {
        PaymentRequestFilter.all => true,
        PaymentRequestFilter.pending => status == 'pending',
        PaymentRequestFilter.approved => status == 'approved',
        PaymentRequestFilter.rejected => status == 'rejected',
      };

      if (!statusMatches) return false;
      if (q.isEmpty) return true;

      return [
        doc.id,
        data['workerName'],
        data['workerEmail'],
        data['transactionId'],
        data['workerId'],
      ].join(' ').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _approve(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    if (_processingId != null) return;

    final data = request.data();
    final credits = _toInt(data['credits']);
    final workerName = _textValue(data['workerName'], 'Worker');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve payment?'),
        content: Text(
          '$credits credits will be added to $workerName\'s wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _primary),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingId = request.id);

    try {
      final adminId =
          FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      await _service.approvePayment(
        requestId: request.id,
        adminId: adminId,
      );

      if (!mounted) return;
      _snack('$credits credits approved and added.');
    } catch (error) {
      if (!mounted) return;
      _snack(
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _reject(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    if (_processingId != null) return;

    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject payment'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Rejection reason',
            hintText: 'Receipt unclear or payment not found',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (reason == null || !mounted) return;

    setState(() => _processingId = request.id);

    try {
      final adminId =
          FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      await _service.rejectPayment(
        requestId: request.id,
        reason: reason,
        adminId: adminId,
      );

      if (!mounted) return;
      _snack('Payment request rejected.');
    } catch (error) {
      if (!mounted) return;
      _snack(
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _view(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final data = request.data();
    final receiptPath = data['receiptPath']?.toString().trim() ?? '';

    String? receiptUrl;
    if (receiptPath.isNotEmpty) {
      try {
        receiptUrl =
            await FirebaseStorage.instance.ref(receiptPath).getDownloadURL();
      } catch (_) {}
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final status =
            data['status']?.toString().toLowerCase() ?? 'pending';
        final color = _statusColor(status);

        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Payment Request',
                            style: GoogleFonts.inter(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Detail('Worker', _textValue(data['workerName'], 'Worker')),
                        _Detail('Email', _textValue(data['workerEmail'], 'No email')),
                        _Detail('Credits', '${_toInt(data['credits'])}'),
                        _Detail(
                          'Amount',
                          'Rs. ${NumberFormat('#,##0').format(_toInt(data['amount']))}',
                        ),
                        _Detail(
                          'Transaction ID',
                          _textValue(data['transactionId'], 'Not provided'),
                        ),
                        _Detail('Status', status.toUpperCase(), color: color),
                        _Detail('Submitted', _formatDate(data['createdAt'])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Payment Receipt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 320,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: receiptUrl == null
                          ? const Center(
                              child: Text('Receipt could not be loaded.'),
                            )
                          : InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 5,
                              child: Image.network(
                                receiptUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Center(
                                  child: Text('Receipt could not be displayed.'),
                                ),
                              ),
                            ),
                    ),
                    if (status == 'rejected' &&
                        _textValue(data['rejectionReason'], '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Reason: ${data['rejectionReason']}',
                        style: const TextStyle(
                          color: _danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (status == 'pending') ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _reject(request);
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _danger,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _approve(request);
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? _danger : _primary,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('payment_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load requests: ${snapshot.error}'),
            );
          }

          final all = snapshot.data?.docs ?? [];
          final filtered = _filtered(all);

          final pending = _count(all, 'pending');
          final approved = _count(all, 'approved');
          final rejected = _count(all, 'rejected');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Requests',
                  style: GoogleFonts.inter(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Review, approve, and reject worker payment proofs.',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _StatCard('Pending', pending, _warning),
                    _StatCard('Approved', approved, _primary),
                    _StatCard('Rejected', rejected, _danger),
                    _StatCard('Total', all.length, _blue),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _search = value),
                        decoration: const InputDecoration(
                          hintText:
                              'Search worker, email or transaction ID...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: PaymentRequestFilter.values.map((item) {
                          return ChoiceChip(
                            label: Text(_filterLabel(item)),
                            selected: _filter == item,
                            onSelected: (_) => setState(() => _filter = item),
                            selectedColor: _primary.withOpacity(.12),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (filtered.isEmpty)
                  const _EmptyState()
                else
                  _RequestTable(
                    requests: filtered,
                    processingId: _processingId,
                    onView: _view,
                    onApprove: _approve,
                    onReject: _reject,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static int _count(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String status,
  ) {
    return docs
        .where(
          (doc) =>
              doc.data()['status']?.toString().toLowerCase() == status,
        )
        .length;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static String _textValue(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(value.toDate());
    }
    return 'Date unavailable';
  }

  static Color _statusColor(String status) {
    if (status == 'approved') return _primary;
    if (status == 'rejected') return _danger;
    return _warning;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.title, this.value, this.color);

  final String title;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 235,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _AdminPaymentRequestsScreenState._border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.10),
            child: Icon(Icons.receipt_long, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(title, style: const TextStyle(color: _AdminPaymentRequestsScreenState._muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestTable extends StatelessWidget {
  const _RequestTable({
    required this.requests,
    required this.processingId,
    required this.onView,
    required this.onApprove,
    required this.onReject,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> requests;
  final String? processingId;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onView;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onApprove;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AdminPaymentRequestsScreenState._border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('WORKER')),
            DataColumn(label: Text('PACKAGE')),
            DataColumn(label: Text('TRANSACTION ID')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: requests.map((request) {
            final data = request.data();
            final status =
                data['status']?.toString().toLowerCase() ?? 'pending';
            final color =
                _AdminPaymentRequestsScreenState._statusColor(status);
            final processing = processingId == request.id;

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 210,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _AdminPaymentRequestsScreenState._textValue(
                            data['workerName'],
                            'Worker',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _AdminPaymentRequestsScreenState._textValue(
                            data['workerEmail'],
                            'No email',
                          ),
                          style: const TextStyle(
                            color: _AdminPaymentRequestsScreenState._muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_AdminPaymentRequestsScreenState._toInt(data['credits'])} credits\n'
                    'Rs. ${_AdminPaymentRequestsScreenState._toInt(data['amount'])}',
                  ),
                ),
                DataCell(
                  Text(
                    _AdminPaymentRequestsScreenState._textValue(
                      data['transactionId'],
                      'Not provided',
                    ),
                  ),
                ),
                DataCell(
                  Chip(
                    label: Text(status.toUpperCase()),
                    backgroundColor: color.withOpacity(.10),
                    labelStyle: TextStyle(color: color),
                  ),
                ),
                DataCell(
                  processing
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'View receipt',
                              onPressed: () => onView(request),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                color: _AdminPaymentRequestsScreenState._blue,
                              ),
                            ),
                            if (status == 'pending') ...[
                              IconButton(
                                tooltip: 'Reject',
                                onPressed: () => onReject(request),
                                icon: const Icon(
                                  Icons.close,
                                  color: _AdminPaymentRequestsScreenState._danger,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Approve',
                                onPressed: () => onApprove(request),
                                icon: const Icon(
                                  Icons.check,
                                  color: _AdminPaymentRequestsScreenState._primary,
                                ),
                              ),
                            ],
                          ],
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

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _AdminPaymentRequestsScreenState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _AdminPaymentRequestsScreenState._muted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color ?? _AdminPaymentRequestsScreenState._text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 70),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AdminPaymentRequestsScreenState._border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 55, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'No payment requests found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

String _filterLabel(PaymentRequestFilter filter) {
  switch (filter) {
    case PaymentRequestFilter.all:
      return 'All';
    case PaymentRequestFilter.pending:
      return 'Pending';
    case PaymentRequestFilter.approved:
      return 'Approved';
    case PaymentRequestFilter.rejected:
      return 'Rejected';
  }
}
