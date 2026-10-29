import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skilllink_admin/theme/admin_design.dart';

/// Support requests sent from the mobile app's Help screens
/// (`support_requests`). Admins can filter, search and resolve them; every
/// status change is written to the audit log.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  static const _pageSize = 50;
  final _search = TextEditingController();
  String _status = 'open';
  int _limit = _pageSize;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> get _query {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'support_requests',
    );
    if (_status != 'all') query = query.where('status', isEqualTo: _status);
    return query.orderBy('createdAt', descending: true).limit(_limit);
  }

  Future<void> _setStatus(String id, String status) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.update(firestore.collection('support_requests').doc(id), {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
    });
    batch.set(firestore.collection('admin_audit_logs').doc(), {
      'action': 'support_request_$status',
      'targetId': id,
      'adminUid': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Marked as $status.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update (${error.code}).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search name, email or message',
                  ),
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'open', label: Text('Open')),
                  ButtonSegment(value: 'resolved', label: Text('Resolved')),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_status},
                onSelectionChanged: (value) => setState(() {
                  _status = value.first;
                  _limit = _pageSize;
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Empty(
                    icon: Icons.error_outline_rounded,
                    title: 'Support requests could not be loaded',
                    message: '${snapshot.error}',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final query = _search.text.trim().toLowerCase();
                final docs = snapshot.data!.docs.where((doc) {
                  if (query.isEmpty) return true;
                  final data = doc.data();
                  return [
                    data['name'],
                    data['email'],
                    data['message'],
                    data['subject'],
                  ].join(' ').toLowerCase().contains(query);
                }).toList();
                if (docs.isEmpty) {
                  return const _Empty(
                    icon: Icons.inbox_outlined,
                    title: 'No support requests',
                    message: 'New messages from the Help screens appear here.',
                  );
                }
                return ListView.separated(
                  itemCount: docs.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == docs.length) {
                      return snapshot.data!.docs.length < _limit
                          ? const SizedBox.shrink()
                          : Center(
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _limit += _pageSize),
                                child: const Text('Load more'),
                              ),
                            );
                    }
                    final doc = docs[index];
                    final data = doc.data();
                    final created = (data['createdAt'] as Timestamp?)?.toDate();
                    final status = '${data['status'] ?? 'open'}';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: kAdminBrandSoft,
                                  foregroundColor: kAdminBrandDark,
                                  child: Text(
                                    '${data['name'] ?? '?'}'.isEmpty
                                        ? '?'
                                        : '${data['name'] ?? '?'}'[0]
                                              .toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${data['name'] ?? 'SkillNova user'} · ${data['role'] ?? ''}',
                                        style: text.titleSmall,
                                      ),
                                      Text(
                                        '${data['email'] ?? ''}',
                                        style: text.bodySmall?.copyWith(
                                          color: kAdminTextMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (created != null)
                                  Text(
                                    DateFormat(
                                      'd MMM y, h:mm a',
                                    ).format(created),
                                    style: text.bodySmall?.copyWith(
                                      color: kAdminTextMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if ('${data['subject'] ?? ''}'.isNotEmpty)
                              Text(
                                '${data['subject']}',
                                style: text.titleSmall,
                              ),
                            Text('${data['message'] ?? ''}'),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: status == 'resolved'
                                  ? OutlinedButton.icon(
                                      onPressed: () =>
                                          _setStatus(doc.id, 'open'),
                                      icon: const Icon(Icons.undo_rounded),
                                      label: const Text('Re-open'),
                                    )
                                  : FilledButton.icon(
                                      onPressed: () =>
                                          _setStatus(doc.id, 'resolved'),
                                      icon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                      ),
                                      label: const Text('Mark resolved'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: kAdminTextMuted),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
