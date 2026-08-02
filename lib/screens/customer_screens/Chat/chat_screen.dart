import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';

class CustomerChatsScreen extends StatefulWidget {
  const CustomerChatsScreen({super.key});

  @override
  State<CustomerChatsScreen> createState() => _CustomerChatsScreenState();
}

class _CustomerChatsScreenState extends State<CustomerChatsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final TabController _tabController;

  String _searchQuery = '';
  bool _isSearchFocused = false;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _chatStream {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('customerId', isEqualTo: _currentUserId)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _searchFocusNode.addListener(() {
      if (!mounted) return;

      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Text(
            'Please sign in to view your chats.',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: const CustomerBottomBar(selectedIndex: 3),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topArea(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chatStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return _loadingState();
                  }

                  if (snapshot.hasError) {
                    return _errorState();
                  }

                  final documents = snapshot.data?.docs ?? [];

                  final sortedChats = [...documents];

                  sortedChats.sort((first, second) {
                    final firstTime = _timestampValue(
                      first.data()['lastMessageTime'] ??
                          first.data()['updatedAt'],
                    );

                    final secondTime = _timestampValue(
                      second.data()['lastMessageTime'] ??
                          second.data()['updatedAt'],
                    );

                    return secondTime.compareTo(firstTime);
                  });

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _chatList(
                        chats: sortedChats.where((document) {
                          return document.data()['archivedByCustomer'] != true;
                        }).toList(),
                        archived: false,
                      ),
                      _chatList(
                        chats: sortedChats.where((document) {
                          return document.data()['archivedByCustomer'] == true;
                        }).toList(),
                        archived: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(.20),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.45,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Chat with your hired professionals',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isSearchFocused ? _primary : _border,
                width: _isSearchFocused ? 1.5 : 1,
              ),
              boxShadow: _isSearchFocused
                  ? [
                      BoxShadow(
                        color: _primary.withOpacity(.10),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : const [],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: true,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search worker, service or message',
                hintStyle: const TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 11.2,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _primary,
                  size: 21,
                ),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _searchQuery = '';
                          });

                          _searchFocusNode.requestFocus();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _textSecondary,
                          size: 19,
                        ),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 17,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: _primary,
              unselectedLabelColor: _textSecondary,
              indicator: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              labelStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  text: 'Active',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.archive_outlined, size: 17),
                  text: 'Archived',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatList({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> chats,
    required bool archived,
  }) {
    if (chats.isEmpty) {
      return _emptyState(archived: archived);
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final chat = chats[index];

        return _chatTile(
          chatId: chat.id,
          chat: chat.data(),
          archived: archived,
        );
      },
    );
  }

  Widget _chatTile({
    required String chatId,
    required Map<String, dynamic> chat,
    required bool archived,
  }) {
    final workerId = chat['workerId']?.toString().trim() ?? '';

    if (workerId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(workerId)
          .snapshots(),
      builder: (context, workerSnapshot) {
        final worker = workerSnapshot.data?.data();

        final workerName = worker?['name']?.toString().trim().isNotEmpty == true
            ? worker!['name'].toString().trim()
            : chat['workerName']?.toString().trim().isNotEmpty == true
            ? chat['workerName'].toString().trim()
            : 'Worker';

        final workerSkill =
            worker?['skill']?.toString().trim().isNotEmpty == true
            ? worker!['skill'].toString().trim()
            : chat['service']?.toString().trim().isNotEmpty == true
            ? chat['service'].toString().trim()
            : 'Professional Service';

        final workerPhone =
            worker?['phone']?.toString().trim() ??
            chat['workerPhone']?.toString().trim();

        final imageUrl = _workerImageUrl(worker, chat);

        final isOnline = worker?['isOnline'] == true;

        final lastMessage =
            chat['lastMessage']?.toString().trim().isNotEmpty == true
            ? chat['lastMessage'].toString().trim()
            : 'Start a conversation';

        final lastMessageType = chat['lastMessageType']?.toString() ?? 'text';

        final unreadCount = _intValue(
          chat['customerUnreadCount'] ?? chat['unreadCountCustomer'],
        );

        final lastSenderId = chat['lastSenderId']?.toString() ?? '';

        final timestamp = chat['lastMessageTime'] ?? chat['updatedAt'];

        final matchesSearch =
            _searchQuery.isEmpty ||
            workerName.toLowerCase().contains(_searchQuery) ||
            workerSkill.toLowerCase().contains(_searchQuery) ||
            lastMessage.toLowerCase().contains(_searchQuery);

        if (!matchesSearch) {
          return const SizedBox.shrink();
        }

        return Dismissible(
          key: ValueKey('$chatId-$archived'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await _toggleArchive(chatId: chatId, archive: !archived);

            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: archived
                    ? const [Color(0xFF16A34A), Color(0xFF14B8A6)]
                    : const [Color(0xFF475569), Color(0xFF334155)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  archived ? Icons.unarchive_rounded : Icons.archive_rounded,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Text(
                  archived ? 'Unarchive' : 'Archive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _openChat(
                chatId: chatId,
                workerId: workerId,
                workerName: workerName,
                workerSkill: workerSkill,
                workerPhone: workerPhone,
                workerImageUrl: imageUrl,
              ),
              onLongPress: () => _showChatOptions(
                chatId: chatId,
                workerName: workerName,
                archived: archived,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: unreadCount > 0
                        ? _primary.withOpacity(.30)
                        : _border,
                    width: unreadCount > 0 ? 1.3 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 60,
                          width: 60,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _secondary],
                            ),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;

                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: _primary,
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) {
                                      return _avatarFallback(workerName);
                                    },
                                  )
                                : _avatarFallback(workerName),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            height: 18,
                            width: 18,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? _success
                                  : const Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                              border: Border.all(color: _surface, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  workerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 13.8,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w900
                                        : FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(timestamp),
                                style: TextStyle(
                                  color: unreadCount > 0
                                      ? _primary
                                      : _textSecondary,
                                  fontSize: 8.7,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  workerSkill,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                height: 3,
                                width: 3,
                                decoration: const BoxDecoration(
                                  color: _textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: isOnline ? _success : _textSecondary,
                                  fontSize: 8.7,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (lastSenderId == _currentUserId) ...[
                                const Icon(
                                  Icons.done_all_rounded,
                                  color: _primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (lastMessageType == 'image') ...[
                                const Icon(
                                  Icons.photo_outlined,
                                  color: _textSecondary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (lastMessageType == 'audio') ...[
                                const Icon(
                                  Icons.mic_none_rounded,
                                  color: _textSecondary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadCount > 0
                                        ? _textPrimary
                                        : _textSecondary,
                                    fontSize: 10.2,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 22,
                                    minHeight: 22,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_primary, _secondary],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Chat options',
                      color: _surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (value) async {
                        if (value == 'archive') {
                          await _toggleArchive(
                            chatId: chatId,
                            archive: !archived,
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(
                                archived
                                    ? Icons.unarchive_outlined
                                    : Icons.archive_outlined,
                                color: _textPrimary,
                                size: 19,
                              ),
                              const SizedBox(width: 9),
                              Text(
                                archived ? 'Unarchive chat' : 'Archive chat',
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: _textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openChat({
    required String chatId,
    required String workerId,
    required String workerName,
    required String workerSkill,
    required String? workerPhone,
    required String workerImageUrl,
  }) async {
    FocusScope.of(context).unfocus();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          workerId: workerId,
          workerName: workerName,
          workerSkill: workerSkill,
          workerPhone: workerPhone,
          workerImageUrl: workerImageUrl,
        ),
      ),
    );
  }

  Future<void> _toggleArchive({
    required String chatId,
    required bool archive,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'archivedByCustomer': archive,
        'archivedAtCustomer': archive ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showMessage(
        archive ? 'Chat moved to archive.' : 'Chat restored to active chats.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage('Unable to update chat archive.', isError: true);
    }
  }

  Future<void> _showChatOptions({
    required String chatId,
    required String workerName,
    required bool archived,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  workerName,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(
                    archived ? Icons.unarchive_rounded : Icons.archive_rounded,
                    color: _primary,
                  ),
                  title: Text(
                    archived ? 'Unarchive chat' : 'Archive chat',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await _toggleArchive(chatId: chatId, archive: !archived);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _workerImageUrl(
    Map<String, dynamic>? worker,
    Map<String, dynamic> chat,
  ) {
    final candidates = [
      worker?['profileImageUrl'],
      worker?['profileImage'],
      worker?['imageUrl'],
      worker?['photoUrl'],
      chat['workerImageUrl'],
      chat['workerImage'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  Widget _avatarFallback(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    final initials = parts.isEmpty
        ? 'WK'
        : parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first.substring(0, 1)}'
                  '${parts.last.substring(0, 1)}'
              .toUpperCase();

    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFDDF4FF)],
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: _primary,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState({required bool archived}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 65, 24, 120),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x070F172A),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: archived
                        ? [
                            const Color(0xFF64748B).withOpacity(.14),
                            const Color(0xFF94A3B8).withOpacity(.08),
                          ]
                        : [
                            _primary.withOpacity(.14),
                            _secondary.withOpacity(.08),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  archived ? Icons.archive_outlined : Icons.forum_outlined,
                  color: archived ? _textSecondary : _primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 17),
              Text(
                archived ? 'No archived chats' : 'No active conversations',
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                archived
                    ? 'Chats you archive will appear here.'
                    : 'Your conversations with workers will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingState() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Container(
          height: 90,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.3),
          ),
        );
      },
    );
  }

  Widget _errorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: _danger, size: 40),
            SizedBox(height: 12),
            Text(
              'Unable to load chats',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: isError ? _danger : _textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  DateTime _timestampValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate();
    final now = DateTime.now();

    if (DateUtils.isSameDay(date, now)) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    final yesterday = now.subtract(const Duration(days: 1));

    if (DateUtils.isSameDay(date, yesterday)) {
      return 'Yesterday';
    }

    if (now.difference(date).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return days[date.weekday - 1];
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}
