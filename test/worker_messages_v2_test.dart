import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/customer_screens/chat/chat_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_repository.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_chat_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_chat_models.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_chat_repository.dart';
import 'package:skill_link/screens/worker_screens/messages/worker_messages_screen.dart';

void main() {
  test('worker unread adapter uses the strongest of every known alias', () {
    final conversation = _conversation(
      'aliases',
      unread: 1,
      legacyUnread: 4,
      oldestUnread: 7,
    );
    expect(conversation.unreadCount, 7);
  });

  test('message type previews are normalized', () {
    expect(_conversation('photo', type: 'image').latestPreview, 'Photo');
    expect(
      _conversation('voice', type: 'voice').latestPreview,
      'Voice message',
    );
    expect(
      _conversation('deleted', type: 'deleted').latestPreview,
      'Message deleted',
    );
  });

  test('same customer keeps separate request conversations', () {
    final result = canonicalWorkerConversations([
      _conversation('plumbing', requestId: 'request-1', service: 'Plumbing'),
      _conversation('ac', requestId: 'request-2', service: 'AC Repair'),
    ]);
    expect(result, hasLength(2));
    expect(result.map((item) => item.requestId), {'request-1', 'request-2'});
  });

  test('duplicate historical chats for one request keep the newest', () {
    final result = canonicalWorkerConversations([
      _conversation('old', requestId: 'request-1', minute: 1),
      _conversation('new', requestId: 'request-1', minute: 4),
    ]);
    expect(result.single.id, 'new');
  });

  test('direct chats retain document identity and deterministic ordering', () {
    final result = canonicalWorkerConversations([
      _conversation('direct-a', minute: 1),
      _conversation('direct-b', minute: 3),
      _conversation('request', requestId: 'request-1', minute: 2),
    ]);
    expect(result.map((item) => item.id), ['direct-b', 'request', 'direct-a']);
  });

  test(
    'bounded query, hydration, and message page constants stay explicit',
    () {
      expect(workerConversationQueryLimit, 80);
      expect(workerCustomerHydrationChunkSize, 10);
      expect(workerMessagePageSize, 40);
    },
  );

  test('request chat identity and ownership match resolution rules', () {
    expect(deterministicWorkerRequestChatId('job-1'), 'request_job-1');
    expect(
      isValidWorkerRequestChat(
        data: const {
          'workerId': 'worker-1',
          'customerId': 'customer-1',
          'requestId': 'job-1',
        },
        workerId: 'worker-1',
        customerId: 'customer-1',
        requestId: 'job-1',
      ),
      isTrue,
    );
    expect(
      isValidWorkerRequestChat(
        data: const {
          'workerId': 'other-worker',
          'customerId': 'customer-1',
          'requestId': 'job-1',
        },
        workerId: 'worker-1',
        customerId: 'customer-1',
        requestId: 'job-1',
      ),
      isFalse,
    );
  });

  test('message pages merge deterministically without duplicates', () {
    final merged = mergeCustomerMessages(
      [_message('m1', 'one', 1), _message('m2', 'old two', 2)],
      [_message('m2', 'new two', 2), _message('m3', 'three', 3)],
    );
    expect(merged.map((item) => item.id), ['m1', 'm2', 'm3']);
    expect(merged[1].text, 'new two');
  });

  testWidgets('empty active messages fit 320x720', (tester) async {
    _setSize(tester, const Size(320, 720));
    await tester.pumpWidget(
      _app(WorkerMessagesScreen(dataSource: _FakeWorkerChatSource())),
    );
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'list keeps two same-customer jobs, previews media and large unread safely',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      final source = _FakeWorkerChatSource(
        conversations: [
          _conversation(
            'plumbing',
            requestId: 'request-1',
            service: 'A very long plumbing service title for a compact card',
            type: 'image',
            oldestUnread: 180,
            minute: 3,
          ),
          _conversation(
            'ac',
            requestId: 'request-2',
            service: 'AC Repair',
            type: 'audio',
            minute: 2,
          ),
        ],
      );
      await tester.pumpWidget(_app(WorkerMessagesScreen(dataSource: source)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('worker-conversation-plumbing')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('worker-conversation-ac')),
        findsOneWidget,
      );
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Voice message'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search is local and supports a no-result state', (tester) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeWorkerChatSource(
      conversations: [
        _conversation('one', service: 'Plumbing'),
        _conversation('two', service: 'AC Repair'),
      ],
    );
    await tester.pumpWidget(_app(WorkerMessagesScreen(dataSource: source)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('worker-message-search')),
      'plumbing',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('worker-conversation-one')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('worker-conversation-two')), findsNothing);
    expect(source.refreshCalls, 0);
    await tester.enterText(
      find.byKey(const ValueKey('worker-message-search')),
      'gardening',
    );
    await tester.pump();
    expect(find.text('No matching conversations'), findsOneWidget);
  });

  testWidgets('archived tab remains readable and restores conversations', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeWorkerChatSource(
      conversations: [_conversation('archived', archived: true)],
    );
    await tester.pumpWidget(_app(WorkerMessagesScreen(dataSource: source)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('worker-conversation-archived')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Conversation options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pump();
    expect(source.archiveChanges, [('archived', false)]);
  });

  testWidgets('messages has a safe error state', (tester) async {
    _setSize(tester, const Size(320, 720));
    await tester.pumpWidget(
      _app(
        WorkerMessagesScreen(dataSource: _FakeWorkerChatSource(error: true)),
      ),
    );
    await tester.pump();
    expect(find.text('Messages could not be loaded'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('messages renders in dark theme without overflow', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 720));
    await tester.pumpWidget(
      _app(
        WorkerMessagesScreen(
          dataSource: _FakeWorkerChatSource(
            conversations: [_conversation('one')],
          ),
        ),
        mode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Messages').first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unrelated worker or invalid chat is rejected before messages', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeWorkerChatSource(context: null);
    await tester.pumpWidget(_app(_detail(source)));
    await tester.pumpAndSettle();
    expect(find.text('Conversation unavailable'), findsOneWidget);
    expect(source.latestSubscriptions, 0);
  });

  testWidgets('missing assigned request rejects request chat', (tester) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeWorkerChatSource(
      context: _context(requestId: 'request-1'),
      request: null,
    );
    await tester.pumpWidget(_app(_detail(source, requestId: 'request-1')));
    await tester.pumpAndSettle();
    expect(find.text('Conversation unavailable'), findsOneWidget);
    expect(source.latestSubscriptions, 0);
  });

  testWidgets('assigned job context routes to canonical job callback', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeWorkerChatSource(
      context: _context(requestId: 'request-1', typing: true),
      request: _request(),
      messages: [
        _message('incoming', 'Please come soon', 1, sender: 'customer-1'),
      ],
    );
    String? viewed;
    await tester.pumpWidget(
      _app(
        WorkerChatDetailV2Screen(
          chatId: 'chat-1',
          customerId: 'customer-1',
          customerName: 'Customer',
          service: 'AC Repair',
          requestId: 'request-1',
          dataSource: source,
          onViewJob: (id) => viewed = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('worker-chat-job-context')),
      findsOneWidget,
    );
    expect(find.textContaining('Accepted'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-typing-indicator')), findsOneWidget);
    expect(find.textContaining('Online'), findsNothing);
    expect(find.textContaining('Active '), findsNothing);
    await tester.tap(find.byKey(const ValueKey('worker-chat-view-job')));
    expect(viewed, 'request-1');
    expect(source.markReadCalls, 1);
  });

  testWidgets('direct chat omits job context and sends trimmed text', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 720));
    final source = _FakeWorkerChatSource(messages: const []);
    await tester.pumpWidget(_app(_detail(source)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('worker-chat-job-context')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '   Hello customer   ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump();
    expect(source.sentContents.single['text'], 'Hello customer');
    expect(source.sentCustomerIds.single, 'customer-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank text does not send', (tester) async {
    _setSize(tester, const Size(320, 720));
    final source = _FakeWorkerChatSource(messages: const []);
    await tester.pumpWidget(_app(_detail(source)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '   ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(source.sentContents, isEmpty);
  });

  testWidgets(
    'chat renders text, image, voice, reply, reaction and real seen state',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      final source = _FakeWorkerChatSource(
        messages: [
          _message(
            'incoming',
            'A long customer message that wraps safely',
            1,
            sender: 'customer-1',
          ),
          CustomerChatMessage(
            id: 'reply',
            data: {
              'senderId': 'worker-1',
              'receiverId': 'customer-1',
              'type': 'text',
              'text': 'Reply response',
              'status': 'seen',
              'createdAt': DateTime(2026, 9, 6, 10, 2),
              'replyTo': const {
                'senderId': 'customer-1',
                'text': 'Quoted request',
              },
              'reactions': const {'customer-1': '👍'},
            },
          ),
          CustomerChatMessage(
            id: 'image',
            data: {
              'senderId': 'customer-1',
              'type': 'image',
              'imageUrl': '',
              'createdAt': DateTime(2026, 9, 6, 10, 3),
            },
          ),
          CustomerChatMessage(
            id: 'audio',
            data: {
              'senderId': 'customer-1',
              'type': 'audio',
              'audioUrl': '',
              'durationMs': 65000,
              'createdAt': DateTime(2026, 9, 6, 10, 4),
            },
          ),
        ],
      );
      await tester.pumpWidget(_app(_detail(source)));
      await tester.pumpAndSettle();
      expect(find.textContaining('A long customer message'), findsOneWidget);
      expect(find.text('Quoted request'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('Photo unavailable'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-audio-message')), findsOneWidget);
      expect(find.text('01:05'), findsOneWidget);
      expect(find.byTooltip('Seen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat loads older page once and removes duplicate IDs', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final latest = List.generate(
      40,
      (index) => _message('m$index', 'Message $index', index + 10),
    );
    final source = _FakeWorkerChatSource(
      messages: latest,
      hasMore: true,
      olderMessages: [
        _message('old', 'Oldest loaded message', 1),
        _message('m0', 'Duplicate message', 10),
      ],
    );
    await tester.pumpWidget(_app(_detail(source)));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('worker-chat-message-list')),
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(source.loadOlderCalls, 1);
    scrollable.position.jumpTo(0);
    await tester.pump();
    expect(find.text('Oldest loaded message'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-m0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

WorkerConversation _conversation(
  String id, {
  String requestId = '',
  String service = 'AC Repair',
  String type = 'text',
  int unread = 0,
  int legacyUnread = 0,
  int oldestUnread = 0,
  int minute = 1,
  bool archived = false,
}) {
  return WorkerConversation(
    id: id,
    data: {
      'workerId': 'worker-1',
      'customerId': 'customer-1',
      'requestId': requestId,
      'service': service,
      'lastMessage': 'Latest message',
      'lastMessageType': type,
      'lastMessageTime': DateTime(2026, 9, 6, 10, minute),
      'workerUnreadCount': unread,
      'unreadCountWorker': legacyUnread,
      'unreadWorkerCount': oldestUnread,
      'archivedByWorker': archived,
    },
    customer: const WorkerChatCustomerSummary(
      id: 'customer-1',
      name: 'A very long customer name that remains readable',
      photoUrl: '',
    ),
  );
}

CustomerChatMessage _message(
  String id,
  String text,
  int minute, {
  String sender = 'worker-1',
}) {
  return CustomerChatMessage(
    id: id,
    data: {
      'senderId': sender,
      'receiverId': sender == 'worker-1' ? 'customer-1' : 'worker-1',
      'type': 'text',
      'text': text,
      'status': 'sent',
      'createdAt': DateTime(2026, 9, 6, 10, minute),
    },
  );
}

WorkerChatContext _context({String requestId = '', bool typing = false}) {
  return WorkerChatContext(
    id: 'chat-1',
    data: {
      'workerId': 'worker-1',
      'customerId': 'customer-1',
      'requestId': requestId,
      'service': 'AC Repair',
      'lastMessageTime': DateTime(2026, 9, 6, 10),
      'typing': {'customer-1': typing},
    },
  );
}

WorkerChatRequest _request() => WorkerChatRequest(
  id: 'request-1',
  data: const {
    'workerId': 'worker-1',
    'customerId': 'customer-1',
    'category': 'AC Repair',
    'status': 'accepted',
    'budget': 'PKR 4,000',
  },
);

Widget _detail(_FakeWorkerChatSource source, {String requestId = ''}) {
  return WorkerChatDetailV2Screen(
    chatId: 'chat-1',
    customerId: 'customer-1',
    customerName: 'Customer',
    service: 'AC Repair',
    requestId: requestId,
    dataSource: source,
  );
}

class _FakeWorkerChatSource implements WorkerChatDataSource {
  _FakeWorkerChatSource({
    this.conversations = const [],
    this.error = false,
    WorkerChatContext? context = const _DefaultContextMarker(),
    WorkerChatRequest? request = const _DefaultRequestMarker(),
    this.messages = const [],
    this.olderMessages = const [],
    this.hasMore = false,
  }) : context = context is _DefaultContextMarker ? _context() : context,
       request = request is _DefaultRequestMarker ? _request() : request;

  final List<WorkerConversation> conversations;
  final bool error;
  final WorkerChatContext? context;
  final WorkerChatRequest? request;
  final List<CustomerChatMessage> messages;
  final List<CustomerChatMessage> olderMessages;
  final bool hasMore;
  int refreshCalls = 0;
  int latestSubscriptions = 0;
  int markReadCalls = 0;
  int loadOlderCalls = 0;
  final List<(String, bool)> archiveChanges = [];
  final List<Map<String, dynamic>> sentContents = [];
  final List<String> sentCustomerIds = [];

  @override
  String get workerId => 'worker-1';

  @override
  Stream<List<WorkerConversation>> watchConversations() =>
      error ? Stream.error(StateError('offline')) : Stream.value(conversations);

  @override
  Stream<WorkerChatContext?> watchChat(String chatId) => Stream.value(context);

  @override
  Stream<WorkerChatCustomer?> watchCustomer(String customerId) => Stream.value(
    const WorkerChatCustomer(
      id: 'customer-1',
      name: 'Sara Customer',
      photoUrl: '',
      phone: '03001234567',
    ),
  );

  @override
  Stream<WorkerChatRequest?> watchRequest(
    String requestId,
    String customerId,
  ) => Stream.value(request);

  @override
  Stream<CustomerMessagePage> watchLatestMessages(
    String chatId, {
    int pageSize = workerMessagePageSize,
  }) {
    return Stream<CustomerMessagePage>.multi((controller) {
      latestSubscriptions++;
      controller.add(
        CustomerMessagePage(
          messages: messages,
          hasMore: hasMore,
          cursor: hasMore ? 'cursor' : null,
        ),
      );
      controller.close();
    });
  }

  @override
  Future<CustomerMessagePage> loadOlderMessages(
    String chatId,
    Object cursor, {
    int pageSize = workerMessagePageSize,
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
    required String customerId,
    required String service,
    required Map<String, dynamic> content,
    Map<String, dynamic>? replyTo,
  }) async {
    sentCustomerIds.add(customerId);
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
  Future<void> setArchived(String chatId, bool archived) async {
    archiveChanges.add((chatId, archived));
  }

  @override
  Future<void> refreshConversations() async {
    refreshCalls++;
  }
}

class _DefaultContextMarker extends WorkerChatContext {
  const _DefaultContextMarker() : super(id: '', data: const {});
}

class _DefaultRequestMarker extends WorkerChatRequest {
  const _DefaultRequestMarker() : super(id: '', data: const {});
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
