import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cnic_verification_screen.dart';
import 'live_selfie_screen.dart';

class WorkerVerificationCenterScreen extends StatefulWidget {
  const WorkerVerificationCenterScreen({super.key});

  @override
  State<WorkerVerificationCenterScreen> createState() =>
      _WorkerVerificationCenterScreenState();
}

class _WorkerVerificationCenterScreenState
    extends State<WorkerVerificationCenterScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF0F9D73);
  static const Color _primaryDark = Color(0xFF087A59);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _info = Color(0xFF2563EB);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _submitting = false;

  Future<void> _submitForReview(Map<String, dynamic> data) async {
    final user = _auth.currentUser;

    if (user == null || _submitting) return;

    final cnicFront = data['cnicFrontPath']?.toString().trim();
    final cnicBack = data['cnicBackPath']?.toString().trim();
    final selfie = data['liveSelfiePath']?.toString().trim();

    if (cnicFront == null ||
        cnicFront.isEmpty ||
        cnicBack == null ||
        cnicBack.isEmpty ||
        selfie == null ||
        selfie.isEmpty) {
      _showMessage(
        'CNIC aur live selfie complete karke phir submit karein.',
        isError: true,
      );
      return;
    }

    final confirmed = await _showSubmitConfirmation();

    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);

    try {
      final batch = _firestore.batch();

      final verificationRef = _firestore
          .collection('verification_requests')
          .doc(user.uid);

      final userRef = _firestore.collection('users').doc(user.uid);

      batch.set(
        verificationRef,
        {
          'workerId': user.uid,
          'role': 'worker',
          'email': user.email,
          'phoneNumber': user.phoneNumber,
          'identityStatus': 'pending',
          'backgroundStatus':
              data['backgroundStatus'] ?? 'not_submitted',
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        userRef,
        {
          'identityVerificationStatus': 'pending',
          'verificationLevel': 'unverified',
          'canAcceptJobs': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      await _showSubmissionSuccess();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.message ?? 'Verification submit nahi ho saki.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Unexpected error aya hai. Dobara try karein.',
        isError: true,
      );
      debugPrint('Verification submit error: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<bool> _showSubmitConfirmation() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 34,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primary, _secondary],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Submit for admin review?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Once submitted, SkillNova admin will review your CNIC and live selfie before enabling job acceptance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: const Text(
                          'Review Again',
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text(
                          'Submit Now',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showSubmissionSuccess() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: _warning.withOpacity(0.11),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: _warning,
                    size: 45,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Submitted for review',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your identity documents are now under admin review. You will be able to accept jobs after approval.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Got It',
                      style: TextStyle(fontWeight: FontWeight.w900),
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

  void _goToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          content: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: isError ? _danger : _success,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: (isError ? _danger : _success).withOpacity(0.26),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: _buildSessionExpired(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -110,
            child: _ambientCircle(
              size: 320,
              color: _primary.withOpacity(0.09),
            ),
          ),
          Positioned(
            bottom: -170,
            left: -130,
            child: _ambientCircle(
              size: 350,
              color: _secondary.withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child:
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('verification_requests')
                        .doc(user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return _buildLoadingState();
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState(snapshot.error.toString());
                      }

                      final data =
                          snapshot.data?.data() ?? <String, dynamic>{};

                      final status = _normalizeStatus(
                        data['identityStatus'],
                      );

                      final cnicDone = _hasText(data['cnicFrontPath']) &&
                          _hasText(data['cnicBackPath']);

                      final selfieDone = _hasText(data['liveSelfiePath']);

                      final emailDone = user.emailVerified;
                      final phoneDone =
                          user.phoneNumber?.trim().isNotEmpty == true;

                      final completedItems = <bool>[
                        emailDone,
                        phoneDone,
                        cnicDone,
                        selfieDone,
                      ].where((item) => item).length;

                      final progress =
                          status == 'approved' ? 1.0 : completedItems / 4;

                      return RefreshIndicator(
                        color: _primary,
                        onRefresh: () async {
                          await user.reload();
                          await Future<void>.delayed(
                            const Duration(milliseconds: 450),
                          );
                          if (mounted) setState(() {});
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding:
                              const EdgeInsets.fromLTRB(20, 10, 20, 34),
                          children: [
                            _buildHero(
                              status: status,
                              progress: progress,
                              completedItems: completedItems,
                            ),
                            const SizedBox(height: 18),
                            _buildStatusCard(status),
                            const SizedBox(height: 18),
                            _buildProgressCard(
                              progress: progress,
                              completedItems: completedItems,
                              status: status,
                            ),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                              title: 'Verification Steps',
                              subtitle:
                                  'Complete every identity requirement below',
                            ),
                            const SizedBox(height: 12),
                            _buildStepCard(
                              step: 1,
                              title: 'Email Verification',
                              subtitle: user.email ?? 'Email account',
                              helper: emailDone
                                  ? 'Email address verified'
                                  : 'Verify your registered email address',
                              icon: Icons.mark_email_read_outlined,
                              complete: emailDone,
                              locked: true,
                              onTap: null,
                            ),
                            const SizedBox(height: 13),
                            _buildStepCard(
                              step: 2,
                              title: 'Phone Verification',
                              subtitle: user.phoneNumber ??
                                  'Phone number not available',
                              helper: phoneDone
                                  ? 'Phone number verified'
                                  : 'Complete OTP phone verification',
                              icon: Icons.phone_android_rounded,
                              complete: phoneDone,
                              locked: true,
                              onTap: null,
                            ),
                            const SizedBox(height: 13),
                            _buildStepCard(
                              step: 3,
                              title: 'CNIC Front & Back',
                              subtitle: cnicDone
                                  ? 'Both CNIC sides uploaded securely'
                                  : 'Capture clear front and back images',
                              helper: cnicDone
                                  ? 'Ready for admin review'
                                  : 'Original CNIC is required',
                              icon: Icons.badge_outlined,
                              complete: cnicDone,
                              locked: status == 'approved',
                              onTap: status == 'approved'
                                  ? null
                                  : () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<bool>(
                                          builder: (_) =>
                                              const CnicVerificationScreen(),
                                        ),
                                      );
                                    },
                            ),
                            const SizedBox(height: 13),
                            _buildStepCard(
                              step: 4,
                              title: 'Live Selfie',
                              subtitle: selfieDone
                                  ? 'Fresh camera selfie uploaded'
                                  : 'Capture a fresh front-camera selfie',
                              helper: selfieDone
                                  ? 'Ready for admin review'
                                  : 'Face must match your CNIC photo',
                              icon:
                                  Icons.face_retouching_natural_rounded,
                              complete: selfieDone,
                              locked: status == 'approved',
                              onTap: status == 'approved'
                                  ? null
                                  : () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<bool>(
                                          builder: (_) =>
                                              const LiveSelfieScreen(),
                                        ),
                                      );
                                    },
                            ),
                            const SizedBox(height: 18),
                            _buildSecurityCard(),
                            const SizedBox(height: 18),
                            _buildReviewTimeCard(status),
                            const SizedBox(height: 22),
                            _buildPrimaryAction(
                              status: status,
                              cnicDone: cnicDone,
                              selfieDone: selfieDone,
                              data: data,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_submitting) _buildBlockingLoader(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _submitting ? null : () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: _textPrimary,
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
                  'Verification Center',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Secure your worker profile',
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _secondary],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero({
    required String status,
    required double progress,
    required int completedItems,
  }) {
    final approved = status == 'approved';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: approved
              ? const [
                  Color(0xFF15803D),
                  Color(0xFF16A34A),
                  Color(0xFF14B8A6),
                ]
              : const [_primaryDark, _primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (approved ? _success : _primary).withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -75,
            right: -50,
            child: Container(
              width: 175,
              height: 175,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -95,
            left: -65,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
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
                      child: Text(
                        approved
                            ? 'IDENTITY VERIFIED'
                            : 'WORKER TRUST & SAFETY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.4,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      approved
                          ? 'Your profile is verified'
                          : 'Build a trusted worker profile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      approved
                          ? 'You can now accept jobs and connect with customers.'
                          : 'Complete identity checks to unlock job acceptance.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: 11.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            approved
                                ? Icons.work_outline_rounded
                                : Icons.checklist_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            approved
                                ? 'JOB ACCESS ENABLED'
                                : '$completedItems OF 4 STEPS COMPLETE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      color: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.18),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          approved ? 'VERIFIED' : 'COMPLETE',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 6.8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
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

  Widget _buildStatusCard(String status) {
    final design = _statusDesign(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: design.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: design.color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: design.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              design.icon,
              color: design.color,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  design.title,
                  style: TextStyle(
                    color: design.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  design.message,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'approved')
            const Icon(
              Icons.verified_rounded,
              color: _success,
              size: 25,
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required double progress,
    required int completedItems,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Verification Progress',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: _primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: _primary.withOpacity(0.09),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_primary),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            status == 'approved'
                ? 'All verification requirements completed'
                : '$completedItems of 4 identity steps completed',
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 9.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String subtitle,
    required String helper,
    required IconData icon,
    required bool complete,
    required bool locked,
    required VoidCallback? onTap,
  }) {
    final actionable = onTap != null && !locked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: actionable ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: complete
                  ? _success.withOpacity(0.22)
                  : _border,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x070F172A),
                blurRadius: 17,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: complete
                          ? const LinearGradient(
                              colors: [_success, _secondary],
                            )
                          : null,
                      color: complete
                          ? null
                          : _primary.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      complete ? Icons.check_rounded : icon,
                      color: complete ? Colors.white : _primary,
                      size: 24,
                    ),
                  ),
                  Positioned(
                    top: -5,
                    left: -5,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: complete ? _success : _textPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _surface,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '$step',
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
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: complete
                                ? _success.withOpacity(0.09)
                                : _warning.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            complete ? 'DONE' : 'PENDING',
                            style: TextStyle(
                              color:
                                  complete ? _success : _warning,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      helper,
                      style: TextStyle(
                        color: complete ? _success : _primary,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : actionable
                        ? Icons.chevron_right_rounded
                        : complete
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                color: complete ? _success : _textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lock_person_outlined,
                color: _info,
                size: 22,
              ),
              SizedBox(width: 9),
              Text(
                'Privacy & Security',
                style: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _securityRow(
            Icons.cloud_done_outlined,
            'Documents stored in private Firebase Storage',
          ),
          _securityRow(
            Icons.visibility_off_outlined,
            'CNIC and selfie are never shown to customers',
          ),
          _securityRow(
            Icons.link_off_rounded,
            'Public download URLs are not stored',
          ),
          _securityRow(
            Icons.admin_panel_settings_outlined,
            'Only authorized admin review is allowed',
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _securityRow(
    IconData icon,
    String text, {
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Icon(icon, color: _info, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E40AF),
                fontSize: 9.8,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTimeCard(String status) {
    if (status == 'approved') {
      return Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _success.withOpacity(0.20)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.verified_rounded,
              color: _success,
              size: 25,
            ),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                'Your worker account has full job access.',
                style: TextStyle(
                  color: _success,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            color: Color(0xFFD97706),
            size: 24,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Review',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review time depends on admin availability. Keep your documents clear to avoid delays.',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 9.6,
                    height: 1.45,
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

  Widget _buildPrimaryAction({
    required String status,
    required bool cnicDone,
    required bool selfieDone,
    required Map<String, dynamic> data,
  }) {
    if (status == 'approved') {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_success, _secondary],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: _success.withOpacity(0.23),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.celebration_rounded,
                  color: Colors.white,
                  size: 38,
                ),
                SizedBox(height: 10),
                Text(
                  'Identity Verification Approved',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your profile is trusted and you can now accept available jobs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 10.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: _goToHome,
              style: FilledButton.styleFrom(
                backgroundColor: _textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              icon: const Icon(
                Icons.home_rounded,
                size: 20,
              ),
              label: const Text(
                'Go to Worker Home',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (status == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _warning.withOpacity(0.20)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _warning,
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin review in progress',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pull down to refresh and check approval status.',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 9.8,
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

    final ready = cnicDone && selfieDone && !_submitting;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            onPressed:
                ready ? () => _submitForReview(data) : null,
            style: FilledButton.styleFrom(
              backgroundColor: status == 'rejected'
                  ? _danger
                  : _primary,
              disabledBackgroundColor: const Color(0xFFD8E2E8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
            ),
            icon: Icon(
              status == 'rejected'
                  ? Icons.refresh_rounded
                  : Icons.verified_user_outlined,
              size: 20,
            ),
            label: Text(
              status == 'rejected'
                  ? 'Resubmit Updated Documents'
                  : ready
                      ? 'Submit for Admin Review'
                      : 'Complete CNIC & Selfie First',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          ready
              ? 'Your documents are ready for secure submission.'
              : 'Complete the remaining identity steps to continue.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBlockingLoader() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.50),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 34),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 34,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 4,
                color: _primary,
              ),
              SizedBox(height: 18),
              Text(
                'Submitting securely...',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Please keep the app open while your verification request is being submitted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: _primary,
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: _danger,
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load verification',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                error,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionExpired() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_clock_outlined,
            color: _danger,
            size: 44,
          ),
          SizedBox(height: 14),
          Text(
            'Session Expired',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Please log in again to continue verification.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  _VerificationStatusDesign _statusDesign(String status) {
    switch (status) {
      case 'approved':
        return const _VerificationStatusDesign(
          color: _success,
          icon: Icons.verified_rounded,
          title: 'Identity Verified',
          message:
              'Your identity has been approved. Job acceptance is enabled.',
        );
      case 'pending':
        return const _VerificationStatusDesign(
          color: _warning,
          icon: Icons.hourglass_top_rounded,
          title: 'Review in Progress',
          message:
              'Your documents are under admin review. Job acceptance remains locked.',
        );
      case 'rejected':
        return const _VerificationStatusDesign(
          color: _danger,
          icon: Icons.error_outline_rounded,
          title: 'Verification Needs Attention',
          message:
              'Update the requested documents and submit your verification again.',
        );
      default:
        return const _VerificationStatusDesign(
          color: _info,
          icon: Icons.shield_outlined,
          title: 'Complete Identity Verification',
          message:
              'CNIC and a fresh live selfie are required before accepting jobs.',
        );
    }
  }

  String _normalizeStatus(dynamic value) {
    final status =
        value?.toString().toLowerCase().trim() ?? 'not_submitted';

    if (status == 'approved' ||
        status == 'pending' ||
        status == 'rejected') {
      return status;
    }

    return 'not_submitted';
  }

  bool _hasText(dynamic value) {
    return value?.toString().trim().isNotEmpty == true;
  }

  Widget _ambientCircle({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _VerificationStatusDesign {
  const _VerificationStatusDesign({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
}
