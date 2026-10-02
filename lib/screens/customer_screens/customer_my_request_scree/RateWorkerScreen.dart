import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/design_system/widgets/skillnova_text_field.dart';

class RateWorkerScreen extends StatefulWidget {
  final String workerId;
  final String requestId;

  const RateWorkerScreen({
    super.key,
    required this.workerId,
    required this.requestId,
  });

  @override
  State<RateWorkerScreen> createState() => _RateWorkerScreenState();
}

class _RateWorkerScreenState extends State<RateWorkerScreen> {
  int _selectedRating = 5;
  final TextEditingController _reviewController = TextEditingController();

  bool _isLoading = false;

  final List<String> _ratingTitles = const [
    'Very poor',
    'Poor',
    'Good',
    'Very good',
    'Excellent',
  ];

  final List<String> _ratingDescriptions = const [
    'The service did not meet expectations.',
    'There were several issues with the service.',
    'The service was satisfactory overall.',
    'The service was professional and reliable.',
    'Outstanding service and a great experience.',
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in again before submitting a review.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final requestRef = firestore.collection('requests').doc(widget.requestId);

      final reviewRef = firestore.collection('reviews').doc(widget.requestId);

      String assignedWorkerId = '';

      await firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);

        if (!requestSnapshot.exists) {
          throw Exception('Request not found');
        }

        final requestData = requestSnapshot.data()!;

        final customerId = requestData['customerId'] as String?;
        final workerId = requestData['workerId'] as String?;
        final status = requestData['status'] as String?;
        final reviewed = requestData['reviewed'] == true;

        if (customerId != user.uid) {
          throw Exception('You cannot review this request');
        }

        if (status != 'completed') {
          throw Exception('This job is not completed yet');
        }

        if (workerId == null || workerId.isEmpty) {
          throw Exception('No worker is assigned to this job');
        }

        if (workerId != widget.workerId) {
          throw Exception('Worker information does not match');
        }

        if (reviewed) {
          throw Exception('You have already reviewed this worker');
        }

        assignedWorkerId = workerId;

        transaction.set(reviewRef, {
          'workerId': assignedWorkerId,
          'customerId': user.uid,
          'requestId': widget.requestId,
          'rating': _selectedRating,
          'review': _reviewController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(requestRef, {
          'reviewed': true,
          'reviewPending': false,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final reviewsSnapshot = await firestore
          .collection('reviews')
          .where('workerId', isEqualTo: assignedWorkerId)
          .get();

      double totalRating = 0;

      for (final doc in reviewsSnapshot.docs) {
        final rating = doc.data()['rating'];

        if (rating is num) {
          totalRating += rating.toDouble();
        }
      }

      final reviewCount = reviewsSnapshot.docs.length;

      final averageRating = reviewCount == 0 ? 0 : totalRating / reviewCount;

      await firestore.collection('users').doc(assignedWorkerId).update({
        'rating': double.parse(averageRating.toStringAsFixed(1)),
        'totalReviews': reviewCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage('Thanks — your review has been posted.');

      await Future<void>.delayed(const Duration(milliseconds: 450));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;

      // Our own guard messages are written for people; anything else
      // (network, permissions) gets a calm generic message.
      final message = error is FirebaseException
          ? 'Your review couldn’t be sent. Check your connection and try '
                'again.'
          : error.toString().replaceFirst('Exception: ', '');
      _showMessage(message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Rate your professional')),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.xs,
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.xl,
                  ),
                  child: ContentWidth(
                    maxWidth: 560,
                    child: AbsorbPointer(
                      absorbing: _isLoading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.workerId)
                                .snapshots(),
                            builder: (context, snapshot) => _workerHeader(
                              snapshot.data?.data() ?? const {},
                            ),
                          ),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          Center(
                            child: Text(
                              'How did it go?',
                              style: text.titleLarge,
                            ),
                          ),
                          const SizedBox(height: SkillNovaSpacing.md),
                          _stars(),
                          const SizedBox(height: SkillNovaSpacing.sm),
                          Center(
                            child: AnimatedSwitcher(
                              duration: SkillNovaMotion.of(
                                context,
                                SkillNovaMotion.fast,
                              ),
                              child: Column(
                                key: ValueKey(_selectedRating),
                                children: [
                                  Text(
                                    _ratingTitles[_selectedRating - 1],
                                    style: text.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _ratingDescriptions[_selectedRating - 1],
                                    textAlign: TextAlign.center,
                                    style: text.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          SkillNovaTextField(
                            label: 'Your review',
                            controller: _reviewController,
                            optional: true,
                            hint:
                                'What stood out? Punctuality, quality, '
                                'communication…',
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 4,
                            maxLines: 6,
                            maxLength: 500,
                          ),
                          const SizedBox(height: SkillNovaSpacing.md),
                          const InfoBanner(
                            tone: SkillNovaTone.neutral,
                            icon: Icons.public_rounded,
                            title: 'Reviews are public',
                            message:
                                'Your rating and review appear on this '
                                'professional’s profile to help other '
                                'customers choose.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _submitBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workerHeader(Map<String, dynamic> worker) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final name = (worker['name']?.toString().trim().isNotEmpty ?? false)
        ? worker['name'].toString().trim()
        : 'Your professional';
    final skill = worker['skill']?.toString().trim() ?? '';
    final photo =
        (worker['profileImageUrl'] ?? worker['photoUrl'])?.toString() ?? '';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return SkillNovaCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors.primaryContainer,
            foregroundImage: photo.startsWith('http')
                ? NetworkImage(photo)
                : null,
            child: Text(
              initials,
              style: text.titleMedium?.copyWith(color: colors.primary),
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleMedium),
                if (skill.isNotEmpty) Text(skill, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stars() {
    return Semantics(
      label: 'Rating',
      value: '$_selectedRating of 5 stars',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var star = 1; star <= 5; star++)
            IconButton(
              tooltip: '$star star${star == 1 ? '' : 's'}',
              iconSize: 40,
              onPressed: () => setState(() => _selectedRating = star),
              icon: AnimatedScale(
                scale: star <= _selectedRating ? 1 : 0.88,
                duration: SkillNovaMotion.of(context, SkillNovaMotion.fast),
                child: Icon(
                  star <= _selectedRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: star <= _selectedRating
                      ? SkillNovaColors.rating
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _submitBar() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(
        SkillNovaSpacing.gutter,
        SkillNovaSpacing.sm,
        SkillNovaSpacing.gutter,
        SkillNovaSpacing.sm,
      ),
      child: ContentWidth(
        maxWidth: 560,
        child: PrimaryButton(
          label: 'Submit review',
          loading: _isLoading,
          fullWidth: true,
          onPressed: _submitReview,
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    SkillNovaToast.show(
      context,
      message,
      tone: isError ? SkillNovaTone.error : SkillNovaTone.success,
    );
  }
}
