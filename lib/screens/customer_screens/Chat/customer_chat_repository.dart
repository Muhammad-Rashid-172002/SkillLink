import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_models.dart';

abstract interface class CustomerChatDataSource {
  String get customerId;

  Stream<List<CustomerConversation>> watchConversations();
  Stream<CustomerChatContext?> watchChat(String chatId);
  Stream<CustomerChatWorker?> watchWorker(String workerId);
  Stream<Map<String, dynamic>?> watchBooking(String requestId);
  Stream<CustomerMessagePage> watchLatestMessages(
    String chatId, {
    int pageSize = 40,
  });
  Future<CustomerMessagePage> loadOlderMessages(
    String chatId,
    Object cursor, {
    int pageSize = 40,
  });
  Future<void> markConversationRead(
    String chatId, {
    dynamic observedLastMessageTime,
  });
  Future<void> setTyping(String chatId, bool typing);
  Future<void> sendMessage(
    String chatId, {
    required String workerId,
    required String service,
    required Map<String, dynamic> content,
    Map<String, dynamic>? replyTo,
  });
  Future<void> deleteMessage(String chatId, CustomerChatMessage message);
  Future<void> setReaction(String chatId, String messageId, String? emoji);
  Future<void> setArchived(String chatId, bool archived);
  Future<void> refreshConversations();
}

class FirebaseCustomerChatRepository implements CustomerChatDataSource {
  FirebaseCustomerChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Map<String, Map<String, dynamic>> _workerCache = {};

  @override
  String get customerId => _auth.currentUser?.uid ?? '';

  Query<Map<String, dynamic>> get _conversationQuery => _firestore
      .collection('chats')
      .where('customerId', isEqualTo: customerId)
      .orderBy('updatedAt', descending: true)
      .limit(80);

  @override
  Stream<List<CustomerConversation>> watchConversations() {
    return _conversationQuery.snapshots().asyncMap((snapshot) async {
      final workerIds = snapshot.docs
          .map((document) => chatText(document.data(), const ['workerId']))
          .where((id) => id.isNotEmpty)
          .toSet();
      await _hydrateWorkers(workerIds);
      final conversations = snapshot.docs
          .where((document) {
            final data = document.data();
            return chatText(data, const ['customerId']) == customerId &&
                chatText(data, const ['workerId']).isNotEmpty;
          })
          .map((document) {
            final data = document.data();
            final workerId = chatText(data, const ['workerId']);
            final workerData = _workerCache[workerId];
            return CustomerConversation(
              id: document.id,
              data: data,
              worker: workerData == null
                  ? null
                  : CustomerChatWorker(id: workerId, data: workerData),
            );
          })
          .toList(growable: false);
      conversations.sort((a, b) {
        final first = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final second = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return second.compareTo(first);
      });
      return conversations;
    });
  }

