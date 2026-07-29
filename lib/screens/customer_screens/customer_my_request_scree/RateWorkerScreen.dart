import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);

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

      _showMessage('Review submitted successfully.');

      await Future<void>.delayed(const Duration(milliseconds: 450));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
            child: _ambientCircle(size: 330, color: _primary.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -165,
            left: -135,
            child: _ambientCircle(
              size: 350,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                    child:
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.workerId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final worker = snapshot.data?.data();

                            return Column(
                              children: [
                                _heroCard(),
                                const SizedBox(height: 18),
                                if (worker != null) ...[
                                  _workerSummary(worker),
                                  const SizedBox(height: 18),
                                ],
                                _ratingCard(),
                                const SizedBox(height: 18),
                                _reviewCard(),
                                const SizedBox(height: 18),
                                _privacyNote(),
                                const SizedBox(height: 20),
                                _submitButton(),
                              ],
                            );
                          },
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading) Positioned.fill(child: _submittingOverlay()),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.maybePop(context),
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
                  'Rate your worker',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Share your experience with the community',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.6,
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
                colors: [_warning, Color(0xFFFBBF24)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _warning.withOpacity(0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
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
            top: -70,
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
            left: -55,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'How was your experience?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.55,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your honest feedback helps workers improve and helps other customers make better choices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 11.2,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workerSummary(Map<String, dynamic> worker) {
    final name = _fallback(worker['name'], 'Skilled worker');
    final skill = _fallback(worker['skill'], 'Professional service');
    final city = _fallback(
      worker['city'] ?? worker['location'],
      'Location unavailable',
    );
    final rating = _doubleValue(worker['rating']);
    final totalReviews = _intValue(
      worker['totalReviews'] ?? worker['reviewsCount'],
    );
    final verified =
        worker['identityVerificationStatus'] == 'approved' &&
        worker['canAcceptJobs'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
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
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _secondary]),
              borderRadius: BorderRadius.circular(20),
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
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 10.6,
                    fontWeight: FontWeight.w900,
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
                    Expanded(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 9.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _warning.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: _warning, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalReviews reviews',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 7.8,
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

  Widget _ratingCard() {
    final index = _selectedRating - 1;
    final title = _ratingTitles[index];
    final description = _ratingDescriptions[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          const Text(
            'Select your rating',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a star to rate the service',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 9.7,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final selected = starValue <= _selectedRating;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starValue;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? _warning.withOpacity(0.11)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: selected ? _warning : _border),
                    ),
                    child: Icon(
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _warning,
                      size: selected ? 29 : 27,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 17),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _ratingColor(_selectedRating).withOpacity(0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  height: 39,
                  width: 39,
                  decoration: BoxDecoration(
                    color: _ratingColor(_selectedRating).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _ratingIcon(_selectedRating),
                    color: _ratingColor(_selectedRating),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _ratingColor(_selectedRating),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 9.3,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$_selectedRating/5',
                  style: TextStyle(
                    color: _ratingColor(_selectedRating),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rate_review_outlined, color: _primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Write a review',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Mention professionalism, timing and service quality.',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 9.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reviewController,
            minLines: 5,
            maxLines: 7,
            maxLength: 350,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 11.5,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText:
                  'Share details about your experience with this worker...',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              counterStyle: const TextStyle(
                color: _textSecondary,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
              contentPadding: const EdgeInsets.all(15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _primary.withOpacity(0.12)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _primary, size: 18),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your review may be visible on the worker’s public profile. Keep it honest, respectful and related to the completed service.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 9.4,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitReview,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
        ),
        icon: const Icon(Icons.send_rounded, size: 18),
        label: const Text(
          'Submit review',
          style: TextStyle(fontSize: 12.2, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _submittingOverlay() {
    return ColoredBox(
      color: _textPrimary.withOpacity(0.28),
      child: Center(
        child: Container(
          width: 245,
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(23),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 30,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primary, strokeWidth: 2.7),
              SizedBox(height: 16),
              Text(
                'Submitting your review',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'We are updating the worker’s rating.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.2,
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

  Color _ratingColor(int rating) {
    if (rating <= 2) return _danger;
    if (rating == 3) return _warning;
    if (rating == 4) return _primary;
    return _success;
  }

  IconData _ratingIcon(int rating) {
    if (rating <= 2) return Icons.sentiment_dissatisfied_rounded;
    if (rating == 3) return Icons.sentiment_neutral_rounded;
    if (rating == 4) return Icons.sentiment_satisfied_rounded;
    return Icons.sentiment_very_satisfied_rounded;
  }

  String _fallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _intValue(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'SW';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: isError ? _danger : _textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
}
