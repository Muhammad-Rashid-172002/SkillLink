import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skill_link/screens/customer_screens/chat/chat_models.dart';

import 'worker_chat_models.dart';

const int workerConversationQueryLimit = 80;
const int workerCustomerHydrationChunkSize = 10;
const int workerMessagePageSize = 40;

abstract interface class WorkerChatDataSource {
  String get workerId;
  Stream<List<WorkerConversation>> watchConversations();
  Stream<WorkerChatContext?> watchChat(String chatId);
  Stream<WorkerChatCustomer?> watchCustomer(String customerId);
  Stream<WorkerChatRequest?> watchRequest(String requestId, String customerId);
  Stream<CustomerMessagePage> watchLatestMessages(
    String chatId, {
    int pageSize = workerMessagePageSize,
  });
  Future<CustomerMessagePage> loadOlderMessages(
    String chatId,
    Object cursor, {
    int pageSize = workerMessagePageSize,
  });
  Future<void> markConversationRead(
    String chatId, {
    dynamic observedLastMessageTime,
  });
  Future<void> setTyping(String chatId, bool typing);
  Future<void> sendMessage(
    String chatId, {
    required String customerId,
    required String service,
    required Map<String, dynamic> content,
    Map<String, dynamic>? replyTo,
  });
  Future<void> deleteMessage(String chatId, CustomerChatMessage message);
  Future<void> setReaction(String chatId, String messageId, String? emoji);
  Future<void> setArchived(String chatId, bool archived);
  Future<void> refreshConversations();
}

class WorkerChatAccessException implements Exception {
  const WorkerChatAccessException();
}

class FirebaseWorkerChatRepository implements WorkerChatDataSource {
  FirebaseWorkerChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Map<String, WorkerChatCustomerSummary> _customerCache = {};

  @override
  String get workerId => _auth.currentUser?.uid ?? '';

  Query<Map<String, dynamic>> get _conversationQuery => _firestore
      .collection('chats')
      .where('workerId', isEqualTo: workerId)
      .orderBy('updatedAt', descending: true)
      .limit(workerConversationQueryLimit);

  @override
  Stream<List<WorkerConversation>> watchConversations() {
    if (workerId.isEmpty) return Stream.value(const []);
    return _conversationQuery.snapshots().asyncMap((snapshot) async {
      final customerIds = snapshot.docs
          .map((document) => chatText(document.data(), const ['customerId']))
          .where((id) => id.isNotEmpty)
          .toSet();
      await _hydrateCustomers(customerIds);
      final conversations = snapshot.docs
          .where((document) {
            final data = document.data();
            return chatText(data, const ['workerId']) == workerId &&
                chatText(data, const ['customerId']).isNotEmpty;
          })
          .map((document) {
            final data = document.data();
            final customerId = chatText(data, const ['customerId']);
            return WorkerConversation(
              id: document.id,
              data: data,
              customer: _customerCache[customerId],
            );
          });
      return canonicalWorkerConversations(conversations);
    });
  }

