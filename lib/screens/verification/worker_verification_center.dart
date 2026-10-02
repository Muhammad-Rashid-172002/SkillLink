import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';

import 'cnic_verification_screen.dart';
import 'live_selfie_screen.dart';

/// Where a worker's identity verification stands.
enum IdentityReviewStatus { notSubmitted, pending, approved, rejected }

IdentityReviewStatus identityReviewStatusOf(Object? value) =>
    switch (value?.toString().toLowerCase().trim()) {
      'approved' => IdentityReviewStatus.approved,
      'pending' => IdentityReviewStatus.pending,
      'rejected' => IdentityReviewStatus.rejected,
      _ => IdentityReviewStatus.notSubmitted,
    };

/// Worker identity verification: shows what is done, what is left, and the
/// review outcome, and submits the CNIC + live selfie for admin review.
class WorkerVerificationCenterScreen extends StatefulWidget {
  const WorkerVerificationCenterScreen({super.key});

  @override
  State<WorkerVerificationCenterScreen> createState() =>
      _WorkerVerificationCenterScreenState();
}

class _WorkerVerificationCenterScreenState
    extends State<WorkerVerificationCenterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _submitting = false;
  int _refreshKey = 0;

  bool _hasText(dynamic value) => value?.toString().trim().isNotEmpty == true;

  Future<void> _submitForReview(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null || _submitting) return;
    if (!_hasText(data['cnicFrontPath']) ||
        !_hasText(data['cnicBackPath']) ||
        !_hasText(data['liveSelfiePath'])) {
      _showMessage(
        'Add both sides of your CNIC and a live selfie first.',
        isError: true,
      );
      return;
    }
    final confirmed = await _confirmSubmit();
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection('verification_requests').doc(user.uid),
        {
          'workerId': user.uid,
          'role': 'worker',
          'email': user.email,
          'phoneNumber': user.phoneNumber,
          'identityStatus': 'pending',
          'backgroundStatus': data['backgroundStatus'] ?? 'not_submitted',
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(_firestore.collection('users').doc(user.uid), {
        'identityVerificationStatus': 'pending',
        'verificationLevel': 'unverified',
        'canAcceptJobs': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      if (!mounted) return;
      _showMessage('Submitted. We’ll notify you when the review is done.');
    } catch (error) {
      debugPrint('Verification submit error: $error');
      if (!mounted) return;
      _showMessage(
        'Your documents couldn’t be submitted. Check your connection and '
        'try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmSubmit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.verified_user_outlined),
        title: const Text('Submit for review?'),
        content: const Text(
          'Our team will check that your CNIC is clear and that your selfie '
          'matches it. You can’t change the documents while they’re being '
          'reviewed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    SkillNovaToast.show(
      context,
      text,
      tone: isError ? SkillNovaTone.error : SkillNovaTone.success,
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<bool>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final canGoBack = Navigator.of(context).canPop();
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: canGoBack,
          title: canGoBack
              ? const Text('Identity verification')
              : const SkillNovaWordmark(size: 26),
          actions: [
            // During onboarding this is a root screen: offer a way out.
            if (!canGoBack)
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => SessionRouter.signOut(context),
                child: const Text('Sign out'),
              ),
            const SizedBox(width: SkillNovaSpacing.xs),
          ],
        ),
        body: user == null
            ? Center(
                child: EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Your session has ended',
                  message: 'Please sign in again to continue verification.',
                  actionLabel: 'Sign in',
                  onAction: () => SessionRouter.signOut(context),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                key: ValueKey(_refreshKey),
                stream: _firestore
                    .collection('verification_requests')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SkillNovaSpacing.xl),
                        child: ErrorState(
                          title: 'Verification unavailable',
                          message:
                              'We couldn’t load your verification right now.',
                          actionLabel: 'Try again',
                          onAction: () => setState(() => _refreshKey++),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(SkillNovaSpacing.gutter),
                      child: Column(
                        children: [
                          SkeletonCard(height: 140),
                          SizedBox(height: SkillNovaSpacing.lg),
                          SkeletonCard(height: 260),
                        ],
                      ),
                    );
                  }
                  return _content(user, snapshot.data!.data() ?? const {});
                },
              ),
      ),
    );
  }

  Widget _content(User user, Map<String, dynamic> data) {
    final status = identityReviewStatusOf(data['identityStatus']);
    final cnicDone =
        _hasText(data['cnicFrontPath']) && _hasText(data['cnicBackPath']);
    final selfieDone = _hasText(data['liveSelfiePath']);
    final editable =
        status == IdentityReviewStatus.notSubmitted ||
        status == IdentityReviewStatus.rejected;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await user.reload();
              if (mounted) setState(() => _refreshKey++);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                SkillNovaSpacing.gutter,
                SkillNovaSpacing.xs,
                SkillNovaSpacing.gutter,
                SkillNovaSpacing.xl,
              ),
              children: [
                ContentWidth(
                  maxWidth: 560,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Verify your identity', style: text.headlineSmall),
                      const SizedBox(height: SkillNovaSpacing.xs),
                      Text(
                        'Customers only see verified professionals. It takes '
                        'about two minutes: your CNIC and a quick selfie.',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: SkillNovaSpacing.lg),
                      _statusBanner(status, data),
                      const SizedBox(height: SkillNovaSpacing.xl),
                      ListGroup(
                        title: 'Checklist',
                        children: [
                          _StepRow(
                            icon: Icons.mark_email_read_outlined,
                            title: 'Email address',
                            subtitle: user.email ?? 'Not available',
                            done: user.emailVerified,
                          ),
                          _StepRow(
                            icon: Icons.phone_iphone_rounded,
                            title: 'Mobile number',
                            subtitle: user.phoneNumber ?? 'Not verified yet',
                            done: user.phoneNumber?.trim().isNotEmpty == true,
                          ),
                          _StepRow(
                            icon: Icons.badge_outlined,
                            title: 'CNIC, front and back',
                            subtitle: cnicDone
                                ? 'Both sides added'
                                : 'Photograph your original card',
                            done: cnicDone,
                            onTap: editable
                                ? () => _open(const CnicVerificationScreen())
                                : null,
                          ),
                          _StepRow(
                            icon: Icons.face_retouching_natural_rounded,
                            title: 'Live selfie',
                            subtitle: selfieDone
                                ? 'Selfie added'
                                : 'Must match your CNIC photo',
                            done: selfieDone,
                            onTap: editable
                                ? () => _open(const LiveSelfieScreen())
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: SkillNovaSpacing.lg),
                      const InfoBanner(
                        tone: SkillNovaTone.neutral,
                        icon: Icons.lock_outline_rounded,
                        title: 'Your documents stay private',
                        message:
                            'Your CNIC and selfie are only seen by SkillNova’s '
                            'verification team — never by customers or other '
                            'professionals.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _actionBar(status, cnicDone && selfieDone, data),
      ],
    );
  }

  Widget _statusBanner(IdentityReviewStatus status, Map<String, dynamic> data) {
    final reason = data['rejectionReason']?.toString().trim() ?? '';
    return switch (status) {
      IdentityReviewStatus.approved => const InfoBanner(
        tone: SkillNovaTone.success,
        icon: Icons.verified_rounded,
        title: 'You’re verified',
        message: 'Your profile shows a verified badge and you can accept jobs.',
      ),
      IdentityReviewStatus.pending => const InfoBanner(
        tone: SkillNovaTone.warning,
        icon: Icons.hourglass_top_rounded,
        title: 'In review',
        message:
            'Our team is checking your documents. You’ll get a notification '
            'as soon as there’s a decision.',
      ),
      IdentityReviewStatus.rejected => InfoBanner(
        tone: SkillNovaTone.error,
        title: 'Changes needed',
        message: reason.isEmpty
            ? 'We couldn’t verify your documents. Retake the photos and '
                  'submit again.'
            : '$reason Retake the photos and submit again.',
      ),
      IdentityReviewStatus.notSubmitted => const InfoBanner(
        icon: Icons.shield_outlined,
        title: 'Not submitted yet',
        message: 'Complete the checklist below, then submit for review.',
      ),
    };
  }

  Widget _actionBar(
    IdentityReviewStatus status,
    bool documentsReady,
    Map<String, dynamic> data,
  ) {
    final colors = Theme.of(context).colorScheme;
    final Widget action = switch (status) {
      IdentityReviewStatus.approved => PrimaryButton(
        label: 'Go to dashboard',
        icon: Icons.arrow_forward_rounded,
        fullWidth: true,
        onPressed: () => SessionRouter.continueSession(context),
      ),
      IdentityReviewStatus.pending => SecondaryButton(
        label: 'Check status',
        icon: Icons.refresh_rounded,
        fullWidth: true,
        onPressed: () => setState(() => _refreshKey++),
      ),
      _ => PrimaryButton(
        label: documentsReady ? 'Submit for review' : 'Complete the checklist',
        loading: _submitting,
        fullWidth: true,
        onPressed: documentsReady ? () => _submitForReview(data) : null,
      ),
    };
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
      child: SafeArea(
        top: false,
        child: ContentWidth(maxWidth: 560, child: action),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      icon: icon,
      tone: done ? SkillNovaTone.success : SkillNovaTone.info,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: done
          ? const StatusBadge(
              label: 'Done',
              tone: SkillNovaTone.success,
              icon: Icons.check_rounded,
            )
          : onTap == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
    );
  }
}
