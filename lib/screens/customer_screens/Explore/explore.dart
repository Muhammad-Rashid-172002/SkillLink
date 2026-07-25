import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSort = 'Top Rated';
  bool _showOnlyAvailable = false;

  final List<ServiceCategory> _categories = const [
    ServiceCategory(
      title: 'All',
      icon: Icons.grid_view_rounded,
      accent: Color(0xFF2563EB),
    ),
    ServiceCategory(
      title: 'Electrician',
      icon: Icons.electrical_services_rounded,
      accent: Color(0xFFF59E0B),
    ),
    ServiceCategory(
      title: 'Plumber',
      icon: Icons.plumbing_rounded,
      accent: Color(0xFF06B6D4),
    ),
    ServiceCategory(
      title: 'Painter',
      icon: Icons.format_paint_rounded,
      accent: Color(0xFF8B5CF6),
    ),
    ServiceCategory(
      title: 'Carpenter',
      icon: Icons.carpenter_rounded,
      accent: Color(0xFFF97316),
    ),
    ServiceCategory(
      title: 'AC Repair',
      icon: Icons.ac_unit_rounded,
      accent: Color(0xFF0EA5E9),
    ),
    ServiceCategory(
      title: 'Cleaner',
      icon: Icons.cleaning_services_rounded,
      accent: Color(0xFF10B981),
    ),
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> get _workersStream {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('profileCompleted', isEqualTo: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const CustomerBottomBar(selectedIndex: 1),
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _ambientCircle(size: 330, color: _primary.withOpacity(0.09)),
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
            child: RefreshIndicator(
              color: _primary,
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 600));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 115),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _header(),
                        const SizedBox(height: 20),
                        _heroCard(),
                        const SizedBox(height: 20),
                        _searchAndFilter(),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          title: 'Browse services',
                          subtitle: 'Select a category to narrow results',
                        ),
                        const SizedBox(height: 14),
                        _categoryScroller(),
                        const SizedBox(height: 26),
                        _workerSectionHeader(),
                        const SizedBox(height: 14),
                        _realTimeWorkers(),
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

  Widget _header() {
    return Row(
      children: [
        Container(
          height: 50,
          width: 50,
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
          child: const Icon(
            Icons.explore_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore professionals',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Find trusted workers for every job',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: _openFilterSheet,
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x070F172A),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.tune_rounded, color: _primary, size: 21),
                  if (_showOnlyAvailable || _selectedSort != 'Top Rated')
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        height: 8,
                        width: 8,
                        decoration: const BoxDecoration(
                          color: _success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -55,
            child: Container(
              height: 170,
              width: 170,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -85,
            left: -45,
            child: Container(
              height: 165,
              width: 165,
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
                        'TRUSTED MARKETPLACE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Discover skilled\nworkers near you',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Compare ratings, services and availability before choosing a professional.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11.7,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 105,
                width: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  color: Colors.white,
                  size: 45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
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
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search worker, skill or city',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.8,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF94A3B8),
                  size: 21,
                ),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _textSecondary,
                          size: 19,
                        ),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openFilterSheet,
            child: Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.filter_alt_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 18.3,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _categoryScroller() {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = _selectedCategory == category.title;

          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedCategory = category.title;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 94,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? category.accent.withOpacity(0.10)
                      : _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? category.accent : _border,
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: category.accent.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        category.icon,
                        color: category.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      category.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? category.accent : _textPrimary,
                        fontSize: 10.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _workerSectionHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _sectionTitle(
            title: _selectedCategory == 'All'
                ? 'Top rated workers'
                : 'Top $_selectedCategory workers',
            subtitle: _selectedSort == 'Top Rated'
                ? 'Sorted by highest customer ratings'
                : 'Sorted by $_selectedSort',
          ),
        ),
        if (_selectedCategory != 'All' ||
            _showOnlyAvailable ||
            _selectedSort != 'Top Rated')
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = 'All';
                _selectedSort = 'Top Rated';
                _showOnlyAvailable = false;
              });
            },
            child: const Text(
              'Reset',
              style: TextStyle(
                color: _primary,
                fontSize: 10.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _realTimeWorkers() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _workersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingWorkers();
        }

        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to load professionals',
            message: 'Please check your internet connection and try again.',
            iconColor: const Color(0xFFDC2626),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        final workers = documents
            .where((document) => _matchesFilters(document.data()))
            .toList();

        _sortWorkers(workers);

        if (workers.isEmpty) {
          return _messageCard(
            icon: Icons.person_search_rounded,
            title: 'No professionals found',
            message: _selectedCategory == 'All'
                ? 'Try another search or adjust your filters.'
                : 'No $_selectedCategory professional matches your filters.',
            iconColor: _primary,
          );
        }

        return Column(
          children: workers.asMap().entries.map((entry) {
            return _workerCard(
              workerId: entry.value.id,
              worker: entry.value.data(),
              rank: entry.key + 1,
            );
          }).toList(),
        );
      },
    );
  }

  bool _matchesFilters(Map<String, dynamic> worker) {
    final name = _stringValue(worker['name']).toLowerCase();
    final skill = _stringValue(worker['skill']).toLowerCase();
    final city = _stringValue(worker['city']).toLowerCase();
    final available = _boolValue(
      worker['isAvailable'] ?? worker['available'],
      defaultValue: true,
    );

    final matchesSearch =
        _searchQuery.isEmpty ||
        name.contains(_searchQuery) ||
        skill.contains(_searchQuery) ||
        city.contains(_searchQuery);

    final matchesCategory =
        _selectedCategory == 'All' ||
        skill.contains(_selectedCategory.toLowerCase());

    final matchesAvailability = !_showOnlyAvailable || available;

    return matchesSearch && matchesCategory && matchesAvailability;
  }

  void _sortWorkers(List<QueryDocumentSnapshot<Map<String, dynamic>>> workers) {
    workers.sort((first, second) {
      final firstData = first.data();
      final secondData = second.data();

      switch (_selectedSort) {
        case 'Most Jobs':
          return _intValue(
            secondData['completedJobs'],
          ).compareTo(_intValue(firstData['completedJobs']));

        case 'Lowest Rate':
          return _numberValue(
            firstData['hourlyRate'],
          ).compareTo(_numberValue(secondData['hourlyRate']));

        case 'Top Rated':
        default:
          final ratingComparison = _doubleValue(
            secondData['rating'],
          ).compareTo(_doubleValue(firstData['rating']));

          if (ratingComparison != 0) {
            return ratingComparison;
          }

          return _intValue(
            secondData['completedJobs'],
          ).compareTo(_intValue(firstData['completedJobs']));
      }
    });
  }

  Widget _workerCard({
    required String workerId,
    required Map<String, dynamic> worker,
    required int rank,
  }) {
    final name = _fallbackValue(worker['name'], 'Skilled Professional');

    final skill = _fallbackValue(worker['skill'], 'Professional Service');

    final city = _fallbackValue(worker['city'], 'Nearby');

    final rating = _doubleValue(worker['rating']);
    final reviews = _intValue(worker['reviewsCount'] ?? worker['totalReviews']);
    final isAvailable = _boolValue(
      worker['isAvailable'] ?? worker['available'],
      defaultValue: true,
    );
    final verified = _boolValue(
      worker['isVerified'] ?? worker['verified'],
      defaultValue: false,
    );
    final rate = _formatRate(worker['hourlyRate']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
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
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 62,
                    width: 62,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primary, _secondary],
                      ),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(left: -5, top: -5, child: _rankBadge(rank)),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      height: 19,
                      width: 19,
                      decoration: BoxDecoration(
                        color: isAvailable ? _success : const Color(0xFF94A3B8),
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
                              fontSize: 14.8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            color: _primary,
                            size: 16,
                          ),
                        ],
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
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        _smallInfo(
                          icon: Icons.location_on_outlined,
                          text: city,
                        ),
                        _smallInfo(
                          icon: isAvailable
                              ? Icons.check_circle_outline_rounded
                              : Icons.schedule_rounded,
                          text: isAvailable ? 'Available' : 'Busy',
                          color: isAvailable ? _success : _textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
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
                  rate,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("requests")
                .where("workerId", isEqualTo: workerId)
                .where("status", isEqualTo: "completed")
                .snapshots(),
            builder: (context, snapshot) {
              final completedJobs = snapshot.data?.docs.length ?? 0;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _metric(
                        icon: Icons.star_rounded,
                        iconColor: _warning,
                        value: rating.toStringAsFixed(1),
                        label: reviews > 0 ? '$reviews reviews' : 'Rating',
                      ),
                    ),
                    _metricDivider(),
                    Expanded(
                      child: _metric(
                        icon: Icons.work_outline_rounded,
                        iconColor: _primary,
                        value: completedJobs.toString(),
                        label: 'Jobs done',
                      ),
                    ),
                    _metricDivider(),
                    Expanded(
                      child: _metric(
                        icon: Icons.workspace_premium_outlined,
                        iconColor: _success,
                        value: rank <= 3 ? 'Top $rank' : 'Trusted',
                        label: 'Ranking',
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
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WorkerPublicProfileScreen(workerId: workerId),
                      ),
                    );
                    _showMessage(
                      '$name profile navigation can be connected here.',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(0, 46),
                  ),
                  icon: const Icon(Icons.person_outline_rounded, size: 17),
                  label: const Text(
                    'View profile',
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
                  onPressed: isAvailable
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  Request(selectedWorkerId: workerId),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor: Colors.white,
                    backgroundColor: _primary,
                    disabledBackgroundColor: _textSecondary.withOpacity(0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(0, 46),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    isAvailable ? 'Send request' : 'Unavailable',
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

  Widget _rankBadge(int rank) {
    final color = rank == 1
        ? const Color(0xFFF59E0B)
        : rank == 2
        ? const Color(0xFF94A3B8)
        : rank == 3
        ? const Color(0xFFB45309)
        : _primary;

    return Container(
      height: 24,
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _smallInfo({
    required IconData icon,
    required String text,
    Color color = _textSecondary,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 9.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _metric({
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
                  fontSize: 10.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _metricDivider() {
    return Container(width: 1, height: 29, color: _border);
  }

  Widget _loadingWorkers() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 176,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _surface,
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

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10.8,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    String tempSort = _selectedSort;
    bool tempAvailability = _showOnlyAvailable;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 5,
                      width: 48,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Filter professionals',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Choose how workers should be displayed.',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Sort workers',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: ['Top Rated', 'Most Jobs', 'Lowest Rate'].map((
                      option,
                    ) {
                      final selected = tempSort == option;

                      return ChoiceChip(
                        selected: selected,
                        label: Text(option),
                        onSelected: (_) {
                          setSheetState(() => tempSort = option);
                        },
                        selectedColor: _primary.withOpacity(0.12),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: BorderSide(color: selected ? _primary : _border),
                        labelStyle: TextStyle(
                          color: selected ? _primary : _textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: tempAvailability,
                    activeColor: _primary,
                    title: const Text(
                      'Available workers only',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: const Text(
                      'Hide professionals who are currently busy.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: (value) {
                      setSheetState(() => tempAvailability = value);
                    },
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              tempSort = 'Top Rated';
                              tempAvailability = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textPrimary,
                            side: const BorderSide(color: _border),
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedSort = tempSort;
                              _showOnlyAvailable = tempAvailability;
                            });

                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            foregroundColor: Colors.white,
                            backgroundColor: _primary,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Apply filters',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

  String _fallbackValue(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _numberValue(dynamic value) {
    if (value is num) return value.toDouble();

    final cleaned = value?.toString().replaceAll(RegExp(r'[^0-9.]'), '');

    return double.tryParse(cleaned ?? '') ?? double.infinity;
  }

  int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _boolValue(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;

    final text = value?.toString().toLowerCase().trim();

    if (text == 'true' || text == '1' || text == 'yes') {
      return true;
    }

    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }

    return defaultValue;
  }

  String _formatRate(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) return 'Rate N/A';

    if (text.toLowerCase().contains('rs')) return text;

    return 'Rs. $text';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'WP';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
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
