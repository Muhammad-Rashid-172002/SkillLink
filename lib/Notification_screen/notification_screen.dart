import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/services/notification_router.dart';

/// One notification document, normalised for display.
@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.data,
  });

  factory NotificationItem.fromMap(String id, Map<String, dynamic> data) {
    String text(Object? value, String fallback) {
      final trimmed = value?.toString().trim() ?? '';
      return trimmed.isEmpty ? fallback : trimmed;
    }

    final raw = data['createdAt'];
    final created = raw is Timestamp
        ? raw.toDate()
        : raw is DateTime
        ? raw
        : raw is String
        ? DateTime.tryParse(raw)
        : null;
    return NotificationItem(
      id: id,
      title: text(data['title'], 'Update'),
      message: text(data['message'], 'You have a new update.'),
      type: text(data['type'], '').toLowerCase(),
      isRead: data['isRead'] == true,
      createdAt: created,
      data: data,
    );
  }

  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  String get status => data['status']?.toString().toLowerCase() ?? '';

  /// Icon and tone that communicate the category at a glance.
  (IconData, SkillNovaTone) get visual => switch (type) {
    'chat' => (Icons.chat_bubble_outline_rounded, SkillNovaTone.info),
    'review' => (Icons.star_outline_rounded, SkillNovaTone.warning),
    'job' || 'direct_job' => (Icons.work_outline_rounded, SkillNovaTone.info),
    'emergency_alert' => (Icons.sos_rounded, SkillNovaTone.error),
    'credits' ||
    'credit' ||
    'payment' => (Icons.account_balance_wallet_outlined, SkillNovaTone.success),
    'job_completed' ||
    'completed' => (Icons.task_alt_rounded, SkillNovaTone.success),
    'job_accepted' || 'accepted' => (Icons.route_outlined, SkillNovaTone.info),
    'job_status' when status == 'completed' => (
      Icons.task_alt_rounded,
      SkillNovaTone.success,
    ),
    'job_status' when status == 'cancelled' || status == 'rejected' => (
      Icons.event_busy_outlined,
      SkillNovaTone.error,
    ),
    'job_status' => (Icons.route_outlined, SkillNovaTone.info),
    _ => (Icons.notifications_none_rounded, SkillNovaTone.neutral),
  };
}

enum NotificationPeriod {
  today('Today'),
  week('This week'),
  earlier('Earlier');

  const NotificationPeriod(this.label);
  final String label;
}

/// Groups newest-first notifications by recency. Pure, so it is testable.
Map<NotificationPeriod, List<NotificationItem>> groupNotifications(
  List<NotificationItem> items, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final startOfToday = DateTime(reference.year, reference.month, reference.day);
  final startOfWeek = startOfToday.subtract(const Duration(days: 6));
  final groups = <NotificationPeriod, List<NotificationItem>>{};
  for (final item in items) {
    final date = item.createdAt;
    final period = date == null || date.isBefore(startOfWeek)
        ? NotificationPeriod.earlier
        : date.isBefore(startOfToday)
        ? NotificationPeriod.week
        : NotificationPeriod.today;
    groups.putIfAbsent(period, () => []).add(item);
  }
  return {
    for (final period in NotificationPeriod.values)
      if (groups[period] != null) period: groups[period]!,
  };
}