  Future<void> _hydrateWorkers(Set<String> ids) async {
    final missing = ids.where((id) => !_workerCache.containsKey(id)).toList();
    for (var offset = 0; offset < missing.length; offset += 30) {
      final end = (offset + 30).clamp(0, missing.length);
      final chunk = missing.sublist(offset, end);
      if (chunk.isEmpty) continue;
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final document in snapshot.docs) {
        _workerCache[document.id] = document.data();
      }
    }
  }

  @override
  Stream<CustomerChatContext?> watchChat(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null || chatText(data, const ['customerId']) != customerId) {
        return null;
      }
      return CustomerChatContext(id: snapshot.id, data: data);
    });
  }

  @override
  Stream<CustomerChatWorker?> watchWorker(String workerId) {
    if (workerId.isEmpty) return Stream.value(null);
    return _firestore.collection('users').doc(workerId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      return data == null
          ? null
          : CustomerChatWorker(id: snapshot.id, data: data);
    });
  }

  @override
  Stream<Map<String, dynamic>?> watchBooking(String requestId) {
    if (requestId.isEmpty) return Stream.value(null);
    return _firestore.collection('requests').doc(requestId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null || chatText(data, const ['customerId']) != customerId) {
        return null;
      }
      return data;
    });
  }

  Query<Map<String, dynamic>> _messageQuery(String chatId) => _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true);

  @override
  Stream<CustomerMessagePage> watchLatestMessages(
    String chatId, {
    int pageSize = 40,
  }) {
    return _messageQuery(chatId).limit(pageSize).snapshots().map((snapshot) {
      return CustomerMessagePage(
        messages: snapshot.docs
            .map(
              (document) =>
                  CustomerChatMessage(id: document.id, data: document.data()),
            )
            .toList(growable: false),
        hasMore: snapshot.docs.length == pageSize,
        cursor: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      );
    });
  }

  @override
  Future<CustomerMessagePage> loadOlderMessages(
    String chatId,
    Object cursor, {
    int pageSize = 40,
  }) async {
    if (cursor is! DocumentSnapshot<Map<String, dynamic>>) {
      return const CustomerMessagePage(messages: [], hasMore: false);
    }
    final snapshot = await _messageQuery(
      chatId,
    ).startAfterDocument(cursor).limit(pageSize).get();
    return CustomerMessagePage(
      messages: snapshot.docs
          .map(
            (document) =>
                CustomerChatMessage(id: document.id, data: document.data()),
          )
          .toList(growable: false),
      hasMore: snapshot.docs.length == pageSize,
      cursor: snapshot.docs.isEmpty ? cursor : snapshot.docs.last,
    );
  }

  @override
  Future<void> markConversationRead(
    String chatId, {
    dynamic observedLastMessageTime,
  }) async {
    if (customerId.isEmpty) return;
    final chatRef = _firestore.collection('chats').doc(chatId);
    final incoming = await chatRef
        .collection('messages')
        .where('receiverId', isEqualTo: customerId)
        .limit(400)
        .get();
    final unread = incoming.docs.where((document) {
      final data = document.data();
      return data['isSeen'] != true || data['isRead'] != true;
    }).toList();
    if (unread.isNotEmpty) {
      final batch = _firestore.batch();
      for (final document in unread) {
        batch.update(document.reference, {
          'status': 'seen',
          'isSeen': true,
          'isRead': true,
          'seenAt': FieldValue.serverTimestamp(),
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    // Do not claim the entire conversation is read if the bounded safety query
    // could not inspect all incoming messages.
    if (incoming.docs.length >= 400) return;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);
      final data = snapshot.data();
      if (data == null || chatText(data, const ['customerId']) != customerId) {
        return;
      }
      final current = data['lastMessageTime'] ?? data['updatedAt'];
      if (!_sameTimestamp(current, observedLastMessageTime) &&
          chatText(data, const ['lastSenderId', 'lastMessageSenderId']) !=
              customerId) {
        return;
      }
      transaction.set(chatRef, {
        'customerUnreadCount': 0,
        'unreadCountCustomer': 0,
        'lastMessageSeen': true,
      }, SetOptions(merge: true));
    });
  }

  bool _sameTimestamp(dynamic a, dynamic b) {
    final first = chatDate(a);
    final second = chatDate(b);
    if (first == null || second == null) return first == second;
    return first.microsecondsSinceEpoch == second.microsecondsSinceEpoch;
  }

  @override
  Future<void> setTyping(String chatId, bool typing) async {
    if (customerId.isEmpty) return;
    await _firestore.collection('chats').doc(chatId).update({
      'typing.$customerId': typing,
    });
  }

  @override
  Future<void> sendMessage(
    String chatId, {
    required String workerId,
    required String service,
    required Map<String, dynamic> content,
    Map<String, dynamic>? replyTo,
  }) async {
    if (customerId.isEmpty || workerId.isEmpty) return;
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final type = chatText(content, const ['type'], 'text');
    final preview = switch (type) {
      'image' => 'Photo',
      'audio' || 'voice' => 'Voice message',
      _ => chatText(content, const ['text']),
    };
    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderId': customerId,
      'receiverId': workerId,
      ...content,
      'replyTo': replyTo,
      'reactions': <String, dynamic>{},
      'status': 'sent',
      'isSeen': false,
      'isRead': false,
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(chatRef, {
      'participants': [customerId, workerId],
      'customerId': customerId,
      'workerId': workerId,
      'service': service,
      'lastMessage': preview,
      'lastMessageType': type,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSenderId': customerId,
      'lastMessageSeen': false,
      'workerUnreadCount': FieldValue.increment(1),
      'unreadCountWorker': FieldValue.increment(1),
      'customerUnreadCount': 0,
      'unreadCountCustomer': 0,
      'archivedByCustomer': false,
      'archivedByWorker': false,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> deleteMessage(String chatId, CustomerChatMessage message) async {
    if (message.senderId != customerId) return;
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id)
        .update({
          'isDeleted': true,
          'text': '',
          'imageUrl': FieldValue.delete(),
          'audioUrl': FieldValue.delete(),
          'reactions': <String, dynamic>{},
          'deletedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> setReaction(
    String chatId,
    String messageId,
    String? emoji,
  ) async {
    final reference = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    if (emoji == null) {
      await reference.update({'reactions.$customerId': FieldValue.delete()});
    } else {
      await reference.set({
        'reactions': {customerId: emoji},
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<void> setArchived(String chatId, bool archived) async {
    await _firestore.collection('chats').doc(chatId).set({
      'archivedByCustomer': archived,
      'archivedAtCustomer': archived ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> refreshConversations() async {
    _workerCache.clear();
    await _conversationQuery.get();
  }
}
