import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skilllink_admin/theme/admin_design.dart';

/// Read-only, append-only log of administrative actions
/// (`admin_audit_logs`). Security rules forbid editing or deleting entries.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  static const _pageSize = 100;
  int _limit = _pageSize;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 360,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Filter by action, user id or admin id',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('admin_audit_logs')
                    .orderBy('createdAt', descending: true)
                    .limit(_limit)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Audit log unavailable: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final query = _search.text.trim().toLowerCase();
                  final docs = snapshot.data!.docs.where((doc) {
                    if (query.isEmpty) return true;
                    return doc
                        .data()
                        .values
                        .join(' ')
                        .toLowerCase()
                        .contains(query);
                  }).toList();
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No actions recorded yet.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == docs.length) {
                        return snapshot.data!.docs.length < _limit
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _limit += _pageSize),
                                    child: const Text('Load more'),
                                  ),
                                ),
                              );
                      }
                      final data = docs[index].data();
                      final created = (data['createdAt'] as Timestamp?)
                          ?.toDate();
                      final target =
                          data['targetUid'] ??
                          data['targetId'] ??
                          data['workerId'] ??
                          '';
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: kAdminBrandSoft,
                          foregroundColor: kAdminBrandDark,
                          child: Icon(Icons.history_rounded, size: 20),
                        ),
                        title: Text(
                          '${data['action'] ?? 'action'}'.replaceAll('_', ' '),
                          style: text.titleSmall,
                        ),
                        subtitle: Text(
                          [
                            if ('$target'.isNotEmpty) 'Target: $target',
                            if (data['reason'] != null)
                              'Reason: ${data['reason']}',
                            'Admin: ${data['adminUid'] ?? data['adminId'] ?? 'unknown'}',
                          ].join(' · '),
                        ),
                        trailing: created == null
                            ? null
                            : Text(
                                DateFormat('d MMM y, h:mm a').format(created),
                                style: text.bodySmall?.copyWith(
                                  color: kAdminTextMuted,
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
