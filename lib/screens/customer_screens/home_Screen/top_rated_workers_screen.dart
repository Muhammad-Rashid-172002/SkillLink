import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';

class TopRatedWorkersScreen extends StatefulWidget {
  const TopRatedWorkersScreen({super.key});

  @override
  State<TopRatedWorkersScreen> createState() => _TopRatedWorkersScreenState();
}

class _TopRatedWorkersScreenState extends State<TopRatedWorkersScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;

  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);

  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _workersStream {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('profileCompleted', isEqualTo: true)
        .where('identityVerificationStatus', isEqualTo: 'approved')
        .where('canAcceptJobs', isEqualTo: true)
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
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: _ambientCircle(size: 300, color: _primary.withOpacity(.10)),
          ),
          Positioned(
            bottom: -150,
            left: -120,
            child: _ambientCircle(
              size: 340,
              color: _secondary.withOpacity(.07),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _workersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState();
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState();
                      }

                      var workers = [...?snapshot.data?.docs];

                      workers.sort((a, b) {
                        final ratingA = _toDouble(a.data()['rating']);
                        final ratingB = _toDouble(b.data()['rating']);

                        final ratingCompare = ratingB.compareTo(ratingA);

                        if (ratingCompare != 0) {
                          return ratingCompare;
                        }

                        final reviewsA = _toInt(a.data()['totalReviews']);
                        final reviewsB = _toInt(b.data()['totalReviews']);

                        return reviewsB.compareTo(reviewsA);
                      });

                      if (_searchQuery.isNotEmpty) {
                        workers = workers.where((document) {
                          final worker = document.data();

                          final name =
                              worker['name']?.toString().toLowerCase() ?? '';

                          final skill =
                              worker['skill']?.toString().toLowerCase() ?? '';

                          final city =
                              worker['city']?.toString().toLowerCase() ?? '';

                          return name.contains(_searchQuery) ||
                              skill.contains(_searchQuery) ||
                              city.contains(_searchQuery);
                        }).toList();
                      }

                      if (workers.isEmpty) {
                        return _buildEmptyState();
                      }

                      return _buildWorkersList(workers);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => Navigator.pop(context),
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
                      size: 21,
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
                      'Top Rated Workers',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Find trusted professionals for your work',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
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
                  gradient: const LinearGradient(
                    colors: [_primary, _secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(.22),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSearchField(),
          const SizedBox(height: 14),
          _buildHeaderBanner(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 57,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        },
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search worker, skill or city...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _textSecondary,
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: _primary,
                    size: 18,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withOpacity(.09), _secondary.withOpacity(.07)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withOpacity(.10)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: _warning.withOpacity(.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.star_rounded, color: _warning, size: 22),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sorted by highest rating',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Workers with better ratings and reviews appear first.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 9.7,
                    height: 1.4,
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

  Widget _buildWorkersList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workers,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final document = workers[index];

        return _workerCard(
          workerId: document.id,
          worker: document.data(),
          rank: index + 1,
        );
      },
    );
  }

  Widget _workerCard({
    required String workerId,
    required Map<String, dynamic> worker,
    required int rank,
  }) {
    final name = _value(worker['name'], 'SkillNova Worker');

    final skill = _value(worker['skill'], 'Professional Service');

    final city = _value(worker['city'], 'Nearby');

    final rating = _toDouble(worker['rating']);
    final totalReviews = _toInt(worker['totalReviews']);
    final hourlyRate = _formatRate(worker['hourlyRate']);
    final bool isVerified =
        worker['identityVerificationStatus'] == 'approved' &&
        worker['canAcceptJobs'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_primary, _secondary]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_primary, _secondary],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withOpacity(.20),
                                  blurRadius: 16,
                                  offset: const Offset(0, 7),
                                ),
                              ],
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
                          Positioned(
                            bottom: -4,
                            right: -4,
                            child: Container(
                              height: 21,
                              width: 21,
                              decoration: BoxDecoration(
                                color: _success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -7,
                            left: -7,
                            child: Container(
                              height: 25,
                              width: 25,
                              decoration: BoxDecoration(
                                color: rank <= 3 ? _warning : _textPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$rank',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: _primary,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: _textSecondary,
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
                          color: _primary.withOpacity(.08),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          hourlyRate,
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 10.3,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('requests')
                        .where('workerId', isEqualTo: workerId)
                        .where('status', isEqualTo: 'completed')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final completedJobs = snapshot.data?.docs.length ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _metric(
                                icon: Icons.star_rounded,
                                iconColor: _warning,
                                value: rating.toStringAsFixed(1),
                                label: 'Rating',
                              ),
                            ),
                            Container(height: 32, width: 1, color: _border),
                            Expanded(
                              child: _metric(
                                icon: Icons.rate_review_outlined,
                                iconColor: _secondary,
                                value: '$totalReviews',
                                label: 'Reviews',
                              ),
                            ),
                            Container(height: 32, width: 1, color: _border),
                            Expanded(
                              child: _metric(
                                icon: Icons.work_outline_rounded,
                                iconColor: _success,
                                value: '$completedJobs',
                                label: 'Jobs',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                                builder: (_) => WorkerPublicProfileScreen(
                                  workerId: workerId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 17,
                          ),
                          label: const Text('View Profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textPrimary,
                            minimumSize: const Size.fromHeight(47),
                            side: const BorderSide(color: _border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 10.7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    Request(selectedWorkerId: workerId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Request Service'),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            foregroundColor: Colors.white,
                            backgroundColor: _primary,
                            minimumSize: const Size.fromHeight(47),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
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
            ),
          ],
        ),
      ),
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
            Icon(icon, color: iconColor, size: 15),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 10.7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 8.7,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: _border),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            color: _primary,
            strokeWidth: 2.5,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_rounded, color: _primary, size: 48),
              SizedBox(height: 16),
              Text(
                'No workers found',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Try searching with another name, skill or city.',
                textAlign: TextAlign.center,
                style: TextStyle(
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 44,
              ),
              SizedBox(height: 14),
              Text(
                'Unable to load workers',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 10.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _value(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }

    return text;
  }

  String _formatRate(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return 'Rate N/A';
    }

    if (text.toLowerCase().contains('rs')) {
      return text;
    }

    return 'Rs. $text';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'SW';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
