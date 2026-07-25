import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/Notification_screen/notification_screen.dart';
import 'package:skill_link/screens/worker_screens/All_jobs/all_job_screen.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/home_screen/JobsByStatusScreen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF0F7A38);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);

  final String uid = FirebaseAuth.instance.currentUser!.uid;
  final Set<String> _acceptingRequestIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 0),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _primary,
          backgroundColor: Colors.white,
          onRefresh: () async {
            setState(() {});
            await Future<void>.delayed(const Duration(milliseconds: 450));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _topHeader(),
                    const SizedBox(height: 22),
                    _earningCard(),
                    const SizedBox(height: 18),
                    _statsRow(),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      title: 'Jobs for you',
                      subtitle: 'Matched with your service category',
                    ),
                    const SizedBox(height: 14),
                    _requestList(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topHeader() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = (data?['name'] ?? 'Worker').toString().trim();
        final skill = (data?['skill'] ?? 'Professional worker').toString();
        final imageUrl =
            (data?['profileImage'] ??
                    data?['profileImageUrl'] ??
                    data?['imageUrl'] ??
                    '')
                .toString();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _profileAvatar(name: name, imageUrl: imageUrl),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Hi, ${_firstName(name)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 21,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text('👋', style: TextStyle(fontSize: 19)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    skill.isEmpty ? 'Professional worker' : skill,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _notificationButton(),
          ],
        );
      },
    );
  }

  Widget _profileAvatar({required String name, required String imageUrl}) {
    final initial = name.trim().isEmpty ? 'W' : name.trim()[0].toUpperCase();

    return Container(
      height: 54,
      width: 54,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(initial),
              )
            : _avatarFallback(initial),
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, Color(0xFF4ADE80)],
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _notificationButton() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: _border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D0F172A),
                        blurRadius: 15,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: _textPrimary,
                    size: 25,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 21,
                        minHeight: 21,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _background, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _earningCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .where('workerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int totalEarnings = 0;

        for (final doc in docs) {
          totalEarnings += _extractAmount(doc.data()['budget']);
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 18, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryDark, _primary, Color(0xFF36C768)],
              stops: [0, 0.55, 1],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3516A34A),
                blurRadius: 28,
                offset: Offset(0, 13),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -55,
                right: -35,
                child: Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -70,
                right: 55,
                child: Container(
                  height: 115,
                  width: 115,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.16),
                          ),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Text(
                        'TOTAL EARNINGS',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${docs.length} completed',
                              style: const TextStyle(
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
                  const SizedBox(height: 20),
                  Text(
                    _formatCurrency(totalEarnings),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Your earnings from completed jobs',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where('status', isEqualTo: 'searching')
                .snapshots(),
            builder: (context, snapshot) {
              return _statCard(
                title: 'Available',
                subtitle: 'New job requests',
                value: '${snapshot.data?.docs.length ?? 0}',
                icon: Icons.work_outline_rounded,
                accentColor: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JobsByStatusScreen(
                        title: 'Pending Jobs',
                        status: 'searching',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where('workerId', isEqualTo: uid)
                .where(
                  'status',
                  whereIn: ['accepted', 'on_the_way', 'in_progress'],
                )
                .snapshots(),
            builder: (context, snapshot) {
              return _statCard(
                title: 'Active',
                subtitle: 'Jobs in progress',
                value: '${snapshot.data?.docs.length ?? 0}',
                icon: Icons.flash_on_rounded,
                accentColor: const Color(0xFF2563EB),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JobsByStatusScreen(
                        title: 'Active Jobs',
                        status: 'active',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
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
                    height: 41,
                    width: 41,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: accentColor.withOpacity(0.8),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                value,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllJobsScreen()),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _primary,
                    size: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _requestList() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, workerSnapshot) {
        if (workerSnapshot.connectionState == ConnectionState.waiting) {
          return _jobsLoadingState();
        }

        if (workerSnapshot.hasError) {
          return _errorState('Unable to load your profile');
        }

        final workerData = workerSnapshot.data?.data();
        final workerSkill = (workerData?['skill'] ?? '').toString();

        if (workerSkill.trim().isEmpty) {
          return _emptyJobs(
            icon: Icons.manage_accounts_outlined,
            title: 'Complete your worker profile',
            message: 'Add your skill to receive matching job requests.',
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .where('status', isEqualTo: 'searching')
              .where('category', isEqualTo: workerSkill)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _jobsLoadingState();
            }

            if (snapshot.hasError) {
              return _errorState('Unable to load job requests');
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return _emptyJobs(
                icon: Icons.search_off_rounded,
                title: 'No matching jobs right now',
                message:
                    'New ${workerSkill.toLowerCase()} requests will appear here.',
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();

                return _jobCard(
                  requestId: doc.id,
                  title: (data['title'] ?? 'Service request').toString(),
                  category: (data['category'] ?? workerSkill).toString(),
                  location: (data['location'] ?? 'Location not provided')
                      .toString(),
                  budget: (data['budget'] ?? 'Budget not provided').toString(),
                  urgency: (data['urgency'] ?? 'Normal').toString(),
                  workerId: uid,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _jobCard({
    required String requestId,
    required String title,
    required String category,
    required String location,
    required String budget,
    required String urgency,
    required String workerId,
  }) {
    final urgencyStyle = _urgencyStyle(urgency);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, 9),
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
                height: 49,
                width: 49,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8EF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
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
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 5),
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: urgencyStyle.background,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  urgencyStyle.label,
                  style: TextStyle(
                    color: urgencyStyle.foreground,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _jobInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: location,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: _border),
                ),
                _jobInfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Budget',
                  value: budget,
                  valueColor: _primaryDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 47,
                  child: OutlinedButton(
                    onPressed: () => _showSkipMessage(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: const BorderSide(color: _border, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                flex: 2,
                child: _acceptButton(requestId: requestId, workerId: workerId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _jobInfoRow({
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
          child: Icon(icon, size: 18, color: _textSecondary),
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

  Widget _acceptButton({required String requestId, required String workerId}) {
    final isLoading = _acceptingRequestIds.contains(requestId);

    return SizedBox(
      height: 47,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () => _acceptJob(requestId: requestId, workerId: workerId),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.55),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          shadowColor: _primary.withOpacity(0.3),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loader'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  key: ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Accept job',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _acceptJob({
    required String requestId,
    required String workerId,
  }) async {
    setState(() => _acceptingRequestIds.add(requestId));

    try {
      final requestRef = FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId);

      final requestDoc = await requestRef.get();
      final requestData = requestDoc.data();

      if (!requestDoc.exists || requestData == null) {
        throw Exception('This job is no longer available.');
      }

      if ((requestData['status'] ?? '').toString() != 'searching') {
        throw Exception('Another worker has already accepted this job.');
      }

      final customerId = requestData['customerId'];
      final category = (requestData['category'] ?? 'Service').toString();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(requestRef);
        final freshData = freshSnapshot.data();

        if (!freshSnapshot.exists ||
            freshData == null ||
            (freshData['status'] ?? '').toString() != 'searching') {
          throw Exception('Another worker has already accepted this job.');
        }

        transaction.update(requestRef, {
          'status': 'accepted',
          'workerId': workerId,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      final existingChat = await FirebaseFirestore.instance
          .collection('chats')
          .where('requestId', isEqualTo: requestId)
          .where('workerId', isEqualTo: workerId)
          .limit(1)
          .get();

      if (existingChat.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('chats').add({
          'customerId': customerId,
          'workerId': workerId,
          'requestId': requestId,
          'service': category,
          'lastMessage': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            backgroundColor: _textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Job accepted successfully',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      final message = error
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('[cloud_firestore/aborted] ', '');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            backgroundColor: const Color(0xFFB91C1C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Text(
              message.isEmpty ? 'Unable to accept this job.' : message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _acceptingRequestIds.remove(requestId));
      }
    }
  }

  Widget _jobsLoadingState() {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          height: 205,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          ),
        ),
      ),
    );
  }

  Widget _emptyJobs({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 27),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8EF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primary, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
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

  Widget _errorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF991B1B),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  void _showSkipMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          backgroundColor: _textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Text(
            'Job skipped. You can still find it in All Jobs.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  int _extractAmount(dynamic value) {
    final text = value?.toString() ?? '0';
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  String _formatCurrency(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return 'Rs. $formatted';
  }

  String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Worker';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  _UrgencyStyle _urgencyStyle(String urgency) {
    switch (urgency.trim().toLowerCase()) {
      case 'urgent':
      case 'high':
        return const _UrgencyStyle(
          label: 'URGENT',
          foreground: Color(0xFFB91C1C),
          background: Color(0xFFFEE2E2),
        );
      case 'low':
        return const _UrgencyStyle(
          label: 'LOW',
          foreground: Color(0xFF2563EB),
          background: Color(0xFFDBEAFE),
        );
      default:
        return const _UrgencyStyle(
          label: 'NORMAL',
          foreground: Color(0xFFB45309),
          background: Color(0xFFFEF3C7),
        );
    }
  }
}

class _UrgencyStyle {
  final String label;
  final Color foreground;
  final Color background;

  const _UrgencyStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });
}