String notificationTimeLabel(DateTime? date, {DateTime? now}) {
  if (date == null) return 'Recently';
  final difference = (now ?? DateTime.now()).difference(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Notification center shared by customers and workers.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _openingId;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _query();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _query() => _firestore
      .collection('notifications')
      .where('userId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(SkillNovaSpacing.xl),
            child: EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to see notifications',
              message: 'Your updates appear here once you are signed in.',
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final items = (snapshot.data?.docs ?? const [])
            .map((doc) => NotificationItem.fromMap(doc.id, doc.data()))
            .toList(growable: false);
        final unread = items.where((item) => !item.isRead).length;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.only(right: SkillNovaSpacing.xs),
                  child: TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text('Mark all read'),
                  ),
                ),
            ],
          ),
          body: _body(snapshot, items, unread),
        );
      },
    );
  }

  Widget _body(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    List<NotificationItem> items,
    int unread,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SkillNovaSpacing.xl),
          child: ErrorState(
            title: 'Notifications unavailable',
            message:
                'We couldn’t load your updates right now. Check your '
                'connection and try again.',
            actionLabel: 'Try again',
            onAction: () => setState(() => _stream = _query()),
          ),
        ),
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const _NotificationSkeleton();
    }
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(SkillNovaSpacing.xl),
          child: EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'You’re all caught up',
            message:
                'Booking updates, new jobs, messages and reviews will show '
                'up here.',
          ),
        ),
      );
    }

    final groups = groupNotifications(items);
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
                Text(
                  unread == 0
                      ? 'No unread updates'
                      : '$unread unread update${unread == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                for (final entry in groups.entries) ...[
                  const SizedBox(height: SkillNovaSpacing.lg),
                  ListGroup(
                    title: entry.key.label,
                    children: [
                      for (final item in entry.value)
                        _NotificationRow(
                          key: ValueKey(item.id),
                          item: item,
                          busy: _openingId == item.id,
                          onTap: () => _open(item),
                          onDelete: () => _delete(item),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _firestore.collection('notifications').doc(id);

  Future<void> _open(NotificationItem item) async {
    if (_openingId != null) return;
    setState(() => _openingId = item.id);
    try {
      if (!item.isRead) {
        await _ref(
          item.id,
        ).update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
      }
      final screen = await NotificationRouter.destinationFor(item.data);
      if (!mounted) return;
      if (screen == null) {
        SkillNovaToast.show(
          context,
          'This update has no further details.',
          tone: SkillNovaTone.info,
        );
        return;
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    } catch (_) {
      if (mounted) {
        SkillNovaToast.show(
          context,
          'We couldn’t open this update. Please try again.',
          tone: SkillNovaTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _delete(NotificationItem item) async {
    try {
      await _ref(item.id).delete();
      if (mounted) SkillNovaToast.show(context, 'Notification removed.');
    } catch (_) {
      if (mounted) {
        SkillNovaToast.show(
          context,
          'We couldn’t remove that notification. Please try again.',
          tone: SkillNovaTone.error,
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _uid)
          .where('isRead', isEqualTo: false)
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (mounted) {
        SkillNovaToast.show(
          context,
          'All caught up.',
          tone: SkillNovaTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        SkillNovaToast.show(
          context,
          'We couldn’t update your notifications. Please try again.',
          tone: SkillNovaTone.error,
        );
      }
    }
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.busy = false,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, tone) = item.visual;
    final time = notificationTimeLabel(item.createdAt);
    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: colors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: SkillNovaSpacing.lg),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Semantics(
        button: true,
        label:
            '${item.isRead ? '' : 'Unread. '}${item.title}. ${item.message}. '
            '$time',
        excludeSemantics: true,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(SkillNovaSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: icon, tone: tone, size: 36),
                const SizedBox(width: SkillNovaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // Unread is shown by weight *and* a dot, not
                              // by color alone.
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: item.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: SkillNovaSpacing.xs),
                          Text(time, style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SkillNovaSpacing.xs),
                SizedBox(
                  width: 10,
                  child: busy
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : item.isRead
                      ? null
                      : Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading notifications',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SkillNovaSpacing.gutter),
        children: [
          const SkeletonBox(width: 140, height: 14),
          const SizedBox(height: SkillNovaSpacing.lg),
          SkillNovaCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < 5; i++)
                  const Padding(
                    padding: EdgeInsets.all(SkillNovaSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 36, height: 36, radius: 11),
                        SizedBox(width: SkillNovaSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 160, height: 14),
                              SizedBox(height: SkillNovaSpacing.xs),
                              SkeletonBox(height: 12),
                            ],
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
}
