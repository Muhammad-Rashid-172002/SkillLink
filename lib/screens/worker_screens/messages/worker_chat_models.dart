import 'package:skill_link/screens/customer_screens/chat/chat_models.dart';

class WorkerChatCustomerSummary {
  const WorkerChatCustomerSummary({
    required this.id,
    required this.name,
    required this.photoUrl,
  });

  final String id;
  final String name;
  final String photoUrl;

  factory WorkerChatCustomerSummary.from(String id, Map<String, dynamic> data) {
    return WorkerChatCustomerSummary(
      id: id,
      name: chatText(data, const [
        'name',
        'displayName',
        'fullName',
      ], 'Customer'),
      photoUrl: chatText(data, const [
        'profileImage',
        'profileImageUrl',
        'photoUrl',
        'imageUrl',
      ]),
    );
  }
}

class WorkerChatCustomer {
  const WorkerChatCustomer({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.phone,
  });

  final String id;
  final String name;
  final String photoUrl;
  final String phone;

  factory WorkerChatCustomer.from(String id, Map<String, dynamic> data) {
    final summary = WorkerChatCustomerSummary.from(id, data);
    return WorkerChatCustomer(
      id: id,
      name: summary.name,
      photoUrl: summary.photoUrl,
      phone: chatText(data, const ['phone', 'phoneNumber']),
    );
  }
}

class WorkerConversation {
  const WorkerConversation({
    required this.id,
    required this.data,
    this.customer,
  });

  final String id;
  final Map<String, dynamic> data;
  final WorkerChatCustomerSummary? customer;

  String get workerId => chatText(data, const ['workerId']);
  String get customerId => chatText(data, const ['customerId']);
  String get requestId => chatText(data, const ['requestId']);
  String get identity => requestId.isEmpty ? 'chat:$id' : 'request:$requestId';
  String get customerName =>
      customer?.name ?? chatText(data, const ['customerName'], 'Customer');
  String get customerPhoto =>
      customer?.photoUrl ??
      chatText(data, const ['customerImageUrl', 'customerImage']);
  String get service => chatText(data, const [
    'service',
    'category',
    'workerSkill',
  ], 'Service conversation');
  bool get archived => data['archivedByWorker'] == true;
  String get lastMessageType =>
      chatText(data, const ['lastMessageType'], 'text').toLowerCase();
  String get lastSenderId =>
      chatText(data, const ['lastSenderId', 'lastMessageSenderId']);
  DateTime? get updatedAt => chatDate(
    data['lastMessageTime'] ?? data['updatedAt'] ?? data['createdAt'],
  );

  int get unreadCount {
    final values = [
      chatInt(data['workerUnreadCount']),
      chatInt(data['unreadCountWorker']),
      chatInt(data['unreadWorkerCount']),
    ];
    return values.reduce((first, second) => first > second ? first : second);
  }

  String get latestPreview => switch (lastMessageType) {
    'image' => 'Photo',
    'audio' || 'voice' => 'Voice message',
    'deleted' => 'Message deleted',
    _ => chatText(data, const ['lastMessage'], 'Start a conversation'),
  };

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$customerName $service $latestPreview'.toLowerCase().contains(
      normalized,
    );
  }
}

/// Request chats use the request ID as identity, while direct chats retain their
/// document identity. This removes historical duplicate chats for one request
/// without collapsing separate jobs belonging to the same customer.
List<WorkerConversation> canonicalWorkerConversations(
  Iterable<WorkerConversation> conversations,
) {
  final byIdentity = <String, WorkerConversation>{};
  for (final conversation in conversations) {
    final existing = byIdentity[conversation.identity];
    final currentDate = conversation.updatedAt ?? DateTime(1970);
    final existingDate = existing?.updatedAt ?? DateTime(1970);
    if (existing == null || currentDate.isAfter(existingDate)) {
      byIdentity[conversation.identity] = conversation;
    }
  }
  return byIdentity.values.toList()..sort((first, second) {
    final a = first.updatedAt ?? DateTime(1970);
    final b = second.updatedAt ?? DateTime(1970);
    final compared = b.compareTo(a);
    return compared == 0 ? first.id.compareTo(second.id) : compared;
  });
}

class WorkerChatContext {
  const WorkerChatContext({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get workerId => chatText(data, const ['workerId']);
  String get customerId => chatText(data, const ['customerId']);
  String get requestId => chatText(data, const ['requestId']);
  String get service => chatText(data, const [
    'service',
    'category',
    'workerSkill',
  ], 'Professional service');
  bool get archived => data['archivedByWorker'] == true;
  bool get customerTyping {
    final typing = data['typing'];
    return typing is Map && typing[customerId] == true;
  }

  dynamic get lastMessageTime => data['lastMessageTime'] ?? data['updatedAt'];
}

class WorkerChatRequest {
  const WorkerChatRequest({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get workerId => chatText(data, const ['workerId']);
  String get customerId => chatText(data, const ['customerId']);
  String get status => chatText(data, const ['status']).toLowerCase();
  String get service =>
      chatText(data, const ['category', 'service', 'title'], 'Service job');
  String get budget => chatText(data, const ['budget']);
}
