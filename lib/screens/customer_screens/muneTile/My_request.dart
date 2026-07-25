import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  static const Color _background = Color(0xFFF4F7FB);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _buildMessageState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Login required',
                  subtitle: 'Please log in again to view your requests.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('requests')
                    .where('customerId', isEqualTo: currentUser.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    debugPrint('MyRequestsScreen error: ${snapshot.error}');
                    return _buildMessageState(
                      icon: Icons.error_outline_rounded,
                      title: 'Unable to load requests',
                      subtitle:
                          'Your requests could not be loaded right now.',
                    );
                  }

                  final requests = [...?snapshot.data?.docs];

                  requests.sort((a, b) {
                    final aDate = _getDate(a.data()['createdAt']);
                    final bDate = _getDate(b.data()['createdAt']);
                    return bDate.compareTo(aDate);
                  });

                  if (requests.isEmpty) {
                    return _buildMessageState(
                      icon: Icons.assignment_outlined,
                      title: 'No requests yet',
                      subtitle:
                          'Requests you send to workers will appear here.',
                    );
                  }

                  return Column(
                    children: [
                      _buildSummary(requests),
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            2,
                            16,
                            110,
                          ),
                          itemCount: requests.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final document = requests[index];

                            return _RequestCard(
                              data: document.data(),
                              onCancel: () => _cancelRequest(
                                context,
                                document.id,
                                document.data(),
                              ),
                              onDelete: () => _deleteRequest(
                                context,
                                document.id,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: _textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Requests',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.45,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Track and manage all service requests',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _primary.withOpacity(.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _primary,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> requests,
  ) {
    int pending = 0;
    int active = 0;
    int completed = 0;
    int cancelled = 0;

    for (final request in requests) {
      final status =
          request.data()['status']?.toString().toLowerCase().trim() ??
              'pending';

      if (status == 'completed') {
        completed++;
      } else if (status == 'accepted' ||
          status == 'in_progress' ||
          status == 'in progress') {
        active++;
      } else if (status == 'pending') {
        pending++;
      } else if (status == 'cancelled' ||
          status == 'canceled' ||
          status == 'rejected') {
        cancelled++;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _primary,
            _primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.23),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -65,
            right: -50,
            child: Container(
              height: 155,
              width: 155,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -55,
            child: Container(
              height: 170,
              width: 170,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.insights_outlined,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your service request activity at a glance',
                          style: TextStyle(
                            color: Color(0xD6FFFFFF),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '${requests.length} TOTAL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _summaryItem(
                      value: pending.toString(),
                      label: 'Pending',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryItem(
                      value: active.toString(),
                      label: 'Active',
                      icon: Icons.handyman_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryItem(
                      value: completed.toString(),
                      label: 'Done',
                      icon: Icons.task_alt_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryItem(
                      value: cancelled.toString(),
                      label: 'Closed',
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(.13),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(.76),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: _primary,
            strokeWidth: 2.5,
          ),
          SizedBox(height: 14),
          Text(
            'Loading your requests...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 30,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x070F172A),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.09),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: _primary,
                  size: 37,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelRequest(
    BuildContext context,
    String requestId,
    Map<String, dynamic> request,
  ) async {
    final status =
        request['status']?.toString().toLowerCase().trim() ?? 'pending';

    if (status != 'pending') {
      _showSnackBar(
        context,
        message: 'Only pending requests can be cancelled.',
        isError: true,
      );
      return;
    }

    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Cancel request?',
      message:
          'This request will no longer be available to the worker.',
      confirmText: 'Cancel Request',
      icon: Icons.cancel_outlined,
    );

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      _showSnackBar(
        context,
        message: 'Request cancelled successfully.',
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;

      _showSnackBar(
        context,
        message: error.message ?? 'Unable to cancel request.',
        isError: true,
      );
    }
  }

  Future<void> _deleteRequest(
    BuildContext context,
    String requestId,
  ) async {
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Delete request?',
      message:
          'This request will be permanently removed from your history.',
      confirmText: 'Delete',
      icon: Icons.delete_outline_rounded,
    );

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .delete();

      if (!context.mounted) return;

      _showSnackBar(
        context,
        message: 'Request deleted successfully.',
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;

      _showSnackBar(
        context,
        message: error.message ?? 'Unable to delete request.',
        isError: true,
      );
    }
  }

  Future<bool> _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required IconData icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 76,
                  width: 76,
                  decoration: BoxDecoration(
                    color: _danger.withOpacity(.09),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: _danger,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _danger,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          confirmText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  static DateTime _getDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
          content: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isError
                    ? const [
                        Color(0xFFDC2626),
                        Color(0xFFEF4444),
                      ]
                    : const [
                        Color(0xFF16A34A),
                        Color(0xFF14B8A6),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isError ? _danger : _success).withOpacity(.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 37,
                  width: 37,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError
                        ? Icons.error_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _RequestCard({
    required this.data,
    required this.onCancel,
    required this.onDelete,
  });

  static const Color _primary = Color(0xFF2563EB);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _cyan = Color(0xFF0891B2);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final title = _value(data['title'], 'Service Request');
    final category = _value(data['category'], 'General Service');
    final description =
        _value(data['description'], 'No description provided.');
    final location =
        _value(data['location'], 'Location not provided');
    final budget = _formatBudget(data['budget']);
    final urgency = _value(data['urgency'], 'Normal');
    final workerName = _value(data['workerName'], '');
    final workerId = _value(data['workerId'], '');
    final requestType = _value(data['requestType'], '');
    final isDirectRequest =
        workerId.isNotEmpty || requestType == 'direct';
    final status = _value(data['status'], 'pending').toLowerCase();
    final createdAt = MyRequestsScreen._getDate(data['createdAt']);
    final statusStyle = _statusStyle(status);

    final canCancel = status == 'pending';
    final canDelete = status == 'cancelled' ||
        status == 'canceled' ||
        status == 'completed' ||
        status == 'rejected';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            Container(
              height: 5,
              width: double.infinity,
              color: statusStyle.color,
            ),
            Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              statusStyle.color.withOpacity(.16),
                              statusStyle.color.withOpacity(.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          _categoryIcon(category),
                          color: statusStyle.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.category_outlined,
                                  color: _textSecondary,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(statusStyle),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _detailTile(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: location,
                          color: _cyan,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _detailTile(
                          icon: Icons.payments_outlined,
                          label: 'Budget',
                          value: budget,
                          color: _success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _detailTile(
                          icon: Icons.bolt_outlined,
                          label: 'Urgency',
                          value: urgency,
                          color: _warning,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _detailTile(
                          icon: isDirectRequest
                              ? Icons.person_pin_circle_outlined
                              : Icons.public_rounded,
                          label: 'Request Type',
                          value: isDirectRequest
                              ? workerName.isNotEmpty
                                  ? workerName
                                  : 'Direct request'
                              : 'Public request',
                          color: _purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Divider(
                    height: 1,
                    color: _border,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: _textSecondary,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Created',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(createdAt),
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canCancel)
                        TextButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                          ),
                          label: const Text('Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: _danger,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      if (canDelete)
                        Material(
                          color: _danger.withOpacity(.08),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onDelete,
                            child: const SizedBox(
                              height: 38,
                              width: 38,
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: _danger,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(_StatusStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: style.color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: style.color.withOpacity(.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            color: style.color,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 7.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    final value = category.toLowerCase();

    if (value.contains('electric')) {
      return Icons.electrical_services_outlined;
    }

    if (value.contains('plumb')) {
      return Icons.plumbing_outlined;
    }

    if (value.contains('paint')) {
      return Icons.format_paint_outlined;
    }

    if (value.contains('carpent')) {
      return Icons.carpenter_outlined;
    }

    if (value.contains('clean')) {
      return Icons.cleaning_services_outlined;
    }

    if (value.contains('repair')) {
      return Icons.build_outlined;
    }

    return Icons.home_repair_service_outlined;
  }

  static _StatusStyle _statusStyle(String status) {
    switch (status) {
      case 'accepted':
        return const _StatusStyle(
          'Accepted',
          _primary,
          Icons.check_circle_outline_rounded,
        );
      case 'in_progress':
      case 'in progress':
        return const _StatusStyle(
          'In Progress',
          _primary,
          Icons.handyman_outlined,
        );
      case 'completed':
        return const _StatusStyle(
          'Completed',
          _success,
          Icons.task_alt_rounded,
        );
      case 'cancelled':
      case 'canceled':
        return const _StatusStyle(
          'Cancelled',
          _danger,
          Icons.cancel_outlined,
        );
      case 'rejected':
        return const _StatusStyle(
          'Rejected',
          _danger,
          Icons.block_rounded,
        );
      default:
        return const _StatusStyle(
          'Pending',
          _warning,
          Icons.schedule_rounded,
        );
    }
  }

  static String _value(
    dynamic value,
    String fallback,
  ) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty || text.toLowerCase() == 'null'
        ? fallback
        : text;
  }

  static String _formatBudget(dynamic value) {
    final budget = value?.toString().trim() ?? '';

    if (budget.isEmpty || budget.toLowerCase() == 'null') {
      return 'Budget not provided';
    }

    return budget.toLowerCase().startsWith('rs')
        ? budget
        : 'Rs $budget';
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Date unavailable';
    }

    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    }

    if (difference.inDays == 0) {
      return '${difference.inHours} hours ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusStyle(
    this.label,
    this.color,
    this.icon,
  );
}
