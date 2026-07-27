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
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _submitting = false;

  Future<void> _submitForReview(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null || _submitting) return;

    final cnicFront = data['cnicFrontPath']?.toString();
    final cnicBack = data['cnicBackPath']?.toString();
    final selfie = data['liveSelfiePath']?.toString();

    if (cnicFront == null || cnicBack == null || selfie == null) {
      _message('Complete CNIC and live selfie before submission.', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final batch = _firestore.batch();
      final verificationRef = _firestore
          .collection('verification_requests')
          .doc(user.uid);
      final userRef = _firestore.collection('users').doc(user.uid);

      batch.set(verificationRef, {
        'workerId': user.uid,
        'role': 'worker',
        'email': user.email,
        'phoneNumber': user.phoneNumber,
        'identityStatus': 'pending',
        'backgroundStatus': data['backgroundStatus'] ?? 'not_submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(userRef, {
        'identityVerificationStatus': 'pending',
        'verificationLevel': 'unverified',
        'canAcceptJobs': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      _message('Verification submitted for admin review.');
    } on FirebaseException catch (e) {
      _message(e.message ?? 'Unable to submit verification.', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Session expired.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Worker Verification Center'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('verification_requests')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final status = data['identityStatus']?.toString() ?? 'not_submitted';
          final cnicDone =
              data['cnicFrontPath'] != null && data['cnicBackPath'] != null;
          final selfieDone = data['liveSelfiePath'] != null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              _statusBanner(status),
              const SizedBox(height: 18),
              _stepCard(
                title: 'Email verification',
                subtitle: user.email ?? 'Email account',
                icon: Icons.email_outlined,
                complete: user.emailVerified,
                onTap: null,
              ),
              const SizedBox(height: 12),
              _stepCard(
                title: 'Phone verification',
                subtitle: user.phoneNumber ?? 'Phone number not available',
                icon: Icons.phone_android_rounded,
                complete: user.phoneNumber != null,
                onTap: null,
              ),
              const SizedBox(height: 12),
              _stepCard(
                title: 'CNIC front and back',
                subtitle: cnicDone
                    ? 'CNIC images securely uploaded'
                    : 'Capture clear front and back images',
                icon: Icons.badge_outlined,
                complete: cnicDone,
                onTap: status == 'approved'
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CnicVerificationScreen(),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 12),
              _stepCard(
                title: 'Live selfie',
                subtitle: selfieDone
                    ? 'Camera selfie securely uploaded'
                    : 'Capture a fresh front-camera selfie',
                icon: Icons.face_retouching_natural,
                complete: selfieDone,
                onTap: status == 'approved'
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LiveSelfieScreen(),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'Your CNIC and selfie are private verification records. They must never be displayed to customers or stored as public download URLs.',
                  style: TextStyle(color: Color(0xFF92400E), height: 1.45),
                ),
              ),
              const SizedBox(height: 18),
              if (status != 'approved')
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    onPressed: (_submitting || !cnicDone || !selfieDone)
                        ? null
                        : () => _submitForReview(data),
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_user_outlined),
                    label: Text(
                      status == 'pending'
                          ? 'Resubmit updated documents'
                          : 'Submit for admin review',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusBanner(String status) {
    Color color;
    IconData icon;
    String title;
    String message;

    switch (status) {
      case 'approved':
        color = const Color(0xFF16A34A);
        icon = Icons.verified_rounded;
        title = 'Identity verified';
        message = 'Your identity has been approved by SkillNova.';
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        icon = Icons.hourglass_top_rounded;
        title = 'Review in progress';
        message = 'You cannot accept jobs until approval.';
        break;
      case 'rejected':
        color = const Color(0xFFDC2626);
        icon = Icons.error_outline_rounded;
        title = 'Verification needs attention';
        message = 'Replace the requested documents and submit again.';
        break;
      default:
        color = const Color(0xFF2563EB);
        icon = Icons.shield_outlined;
        title = 'Complete identity verification';
        message = 'CNIC and live selfie are required before accepting jobs.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool complete,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF10B981)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                complete ? Icons.check_circle_rounded : Icons.chevron_right,
                color: complete
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
