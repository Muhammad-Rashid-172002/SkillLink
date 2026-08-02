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
  static const Color _background = Color(0xFFF5F8FF);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF1769E8);
  static const Color _primaryDark = Color(0xFF073B91);
  static const Color _secondary = Color(0xFF48A8FF);
  static const Color _textPrimary = Color(0xFF101827);
  static const Color _textSecondary = Color(0xFF687386);
  static const Color _border = Color(0xFFE6ECF5);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF4A100);

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
          .where('identityVerificationStatus', isEqualTo: 'approved')
          .where('canAcceptJobs', isEqualTo: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const CustomerBottomBar(selectedIndex: 0),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _blurCircle(size: 320, color: _secondary.withOpacity(.13)),
          ),
          Positioned(
            top: 300,
            left: -180,
            child: _blurCircle(size: 360, color: _primary.withOpacity(.08)),
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
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _topHeader(),
                        const SizedBox(height: 18),
                        _searchBar(),
                        const SizedBox(height: 18),
                        _heroBanner(),
                        const SizedBox(height: 22),
                        _trustStrip(),
                        const SizedBox(height: 26),
                        _sectionHeader(
                          title: 'Popular Services',
                          subtitle: 'What service do you need today?',
                          action: 'See all',
                          onActionTap: _openAllServices,
                        ),
                        const SizedBox(height: 14),
                        _categoriesGrid(),
                        const SizedBox(height: 28),
                        _sectionHeader(
                          title: 'Top Professionals Near You',
                          subtitle: 'Verified experts with great ratings',
                          action: 'View all',
                          onActionTap: _openAllWorkers,
                        ),
                        const SizedBox(height: 14),
                        _workersList(),
                        const SizedBox(height: 10),
                        _safetyCard(),
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

  Future<void> _openAllServices() async {
    final selectedService = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AllServicesScreen()),
    );

    if (selectedService == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Request(selectedService: selectedService),
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
            : 'Your location';

        return Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(.20),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showFeatureMessage(
                      'Location selector can be connected here.',
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: _primary,
                        ),
                      ],
                    ),
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
            borderRadius: BorderRadius.circular(16),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A0F172A),
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
                        minWidth: 19,
                        minHeight: 19,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _background, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
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
            color: Color(0x090F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'What service do you need?',
          hintStyle: const TextStyle(
            color: Color(0xFF9AA5B5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _primary,
            size: 23,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _secondary]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Filters',
              onPressed: () => _showFeatureMessage(
                'Advanced filters can be connected here.',
              ),
              icon: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _heroBanner() {
    return Container(
      height: 220,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F7CF6), Color(0xFF145BD7), Color(0xFF0A3E9F)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -45,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -105,
            left: -65,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 17,
            bottom: 10,
            right: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(.15)),
                  ),
                  child: const Text(
                    'RELIABLE • FAST • VERIFIED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .45,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Reliable Services,\nRight at Your\nDoorstep',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.55,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => Request()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: _primary,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Book Now',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 7),
                        Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: -7,
            bottom: -8,
            width: 155,
            height: 195,
            child: Image.asset(
              'assets/skillNove_customer.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              errorBuilder: (_, __, ___) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 126,
                    height: 155,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.12),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(.17)),
                    ),
                    child: const Icon(
                      Icons.home_repair_service_rounded,
                      color: Colors.white,
                      size: 70,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _trustItem(
            icon: Icons.verified_user_rounded,
            title: 'Verified',
            subtitle: 'Professionals',
          ),
          _divider(),
          _trustItem(
            icon: Icons.bolt_rounded,
            title: 'Quick',
            subtitle: 'Response',
          ),
          _divider(),
          _trustItem(
            icon: Icons.workspace_premium_rounded,
            title: 'Quality',
            subtitle: 'Service',
          ),
          _divider(),
          _trustItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Affordable',
            subtitle: 'Prices',
          ),
        ],
      ),
    );
  }

  Widget _trustItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primary.withOpacity(.14),
                  _secondary.withOpacity(.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primary, size: 19),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 1,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 7.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 46, color: _border);
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
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.3,
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
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
          child: Row(
            children: [
              Text(
                action,
                style: const TextStyle(
                  fontSize: 10.5,
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

    if (filtered.isEmpty) return _emptySearchResult();

    final visible = filtered.take(8).toList();

    return GridView.builder(
      itemCount: visible.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: .72,
      ),
      itemBuilder: (context, index) {
        final category = visible[index];
        final originalIndex = _categories.indexOf(category);
        final selected = _selectedCategory == originalIndex;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
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
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? category.color.withOpacity(.09) : _surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? category.color : _border,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 13,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(category.icon, color: category.color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(height: 9),
                  Flexible(
                    child: Text(
                      category.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 9,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
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

        if (workers.isEmpty) return _emptyWorkers();

        return Column(
          children: workers
              .take(3)
              .map((doc) => _workerCard(workerId: doc.id, worker: doc.data()))
              .toList(),
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

    final photoUrl =
        worker['profileImage']?.toString().trim() ??
        worker['profileImageUrl']?.toString().trim() ??
        '';

    final rating = _toDouble(worker['rating']);
    final experience = worker['experience']?.toString().trim();
    final distance = worker['distance']?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 17,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _secondary],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _workerInitial(name),
                      )
                    : _workerInitial(name),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _success,
                    shape: BoxShape.circle,
                    border: Border.all(color: _surface, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: _warning, size: 15),
                    const SizedBox(width: 3),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: _textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        [
                          city,
                          if (experience != null && experience.isNotEmpty)
                            '$experience exp.',
                          if (distance != null && distance.isNotEmpty) distance,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              SizedBox(
                height: 37,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Request(selectedWorkerId: workerId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      fontSize: 9.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WorkerPublicProfileScreen(workerId: workerId),
                    ),
                  );
                },
                child: const Text(
                  'View profile',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workerInitial(String name) {
    return Container(
      alignment: Alignment.center,
      color: _primary,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _safetyCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF3FF), Color(0xFFF7FBFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6E7FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _secondary]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(.18),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Safety is Our Priority',
                  style: TextStyle(
                    color: _primaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'We connect you with identity-verified professionals.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.3,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: _primary,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _workerLoading() {
    return Column(
      children: List.generate(
        2,
        (_) => Container(
          height: 88,
          margin: const EdgeInsets.only(bottom: 13),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            color: _primary,
            strokeWidth: 2.4,
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.person_search_rounded, color: _primary, size: 39),
          SizedBox(height: 10),
          Text(
            'No professionals found',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try another search or check again later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10.5,
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
          SizedBox(height: 9),
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
      padding: const EdgeInsets.all(18),
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

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _blurCircle({required double size, required Color color}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
