import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_components.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_models.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_screen.dart';
import 'package:skill_link/screens/customer_screens/Chat/customer_chat_repository.dart';

void main() {
  test(
    'chat compatibility adapters normalize unread, previews, and states',
    () {
      final conversation = _conversation(
        'aliases',
        primaryUnread: 0,
        legacyUnread: 4,
        type: 'audio',
      );
      expect(conversation.unreadCount, 4);
      expect(conversation.latestPreview, 'Voice message');
      expect(
        CustomerChatMessage(
          id: 'seen',
          data: const {'isRead': true, 'status': 'sent'},
        ).status,
        CustomerMessageStatus.seen,
      );
      expect(
        CustomerChatMessage(
          id: 'delivered',
          data: const {'status': 'delivered'},
        ).status,
        CustomerMessageStatus.delivered,
      );
    },
  );

  test('message pages merge in order without duplicates', () {
    final latest = [
      _message('m3', 'third', 3),
      _message('m2', 'updated second', 2),
    ];
    final older = [_message('m2', 'second', 2), _message('m1', 'first', 1)];
    final merged = mergeCustomerMessages(older, latest);
    expect(merged.map((item) => item.id), ['m1', 'm2', 'm3']);
    expect(merged[1].text, 'updated second');
  });

  testWidgets('messages list shows empty state at 320px', (tester) async {
    _setSize(tester, const Size(320, 720));
    await tester.pumpWidget(
      _app(CustomerChatsScreen(dataSource: _FakeChatSource())),
    );
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
    expect(
      find.text('Your conversations with professionals will appear here.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'messages list renders ordered read/unread, photos, attachment previews and long names',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      final source = _FakeChatSource(
        conversations: [
          _conversation(
            'old',
            name: 'A very long professional name that must truncate gracefully',
            type: 'text',
            message: 'I can help tomorrow',
            minute: 1,
          ),
          _conversation(
            'voice',
            name: 'Sara Malik',
            type: 'audio',
            primaryUnread: 2,
            photo: 'https://example.com/sara.jpg',
            minute: 3,
          ),
          _conversation('photo', name: 'Ahmed Khan', type: 'image', minute: 2),
        ],
      );
      await tester.pumpWidget(_app(CustomerChatsScreen(dataSource: source)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('conversation-voice')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('conversation-photo-voice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('conversation-photo-fallback-photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('conversation-unread-voice')),
        findsOneWidget,
      );
      expect(find.text('Voice message'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('I can help tomorrow'), findsOneWidget);
      final voiceTop = tester
          .getTopLeft(find.byKey(const ValueKey('conversation-voice')))
          .dy;
      final photoTop = tester
          .getTopLeft(find.byKey(const ValueKey('conversation-photo')))
          .dy;
      expect(voiceTop, lessThan(photoTop));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('conversation search is local and supports result/no result', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeChatSource(
      conversations: [
        _conversation('one', name: 'Ahmed Khan', service: 'AC Repair'),
        _conversation('two', name: 'Sara Malik', service: 'Plumbing'),
      ],
    );
    await tester.pumpWidget(_app(CustomerChatsScreen(dataSource: source)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversation-search')),
      'plumbing',
    );
    await tester.pump();
    expect(find.text('Sara Malik'), findsOneWidget);
    expect(find.text('Ahmed Khan'), findsNothing);
    expect(source.searchReads, 0);

    await tester.enterText(
      find.byKey(const ValueKey('conversation-search')),
      'gardener',
    );
    await tester.pump();
    expect(find.text('No matching conversations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('messages list has a polished Firestore error state', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 720));
    await tester.pumpWidget(
      _app(CustomerChatsScreen(dataSource: _FakeChatSource(error: true))),
    );
    await tester.pump();
    expect(find.text('Messages could not be loaded'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('messages list follows dark theme at narrow width', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 720));
    await tester.pumpWidget(
      _app(
        CustomerChatsScreen(
          dataSource: _FakeChatSource(conversations: [_conversation('one')]),
        ),
        mode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Messages'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chat detail shows booking, verified header, typing and composer',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      final source = _FakeChatSource(
        context: _context(typing: true, requestId: 'request-1'),
        worker: _worker(),
        booking: const {'status': 'on_the_way', 'category': 'AC Repair'},
        messages: [_message('hello', 'On my way', 1, sender: 'worker-1')],
      );
      var viewed = false;
      await tester.pumpWidget(
        _app(
          ChatDetailScreen(
            chatId: 'chat-1',
            workerId: 'worker-1',
            workerName: 'Fallback name',
            workerSkill: 'Fallback skill',
            dataSource: source,
            onViewProfile: () {},
            onCall: () {},
            onViewBooking: (_, _) => viewed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.text('Professional on the way'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-typing-indicator')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('chat-composer-field')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-booking-context')));
      expect(viewed, isTrue);
      expect(source.markReadCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty direct chat omits booking context and supports keyboard send',
    (tester) async {
      _setSize(tester, const Size(320, 720));
      final source = _FakeChatSource(
        context: _context(),
        worker: _worker(),
        messages: [],
      );
      await tester.pumpWidget(
        _app(
          ChatDetailScreen(
            chatId: 'chat-1',
            workerId: 'worker-1',
            workerName: 'Ahmed Khan',
            workerSkill: 'AC Repair',
            dataSource: source,
            onViewProfile: () {},
            onCall: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start the conversation'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-booking-context')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('chat-composer-field')),
        'Hello there',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-send')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pump();
      expect(source.sentContents.single['text'], 'Hello there');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'message bubbles cover text, image, voice, reply, reaction and delete',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      final messages = [
        _message(
          'incoming',
          'A long incoming message\nthat wraps onto another line',
          1,
          sender: 'worker-1',
        ),
        CustomerChatMessage(
          id: 'reply',
          data: {
            'senderId': 'customer-1',
            'text': 'Reply response',
            'type': 'text',
            'createdAt': DateTime(2026, 9, 2, 10, 2),
            'status': 'seen',
            'replyTo': const {'senderId': 'worker-1', 'text': 'Quoted message'},
            'reactions': const {'worker-1': '👍'},
          },
        ),
        CustomerChatMessage(
          id: 'image',
          data: {
            'senderId': 'worker-1',
            'type': 'image',
            'imageUrl': 'safe-url',
            'createdAt': DateTime(2026, 9, 2, 10, 3),
          },
        ),
        CustomerChatMessage(
          id: 'audio',
          data: {
            'senderId': 'worker-1',
            'type': 'audio',
            'audioUrl': 'safe-audio',
            'createdAt': DateTime(2026, 9, 2, 10, 4),
          },
        ),
        CustomerChatMessage(
          id: 'deleted',
          data: {
            'senderId': 'customer-1',
            'type': 'text',
            'isDeleted': true,
            'createdAt': DateTime(2026, 9, 2, 10, 5),
          },
        ),
      ];
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: messages
                    .map(
                      (message) => MessageBubble(
                        message: message,
                        currentUserId: 'customer-1',
                        workerName: 'Ahmed Khan',
                        onReply: () {},
                        onLongPress: () {},
                        imageBuilder: (_) => const SizedBox(
                          key: ValueKey('test-image'),
                          width: 200,
                          height: 120,
                        ),
                        audioBuilder: (_, _) => const SizedBox(
                          key: ValueKey('test-audio'),
                          width: 220,
                          height: 48,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('A long incoming message'), findsOneWidget);
      expect(find.text('Quoted message'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      expect(find.byKey(const ValueKey('test-image')), findsOneWidget);
      expect(find.byKey(const ValueKey('test-audio')), findsOneWidget);
      expect(find.text('Message deleted'), findsOneWidget);
      expect(find.byTooltip('Seen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat loads an older page when customer scrolls upward', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final latest = List.generate(
      40,
      (index) => _message('m$index', 'Message $index', index + 10),
    );
    final source = _FakeChatSource(
      context: _context(),
      worker: _worker(),
      messages: latest,
      hasMore: true,
      olderMessages: [_message('old', 'Oldest loaded message', 1)],
    );
    await tester.pumpWidget(
      _app(
        ChatDetailScreen(
          chatId: 'chat-1',
          workerId: 'worker-1',
          workerName: 'Ahmed Khan',
          workerSkill: 'AC Repair',
          dataSource: source,
          onViewProfile: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('chat-message-list')),
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(source.loadOlderCalls, 1);
    scrollable.position.jumpTo(0);
    await tester.pump();
    expect(find.text('Oldest loaded message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

CustomerConversation _conversation(
  String id, {
  String name = 'Ahmed Khan',
  String service = 'AC Repair',
  String type = 'text',
  String message = 'Latest message',
  int primaryUnread = 0,
  int legacyUnread = 0,
  String photo = '',
  int minute = 1,
}) {
  return CustomerConversation(
    id: id,
    data: {
      'customerId': 'customer-1',
      'workerId': 'worker-$id',
      'service': service,
      'lastMessage': message,
      'lastMessageType': type,
      'lastMessageTime': DateTime(2026, 9, 2, 10, minute),
      'customerUnreadCount': primaryUnread,
      'unreadCountCustomer': legacyUnread,
    },
    worker: CustomerChatWorker(
      id: 'worker-$id',
      data: {
        'role': 'worker',
        'name': name,
        'skill': service,
        'profileImageUrl': photo,
        'identityVerificationStatus': 'approved',
      },
    ),
  );
}

CustomerChatMessage _message(
  String id,
  String text,
  int minute, {
  String sender = 'customer-1',
}) {
  return CustomerChatMessage(
    id: id,
    data: {
      'senderId': sender,
      'receiverId': sender == 'customer-1' ? 'worker-1' : 'customer-1',
      'type': 'text',
      'text': text,
      'status': 'sent',
      'createdAt': DateTime(2026, 9, 2, 10, minute),
    },
  );
}

CustomerChatContext _context({bool typing = false, String requestId = ''}) {
  return CustomerChatContext(
    id: 'chat-1',
    data: {
      'customerId': 'customer-1',
      'workerId': 'worker-1',
      'service': 'AC Repair',
      'requestId': requestId,
      'lastMessageTime': DateTime(2026, 9, 2, 10),
      'typing': {'worker-1': typing},
    },
  );
}

CustomerChatWorker _worker() => const CustomerChatWorker(
  id: 'worker-1',
  data: {
    'role': 'worker',
    'name': 'Ahmed Khan',
    'skill': 'AC Repair',
    'identityVerificationStatus': 'approved',
    'phone': '03001234567',
  },
);

class _FakeChatSource implements CustomerChatDataSource {
  _FakeChatSource({
    this.conversations = const [],
    this.error = false,
    CustomerChatContext? context,
    this.worker,
    this.booking,
    this.messages = const [],
    this.olderMessages = const [],
    this.hasMore = false,
  }) : context = context ?? _context();

  final List<CustomerConversation> conversations;
  final bool error;
  final CustomerChatContext context;
  final CustomerChatWorker? worker;
  final Map<String, dynamic>? booking;
  final List<CustomerChatMessage> messages;
  final List<CustomerChatMessage> olderMessages;
  final bool hasMore;
  int searchReads = 0;
  int markReadCalls = 0;
  int loadOlderCalls = 0;
  final List<Map<String, dynamic>> sentContents = [];

  @override
  String get customerId => 'customer-1';

  @override
  Stream<List<CustomerConversation>> watchConversations() =>
      error ? Stream.error(StateError('offline')) : Stream.value(conversations);

  @override
  Stream<CustomerChatContext?> watchChat(String chatId) =>
      Stream.value(context);

  @override
  Stream<CustomerChatWorker?> watchWorker(String workerId) =>
      Stream.value(worker);

  @override
  Stream<Map<String, dynamic>?> watchBooking(String requestId) =>
      Stream.value(booking);

  @override
  Stream<CustomerMessagePage> watchLatestMessages(
    String chatId, {
    int pageSize = 40,
  }) => Stream.value(
    CustomerMessagePage(
      messages: messages,
      hasMore: hasMore,
      cursor: hasMore ? 'cursor' : null,
    ),
  );

  @override
  Future<CustomerMessagePage> loadOlderMessages(
    String chatId,
    Object cursor, {
    int pageSize = 40,
  }) async {
    loadOlderCalls++;
    return CustomerMessagePage(
      messages: olderMessages,
      hasMore: false,
      cursor: 'older-cursor',
    );
  }

  @override
  Future<void> markConversationRead(
    String chatId, {
    dynamic observedLastMessageTime,
  }) async {
    markReadCalls++;
  }

  @override
  Future<void> setTyping(String chatId, bool typing) async {}

  @override
  Future<void> sendMessage(
    String chatId, {
    required String workerId,
    required String service,
    required Map<String, dynamic> content,
    Map<String, dynamic>? replyTo,
  }) async {
    sentContents.add(content);
  }

  @override
  Future<void> deleteMessage(
    String chatId,
    CustomerChatMessage message,
  ) async {}

  @override
  Future<void> setReaction(
    String chatId,
    String messageId,
    String? emoji,
  ) async {}

  @override
  Future<void> setArchived(String chatId, bool archived) async {}

  @override
  Future<void> refreshConversations() async {}
}

Widget _app(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: SkillNovaTheme.light,
    darkTheme: SkillNovaTheme.dark,
    themeMode: mode,
    home: child,
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}
