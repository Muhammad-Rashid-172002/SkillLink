import 'package:cloud_firestore/cloud_firestore.dart';

/// Requests and reviews only store customer/worker ids. This joins in the
/// display name, email and phone from `users/{id}` so admins see who is
/// involved instead of a generic "Customer" / "Worker". Profiles are cached
/// and fetched in batches of 10 (the Firestore `whereIn` limit).
class ParticipantDirectory {
  ParticipantDirectory({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, Map<String, dynamic>> _cache = {};

  Stream<List<(String, Map<String, dynamic>)>> join(
    Stream<QuerySnapshot<Map<String, dynamic>>> source,
  ) {
    return source.asyncMap((snapshot) async {
      final ids = <String>{
        for (final doc in snapshot.docs) ...[
          _id(doc.data()['customerId']),
          _id(doc.data()['workerId']),
        ],
      }..removeWhere((id) => id.isEmpty || _cache.containsKey(id));
      final missing = ids.toList();
      for (var i = 0; i < missing.length; i += 10) {
        final chunk = missing.sublist(i, (i + 10).clamp(0, missing.length));
        try {
          final users = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final user in users.docs) {
            _cache[user.id] = user.data();
          }
        } catch (_) {
          // Show whatever the document itself contains.
        }
      }
      return [
        for (final doc in snapshot.docs) (doc.id, _withNames(doc.data())),
      ];
    });
  }

  Map<String, dynamic> _withNames(Map<String, dynamic> source) {
    final data = Map<String, dynamic>.of(source);
    void fill(String key, Object? value) {
      final current = data[key]?.toString().trim() ?? '';
      final next = value?.toString().trim() ?? '';
      if (current.isEmpty && next.isNotEmpty) data[key] = next;
    }

    final customer = _cache[_id(data['customerId'])];
    if (customer != null) {
      fill('customerName', customer['name']);
      fill('customerEmail', customer['email']);
      fill('customerPhone', customer['phone'] ?? customer['phoneNumber']);
    }
    final worker = _cache[_id(data['workerId'])];
    if (worker != null) {
      fill('workerName', worker['name']);
      fill('workerEmail', worker['email']);
    }
    return data;
  }

  static String _id(Object? value) => value?.toString().trim() ?? '';
}