  Future<void> _hydrateCustomers(Set<String> ids) async {
    final missing = ids
        .where((id) => !_customerCache.containsKey(id))
        .toList(growable: false);
    for (
      var offset = 0;
      offset < missing.length;
      offset += workerCustomerHydrationChunkSize
    ) {
      final end = (offset + workerCustomerHydrationChunkSize).clamp(
        0,
        missing.length,
      );
      final chunk = missing.sublist(offset, end);
      if (chunk.isEmpty) continue;
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final document in snapshot.docs) {
        _customerCache[document.id] = WorkerChatCustomerSummary.from(
          document.id,
          document.data(),
        );
      }
    }
  }

  @override
  Stream<WorkerChatContext?> watchChat(String chatId) {
    if (workerId.isEmpty || chatId.isEmpty) return Stream.value(null);
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null ||
          chatText(data, const ['workerId']) != workerId ||
          chatText(data, const ['customerId']).isEmpty) {
        return null;
      }
      return WorkerChatContext(id: doc.id, data: data);
    });
  }

  @override
  Stream<WorkerChatCustomer?> watchCustomer(String customerId) {
    if (customerId.isEmpty) return Stream.value(null);
    return _firestore.collection('users').doc(customerId).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      return data == null ? null : WorkerChatCustomer.from(doc.id, data);
    });
  }

  @override
  Stream<WorkerChatRequest?> watchRequest(String requestId, String customerId) {
    if (requestId.isEmpty) return Stream.value(null);
    return _firestore.collection('requests').doc(requestId).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (data == null ||
          chatText(data, const ['workerId']) != workerId ||
          chatText(data, const ['customerId']) != customerId) {
        return null;
      }
      return WorkerChatRequest(id: doc.id, data: data);
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
    int pageSize = workerMessagePageSize,
  }) {
    return _messageQuery(chatId).limit(pageSize).snapshots().map((snapshot) {
      return CustomerMessagePage(
        messages: snapshot.docs
            .map((doc) => CustomerChatMessage(id: doc.id, data: doc.data()))
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
    int pageSize = workerMessagePageSize,
  }) async {
    if (cursor is! DocumentSnapshot<Map<String, dynamic>>) {
      return const CustomerMessagePage(messages: [], hasMore: false);
    }
    final snapshot = await _messageQuery(
      chatId,
    ).startAfterDocument(cursor).limit(pageSize).get();
    return CustomerMessagePage(
      messages: snapshot.docs
          .map((doc) => CustomerChatMessage(id: doc.id, data: doc.data()))
          .toList(growable: false),
      hasMore: snapshot.docs.length == pageSize,
      cursor: snapshot.docs.isEmpty ? cursor : snapshot.docs.last,
    );
  }

  Future<Map<String, dynamic>> _ownedChat(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> chatRef,
  ) async {
    final snapshot = await transaction.get(chatRef);
    final data = snapshot.data();
    if (workerId.isEmpty ||
        data == null ||
        chatText(data, const ['workerId']) != workerId ||
        chatText(data, const ['customerId']).isEmpty) {
      throw const WorkerChatAccessException();
    }
    final requestId = chatText(data, const ['requestId']);
    if (requestId.isNotEmpty) {
      final request = await transaction.get(
        _firestore.collection('requests').doc(requestId),
      );
      final requestData = request.data();
      if (requestData == null ||
          chatText(requestData, const ['workerId']) != workerId ||
          chatText(requestData, const ['customerId']) !=
              chatText(data, const ['customerId'])) {
        throw const WorkerChatAccessException();
      }
    }
    return data;
  }

  @override
  Future<void> markConversationRead(
    String chatId, {
    dynamic observedLastMessageTime,
  }) async {
    if (workerId.isEmpty) return;
    final chatRef = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((transaction) async {
      await _ownedChat(transaction, chatRef);
    });
    final incoming = await chatRef
        .collection('messages')
        .where('receiverId', isEqualTo: workerId)
        .limit(400)
        .get();
    final unread = incoming.docs
        .where((doc) {
          final data = doc.data();
          return data['isSeen'] != true || data['isRead'] != true;
        })
        .toList(growable: false);
    if (unread.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {
          'status': 'seen',
          'isSeen': true,
          'isRead': true,
          'seenAt': FieldValue.serverTimestamp(),
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    if (incoming.docs.length >= 400) return;
    await _firestore.runTransaction((transaction) async {
      final data = await _ownedChat(transaction, chatRef);
      final current = data['lastMessageTime'] ?? data['updatedAt'];
      if (!_sameTimestamp(current, observedLastMessageTime) &&
          chatText(data, const ['lastSenderId', 'lastMessageSenderId']) !=
              workerId) {
        return;
      }
      transaction.set(chatRef, {
        'workerUnreadCount': 0,
        'unreadCountWorker': 0,
        'unreadWorkerCount': 0,
        'lastMessageSeen': true,
      }, SetOptions(merge: true));
    });
  }

  bool _sameTimestamp(dynamic first, dynamic second) {
    final a = chatDate(first);
    final b = chatDate(second);
    if (a == null || b == null) return a == b;
    return a.microsecondsSinceEpoch == b.microsecondsSinceEpoch;
  }

  @override
  Future<void> setTyping(String chatId, bool typing) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((transaction) async {
      await _ownedChat(transaction, chatRef);
      transaction.update(chatRef, {'typing.$workerId': typing});
    });
  }

  @override
  Future<void> sendMessage(
    String chatId, {
    required String customerId,
    required String service,
    required Map<String, dynamic> content,
    Map<String, dynamic>? replyTo,
  }) async {
    final type = chatText(content, const ['type'], 'text').toLowerCase();
    if (type == 'text' && chatText(content, const ['text']).trim().isEmpty) {
      return;
    }
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    await _firestore.runTransaction((transaction) async {
      final chat = await _ownedChat(transaction, chatRef);
      final actualCustomer = chatText(chat, const ['customerId']);
      if (actualCustomer != customerId) throw const WorkerChatAccessException();
      final preview = switch (type) {
        'image' => 'Photo',
        'audio' || 'voice' => 'Voice message',
        _ => chatText(content, const ['text']),
      };
      transaction.set(messageRef, {
        'senderId': workerId,
        'receiverId': actualCustomer,
        ...content,
        'replyTo': replyTo,
        'reactions': <String, dynamic>{},
        'status': 'sent',
        'isSeen': false,
        'isRead': false,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(chatRef, {
        'participants': [actualCustomer, workerId],
        'customerId': actualCustomer,
        'workerId': workerId,
        'service': service,
        'lastMessage': preview,
        'lastMessageType': type,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSenderId': workerId,
        'lastMessageSeen': false,
        'customerUnreadCount': FieldValue.increment(1),
        'unreadCountCustomer': FieldValue.increment(1),
        'workerUnreadCount': 0,
        'unreadCountWorker': 0,
        'unreadWorkerCount': 0,
        'archivedByCustomer': false,
        'archivedByWorker': false,
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> deleteMessage(String chatId, CustomerChatMessage message) async {
    if (message.senderId != workerId) return;
    final chatRef = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((transaction) async {
      await _ownedChat(transaction, chatRef);
      transaction.update(chatRef.collection('messages').doc(message.id), {
        'isDeleted': true,
        'text': '',
        'imageUrl': FieldValue.delete(),
        'audioUrl': FieldValue.delete(),
        'reactions': <String, dynamic>{},
        'deletedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> setReaction(
    String chatId,
    String messageId,
    String? emoji,
  ) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((transaction) async {
      await _ownedChat(transaction, chatRef);
      final messageRef = chatRef.collection('messages').doc(messageId);
      if (emoji == null) {
        transaction.update(messageRef, {
          'reactions.$workerId': FieldValue.delete(),
        });
      } else {
        transaction.set(messageRef, {
          'reactions': {workerId: emoji},
        }, SetOptions(merge: true));
      }
    });
  }

  @override
  Future<void> setArchived(String chatId, bool archived) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    await _firestore.runTransaction((transaction) async {
      await _ownedChat(transaction, chatRef);
      transaction.set(chatRef, {
        'archivedByWorker': archived,
        'archivedAtWorker': archived ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> refreshConversations() async {
    _customerCache.clear();
    if (workerId.isNotEmpty) await _conversationQuery.get();
  }
}
