import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReviewsRatingsScreen extends StatefulWidget {
  const ReviewsRatingsScreen({super.key});

  @override
  State<ReviewsRatingsScreen> createState() => _ReviewsRatingsScreenState();
}

class _ReviewsRatingsScreenState extends State<ReviewsRatingsScreen> {
  static const Color _primary = Color(0xFFF59E0B);
  static const Color _primaryDark = Color(0xFFD97706);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);

  final String uid = FirebaseAuth.instance.currentUser!.uid;

  String selectedFilter = 'All';

  final List<String> filters = const [
    'All',
    '5 Stars',
    '4 Stars',
    '3 Stars',
    '2 Stars',
    '1 Star',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        foregroundColor: _textPrimary,
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
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 21,
              ),
            ),
          ),
        ),
        title: const Text(
          'Reviews & Ratings',
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
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('reviews')
              .where('workerId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _loadingState();
            }

            if (snapshot.hasError) {
              return _errorState(snapshot.error.toString());
            }

            final reviews = snapshot.data?.docs ?? [];

            reviews.sort((a, b) {
              final aDate = _extractDate(a.data());
              final bDate = _extractDate(b.data());
              return bDate.compareTo(aDate);
            });

            final stats = _calculateStats(reviews);
            final filteredReviews = _filterReviews(reviews);

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
                        _ratingSummaryCard(stats),
                        const SizedBox(height: 22),
                        _ratingBreakdown(stats),
                        const SizedBox(height: 22),
                        _filterChips(),
                        const SizedBox(height: 24),
                        _sectionHeader(filteredReviews.length),
                        const SizedBox(height: 14),
                        if (filteredReviews.isEmpty)
                          _emptyState()
                        else
                          ...filteredReviews.map(
                            (doc) => _reviewCard(doc.data()),
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

  Widget _ratingSummaryCard(_ReviewStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(21, 22, 21, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, Color(0xFFFBBF24)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30F59E0B),
            blurRadius: 28,
            offset: Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -48,
            top: -60,
            child: Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -72,
            child: Container(
              height: 125,
              width: 125,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
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
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'CUSTOMER RATING',
                      style: TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.05,
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
                          'Live',
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stats.average.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 7, bottom: 5),
                    child: Text(
                      '/ 5.0',
                      style: TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${stats.totalReviews}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stats.totalReviews == 1 ? 'Review' : 'Reviews',
                          style: const TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(
                      index < stats.average.round()
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 17),
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
                      Icons.thumb_up_alt_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'Customer satisfaction',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${stats.satisfactionPercent.toStringAsFixed(0)}%',
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

  Widget _ratingBreakdown(_ReviewStats stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rating breakdown',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (index) {
            final star = 5 - index;
            final count = stats.starCounts[star] ?? 0;
            final ratio = stats.totalReviews == 0
                ? 0.0
                : count / stats.totalReviews;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == 4 ? 0 : 11,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$star',
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.star_rounded,
                    color: _primary,
                    size: 17,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  SizedBox(
                    width: 26,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 39,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter == selectedFilter;

          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            onSelected: (_) {
              setState(() {
                selectedFilter = filter;
              });
            },
            label: Text(filter),
            backgroundColor: _surface,
            selectedColor: _primary,
            side: BorderSide(
              color: selected ? _primary : _border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          );
        },
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
                'Customer reviews',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'See who reviewed you and what they said',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12.5,
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
            color: const Color(0xFFFFF7E8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
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

  Widget _reviewCard(Map<String, dynamic> data) {
    final customerName =
        (data['customerName'] ?? data['reviewerName'] ?? 'Customer')
            .toString();

    final customerImage =
        (data['customerImage'] ??
                data['customerImageUrl'] ??
                data['reviewerImage'] ??
                '')
            .toString();

    final reviewText =
        (data['review'] ?? data['comment'] ?? 'No written review')
            .toString();

    final jobTitle =
        (data['jobTitle'] ?? data['serviceTitle'] ?? 'SkillNova service')
            .toString();

    final rating = _toDouble(data['rating']).clamp(0, 5);
    final createdAt = _extractDate(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 7),
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
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(17),
                ),
                clipBehavior: Clip.antiAlias,
                child: customerImage.isNotEmpty
                    ? Image.network(
                        customerImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _customerPlaceholder(customerName),
                      )
                    : _customerPlaceholder(customerName),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.work_outline_rounded,
                          color: _textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            jobTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11.5,
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
                  horizontal: 9,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: _primary,
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _primaryDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(
                  index < rating.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: _primary,
                  size: 19,
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            reviewText,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          const Divider(
            height: 1,
            color: _border,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF16A34A),
                size: 15,
              ),
              const SizedBox(width: 6),
              const Text(
                'Verified customer review',
                style: TextStyle(
                  color: Color(0xFF16A34A),
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.calendar_month_outlined,
                color: _textSecondary,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerPlaceholder(String name) {
    final initial = name.trim().isEmpty
        ? 'C'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      color: const Color(0xFFFFF7E8),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: _primaryDark,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterReviews(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews,
  ) {
    if (selectedFilter == 'All') return reviews;

    final selectedRating =
        int.tryParse(selectedFilter.split(' ').first) ?? 0;

    return reviews.where((doc) {
      final rating = _toDouble(doc.data()['rating']).round();
      return rating == selectedRating;
    }).toList();
  }

  _ReviewStats _calculateStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews,
  ) {
    if (reviews.isEmpty) {
      return const _ReviewStats(
        average: 0,
        totalReviews: 0,
        satisfactionPercent: 0,
        starCounts: {
          1: 0,
          2: 0,
          3: 0,
          4: 0,
          5: 0,
        },
      );
    }

    double totalRating = 0;
    int positiveReviews = 0;
    final Map<int, int> starCounts = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
    };

    for (final doc in reviews) {
      final rating = _toDouble(doc.data()['rating']).clamp(0, 5);
      totalRating += rating;

      final roundedRating = rating.round().clamp(1, 5);
      starCounts[roundedRating] =
          (starCounts[roundedRating] ?? 0) + 1;

      if (rating >= 4) {
        positiveReviews++;
      }
    }

    final average = totalRating / reviews.length;
    final satisfaction =
        (positiveReviews / reviews.length) * 100;

    return _ReviewStats(
      average: average,
      totalReviews: reviews.length,
      satisfactionPercent: satisfaction,
      starCounts: starCounts,
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
            backgroundColor: Color(0xFFFFF7E8),
            child: Icon(
              Icons.rate_review_outlined,
              color: _primary,
              size: 32,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No reviews found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Customer reviews will appear here after they rate your completed jobs.',
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
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 220,
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
        const SizedBox(height: 20),
        ...List.generate(
          3,
          (_) => Container(
            height: 180,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
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
                'Unable to load reviews',
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

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static DateTime _extractDate(Map<String, dynamic> data) {
    final possibleValues = [
      data['createdAt'],
      data['updatedAt'],
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
}

class _ReviewStats {
  final double average;
  final int totalReviews;
  final double satisfactionPercent;
  final Map<int, int> starCounts;

  const _ReviewStats({
    required this.average,
    required this.totalReviews,
    required this.satisfactionPercent,
    required this.starCounts,
  });
}
