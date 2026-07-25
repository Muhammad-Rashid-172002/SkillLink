import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/Notification_screen/notification_screen.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart'
    hide ServiceOption;
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/AllServicesScreen.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/top_rated_workers_screen.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE4EAF2);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  int _selectedCategory = -1;

  final List<ServiceOption> _categories = allServices;
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _userStream =>
      FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _notificationStream =>
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _uid)
          .where('isRead', isEqualTo: false)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _workersStream =>
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .where('profileCompleted', isEqualTo: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const CustomerBottomBar(selectedIndex: 0),
      body: Stack(
        children: [
          Positioned(
            top: -130,
            right: -120,
            child: _ambientCircle(size: 320, color: _primary.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -150,
            left: -130,
            child: _ambientCircle(
              size: 340,
              color: _secondary.withOpacity(0.07),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: _primary,
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 650));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _topHeader(),
                        const SizedBox(height: 20),
                        _searchBar(),
                        const SizedBox(height: 20),
                        _heroBanner(),
                        const SizedBox(height: 24),
                        _quickStats(),
                        const SizedBox(height: 28),
                        _sectionHeader(
                          title: 'Popular services',
                          subtitle: 'Choose a service to get started',
                          action: 'See all',
                          onActionTap: () async {
                            final selectedService =
                                await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AllServicesScreen(),
                                  ),
                                );

                            if (selectedService == null || !context.mounted)
                              return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    Request(selectedService: selectedService),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                        _categoriesGrid(),
                        const SizedBox(height: 28),
                        _sectionHeader(
                          title: 'Top professionals',
                          subtitle: 'Highest-rated trusted workers',
                          action: 'View all',
                          onActionTap: _openAllWorkers,
                        ),
                        const SizedBox(height: 15),
                        _workersList(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAllWorkers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TopRatedWorkersScreen()),
    );
  }

  Widget _topHeader() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        final name = data?['name']?.toString().trim().isNotEmpty == true
            ? data!['name'].toString().trim()
            : 'Customer';

        final city = data?['city']?.toString().trim().isNotEmpty == true
            ? data!['city'].toString().trim()
            : 'Your city';

        return Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _secondary]),
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: _primary,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 10.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _notificationButton(),
          ],
        );
      },
    );
  }

  Widget _notificationButton() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationStream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x080F172A),
                        blurRadius: 14,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: _textPrimary,
                    size: 23,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _background, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
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

  Widget _searchBar() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value.trim().toLowerCase());
        },
        decoration: InputDecoration(
          hintText: 'Search electrician, plumber...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12.3,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 22,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Filters',
              onPressed: () {
                _showFeatureMessage('Advanced filters can be connected here.');
              },
              icon: const Icon(Icons.tune_rounded, color: _primary, size: 19),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _heroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
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
            top: -68,
            right: -50,
            child: Container(
              height: 175,
              width: 175,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -85,
            left: -55,
            child: Container(
              height: 175,
              width: 175,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        'FAST & TRUSTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Need help at\nhome today?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Post your request and connect with trusted professionals nearby.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 12.2,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 17),
                    SizedBox(
                      height: 43,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Request()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.white,
                          foregroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Post a request',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 112,
                width: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.verified_user_outlined,
            value: 'Verified',
            label: 'Professionals',
            color: _success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.schedule_rounded,
            value: 'Quick',
            label: 'Responses',
            color: _primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.star_outline_rounded,
            value: 'Rated',
            label: 'Services',
            color: _warning,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 9.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onActionTap,
  }) {
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
                  fontSize: 18.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          ),
          child: Row(
            children: [
              Text(
                action,
                style: const TextStyle(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoriesGrid() {
    final filtered = _categories.where((category) {
      if (_searchQuery.isEmpty) return true;
      return category.title.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return _emptySearchResult();
    }

    return GridView.builder(
      itemCount: filtered.length > 6 ? 6 : filtered.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final category = filtered[index];
        final originalIndex = _categories.indexOf(category);
        final selected = _selectedCategory == originalIndex;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          child: InkWell(
            borderRadius: BorderRadius.circular(21),
            onTap: () {
              setState(() => _selectedCategory = originalIndex);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Request(selectedService: category.title),
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? category.color.withOpacity(0.08) : _surface,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: selected ? category.color : _border,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x070F172A),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(category.icon, color: category.color, size: 23),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    category.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 11.2,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selected ? 'Selected' : 'Explore',
                    style: TextStyle(
                      color: selected ? category.color : _textSecondary,
                      fontSize: 8.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _workersList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _workersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _workerLoading();
        }

        if (snapshot.hasError) {
          return _errorCard('Unable to load workers right now.');
        }

        var workers = [...?snapshot.data?.docs];

        // Highest-rated worker sabse pehle
        workers.sort((a, b) {
          final ratingA = _toDouble(a.data()['rating']);
          final ratingB = _toDouble(b.data()['rating']);

          return ratingB.compareTo(ratingA);
        });

        if (_searchQuery.isNotEmpty) {
          workers = workers.where((doc) {
            final data = doc.data();

            final name = data['name']?.toString().toLowerCase() ?? '';

            final skill = data['skill']?.toString().toLowerCase() ?? '';

            return name.contains(_searchQuery) || skill.contains(_searchQuery);
          }).toList();
        }

        if (workers.isEmpty) {
          return _emptyWorkers();
        }

        // Home screen par sirf top 3 workers
        final topWorkers = workers.take(3).toList();

        return Column(
          children: topWorkers.map((doc) {
            return _workerCard(workerId: doc.id, worker: doc.data());
          }).toList(),
        );
      },
    );
  }

  Widget _workerCard({
    required String workerId,
    required Map<String, dynamic> worker,
  }) {
    final name = worker['name']?.toString().trim().isNotEmpty == true
        ? worker['name'].toString().trim()
        : 'Skilled Worker';

    final skill = worker['skill']?.toString().trim().isNotEmpty == true
        ? worker['skill'].toString().trim()
        : 'Professional Service';

    final city = worker['city']?.toString().trim().isNotEmpty == true
        ? worker['city'].toString().trim()
        : 'Nearby';

    final rating = _toDouble(worker['rating']);
    final hourlyRate = _formatRate(worker['hourlyRate']);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primary, _secondary],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      height: 19,
                      width: 19,
                      decoration: BoxDecoration(
                        color: _success,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surface, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 14.6,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          color: _primary,
                          size: 15,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skill,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: _textSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 9.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  hourlyRate,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where('workerId', isEqualTo: workerId)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snapshot) {
              final int completedJobs = snapshot.data?.docs.length ?? 0;

              return Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _workerMetric(
                        icon: Icons.star_rounded,
                        iconColor: _warning,
                        value: rating.toStringAsFixed(1),
                        label: 'Rating',
                      ),
                    ),
                    Container(width: 1, height: 28, color: _border),
                    Expanded(
                      child: _workerMetric(
                        icon: Icons.work_outline_rounded,
                        iconColor: _primary,
                        value: completedJobs.toString(),
                        label: 'Jobs',
                      ),
                    ),
                    Container(width: 1, height: 28, color: _border),
                    Expanded(
                      child: _workerMetric(
                        icon: Icons.schedule_rounded,
                        iconColor: _success,
                        value: 'Active',
                        label: 'Status',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WorkerPublicProfileScreen(workerId: workerId),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'View profile',
                    style: TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            Request(selectedWorkerId: workerId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor: Colors.white,
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Request service',
                    style: TextStyle(
                      fontSize: 10.8,
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

  Widget _workerMetric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 8.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _workerLoading() {
    return Column(
      children: List.generate(
        2,
        (_) => Container(
          height: 132,
          margin: const EdgeInsets.only(bottom: 13),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: _border),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            color: _primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  Widget _emptyWorkers() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.person_search_rounded, color: _primary, size: 40),
          SizedBox(height: 12),
          Text(
            'No professionals found',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Try another search or check again later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySearchResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: _textSecondary, size: 36),
          SizedBox(height: 10),
          Text(
            'No matching service found',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureMessage(String message) {
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

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'CU';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatRate(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) return 'Rate N/A';

    if (text.toLowerCase().contains('rs')) return text;

    return 'Rs. $text';
  }

  Widget _ambientCircle({required double size, required Color color}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class ServiceCategory {
  final String title;
  final IconData icon;
  final Color accent;

  const ServiceCategory({
    required this.title,
    required this.icon,
    required this.accent,
  });
}
