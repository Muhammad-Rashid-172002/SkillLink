import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/request_tracking_screen.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/customer_home_screen.dart';

class CustomerMyRequestsScreen extends StatefulWidget {
  const CustomerMyRequestsScreen({super.key});

  @override
  State<CustomerMyRequestsScreen> createState() =>
      _CustomerMyRequestsScreenState();
}

class _CustomerMyRequestsScreenState
    extends State<CustomerMyRequestsScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _pending = Color(0xFFF59E0B);
  static const Color _accepted = Color(0xFF2563EB);
  static const Color _completed = Color(0xFF16A34A);

  int _selectedTab = 0;

  final List<RequestTabData> _tabs = const [
    RequestTabData(
      title: 'Pending',
      status: 'pending',
      icon: Icons.schedule_rounded,
      color: _pending,
    ),
    RequestTabData(
      title: 'Accepted',
      status: 'accepted',
      icon: Icons.handshake_outlined,
      color: _accepted,
    ),
    RequestTabData(
      title: 'Completed',
      status: 'completed',
      icon: Icons.task_alt_rounded,
      color: _completed,
    ),
  ];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _requestsStream {
    return FirebaseFirestore.instance
        .collection('requests')
        .where('customerId', isEqualTo: _uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _ambientCircle(
              size: 330,
              color: _primary.withOpacity(0.09),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -130,
            child: _ambientCircle(
              size: 340,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _requestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return _loadingScreen();
                }

                if (snapshot.hasError) {
                  return _errorScreen();
                }

                final allRequests = snapshot.data?.docs ?? [];

                final pendingCount = allRequests
                    .where(
                      (doc) =>
                          _statusValue(doc.data()['status']) == 'pending',
                    )
                    .length;

                final acceptedCount = allRequests
                    .where(
                      (doc) =>
                          _statusValue(doc.data()['status']) == 'accepted',
                    )
                    .length;

                final completedCount = allRequests
                    .where(
                      (doc) =>
                          _statusValue(doc.data()['status']) == 'completed',
                    )
                    .length;

                final selectedStatus = _tabs[_selectedTab].status;

                final filteredRequests = allRequests.where((doc) {
                  return _statusValue(doc.data()['status']) ==
                      selectedStatus;
                }).toList();

                filteredRequests.sort((first, second) {
                  final firstDate = _extractDate(first.data());
                  final secondDate = _extractDate(second.data());
                  return secondDate.compareTo(firstDate);
                });

                return RefreshIndicator(
                  color: _primary,
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 550),
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          14,
                          20,
                          40,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            [
                              _topBar(),
                              const SizedBox(height: 20),
                              _heroCard(
                                total: allRequests.length,
                                pending: pendingCount,
                                accepted: acceptedCount,
                                completed: completedCount,
                              ),
                              const SizedBox(height: 22),
                              _statusTabs(
                                pendingCount: pendingCount,
                                acceptedCount: acceptedCount,
                                completedCount: completedCount,
                              ),
                              const SizedBox(height: 24),
                              _sectionHeader(
                                count: filteredRequests.length,
                              ),
                              const SizedBox(height: 14),
                              if (filteredRequests.isEmpty)
                                _emptyState()
                              else
                                ...filteredRequests.map(
                                  (doc) => _requestCard(
                                    requestId: doc.id,
                                    data: doc.data(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerHomeScreen(),
                  ),
                );
              }
            },
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x070F172A),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textPrimary,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My requests',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Track every service request in one place',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _secondary],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.20),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.assignment_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
      ],
    );
  }

  Widget _heroCard({
    required int total,
    required int pending,
    required int accepted,
    required int completed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -75,
            right: -55,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -95,
            left: -60,
            child: Container(
              height: 190,
              width: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'REQUEST OVERVIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '$total total requests',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stay updated with the latest progress of your service requests.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 11.7,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _heroMetric(
                      value: '$pending',
                      label: 'Pending',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _heroMetric(
                      value: '$accepted',
                      label: 'Accepted',
                      icon: Icons.handshake_outlined,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _heroMetric(
                      value: '$completed',
                      label: 'Completed',
                      icon: Icons.task_alt_rounded,
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

  Widget _heroMetric({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.16),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 8.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTabs({
    required int pendingCount,
    required int acceptedCount,
    required int completedCount,
  }) {
    final counts = [
      pendingCount,
      acceptedCount,
      completedCount,
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final tab = _tabs[index];
          final selected = _selectedTab == index;

          return Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: () {
                  setState(() => _selectedTab = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? tab.color : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: tab.color.withOpacity(0.20),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab.icon,
                            color: selected
                                ? Colors.white
                                : tab.color,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            tab.title,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : _textPrimary,
                              fontSize: 10.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${counts[index]} requests',
                        style: TextStyle(
                          color: selected
                              ? Colors.white.withOpacity(0.74)
                              : _textSecondary,
                          fontSize: 8.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _sectionHeader({
    required int count,
  }) {
    final selectedTab = _tabs[_selectedTab];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selectedTab.title} requests',
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count == 1
                    ? '1 request found'
                    : '$count requests found',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selectedTab.color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Icon(
                selectedTab.icon,
                color: selectedTab.color,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                selectedTab.title,
                style: TextStyle(
                  color: selectedTab.color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _requestCard({
    required String requestId,
    required Map<String, dynamic> data,
  }) {
    final title = _fallback(
      data['title'],
      'Service request',
    );

    final category = _fallback(
      data['category'],
      'General service',
    );

    final location = _fallback(
      data['location'],
      data['address']?.toString().trim().isNotEmpty == true
          ? data['address'].toString()
          : 'Location not provided',
    );

    final budget = _formatBudget(data['budget']);
    final status = _statusValue(data['status']);
    final date = _extractDate(data);
    final statusData = _statusDesign(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 17,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: _categoryColor(category).withOpacity(0.11),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: _categoryColor(category),
                  size: 27,
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
                        fontSize: 14.8,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              _statusBadge(statusData),
            ],
          ),
          const SizedBox(height: 15),
          _progressTrack(status),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _infoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  value: location,
                ),
                const SizedBox(height: 11),
                _infoDivider(),
                const SizedBox(height: 11),
                _infoRow(
                  icon: Icons.payments_outlined,
                  title: 'Budget',
                  value: budget,
                ),
                const SizedBox(height: 11),
                _infoDivider(),
                const SizedBox(height: 11),
                _infoRow(
                  icon: Icons.schedule_rounded,
                  title: 'Created',
                  value: _formatDate(date),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestTrackingScreen(
                          requestId: requestId,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: const BorderSide(color: _border),
                    minimumSize: const Size(0, 47),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 17,
                  ),
                  label: const Text(
                    'View details',
                    style: TextStyle(
                      fontSize: 10.7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _primaryAction(
                    status: status,
                    requestId: requestId,
                    data: data,
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor: Colors.white,
                    backgroundColor: statusData.color,
                    disabledBackgroundColor:
                        _textSecondary.withOpacity(0.25),
                    minimumSize: const Size(0, 47),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: Icon(
                    _actionIcon(status),
                    size: 16,
                  ),
                  label: Text(
                    _actionLabel(status),
                    style: const TextStyle(
                      fontSize: 10.7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(StatusDesign design) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: design.color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            design.icon,
            color: design.color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            design.label,
            style: TextStyle(
              color: design.color,
              fontSize: 9.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressTrack(String status) {
    final currentIndex = status == 'completed'
        ? 2
        : status == 'accepted'
            ? 1
            : 0;

    const labels = [
      'Pending',
      'Accepted',
      'Completed',
    ];

    return Column(
      children: [
        Row(
          children: List.generate(3, (index) {
            final reached = index <= currentIndex;

            return Expanded(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 24,
                    width: 24,
                    decoration: BoxDecoration(
                      color: reached
                          ? _tabs[index].color
                          : const Color(0xFFE8EDF4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      reached
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                      color: reached
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                      size: 13,
                    ),
                  ),
                  if (index != 2)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: index < currentIndex
                              ? _tabs[index + 1].color
                              : const Color(0xFFE8EDF4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 7),
        Row(
          children: labels.map((label) {
            return Expanded(
              child: Text(
                label,
                textAlign: label == 'Pending'
                    ? TextAlign.left
                    : label == 'Completed'
                        ? TextAlign.right
                        : TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 8.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 33,
          width: 33,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: _primary,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 8.7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 10.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoDivider() {
    return Container(
      height: 1,
      color: _border,
    );
  }

  VoidCallback? _primaryAction({
    required String status,
    required String requestId,
    required Map<String, dynamic> data,
  }) {
    if (status == 'pending') {
      return null;
    }

    if (status == 'accepted') {
      return () {
        _showMessage(
          'Chat screen navigation can be connected here.',
        );
      };
    }

    return () {
      _showMessage(
        'Worker rating screen can be connected here.',
      );
    };
  }

  String _actionLabel(String status) {
    if (status == 'accepted') return 'Chat worker';
    if (status == 'completed') return 'Rate worker';
    return 'Waiting';
  }

  IconData _actionIcon(String status) {
    if (status == 'accepted') return Icons.chat_bubble_outline_rounded;
    if (status == 'completed') return Icons.star_outline_rounded;
    return Icons.hourglass_top_rounded;
  }

  Widget _emptyState() {
    final tab = _tabs[_selectedTab];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: tab.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              tab.icon,
              color: tab.color,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${tab.title.toLowerCase()} requests',
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _emptyMessage(tab.status),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10.8,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tab.status == 'pending') ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerHomeScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                foregroundColor: Colors.white,
                backgroundColor: _primary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                size: 18,
              ),
              label: const Text(
                'Create a request',
                style: TextStyle(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        child: Column(
          children: [
            _topBar(),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _border),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: _primary,
                        strokeWidth: 2.6,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Loading your requests...',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        child: Column(
          children: [
            _topBar(),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: _border),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: Color(0xFFDC2626),
                        size: 42,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Unable to load requests',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Please check your internet connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10.8,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyMessage(String status) {
    if (status == 'accepted') {
      return 'Requests accepted by workers will appear here.';
    }

    if (status == 'completed') {
      return 'Your completed service requests will appear here.';
    }

    return 'Create a new service request and track its progress here.';
  }

  StatusDesign _statusDesign(String status) {
    if (status == 'accepted') {
      return const StatusDesign(
        label: 'Accepted',
        icon: Icons.handshake_outlined,
        color: _accepted,
      );
    }

    if (status == 'completed') {
      return const StatusDesign(
        label: 'Completed',
        icon: Icons.task_alt_rounded,
        color: _completed,
      );
    }

    return const StatusDesign(
      label: 'Pending',
      icon: Icons.schedule_rounded,
      color: _pending,
    );
  }

  String _statusValue(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    if (status == 'accepted') return 'accepted';
    if (status == 'completed') return 'completed';
    return 'pending';
  }

  String _fallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatBudget(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) return 'Budget not specified';

    if (text.toLowerCase().contains('rs')) return text;

    return 'Rs. $text';
  }

  DateTime _extractDate(Map<String, dynamic> data) {
    final value =
        data['createdAt'] ?? data['timestamp'] ?? data['date'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Recently';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    }
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
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

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();

    if (value.contains('electric')) {
      return Icons.electrical_services_rounded;
    }
    if (value.contains('plumb')) return Icons.plumbing_rounded;
    if (value.contains('paint')) return Icons.format_paint_rounded;
    if (value.contains('carpenter')) return Icons.carpenter_rounded;
    if (value.contains('ac') || value.contains('air')) {
      return Icons.ac_unit_rounded;
    }
    if (value.contains('clean')) {
      return Icons.cleaning_services_rounded;
    }

    return Icons.home_repair_service_rounded;
  }

  Color _categoryColor(String category) {
    final value = category.toLowerCase();

    if (value.contains('electric')) return const Color(0xFFF59E0B);
    if (value.contains('plumb')) return const Color(0xFF06B6D4);
    if (value.contains('paint')) return const Color(0xFF8B5CF6);
    if (value.contains('carpenter')) return const Color(0xFFF97316);
    if (value.contains('ac') || value.contains('air')) {
      return const Color(0xFF0EA5E9);
    }
    if (value.contains('clean')) return const Color(0xFF10B981);

    return _primary;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: _textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  Widget _ambientCircle({
    required double size,
    required Color color,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 50,
        sigmaY: 50,
      ),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class RequestTabData {
  final String title;
  final String status;
  final IconData icon;
  final Color color;

  const RequestTabData({
    required this.title,
    required this.status,
    required this.icon,
    required this.color,
  });
}

class StatusDesign {
  final String label;
  final IconData icon;
  final Color color;

  const StatusDesign({
    required this.label,
    required this.icon,
    required this.color,
  });
}
