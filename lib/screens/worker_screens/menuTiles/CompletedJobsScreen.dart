import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CompletedJobsScreen extends StatelessWidget {
  const CompletedJobsScreen({super.key});

  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF0F7A38);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        foregroundColor: _textPrimary,
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 21),
            ),
          ),
        ),
        title: const Text(
          'Completed Jobs',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: currentUser == null
            ? _authErrorState()
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('requests')
                    .where('workerId', isEqualTo: currentUser.uid)
                    .where('status', isEqualTo: 'completed')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _loadingState();
                  }

                  if (snapshot.hasError) {
                    return _errorState(snapshot.error.toString());
                  }

                  final jobs = snapshot.data?.docs ?? [];

                  jobs.sort((a, b) {
                    final aDate = _extractDate(a.data());
                    final bDate = _extractDate(b.data());
                    return bDate.compareTo(aDate);
                  });

                  return RefreshIndicator(
                    color: _primary,
                    onRefresh: () async {
                      await Future<void>.delayed(
                        const Duration(milliseconds: 450),
                      );
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _summaryCard(jobs),
                              const SizedBox(height: 24),
                              _sectionHeader(jobs.length),
                              const SizedBox(height: 14),
                              if (jobs.isEmpty)
                                _emptyState()
                              else
                                ...List.generate(
                                  jobs.length,
                                  (index) {
                                    final doc = jobs[index];
                                    return _jobCard(
                                      data: doc.data(),
                                      index: index,
                                    );
                                  },
                                ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _summaryCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
  ) {
    final totalJobs = jobs.length;
    final totalEarnings = jobs.fold<double>(
      0,
      (sum, doc) => sum + _extractAmount(doc.data()['budget']),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, Color(0xFF3DD56E)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3116A34A),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -55,
            right: -42,
            child: Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            right: 42,
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
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
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'WORK HISTORY',
                      style: TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 23),
              Text(
                '$totalJobs',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Successfully completed jobs',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'Recorded job value',
                      style: TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      totalEarnings > 0
                          ? 'Rs. ${_formatNumber(totalEarnings)}'
                          : 'Not available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job history',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'All successfully completed customer requests',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count ${count == 1 ? 'job' : 'jobs'}',
              style: const TextStyle(
                color: _primaryDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _jobCard({
    required Map<String, dynamic> data,
    required int index,
  }) {
    final title = (data['title'] ?? 'Untitled job').toString();
    final category = (data['category'] ?? 'Service').toString();
    final location =
        (data['location'] ?? 'Location not provided').toString();
    final budget =
        (data['budget'] ?? 'Budget not provided').toString();
    final completedAt = _extractDate(data);
    final description = (data['description'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
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
                  color: const Color(0xFFEAF8EF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: _primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16.5,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: _primary,
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'DONE',
                      style: TextStyle(
                        color: _primaryDark,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              children: [
                _infoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: location,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: _border),
                ),
                _infoRow(
                  icon: Icons.payments_outlined,
                  label: 'Job budget',
                  value: budget,
                  valueColor: _primaryDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: Color(0xFF4F46E5),
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(completedAt),
                      style: const TextStyle(
                        color: Color(0xFF4338CA),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '#${(index + 1).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: _textSecondary,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? _textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 31),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Color(0xFFEAF8EF),
            child: Icon(
              Icons.work_history_outlined,
              color: _primary,
              size: 32,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No completed jobs yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Jobs marked as completed will automatically appear in your work history.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        Container(
          height: 210,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Loading completed jobs...',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(
          3,
          (_) => Container(
            height: 190,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: _primary,
                strokeWidth: 2.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFECACA),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load completed jobs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                error,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authErrorState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No signed-in worker account was found.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category.trim().toLowerCase()) {
      case 'electrician':
        return Icons.electrical_services_rounded;
      case 'plumber':
        return Icons.plumbing_rounded;
      case 'painter':
        return Icons.format_paint_rounded;
      case 'ac repair':
        return Icons.ac_unit_rounded;
      case 'carpenter':
        return Icons.carpenter_rounded;
      case 'cleaner':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  static DateTime _extractDate(Map<String, dynamic> data) {
    final possibleValues = [
      data['completedAt'],
      data['updatedAt'],
      data['createdAt'],
    ];

    for (final value in possibleValues) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _extractAmount(dynamic value) {
    if (value is num) return value.toDouble();

    final cleaned = value
        ?.toString()
        .replaceAll(RegExp(r'[^0-9.]'), '');

    return double.tryParse(cleaned ?? '') ?? 0;
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Date unavailable';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatNumber(double number) {
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }
}
