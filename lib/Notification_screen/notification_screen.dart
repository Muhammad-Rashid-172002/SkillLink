import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/RateWorkerScreen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _signedOutView(context);
    }

    final uid = user.uid;

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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _loadingScreen(context);
                }

                if (snapshot.hasError) {
                  return _errorScreen(context, snapshot.error.toString());
                }

                final notifications = snapshot.data?.docs ?? [];

                final unreadCount = notifications.where((doc) {
                  return doc.data()['isRead'] != true;
                }).length;

                return RefreshIndicator(
                  color: _primary,
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 500),
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _topBar(
                              context: context,
                              unreadCount: unreadCount,
                              uid: uid,
                            ),
                            const SizedBox(height: 20),
                            _heroCard(
                              total: notifications.length,
                              unread: unreadCount,
                            ),
                            const SizedBox(height: 22),
                            _sectionHeader(
                              total: notifications.length,
                              unread: unreadCount,
                            ),
                            const SizedBox(height: 14),
                            if (notifications.isEmpty)
                              _emptyState()
                            else
                              ...notifications.map(
                                (doc) => _notificationCard(
                                  context: context,
                                  doc: doc,
                                ),
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
        ],
      ),
    );
  }

  Widget _topBar({
    required BuildContext context,
    required int unreadCount,
    required String uid,
  }) {
    return Row(
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
                'Notifications',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Stay updated with your latest activity',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (unreadCount > 0)
          TextButton.icon(
            onPressed: () => _markAllAsRead(context, uid),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              backgroundColor: _primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 16),
            label: const Text(
              'Mark all',
              style: TextStyle(fontSize: 9.7, fontWeight: FontWeight.w900),
            ),
          )
        else
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _secondary]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
      ],
    );
  }

  Widget _heroCard({required int total, required int unread}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
                        'NOTIFICATION CENTER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      unread == 0
                          ? 'You are all caught up'
                          : '$unread unread updates',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      total == 0
                          ? 'New job, chat and payment updates will appear here.'
                          : 'You have $total notifications in your activity history.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11.2,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 94,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 43,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 17,
                        right: 16,
                        child: Container(
                          height: 20,
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: _warning,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({required int total, required int unread}) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent activity',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Latest updates from SkillNova',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: unread > 0
                ? _primary.withOpacity(0.09)
                : _success.withOpacity(0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Icon(
                unread > 0
                    ? Icons.mark_email_unread_outlined
                    : Icons.done_all_rounded,
                color: unread > 0 ? _primary : _success,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                unread > 0 ? '$unread unread' : '$total total',
                style: TextStyle(
                  color: unread > 0 ? _primary : _success,
                  fontSize: 9.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notificationCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();
    final title = _fallback(data['title'], 'Notification');
    final message = _fallback(data['message'], 'You have a new update.');
    final isRead = data['isRead'] == true;
    final type = _notificationType(
      title: title,
      explicitType: data['type']?.toString(),
    );
    final notificationType =
        data['type']?.toString().toLowerCase().trim() ?? '';

    final isCompletedNotification =
        title.toLowerCase().contains('completed') ||
        notificationType == 'job_completed' ||
        notificationType == 'completed';

    final reviewed = data['reviewed'] == true;

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        await doc.reference.delete();

        if (context.mounted) {
          _showMessage(context, 'Notification deleted.');
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.only(right: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),

          onTap: () async {
            try {
              if (!isRead) {
                await doc.reference.update({
                  'isRead': true,
                  'readAt': FieldValue.serverTimestamp(),
                });
              }

              final notificationType =
                  data['type']?.toString().toLowerCase().trim() ?? '';

              final requestId = data['requestId']?.toString().trim() ?? '';

              String workerId = data['workerId']?.toString().trim() ?? '';

              final isCompletedNotification =
                  title.toLowerCase().contains('completed') ||
                  notificationType == 'job_completed' ||
                  notificationType == 'completed';

              if (!isCompletedNotification) {
                if (context.mounted) {
                  _showMessage(context, 'Notification marked as read.');
                }
                return;
              }

              if (requestId.isEmpty) {
                if (!context.mounted) return;

                _showMessage(
                  context,
                  'Request information was not found.',
                  isError: true,
                );
                return;
              }

              final requestSnapshot = await FirebaseFirestore.instance
                  .collection('requests')
                  .doc(requestId)
                  .get();

              if (!requestSnapshot.exists) {
                if (!context.mounted) return;

                _showMessage(
                  context,
                  'This job request was not found.',
                  isError: true,
                );
                return;
              }

              final requestData = requestSnapshot.data() ?? {};

              if (workerId.isEmpty) {
                workerId = requestData['workerId']?.toString().trim() ?? '';
              }

              final reviewed = requestData['reviewed'] == true;
              final reviewPending = requestData['reviewPending'] == true;

              final status =
                  requestData['status']?.toString().toLowerCase().trim() ?? '';

              if (!context.mounted) return;

              if (reviewed) {
                _showMessage(context, 'You have already reviewed this worker.');
                return;
              }

              if (status != 'completed') {
                _showMessage(
                  context,
                  'You can rate the worker after the job is completed.',
                  isError: true,
                );
                return;
              }

              if (!reviewPending) {
                _showMessage(
                  context,
                  'Review is not available for this job.',
                  isError: true,
                );
                return;
              }

              if (workerId.isEmpty) {
                _showMessage(
                  context,
                  'Worker information was not found.',
                  isError: true,
                );
                return;
              }

              final submitted = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => RateWorkerScreen(
                    requestId: requestId,
                    workerId: workerId,
                  ),
                ),
              );

              if (submitted == true && context.mounted) {
                _showMessage(context, 'Thank you for rating the worker.');
              }
            } on FirebaseException catch (error) {
              if (!context.mounted) return;

              _showMessage(
                context,
                error.message ?? 'Unable to open notification.',
                isError: true,
              );
            } catch (error) {
              if (!context.mounted) return;

              _showMessage(
                context,
                'Unable to open notification.',
                isError: true,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.only(bottom: 13),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: isCompletedNotification && !reviewed
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
                    )
                  : null,

              // Normal notifications ke liye white/light background
              color: isCompletedNotification && !reviewed
                  ? null
                  : isRead
                  ? _surface
                  : type.color.withOpacity(0.055),

              borderRadius: BorderRadius.circular(22),

              border: Border.all(
                color: isCompletedNotification && !reviewed
                    ? const Color(0xFFF59E0B).withOpacity(0.35)
                    : isRead
                    ? _border
                    : type.color.withOpacity(0.22),
                width: isCompletedNotification && !reviewed ? 1.4 : 1,
              ),

              boxShadow: [
                BoxShadow(
                  color: isCompletedNotification && !reviewed
                      ? const Color(0xFFF59E0B).withOpacity(0.12)
                      : const Color(0x070F172A),
                  blurRadius: isCompletedNotification && !reviewed ? 20 : 15,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: isCompletedNotification
                        ? const Color(0xFFF59E0B).withOpacity(0.13)
                        : type.color.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCompletedNotification ? Icons.star_rounded : type.icon,
                    color: isCompletedNotification
                        ? const Color(0xFFF59E0B)
                        : type.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 13.2,
                                height: 1.25,
                                fontWeight: isRead
                                    ? FontWeight.w800
                                    : FontWeight.w900,
                              ),
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              height: 9,
                              width: 9,
                              decoration: BoxDecoration(
                                color: type.color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: type.color.withOpacity(0.30),
                                    blurRadius: 7,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10.3,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isCompletedNotification && !reviewed) ...[
                        const SizedBox(height: 11),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.11),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.20),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                color: Color(0xFFD97706),
                                size: 17,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tap this notification to rate your worker',
                                  style: TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFFD97706),
                                size: 17,
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isCompletedNotification && !reviewed
                                  ? const Color(0xFFF59E0B).withOpacity(0.12)
                                  : reviewed
                                  ? _success.withOpacity(0.10)
                                  : type.color.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              isCompletedNotification && !reviewed
                                  ? 'Rate worker'
                                  : reviewed
                                  ? 'Reviewed'
                                  : type.label,
                              style: TextStyle(
                                color: isCompletedNotification && !reviewed
                                    ? const Color(0xFFD97706)
                                    : reviewed
                                    ? _success
                                    : type.color,
                                fontSize: 8.3,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.schedule_rounded,
                            color: _textSecondary,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _timeAgo(data['createdAt']),
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 8.7,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(23),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'No notifications yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Job, chat, payment and worker updates will appear here when available.',
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
    );
  }

  Widget _loadingScreen(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Column(
        children: [
          _topBar(context: context, unreadCount: 0, uid: ''),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _border),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2.6,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Loading notifications...',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorScreen(BuildContext context, String error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Column(
        children: [
          _topBar(context: context, unreadCount: 0, uid: ''),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 62,
                      width: 62,
                      decoration: BoxDecoration(
                        color: _danger.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        color: _danger,
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Unable to load notifications',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please check your internet connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      error,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signedOutView(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, color: _primary, size: 44),
                  SizedBox(height: 15),
                  Text(
                    'Sign in required',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Please sign in again to view your notifications.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10.6,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAllAsRead(BuildContext context, String uid) async {
    if (uid.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          _showMessage(context, 'No unread notifications.');
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (context.mounted) {
        _showMessage(context, 'All notifications marked as read.');
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Unable to update notifications.', isError: true);
      }
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: _danger,
                  size: 30,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Delete notification?',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'This notification will be permanently removed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Delete',
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
  }

  NotificationTypeDesign _notificationType({
    required String title,
    String? explicitType,
  }) {
    final value = '${explicitType ?? ''} $title'.toLowerCase();

    if (value.contains('chat') || value.contains('message')) {
      return const NotificationTypeDesign(
        label: 'Chat',
        icon: Icons.chat_bubble_outline_rounded,
        color: Color(0xFF2563EB),
      );
    }

    if (value.contains('payment') ||
        value.contains('wallet') ||
        value.contains('credit')) {
      return const NotificationTypeDesign(
        label: 'Payment',
        icon: Icons.account_balance_wallet_outlined,
        color: _warning,
      );
    }

    if (value.contains('job') ||
        value.contains('worker') ||
        value.contains('work') ||
        value.contains('request')) {
      return const NotificationTypeDesign(
        label: 'Job update',
        icon: Icons.work_outline_rounded,
        color: _success,
      );
    }

    if (value.contains('review') || value.contains('rating')) {
      return const NotificationTypeDesign(
        label: 'Review',
        icon: Icons.star_outline_rounded,
        color: Color(0xFF8B5CF6),
      );
    }

    return const NotificationTypeDesign(
      label: 'General',
      icon: Icons.notifications_none_rounded,
      color: _primary,
    );
  }

  String _timeAgo(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) return 'Recently';

    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
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

  String _fallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
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

class NotificationTypeDesign {
  final String label;
  final IconData icon;
  final Color color;

  const NotificationTypeDesign({
    required this.label,
    required this.icon,
    required this.color,
  });
}
