import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';

/// Aggregate figures for a worker's reviews. Computed only from real reviews.
@immutable
class ReviewStats {
  const ReviewStats({
    required this.average,
    required this.total,
    required this.starCounts,
  });

  factory ReviewStats.from(Iterable<Map<String, dynamic>> reviews) {
    final counts = {for (var star = 1; star <= 5; star++) star: 0};
    var sum = 0.0;
    var total = 0;
    for (final review in reviews) {
      final rating = reviewRating(review);
      if (rating <= 0) continue;
      sum += rating;
      total++;
      final star = rating.round().clamp(1, 5);
      counts[star] = counts[star]! + 1;
    }
    return ReviewStats(
      average: total == 0 ? 0 : sum / total,
      total: total,
      starCounts: counts,
    );
  }

  final double average;
  final int total;
  final Map<int, int> starCounts;

  /// Share of reviews rated 4 or 5 stars.
  int get positivePercent => total == 0
      ? 0
      : (((starCounts[4]! + starCounts[5]!) / total) * 100).round();
}

double reviewRating(Map<String, dynamic> data) {
  final value = data['rating'];
  final rating = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  return rating.clamp(0, 5).toDouble();
}

DateTime? _reviewDate(Map<String, dynamic> data) {
  for (final key in const ['createdAt', 'updatedAt']) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
  }
  return null;
}

/// A worker's reviews and rating breakdown.
class ReviewsRatingsScreen extends StatefulWidget {
  const ReviewsRatingsScreen({super.key});

  @override
  State<ReviewsRatingsScreen> createState() => _ReviewsRatingsScreenState();
}

