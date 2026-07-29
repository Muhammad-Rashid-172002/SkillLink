import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/review_management_service.dart';

enum ReviewFilter {
  all,
  positive,
  neutral,
  negative,
  flagged,
  hidden,
}

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final ReviewManagementService _service = ReviewManagementService();
  final TextEditingController _searchController = TextEditingController();

  ReviewFilter _selectedFilter = ReviewFilter.all;
  String _searchQuery = '';
  bool _gridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagedReview> _applyFilters(List<ManagedReview> reviews) {
    final query = _searchQuery.trim().toLowerCase();

    return reviews.where((review) {
      final matchesSearch = query.isEmpty ||
          review.customerName.toLowerCase().contains(query) ||
          review.workerName.toLowerCase().contains(query) ||
          review.comment.toLowerCase().contains(query) ||
          review.jobTitle.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        ReviewFilter.all => true,
        ReviewFilter.positive => review.rating >= 4,
        ReviewFilter.neutral => review.rating >= 3 && review.rating < 4,
        ReviewFilter.negative => review.rating < 3,
        ReviewFilter.flagged => review.isFlagged,
        ReviewFilter.hidden => review.isHidden,
      };

      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  Future<void> _toggleHidden(ManagedReview review) async {
    try {
      await _service.setReviewHidden(
        reviewId: review.id,
        isHidden: !review.isHidden,
      );

      if (!mounted) return;

      _showMessage(
        review.isHidden
            ? 'Review visible kar diya gaya.'
            : 'Review hide kar diya gaya.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Review visibility update nahi ho saki: $error',
        isError: true,
      );
    }
  }

  Future<void> _toggleFlagged(ManagedReview review) async {
    try {
      await _service.setReviewFlagged(
        reviewId: review.id,
        isFlagged: !review.isFlagged,
      );

      if (!mounted) return;

      _showMessage(
        review.isFlagged
            ? 'Review se flag remove ho gaya.'
            : 'Review flag kar diya gaya.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Review flag update nahi ho saka: $error',
        isError: true,
      );
    }
  }

  Future<void> _deleteReview(ManagedReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete review?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Ye review Firestore se permanently delete ho jayega. Is action ko undo nahi kiya ja sakta.',
            style: GoogleFonts.inter(
              height: 1.5,
              color: const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete review'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteReview(review.id);

      if (!mounted) return;
      _showMessage('Review delete ho gaya.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Review delete nahi ho saka: $error',
        isError: true,
      );
    }
  }

  void _showReviewDetails(ManagedReview review) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 58,
                          width: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7D6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFEAB308),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.jobTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _RatingStars(rating: review.rating),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        review.comment,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.7,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _InfoTile(
                          label: 'Customer',
                          value: review.customerName,
                          icon: Icons.person_outline_rounded,
                        ),
                        _InfoTile(
                          label: 'Worker',
                          value: review.workerName,
                          icon: Icons.engineering_outlined,
                        ),
                        _InfoTile(
                          label: 'Submitted',
                          value: _formatDateTime(review.createdAt),
                          icon: Icons.calendar_today_outlined,
                        ),
                        _InfoTile(
                          label: 'Status',
                          value: review.isHidden ? 'Hidden' : 'Visible',
                          icon: review.isHidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _toggleFlagged(review);
                            },
                            icon: Icon(
                              review.isFlagged
                                  ? Icons.flag_outlined
                                  : Icons.outlined_flag_rounded,
                            ),
                            label: Text(
                              review.isFlagged
                                  ? 'Remove flag'
                                  : 'Flag review',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD97706),
                              side: const BorderSide(
                                color: Color(0xFFD97706),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _toggleHidden(review);
                            },
                            icon: Icon(
                              review.isHidden
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                            label: Text(
                              review.isHidden
                                  ? 'Make visible'
                                  : 'Hide review',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.reviewsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ReviewsErrorState(
            message: 'Reviews load nahi ho sake.\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF16A34A),
            ),
          );
        }

        final allReviews = snapshot.data!.docs
            .map(ManagedReview.fromDocument)
            .toList();

        final filteredReviews = _applyFilters(allReviews);

        final averageRating = allReviews.isEmpty
            ? 0.0
            : allReviews
                    .map((review) => review.rating)
                    .fold<double>(0, (sum, value) => sum + value) /
                allReviews.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewsHeader(
                total: allReviews.length,
                averageRating: averageRating,
                positive:
                    allReviews.where((review) => review.rating >= 4).length,
                negative:
                    allReviews.where((review) => review.rating < 3).length,
                flagged:
                    allReviews.where((review) => review.isFlagged).length,
              ),
              const SizedBox(height: 22),
              _ReviewsToolbar(
                controller: _searchController,
                selectedFilter: _selectedFilter,
                resultCount: filteredReviews.length,
                gridView: _gridView,
                onSearchChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                onFilterChanged: (filter) {
                  setState(() => _selectedFilter = filter);
                },
                onViewChanged: (value) {
                  setState(() => _gridView = value);
                },
              ),
              const SizedBox(height: 18),
              if (filteredReviews.isEmpty)
                const _EmptyReviewsState()
              else if (_gridView)
                _ReviewsGrid(
                  reviews: filteredReviews,
                  onView: _showReviewDetails,
                  onToggleHidden: _toggleHidden,
                  onToggleFlagged: _toggleFlagged,
                  onDelete: _deleteReview,
                )
              else
                _ReviewsTable(
                  reviews: filteredReviews,
                  onView: _showReviewDetails,
                  onToggleHidden: _toggleHidden,
                  onToggleFlagged: _toggleFlagged,
                  onDelete: _deleteReview,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader({
    required this.total,
    required this.averageRating,
    required this.positive,
    required this.negative,
    required this.flagged,
  });

  final int total;
  final double averageRating;
  final int positive;
  final int negative;
  final int flagged;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ReviewStatCard(
        title: 'Total Reviews',
        value: '$total',
        icon: Icons.reviews_rounded,
        color: const Color(0xFF2563EB),
      ),
      _ReviewStatCard(
        title: 'Average Rating',
        value: averageRating.toStringAsFixed(1),
        icon: Icons.star_rounded,
        color: const Color(0xFFEAB308),
      ),
      _ReviewStatCard(
        title: 'Positive',
        value: '$positive',
        icon: Icons.thumb_up_alt_rounded,
        color: const Color(0xFF16A34A),
      ),
      _ReviewStatCard(
        title: 'Negative',
        value: '$negative',
        icon: Icons.thumb_down_alt_rounded,
        color: const Color(0xFFDC2626),
      ),
      _ReviewStatCard(
        title: 'Flagged',
        value: '$flagged',
        icon: Icons.flag_rounded,
        color: const Color(0xFFD97706),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews Management',
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Monitor customer feedback and manage inappropriate reviews.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1180
                ? 5
                : constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 520
                        ? 2
                        : 1;

            final width =
                (constraints.maxWidth - ((columns - 1) * 14)) / columns;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ReviewStatCard extends StatelessWidget {
  const _ReviewStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewsToolbar extends StatelessWidget {
  const _ReviewsToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.gridView,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final ReviewFilter selectedFilter;
  final int resultCount;
  final bool gridView;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ReviewFilter> onFilterChanged;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          final search = SizedBox(
            width: compact ? double.infinity : 340,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search customer, worker, job or review...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF16A34A),
                    width: 1.6,
                  ),
                ),
              ),
            ),
          );

          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReviewFilter.values.map((filter) {
              final selected = selectedFilter == filter;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onFilterChanged(filter),
                label: Text(_reviewFilterLabel(filter)),
                selectedColor:
                    const Color(0xFF16A34A).withOpacity(0.12),
                backgroundColor: const Color(0xFFF8FAFC),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFE2E8F0),
                ),
                labelStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF64748B),
                ),
              );
            }).toList(),
          );

          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$resultCount reviews',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              _ViewButton(
                icon: Icons.table_rows_rounded,
                selected: !gridView,
                onTap: () => onViewChanged(false),
              ),
              const SizedBox(width: 6),
              _ViewButton(
                icon: Icons.grid_view_rounded,
                selected: gridView,
                onTap: () => onViewChanged(true),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 14),
                filters,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: controls,
                ),
              ],
            );
          }

          return Row(
            children: [
              search,
              const SizedBox(width: 16),
              Expanded(child: filters),
              const SizedBox(width: 10),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF16A34A)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _ReviewsTable extends StatelessWidget {
  const _ReviewsTable({
    required this.reviews,
    required this.onView,
    required this.onToggleHidden,
    required this.onToggleFlagged,
    required this.onDelete,
  });

  final List<ManagedReview> reviews;
  final ValueChanged<ManagedReview> onView;
  final ValueChanged<ManagedReview> onToggleHidden;
  final ValueChanged<ManagedReview> onToggleFlagged;
  final ValueChanged<ManagedReview> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFFF8FAFC),
          ),
          dataRowMinHeight: 78,
          dataRowMaxHeight: 92,
          horizontalMargin: 20,
          columnSpacing: 28,
          columns: const [
            DataColumn(label: _TableHeading('REVIEW')),
            DataColumn(label: _TableHeading('CUSTOMER')),
            DataColumn(label: _TableHeading('WORKER')),
            DataColumn(label: _TableHeading('RATING')),
            DataColumn(label: _TableHeading('STATUS')),
            DataColumn(label: _TableHeading('DATE')),
            DataColumn(label: _TableHeading('ACTIONS')),
          ],
          rows: reviews.map((review) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 280,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.jobTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          review.comment,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            height: 1.35,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 130,
                    child: Text(
                      review.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 130,
                    child: Text(
                      review.workerName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                DataCell(_RatingStars(rating: review.rating)),
                DataCell(
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _VisibilityBadge(isHidden: review.isHidden),
                      if (review.isFlagged) const _FlaggedBadge(),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    _formatDate(review.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
                DataCell(
                  _ReviewActions(
                    review: review,
                    onView: onView,
                    onToggleHidden: onToggleHidden,
                    onToggleFlagged: onToggleFlagged,
                    onDelete: onDelete,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ReviewsGrid extends StatelessWidget {
  const _ReviewsGrid({
    required this.reviews,
    required this.onView,
    required this.onToggleHidden,
    required this.onToggleFlagged,
    required this.onDelete,
  });

  final List<ManagedReview> reviews;
  final ValueChanged<ManagedReview> onView;
  final ValueChanged<ManagedReview> onToggleHidden;
  final ValueChanged<ManagedReview> onToggleFlagged;
  final ValueChanged<ManagedReview> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;

        final width =
            (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: reviews.map((review) {
            return SizedBox(
              width: width,
              child: _ReviewCard(
                review: review,
                onView: onView,
                onToggleHidden: onToggleHidden,
                onToggleFlagged: onToggleFlagged,
                onDelete: onDelete,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.onView,
    required this.onToggleHidden,
    required this.onToggleFlagged,
    required this.onDelete,
  });

  final ManagedReview review;
  final ValueChanged<ManagedReview> onView;
  final ValueChanged<ManagedReview> onToggleHidden;
  final ValueChanged<ManagedReview> onToggleFlagged;
  final ValueChanged<ManagedReview> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE6ECF2)),
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
              _RatingStars(rating: review.rating),
              const Spacer(),
              _ReviewActions(
                review: review,
                onView: onView,
                onToggleHidden: onToggleHidden,
                onToggleFlagged: onToggleFlagged,
                onDelete: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            review.jobTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.55,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _VisibilityBadge(isHidden: review.isHidden),
              if (review.isFlagged) const _FlaggedBadge(),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          _ReviewPersonRow(
            icon: Icons.person_outline_rounded,
            label: 'Customer',
            value: review.customerName,
          ),
          const SizedBox(height: 9),
          _ReviewPersonRow(
            icon: Icons.engineering_outlined,
            label: 'Worker',
            value: review.workerName,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onView(review),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('View review'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({
    required this.review,
    required this.onView,
    required this.onToggleHidden,
    required this.onToggleFlagged,
    required this.onDelete,
  });

  final ManagedReview review;
  final ValueChanged<ManagedReview> onView;
  final ValueChanged<ManagedReview> onToggleHidden;
  final ValueChanged<ManagedReview> onToggleFlagged;
  final ValueChanged<ManagedReview> onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Review actions',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView(review);
            break;
          case 'visibility':
            onToggleHidden(review);
            break;
          case 'flag':
            onToggleFlagged(review);
            break;
          case 'delete':
            onDelete(review);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'view',
          child: _ActionMenuItem(
            icon: Icons.visibility_outlined,
            text: 'View details',
          ),
        ),
        PopupMenuItem(
          value: 'visibility',
          child: _ActionMenuItem(
            icon: review.isHidden
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            text: review.isHidden ? 'Make visible' : 'Hide review',
          ),
        ),
        PopupMenuItem(
          value: 'flag',
          child: _ActionMenuItem(
            icon: review.isFlagged
                ? Icons.flag_outlined
                : Icons.outlined_flag_rounded,
            text: review.isFlagged ? 'Remove flag' : 'Flag review',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: _ActionMenuItem(
            icon: Icons.delete_outline_rounded,
            text: 'Delete review',
            danger: true,
          ),
        ),
      ],
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Color(0xFF64748B),
          size: 20,
        ),
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color =
        danger ? const Color(0xFFDC2626) : const Color(0xFF334155);

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starNumber = index + 1;
          final filled = rating >= starNumber;
          final half = !filled && rating >= starNumber - 0.5;

          return Icon(
            filled
                ? Icons.star_rounded
                : half
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded,
            size: 18,
            color: const Color(0xFFEAB308),
          );
        }),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.isHidden});

  final bool isHidden;

  @override
  Widget build(BuildContext context) {
    final color = isHidden
        ? const Color(0xFF64748B)
        : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isHidden ? 'HIDDEN' : 'VISIBLE',
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _FlaggedBadge extends StatelessWidget {
  const _FlaggedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'FLAGGED',
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFD97706),
        ),
      ),
    );
  }
}

class _ReviewPersonRow extends StatelessWidget {
  const _ReviewPersonRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 215,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  const _TableHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

class _EmptyReviewsState extends StatelessWidget {
  const _EmptyReviewsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 70),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 58,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(
            'No reviews found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search ya selected filter ke mutabiq koi review nahi mila.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsErrorState extends StatelessWidget {
  const _ReviewsErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFDA4AF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF991B1B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _reviewFilterLabel(ReviewFilter filter) {
  switch (filter) {
    case ReviewFilter.all:
      return 'All';
    case ReviewFilter.positive:
      return 'Positive';
    case ReviewFilter.neutral:
      return 'Neutral';
    case ReviewFilter.negative:
      return 'Negative';
    case ReviewFilter.flagged:
      return 'Flagged';
    case ReviewFilter.hidden:
      return 'Hidden';
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  return DateFormat('dd MMM yyyy').format(date);
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Unknown';
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}
