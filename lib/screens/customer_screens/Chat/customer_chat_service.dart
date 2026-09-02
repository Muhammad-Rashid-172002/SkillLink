import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_detail_screen.dart';
import 'chat_models.dart';

class CustomerChatDestination {
  const CustomerChatDestination({
    required this.chatId,
    required this.workerId,
    required this.workerName,
    required this.workerSkill,
    required this.workerPhone,
    required this.workerImageUrl,
    required this.workerVerified,
    required this.requestId,
  });

  final String chatId;
  final String workerId;
  final String workerName;
  final String workerSkill;
  final String workerPhone;
  final String workerImageUrl;
  final bool workerVerified;
  final String requestId;
}

/// Resolves every customer chat entry point through one compatibility path.
/// Historical random chat IDs remain valid; only newly-created conversations
/// receive deterministic IDs to prevent concurrent duplicate creation.
class CustomerChatService {
  CustomerChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get customerId => _auth.currentUser?.uid ?? '';

  Future<CustomerChatDestination?> loadExisting(String chatId) async {
    final uid = customerId;
    if (uid.isEmpty || chatId.trim().isEmpty) return null;
    final snapshot = await _firestore.collection('chats').doc(chatId).get();
    final data = snapshot.data();
    if (data == null || chatText(data, const ['customerId']) != uid) {
      return null;
    }
    return _destination(snapshot.id, data);
  }

  Future<CustomerChatDestination> resolveDirect({
    required String workerId,
    String workerName = 'Professional',
    String workerSkill = 'Professional service',
    String workerPhone = '',
    String workerImageUrl = '',
    bool workerVerified = false,
  }) async {
    final uid = customerId;
    if (uid.isEmpty) throw StateError('A signed-in customer is required.');
    if (workerId.trim().isEmpty) {
      throw StateError('A valid worker is required.');
    }

    final historical = await _firestore
        .collection('chats')
        .where('customerId', isEqualTo: uid)
        .limit(80)
        .get();
    final matching = historical.docs.where((document) {
      final data = document.data();
      return chatText(data, const ['workerId']) == workerId &&
          chatText(data, const ['requestId']).isEmpty;
    }).toList();
    if (matching.isNotEmpty) {
      matching.sort((a, b) {
        final first = chatDate(
          a.data()['lastMessageTime'] ?? a.data()['updatedAt'],
        );
        final second = chatDate(
          b.data()['lastMessageTime'] ?? b.data()['updatedAt'],
        );
        return (second ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          first ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      });
      return _destination(matching.first.id, matching.first.data());
    }

    final reference = _firestore
        .collection('chats')
        .doc('direct_${uid}_$workerId');
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) return;
      transaction.set(reference, {
        'participants': [uid, workerId],
        'customerId': uid,
        'workerId': workerId,
        'workerName': workerName,
        'workerSkill': workerSkill,
        'workerImageUrl': workerImageUrl,
        'service': workerSkill,
        'lastMessage': '',
        'customerUnreadCount': 0,
        'unreadCountCustomer': 0,
        'workerUnreadCount': 0,
        'unreadCountWorker': 0,
        'archivedByCustomer': false,
        'archivedByWorker': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return CustomerChatDestination(
      chatId: reference.id,
      workerId: workerId,
      workerName: workerName,
      workerSkill: workerSkill,
      workerPhone: workerPhone,
      workerImageUrl: workerImageUrl,
      workerVerified: workerVerified,
      requestId: '',
    );
  }

  Future<CustomerChatDestination> resolveBooking({
    required String requestId,
    required String workerId,
    required String service,
    String existingChatId = '',
    String workerName = 'Professional',
    String workerPhone = '',
    String workerImageUrl = '',
    bool workerVerified = false,
  }) async {
    final uid = customerId;
    if (uid.isEmpty) throw StateError('A signed-in customer is required.');
    if (requestId.isEmpty || workerId.isEmpty) {
      throw StateError('A valid booking and worker are required.');
    }

    if (existingChatId.isNotEmpty) {
      final existing = await loadExisting(existingChatId);
      if (existing != null &&
          existing.workerId == workerId &&
          (existing.requestId.isEmpty || existing.requestId == requestId)) {
        return existing;
      }
    }

    final historical = await _firestore
        .collection('chats')
        .where('requestId', isEqualTo: requestId)
        .limit(10)
        .get();
    for (final document in historical.docs) {
      final data = document.data();
      if (chatText(data, const ['customerId']) == uid &&
          chatText(data, const ['workerId']) == workerId) {
        await _linkRequest(requestId, document.id, workerId);
        return _destination(document.id, data);
      }
    }

    final reference = _firestore.collection('chats').doc('request_$requestId');
    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(reference);
      if (!chatSnapshot.exists) {
        transaction.set(reference, {
          'participants': [uid, workerId],
          'customerId': uid,
          'workerId': workerId,
          'workerName': workerName,
          'workerSkill': service,
          'workerImageUrl': workerImageUrl,
          'requestId': requestId,
          'service': service,
          'lastMessage': '',
          'customerUnreadCount': 0,
          'unreadCountCustomer': 0,
          'workerUnreadCount': 0,
          'unreadCountWorker': 0,
          'archivedByCustomer': false,
          'archivedByWorker': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    await _linkRequest(requestId, reference.id, workerId);
    return CustomerChatDestination(
      chatId: reference.id,
      workerId: workerId,
      workerName: workerName,
      workerSkill: service,
      workerPhone: workerPhone,
      workerImageUrl: workerImageUrl,
      workerVerified: workerVerified,
      requestId: requestId,
    );
  }

  Future<void> _linkRequest(
    String requestId,
    String chatId,
    String workerId,
  ) async {
    final request = _firestore.collection('requests').doc(requestId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(request);
      final data = snapshot.data();
      if (data == null ||
          chatText(data, const ['customerId']) != customerId ||
          chatText(data, const ['workerId']) != workerId) {
        return;
      }
      transaction.update(request, {
        'chatId': chatId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<CustomerChatDestination> _destination(
    String chatId,
    Map<String, dynamic> chat,
  ) async {
    final workerId = chatText(chat, const ['workerId']);
    final workerSnapshot = workerId.isEmpty
        ? null
        : await _firestore.collection('users').doc(workerId).get();
    final worker = workerSnapshot?.data();
    final profile = worker == null
        ? null
        : CustomerChatWorker(id: workerId, data: worker);
    return CustomerChatDestination(
      chatId: chatId,
      workerId: workerId,
      workerName:
          profile?.name ?? chatText(chat, const ['workerName'], 'Professional'),
      workerSkill: chatText(chat, const [
        'service',
        'workerSkill',
        'category',
      ], profile?.skill ?? 'Professional service'),
      workerPhone: profile?.phone ?? '',
      workerImageUrl:
          profile?.photoUrl ?? chatText(chat, const ['workerImageUrl']),
      workerVerified: profile?.verified ?? false,
      requestId: chatText(chat, const ['requestId']),
    );
  }
}

abstract final class CustomerChatNavigator {
  static Future<void> open(
    BuildContext context,
    CustomerChatDestination destination,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(
          chatId: destination.chatId,
          workerId: destination.workerId,
          workerName: destination.workerName,
          workerSkill: destination.workerSkill,
          workerPhone: destination.workerPhone,
          workerImageUrl: destination.workerImageUrl,
          workerVerified: destination.workerVerified,
          requestId: destination.requestId,
        ),
      ),
    );
  }
}
