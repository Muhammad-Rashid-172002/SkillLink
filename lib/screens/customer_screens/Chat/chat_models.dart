import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? chatDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String chatText(
  Map<String, dynamic>? data,
  List<String> keys, [
  String fallback = '',
]) {
  if (data == null) return fallback;
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return fallback;
}

int chatInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class CustomerChatWorker {
  const CustomerChatWorker({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get name => chatText(data, const ['name', 'fullName'], 'Professional');
  String get skill => chatText(data, const [
    'skill',
    'service',
    'category',
  ], 'Professional service');
  String get phone => chatText(data, const ['phone', 'phoneNumber']);
  String get photoUrl => chatText(data, const [
    'profileImage',
    'profileImageUrl',
    'photoUrl',
    'imageUrl',
  ]);

  /// This matches the strong public-worker verification used by Explore V2.
  bool get verified =>
      data['role'] == 'worker' &&
      data['identityVerificationStatus'] == 'approved';
}

class CustomerConversation {
  const CustomerConversation({
    required this.id,
    required this.data,
    required this.worker,
  });

  final String id;
  final Map<String, dynamic> data;
  final CustomerChatWorker? worker;

  String get customerId => chatText(data, const ['customerId']);
  String get workerId => chatText(data, const ['workerId']);
  String get requestId => chatText(data, const ['requestId']);
  String get workerName =>
      worker?.name ?? chatText(data, const ['workerName'], 'Professional');
  String get service => chatText(data, const [
    'service',
    'category',
    'workerSkill',
  ], worker?.skill ?? 'Professional service');
  String get workerPhoto =>
      worker?.photoUrl ??
      chatText(data, const ['workerImageUrl', 'workerImage']);
  String get workerPhone => worker?.phone ?? '';
  bool get workerVerified => worker?.verified ?? false;
  bool get archived => data['archivedByCustomer'] == true;
  String get lastSenderId =>
      chatText(data, const ['lastSenderId', 'lastMessageSenderId']);
  String get lastMessageType =>
      chatText(data, const ['lastMessageType'], 'text').toLowerCase();
  DateTime? get updatedAt => chatDate(
    data['lastMessageTime'] ?? data['updatedAt'] ?? data['createdAt'],
  );

  /// Historical documents use either alias, and some contain both. Taking the
  /// maximum avoids hiding unread messages when one alias is stale at zero.
  int get unreadCount {
    final primary = chatInt(data['customerUnreadCount']);
    final legacy = chatInt(data['unreadCountCustomer']);
    return primary > legacy ? primary : legacy;
  }

  String get latestPreview {
    switch (lastMessageType) {
      case 'image':
        return 'Photo';
      case 'audio':
      case 'voice':
        return 'Voice message';
      case 'deleted':
        return 'Message deleted';
      default:
        return chatText(data, const ['lastMessage'], 'Start a conversation');
    }
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$workerName $service $latestPreview'.toLowerCase().contains(
      normalized,
    );
  }
}

enum CustomerMessageStatus { sending, sent, delivered, seen }

class CustomerChatMessage {
  const CustomerChatMessage({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get senderId => chatText(data, const ['senderId']);
  String get receiverId => chatText(data, const ['receiverId']);
  String get type => chatText(data, const ['type'], 'text').toLowerCase();
  String get text => chatText(data, const ['text']);
  String get imageUrl => chatText(data, const ['imageUrl']);
  String get audioUrl => chatText(data, const ['audioUrl']);
  DateTime? get createdAt => chatDate(data['createdAt']);
  bool get isDeleted => data['isDeleted'] == true;
  Map<String, dynamic>? get replyTo {
    final value = data['replyTo'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Map<String, dynamic> get reactions {
    final value = data['reactions'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  CustomerMessageStatus get status {
    if (data['isSeen'] == true || data['isRead'] == true) {
      return CustomerMessageStatus.seen;
    }
    switch (chatText(data, const ['status']).toLowerCase()) {
      case 'seen':
      case 'read':
        return CustomerMessageStatus.seen;
      case 'delivered':
        return CustomerMessageStatus.delivered;
      case 'sent':
        return CustomerMessageStatus.sent;
      default:
        return createdAt == null
            ? CustomerMessageStatus.sending
            : CustomerMessageStatus.sent;
    }
  }

  String get replyPreview {
    if (isDeleted) return 'Message deleted';
    switch (type) {
      case 'image':
        return 'Photo';
      case 'audio':
      case 'voice':
        return 'Voice message';
      default:
        return text;
    }
  }
}

class CustomerMessagePage {
  const CustomerMessagePage({
    required this.messages,
    required this.hasMore,
    this.cursor,
  });

  final List<CustomerChatMessage> messages;
  final bool hasMore;
  final Object? cursor;
}

class CustomerChatContext {
  const CustomerChatContext({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get customerId => chatText(data, const ['customerId']);
  String get workerId => chatText(data, const ['workerId']);
  String get requestId => chatText(data, const ['requestId']);
  String get service => chatText(data, const [
    'service',
    'category',
    'workerSkill',
  ], 'Professional service');
  bool get workerTyping {
    final typing = data['typing'];
    return typing is Map && typing[workerId] == true;
  }

  dynamic get lastMessageTime => data['lastMessageTime'] ?? data['updatedAt'];
}

List<CustomerChatMessage> mergeCustomerMessages(
  Iterable<CustomerChatMessage> older,
  Iterable<CustomerChatMessage> latest,
) {
  final byId = <String, CustomerChatMessage>{};
  for (final message in older) {
    byId[message.id] = message;
  }
  for (final message in latest) {
    byId[message.id] = message;
  }
  return byId.values.toList()..sort((a, b) {
    final first = a.createdAt ?? DateTime.now();
    final second = b.createdAt ?? DateTime.now();
    final compared = first.compareTo(second);
    return compared == 0 ? a.id.compareTo(b.id) : compared;
  });
}