class _ReviewsRatingsScreenState extends State<ReviewsRatingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _customerNames = {};
  final Set<String> _requestedNames = {};
  int? _starFilter;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _query();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _query() => _firestore
      .collection('reviews')
      .where('workerId', isEqualTo: _uid)
      .snapshots();

  /// Reviews store the customer's id; show their first name instead of a
  /// generic "Customer". Loaded in small batches and cached.
  void _loadNames(Iterable<Map<String, dynamic>> reviews) {
    final missing = reviews
        .map((review) => review['customerId']?.toString() ?? '')
        .where((id) => id.isNotEmpty && _requestedNames.add(id))
        .toList();
    for (var i = 0; i < missing.length; i += 10) {
      final chunk = missing.sublist(i, (i + 10).clamp(0, missing.length));
      _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get()
          .then((snapshot) {
            if (!mounted) return;
            setState(() {
              for (final doc in snapshot.docs) {
                final name = doc.data()['name']?.toString().trim() ?? '';
                if (name.isNotEmpty) {
                  _customerNames[doc.id] = name.split(RegExp(r'\s+')).first;
                }
              }
            });
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews & ratings')),
      body: _uid.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Sign in to see your reviews',
                message: 'Your reviews appear once you’re signed in.',
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(SkillNovaSpacing.xl),
                      child: ErrorState(
                        title: 'Reviews unavailable',
                        message:
                            'We couldn’t load your reviews right now. Check '
                            'your connection and try again.',
                        actionLabel: 'Try again',
                        onAction: () => setState(() => _stream = _query()),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) return const _ReviewsSkeleton();
                final reviews =
                    snapshot.data!.docs.map((doc) => doc.data()).toList()..sort(
                      (a, b) => (_reviewDate(b) ?? DateTime(0)).compareTo(
                        _reviewDate(a) ?? DateTime(0),
                      ),
                    );
                _loadNames(reviews);
                return _content(reviews);
              },
            ),
    );
  }

  Widget _content(List<Map<String, dynamic>> reviews) {
    final stats = ReviewStats.from(reviews);
    if (stats.total == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(SkillNovaSpacing.xl),
          child: EmptyState(
            icon: Icons.star_outline_rounded,
            title: 'No reviews yet',
            message:
                'Customers can rate you after a job is completed. Great '
                'reviews help you win more leads.',
          ),
        ),
      );
    }
    final visible = _starFilter == null
        ? reviews
        : reviews
              .where(
                (review) =>
                    reviewRating(review).round().clamp(1, 5) == _starFilter,
              )
              .toList();
    return RefreshIndicator(
      onRefresh: () async => setState(() => _stream = _query()),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          SkillNovaSpacing.gutter,
          SkillNovaSpacing.xs,
          SkillNovaSpacing.gutter,
          SkillNovaSpacing.xxxl,
        ),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summary(stats),
                const SizedBox(height: SkillNovaSpacing.xl),
                _filters(stats),
                const SizedBox(height: SkillNovaSpacing.md),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No $_starFilter-star reviews',
                    message: 'Try another rating.',
                    actionLabel: 'Show all',
                    onAction: () => setState(() => _starFilter = null),
                  )
                else
                  for (final review in visible) ...[
                    _ReviewCard(
                      data: review,
                      customerName:
                          _customerNames[review['customerId']?.toString()],
                    ),
                    const SizedBox(height: SkillNovaSpacing.sm),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(ReviewStats stats) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return SkillNovaCard(
      padding: const EdgeInsets.all(SkillNovaSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label:
                'Average ${stats.average.toStringAsFixed(1)} out of 5 from '
                '${stats.total} reviews',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.average.toStringAsFixed(1),
                  style: text.displaySmall,
                ),
                _Stars(rating: stats.average, size: 16),
                const SizedBox(height: SkillNovaSpacing.xxs),
                Text(
                  '${stats.total} review${stats.total == 1 ? '' : 's'}',
                  style: text.bodySmall,
                ),
                Text(
                  '${stats.positivePercent}% positive',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.lg),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text('$star', style: text.labelMedium),
                        ),
                        const SizedBox(width: SkillNovaSpacing.xs),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: stats.starCounts[star]! / stats.total,
                              minHeight: 6,
                              color: SkillNovaColors.rating,
                              backgroundColor: colors.surfaceContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: SkillNovaSpacing.xs),
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${stats.starCounts[star]}',
                            textAlign: TextAlign.end,
                            style: text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(ReviewStats stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All (${stats.total})'),
            selected: _starFilter == null,
            onSelected: (_) => setState(() => _starFilter = null),
          ),
          for (var star = 5; star >= 1; star--)
            if (stats.starCounts[star]! > 0) ...[
              const SizedBox(width: SkillNovaSpacing.xs),
              ChoiceChip(
                avatar: const Icon(Icons.star_rounded, size: 16),
                label: Text('$star (${stats.starCounts[star]})'),
                selected: _starFilter == star,
                onSelected: (_) => setState(() => _starFilter = star),
              ),
            ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 14});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            rating >= star
                ? Icons.star_rounded
                : rating >= star - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: SkillNovaColors.rating,
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.data, this.customerName});
  final Map<String, dynamic> data;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final name =
        customerName ??
        (data['customerName'] ?? data['reviewerName'])?.toString().trim() ??
        'Customer';
    final body = (data['review'] ?? data['comment'])?.toString().trim() ?? '';
    final service =
        (data['jobTitle'] ?? data['serviceTitle'] ?? data['category'])
            ?.toString()
            .trim() ??
        '';
    final rating = reviewRating(data);
    final date = _reviewDate(data);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateLabel = date == null
        ? ''
        : '${date.day} ${months[date.month - 1]} ${date.year}';
    return SkillNovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: text.titleSmall?.copyWith(color: colors.primary),
                ),
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.titleSmall),
                    if (dateLabel.isNotEmpty)
                      Text(dateLabel, style: text.bodySmall),
                  ],
                ),
              ),
              Semantics(
                label: '${rating.toStringAsFixed(0)} stars',
                excludeSemantics: true,
                child: _Stars(rating: rating),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            Text(body, style: text.bodyLarge),
          ],
          if (service.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            StatusBadge(label: service, icon: Icons.handyman_outlined),
          ],
        ],
      ),
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading reviews',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SkillNovaSpacing.gutter),
        children: const [
          SkeletonCard(height: 150),
          SizedBox(height: SkillNovaSpacing.xl),
          SkeletonCard(height: 110),
          SizedBox(height: SkillNovaSpacing.sm),
          SkeletonCard(height: 110),
        ],
      ),
    );
  }
}
